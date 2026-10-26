// SPDX-License-Identifier: MIT
import Foundation

public enum DockDataState: Equatable, Sendable { case fresh, stale, unavailable, loading }
public enum DockAlertSeverity: Int, Codable, Comparable, Sendable {
    case none, warning, critical
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}
public struct DockForecastSignal: Sendable {
    public let windowID: String
    public let validUntil: Date
    public init(windowID: String, validUntil: Date) { self.windowID = windowID; self.validUntil = validUntil }
}
public struct DockResetSignal: Sendable {
    public enum Status: Sendable { case announced, confirmed }
    public var id: String, status: Status
    public var announcedAt: Date?, confirmedAt: Date?, scheduledThrough: Date?
    public var restartedReading = false
    public init(id: String, status: Status, announcedAt: Date? = nil, confirmedAt: Date? = nil, scheduledThrough: Date? = nil) {
        self.id = id; self.status = status; self.announcedAt = announcedAt
        self.confirmedAt = confirmedAt; self.scheduledThrough = scheduledThrough
    }
}
public struct DockResetCardSignal: Sendable {
    public let id: String
    public let expiresAt: Date
    public init(id: String, expiresAt: Date) { self.id = id; self.expiresAt = expiresAt }
}
/// A validated display projection supplied by the data owner; never a second CLI reader/scorer.
public struct DockSubscriptionSignal: Sendable {
    public var id: String
    public var dataState: DockDataState = .unavailable
    public var alert: DockAlertSeverity = .none
    public var forecast: DockForecastSignal?
    public var reset: DockResetSignal?
    public var cards: [DockResetCardSignal] = []
    public var drawingCredits = false, creditsKnown = false, exhaustedQuotaObserved = false
    public init(id: String) { self.id = id }
}
public enum DockNoticeKind: Int, Codable, Hashable, Sendable {
    case forecast, resetAnnounced, resetConfirmed, cardsExpiring, credits
}
public struct DockNoticeKey: Hashable, Sendable {
    public let subscriptionID: String
    public let kind: DockNoticeKind
    public let sourceIDs: [String]
}
public struct DockNotice: Equatable, Sendable {
    public enum Tone: Equatable, Hashable, Sendable { case amber, blue, white }
    public enum Shape: Equatable, Sendable { case solid, hollow }
    public let key: DockNoticeKey
    public let tone: Tone
    public let shape: Shape
    public var rank: Int { key.kind.rawValue }
}
public enum DockNoticeProjection {
    public static func candidates(for signal: DockSubscriptionSignal, at now: Date) -> [DockNotice] {
        guard !signal.id.isEmpty, now.timeIntervalSinceReferenceDate.isFinite else { return [] }
        let fresh = signal.dataState == .fresh
        var notices = [DockNotice]()
        func append(_ kind: DockNoticeKind, _ ids: [String], _ tone: DockNotice.Tone, _ shape: DockNotice.Shape = .solid) {
            notices.append(DockNotice(key: DockNoticeKey(subscriptionID: signal.id, kind: kind, sourceIDs: ids), tone: tone, shape: shape))
        }
        if fresh, let forecast = signal.forecast, !forecast.windowID.isEmpty, forecast.validUntil > now {
            append(.forecast, [forecast.windowID], .amber)
        }
        if let reset = signal.reset, !reset.id.isEmpty {
            switch reset.status {
            case .announced:
                let until = reset.scheduledThrough ?? reset.announcedAt?.addingTimeInterval(48*3600)
                let observed = reset.announcedAt.map { $0 <= now } ?? (reset.scheduledThrough != nil)
                if observed, let until, until > now { append(.resetAnnounced, [reset.id], .blue, .hollow) }
            case .confirmed:
                if !reset.restartedReading, let at = reset.confirmedAt, at <= now, now < at.addingTimeInterval(24*3600) {
                    append(.resetConfirmed, [reset.id], .blue)
                }
            }
        }
        if fresh {
            // Stable event identity despite an upstream array reorder; expired/unknown cards are never invented.
            let cards = Set(signal.cards.filter { !$0.id.isEmpty && $0.expiresAt > now && $0.expiresAt <= now.addingTimeInterval(48*3600) }.map(\.id)).sorted()
            if !cards.isEmpty { append(.cardsExpiring, cards, .amber) }
            if signal.drawingCredits && signal.creditsKnown && signal.exhaustedQuotaObserved { append(.credits, [], .white) }
        }
        return notices
    }
    public static func selected(for signal: DockSubscriptionSignal, at now: Date) -> DockNotice? { candidates(for: signal, at: now).first }
}
public struct DockSliverSegment: Equatable, Sendable {
    public let subscriptionID: String, stationID: String
    public let severity: DockAlertSeverity
}
public struct DockSliverDot: Equatable, Sendable {
    public let stationID: String
    public let notice: DockNotice
}
public struct DockAttentionProjection: Sendable {
    public enum Base: Sendable { case neutral }
    public let base = Base.neutral
    public let segments: [DockSliverSegment]
    public let dots: [DockSliverDot]
    public let menuNotice: DockNotice?
}
public enum DockNoticeSurface: Hashable, Sendable { case sliver, dock, menu }

