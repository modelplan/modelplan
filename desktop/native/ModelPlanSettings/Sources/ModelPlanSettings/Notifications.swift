// SPDX-License-Identifier: MIT
import Foundation

public enum NotificationAuthorization: String, Sendable { case notDetermined, authorized, provisional, denied, unavailable }
public enum NotificationPermissionEffect: Equatable, Sendable { case none, requestAuthorization(UUID) }
public struct SettingsNotice: Sendable {
    public let kind: NotificationKind
    /// Stable semantic episode, not the snapshot revision, receipt time or notification body.
    public let subscriptionID: String
    public let episodeID: String
    public let beganAt: Date
    public let expiresAt: Date
    public let projectName: String?
    public let restored: Bool
    public init(kind: NotificationKind, subscriptionID: String, episodeID: String, beganAt: Date,
                expiresAt: Date, projectName: String? = nil, restored: Bool = false) {
        self.kind = kind; self.subscriptionID = subscriptionID; self.episodeID = episodeID
        self.beganAt = beganAt; self.expiresAt = expiresAt; self.projectName = projectName; self.restored = restored
    }
}
public struct NotificationDelivery: Equatable, Sendable {
    public let kind: NotificationKind
    public let projectName: String?
}
private struct EpisodeKey: Codable, Hashable, Sendable {
    let kind: NotificationKind
    let subscriptionID: String
    let episodeID: String
}
/// Persist separately as app cache if restart deduplication is needed. Contains opaque IDs/deadlines,
/// never project names/bodies. Pass the restored ledger to the policy before admitting live events.
public struct NotificationLedger: Codable, Equatable, Sendable {
    fileprivate struct Entry: Codable, Equatable, Sendable { let key: EpisodeKey; let expiresAt: Date }
    fileprivate var entries: [Entry] = []
    public init() {}
    public var count: Int { entries.count }
}

/// Policy only. The adapter sends a returned delivery, then records it after the OS accepts it.
/// It must serialize evaluate/send/record on its own actor and recheck deadlines/consent before sending.
public struct NotificationPolicy: Sendable {
    public private(set) var authorization: NotificationAuthorization
    public private(set) var ledger: NotificationLedger
    private var pending: UUID?
    public init(authorization: NotificationAuthorization = .notDetermined, ledger: NotificationLedger = .init()) {
        self.authorization = authorization; self.ledger = ledger
    }
    public mutating func userSetOptIn(_ enabled: Bool, preferences: inout SettingsPreferences) -> NotificationPermissionEffect {
        let previous = preferences.notifications.optedIn
        preferences.notifications.optedIn = enabled
        if !enabled { pending = nil; return .none }
        guard !previous, pending == nil, authorization == .notDetermined else { return .none }
        let token = UUID(); pending = token; return .requestAuthorization(token)
    }
    public mutating func receivedAuthorization(_ result: NotificationAuthorization, request: UUID) {
        guard pending == request else { return }; pending = nil; authorization = result
    }
    /// Observed system changes do not trigger another permission request.
    public mutating func observeAuthorization(_ result: NotificationAuthorization) { authorization = result; pending = nil }
    public func delivery(for notice: SettingsNotice, preferences: SettingsPreferences, now: Date) -> NotificationDelivery? {
        guard preferences.notifications.optedIn, preferences.notifications.kinds.contains(notice.kind),
              authorization == .authorized || authorization == .provisional,
              valid(notice, now: now), !notice.restored,
              ledger.entries.count <= 4096, ledger.entries.allSatisfy({ $0.expiresAt.timeIntervalSinceReferenceDate.isFinite }),
              !ledger.entries.contains(where: { $0.key == key(notice) }),
              ledger.entries.filter({ $0.expiresAt > now }).count < 4096 else { return nil }
        return .init(kind: notice.kind, projectName: preferences.showProjectNames ? notice.projectName : nil)
    }
    public mutating func recordDelivered(_ notice: SettingsNotice, preferences: SettingsPreferences, now: Date) {
        guard delivery(for: notice, preferences: preferences, now: now) != nil else { return }
        ledger.entries.removeAll { $0.expiresAt <= now }
        ledger.entries.append(.init(key: key(notice), expiresAt: notice.expiresAt))
    }
    private func key(_ n: SettingsNotice) -> EpisodeKey { .init(kind: n.kind, subscriptionID: n.subscriptionID, episodeID: n.episodeID) }
    private func valid(_ n: SettingsNotice, now: Date) -> Bool {
        now.timeIntervalSinceReferenceDate.isFinite && n.beganAt.timeIntervalSinceReferenceDate.isFinite &&
            n.expiresAt.timeIntervalSinceReferenceDate.isFinite && n.beganAt <= now && n.expiresAt > now &&
            !n.subscriptionID.isEmpty && n.subscriptionID.utf8.count <= 256 && !n.episodeID.isEmpty && n.episodeID.utf8.count <= 256
    }
}
