// SPDX-License-Identifier: MIT
import Foundation

/// Spec 5.3 B (behaviour from CodexBar `MenuBarVisibilityWatcher`, own code): display-change notifications come in
/// bursts while a reconfiguration settles (clamshell, display wake, resolution), and menu-bar frames are only right
/// after the last one. So the status item is re-verified once 750 ms after the LAST change (trailing debounce), then
/// once more 2 s later. A new change cancels both and starts over. No recreation is ever done here.
@MainActor public final class DisplayChangeRecheck {
    /// Arms `fire` after `milliseconds`; the returned closure cancels it. Tests pass a fake clock.
    public typealias Schedule = @MainActor (_ milliseconds: UInt64, _ fire: @escaping @MainActor () -> Void) -> () -> Void
    public static let settleMilliseconds: UInt64 = 750
    public static let followUpMilliseconds: UInt64 = 2_000
    private let schedule: Schedule
    private let settled: @MainActor () -> Void
    private let followUp: @MainActor () -> Void
    private var cancelPending: (() -> Void)?
    private var generation: UInt64 = 0

    public init(schedule: @escaping Schedule = DisplayChangeRecheck.sleepSchedule,
                settled: @escaping @MainActor () -> Void, followUp: @escaping @MainActor () -> Void) {
        self.schedule = schedule; self.settled = settled; self.followUp = followUp
    }
    /// One display-parameter notification.
    public func displaysChanged() {
        cancel()
        let token = generation
        cancelPending = schedule(Self.settleMilliseconds) { [weak self] in
            guard let self, self.generation == token else { return }
            self.cancelPending = nil
            self.settled()
            guard self.generation == token else { return }
            self.cancelPending = self.schedule(Self.followUpMilliseconds) { [weak self] in
                guard let self, self.generation == token else { return }
                self.cancelPending = nil
                self.followUp()
            }
        }
    }
    public var isPending: Bool { cancelPending != nil }
    /// Cancels a pending settle or follow-up (a new change, terminate).
    public func cancel() {
        generation &+= 1
        cancelPending?(); cancelPending = nil
    }
    public static func sleepSchedule(_ milliseconds: UInt64, _ fire: @escaping @MainActor () -> Void) -> () -> Void {
        let task = Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(Int64(milliseconds))) } catch { return }
            guard !Task.isCancelled else { return }
            fire()
        }
        return { task.cancel() }
    }
}
