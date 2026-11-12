// SPDX-License-Identifier: MIT
import Foundation

/// D166: the words for a public Codex reset event on the Quota Widget card and in its one notification.
/// Extra resets issued (a reset credit) and a direct limit reset are named apart; a forecast shows its
/// expected window, a confirmation its time. Personal balance always comes from the local reading.
/// "重置卡" / "reset card" is never used (LBL-2.2-11): the product word is 额外重置 / extra resets.
public struct EngineResetEventWording: Sendable {
    public let english: Bool
    public var calendar: Calendar
    public init(english: Bool, calendar: Calendar = .current) { self.english = english; self.calendar = calendar }

    public func label(_ event: EngineResetEvent) -> String {
        "↺ " + (event.isResetCredit ? (english ? "Extra resets" : "额外重置") : (english ? "Limit reset" : "额度重置"))
    }

    public func title(_ event: EngineResetEvent, now: Date) -> String {
        if event.status == "confirmed" {
            let at = event.confirmedAt ?? event.publishedAt
            if event.confirmedAtBasis == "firstSeen" {
                return english ? "Confirmed by " + time(at, now: now) : "已确认 · " + time(at, now: now) + " 前"
            }
            return (english ? "Confirmed · " : "已确认 · ") + time(at, now: now)
        }
        guard let from = event.scheduledFrom, let through = event.scheduledThrough else {
            return event.isResetCredit ? (english ? "Extra resets announced" : "已公告额外重置")
                                       : (english ? "Public reset announced" : "已公告公开重置")
        }
        if now >= through { return english ? "Awaiting confirmation" : "等待确认" }
        switch event.schedulePrecision {
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

    /// The local reading is the only personal fact; a rise after the confirmation is an observation.
    public func detail(rose: Bool) -> String {
        if rose { return english ? "Local reading rose · your balance is the local reading" : "本机读数已回升 · 余量以本机读数为准" }
        return english ? "Your balance is the local reading" : "余量以本机读数为准"
    }

    /// One notification, on confirmation only.
    public func notification(_ event: EngineResetEvent, rose: Bool) -> (title: String, body: String) {
        let title = event.isResetCredit ? (english ? "Codex extra resets confirmed" : "Codex 额外重置已确认")
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
    /// Today: the clock only; another day: the day and the clock.
    private func time(_ date: Date, now: Date) -> String {
        calendar.isDate(date, inSameDayAs: now) ? clock(date) : day(date) + " " + clock(date)
    }
}
