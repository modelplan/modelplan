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
    /// Test seam with the Settings kind; set by a non-windowed host. Either override suppresses the OS.
    var kindDeliveryOverride:(@MainActor (NotificationKind,String) async throws -> Void)?
    /// Last read reset instant per member window. A later instant read after the earlier one
    /// passed is one "quota reset" episode; the first reading of a window never notifies.
    private var readResets:[String:Date]=[:]
    /// True when this notifier can actually deliver (system delivery or a host override).
    var delivers:Bool { deliverToSystem || deliveryOverride != nil || kindDeliveryOverride != nil }
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
        guard delivers else { return }
        applyQuotaResets(snapshot)
        guard case .available(let events)=EngineRowsEventDecoder.decode(snapshot.rows) else { return }
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
        let notice=SettingsNotice(kind:.official,subscriptionID:event.rowID,episodeID:event.id+":"+event.status,beganAt:event.publishedAt,expiresAt:event.expiresAt)
        await deliver(notice,identifier:"reset-"+event.rowID+"-"+notice.episodeID,stillCurrent:{ [weak self] in
            guard let self,let composition=self.composition else { return false }
            return self.isCurrent(event,composition)
        }) { english in
            (event.status == "confirmed" ? (english ? "Public reset confirmed":"公开重置已确认") : (english ? "Public reset announced":"已公告公开重置"),
             english ? "The public status does not confirm a personal quota reset.":"公开状态不代表个人额度已重置。")
        }
    }
    /// "Quota reset" (Settings kind `.reset`): a current reading of a member window reports a
    /// later reset instant than the one read before, after that earlier instant passed.
    private func applyQuotaResets(_ snapshot:EngineStoreSnapshot) {
        let members=EngineAccountMemberCatalogue(rows:snapshot.rows?.projection.rows ?? []).members
        for member in members where member.account.valueState == .current {
            for window in member.account.windows where window.current {
                guard let reset=EngineResetTimestampContract.date(window.resetsAt),
                      let observed=EngineResetTimestampContract.date(window.observedAt) else { continue }
                let key=member.id+"|"+window.id
                let previous=readResets[key]
                if previous == nil || reset > previous! { readResets[key]=reset }
                guard let previous,reset > previous,previous <= observed else { continue }
                let episode="quota:"+window.id+":"+String(Int(previous.timeIntervalSince1970))
                let pendingKey=member.id+"#"+episode
                guard pending.insert(pendingKey).inserted else { continue }
                let notice=SettingsNotice(kind:.reset,subscriptionID:member.id,episodeID:episode,beganAt:observed,expiresAt:reset)
                let english=member.name(english:true),chinese=member.name(english:false)
                let memberID=member.id,windowID=window.id
                Task { @MainActor [weak self] in
                    defer { self?.pending.remove(pendingKey) }
                    await self?.deliver(notice,identifier:"quota-reset-"+memberID+"-"+episode,stillCurrent:{ [weak self] in
                        guard let self,let composition=self.composition else { return false }
                        return composition.accountMembers.members.contains { $0.id == memberID && $0.account.windows.contains { $0.id == windowID } }
                    }) { isEnglish in
                        isEnglish ? ("Quota reset", english+": a new quota cycle was read.") : ("额度已重置", chinese+"：已读取到新的额度周期。")
                    }
                }
            }
        }
    }
    /// One serialized admission → delivery → ledger path for every kind. Authorization is the
    /// system's current state; this never requests permission (Settings' opt-in does that).
    private func deliver(_ notice:SettingsNotice,identifier:String,stillCurrent:@MainActor () -> Bool,
                         text:(Bool) -> (String,String)) async {
        guard let composition,stillCurrent() else { return }
        if deliveryOverride != nil || kindDeliveryOverride != nil { consumer.observeAuthorization(.authorized) }
        else {
            let authorization=await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            consumer.observeAuthorization(authorization == .authorized ? .authorized : authorization == .provisional ? .provisional : .denied)
        }
        let snapshot=await settings.snapshot()
        guard stillCurrent(),consumer.delivery(for:notice,snapshot:snapshot,now:composition.currentDate()) != nil else { return }
        do {
            if let kindDeliveryOverride { try await kindDeliveryOverride(notice.kind,notice.episodeID) }
            else if let deliveryOverride { try await deliveryOverride(notice.episodeID) }
            else {
                let (title,body)=text(snapshot.preferences.language == .english)
                let content=UNMutableNotificationContent()
                content.title=title;content.body=body
                try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier:identifier,content:content,trigger:nil))
            }
            // Record only accepted delivery; Settings owns pruning and the bounded ledger.
            consumer.recordAccepted(notice,snapshot:snapshot,now:composition.currentDate())
            try FileManager.default.createDirectory(at:cacheURL.deletingLastPathComponent(),withIntermediateDirectories:true)
            try JSONEncoder().encode(consumer.policy.ledger).write(to:cacheURL,options:.atomic)
        } catch { /* A failed delivery does not create a ledger entry. */ }
    }
}
