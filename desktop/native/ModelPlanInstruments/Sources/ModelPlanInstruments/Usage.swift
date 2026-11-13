// SPDX-License-Identifier: MIT
import Foundation

public struct InstrumentBinding: Sendable {
    public let subscriptionID: String
    public let sources: [String]
    public init(subscriptionID: String, sources: [String]) { self.subscriptionID = subscriptionID; self.sources = sources }
    /// Current source links for labels only. Even a unique link is not proof of historical account ownership.
    public static func sources(for subscription: String, bindings: [Self]) -> [String] {
        let own = Set(bindings.filter { $0.subscriptionID == subscription }.flatMap(\.sources))
        guard !own.isEmpty, own.allSatisfy({ source in
            Set(bindings.filter { $0.sources.contains(source) }.map(\.subscriptionID)).count == 1
        }) else { return [] }
        return own.sorted()
    }
}

public struct GenerationSums: Sendable {
    public let eligibleRequests: Double?
    public let eligibleOutputTokens: Double?
    public let generationMilliseconds: Double?
    public let basis: String?
    public let usable: Bool
    public init(eligibleRequests: Double?, eligibleOutputTokens: Double?, generationMilliseconds: Double?, basis: String?, usable: Bool = true) {
        self.eligibleRequests = known(eligibleRequests); self.eligibleOutputTokens = known(eligibleOutputTokens)
        self.generationMilliseconds = known(generationMilliseconds); self.basis = basis; self.usable = usable
    }
    public static func weightedTPS(_ rows: [Self], recording: Bool) -> Double? {
        guard recording, let first = rows.first, let basis = first.basis,
              rows.allSatisfy({ $0.usable && $0.basis == basis }),
              let requests = strictSum(rows.map(\.eligibleRequests)), requests >= 5,
              let tokens = strictSum(rows.map(\.eligibleOutputTokens)),
              let ms = strictSum(rows.map(\.generationMilliseconds)), ms > 0 else { return nil }
        return known(tokens / (ms / 1000))
    }
}

public enum UsageRange: Sendable { case hours24, days7, days30 }
public enum UsageChartMode: Sendable { case stacked, split }
public struct InstrumentUsageBucket: Sendable {
    public let subscriptionID: String
    public let at: Date
    public let tokens: Double?
    public let attribution: UsageAttribution
    public let evidence: InstrumentEvidence
    public let timeBasis: UsageTimeBasis
    public init(subscriptionID: String, at: Date, tokens: Double?, attribution: UsageAttribution = .verifiedSubscription,
                evidence: InstrumentEvidence = .init(), timeBasis: UsageTimeBasis = .unspecified) {
        self.subscriptionID = subscriptionID; self.at = at; self.tokens = known(tokens)
        self.attribution = attribution; self.evidence = evidence; self.timeBasis = timeBasis
    }
    func usableTokens(now: Date, expectedBasis: UsageTimeBasis? = nil) -> Double? {
        let compatible = expectedBasis == nil || timeBasis == .unspecified || timeBasis == expectedBasis
        return attribution == .verifiedSubscription && evidence.usable(at: now) && compatible ? tokens : nil
    }
}
public struct UsageSegment: Sendable {
    public let subscriptionID: String
    public let tokens: Double?
}
public struct UsageBucket: Sendable {
    /// Absolute start/end retain distinct identities for repeated local hours.
    public let start: Date
    public let end: Date
    public let perSubscription: [String: Double?]
    public let segments: [UsageSegment]
    public let evidenceBySubscription: [String: [InstrumentUsageBucket]]
    public var total: Double? { strictSum(Array(perSubscription.values)) }
    public var recordedTotal: Double? { strictSum(perSubscription.values.compactMap { $0 }.map(Optional.some)) }
    public var partial: Bool { perSubscription.values.contains { $0 == nil } }
}

public struct UsageChart: Sendable {
    public let subscriptionIDs: [String]
    public let buckets: [UsageBucket]
    public let mode: UsageChartMode
    public init(rows: [InstrumentUsageBucket], subscriptionIDs: [String], range: UsageRange, now: Date, calendar: Calendar,
                mode: UsageChartMode = .stacked) {
        self.mode = mode
        var seen = Set<String>()
        self.subscriptionIDs = subscriptionIDs.filter { seen.insert($0).inserted }
        let today = calendar.startOfDay(for: now)
        let starts: [Date]
        let component: Calendar.Component
        switch range {
        case .hours24:
            component = .hour
            let end = calendar.date(byAdding: .day, value: 1, to: today)!
            // A local day has 23/25 hours at DST and may begin at a quarter-hour UTC offset.
            starts = stride(from: today.timeIntervalSinceReferenceDate, to: end.timeIntervalSinceReferenceDate, by: 3600)
                .map { Date(timeIntervalSinceReferenceDate: $0) }
        case .days7, .days30:
            component = .day
            let count = range == .days7 ? 7 : 30
            starts = (0..<count).map { calendar.date(byAdding: .day, value: $0 - count + 1, to: today)! }
        }
        let ids = self.subscriptionIDs
        buckets = starts.map { start in
            let end = calendar.date(byAdding: component, value: 1, to: start)!
            let selected = rows.filter { $0.at >= start && $0.at < end && $0.at <= now }
            var per: [String: Double?] = [:]
            var evidence: [String: [InstrumentUsageBucket]] = [:]
            for id in ids {
                evidence[id] = selected.filter { $0.subscriptionID == id }
                // updateValue retains a present unknown entry; dictionary subscript=nil would remove it.
                per.updateValue(strictSum((evidence[id] ?? []).map { $0.usableTokens(now: now, expectedBasis: range == .hours24 ? .completionHour : .turnStartLocalDay) }), forKey: id)
            }
            let segments = ids.map { UsageSegment(subscriptionID: $0, tokens: per[$0] ?? nil) }
            return UsageBucket(start: start, end: end, perSubscription: per, segments: segments, evidenceBySubscription: evidence)
        }
    }
}

