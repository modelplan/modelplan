// SPDX-License-Identifier: MIT
import Foundation

public enum InstrumentFreshness: String, Codable, Sendable { case fresh, stale, unavailable, unknown }

/// A verdict supplied by Core. No invented source TTL, clock read or historical account inference.
public struct InstrumentEvidence: Sendable {
    public let source: String?
    public let observedAt: Date?
    public let validUntil: Date?
    public let freshness: InstrumentFreshness
    public let reason: String?
    public init(source: String? = nil, observedAt: Date? = nil, validUntil: Date? = nil,
                freshness: InstrumentFreshness = .fresh, reason: String? = nil) {
        self.source = source; self.observedAt = observedAt; self.validUntil = validUntil
        self.freshness = freshness; self.reason = reason
    }
    public func usable(at now: Date) -> Bool {
        freshness == .fresh && (validUntil.map { $0 > now } ?? true) && (observedAt.map { $0 <= now } ?? true)
    }
}

public enum UsageAttribution: String, Codable, Sendable {
    case verifiedSubscription, sourceWideCurrentBinding, unattributed
}

public enum UsageTimeBasis: String, Sendable { case turnStartLocalDay, completionHour, unspecified }
public enum UsageSummaryPeriod: Sendable { case today, days7, days30 }

/// An independently identified source total, supplied by the CLI adapter rather than copied per account.
public struct SourceTokenTotal: Sendable {
    public let source: String
    public let tokens: Double?
    public let evidence: InstrumentEvidence
    public let period: UsageSummaryPeriod
    public let coverageStart: Date?
    public let coverageComplete: Bool?
    public init(source: String, tokens: Double?, evidence: InstrumentEvidence, period: UsageSummaryPeriod = .today,
                coverageStart: Date? = nil, coverageComplete: Bool? = nil) {
        self.source = source; self.tokens = known(tokens); self.evidence = evidence
        self.period = period
        self.coverageStart = coverageStart; self.coverageComplete = coverageComplete
    }
    public static func total(_ rows: [Self], now: Date, expectedPeriod: UsageSummaryPeriod = .today) -> Double? {
        // Duplicate source totals are ambiguous, not extra usage or an opportunity to pick one.
        guard Set(rows.map(\.source)).count == rows.count,
              rows.allSatisfy({ !$0.source.isEmpty && $0.evidence.usable(at: now) && $0.period == expectedPeriod }) else { return nil }
        return strictSum(rows.map(\.tokens))
    }
}

public struct UsageTokenDetail: Sendable {
    public let input: Double?
    public let output: Double?
    public let cacheRead: Double?
    public let cacheWrite: Double?
    public var cacheHitRatio: Double? {
        guard let input, let cacheRead else { return nil }
        return ratio(cacheRead, known(input + cacheRead))
    }
    public init(input: Double?, output: Double?, cacheRead: Double?, cacheWrite: Double?) {
        self.input = known(input); self.output = known(output)
        self.cacheRead = known(cacheRead); self.cacheWrite = known(cacheWrite)
    }
}
