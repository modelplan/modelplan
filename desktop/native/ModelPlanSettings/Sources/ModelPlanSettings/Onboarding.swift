// SPDX-License-Identifier: MIT
import Foundation

public enum OnboardingStep: Int, Codable, CaseIterable, Sendable { case welcome = 1, detectedSubscriptions, dockLocation }
public enum TutorialResult: String, Codable, Sendable { case quick, hold }
public struct OnboardingState: Codable, Equatable, Sendable {
    public private(set) var step: OnboardingStep = .welcome
    public private(set) var completed = false
    public private(set) var lesson: TutorialResult?
    public private(set) var trialDemonstrated = false
    public init() {}
    public var isValid: Bool { !completed || step == .dockLocation }
    public mutating func next() {
        guard !completed else { return }
        switch step {
        case .welcome: step = .detectedSubscriptions
        case .detectedSubscriptions: step = .dockLocation
        case .dockLocation: completed = true
        }
    }
    public mutating func back() {
        guard !completed else { return }
        switch step { case .welcome: break; case .detectedSubscriptions: step = .welcome; case .dockLocation: step = .detectedSubscriptions }
    }
    public mutating func replay() { self = .init() }
    public mutating func demonstrateTrial() { if step == .welcome && !completed { trialDemonstrated.toggle() } }
    public mutating func recordLesson(_ result: TutorialResult, holdAvailable: Bool) {
        guard step == .dockLocation, !completed, result == .quick || holdAvailable else { return }
        lesson = result
    }
}

/// Pure lesson reducer. No timers, animations or actual cockpit-opening effects.
/// Browser lesson timing (800 ms) is intentionally independent of product ignition (default 950 ms).
public struct TutorialGesture: Sendable {
    public static let lessonSeconds: Double = 0.8
    private var beganAt: Double?
    private var lastTime: Double?
    public var holdAvailable: Bool
    public init(holdAvailable: Bool = false) { self.holdAvailable = holdAvailable }
    public mutating func press(at time: Double, repeated: Bool = false) -> Bool {
        guard time.isFinite, lastTime.map({ time >= $0 }) ?? true, !repeated, beganAt == nil else { return false }
        beganAt = time; lastTime = time; return true
    }
    public mutating func advance(at time: Double) -> TutorialResult? {
        guard accept(time), holdAvailable, let beganAt, time >= beganAt + Self.lessonSeconds else { return nil }
        self.beganAt = nil; return .hold
    }
    public mutating func release(at time: Double) -> TutorialResult? {
        guard accept(time), let beganAt else { return nil }
        self.beganAt = nil
        return holdAvailable && time >= beganAt + Self.lessonSeconds ? .hold : .quick
    }
    public mutating func cancel() { beganAt = nil }
    private mutating func accept(_ time: Double) -> Bool {
        guard time.isFinite, lastTime.map({ time >= $0 }) ?? true else { return false }
        lastTime = time; return true
    }
}
