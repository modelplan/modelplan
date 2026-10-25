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
    public static func of(_ remaining: Double?) -> Self {
        guard let remaining = percentage(remaining) else { return .unknown }
        return remaining < 16 ? .critical : remaining < 41 ? .amber : .healthy
    }
}

/// Already attributed input. An absent window is distinct from an unreadable existing window.
public struct InstrumentQuota: Sendable {
    public let id: String
    public let period: QuotaPeriod
    public let scope: String?
    public let remaining: Double?
    public let resetsAt: Date?
    public let durationMinutes: Double?
    public let readable: Bool
    public init(id: String, period: QuotaPeriod, scope: String? = nil, remaining: Double?,
                resetsAt: Date? = nil, durationMinutes: Double? = nil, readable: Bool = true) {
        self.id = id; self.period = period; self.scope = scope; self.remaining = remaining
        self.resetsAt = resetsAt; self.durationMinutes = durationMinutes; self.readable = readable
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

    public init(_ input: InstrumentQuota, now: Date) {
        id = input.id; period = input.period; scope = input.scope
        let passed = input.resetsAt.map { $0 <= now } ?? false
        remaining = input.readable && !passed ? percentage(input.remaining) : nil
        level = .of(remaining)
        litSegments = remaining.map { $0 == 0 ? 0 : max(1, min(10, Int(($0 / 10).rounded()))) }
        resetsAt = input.readable && !passed ? input.resetsAt : nil
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

    public init(windows: [InstrumentQuota], now: Date) {
        let first = windows.firstIndex { $0.scope == nil && $0.period == .fiveHours }
        let second = windows.firstIndex { $0.scope == nil && $0.period == .weekly }
        fiveHours = first.map { QuotaCell(windows[$0], now: now) }
        weekly = second.map { QuotaCell(windows[$0], now: now) }
        other = windows.enumerated().filter { $0.offset != first && $0.offset != second }
            .map { ($0.offset, QuotaCell($0.element, now: now)) }
            .sorted { a, b in
                let x = a.1.remaining ?? .infinity, y = b.1.remaining ?? .infinity
                return x == y ? a.0 < b.0 : x < y
            }.map(\.1)
    }
}

public struct ResetAllowance: Sendable {
    public let count: Int?
    public let expiresAt: Date?
    public init(count: Int?, expiresAt: Date?) { self.count = count; self.expiresAt = expiresAt }
}

public struct ReservePresentation: Sendable {
    public let resets: Int?
    public let nearestExpiry: Date?
    public let compactExpiries: [Date]
    public let expiryOverflow: Int
    public let expiryWarning: Bool
    public let credits: Double?
    public let drawingCredits: Bool

    /// nil allowances means unreadable; [] means a known zero. Counts can represent grouped allowances.
    public init(allowances: [ResetAllowance]?, credits: Double?, drawingCredits: Bool, now: Date) {
        let active = allowances?.filter { ($0.expiresAt.map { $0 > now } ?? true) && $0.count != 0 }
        var total: Int? = active == nil ? nil : 0
        for allowance in active ?? [] {
            guard let count = allowance.count, count >= 0, let previous = total else { total = nil; continue }
            let next = previous.addingReportingOverflow(count)
            total = next.overflow ? nil : next.partialValue
        }
        resets = total
        let dates = (active ?? []).compactMap(\.expiresAt).sorted()
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
    public init(id: String, quotas: QuotaRows, todayTokens: Double?, todayGenerationTPS: Double?,
                reserve: ReservePresentation? = nil, caution: QuotaLevel = .unknown) {
        self.id = id; self.quotas = quotas; self.todayTokens = known(todayTokens)
        self.todayGenerationTPS = known(todayGenerationTPS); self.reserve = reserve; self.caution = caution
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
