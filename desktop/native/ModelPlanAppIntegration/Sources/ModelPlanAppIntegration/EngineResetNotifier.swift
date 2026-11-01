// SPDX-License-Identifier: MIT
import Foundation
import UserNotifications
import ModelPlanEngineStore
import ModelPlanEngineClient
import ModelPlanSettings

/// One serialized consumer of admitted public reset events. It never asks for permission.
@MainActor final class EngineResetNotifier:EngineStoreSink {
    private weak var composition:EngineDockMenuComposition?
    private let settings:SettingsStore
    private let ledger:EngineResetEventLedger
    private let deliverToSystem:Bool
    private var pending=Set<String>()
    private var attachment:UUID?
    var deliveryOverride:(@MainActor (String) async throws -> Void)?
    init(composition:EngineDockMenuComposition,settings:SettingsStore,ledger:EngineResetEventLedger,deliverToSystem:Bool) {
        self.composition=composition;self.settings=settings;self.ledger=ledger;self.deliverToSystem=deliverToSystem
    }
    func start() { guard let composition,attachment == nil else { return };attachment=composition.store.attach(self) }
    func clearPrivateViews(_ invalidation:EngineInvalidation) { }
    func apply(_ snapshot:EngineStoreSnapshot) {
        guard deliverToSystem || deliveryOverride != nil, case .available(let events)=EngineRowsEventDecoder.decode(snapshot.rows) else { return }
        for event in events where event.status == "announced" && !ledger.wasDelivered(event.id) && !ledger.acknowledged.contains(event.id) && !pending.contains(event.id) {
            pending.insert(event.id)
            Task { @MainActor [weak self] in await self?.sendIfAllowed(event) }
        }
    }
    private func affectsMember(_ event:EngineResetEvent,_ composition:EngineDockMenuComposition) -> Bool {
        composition.accountMembers.members.contains { member in
            member.rowID == event.rowID && (event.planIDs.map { $0.contains(member.account.plan.id) } ?? true)
        }
    }
    private func sendIfAllowed(_ event:EngineResetEvent) async {
        defer { pending.remove(event.id) }
        let preferences=await settings.snapshot().preferences
        guard preferences.notifications.optedIn,preferences.notifications.kinds.contains(.reset),
              event.publishedAt <= Date(),event.expiresAt > Date(),let composition,
              case .available(let current)=EngineRowsEventDecoder.decode(composition.store.snapshot.rows),
              current.contains(where:{$0.id == event.id && $0.rowID == event.rowID}),affectsMember(event,composition),
              !ledger.wasDelivered(event.id),!ledger.acknowledged.contains(event.id) else { return }
        if let deliveryOverride {
            do { try await deliveryOverride(event.id);try ledger.recordDelivered(event.id) } catch {}
            return
        }
        let center=UNUserNotificationCenter.current()
        let authorization=await center.notificationSettings().authorizationStatus
        guard authorization == .authorized || authorization == .provisional else { return }
        let latest=await settings.snapshot().preferences
        guard latest.notifications.optedIn,latest.notifications.kinds.contains(.reset),!ledger.acknowledged.contains(event.id) else { return }
        guard case .available(let currentAgain)=EngineRowsEventDecoder.decode(composition.store.snapshot.rows),
              currentAgain.contains(where:{$0.id == event.id && $0.rowID == event.rowID}),affectsMember(event,composition),
              event.expiresAt > Date(),!ledger.wasDelivered(event.id) else { return }
        let english=latest.language == .english
        let content=UNMutableNotificationContent();content.title=english ? "Public reset announced":"已公告公开重置"
        content.body=english ? "A provider announced a reset. This does not confirm a personal quota reset.":"服务商已公告重置，个人额度是否重置尚未确认。"
        do {
            try await center.add(UNNotificationRequest(identifier:"reset-"+event.id,content:content,trigger:nil))
            try ledger.recordDelivered(event.id)
        } catch { /* A failed delivery is not marked delivered. */ }
    }
}
