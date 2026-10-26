// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanInstruments
import ModelPlanSettings

/// The app's existing, single arbiter receives these calls. Admission is not display or persistence.
@MainActor public protocol InstrumentTrialHintReceiving: AnyObject {
    @discardableResult func beginTrialRest(on target: TrialHintTarget, at now: TimeInterval) -> Bool
    func cancelTrialRest(on target: TrialHintTarget, reason: TrialHintCancellation)
}

/// View-local geometry and pointer must be resolved again by the host, not cached for a deadline.
public struct InstrumentHintSourceSnapshot: Equatable, Sendable {
    public let anchor: FaderRestAnchor
    public let pointer: CGPoint
    public init(anchor: FaderRestAnchor, pointer: CGPoint) { self.anchor = anchor; self.pointer = pointer }
}

/// An ephemeral view lifetime, never stored in preferences. Reusing a source ID retires its old lease.
public struct InstrumentHintSourceLease: Hashable, Sendable {
    fileprivate let sourceID: UUID, generation: UUID
}

/// Maps real view events to one app-owned trial arbiter without owning policy, timers, overlays or files.
/// Bind each view's onHintInput with its lease; the resolver should capture that view weakly.
@MainActor public final class InstrumentHintSourceRouter {
    private struct Binding {
        let lease: InstrumentHintSourceLease
        let resolve: () -> InstrumentHintSourceSnapshot?
    }
    private struct Rest {
        let lease: InstrumentHintSourceLease
        let snapshot: InstrumentHintSourceSnapshot
        let target: TrialHintTarget
    }
    private weak var receiver: (any InstrumentTrialHintReceiving)?
    private let uptime: () -> TimeInterval
    private var bindings: [UUID: Binding] = [:]
    private var rest: Rest?
    private var operationGeneration: UInt64 = 0
    public var pendingTarget: TrialHintTarget? { rest?.target }

    public init(receiver: any InstrumentTrialHintReceiving,
                uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.receiver = receiver; self.uptime = uptime
    }
    public func register(sourceID: UUID = UUID(),
                         resolve: @escaping () -> InstrumentHintSourceSnapshot?) -> InstrumentHintSourceLease {
        operationGeneration &+= 1
        let lease = InstrumentHintSourceLease(sourceID: sourceID, generation: UUID())
        // Install first: a cancellation callout may synchronously register a newer replacement.
        bindings[sourceID] = Binding(lease: lease, resolve: resolve)
        if rest?.lease.sourceID == sourceID { cancelCurrent(reason: .targetRemoval) }
        return lease
    }
    public func remove(_ lease: InstrumentHintSourceLease) {
        guard isCurrent(lease) else { return }
        operationGeneration &+= 1
        bindings.removeValue(forKey: lease.sourceID)
        if rest?.lease == lease { cancelCurrent(reason: .targetRemoval) }
    }
    public func receive(_ input: InstrumentHintInput, from lease: InstrumentHintSourceLease) {
        guard isCurrent(lease), receiver != nil else { return }
        let eventTime: Double
        switch input {
        case .faderRestCandidate(_, _, let at), .cancelFaderRest(_, let at): eventTime = at
        }
        let now = uptime()
        guard now.isFinite, now >= 0, eventTime.isFinite, eventTime >= 0, eventTime <= now else { return }
        operationGeneration &+= 1
        let operation = operationGeneration
        switch input {
        case .faderRestCandidate(let anchor, let pointer, _):
            let resolved = bindings[lease.sourceID]?.resolve()
            guard operationGeneration == operation, isCurrent(lease) else { return }
            guard let state = resolved, valid(state),
                  state.anchor == anchor, state.pointer == pointer else {
                if rest?.lease == lease { cancelCurrent(reason: .targetRemoval) }
                return
            }
            if let rest, rest.lease == lease, rest.snapshot == state { return }
            if rest != nil { cancelCurrent(reason: .pointerMovement) }
            // A receiver callout can have created a newer rest or replaced this source.
            guard operationGeneration == operation, isCurrent(lease), rest == nil, let receiver else { return }
            let current = bindings[lease.sourceID]?.resolve()
            guard operationGeneration == operation, isCurrent(lease), rest == nil, current == state else { return }
            let target = TrialHintTarget(id: UUID().uuidString)
            rest = Rest(lease: lease, snapshot: state, target: target)
            let accepted = receiver.beginTrialRest(on: target, at: now)
            if rest?.target == target, !accepted { rest = nil }
        case .cancelFaderRest(let reason, _):
            switch reason {
            case .removal, .teardown: remove(lease)
            case .pointerDown, .keyboard, .focusLoss:
                // Real input from any current live surface cancels pending rest globally.
                cancelCurrent(reason: cancellation(reason))
            case .movement, .leave, .layoutChange:
                if rest?.lease == lease { cancelCurrent(reason: cancellation(reason)) }
            }
        }
    }

    /// Call from the sole app deadline before offer/placement. A changed/removed anchor cancels
    /// only the matching pending rest; the shared arbiter alone decides whether an offer can show.
    public func validatePendingRest() -> InstrumentHintSourceSnapshot? {
        guard let pending = rest else { return nil }
        let operation = operationGeneration
        let state = bindings[pending.lease.sourceID]?.resolve()
        guard operationGeneration == operation, rest?.target == pending.target, isCurrent(pending.lease) else { return nil }
        guard let state, valid(state), state == pending.snapshot else {
            cancelCurrent(reason: .targetRemoval); return nil
        }
        return state
    }
    /// Only after the shared arbiter confirms a real placed/visible offer. No seen flag is written here.
    public func didConfirmShown(_ target: TrialHintTarget) {
        if rest?.target == target { operationGeneration &+= 1; rest = nil }
    }
    private func isCurrent(_ lease: InstrumentHintSourceLease) -> Bool {
        bindings[lease.sourceID]?.lease == lease
    }
    private func cancelCurrent(reason: TrialHintCancellation) {
        guard let pending = rest else { return }
        rest = nil // Clear before callout so reentrant input owns its own new rest.
        receiver?.cancelTrialRest(on: pending.target, reason: reason)
    }
    private func valid(_ state: InstrumentHintSourceSnapshot) -> Bool {
        let r = state.anchor.travel, p = state.pointer
        return !state.anchor.modelID.isEmpty && !state.anchor.regionID.isEmpty
            && r.origin.x.isFinite && r.origin.y.isFinite && r.width.isFinite && r.height.isFinite
            && r.width > 0 && r.height > 0 && p.x.isFinite && p.y.isFinite && r.contains(p)
    }
    private func cancellation(_ reason: InstrumentHintCancellation) -> TrialHintCancellation {
        switch reason {
        case .movement: return .pointerMovement
        case .leave: return .pointerLeave
        case .pointerDown: return .pointerDown
        case .keyboard: return .keyInput
        case .focusLoss: return .focusLoss
        case .removal, .layoutChange, .teardown: return .targetRemoval
        }
    }
}