public struct HeatmapCell: Sendable {
    public let day: Date
    public let column: Int
    public let row: Int
    public let perSubscription: [String: Double?]
    public let total: Double?
    /// nil means no reading; zero means a reported zero. Positive readings use steps 1...4.
    public let intensity: Int?
    public var completeTotal: Double? { strictSum(Array(perSubscription.values)) }
    public var partial: Bool { perSubscription.values.contains { $0 == nil } }
}
public struct UsageHeatmap: Sendable {
    public let cells: [HeatmapCell]
    public let coverageStart: Date?
    public let shortCoverage: Bool
    public let coverageBySubscription: [String: Date]
    public let retainedRows: [InstrumentUsageBucket]
    /// Future cells in the last week are absent. Geometry consumers still have exactly 26 × 7 slots.
    public var grid: [HeatmapCell?] { (0..<182).map { $0 < cells.count ? cells[$0] : nil } }
    public init(rows: [InstrumentUsageBucket], subscriptionIDs: [String], coverageStart: Date?, now: Date, calendar: Calendar,
                coverageBySubscription: [String: Date] = [:]) {
        let today = calendar.startOfDay(for: now)
        let weekday = (calendar.component(.weekday, from: today) + 5) % 7 // Monday = 0
        let count = 25 * 7 + weekday + 1
        let first = calendar.date(byAdding: .day, value: 1 - count, to: today)!
        var ids = Set<String>()
        let unique = subscriptionIDs.filter { ids.insert($0).inserted }
        self.coverageBySubscription = coverageBySubscription.filter { unique.contains($0.key) }
        let completeCoverage = !unique.isEmpty && unique.allSatisfy { coverageBySubscription[$0] != nil }
        let reportedCoverage = coverageStart ?? (completeCoverage ? unique.compactMap { coverageBySubscription[$0] }.min() : nil)
        let resolvedCoverage = reportedCoverage.flatMap { $0 <= now ? $0 : nil }
        self.coverageStart = resolvedCoverage
        shortCoverage = resolvedCoverage.map { calendar.startOfDay(for: $0) > first } ?? true
        let retentionStart = calendar.date(byAdding: .day, value: -370, to: today)!
        let retained = rows.filter { unique.contains($0.subscriptionID) && $0.at >= retentionStart && $0.at <= now }
        retainedRows = retained
        let days = (0..<count).map { calendar.date(byAdding: .day, value: $0, to: first)! }
        let values: [(Date, [String: Double?], Double?)] = days.map { day in
            let end = calendar.date(byAdding: .day, value: 1, to: day)!
            let selected = retained.filter { $0.at >= day && $0.at < end }
            var per: [String: Double?] = [:]
            for id in unique {
                let start = coverageBySubscription[id] ?? coverageStart
                let covered = start.map { day >= calendar.startOfDay(for: $0) } ?? true
                let tokens = covered ? strictSum(selected.filter { $0.subscriptionID == id }.map { $0.usableTokens(now: now, expectedBasis: .turnStartLocalDay) }) : nil
                per.updateValue(tokens, forKey: id)
            }
            let reported = per.values.compactMap { $0 }
            // The tooltip retains unknown subscriptions; intensity describes the recorded portion only.
            let total = reported.isEmpty ? nil : strictSum(reported.map(Optional.some))
            return (day, per, total)
        }
        let positives = values.compactMap(\.2).filter { $0 > 0 }.sorted()
        let cuts = [0.25, 0.5, 0.75].map { p in
            positives.isEmpty ? Double.infinity : positives[min(positives.count - 1, Int(p * Double(positives.count)))]
        }
        cells = values.enumerated().map { i, value in
            let step = value.2.map { $0 == 0 ? 0 : $0 <= cuts[0] ? 1 : $0 <= cuts[1] ? 2 : $0 <= cuts[2] ? 3 : 4 }
            return HeatmapCell(day: value.0, column: i / 7, row: i % 7, perSubscription: value.1, total: value.2, intensity: step)
        }
    }
    public func coverageDescription(language: InstrumentLanguage, calendar: Calendar) -> String? {
        guard shortCoverage, let coverageStart else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = calendar; formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: language == .chinese ? "zh_CN" : "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let day = formatter.string(from: coverageStart)
        return language == .chinese ? "从 \(day) 开始记录" : "Recorded since \(day)"
    }
}
