// SPDX-License-Identifier: MIT
import Foundation

/// WP-15 (V1-FINAL §1, §2, §12; D290 item 9): the pure rules behind the widget ring and the widget card.
/// Words come from the app's string table; this file decides only what is shown and when.
/// Reference: Pulse (qunqin24/Pulse v1.12.4, `UsageRingView` / panel hover card) for the ring and card behaviour;
/// CodexBar `UsageMenuCardView` / `UsageFormatter` for the card's rows (stale tint, compact figures).

/// DOCK-3.2-50 / DOCK-3.3-09 (amended): an earlier reading looks normal for its first hour, then dims; it shows "--"
/// only once its window has reset (that boundary is the reading's `until`).
public enum DockStaleRule {
    public static let normalAge: TimeInterval = 3600
    public static func isDimmed(observedAt: Date, now: Date) -> Bool {
        let age = now.timeIntervalSince(observedAt)
        return age.isFinite && age >= normalAge
    }
    /// When a kept reading crosses from normal to dim; nil once it has (no timer needed).
    public static func dimsAt(observedAt: Date, now: Date) -> Date? {
        let boundary = observedAt.addingTimeInterval(normalAge)
        guard boundary.timeIntervalSinceReferenceDate.isFinite, boundary > now else { return nil }
        return boundary
    }
}

/// V1-FINAL §0 figures shared by the card rows.
public enum DockWidgetFigures {
    /// Tokens as k / M / B, three significant figures at most, never truncated: "980", "1.2k", "33.9M", "212M", "1.5B".
    public static func tokens(_ n: Int64) -> String {
        guard n >= 1000 else { return String(max(0, n)) }
        let units: [(Double, String)] = [(1e9, "B"), (1e6, "M"), (1e3, "k")]
        let value = Double(n)
        for (index, (size, suffix)) in units.enumerated() where value >= size {
            let scaled = value / size
            // 999.95k rounds to "1000k": carry it to the next unit up instead.
            if scaled.rounded() >= 1000, index > 0 {
                let (bigger, biggerSuffix) = units[index - 1]
                return format(value / bigger) + biggerSuffix
            }
            return format(scaled) + suffix
        }
        return String(n)
    }
    private static func format(_ scaled: Double) -> String {
        if scaled >= 100 { return String(Int(scaled.rounded())) }
        let tenths = (scaled * 10).rounded() / 10
        if tenths >= 100 { return String(Int(tenths.rounded())) }
        return tenths == tenths.rounded() ? String(Int(tenths)) : String(format: "%.1f", tenths)
    }
    /// V1-FINAL §0 durations ("40m", "3h18", "5d18h"), whole minutes first, at least 1m; the same rule as the alert sentence.
    public static func duration(minutes: Double) -> String {
        let m = max(1, Int(minutes.rounded()))
        if m < 60 { return "\(m)m" }
        if m < 1440 { let rest = m % 60; return "\(m / 60)h" + (rest < 10 ? "0" : "") + "\(rest)" }
        return "\(m / 1440)d\((m % 1440) / 60)h"
    }
}

/// DOCK-3.8-51: the card's today row. Left half = amount ("33.9M ≈$10.2"), right half = now ("● 1 running · 66 t/s").
/// Either half is left out when it has nothing; the row is left out when both are. Always "today" (board-3 item 9).
public enum DockTodayRow {
    /// - Parameters:
    ///   - cost: the estimated-cost text ("≈$10.2"); nil until WP-06 supplies it (the hook stays empty in v1 final until then).
    ///   - running: the localized running phrase ("1 个在跑"); nil or empty when nothing runs.
    public static func make(label: String, cost: String?, tokens: Int64?, running: String?, tokensPerSecond: Double?) -> DockCardRow? {
        // Master spec §2.1 (D464, D474): total tokens first, ≈$ (or "未计价") after it.
        let left = [tokens.flatMap { $0 > 0 ? DockWidgetFigures.tokens($0) : nil }, cost]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        var now: [String] = []
        if let running, !running.isEmpty { now.append("● " + running) }
        if let tps = tokensPerSecond, tps.isFinite, tps > 0 { now.append("\(Int(tps.rounded())) t/s") }
        let right = now.joined(separator: " · ")
        guard !left.isEmpty || !right.isEmpty else { return nil }
        // A row with only the right half keeps it on the right (value empty, detail filled).
        return DockCardRow(id: "today", kind: .statistic, label: label, value: left, detail: right)
    }
}

/// DOCK-3.8-52 / V1-FINAL §11: the one alert the card footer states, or nil. Red: at or below the red line, or used up.
/// Amber: forecast to run out before the window resets. Only a fresh reading alerts; a stale or unreadable one never does (§12).
public struct DockCardAlert: Equatable, Sendable {
    public let windowID: String, label: String, period: DockQuotaPeriod
    public let remaining: Double
    public let runOutAt: Date?, resetsAt: Date?
    public let severity: DockAlertSeverity
    public var usedUp: Bool { remaining <= 0 }
}
public enum DockCardAlertRule {
    public static func alert(input: DockInstrumentInput, runOutTimes: [String: Date] = [:], redBelow: Double = 25, now: Date) -> DockCardAlert? {
        guard input.dataState == .fresh, now.timeIntervalSinceReferenceDate.isFinite, redBelow.isFinite else { return nil }
        var found: [DockCardAlert] = []
        for window in input.windows where window.isGeneral {
            guard let remaining = DockInstrumentProjection.admittedRemaining(window, in: input, now: now) else { continue }
            let reset = window.resetsAt.flatMap { $0 > now ? $0 : nil }
            let runOut = runOutTimes[window.id].flatMap { at -> Date? in
                guard at.timeIntervalSinceReferenceDate.isFinite, at > now, reset.map({ at < $0 }) ?? true else { return nil }
                return at
            }
            let severity: DockAlertSeverity = remaining <= redBelow ? .critical : runOut != nil ? .warning : .none
            guard severity != .none else { continue }
            found.append(.init(windowID: window.id, label: window.label, period: window.period, remaining: remaining,
                               runOutAt: runOut, resetsAt: reset, severity: severity))
        }
        // Red before amber; within a colour the tightest window.
        return found.min { a, b in a.severity != b.severity ? a.severity > b.severity : a.remaining < b.remaining }
    }
}
