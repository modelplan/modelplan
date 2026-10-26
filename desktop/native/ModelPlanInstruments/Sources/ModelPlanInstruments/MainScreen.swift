// SPDX-License-Identifier: MIT
import Foundation

public enum MainScreenPage: CaseIterable, Hashable, Sendable {
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
    public let evidence: InstrumentEvidence
    public init(id: String, subscriptionID: String?, severity: NoticeSeverity, text: String, expiresAt: Date?, evidence: InstrumentEvidence = .init()) {
        self.id = id; self.subscriptionID = subscriptionID; self.severity = severity; self.text = text; self.expiresAt = expiresAt
        self.evidence = evidence
    }
}

public struct OverviewPresentation: Sendable {
    public let notices: [InstrumentNotice]
    public let todayTokens: Double?
    public let thirtyDayTokens: Double?
    public let chart: UsageChart
    public let heatmap: UsageHeatmap
    public let reportedTodaySources: [SourceTokenTotal]?
    public let reportedThirtyDaySources: [SourceTokenTotal]?
    public init(columns: [EngineColumn], daily: [InstrumentUsageBucket], hourly: [InstrumentUsageBucket],
                notices: [InstrumentNotice], scope: InstrumentScope, range: UsageRange, coverageStart: Date?, now: Date, calendar: Calendar,
                mode: UsageChartMode = .stacked, coverageBySubscription: [String: Date] = [:], reportedTodaySources: [SourceTokenTotal]? = nil,
                reportedThirtyDaySources: [SourceTokenTotal]? = nil) {
        let selected = columns.filter { scope == .all || scope == .subscription($0.id) }
        let ids = selected.map(\.id)
        self.notices = notices.enumerated().filter {
            $0.element.evidence.usable(at: now) && ($0.element.expiresAt.map { $0 > now } ?? true) && (scope == .all || $0.element.subscriptionID.map { scope == .subscription($0) } == true)
        }.sorted {
            $0.element.severity.rawValue == $1.element.severity.rawValue ? $0.offset < $1.offset : $0.element.severity.rawValue > $1.element.severity.rawValue
        }.map(\.element)
        self.reportedTodaySources = scope == .all ? reportedTodaySources : nil
        self.reportedThirtyDaySources = scope == .all ? reportedThirtyDaySources : nil
        if scope == .all, let reportedTodaySources {
            todayTokens = SourceTokenTotal.total(reportedTodaySources, now: now)
        } else {
            todayTokens = Set(ids).count == ids.count ? strictSum(selected.map {
                $0.evidence.usable(at: now) && $0.todayAttribution == .verifiedSubscription ? $0.todayTokens : nil
            }) : nil
        }
        let month = UsageChart(rows: daily, subscriptionIDs: ids, range: .days30, now: now, calendar: calendar)
        thirtyDayTokens = scope == .all && reportedThirtyDaySources != nil
            ? SourceTokenTotal.total(reportedThirtyDaySources ?? [], now: now, expectedPeriod: .days30)
            : strictSum(month.buckets.map(\.total))
        chart = UsageChart(rows: range == .hours24 ? hourly : daily, subscriptionIDs: ids, range: range, now: now, calendar: calendar, mode: mode)
        heatmap = UsageHeatmap(rows: daily, subscriptionIDs: ids, coverageStart: coverageStart, now: now, calendar: calendar, coverageBySubscription: coverageBySubscription)
    }
}

public enum ResetProvenance: Sendable {
    case natural, publicAnnouncement, confirmedAwaitingReading, resetAllowance, correction, unknown
}
public struct InstrumentCycle: Sendable {
    public let id: String
    public let endedAt: Date?
    public let used: Double?
    public let provenance: ResetProvenance
    public let breakdown: [CycleBreakdown]
    public let hadDrop: Bool?
    public let evidence: InstrumentEvidence
    public init(id: String, endedAt: Date?, used: Double?, provenance: ResetProvenance, breakdown: [CycleBreakdown],
                hadDrop: Bool? = nil, evidence: InstrumentEvidence = .init()) {
        self.id = id; self.endedAt = endedAt; self.used = known(used); self.provenance = provenance; self.breakdown = breakdown
        self.hadDrop = hadDrop; self.evidence = evidence
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
    public let evidence: InstrumentEvidence
    public let drawingCredits: Bool?
    public let historyStatus: String?
    public let historyUnavailableReason: String?
    public var observedAt: Date? { evidence.observedAt }
    /// There is deliberately no limit/used/remaining/credit-bar API. Nil drawing state is unknown, not false.
    public init(balance: Double?, drawingCredits: Bool?, evidence: InstrumentEvidence, now: Date,
                historyStatus: String? = nil, historyUnavailableReason: String? = nil) {
        self.evidence = evidence; self.historyStatus = historyStatus; self.historyUnavailableReason = historyUnavailableReason
        self.balance = evidence.usable(at: now) ? known(balance) : nil
        self.drawingCredits = evidence.usable(at: now) ? drawingCredits : nil
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
    public static var unavailable: Self { Self(today: [], recent7: [], recent30: [], recording: false) }
    public init(today: [GenerationSums], recent7: [GenerationSums], recent30: [GenerationSums], recording: Bool) {
        todayTPS = GenerationSums.weightedTPS(today, recording: recording)
        recent7TPS = GenerationSums.weightedTPS(recent7, recording: recording)
        recent30TPS = GenerationSums.weightedTPS(recent30, recording: recording)
    }
}

public struct SubscriptionHeader: Sendable {
    public let name: String?
    public let plan: String?
    public let glyphID: String?
    public let evidence: InstrumentEvidence
    public init(name: String?, plan: String?, glyphID: String?, evidence: InstrumentEvidence) {
        self.name = name; self.plan = plan; self.glyphID = glyphID; self.evidence = evidence
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
    public let header: SubscriptionHeader?
    public let usageDetail: UsageTokenDetail?
    public let sourceWideStatistics: SubscriptionStatistics?
    /// History is newest first. The adapter must prove historical subscription attribution;
    /// even a unique current source binding is insufficient.
    public init(id: String, windows: QuotaRows, reserve: ReservePresentation?, credits: CreditPresentation?,
                statistics: SubscriptionStatistics, cycles: [InstrumentCycle], peak: PeakBand?, observedAt: Date?,
                historyAttributed: Bool, now: Date, language: InstrumentLanguage,
                header: SubscriptionHeader? = nil, usageDetail: UsageTokenDetail? = nil) {
        self.id = id; self.windows = windows; self.reserve = reserve; self.credits = credits
        self.statistics = historyAttributed ? statistics : .unavailable; self.historyAttributed = historyAttributed
        sourceWideStatistics = historyAttributed ? nil : statistics
        self.header = header; self.usageDetail = historyAttributed ? usageDetail : nil
        self.cycles = historyAttributed ? Array(cycles.filter {
            $0.evidence.usable(at: now) && ($0.endedAt.map { $0 <= now } ?? true)
        }.prefix(10)) : []
        self.peak = historyAttributed ? peak : nil
        sourceAge = InstrumentFormat(language).age(header?.evidence.observedAt ?? observedAt, now: now)
    }
}
