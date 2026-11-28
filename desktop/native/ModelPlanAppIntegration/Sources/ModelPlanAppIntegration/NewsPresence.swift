// SPDX-License-Identifier: MIT
import AppKit
import CoreGraphics
import ModelPlanDock

/// Master spec §5.3 (D474, D397/D166): the news clock's "present hours" count only while the user is at the Mac.
/// macOS has no idle notification, so the idle seconds are read at the existing refresh tick (`isPresentNow`, no new
/// timer). Sleep, screen sleep, a lock and a fast user switch close the present span at once through their
/// notifications, so the time up to the next refresh is never counted.
@MainActor final class NewsPresenceMonitor {
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []

    init(clock: DockNewsClockStore) {
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification] {
            observers.append((workspace, workspace.addObserver(forName: name, object: nil, queue: .main) { [weak clock] _ in
                clock?.endPresence()
            }))
        }
        let distributed = DistributedNotificationCenter.default()
        observers.append((distributed, distributed.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak clock] _ in
            clock?.endPresence()
        }))
    }

    func stop() {
        for (center, token) in observers { center.removeObserver(token) }
        observers.removeAll()
    }

    /// Read at each refresh tick: awake (refreshes only run then), unlocked, in the console session, and input within
    /// the last five minutes (`DockNewsClock.idleThreshold`).
    nonisolated static func isPresentNow() -> Bool {
        let session = CGSessionCopyCurrentDictionary() as? [String: Any]
        let locked = (session?["CGSSessionScreenIsLocked"] as? Bool) == true
        let onConsole = (session?["kCGSSessionOnConsoleKey"] as? Bool) ?? true
        // kCGAnyInputEventType (~0): seconds since the last keyboard, mouse or trackpad event in this login session.
        let idle = CGEventType(rawValue: ~0).map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
        return DockNewsClock.isPresent(locked: locked, onConsole: onConsole, idleSeconds: idle)
    }
}
