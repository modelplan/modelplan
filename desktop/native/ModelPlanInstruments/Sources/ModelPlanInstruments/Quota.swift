// SPDX-License-Identifier: MIT
import Foundation

public enum QuotaRow: CaseIterable, Sendable { case fiveHours, weekly, other }
public enum QuotaPeriod: Equatable, Sendable {
    case fiveHours, daily, weekly, monthly, other(String)
    public init(_ key: String) {
        switch key {
        case "5h": self = .fiveHours
        case "day", "daily": self = .daily
        case "week", "weekly": self = .weekly
        case "month", "monthly": self = .monthly
        default: self = .other(key)
        }
    }
}

public enum QuotaLevel: Int, Comparable, Sendable {
    case unknown, healthy, amber, critical
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    public static func of(_ remaining: Double?, redBelow: Double = 25) -> Self {
        guard let remaining = percentage(remaining), redBelow.isFinite, (0...100).contains(redBelow) else { return .unknown }
        return remaining <= redBelow ? .critical : remaining < 41 ? .amber : .healthy
    }
}
public enum QuotaPublicReset: Equatable, Sendable { case announced(Date?), confirmedAwaitingReading }

/// Already attributed input. An absent window is distinct from an unreadable existing window.
public struct InstrumentQuota: Sendable {
    public let id: String
    public let period: QuotaPeriod
    public let scope: String?
    public let remaining: Double?
    public let resetsAt: Date?
    public let durationMinutes: Double?
    public let readable: Bool
    public let runsOutAt: Date?
    public let publicReset: QuotaPublicReset?
    public init(id: String, period: QuotaPeriod, scope: String? = nil, remaining: Double?,
                resetsAt: Date? = nil, durationMinutes: Double? = nil, readable: Bool = true,
                runsOutAt: Date? = nil, publicReset: QuotaPublicReset? = nil) {
        self.id = id; self.period = period; self.scope = scope; self.remaining = remaining
        self.resetsAt = resetsAt; self.durationMinutes = durationMinutes; self.readable = readable
        self.runsOutAt = runsOutAt; self.publicReset = publicReset
    }
}

public struct QuotaCell: Sendable {
    public let id: String
    public let period: QuotaPeriod
    public let scope: String?
    public let remaining: Double?
    public let level: QuotaLevel
    public let litSegments: Int?
    public let resetsAt: Date?
    public let timeFraction: Double?
    public let timeDots: Int?
    public let runsOutAt: Date?
    public let publicReset: QuotaPublicReset?

    public init(_ input: InstrumentQuota, now: Date, redBelow: Double = 25) {
        id = input.id; period = input.period; scope = input.scope
        let passed = input.resetsAt.map { $0 <= now } ?? false
        remaining = input.readable && !passed ? percentage(input.remaining) : nil
        level = .of(remaining, redBelow: redBelow)
        litSegments = remaining.map { $0 == 0 ? 0 : max(1, min(10, Int(($0 / 10).rounded()))) }
        resetsAt = input.readable && !passed ? input.resetsAt : nil
        runsOutAt = input.readable && !passed ? input.runsOutAt.flatMap {
            let m = $0.timeIntervalSince(now) / 60
            return m.isFinite && m >= 0 && m < Double(Int.max / 2) ? $0 : nil
        } : nil
        publicReset = input.readable ? input.publicReset : nil // Announcement never changes the account reading.
        if input.readable, let reset = input.resetsAt, let duration = known(input.durationMinutes), duration > 0 {
            // Calendar windows need their actual reported duration; never assume a 30-day month.
            timeFraction = min(1, max(0, reset.timeIntervalSince(now) / 60 / duration))
        } else { timeFraction = nil }
        timeDots = timeFraction.map { $0 == 0 ? 0 : max(1, min(10, Int(($0 * 10).rounded()))) }
    }
}

public struct QuotaRows: Sendable {
    public let fiveHours: QuotaCell?
    public let weekly: QuotaCell?
    public let other: [QuotaCell]
    public var tightestOther: QuotaCell? { other.first }
    public var otherOverflow: Int { max(0, other.count - 1) }

