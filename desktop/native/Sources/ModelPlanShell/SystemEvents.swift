// SPDX-License-Identifier: MIT
import AppKit
import CoreGraphics
import ModelPlanCore

/// Native-shell spec item 2: one typed fan-out of the OS edges, independent of the gate. The gate is a pause/resume
/// reason set (it coalesces and can stay closed for another reason), so "gate opened" is not "this Mac just woke";
/// subscribers get the raw edge exactly once per notification, after the gate has been updated.
public enum SystemSignal: Equatable, Sendable {
    case wake, screensWake, unlock, clockChanged, timeZoneChanged
    /// Every display-parameter notification.
    case displaysChanged
    /// Once, 750 ms after the LAST display-parameter notification of a burst (CodexBar `MenuBarVisibilityWatcher`).
    case displaysSettled
}

/// AppKit notifications feed the same lifecycle transaction exercised by contract checks.
/// Screen-lock distributed notification names are best-effort OS conventions, not a security ACL.
@MainActor public final class SystemEvents {
    private let gate: LifecycleCoordinator
    private let workspace: NotificationCenter
    private let local: NotificationCenter
    private let distributed: NotificationCenter
    private let displayIDs: @MainActor () -> Set<UInt32>
    private let onConsole: @MainActor () -> Bool?
    private let displaysAsleep: @MainActor (Set<UInt32>) -> Bool
    /// v1 full review 11-24 #4: a lock seed from state tracked by the lock edges before this instance started (the
    /// pre-lifecycle watcher); nil seeds nothing (the lock edge only). Never a private Window Server property.
    private let screenLocked: (@MainActor () -> Bool?)?
    private var previousDisplays: Set<UInt32> = []
    private var tokens: [(NotificationCenter, NSObjectProtocol)] = []
    public typealias Schedule = @MainActor (_ milliseconds: UInt64, _ fire: @escaping @MainActor () -> Void) -> () -> Void
    public static let displaysSettleMilliseconds: UInt64 = 750
    private let schedule: Schedule
    private var subscribers: [(id: UInt64, handler: @MainActor (SystemSignal) -> Void)] = []
    private var nextSubscriber: UInt64 = 0
    private var cancelSettle: (() -> Void)?
    public init(gate: LifecycleCoordinator, workspace: NotificationCenter = NSWorkspace.shared.notificationCenter,
                local: NotificationCenter = .default, distributed: NotificationCenter = DistributedNotificationCenter.default(),
                displayIDs: @escaping @MainActor () -> Set<UInt32> = { SystemEvents.currentDisplayIDs() },
                onConsole: @escaping @MainActor () -> Bool? = {
                    (CGSessionCopyCurrentDictionary() as? [String: Any])?[kCGSessionOnConsoleKey as String] as? Bool
                }, displaysAsleep: @escaping @MainActor (Set<UInt32>) -> Bool = { ids in
                    !ids.isEmpty && ids.allSatisfy { CGDisplayIsAsleep($0) != 0 }
                }, screenLocked: (@MainActor () -> Bool?)? = nil, schedule: @escaping Schedule = SystemEvents.sleepSchedule) {
        self.schedule = schedule; self.screenLocked = screenLocked
        self.gate = gate; self.workspace = workspace; self.local = local
        self.distributed = distributed; self.displayIDs = displayIDs; self.onConsole = onConsole; self.displaysAsleep = displaysAsleep
    }
    nonisolated public static func currentConsoleState() -> Bool? {
        (CGSessionCopyCurrentDictionary() as? [String: Any])?[kCGSessionOnConsoleKey as String] as? Bool
    }
    /// The distributed screen-lock edges. macOS documents no query for the lock state (the documented session
    /// properties are user, console and login keys only), so the lock is tracked from these edges and an unknown state
    /// is "not locked" (fail open: the app never stays paused on a guess). Review 11-24 macrevb-1215-1.
    nonisolated public static let screenLockedNotification = Notification.Name("com.apple.screenIsLocked")
    nonisolated public static let screenUnlockedNotification = Notification.Name("com.apple.screenIsUnlocked")
    /// The workspace pause/resume pairs. The lifecycle and the pre-lifecycle (early start) watcher both observe exactly
    /// these, plus the lock edges and the screen-parameter change (`.noDisplay`), so the two phases share one reason set.
    public static var workspacePausePairs: [(pause: Notification.Name, resume: Notification.Name, reason: LifecycleCoordinator.PauseReason)] {
        [(NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification, .systemSleep),
         (NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification, .screenSleep),
         (NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.sessionDidBecomeActiveNotification, .sessionInactive)]
    }
    /// Review 11-24 #4: the OS pause reasons that hold right now, from the same documented queries `start()` seeds
    /// with (displays, console, display sleep). The lock has no documented query: it is unknown here, so not a reason.
    @MainActor public static func pauseReasonsNow() -> Set<LifecycleCoordinator.PauseReason> {
        pauseReasons(displayIDs: currentDisplayIDs(), onConsole: currentConsoleState(), screenLocked: nil)
    }
    /// Pure reduction of the queries; `NSScreen` is read only by the main-actor entry above, never in a default argument.
    nonisolated public static func pauseReasons(displayIDs: Set<UInt32>, onConsole: Bool?,
                                                screenLocked: Bool?) -> Set<LifecycleCoordinator.PauseReason> {
        var reasons: Set<LifecycleCoordinator.PauseReason> = []
        if displayIDs.isEmpty { reasons.insert(.noDisplay) }
        if onConsole == false { reasons.insert(.sessionInactive) }
        if allDisplaysAsleep(displayIDs) { reasons.insert(.screenSleep) }
        if screenLocked == true { reasons.insert(.screenLocked) }
        return reasons
    }
    nonisolated public static func allDisplaysAsleep(_ ids: Set<UInt32>) -> Bool {
        !ids.isEmpty && ids.allSatisfy { CGDisplayIsAsleep($0) != 0 }
    }
    public static func currentDisplayIDs() -> Set<UInt32> {
        Set(NSScreen.screens.compactMap { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value })
    }
    public func start() {
        guard tokens.isEmpty else { return }
        previousDisplays = displayIDs()
        gate.set(.noDisplay, blocked: previousDisplays.isEmpty)
        let pairs = Self.workspacePausePairs
        let resumeSignals: [Notification.Name: SystemSignal] = [NSWorkspace.didWakeNotification: .wake,
                                                                NSWorkspace.screensDidWakeNotification: .screensWake]
        for (pause, resume, reason) in pairs {
            observe(workspace, pause) { [weak gate] in gate?.set(reason, blocked: true) }
            let signal = resumeSignals[resume]
            observe(workspace, resume) { [weak self, weak gate] in
                gate?.set(reason, blocked: false)
                if let signal { self?.emit(signal) }
            }
        }
        observe(distributed, Self.screenLockedNotification) { [weak gate] in gate?.set(.screenLocked, blocked: true) }
        observe(distributed, Self.screenUnlockedNotification) { [weak self, weak gate] in
            gate?.set(.screenLocked, blocked: false); self?.emit(.unlock)
        }
        observe(local, .NSSystemClockDidChange) { [weak self, weak gate] in gate?.clockChanged(); self?.emit(.clockChanged) }
        observe(local, .NSSystemTimeZoneDidChange) { [weak self, weak gate] in gate?.clockChanged(); self?.emit(.timeZoneChanged) }
        observe(local, NSApplication.didChangeScreenParametersNotification) { [weak self] in
            guard let self else { return }
            self.screensChanged()
            self.emit(.displaysChanged)
            self.cancelSettle?()
            self.cancelSettle = self.schedule(Self.displaysSettleMilliseconds) { [weak self] in
                guard let self else { return }
                self.cancelSettle = nil
                self.emit(.displaysSettled)
            }
        }
        // Public on-console/display-asleep queries seed state when launched during a paused session.
        if let onConsole = onConsole() { gate.set(.sessionInactive, blocked: !onConsole) }
        gate.set(.screenSleep, blocked: displaysAsleep(previousDisplays))
        if let locked = screenLocked?() { gate.set(.screenLocked, blocked: locked) }
        gate.start()
    }
    public func stop() {
        for (center, token) in tokens { center.removeObserver(token) }
        tokens.removeAll()
        cancelSettle?(); cancelSettle = nil
        subscribers.removeAll()
    }
    /// Subscribers run synchronously on the main actor, in subscription order, after the gate update. The returned
    /// closure unsubscribes (idempotent).
    public func subscribe(_ handler: @escaping @MainActor (SystemSignal) -> Void) -> () -> Void {
        nextSubscriber &+= 1
        let id = nextSubscriber
        subscribers.append((id, handler))
        return { [weak self] in
            MainActor.assumeIsolated { self?.subscribers.removeAll { $0.id == id } }
        }
    }
    private func emit(_ signal: SystemSignal) {
        // A snapshot: a subscriber may unsubscribe (a cockpit closing on wake) while this runs.
        for entry in subscribers { entry.handler(signal) }
    }
    public static func sleepSchedule(_ milliseconds: UInt64, _ fire: @escaping @MainActor () -> Void) -> () -> Void {
        let task = Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(Int64(milliseconds))) } catch { return }
            guard !Task.isCancelled else { return }
            fire()
        }
        return { task.cancel() }
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
