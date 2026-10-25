// SPDX-License-Identifier: MIT
import Foundation

public struct InstrumentBinding: Sendable {
    public let subscriptionID: String
    public let sources: [String]
    public init(subscriptionID: String, sources: [String]) { self.subscriptionID = subscriptionID; self.sources = sources }
    /// Source-wide history is usable for a subscription only under a unique current binding.
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
public struct InstrumentUsageBucket: Sendable {
    public let subscriptionID: String
    public let at: Date
    public let tokens: Double?
    public init(subscriptionID: String, at: Date, tokens: Double?) {
        self.subscriptionID = subscriptionID; self.at = at; self.tokens = known(tokens)
    }
}
public struct UsageBucket: Sendable {
    /// Absolute start/end retain distinct identities for repeated local hours.
    public let start: Date
    public let end: Date
    public let perSubscription: [String: Double?]
    public var total: Double? { strictSum(Array(perSubscription.values)) }
}

public struct UsageChart: Sendable {
    public let subscriptionIDs: [String]
    public let buckets: [UsageBucket]
    public init(rows: [InstrumentUsageBucket], subscriptionIDs: [String], range: UsageRange, now: Date, calendar: Calendar) {
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
            for id in ids {
                // updateValue retains a present unknown entry; dictionary subscript=nil would remove it.
                per.updateValue(strictSum(selected.filter { $0.subscriptionID == id }.map(\.tokens)), forKey: id)
            }
            return UsageBucket(start: start, end: end, perSubscription: per)
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
}
public struct UsageHeatmap: Sendable {
    public let cells: [HeatmapCell]
    public let coverageStart: Date?
    public let shortCoverage: Bool
    public init(rows: [InstrumentUsageBucket], subscriptionIDs: [String], coverageStart: Date?, now: Date, calendar: Calendar) {
        let today = calendar.startOfDay(for: now)
        let weekday = (calendar.component(.weekday, from: today) + 5) % 7 // Monday = 0
        let count = 25 * 7 + weekday + 1
        let first = calendar.date(byAdding: .day, value: 1 - count, to: today)!
        self.coverageStart = coverageStart
        shortCoverage = coverageStart.map { $0 > first } ?? true
        var ids = Set<String>()
        let unique = subscriptionIDs.filter { ids.insert($0).inserted }
        let days = (0..<count).map { calendar.date(byAdding: .day, value: $0, to: first)! }
        let values: [(Date, [String: Double?], Double?)] = days.map { day in
            let end = calendar.date(byAdding: .day, value: 1, to: day)!
            let selected = rows.filter { $0.at >= day && $0.at < end && $0.at <= now && (coverageStart.map { day >= calendar.startOfDay(for: $0) } ?? true) }
            var per: [String: Double?] = [:]
            for id in unique { per.updateValue(strictSum(selected.filter { $0.subscriptionID == id }.map(\.tokens)), forKey: id) }
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
}
