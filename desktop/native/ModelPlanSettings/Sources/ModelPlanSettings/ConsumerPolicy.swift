// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanDock

public struct SettingsEnvironment: Sendable {
    public var darkAppearance = false
    public var reduceMotion = false
    public var reduceTransparency = false
    public var fullscreen = false
    /// False until the native entrance has independently passed its gate; OS support alone is insufficient.
    public var entranceAccepted = false
    public var macOSMajor = 14
    public init() {}
}
public struct EffectiveSettings: Equatable, Sendable {
    public let darkAppearance: Bool, reduceMotion: Bool, reduceTransparency: Bool
    public let dockAllowed: Bool, autoHide: Bool, showPercentages: Bool, sliverAlert: Bool
    public let showDock: Bool, allowedOverFullscreen: Bool, followActiveDisplay: Bool
    public let revealSeconds: Double, magnification: HoverMagnification, size: SettingsSize
    public let menuDisplay: MenuDisplay, language: SettingsLanguage, showProjectNames: Bool
    public let opening: OpeningPreference, ignitionSeconds: Double?
    public let redBelow: Int
    public init(_ p: SettingsPreferences, environment e: SettingsEnvironment) {
        darkAppearance = p.theme == .night || (p.theme == .system && e.darkAppearance)
        reduceMotion = p.motion == .on || (p.motion == .system && e.reduceMotion)
        reduceTransparency = p.transparency == .on || (p.transparency == .system && e.reduceTransparency)
        showDock = p.showDock; allowedOverFullscreen = !e.fullscreen || p.showOverFullscreen
        dockAllowed = showDock && allowedOverFullscreen
        followActiveDisplay = p.followActiveDisplay
        autoHide = p.autoHide; revealSeconds = Double(p.revealMilliseconds) / 1000
        showPercentages = p.showPercentages; sliverAlert = p.sliverAlert
        size = p.size; magnification = reduceMotion ? .none : p.magnification
        menuDisplay = p.menuDisplay; language = p.language; showProjectNames = p.showProjectNames; redBelow = p.redBelow
        opening = p.opening == .quick || reduceMotion || e.macOSMajor < 15 || !e.entranceAccepted ? .quick : .hold
        ignitionSeconds = opening == .hold ? 0.2 + 3 * Double(p.beatMilliseconds) / 1000 : nil
    }
    public var visibilityPolicy: DockVisibilityPolicy {
        var policy = DockVisibilityPolicy(); policy.revealDwell = revealSeconds; return policy
    }
    public func applying(to input: DockPresence) -> DockPresence {
        var result = input
        result.enabled = showDock; result.autoHide = autoHide
        result.allowedOverFullscreen = allowedOverFullscreen
        return result
    }
}

public extension SettingsPreferences {
    /// One shared ordering/visibility source is used by Settings, the dock and the cockpit.
    func presentedSubscriptionIDs(_ catalogue: [String], includingHidden: Bool = false) throws -> [String] {
        try subscriptions.orderedIDs(in: catalogue, visibleOnly: !includingHidden)
    }
    func applying(to input: DockInstrumentInput) -> DockInstrumentInput {
        var result = input
        if let value = subscriptionSettings[input.id] { result.alias = value.alias.nilIfEmpty }
        result.showUsedPercent = percentageMode == .used
        let pin = subscriptionSettings[input.id]?.percentagePin ?? .auto
        // A pin selects a general window, never a model/feature-specific extra quota.
        switch pin {
        case .auto: result.selectedWindowID = nil
        case .fiveHour: result.selectedWindowID = input.windows.first { $0.period == .fiveHour }?.id
        case .week: result.selectedWindowID = input.windows.first { $0.period == .week }?.id
        }
        return result
    }
}
private extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }

public enum ShortcutAction: String, Sendable { case openCockpit, toggleDock }
public enum ShortcutRegistration: Equatable, Sendable { case notRequested, registered, conflict, denied, unavailable }
public struct ShortcutPolicy: Sendable {
    public var openRegistration: ShortcutRegistration = .notRequested
    public var dockRegistration: ShortcutRegistration = .notRequested
    public init() {}
    /// Local matching never depends on global registration. IME/editor/repeat events are ignored.
    public func action(for chord: ShortcutChord, preferences: SettingsPreferences, global: Bool,
                       editingText: Bool = false, composing: Bool = false, repeated: Bool = false) -> ShortcutAction? {
        guard chord.isValid, !editingText, !composing, !repeated else { return nil }
        if chord == preferences.openShortcut, !global || openRegistration == .registered { return .openCockpit }
        if chord == preferences.dockShortcut, !global || dockRegistration == .registered { return .toggleDock }
        return nil
    }
}

/// Composition is transient, never sent to storage on every keystroke or language/appearance change.
public struct AliasDraft: Equatable, Sendable {
    public let subscriptionID: String
    public private(set) var text: String
    public private(set) var composing = false
    public init(subscriptionID: String, committed: String) { self.subscriptionID = subscriptionID; text = committed }
    public mutating func input(_ text: String, composing: Bool) { self.text = text; self.composing = composing }
    public func commit(to preferences: inout SettingsPreferences) throws {
        guard !composing else { throw SettingsError.invalidPreference }
        var candidate = preferences
        var value = candidate.subscriptionSettings[subscriptionID] ?? .init()
        value.alias = text.trimmingCharacters(in: .whitespacesAndNewlines)
        candidate.subscriptionSettings[subscriptionID] = value
        try candidate.validate(); preferences = candidate
    }
}

public enum LoginServiceState: String, Sendable { case notRegistered, enabled, requiresApproval, unavailable }
/// Saved user intent and current system observation are independent facts.
public struct LoginSetting: Equatable, Sendable {
    public static let title = SettingsText("Open at login", "登录时自动打开")
    public let requestedEnabled: Bool
    public let observedState: LoginServiceState
    public init(preferences: SettingsPreferences, capabilities: SettingsCapabilities) {
        self.init(requestedEnabled: preferences.openAtLogin, observedState: capabilities.login)
    }
    init(requestedEnabled: Bool, observedState: LoginServiceState) {
        self.requestedEnabled = requestedEnabled; self.observedState = observedState
    }
}
public enum SettingsActionRequest: Equatable, Sendable {
    case setLoginEnabled(Bool), clearAppCache, resetHelpHints
}
public struct SettingsCapabilities: Sendable {
    public var login: LoginServiceState = .notRegistered
    public var appCacheClearAvailable = false
    public init() {}
    /// Returns an intent only. The caller must perform it and refresh the observed service state.
    public func loginRequest(enabled: Bool) -> SettingsActionRequest? {
        guard login != .unavailable else { return nil }
        return .setLoginEnabled(enabled)
    }
    public var clearRequest: SettingsActionRequest? { appCacheClearAvailable ? .clearAppCache : nil }
    // No capture-hiding, CLI clear/retention or reader-enabling command exists in this contract.
}
