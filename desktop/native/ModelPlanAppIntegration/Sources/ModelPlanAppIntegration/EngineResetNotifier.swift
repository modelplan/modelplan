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
    var deliveryOverride:(@MainActor (String,String) async throws -> Void)?
    /// Test seam with the Settings kind; set by a non-windowed host. Either override suppresses the OS.
    var kindDeliveryOverride:(@MainActor (NotificationKind,String) async throws -> Void)?
    /// Last read reset instant per member window. A later instant read after the earlier one
    /// passed is one "quota reset" episode; the first reading of a window never notifies.
    private var readResets:[String:Date]=[:]
    /// True when this notifier can actually deliver (system delivery or a host override).
    var delivers:Bool { deliverToSystem || deliveryOverride != nil || kindDeliveryOverride != nil }
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
    func apply(_ snapshot:EngineStoreSnapshot) {
        guard delivers else { return }
        applyQuotaResets(snapshot)
        guard case .available(let events)=EngineRowsEventDecoder.decode(snapshot.rows) else { return }
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
        guard let composition, attachment != nil, await authorizeDelivery() else { return }
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
        await send(notice, identifier: "reset-" + event.rowID + "-" + notice.episodeID, snapshot: snapshot, now: now,
                   title: english ? "Official extra reset" : "官方额外重置",
                   body: english ? "The public status does not confirm a personal quota reset." : "公开状态不代表个人额度已重置。")
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
                    }) { isEnglish,showNames in
                        Self.quotaResetText(name:isEnglish ? english : chinese,english:isEnglish,showNames:showNames)
                    }
                }
            }
        }
    }
    /// "Project names" off also keeps names out of notifications, as the row promises.
    static func quotaResetText(name:String,english:Bool,showNames:Bool) -> (String,String) {
        if english { return ("Quota reset",showNames ? name+": a new quota cycle was read." : "A new quota cycle was read.") }
        return ("额度已重置",showNames ? name+"：已读取到新的额度周期。" : "已读取到新的额度周期。")
    }
    /// Authorization is the system's current state; this never requests permission (Settings' opt-in does that).
    private func authorizeDelivery() async -> Bool {
        if deliveryOverride != nil || kindDeliveryOverride != nil { consumer.observeAuthorization(.authorized); return true }
        guard deliverToSystem else { return false }
        let authorization = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        consumer.observeAuthorization(authorization == .authorized ? .authorized : authorization == .provisional ? .provisional : .denied)
        return true
    }
    /// The quota kind's admission; the official kind has its own above, for its event identity.
    private func deliver(_ notice:SettingsNotice,identifier:String,stillCurrent:@MainActor () -> Bool,
                         text:(Bool,Bool) -> (String,String)) async {
        guard let composition,stillCurrent(),await authorizeDelivery() else { return }
        let snapshot=await settings.snapshot()
        let now=composition.currentDate()
        guard stillCurrent(),consumer.delivery(for:notice,snapshot:snapshot,now:now) != nil else { return }
        let (title,body)=text(snapshot.preferences.language == .english,snapshot.preferences.showProjectNames)
        await send(notice,identifier:identifier,snapshot:snapshot,now:now,title:title,body:body)
    }
    /// One delivery and ledger path for every kind.
    private func send(_ notice:SettingsNotice,identifier:String,snapshot:SettingsSnapshot,now:Date,title:String,body:String) async {
        do {
            if let kindDeliveryOverride { try await kindDeliveryOverride(notice.kind,notice.episodeID) }
            else if let deliveryOverride { try await deliveryOverride(notice.episodeID,title) }
            else {
                let content=UNMutableNotificationContent()
                content.title=title;content.body=body
                try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier:identifier,content:content,trigger:nil))
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
