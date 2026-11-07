// SPDX-License-Identifier: MIT
import Foundation
import OSLog
import UserNotifications
import ModelPlanEngineStore
import ModelPlanEngineClient
import ModelPlanSettings

/// Serializes event admission and delivery using the shared Settings notification policy.
@MainActor final class EngineResetNotifier:EngineStoreSink {
    private static let logger=Logger(subsystem:"ai.modelplan.notifications",category:"reset-ledger")
    private weak var composition:EngineDockMenuComposition?
    private let settings:SettingsStore
    private struct SavedLedger: Codable {
        let official: NotificationLedger
        let previous: NotificationLedger?
    }
    private let consumer:SettingsNotificationConsumer
    private let previousPolicy: NotificationPolicy?
    private let cacheURL:URL
    private let deliverToSystem:Bool
    private var pending=Set<String>()
    private var attachment:UUID?
    var deliveryOverride: (@MainActor (String, String) async throws -> Void)?
    init(composition:EngineDockMenuComposition,settings:SettingsStore,cacheURL:URL,deliverToSystem:Bool) throws {
        self.composition=composition;self.settings=settings;self.cacheURL=cacheURL;self.deliverToSystem=deliverToSystem
        let saved: SavedLedger
        if FileManager.default.fileExists(atPath: cacheURL.path) {
            let bytes = try Data(contentsOf: cacheURL)
            let decoder = JSONDecoder()
            do { saved = try decoder.decode(SavedLedger.self, from: bytes) }
            catch is DecodingError {
                saved = try SavedLedger(official: .init(), previous: decoder.decode(NotificationLedger.self, from: bytes))
            }
        } else { saved = SavedLedger(official: .init(), previous: nil) }
        previousPolicy = saved.previous.map { NotificationPolicy(authorization: .authorized, ledger: $0) }
        consumer = SettingsNotificationConsumer(policy: NotificationPolicy(ledger: saved.official))
    }
    static func recovering(composition:EngineDockMenuComposition,settings:SettingsStore,cacheURL:URL,deliverToSystem:Bool) throws -> EngineResetNotifier {
        do {
            return try .init(composition:composition,settings:settings,cacheURL:cacheURL,deliverToSystem:deliverToSystem)
        } catch let error as DecodingError {
            logger.error("Reset notification ledger is corrupt; quarantining it before starting a fresh ledger: \(error.localizedDescription, privacy: .private)")
            let timestamp=ISO8601DateFormatter().string(from:Date()).replacingOccurrences(of:":",with:"-")
            let quarantine=cacheURL.deletingLastPathComponent().appendingPathComponent(cacheURL.lastPathComponent+".corrupt-"+timestamp+"-"+UUID().uuidString)
            do { try FileManager.default.moveItem(at:cacheURL,to:quarantine) }
            catch { logger.error("Could not quarantine the corrupt reset notification ledger: \(error.localizedDescription, privacy: .private)");throw error }
            return try .init(composition:composition,settings:settings,cacheURL:cacheURL,deliverToSystem:deliverToSystem)
        } catch {
            logger.error("Could not read the reset notification ledger: \(error.localizedDescription, privacy: .private)")
            throw error
        }
    }
    func start() { guard let composition,attachment == nil else { return };attachment=composition.store.attach(self) }
    func stop() { if let attachment { composition?.store.detach(attachment) };attachment=nil }
    func clearPrivateViews(_ invalidation:EngineInvalidation) { }
    func apply(_ snapshot: EngineStoreSnapshot) {
        guard deliverToSystem || deliveryOverride != nil,
              case .available(let events) = EngineRowsEventDecoder.decode(snapshot.rows) else { return }
        for event in events {
            let key = event.rowID + "#" + event.id
            guard pending.insert(key).inserted else { continue }
            Task { @MainActor [weak self] in await self?.sendIfAllowed(event, key: key) }
        }
    }

    private func currentEvent(matching observed: EngineResetEvent, in composition: EngineDockMenuComposition) -> EngineResetEvent? {
        guard case .available(let current) = EngineRowsEventDecoder.decode(composition.store.snapshot.rows) else { return nil }
        return current.filter { event in
            event.id == observed.id && event.rowID == observed.rowID && composition.accountMembers.members.contains { member in
                member.rowID == event.rowID && (event.planIDs.map { $0.contains(member.account.plan.id) } ?? true)
            }
        }.max { $0.publishedAt < $1.publishedAt }
    }

    private func wasDeliveredByPreviousVersion(_ notice: SettingsNotice, snapshot: SettingsSnapshot, now: Date) -> Bool {
        guard let previousPolicy else { return false }
        var preferences = snapshot.preferences
        preferences.notifications.kinds.insert(.reset)
        return ["announced", "confirmed"].contains { status in
            let episode = notice.episodeID + ":" + status
            guard episode.utf8.count <= 256 else { return false }
            let legacy = SettingsNotice(kind: .reset, subscriptionID: notice.subscriptionID, episodeID: episode,
                beganAt: notice.beganAt, expiresAt: notice.expiresAt)
            return previousPolicy.delivery(for: legacy, preferences: preferences, now: now) == nil
        }
    }

    private func sendIfAllowed(_ observed: EngineResetEvent, key: String) async {
        defer { pending.remove(key) }
        guard let composition, attachment != nil else { return }
        let override = deliveryOverride
        if override != nil { consumer.observeAuthorization(.authorized) }
        else {
            guard deliverToSystem else { return }
            let authorization = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            consumer.observeAuthorization(authorization == .authorized ? .authorized : authorization == .provisional ? .provisional : .denied)
        }
        let snapshot = await settings.snapshot()
        // Confirmation keeps the announcement's event ID on the wire. Read the current
        // status after suspension so a confirmation can replace an in-flight announcement.
        guard attachment != nil, let event = currentEvent(matching: observed, in: composition) else { return }
        let now = composition.currentDate()
        guard event.publishedAt <= now, now < event.expiresAt else { return }
        // A later confirmation can carry the same event ID beyond the announcement's expiry.
        // Keep delivered identities within the policy's existing bounded ledger.
        let notice = SettingsNotice(kind: .official, subscriptionID: event.rowID, episodeID: event.id,
            beganAt: event.publishedAt, expiresAt: .distantFuture)
        guard consumer.delivery(for: notice, snapshot: snapshot, now: now) != nil,
              !wasDeliveredByPreviousVersion(notice, snapshot: snapshot, now: now) else { return }
        let english = snapshot.preferences.language == .english
        let title = english ? "Official extra reset" : "官方额外重置"
        do {
            if let override { try await override(notice.episodeID, title) }
            else {
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = english ? "The public status does not confirm a personal quota reset." : "公开状态不代表个人额度已重置。"
                try await UNUserNotificationCenter.current().add(UNNotificationRequest(
                    identifier: "reset-" + event.rowID + "-" + notice.episodeID, content: content, trigger: nil))
            }
        } catch { return }
        consumer.recordAccepted(notice, snapshot: snapshot, now: now)
        do {
            try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let saved = SavedLedger(official: consumer.policy.ledger, previous: previousPolicy?.ledger)
            try JSONEncoder().encode(saved).write(to: cacheURL, options: .atomic)
        } catch {
            Self.logger.error("Could not persist the reset notification ledger: \(error.localizedDescription, privacy: .private)")
        }
    }
}
