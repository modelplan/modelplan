// SPDX-License-Identifier: MIT
import AppKit
import CoreGraphics
import ModelPlanCore

/// AppKit notifications feed the same lifecycle transaction exercised by contract checks.
/// Screen-lock distributed notification names are best-effort OS conventions, not a security ACL.
@MainActor public final class SystemEvents {
    private let gate: LifecycleCoordinator
    private let workspace: NotificationCenter
    private let local: NotificationCenter
    private let distributed: DistributedNotificationCenter
    private let displayIDs: @MainActor () -> Set<UInt32>
    private var previousDisplays: Set<UInt32> = []
    private var tokens: [(NotificationCenter, NSObjectProtocol)] = []
    public init(gate: LifecycleCoordinator, workspace: NotificationCenter = NSWorkspace.shared.notificationCenter,
                local: NotificationCenter = .default, distributed: DistributedNotificationCenter = .default(),
                displayIDs: @escaping @MainActor () -> Set<UInt32> = { SystemEvents.currentDisplayIDs() }) {
        self.gate = gate; self.workspace = workspace; self.local = local
        self.distributed = distributed; self.displayIDs = displayIDs
    }
    public static func currentDisplayIDs() -> Set<UInt32> {
        Set(NSScreen.screens.compactMap { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value })
    }
    public func start() {
        guard tokens.isEmpty else { return }
        previousDisplays = displayIDs()
        gate.set(.noDisplay, blocked: previousDisplays.isEmpty)
        let pairs: [(Notification.Name, Notification.Name, LifecycleCoordinator.PauseReason)] = [
            (NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification, .systemSleep),
            (NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification, .screenSleep),
            (NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.sessionDidBecomeActiveNotification, .sessionInactive)]
        for (pause, resume, reason) in pairs {
            observe(workspace, pause) { [weak gate] in gate?.set(reason, blocked: true) }
            observe(workspace, resume) { [weak gate] in gate?.set(reason, blocked: false) }
        }
        observe(distributed, Notification.Name("com.apple.screenIsLocked")) { [weak gate] in gate?.set(.screenLocked, blocked: true) }
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) { [weak gate] in gate?.set(.screenLocked, blocked: false) }
        observe(local, .NSSystemClockDidChange) { [weak gate] in gate?.clockChanged() }
        observe(local, .NSSystemTimeZoneDidChange) { [weak gate] in gate?.clockChanged() }
        observe(local, NSApplication.didChangeScreenParametersNotification) { [weak self] in self?.screensChanged() }
        // Public on-console/display-asleep queries seed state when launched during a paused session.
        if let session = CGSessionCopyCurrentDictionary() as? [String: Any],
           let onConsole = session[kCGSessionOnConsoleKey as String] as? Bool {
            gate.set(.sessionInactive, blocked: !onConsole)
        }
        gate.set(.screenSleep, blocked: !previousDisplays.isEmpty && previousDisplays.allSatisfy { CGDisplayIsAsleep($0) != 0 })
        gate.start()
    }
    public func stop() {
        for (center, token) in tokens { center.removeObserver(token) }
        tokens.removeAll()
    }
    deinit { for (center, token) in tokens { center.removeObserver(token) } }
    private func observe(_ center: NotificationCenter, _ name: Notification.Name, _ action: @escaping @MainActor () -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { action() }
        }
        tokens.append((center, token))
    }
    private func screensChanged() {
        let current = displayIDs()
        if !previousDisplays.subtracting(current).isEmpty { gate.displayRemoved() }
        previousDisplays = current
        gate.set(.noDisplay, blocked: current.isEmpty)
    }
}
