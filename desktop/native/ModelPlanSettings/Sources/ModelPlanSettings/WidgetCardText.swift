// SPDX-License-Identifier: MIT
import Foundation

/// WP-15 (V1-FINAL §0, §2; board-3): the Quota Widget card's words, English and Chinese side by side.
/// The alert footer's sentence is not here: it is `AlertSentence` (ALR-50, WP-11), shared with the cockpit and the menu.
public enum WidgetCardText {
    /// C23 (D474): 今天 everywhere, never 今日.
    public static let today = SettingsText("Today", "今天")
    /// DOCK-3.8-51: "1 running" / "1 个在跑".
    public static func running(_ count: Int) -> SettingsText {
        SettingsText("\(count) running", "\(count) 个在跑")
    }
    /// DOCK-3.8-50: the header's right side, "Updated 3 min ago" / "3 分钟前更新".
    public enum Age: Equatable, Sendable { case unknown, justNow, minutes(Int), hours(Int), days(Int), older }
    public static func updated(_ age: Age) -> SettingsText {
        switch age {
        case .unknown: return SettingsText("Not read yet", "未读取")
        case .justNow: return SettingsText("Updated just now", "刚刚更新")
        case .minutes(let n): return SettingsText("Updated \(n) min ago", "\(n) 分钟前更新")
        case .hours(let n): return SettingsText("Updated \(n) h ago", "\(n) 小时前更新")
        case .days(let n): return SettingsText("Updated \(n) d ago", "\(n) 天前更新")
        case .older: return SettingsText("Updated over 30 days ago", "超过 30 天前更新")
        }
    }
    /// A missing, zero or implausible reading time is never printed as an age; readings cannot predate 2020.
    public static func age(observedAt: Date?, now: Date) -> Age {
        guard let observedAt, observedAt >= Date(timeIntervalSince1970: 1_577_836_800) else { return .unknown }
        let seconds = now.timeIntervalSince(observedAt)
        guard seconds.isFinite, seconds >= 0 else { return .unknown }
        if seconds < 60 { return .justNow }
        if seconds < 3600 { return .minutes(Int(seconds / 60)) }
        if seconds < 48 * 3600 { return .hours(Int(seconds / 3600)) }
        if seconds <= 30 * 86_400 { return .days(Int(seconds / 86_400)) }
        return .older
    }
    /// DOCK-3.8-53: the loading card's header ("正在读取…"); its rows are names and placeholder blocks only.
    public static let reading = SettingsText("Reading…", "正在读取…")
    /// DOCK-3.8-53: the unreadable card's one button.
    public static let readAgain = SettingsText("Read again", "重新读取")
    /// V1-FINAL §0: a quota row's right side, "resets in 5d18h" / "5d18h 后重置", or "out ~40m" / "约40m用完".
    public static func resetsIn(_ duration: String) -> SettingsText { SettingsText("resets in " + duration, duration + " 后重置") }
    public static func runsOutIn(_ duration: String) -> SettingsText { SettingsText("out ~" + duration, "约" + duration + "用完") }
    /// Master spec §3.2 / decision 1 (D474): a quota row's second line. 预估 is our own estimate (约 only for ≈$).
    public static func estimateOut(_ duration: String) -> SettingsText { SettingsText("est. out in " + duration, "预估 " + duration + " 用完") }
    public static let lastsToReset = SettingsText("lasts to reset", "够用到重置")
    /// Master spec §2.1: today's tokens have no public price, so no ≈$ (never $0).
    public static let unpriced = SettingsText("unpriced", "未计价")
    public static let usedUp = SettingsText("used up", "已用完")
    /// G3-136: why the widget is an empty ring. A tool without permission uses the shared cause table's sentence.
    public static let stillReading = SettingsText("Still reading", "正在读取")
    public static let noSubscriptions = SettingsText("No subscriptions yet", "还没有订阅")
    /// Master spec §3.4 (D474, D320): subscriptions exist but none has a good reading yet (first run, or every one failing).
    public static let noReadingYet = SettingsText("No quota read yet", "还没读到额度")
    public static let noReadingYetHint = SettingsText("Sign in to a coding tool and it appears here", "登录一个编程工具后会自动出现")
    public static let openSubscriptions = SettingsText("Open Settings › Subscriptions", "打开设置 › 订阅")
}
