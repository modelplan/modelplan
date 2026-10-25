// SPDX-License-Identifier: MIT
import Foundation

public enum MainScreenPage: CaseIterable, Sendable {
    case overview, subscriptions, effort, destinations
    public func title(_ language: InstrumentLanguage) -> String {
        switch (self, language) {
        case (.overview, .chinese): return "总览"
        case (.overview, .english): return "Overview"
        case (.subscriptions, .chinese): return "订阅"
        case (.subscriptions, .english): return "Subscriptions"
        case (.effort, .chinese): return "档位"
        case (.effort, .english): return "Effort"
        case (.destinations, .chinese): return "去向"
        case (.destinations, .english): return "Destinations"
        }
    }
}

public enum InstrumentScope: Equatable, Sendable { case all, subscription(String) }
public enum NoticeSeverity: Int, Sendable { case information, amber, critical }
public struct InstrumentNotice: Sendable {
    public let id: String
    public let subscriptionID: String?
    public let severity: NoticeSeverity
    public let text: String
    public let expiresAt: Date?
    public init(id: String, subscriptionID: String?, severity: NoticeSeverity, text: String, expiresAt: Date?) {
        self.id = id; self.subscriptionID = subscriptionID; self.severity = severity; self.text = text; self.expiresAt = expiresAt
    }
}

public struct OverviewPresentation: Sendable {
    public let notices: [InstrumentNotice]
    public let todayTokens: Double?
    public let thirtyDayTokens: Double?
    public let chart: UsageChart
    public let heatmap: UsageHeatmap
    public init(columns: [EngineColumn], daily: [InstrumentUsageBucket], hourly: [InstrumentUsageBucket],
                notices: [InstrumentNotice], scope: InstrumentScope, range: UsageRange, coverageStart: Date?, now: Date, calendar: Calendar) {
        let selected = columns.filter { scope == .all || scope == .subscription($0.id) }
        let ids = selected.map(\.id)
        self.notices = notices.enumerated().filter {
            ($0.element.expiresAt.map { $0 > now } ?? true) && (scope == .all || $0.element.subscriptionID.map { scope == .subscription($0) } == true)
        }.sorted {
            $0.element.severity.rawValue == $1.element.severity.rawValue ? $0.offset < $1.offset : $0.element.severity.rawValue > $1.element.severity.rawValue
        }.map(\.element)
        todayTokens = strictSum(selected.map(\.todayTokens))
        let month = UsageChart(rows: daily, subscriptionIDs: ids, range: .days30, now: now, calendar: calendar)
        thirtyDayTokens = strictSum(month.buckets.map(\.total))
        chart = UsageChart(rows: range == .hours24 ? hourly : daily, subscriptionIDs: ids, range: range, now: now, calendar: calendar)
        heatmap = UsageHeatmap(rows: daily, subscriptionIDs: ids, coverageStart: coverageStart, now: now, calendar: calendar)
    }
}

public enum ResetProvenance: Sendable { case natural, publicAnnouncement, confirmedAwaitingReading, correction, unknown }
public struct InstrumentCycle: Sendable {
    public let id: String
    public let endedAt: Date?
    public let used: Double?
    public let provenance: ResetProvenance
    public let breakdown: [CycleBreakdown]
    public init(id: String, endedAt: Date?, used: Double?, provenance: ResetProvenance, breakdown: [CycleBreakdown]) {
        self.id = id; self.endedAt = endedAt; self.used = known(used); self.provenance = provenance; self.breakdown = breakdown
    }
}
public struct CycleBreakdown: Sendable {
    public let modelID: String
    public let effort: String?
    public let fast: Bool?
    public let points: Double?
    public init(modelID: String, effort: String?, fast: Bool?, points: Double?) {
        self.modelID = modelID; self.effort = effort; self.fast = fast; self.points = known(points)
    }
}

public struct CreditPresentation: Sendable {
    public let balance: Double?
    public let used: Double?
    public let limit: Double?
    public let remainingPercent: Double?
    public let resetsAt: Date?
    public let daily: [InstrumentUsageBucket]
    public init(balance: Double?, used: Double?, limit: Double?, resetsAt: Date?, daily: [InstrumentUsageBucket]) {
        self.balance = known(balance); self.used = known(used); self.limit = known(limit); self.resetsAt = resetsAt
        if let used = known(used), let limit = known(limit), limit > 0, used <= limit {
            remainingPercent = (limit - used) / limit * 100
        } else { remainingPercent = nil }
        // Daily credit rows must arrive in chronological order from the adapter.
        self.daily = Array(daily.suffix(30))
    }
}

public struct PeakBand: Sendable {
    public let from: Date
    public let until: Date
    public init?(from: Date, until: Date) {
        guard from < until else { return nil }
        self.from = from; self.until = until
    }
}

/// Subscription statistics explicitly retain their window; today's rate cannot borrow a 7/30-day value.
public struct SubscriptionStatistics: Sendable {
    public let todayTPS: Double?
    public let recent7TPS: Double?
    public let recent30TPS: Double?
    public init(today: [GenerationSums], recent7: [GenerationSums], recent30: [GenerationSums], recording: Bool) {
        todayTPS = GenerationSums.weightedTPS(today, recording: recording)
        recent7TPS = GenerationSums.weightedTPS(recent7, recording: recording)
        recent30TPS = GenerationSums.weightedTPS(recent30, recording: recording)
    }
}

public struct SubscriptionPresentation: Sendable {
    public let id: String
    public let windows: QuotaRows
    public let reserve: ReservePresentation?
    public let credits: CreditPresentation?
    public let statistics: SubscriptionStatistics
    public let cycles: [InstrumentCycle]
    public let peak: PeakBand?
    public let sourceAge: String
    public let historyAttributed: Bool
    /// History is newest first. The adapter must prove unique source attribution before setting historyAttributed.
    public init(id: String, windows: QuotaRows, reserve: ReservePresentation?, credits: CreditPresentation?,
                statistics: SubscriptionStatistics, cycles: [InstrumentCycle], peak: PeakBand?, observedAt: Date?,
                historyAttributed: Bool, now: Date, language: InstrumentLanguage) {
        self.id = id; self.windows = windows; self.reserve = reserve; self.credits = credits
        self.statistics = statistics; self.historyAttributed = historyAttributed
        self.cycles = historyAttributed ? Array(cycles.prefix(10)) : []
        self.peak = historyAttributed ? peak : nil
        sourceAge = InstrumentFormat(language).age(observedAt, now: now)
    }
}

public struct EffortPagePresentation: Sendable {
    public let models: [InstrumentModel]
    public init(models: [InstrumentModel], offeredModelIDs: Set<String>, scope: InstrumentScope, publicationUsable: Bool) {
        self.models = publicationUsable ? models.filter {
            scope == .all || (!$0.olderVersion && offeredModelIDs.contains($0.id))
        } : []
    }
}