    public init(windows: [InstrumentQuota], now: Date, redBelow: Double = 25) {
        let first = windows.firstIndex { $0.scope == nil && $0.period == .fiveHours }
        let second = windows.firstIndex { $0.scope == nil && $0.period == .weekly }
        fiveHours = first.map { QuotaCell(windows[$0], now: now, redBelow: redBelow) }
        weekly = second.map { QuotaCell(windows[$0], now: now, redBelow: redBelow) }
        other = windows.enumerated().filter { $0.offset != first && $0.offset != second }
            .map { ($0.offset, QuotaCell($0.element, now: now, redBelow: redBelow)) }
            .sorted { a, b in
                let x = a.1.remaining ?? .infinity, y = b.1.remaining ?? .infinity
                return x == y ? a.0 < b.0 : x < y
            }.map(\.1)
    }
}

public struct ResetAllowance: Sendable {
    public let count: Int?
    public let expiresAt: Date?
    public let kind: String?
    public let source: String?
    public let evidence: InstrumentEvidence
    public init(count: Int?, expiresAt: Date?, kind: String? = nil, source: String? = nil, evidence: InstrumentEvidence = .init()) {
        self.count = count; self.expiresAt = expiresAt; self.kind = kind; self.source = source; self.evidence = evidence
    }
}

public struct ReservePresentation: Sendable {
    public let resets: Int?
    public let nearestExpiry: Date?
    public let compactExpiries: [Date]
    public let expiryOverflow: Int
    public let expiryWarning: Bool
    public let credits: Double?
    public let drawingCredits: Bool
    public let allowances: [ResetAllowance]?

    /// nil allowances means unreadable; [] means a known zero. Counts can represent grouped allowances.
    public init(allowances: [ResetAllowance]?, credits: Double?, drawingCredits: Bool, now: Date) {
        let active = allowances?.filter {
            // An untrusted zero/expiry cannot prove an empty reserve. Keep the row so
            // the aggregate stays unknown; only trusted readings may be discarded.
            guard $0.evidence.usable(at: now) else { return true }
            return ($0.expiresAt.map { $0 > now } ?? true) && $0.count != 0
        }
        self.allowances = active
        var total: Int? = active == nil ? nil : 0
        for allowance in active ?? [] {
            guard allowance.evidence.usable(at: now), let count = allowance.count, count >= 0, let previous = total else { total = nil; continue }
            let next = previous.addingReportingOverflow(count)
            total = next.overflow ? nil : next.partialValue
        }
        resets = total
        let dates = (active ?? []).filter { $0.evidence.usable(at: now) }.compactMap(\.expiresAt).sorted()
        nearestExpiry = dates.first
        compactExpiries = Array(dates.prefix(4))
        expiryOverflow = max(0, dates.count - 4)
        expiryWarning = dates.contains { $0.timeIntervalSince(now) <= 48 * 3600 }
        self.credits = known(credits); self.drawingCredits = drawingCredits
    }
}

public struct EngineColumn: Sendable {
    public let id: String
    public let quotas: QuotaRows
    public let todayTokens: Double?
    public let todayGenerationTPS: Double?
    public let reserve: ReservePresentation?
    public let caution: QuotaLevel
    public let evidence: InstrumentEvidence
    public let todayAttribution: UsageAttribution
    public init(id: String, quotas: QuotaRows, todayTokens: Double?, todayGenerationTPS: Double?,
                reserve: ReservePresentation? = nil, caution: QuotaLevel = .unknown,
                evidence: InstrumentEvidence = .init(), todayAttribution: UsageAttribution = .verifiedSubscription) {
        self.id = id; self.quotas = quotas; self.todayTokens = known(todayTokens)
        self.todayGenerationTPS = known(todayGenerationTPS); self.reserve = reserve; self.caution = caution
        self.evidence = evidence; self.todayAttribution = todayAttribution
    }
}

public struct EnginePage: Sendable {
    public let page: Int
    public let pageCount: Int
    public let columns: [EngineColumn?]
    public let pageCautions: [QuotaLevel]
    public init(columns: [EngineColumn], page requested: Int) {
        pageCount = max(1, (columns.count + 5) / 6)
        page = min(max(0, requested), pageCount - 1)
        let shown = Array(columns.dropFirst(page * 6).prefix(6))
        let slots = columns.isEmpty ? 6 : columns.count <= 6 ? max(3, columns.count) : 6
        self.columns = (0..<slots).map { $0 < shown.count ? shown[$0] : nil }
        pageCautions = (0..<pageCount).map { p in
            columns.dropFirst(p * 6).prefix(6).map(\.caution).filter { $0 >= .amber }.max() ?? .unknown
        }
    }
}
