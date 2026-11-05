// SPDX-License-Identifier: MIT
import Foundation

/// Pure ordering proposal. This type holds no row data, clock, timer, UI or owner policy.
struct HostDeadlineFence {
    struct Ticket: Equatable, Sendable { fileprivate let generation: UInt64 }
    /// Separate fields deliberately permit a known deadline and another unknown one.
    struct Plan: Equatable, Sendable {
        let next: Date?
        let hasUnknownDeadline: Bool
    }
    enum Directive: Equatable, Sendable {
        /// Caller must cancel the prior timer and synchronously scrub cached content and AX.
        case clear(Ticket)
        /// Issued only after the caller acknowledges the corresponding synchronous clear.
        case recompute(Ticket)
        case schedule(Ticket, Date, hasUnknownDeadline: Bool)
        /// No retained-value policy can be inferred from absent or invalid producer timing.
        case authorityRequired(Ticket)
        /// No future timer was supplied; this does not mean data is valid forever.
        case noFutureDeadline(Ticket)
        /// A producer returned a deadline already reached; do not present it or spin.
        case overdue(Ticket)
        case none
    }
    private enum Phase {
        case idle, clearing(Ticket, recompute: Bool), recomputing(Ticket)
        case waiting(Ticket, Date, hasUnknownDeadline: Bool), blocked(Ticket), suspended, closing(Ticket), closed
    }
    private var generation: UInt64 = 0
    private var phase: Phase = .idle
    private mutating func next() -> Ticket { generation &+= 1; return Ticket(generation: generation) }
    var isSuspended: Bool { if case .suspended = phase { return true }; return false }
    var isClosed: Bool { if case .closed = phase { return true }; return false }
    func isCurrent(_ ticket: Ticket) -> Bool {
        guard ticket.generation == generation else { return false }
        switch phase { case .suspended, .closing, .closed: return false; default: return true }
    }

    /// Content replacement, accepted-event change, resume or clock correction.
    mutating func invalidateAndRecompute() -> Directive {
        if case .closed = phase { return .none }
        if case .closing = phase { return .none }
        if case .suspended = phase { return .none }
        let ticket = next(); phase = .clearing(ticket, recompute: true); return .clear(ticket)
    }
    /// Only the lifecycle owner can reopen after a completed pause clear.
    mutating func resume() -> Directive {
        guard case .suspended = phase else { return .none }
        phase = .idle; return invalidateAndRecompute()
    }
    /// Withdrawal or lifecycle pause clears but must not recreate the surface.
    mutating func withdraw() -> Directive {
        if case .closed = phase { return .none }
        if case .closing = phase { return .none }
        let ticket = next(); phase = .clearing(ticket, recompute: false); return .clear(ticket)
    }
    /// Once closing starts, neither resume nor old callbacks can reopen this fence.
    mutating func close() -> Directive {
        if case .closed = phase { return .none }
        if case .closing = phase { return .none }
        let ticket = next(); phase = .closing(ticket); return .clear(ticket)
    }
    mutating func didClear(_ ticket: Ticket) -> Directive {
        switch phase {
        case .clearing(let current, let recompute) where current == ticket:
            if recompute { phase = .recomputing(ticket); return .recompute(ticket) }
            phase = .suspended; return .none
        case .closing(let current) where current == ticket:
            phase = .closed; return .none
        default: return .none
        }
    }
    /// Called with the same accepted-generation producer result after recomputation.
    mutating func didRecompute(_ ticket: Ticket, plan: Plan, now: Date) -> Directive {
        guard case .recomputing(let current) = phase, current == ticket else { return .none }
        guard now.timeIntervalSinceReferenceDate.isFinite else {
            phase = .blocked(ticket); return .authorityRequired(ticket)
        }
        guard let instant = plan.next else {
            phase = .blocked(ticket)
            return plan.hasUnknownDeadline ? .authorityRequired(ticket) : .noFutureDeadline(ticket)
        }
        guard instant.timeIntervalSinceReferenceDate.isFinite else {
            phase = .blocked(ticket); return .authorityRequired(ticket)
        }
        // The producer contract supplies future times only; reject a violated contract without looping.
        guard instant > now else { phase = .blocked(ticket); return .overdue(ticket) }
        phase = .waiting(ticket, instant, hasUnknownDeadline: plan.hasUnknownDeadline)
        return .schedule(ticket, instant, hasUnknownDeadline: plan.hasUnknownDeadline)
    }
    /// Early delivery is rearmed; at or after expiry, scrub before any recomputation.
    mutating func timerFired(_ ticket: Ticket, now: Date) -> Directive {
        guard case .waiting(let current, let deadline, let hasUnknown) = phase, current == ticket else { return .none }
        guard now.timeIntervalSinceReferenceDate.isFinite else {
            let nextTicket = next(); phase = .clearing(nextTicket, recompute: false); return .clear(nextTicket)
        }
        if now < deadline { return .schedule(ticket, deadline, hasUnknownDeadline: hasUnknown) }
        let nextTicket = next(); phase = .clearing(nextTicket, recompute: true); return .clear(nextTicket)
    }
}
