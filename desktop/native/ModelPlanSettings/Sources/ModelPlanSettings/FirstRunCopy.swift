// SPDX-License-Identifier: MIT
import Foundation

/// FR-9-11 (owner-approved mock, D189): the first-run page's own copy, one string table for both languages.
/// The large privacy promise and the FR-9-03 line stay in `FirstRunPage`; their wording is unchanged.
public enum FirstRunCopy {
    public static let learnMore = SettingsText("Learn more ›", "了解详情 ›")
    public static let toolsHeading = SettingsText("Tools ModelPlan reads", "读取这些工具的额度")
    public static let toolsHint = SettingsText("Untick to stop reading", "取消勾选即不读取")
    /// A tool with no system prompt: it is read as soon as Done is pressed.
    public static let detected = SettingsText("Detected · read without asking", "本机已检测到 · 无需授权")
    /// D41: a tool whose login is in the Keychain; the row carries Allow and Later.
    public static let keychainLine = SettingsText("Login is in the Keychain; macOS will ask once. Choose \u{201C}Always Allow\u{201D}.",
                                                  "登录信息在钥匙串里，macOS 会问一次，请选\u{201C}始终允许\u{201D}。")
    public static let allow = SettingsText("Allow", "允许")
    public static let later = SettingsText("Later", "稍后")
    /// The three former small-print paragraphs in one. The line about reading session files lives in Settings › Data & Privacy.
    public static let smallPrint = SettingsText(
        "Tools you install later are read too. After Done, up to 30 days of past usage is imported in the background (counts, models and times only). Change any of this in Settings › Data & Privacy.",
        "之后安装的工具默认也会读取。点\u{201C}完成\u{201D}后会在后台导入最多 30 天的过往用量（只含次数、模型和时间）。都可在 设置 › 数据与隐私 中更改。")
    public static func window(_ kind: FirstRunReadingKind) -> SettingsText {
        kind == .fiveHour ? .init("5h", "5小时") : .init("Weekly", "每周")
    }
    public static func left(_ percent: Int) -> SettingsText { .init("\(percent)% left", "剩 \(percent)%") }
}
