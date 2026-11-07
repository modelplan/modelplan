// SPDX-License-Identifier: MIT
import Foundation
import OSLog
import UserNotifications
import ModelPlanEngineStore
import ModelPlanEngineClient
import ModelPlanSettings
import ModelPlanWire

/// One window forecast to run out before its reset. A window has one episode per cycle, so a
/// run-out moving as readings arrive does not notify again.
struct EngineForecastEpisode:Equatable,Sendable {
    let subscriptionRef:String, episodeID:String
    let observedAt:Date, resetsAt:Date
    let name:SettingsText, window:SettingsText
}

/// Admits a forecast only for a current reading of a verified subscription, with its run-out still
/// ahead and before the reset. Quota readings alone never create a notice.
enum EngineForecastDecoder {
    private static func date(_ timestamp:WireTimestamp?) -> Date? {
        guard let timestamp else { return nil }
        let formatter=ISO8601DateFormatter(); formatter.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        return formatter.date(from:timestamp.rawValue) ?? ISO8601DateFormatter().date(from:timestamp.rawValue)
    }
    static func episodes(_ rows:WireRowsSnapshot?,now:Date) -> [EngineForecastEpisode] {
        guard let projection=rows?.projection else { return [] }
        var seen=Set<String>()
        return (projection.forecasts ?? []).compactMap { forecast -> EngineForecastEpisode? in
            guard let runsOut=date(forecast.runsOutAt),runsOut > now,let observed=date(forecast.observedAt),
                  let row=projection.rows.first(where:{ $0.id == forecast.source }),
                  let account=row.accounts.first(where:{ $0.subscriptionRef == forecast.subscriptionRef && $0.valueState == .current }),
                  let window=account.windows.first(where:{ $0.id == forecast.windowId && $0.current }),
                  let resets=date(window.resetsAt),resets > runsOut else { return nil }
            // A computed reset can jitter by a couple of minutes between readings of one cycle.
            let cycle=Int(resets.timeIntervalSince1970/600)
            let episode=forecast.windowId+":"+String(cycle)
            guard seen.insert(forecast.subscriptionRef+"#"+episode).inserted else { return nil }
            return .init(subscriptionRef:forecast.subscriptionRef,episodeID:episode,observedAt:observed,resetsAt:resets,
                         name:.init(row.name.en,row.name.zh),window:.init(window.label.en,window.label.zh))
        }
    }
}

/// Serializes forecast admission and delivery using the shared Settings notification policy.
@MainActor final class EngineForecastNotifier:EngineStoreSink {
    private static let logger=Logger(subsystem:"ai.modelplan.notifications",category:"forecast-ledger")
    private let settings:SettingsStore
    private let consumer:SettingsNotificationConsumer
    private let cacheURL:URL
    private let deliverToSystem:Bool
    private let now:@MainActor () -> Date
    private var latest:WireRowsSnapshot?
    private var pending=Set<String>()
    var deliveryOverride:(@MainActor (String) async throws -> Void)?
    init(settings:SettingsStore,cacheURL:URL,deliverToSystem:Bool,now:@escaping @MainActor () -> Date) {
        self.settings=settings;self.cacheURL=cacheURL;self.deliverToSystem=deliverToSystem;self.now=now
        var ledger=NotificationLedger()
        if let data=try? Data(contentsOf:cacheURL) {
            do { ledger=try JSONDecoder().decode(NotificationLedger.self,from:data) }
            catch {
                Self.logger.error("Forecast notification ledger is corrupt; starting a fresh ledger.")
                try? FileManager.default.removeItem(at:cacheURL)
            }
        }
        consumer=SettingsNotificationConsumer(policy:NotificationPolicy(ledger:ledger))
    }
    func clearPrivateViews(_ invalidation:EngineInvalidation) { latest=nil }
    func apply(_ snapshot:EngineStoreSnapshot) { apply(rows:snapshot.rows) }
    func apply(rows:WireRowsSnapshot?) {
        latest=rows
        guard deliverToSystem || deliveryOverride != nil else { return }
        for episode in EngineForecastDecoder.episodes(rows,now:now()) {
            let key=episode.subscriptionRef+"#"+episode.episodeID
            guard pending.insert(key).inserted else { continue }
            Task { @MainActor [weak self] in await self?.sendIfAllowed(episode,key:key) }
        }
    }
    private func isCurrent(_ episode:EngineForecastEpisode) -> Bool {
        EngineForecastDecoder.episodes(latest,now:now()).contains { $0.subscriptionRef == episode.subscriptionRef && $0.episodeID == episode.episodeID }
    }
    private func sendIfAllowed(_ episode:EngineForecastEpisode,key:String) async {
        defer { pending.remove(key) }
        guard isCurrent(episode) else { return }
        let notice=SettingsNotice(kind:.forecast,subscriptionID:episode.subscriptionRef,episodeID:episode.episodeID,beganAt:episode.observedAt,expiresAt:episode.resetsAt)
        if deliveryOverride != nil { consumer.observeAuthorization(.authorized) }
        else {
            let authorization=await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            consumer.observeAuthorization(authorization == .authorized ? .authorized : authorization == .provisional ? .provisional : .denied)
        }
        let snapshot=await settings.snapshot()
        guard isCurrent(episode),consumer.delivery(for:notice,snapshot:snapshot,now:now()) != nil else { return }
        do {
            if let deliveryOverride { try await deliveryOverride(notice.episodeID) }
            else {
                let english=snapshot.preferences.language == .english
                let content=UNMutableNotificationContent()
                content.title=english ? "May not last to reset":"可能撑不到重置"
                content.body=english ? "\(episode.name.english) \(episode.window.english) may run out before its reset.":"\(episode.name.chinese) \(episode.window.chinese) 可能撑不到重置。"
                try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier:"forecast-"+episode.subscriptionRef+"-"+notice.episodeID,content:content,trigger:nil))
            }
            // Record only accepted delivery; Settings owns pruning and the bounded ledger.
            consumer.recordAccepted(notice,snapshot:snapshot,now:now())
            try FileManager.default.createDirectory(at:cacheURL.deletingLastPathComponent(),withIntermediateDirectories:true)
            try JSONEncoder().encode(consumer.policy.ledger).write(to:cacheURL,options:.atomic)
        } catch { /* A failed delivery does not create a ledger entry. */ }
    }
}
