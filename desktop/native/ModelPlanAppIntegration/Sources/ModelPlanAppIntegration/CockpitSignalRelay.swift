// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanCockpitWeb
import ModelPlanShell

/// Native-shell spec item 2 (tail): the app's one wake/unlock/clock/display source for every cockpit page, for the
/// whole life of the app. A page subscribes here when it is built, which is often during the prewarm, before the
/// lifecycle (and its `SystemEvents`) exists; the lifecycle feeds the relay once it starts. Before this, a page built
/// that early kept its own NSWorkspace observers for its whole life, so it never had the settled display pass and
/// counted every wake twice.
///
/// `didWake` and `screensDidWake` both arrive on one system wake; the page gets one `.wake` for them (spec 2.3: a
/// second wake edge within 1 s is the same wake). A display-only wake still arrives alone and is delivered.
@MainActor final class CockpitSignalRelay {
    static let wakeCollapseMilliseconds: UInt64 = 1_000
    private let now: @MainActor () -> UInt64
    private var subscribers: [(id: UInt64, handler: @MainActor (CockpitSystemSignal) -> Void)] = []
    private var nextID: UInt64 = 0
    private var lastWake: UInt64?

    init(now: @escaping @MainActor () -> UInt64 = DismissalFunnel.uptimeMilliseconds) { self.now = now }

    /// The page's subscription; the returned closure unsubscribes (idempotent).
    func subscribe(_ handler: @escaping @MainActor (CockpitSystemSignal) -> Void) -> () -> Void {
        nextID &+= 1; let id = nextID
        subscribers.append((id, handler))
        return { [weak self] in MainActor.assumeIsolated { self?.subscribers.removeAll { $0.id == id } } }
    }

    /// One signal from the lifecycle's `SystemEvents` (gate already updated).
    func deliver(_ signal: SystemSignal) {
        let mapped: CockpitSystemSignal
        switch signal {
        case .wake, .screensWake:
            let time = now()
            if let lastWake, time >= lastWake, time - lastWake < Self.wakeCollapseMilliseconds { return }
            lastWake = time; mapped = .wake
        case .unlock: mapped = .unlock
        case .clockChanged, .timeZoneChanged: mapped = .clockChanged
        case .displaysChanged: mapped = .displaysChanged
        case .displaysSettled: mapped = .displaysSettled
        }
        // A snapshot: a page may unsubscribe (close) while this runs.
        for entry in subscribers { entry.handler(mapped) }
    }

    var subscriberCount: Int { subscribers.count }
}
