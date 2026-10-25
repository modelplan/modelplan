// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanPrimitives

/// Adapts M0's semantic state machine to ContinuousClock; it owns no timer, view, or navigation stack.
public struct CautionLampModel: Sendable {
    public typealias Condition = ModelPlanPrimitives.CautionCondition
    public typealias Mode = ModelPlanPrimitives.CautionState.Mode
    public typealias Severity = ModelPlanPrimitives.CautionCondition.Severity
    public enum Action: Equatable, Sendable { case openAlerts }

    public struct Presentation: Equatable, Sendable {
        public let mode: Mode
        public let severity: Severity?
        /// Schedule a single validation at this absolute deadline in common run-loop modes.
        public let deadline: ContinuousClock.Instant?
        public let blinkStartedAt: ContinuousClock.Instant?
        public let remainingBlink: Duration
        public var isLit: Bool { severity != nil }
        /// The renderer uses one bounded opacity animation, retaining this phase across hide/show.
        public static let blinkPeriod: Duration = .seconds(1)
    }

    private let origin: ContinuousClock.Instant
    private var state = ModelPlanPrimitives.CautionState()
    public private(set) var reduceMotion: Bool

    public init(now: ContinuousClock.Instant = ContinuousClock().now, reduceMotion: Bool = false) {
        origin = now
        self.reduceMotion = reduceMotion
    }

    public mutating func update(_ conditions: [Condition], now: ContinuousClock.Instant = ContinuousClock().now) {
        state.update(conditions, now: elapsed(now), reduceMotion: reduceMotion)
    }

    public mutating func setReduceMotion(_ enabled: Bool, now: ContinuousClock.Instant = ContinuousClock().now) {
        reduceMotion = enabled
        state.validate(now: elapsed(now), reduceMotion: enabled)
    }

    /// Call before every restored frame, and on menu/tracking exit or deadline delivery.
    /// An old callback only validates the current deadline; it cannot end a newer episode early.
    public mutating func presentation(now: ContinuousClock.Instant = ContinuousClock().now) -> Presentation {
        state.validate(now: elapsed(now), reduceMotion: reduceMotion)
        let blinking = state.mode == .blinking
        let deadline = blinking ? state.deadline.map { origin.advanced(by: .seconds($0)) } : nil
        let started = blinking ? state.blinkStart.map { origin.advanced(by: .seconds($0)) } : nil
        return Presentation(mode: state.mode, severity: state.severity, deadline: deadline,
                            blinkStartedAt: started, remainingBlink: deadline.map { now.duration(to: $0) } ?? .zero)
    }

    /// Navigation consumes the action through the existing sourced-view/return route.
    @discardableResult
    public mutating func press(now: ContinuousClock.Instant = ContinuousClock().now) -> Action? {
        state.validate(now: elapsed(now), reduceMotion: reduceMotion)
        guard state.severity != nil else { return nil }
        state.press()
        return .openAlerts
    }

    private func elapsed(_ now: ContinuousClock.Instant) -> Double {
        let duration = origin.duration(to: now).components
        return Double(duration.seconds) + Double(duration.attoseconds) / 1e18
    }
}
