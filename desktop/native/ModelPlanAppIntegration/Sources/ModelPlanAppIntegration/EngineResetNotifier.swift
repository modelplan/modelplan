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
    private let consumer:SettingsNotificationConsumer
    private let cacheURL:URL
    private let deliverToSystem:Bool
    private var pending=Set<String>()
    private var attachment:UUID?
    var deliveryOverride:(@MainActor (String) async throws -> Void)?
    init(composition:EngineDockMenuComposition,settings:SettingsStore,cacheURL:URL,deliverToSystem:Bool) throws {
        self.composition=composition;self.settings=settings;self.cacheURL=cacheURL;self.deliverToSystem=deliverToSystem
        let ledger:NotificationLedger
        if FileManager.default.fileExists(atPath:cacheURL.path) {
            ledger=try JSONDecoder().decode(NotificationLedger.self,from:Data(contentsOf:cacheURL))
        } else { ledger=NotificationLedger() }
        consumer=SettingsNotificationConsumer(policy:NotificationPolicy(ledger:ledger))
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
    func apply(_ snapshot:EngineStoreSnapshot) {
        guard deliverToSystem || deliveryOverride != nil, case .available(let events)=EngineRowsEventDecoder.decode(snapshot.rows) else { return }
        for event in events {
            let key=event.rowID+"#"+event.id+":"+event.status
            guard pending.insert(key).inserted else { continue }
            Task { @MainActor [weak self] in await self?.sendIfAllowed(event,key:key) }
        }
    }
    private func affectsMember(_ event:EngineResetEvent,_ composition:EngineDockMenuComposition) -> Bool {
        composition.accountMembers.members.contains { member in
            member.rowID == event.rowID && (event.planIDs.map { $0.contains(member.account.plan.id) } ?? true)
        }
    }
    private func isCurrent(_ event:EngineResetEvent,_ composition:EngineDockMenuComposition) -> Bool {
        guard case .available(let current)=EngineRowsEventDecoder.decode(composition.store.snapshot.rows) else { return false }
        return current.contains { $0.id == event.id && $0.rowID == event.rowID && $0.status == event.status } && affectsMember(event,composition)
    }
    private func sendIfAllowed(_ event:EngineResetEvent,key:String) async {
        defer { pending.remove(key) }
        guard let composition,isCurrent(event,composition) else { return }
        let notice=SettingsNotice(kind:.reset,subscriptionID:event.rowID,episodeID:event.id+":"+event.status,beganAt:event.publishedAt,expiresAt:event.expiresAt)
        if deliveryOverride != nil { consumer.observeAuthorization(.authorized) }
        else {
            let authorization=await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            consumer.observeAuthorization(authorization == .authorized ? .authorized : authorization == .provisional ? .provisional : .denied)
        }
        let snapshot=await settings.snapshot()
        guard isCurrent(event,composition),consumer.delivery(for:notice,snapshot:snapshot,now:Date()) != nil else { return }
        do {
            if let deliveryOverride { try await deliveryOverride(notice.episodeID) }
            else {
                let english=snapshot.preferences.language == .english
                let content=UNMutableNotificationContent()
                content.title=event.status == "confirmed" ? (english ? "Public reset confirmed":"公开重置已确认") : (english ? "Public reset announced":"已公告公开重置")
                content.body=english ? "The public status does not confirm a personal quota reset.":"公开状态不代表个人额度已重置。"
                try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier:"reset-"+event.rowID+"-"+notice.episodeID,content:content,trigger:nil))
            }
            // Record only accepted delivery; Settings owns pruning and the bounded ledger.
            consumer.recordAccepted(notice,snapshot:snapshot,now:Date())
            try FileManager.default.createDirectory(at:cacheURL.deletingLastPathComponent(),withIntermediateDirectories:true)
            try JSONEncoder().encode(consumer.policy.ledger).write(to:cacheURL,options:.atomic)
        } catch { /* A failed delivery does not create a ledger entry. */ }
    }
}
