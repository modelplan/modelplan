// SPDX-License-Identifier: MIT
import Foundation

/// A published peak window of one subscription; `to` is nil when the publication shows no end.
public struct DockPeakWindow: Equatable, Sendable {
    public var from: Date, to: Date?
    public init(from: Date, to: Date?) { self.from = from; self.to = to }
}

/// One timed fact for the card's "接下来" block.
public struct DockNextFact: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case fiveHourReset, weeklyReset, monthlyReset, peak, runOut }
    public var kind: Kind
    public var at: Date
    /// A peak's end, when known.
    public var until: Date?
    public init(kind: Kind, at: Date, until: Date? = nil) { self.kind = kind; self.at = at; self.until = until }
}

/// D466 section 5 / master spec §3.2 (D474): the widget card's "接下来" / "Next" block. The same lines as the cockpit
/// strip hover: what falls in the next 24 hours (resets, peak windows, an estimated run-out), at most `maxLines`; when
/// nothing does, say so and list the next two items (`之后`). A plan with peak rules also states the state now (off-peak,
/// or in the peak and when it ends). In an alert state (`inAlert`) the footer sentence already says what matters, so
/// with nothing in 24 h the block is left out entirely.
public enum DockNextBlock {
    public static let horizon: TimeInterval = 24 * 3600
    public static let maxLines = 3

    public static func rows(facts: [DockNextFact], peaks: [DockPeakWindow], hasPeakRules: Bool, now: Date,
                            english: Bool, inAlert: Bool = false, calendar: Calendar = .current) -> [DockCardRow] {
        guard now.timeIntervalSinceReferenceDate.isFinite else { return [] }
        let clock: (Date) -> String = { date in
            let c = calendar.dateComponents([.hour, .minute], from: date)
            return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
        }
        let weekdays = english ? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"] : ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        // Within 24 h: "13:04", or "Tomorrow 02:00" past midnight; beyond: "Wed 05:42".
        func stamp(_ date: Date, later: Bool) -> String {
            if later {
                let day = weekdays[max(0, min(6, calendar.component(.weekday, from: date) - 1))]
                return day + " " + clock(date)
            }
            if calendar.isDate(date, inSameDayAs: now) { return clock(date) }
            return (english ? "Tomorrow " : "明天 ") + clock(date)
        }
        // Every timed item: the user's own facts plus each peak start still ahead.
        var all = facts.filter { $0.at > now && $0.at.timeIntervalSinceReferenceDate.isFinite }
        for peak in peaks where peak.from > now { all.append(DockNextFact(kind: .peak, at: peak.from, until: peak.to)) }
        all.sort { $0.at < $1.at }
        func words(_ fact: DockNextFact, later: Bool) -> String {
            let head = stamp(fact.at, later: later)
            switch fact.kind {
            case .fiveHourReset: return head + (english ? " 5-hour reset" : " 5 小时额度重置")
            case .weeklyReset: return head + (english ? " weekly reset" : " 每周额度重置")
            case .monthlyReset: return head + (english ? " monthly reset" : " 每月额度重置")
            // 预估 is our own estimate (预计 is kept for official times, §3.2).
            case .runOut: return head + (english ? " est. run-out" : " 预估用完")
            case .peak:
                let span = fact.until.map { clock(fact.at) + "–" + clock($0) } ?? clock(fact.at)
                // The date prefix is whatever `stamp` adds before the clock ("Tomorrow ", "Wed "); today adds none.
                let stamped = stamp(fact.at, later: later)
                let prefix = String(stamped.dropLast(clock(fact.at).count))
                return prefix + span + (english ? " Peak" : " 高峰")
            }
        }
        // The state now, only for a plan with peak rules.
        var state = ""
        if hasPeakRules {
            if let current = peaks.first(where: { $0.from <= now && ($0.to.map { $0 > now } ?? true) }) {
                state = english ? "In peak" : "高峰中"
                if let end = current.to { let at = clock(end); state += english ? " · ends \(at)" : " · \(at) 结束" }
            } else { state = english ? "Off-peak now" : "现在闲时" }
        }
        let within = all.filter { $0.at <= now.addingTimeInterval(horizon) }
        let beyond = all.filter { $0.at > now.addingTimeInterval(horizon) }
        // An alert state with nothing in 24 h: the footer sentence already says it, so the block is left out (§3.2).
        if inAlert && within.isEmpty { return [] }
        var rows = [DockCardRow]()
        func line(_ text: String) { rows.append(DockCardRow(id: "next." + String(rows.count), kind: .event, label: "", value: text)) }
        // macrev2-1289-6 (§3.2, approved): a normal card with nothing known still says so, in the strip hover's words.
        let suffix = state.isEmpty ? "" : " · " + state
        if within.isEmpty {
            // The heading is the sentence itself (the strip hover's words), then the next two items.
            line((english ? "No resets or peaks in the next 24 h" : "接下来 24 小时没有重置，也没有高峰") + suffix)
            for fact in beyond.prefix(2) { line((english ? "Later " : "之后 ") + words(fact, later: true)) }
        } else {
            line((english ? "Next" : "接下来") + suffix)
            for fact in within.prefix(maxLines) { line(words(fact, later: false)) }
        }
        return rows
    }
}
