// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanDock
import ModelPlanCockpitWeb

/// D466: the host side of the cockpit's news channel (and, D474, the `seen` memory). The page cannot read the Swift clock, so this sends it the
/// answers (`news {items:[{id,status,untilUnixMs}]}`, at most 64) on load, with each display and whenever an answer
/// changes, and records the page's first looks (`newsLook`) in the same shared `DockNewsClock`.
@MainActor public final class CockpitNewsBridge {
    private weak var coordinator: EngineCockpitCoordinator?
    private let provider: EngineDockContentProvider
    private let events: () -> [EngineResetEvent]
    private let now: () -> Date
    public init(coordinator: EngineCockpitCoordinator, provider: EngineDockContentProvider,
                events: @escaping () -> [EngineResetEvent], now: @escaping () -> Date) {
        self.coordinator = coordinator; self.provider = provider; self.events = events; self.now = now
        coordinator.onNewsLook = { [weak self] looks in self?.record(looks) }
        // Every refresh ticks the clock; the answers follow it.
        provider.onNewsTick = { [weak self] in self?.refresh() }
        refresh()
    }
    /// The answers for these events at `now`: every announced or confirmed event the clock knows, newest first.
    public static func items(events: [EngineResetEvent], clock: DockNewsClockStore, now: Date) -> [CockpitNewsItem] {
        var seen = Set<String>()
        var result = [CockpitNewsItem]()
        for event in events.sorted(by: { $0.publishedAt > $1.publishedAt }) {
            guard let status = CockpitNewsItem.Status(rawValue: event.status), seen.insert(event.id + "#" + event.status).inserted else { continue }
            let anchor = status == .confirmed ? (event.confirmedAt ?? event.publishedAt) : event.publishedAt
            let key = DockNewsClock.key(eventID: event.id, status: event.status)
            result.append(CockpitNewsItem(id: event.id, status: status, until: clock.liveUntil(key, anchor: anchor, at: now)))
            if result.count == 64 { break }
        }
        return result
    }
    public func refresh() {
        coordinator?.newsItems = Self.items(events: events(), clock: provider.newsClock, now: now())
        // D474 decision 3 (C45): the seen-subscriptions memory rides the same refresh tick (it changes only when a
        // projection records a first good reading, or a Forget / privacy clear empties it). No store: nothing is sent.
        if let seen = provider.seenSubscriptions { coordinator?.seenIDs = seen.ids }
    }
    private func record(_ looks: [CockpitNewsLookEvent]) {
        let at = now()
        for look in looks { provider.recordNewsLook(eventID: look.id, status: look.status.rawValue, at: look.at ?? at) }
        refresh()
    }
}
