// SPDX-License-Identifier: MIT
import Foundation

/// ALR-50 (WP-11, V1-FINAL §0, §8.1, §11): the one sentence an alert has, for the native surfaces (the menu line and the
/// Quota Widget card footer). The cockpit page builds the same words (`desktop/cockpit/study/rocket-r1/alert-sentence.js`);
/// `desktop/tests/shared/alert-sentences.json` holds both tables to the same cases, so the lamp, the column wash, the
/// overview, the alert list, the menu and the widget card can never say it differently.
/// D474 §3.2, three forms, each keeping the reset time when it is known:
/// long (`text`) "Codex 每周 53% · 预估 2d16h 用完 · 4d14h 后重置" (card footer, alert list, lamp tooltip);
/// `short` "Codex 每周 53% · 预估2d16h · 4d14h后重置" (menu line, 总览); used up "Codex 5小时 已用完 · 3h18 后重置" (all).
/// A form that does not fit fades the subscription name; the time is never cut.
public struct AlertSentenceText: Equatable, Sendable {
    /// Which form the sentence is (`tests/shared/alert-sentences.json` `form`).
    public enum Form: String, Sendable { case quota, usedUp, unreadable, unreadableMany }
    public let form: Form
    /// The long form: with the forecast and the reset when they are known.
    public let text: SettingsText
    /// The short form for single-line places; it still keeps the reset time.
    public let short: SettingsText
    public init(form: Form = .quota, text: SettingsText, short: SettingsText) { self.form = form; self.text = text; self.short = short }
}

public enum AlertSentence {
    /// V1-FINAL §0 times: "40m", "3h18", "1d20h". Whole minutes first (119.7 minutes is "2h00", never "1h60"); at least 1m.
    public static func duration(minutes: Double) -> String {
        let m = max(1, Int(minutes.rounded()))
        if m < 60 { return "\(m)m" }
        if m < 1440 { let rest = m % 60; return "\(m / 60)h" + (rest < 10 ? "0" : "") + "\(rest)" }
        return "\(m / 1440)d\((m % 1440) / 60)h"
    }

    /// A quota window: red (at the red line or used up) or amber (forecast to run out). `remaining` is the percent left.
    public static func quota(subscription: SettingsText, window: SettingsText, remaining: Double,
                             runOutMinutes: Double?, resetMinutes: Double?) -> AlertSentenceText {
        let usedUp = remaining <= 0, r = Int(remaining.rounded())
        let head = usedUp
            ? SettingsText("\(subscription.english) \(window.english) used up", "\(subscription.chinese) \(window.chinese) 已用完")
            : SettingsText("\(subscription.english) \(window.english) \(r)%", "\(subscription.chinese) \(window.chinese) \(r)%")
        var out: SettingsText?, outShort: SettingsText?
        if !usedUp, let m = runOutMinutes, m.isFinite {
            let t = duration(minutes: m)
            out = SettingsText("est. out in \(t)", "预估 \(t) 用完"); outShort = SettingsText("est. \(t)", "预估\(t)")
        }
        var reset: SettingsText?, resetShort: SettingsText?
        if let m = resetMinutes, m.isFinite, m > 0 {
            let t = duration(minutes: m)
            reset = SettingsText("resets in \(t)", "\(t) 后重置"); resetShort = SettingsText("resets \(t)", "\(t)后重置")
        }
        if usedUp { let s = join([head, reset]); return .init(form: .usedUp, text: s, short: s) }
        return .init(form: .quota, text: join([head, out, reset]), short: join([head, outShort, resetShort]))
    }

    /// A subscription that cannot be read (grey, list-only). `cause` is the reader failure code.
    /// `tool`: the producer row's tool id, for a cause that reads differently per tool (G3-218).
    public static func unreadable(subscription: SettingsText, cause: String?, tool: String? = nil) -> AlertSentenceText {
        let head = SettingsText("\(subscription.english) no reading", "\(subscription.chinese) 读不到")
        return .init(form: .unreadable, text: join([head, cause.flatMap { Self.cause($0, tool: tool) }]), short: head)
    }

    /// Three or more unreadable subscriptions merge into one line (the overview, the menu).
    public static func unreadableMany(_ count: Int) -> AlertSentenceText {
        let s = SettingsText(count == 1 ? "1 subscription has no reading" : "\(count) subscriptions have no reading", "\(count) 个订阅读不到")
        return .init(form: .unreadableMany, text: s, short: s)
    }

    /// The short cause after "no reading"; nil for any other failure code.
    public static func cause(_ code: String, tool: String? = nil) -> SettingsText? {
        // G3-218: Antigravity's reader reads the running app (no install step, no Node.js): runtime_missing = not running.
        if code == "runtime_missing", (tool ?? "").lowercased() == "antigravity" { return .init("not running", "未运行") }
        switch code {
        case "not_signed_in", "login_expired", "http_401", "unsupported_login": return .init("not signed in", "未登录")
        case "key_missing": return .init("key missing", "缺少密钥")
        case "keychain_unset", "keychain_denied", "keychain_canceled", "keychain_not_found", "keychain_unavailable",
             "keychain_confirmation_needed": return .init("Keychain access needed", "需要钥匙串权限")
        case "consent_required", "consent_denied", "consent_outdated", "consent_changed", "no_consent",
             "browser_session_consent_required", "privacy_blocked": return .init("needs permission", "需要授权")
        case "tool_not_found", "runtime_missing", "file_missing": return .init("not installed", "未安装")
        case "update_required", "schema_changed": return .init("update needed", "需要更新")
        case "network", "timeout", "http_5xx", "http_429", "http_403": return .init("network problem", "网络问题")
        default: return nil
        }
    }

    /// Failure codes that mean "still reading" or "nothing to read": never an unreadable (grey) alert.
    public static let notUnreadable: Set<String> = ["ok", "estimated", "not_read_yet", "reader_busy", "usage_not_reported",
        "no_usage_windows", "stale_reading", "catalogue_off", "readers_off", "no_dock_rows", "not_admitted", "cleanup_pending"]
    public static func isUnreadable(_ code: String?) -> Bool { guard let code, !code.isEmpty else { return false }; return !notUnreadable.contains(code) }

    private static func join(_ parts: [SettingsText?]) -> SettingsText {
        let p = parts.compactMap { $0 }
        return .init(p.map(\.english).joined(separator: " · "), p.map(\.chinese).joined(separator: " · "))
    }
}
