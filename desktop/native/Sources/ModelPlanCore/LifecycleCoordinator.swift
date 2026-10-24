// SPDX-License-Identifier: MIT
import Foundation

/// Combines independent OS pause reasons. A wake is not an unlock or a user-session return.
@MainActor public final class LifecycleCoordinator {
    public enum PauseReason: Hashable, Sendable {
        case systemSleep, screenSleep, screenLocked, sessionInactive, noDisplay, userDisabled
    }
    private let store: SnapshotStore
    private var reasons: Set<PauseReason> = []
    private var started = false
    private var stopped = false
    private var displayRecovery: Task<Void, Never>?
    public private(set) var canPresent = false
    /// Called after deadline validation on resume, and before work cancellation on pause.
    /// Consumers may hide/re-render, but must never activate another app's focus on resume.
    public var onPresentationChange: ((Bool) -> Void)?
    public init(store: SnapshotStore) { self.store = store }
    public func start() {
        guard !started, !stopped else { return }
        started = true; reconcile()
    }
    public func set(_ reason: PauseReason, blocked: Bool) {
        guard !stopped else { return }
        let changed: Bool
        if blocked { changed = reasons.insert(reason).inserted }
        else { changed = reasons.remove(reason) != nil }
        if changed { reconcile() }
    }
    /// Removed displays invalidate in-flight results, even when another display remains available.
    /// Coalesce a burst into one recovery, and retain all unrelated pause reasons.
    public func displayRemoved() {
        guard started, !stopped else { return }
        hide(); store.suspend()
        guard displayRecovery == nil else { return }
        displayRecovery = Task { [weak self] in
            await Task.yield()
            guard let self, !Task.isCancelled, !self.stopped else { return }
            self.displayRecovery = nil; self.reconcile()
        }
    }
    public func clockChanged() { store.clockOrTimeZoneChanged() }
    public func stop() async {
        stopped = true; displayRecovery?.cancel(); displayRecovery = nil
        hide(); await store.stopAndWait()
    }
    private func hide() {
        guard canPresent else { return }
        canPresent = false; onPresentationChange?(false)
    }
    private func reconcile() {
        guard started, !stopped else { return }
        if !reasons.isEmpty || displayRecovery != nil {
            hide(); store.suspend()
        } else {
            store.resume() // Retire deadlines before the consumer can restore a frame.
            if !canPresent { canPresent = true; onPresentationChange?(true) }
        }
    }
}
