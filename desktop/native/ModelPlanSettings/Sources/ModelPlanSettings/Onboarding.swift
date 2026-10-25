// SPDX-License-Identifier: MIT
import Foundation

/// Stable content ID, independent of position or number of steps.
public struct OnboardingStep: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let welcome = Self(rawValue: "welcome")
    public static let detectedSubscriptions = Self(rawValue: "detectedSubscriptions")
    public static let dockLocation = Self(rawValue: "dockLocation")
    /// Compatibility with the initial draft only; navigation uses the injected definition.
    public static var allCases: [Self] { OnboardingDefinition.provisional.steps.map(\.id) }
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let legacy = try? c.decode(Int.self) {
            rawValue = [1: Self.welcome, 2: .detectedSubscriptions, 3: .dockLocation][legacy]?.rawValue ?? "invalid-legacy-\(legacy)"
        } else { rawValue = try c.decode(String.self) }
    }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public struct OnboardingStepCapabilities: OptionSet, Equatable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let trialDemo = Self(rawValue: 1)
    public static let dockLesson = Self(rawValue: 2)
}
public struct OnboardingStepDefinition: Equatable, Sendable {
    public let id: OnboardingStep
    public let title: SettingsText
    public let capabilities: OnboardingStepCapabilities
    public init(id: OnboardingStep, title: SettingsText, capabilities: OnboardingStepCapabilities = []) {
        self.id = id; self.title = title; self.capabilities = capabilities
    }
}
public struct OnboardingDefinition: Equatable, Sendable {
    public let steps: [OnboardingStepDefinition]
    // Stable across locales/titles, changes when order, content identity or lesson capabilities change.
    fileprivate var signature: [String] { steps.map { "\($0.id.rawValue.utf8.count):\($0.id.rawValue):\($0.capabilities.rawValue)" } }
    public init(steps: [OnboardingStepDefinition]) throws {
        guard !steps.isEmpty, steps.count <= 32, Set(steps.map(\.id)).count == steps.count,
              steps.allSatisfy({ validSettingsIdentifier($0.id.rawValue) && !$0.title.english.isEmpty && !$0.title.chinese.isEmpty &&
                  $0.capabilities.subtracting([.trialDemo, .dockLesson]).isEmpty }) else { throw SettingsError.invalidCatalogue }
        self.steps = steps
    }
    private init(provisional steps: [OnboardingStepDefinition]) { self.steps = steps }
    /// Provisional existing content, not the final first-run design. One table supplies all order/end rules.
    public static let provisional = OnboardingDefinition(provisional: [
        .init(id: .welcome, title: .init("Welcome and privacy", "欢迎与隐私"), capabilities: .trialDemo),
        .init(id: .detectedSubscriptions, title: .init("Detected subscriptions", "已检测到的订阅")),
        .init(id: .dockLocation, title: .init("Find the dock", "挂件位置"), capabilities: .dockLesson),
    ])
}
public enum TutorialResult: String, Codable, Sendable { case quick, hold }
public struct OnboardingState: Codable, Equatable, Sendable {
    public private(set) var step: OnboardingStep
    public private(set) var completed = false
    public private(set) var lesson: TutorialResult?
    public private(set) var trialDemonstrated = false
    private var definitionSignature: [String]?
    public init(definition: OnboardingDefinition = .provisional) {
        step = definition.steps[0].id; definitionSignature = definition.signature
    }
    public var isStructurallyValid: Bool { validSettingsIdentifier(step.rawValue) }
    public var isValid: Bool { isValid(in: .provisional) }
    public func isValid(in definition: OnboardingDefinition) -> Bool {
        (definitionSignature == definition.signature || (definitionSignature == nil && definition.signature == OnboardingDefinition.provisional.signature)) &&
            definition.steps.contains { $0.id == step } && (!completed || step == definition.steps.last?.id)
    }
    private enum CodingKeys: CodingKey { case step, completed, lesson, trialDemonstrated, definitionSignature }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Malformed/obsolete progress recovers at the definition boundary; never changes consent/preferences.
        step = (try? c.decode(OnboardingStep.self, forKey: .step)) ?? .init(rawValue: "invalid-progress")
        completed = (try? c.decode(Bool.self, forKey: .completed)) ?? false
        lesson = try? c.decode(TutorialResult.self, forKey: .lesson)
        trialDemonstrated = (try? c.decode(Bool.self, forKey: .trialDemonstrated)) ?? false
        definitionSignature = c.contains(.definitionSignature) ? ((try? c.decode([String].self, forKey: .definitionSignature)) ?? []) : nil
    }
    public mutating func reconcile(in definition: OnboardingDefinition = .provisional) {
        guard isStructurallyValid, isValid(in: definition) else { self = .init(definition: definition); return }
        definitionSignature = definition.signature
        if !definition.steps.contains(where: { $0.capabilities.contains(.dockLesson) }) { lesson = nil }
        if !definition.steps.contains(where: { $0.capabilities.contains(.trialDemo) }) { trialDemonstrated = false }
    }
    public mutating func next(in definition: OnboardingDefinition = .provisional) {
        reconcile(in: definition)
        guard !completed, let index = definition.steps.firstIndex(where: { $0.id == step }) else { return }
        if index + 1 < definition.steps.count { step = definition.steps[index + 1].id } else { completed = true }
    }
    public mutating func back(in definition: OnboardingDefinition = .provisional) {
        reconcile(in: definition)
        guard !completed, let index = definition.steps.firstIndex(where: { $0.id == step }), index > 0 else { return }
        step = definition.steps[index - 1].id
    }
    public mutating func replay(in definition: OnboardingDefinition = .provisional) { self = .init(definition: definition) }
    public mutating func demonstrateTrial(in definition: OnboardingDefinition = .provisional) {
        reconcile(in: definition)
        if !completed && definition.steps.first(where: { $0.id == step })?.capabilities.contains(.trialDemo) == true { trialDemonstrated.toggle() }
    }
    public mutating func recordLesson(_ result: TutorialResult, holdAvailable: Bool, in definition: OnboardingDefinition = .provisional) {
        reconcile(in: definition)
        guard !completed, definition.steps.first(where: { $0.id == step })?.capabilities.contains(.dockLesson) == true,
              result == .quick || holdAvailable else { return }
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
