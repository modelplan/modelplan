// SPDX-License-Identifier: MIT
import Foundation

public enum SettingsB22Edit: Sendable {
    case notificationConsent(Bool), notification(NotificationKind, Bool), projectNames(Bool)
    public static let keys: Set<SettingKey> = [.notificationConsent,.forecast,.reset,.official,.expiring,.stale,.projectNames]
    public init(key: SettingKey, value: String) throws {
        guard let enabled = Bool(value) else { throw SettingsError.invalidPreference }
        if key == .notificationConsent { self = .notificationConsent(enabled) }
        else if key == .projectNames { self = .projectNames(enabled) }
        else if let kind = NotificationKind(rawValue: key.rawValue) { self = .notification(kind, enabled) }
        else { throw SettingsError.invalidPreference }
    }
    func apply(to p: inout SettingsPreferences) throws {
        switch self {
        case .notificationConsent(let v): p.notifications.optedIn = v
        case .notification(let kind, let v):
            if v { p.notifications.kinds.insert(kind) } else { p.notifications.kinds.remove(kind) }
        case .projectNames(let v): p.showProjectNames = v
        }
        try p.validate()
    }
}
public enum SettingsPublicLink: String, CaseIterable, Sendable {
    case website, methodology, privacy, repository, feedback
    public var url: URL {
        switch self {
        case .website: return URL(string: "https://modelplan.ai")!
        case .methodology: return URL(string: "https://modelplan.ai/methodology")!
        case .privacy: return URL(string: "https://modelplan.ai/privacy")!
        case .repository: return URL(string: "https://github.com/modelplan/modelplan")!
        case .feedback: return SettingsAbout.feedbackURL
        }
    }
}
public enum SettingsUpdateState: String, Sendable { case unavailable, notChecked, current, available, failed }
public enum SettingsB22Action: Sendable {
    case clearAppCache, openLink(SettingsPublicLink), checkForUpdates, previewFirstRun
}

/// One app-owned instance wraps the existing policy. It never requests permission or posts an OS notice.
/// The host serializes admission/send/acceptance and records only actual accepted deliveries.
@MainActor public final class SettingsNotificationConsumer {
    public private(set) var policy: NotificationPolicy
    private var lastConsentRevision: UInt64?
    public init(policy: NotificationPolicy = .init()) { self.policy = policy }
    public func committedConsent(_ request: SettingsHostRequest, snapshot: SettingsSnapshot) -> NotificationPermissionEffect {
        guard request.revision == snapshot.revision,
              lastConsentRevision.map({ request.revision > $0 }) ?? true,
              case .notificationConsentChanged(let previous, let enabled) = request.intent,
              enabled == snapshot.preferences.notifications.optedIn else { return .none }
        lastConsentRevision = request.revision
        var before = snapshot.preferences; before.notifications.optedIn = previous
        return policy.userSetOptIn(enabled, preferences: &before)
    }
    public func observeAuthorization(_ result: NotificationAuthorization) { policy.observeAuthorization(result) }
    public func receivedAuthorization(_ result: NotificationAuthorization, request: UUID) { policy.receivedAuthorization(result, request: request) }
    public func delivery(for notice: SettingsNotice, snapshot: SettingsSnapshot, now: Date) -> NotificationDelivery? {
        policy.delivery(for: notice, preferences: snapshot.preferences, now: now)
    }
    public func recordAccepted(_ notice: SettingsNotice, snapshot: SettingsSnapshot, now: Date) {
        policy.recordDelivered(notice, preferences: snapshot.preferences, now: now)
    }
}
