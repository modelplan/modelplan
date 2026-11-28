// SPDX-License-Identifier: MIT
import Foundation

/// D166: the words for a public Codex reset event on the Quota Widget card and in its one notification.
/// Banked resets issued (a reset credit) and a direct limit reset are named apart; a forecast shows its
/// expected window, a confirmation its time. Personal balance always comes from the local reading.
/// "重置卡" / "reset card" is banned (LBL-2.2-11, D428): the product word is 额外重置次数 / banked resets; a direct reset keeps its own wording (D166).
public struct EngineResetEventWording: Sendable {
    public let english: Bool
    public var calendar: Calendar
    public init(english: Bool, calendar: Calendar = .current) { self.english = english; self.calendar = calendar }

    public func label(_ event: EngineResetEvent) -> String {
        "↺ " + (event.isResetCredit ? (english ? "Banked resets" : "额外重置") : (english ? "Limit reset" : "额度重置"))
    }

    public func title(_ event: EngineResetEvent, now: Date) -> String {
        if event.status == "confirmed" {
            // D466: an absolute time, "今天 00:29" / "Today 00:29", also for a first-seen time (no "09:11 前").
            let at = event.confirmedAt ?? event.publishedAt
            return (english ? "Confirmed · " : "已确认 · ") + pastTime(at, now: now)
        }
        guard let from = event.scheduledFrom, let through = event.scheduledThrough else {
            return event.isResetCredit ? (english ? "Banked resets announced" : "已公告额外重置")
                                       : (english ? "Public reset announced" : "已公告公开重置")
        }
        if now >= through { return english ? "Awaiting confirmation" : "等待确认" }
        switch event.schedulePrecision ?? "" {
        case "deadline" where from == through:
            let at = clock(through)
            if event.isResetCredit { return english ? "Expected by " + at : "预计 " + at + " 前" }
            return english ? "Reset " + at + " announced" : "预告 " + at + " 重置"
        case "date":
            let first = day(from), last = day(through.addingTimeInterval(-1))
            if first == last { return english ? "Expected " + first : "预计 " + first }
            return english ? "Expected between " + first + " and " + last : "预计 " + first + "–" + last + " 之间"
        default:
            if from == through { return english ? "Expected around " + time(from, now: now) : "预计 " + time(from, now: now) + " 前后" }
            return english ? "Expected between " + time(from, now: now) + " and " + time(through, now: now)
                           : "预计 " + time(from, now: now) + "–" + time(through, now: now) + " 之间"
        }
    }

    /// D466: the card's second line for a confirmed banked reset: when it was issued and where it went. The reset only
    /// adds to the Reserve; no window was reset.
    public func bankedConfirmedDetail(_ event: EngineResetEvent, now: Date) -> String {
        let at = pastTime(event.confirmedAt ?? event.publishedAt, now: now)
        return english ? "Issued " + at.replacingOccurrences(of: "Today ", with: "today ") + ": +1 reset, now in Reserve" : at + " 发放，你多了 1 次重置，已在储备里"
    }

    /// The local reading is the only personal fact; a rise after the confirmation is an observation.
    public func detail(rose: Bool) -> String {
        if rose { return english ? "Local reading rose · your balance is the local reading" : "本机读数已回升 · 余量以本机读数为准" }
        return english ? "Your balance is the local reading" : "余量以本机读数为准"
    }

    /// One notification, on confirmation only.
    public func notification(_ event: EngineResetEvent, rose: Bool) -> (title: String, body: String) {
        let title = event.isResetCredit ? (english ? "Codex banked resets confirmed" : "Codex 额外重置已确认")
                                        : (english ? "Codex limit reset confirmed" : "Codex 额度重置已确认")
        if rose { return (title, english ? "Already in effect: your local reading rose." : "已生效：本机读数已回升。") }
        return (title, english ? "Your balance is the local reading." : "余量以本机读数为准。")
    }

    private func clock(_ date: Date) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
    private func day(_ date: Date) -> String {
        let c = calendar.dateComponents([.month, .day], from: date)
        let month = c.month ?? 1, day = c.day ?? 1
        if english {
            let names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
            return names[max(0, min(11, month - 1))] + " \(day)"
        }
        return "\(month)月\(day)日"
    }
    /// Today: "今天 00:29" / "Today 00:29"; another day: the day and the clock. Forecast times in the future on the
    /// same day keep the plain clock ("预计 13:04–15:00 之间").
    private func time(_ date: Date, now: Date) -> String {
        calendar.isDate(date, inSameDayAs: now) ? clock(date) : day(date) + " " + clock(date)
    }
    private func pastTime(_ date: Date, now: Date) -> String {
        calendar.isDate(date, inSameDayAs: now) ? (english ? "Today " : "今天 ") + clock(date) : day(date) + " " + clock(date)
    }
}