/// Tracks semantic acknowledgements only. Renderers decide positions/colours, and explicitly consume first appearance.
public struct DockAttentionState: Sendable {
    private var alertAcknowledgements: [String: DockAlertSeverity] = [:]
    private var sliverAcknowledgements = Set<DockNoticeKey>(), menuAcknowledgements = Set<DockNoticeKey>()
    private var appeared: [DockNoticeSurface: Set<DockNoticeKey>] = [:]
    private var activeKeys = Set<DockNoticeKey>()
    public init() {}
    public var retainedKeyCount: Int { sliverAcknowledgements.count + menuAcknowledgements.count + appeared.values.reduce(0) { $0+$1.count } }
    private mutating func reconcile(_ signals: [DockSubscriptionSignal], at now: Date) throws {
        guard now.timeIntervalSinceReferenceDate.isFinite else { throw DockLogicError.invalidTime }
        let ids = signals.map(\.id)
        guard !ids.contains(""), Set(ids).count == ids.count else { throw DockLogicError.invalidCatalogue }
        let available = Set(ids)
        alertAcknowledgements = alertAcknowledgements.filter { available.contains($0.key) }
        for s in signals where s.dataState == .fresh {
            // Unknown/stale is not evidence of improvement and cannot lower an acknowledged alert.
            if let acknowledged = alertAcknowledgements[s.id], s.alert < acknowledged { alertAcknowledgements[s.id] = s.alert }
        }
        activeKeys = Set(signals.flatMap { DockNoticeProjection.candidates(for: $0, at: now).map(\.key) })
        // Preserve acknowledgements across a transient stale/unavailable read, but never display that data.
        // Retention uses the original deadlines; expiration/removal still retires every retained key.
        let retainedKeys = Set(signals.flatMap { signal -> [DockNoticeKey] in
            var lastEvidence = signal; lastEvidence.dataState = .fresh
            return DockNoticeProjection.candidates(for: lastEvidence, at: now).map(\.key)
        })
        sliverAcknowledgements.formIntersection(retainedKeys); menuAcknowledgements.formIntersection(retainedKeys)
        for surface in Array(appeared.keys) { appeared[surface]?.formIntersection(retainedKeys) }
    }
    public mutating func acknowledgeDockOpen(_ signals: [DockSubscriptionSignal], at now: Date) throws {
        try reconcile(signals, at: now)
        for s in signals {
            if s.dataState == .fresh { alertAcknowledgements[s.id] = s.alert }
            if let n = DockNoticeProjection.selected(for: s, at: now) { sliverAcknowledgements.insert(n.key); menuAcknowledgements.insert(n.key) }
        }
    }
    public mutating func acknowledgeCockpitOpen(_ signals: [DockSubscriptionSignal], at now: Date) throws {
        try reconcile(signals, at: now)
        for s in signals { if let n = DockNoticeProjection.selected(for: s, at: now) { menuAcknowledgements.insert(n.key) } }
    }
    public mutating func firstAppearance(of key: DockNoticeKey, on surface: DockNoticeSurface) -> Bool {
        guard activeKeys.contains(key) else { return false }
        return appeared[surface, default: []].insert(key).inserted
    }
    /// stationBySubscription is provided by frozen geometry. Several overflow subscriptions may share one station.
    public mutating func project(_ signals: [DockSubscriptionSignal], stationBySubscription stations: [String: String], sliverAlerts: Bool = true, at now: Date) throws -> DockAttentionProjection {
        try reconcile(signals, at: now)
        var segments = [DockSliverSegment](), dots = [DockSliverDot](), menu: DockNotice?
        for s in signals {
            if sliverAlerts, s.dataState == .fresh, s.alert > (alertAcknowledgements[s.id] ?? .none), let station = stations[s.id] {
                segments.append(DockSliverSegment(subscriptionID: s.id, stationID: station, severity: s.alert))
            }
            if let n = DockNoticeProjection.selected(for: s, at: now) {
                if !sliverAcknowledgements.contains(n.key), let station = stations[s.id] { dots.append(DockSliverDot(stationID: station, notice: n)) }
                if !menuAcknowledgements.contains(n.key), menu == nil || n.rank < menu!.rank { menu = n }
            }
        }
        return DockAttentionProjection(segments: segments, dots: dots, menuNotice: menu)
    }
}
