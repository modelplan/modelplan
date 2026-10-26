// SPDX-License-Identifier: MIT
import Foundation

public enum FirstRunAction: Equatable, Sendable { case done, seeWhatsHere }
public enum FirstRunHost: Equatable, Sendable { case popup, standalone }
public enum FirstRunEffect: Equatable, Sendable {
    case closeFirstRunPopup, revealDock, returnToSettings, openCockpit, latchOptionHelp
}
public struct OptionHelpState: Equatable, Sendable {
    public private(set) var optionHeld = false, latched = false
    public init() {}
    public var visible: Bool { optionHeld || latched }
    public mutating func optionChanged(_ held: Bool) { optionHeld = held }
    public mutating func latchFromFirstRun() { latched = true }
    /// Esc and outside/click handlers share this release. No cockpit/card state is owned or changed.
    public mutating func release() { optionHeld = false; latched = false }
}
public struct FirstRunPage: Sendable {
    public let privacy = SettingsText("Nothing on this Mac is uploaded; only public data is downloaded", "不上传任何本机数据，只下载公开数据")
    public let loginSubtitle = SettingsText("You can turn this off in Settings", "可随时在设置里关闭")
    public let done = SettingsText("Done", "完成"), seeWhatsHere = SettingsText("See what's here", "看看都有什么")
    public let subscriptions: [SettingsSubscription]
    public let readers: [ReaderSetting]
    public let login: LoginSetting
    public init(preferences: SettingsPreferences, context: SettingsPageContext) throws {
        guard Set(context.subscriptions.map(\.id)).count == context.subscriptions.count,
              context.subscriptions.allSatisfy({ !$0.id.isEmpty }) else { throw SettingsError.invalidCatalogue }
        subscriptions = context.subscriptions
        readers = ReaderSetting.project(consent: preferences.readerConsent, observations: context.readerObservations)
        login = .init(preferences: preferences, capabilities: context.capabilities)
    }
}
public enum LoginRequestReason: Equatable, Sendable { case explicitUserChoice, firstRunCompletion, restoration, systemObservation }
public enum LoginServicePolicy {
    /// No automatic repair of an externally disabled item, and no pretend approval success.
    public static func request(choice: Bool, observed: LoginServiceState, reason: LoginRequestReason) -> SettingsActionRequest? {
        guard reason == .explicitUserChoice || reason == .firstRunCompletion else { return nil }
        switch (observed, choice) {
        case (.notRegistered, true): return .setLoginEnabled(true)
        case (.enabled, false), (.requiresApproval, false): return .setLoginEnabled(false)
        default: return nil
        }
    }
}
public struct LoginChoiceCommit: Sendable {
    public let snapshot: SettingsSnapshot
    public let observedState: LoginServiceState
    public let request: SettingsActionRequest?
    /// Consumers must check this revision again before acting on an async/stale request.
    public var revision: UInt64 { snapshot.revision }
}
public struct FirstRunCommit: Sendable {
    public let snapshot: SettingsSnapshot
    public let effects: [FirstRunEffect]
    public let login: LoginChoiceCommit
}
public extension SettingsStore {
    func commitOpenAtLogin(_ enabled: Bool, capabilities: SettingsCapabilities, expectedRevision: UInt64) throws -> LoginChoiceCommit {
        let saved = try update(expectedRevision: expectedRevision) { $0.openAtLogin = enabled }
        return .init(snapshot: saved, observedState: capabilities.login,
                     request: LoginServicePolicy.request(choice: enabled, observed: capabilities.login, reason: .explicitUserChoice))
    }
    func completeFirstRun(options: OnboardingOptions, action: FirstRunAction, host: FirstRunHost,
                          capabilities: SettingsCapabilities, expectedRevision: UInt64) throws -> FirstRunCommit {
        guard onboardingDefinition == .task65 else { throw SettingsError.invalidPreference }
        let saved = try update(expectedRevision: expectedRevision) { p in
            options.apply(to: &p)
            p.onboarding = OnboardingState(definition: .task65)
            p.onboarding.next(in: .task65)
        }
        let effects: [FirstRunEffect]
        if action == .seeWhatsHere { effects = (host == .popup ? [.closeFirstRunPopup] : []) + [.openCockpit,.latchOptionHelp] }
        else { effects = host == .popup ? [.closeFirstRunPopup,.revealDock] : [.returnToSettings] }
        return .init(snapshot: saved, effects: effects, login: .init(snapshot: saved, observedState: capabilities.login,
            request: LoginServicePolicy.request(choice: saved.preferences.openAtLogin, observed: capabilities.login, reason: .firstRunCompletion)))
    }
}

public extension SettingsStore {
    /// After success, the app resets the one shared in-memory scheduler's budgets/dwell as well.
    func resetFirstUseHints(expectedRevision: UInt64) throws -> SettingsSnapshot {
        try update(expectedRevision: expectedRevision) { $0.helpHints = .init() }
    }
}
