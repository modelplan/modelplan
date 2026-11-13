// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanDock

/// Drives only supplied timing facts. It owns no reader, window or data policy.
@MainActor final class HostDeadlineDriver<Value> {
    struct Candidate {
        let value: Value
        /// Captured from the same accepted snapshot as both value and deadline.
        let sourceToken: UInt64
        /// nil is a missing contract, distinct from the producer's `.unknown` and `.none`.
        let deadline: DockContentRecomputeDeadline?
    }
    enum Status: Equatable {
        case idle, scheduled, noFutureDeadline, missingContract, unknown, mixedUnknown, overdue, invalidClock, staleSource, suspended, closed
    }
    private let wallNow: @MainActor () -> Date
    private let elapsed: () -> TimeInterval
    private let scheduler: any DockEdgeScheduling
    private let clear: @MainActor () -> Void
    private let recompute: @MainActor (Date) -> Candidate?
    private let install: @MainActor (Value) -> Void
    private let sourceIsCurrent: @MainActor (UInt64) -> Bool
    private let report: @MainActor (Status) -> Void
    private let installValidatedUnknown: Bool
    private let presentationInterval: TimeInterval?
    private let refreshPresentation: @MainActor (Date) -> Void
    private var fence = HostDeadlineFence()
    private var scheduledSourceToken: UInt64?
    private var crossingBoundary = false
    private(set) var status: Status = .idle

    init(wallNow: @escaping @MainActor () -> Date, elapsed: @escaping () -> TimeInterval,
         scheduler: any DockEdgeScheduling, clear: @escaping @MainActor () -> Void,
         recompute: @escaping @MainActor (Date) -> Candidate?,
         install: @escaping @MainActor (Value) -> Void,
         sourceIsCurrent: @escaping @MainActor (UInt64) -> Bool, installValidatedUnknown: Bool = false,
         presentationInterval: TimeInterval? = nil, refreshPresentation: @escaping @MainActor (Date) -> Void = { _ in },
         report: @escaping @MainActor (Status) -> Void = { _ in }) {
        self.wallNow = wallNow; self.elapsed = elapsed; self.scheduler = scheduler
        self.clear = clear; self.recompute = recompute; self.install = install
        self.sourceIsCurrent = sourceIsCurrent; self.report = report; self.installValidatedUnknown = installValidatedUnknown
        self.presentationInterval = presentationInterval.flatMap { $0.isFinite && $0 > 0 ? $0:nil }
        self.refreshPresentation = refreshPresentation
    }
    /// Accepted replacement or significant clock change; never starts a reader.
    func invalidate() { handle(fence.invalidateAndRecompute()) }
    func replace() { if fence.isSuspended { resume() } else { invalidate() } }
    func suspend() { handle(fence.withdraw()); if fence.isSuspended { setStatus(.suspended) } }
    func resume() { handle(fence.resume()) }
    func close() { handle(fence.close()); if fence.isClosed { setStatus(.closed) } }
    private func setStatus(_ value: Status) { status = value; report(value) }

    private func handle(_ directive: HostDeadlineFence.Directive, candidate: Candidate? = nil, missing: Bool = false) {
        switch directive {
        case .clear(let ticket):
            scheduledSourceToken = nil; scheduler.cancel(); clear()
            handle(fence.didClear(ticket))
        case .recompute(let ticket):
            let now = wallNow(), result = recompute(now)
            guard fence.isCurrent(ticket) else { return }
            guard let candidate = result else {
                handle(fence.withdraw()); if fence.isSuspended { setStatus(.staleSource) }; return
            }
            guard sourceIsCurrent(candidate.sourceToken) else {
                handle(fence.withdraw()); if fence.isSuspended { setStatus(.staleSource) }; return
            }
            let plan: HostDeadlineFence.Plan
            switch candidate.deadline {
            case .some(.scheduled(let date, let unknown)): plan = .init(next: date, hasUnknownDeadline: unknown)
            case .some(.unknown), .none: plan = .init(next: nil, hasUnknownDeadline: true)
            case .some(.none): plan = .init(next: nil, hasUnknownDeadline: false)
            }
            handle(fence.didRecompute(ticket, plan: plan, now: now), candidate: candidate, missing: candidate.deadline == nil)
        case .schedule(let ticket, let date, let unknown):
            let wall = wallNow(), clock = elapsed(), delay = date.timeIntervalSince(wall)
            guard wall.timeIntervalSinceReferenceDate.isFinite, clock.isFinite, delay.isFinite, (clock + max(0, delay)).isFinite else {
                handle(fence.withdraw()); if fence.isSuspended { setStatus(.invalidClock) }; return
            }
            // Time can cross the boundary between recompute and scheduling. Never install that stale candidate.
            if delay <= 0 {
                guard !crossingBoundary else { handle(fence.withdraw()); if fence.isSuspended { setStatus(.overdue) }; return }
                crossingBoundary = true; defer { crossingBoundary = false }
                handle(fence.timerFired(ticket, now: wall)); return
            }
            if let candidate { scheduledSourceToken = candidate.sourceToken }
            guard let source = scheduledSourceToken, sourceIsCurrent(source) else {
                handle(fence.withdraw()); if fence.isSuspended { setStatus(.staleSource) }; return
            }
            setStatus(unknown ? .mixedUnknown : .scheduled)
            guard fence.isCurrent(ticket) else { return }
            guard sourceIsCurrent(source) else {
                handle(fence.withdraw()); if fence.isSuspended { setStatus(.staleSource) }; return
            }
            let wakeDelay = presentationInterval.map { min(delay,$0) } ?? delay
            scheduler.arm(at: clock + max(0, wakeDelay)) { [weak self] in
                guard let self, self.fence.isCurrent(ticket) else { return }
                guard self.sourceIsCurrent(source) else {
                    self.handle(self.fence.withdraw()); if self.fence.isSuspended { self.setStatus(.staleSource) }; return
                }
                let now = self.wallNow()
                guard now.timeIntervalSinceReferenceDate.isFinite else {
                    self.handle(self.fence.withdraw()); if self.fence.isSuspended { self.setStatus(.invalidClock) }; return
                }
                if now < date, self.presentationInterval != nil {
                    // This is not a new source admission or a deadline extension.
                    self.refreshPresentation(now)
                    guard self.fence.isCurrent(ticket) else { return }
                    guard self.sourceIsCurrent(source) else { self.handle(self.fence.withdraw()); return }
                    self.handle(.schedule(ticket,date,hasUnknownDeadline:unknown))
                } else { self.handle(self.fence.timerFired(ticket, now: now)) }
            }
            // Unknown/mixed policy is intentionally unresolved: never reinstall here.
            if (!unknown || installValidatedUnknown), let candidate, fence.isCurrent(ticket) {
                guard sourceIsCurrent(source) else {
                    handle(fence.withdraw()); if fence.isSuspended { setStatus(.staleSource) }; return
                }
                install(candidate.value)
            }
        case .authorityRequired(let ticket):
            setStatus(missing ? .missingContract : .unknown)
            if !missing, installValidatedUnknown, let candidate, fence.isCurrent(ticket),
               sourceIsCurrent(candidate.sourceToken) { install(candidate.value) }
        case .noFutureDeadline(let ticket):
            setStatus(.noFutureDeadline)
            // This is an evaluated projection, not an assertion of infinite lifetime.
            if let candidate, fence.isCurrent(ticket), sourceIsCurrent(candidate.sourceToken) { install(candidate.value) }
        case .overdue:
            setStatus(.overdue)
        case .none:
            break
        }
    }
}
