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

    // MARK: Scan (first run v1, owner OK 2026-11-12). The strings follow the approved demo.
    public static let looking = SettingsText("Looking for tools on this Mac…", "正在查找本机的工具…")
    public static func progress(done: Int, total: Int) -> SettingsText {
        .init("Reading · \(done) of \(total) done", "正在读取 · \(done)/\(total) 完成")
    }
    public static func found(_ count: Int) -> SettingsText {
        .init("\(count) found · untick to stop reading", "找到 \(count) 个工具 · 取消勾选即不读取")
    }
    public static let engineStarting = SettingsText("Starting the reader…", "正在启动读取引擎…")
    public static func engineWaiting(_ seconds: Int) -> SettingsText {
        .init("Starting the reader · \(seconds) s so far. The first start takes longer; the tools below are already listed.",
              "正在启动读取引擎 · 已等 \(seconds) 秒。第一次会慢一些，可以先看看下面的工具。")
    }
    public static func engineSlow(_ seconds: Int) -> SettingsText {
        .init("The reader still isn\u{2019}t ready (\(seconds) s), much slower than usual. Keep waiting, or close this window and pick up next time.",
              "读取引擎还没好（已等 \(seconds) 秒），比平时慢很多。可以继续等，也可以先关掉窗口，下次打开接着来。")
    }
    public static let engineFailed = SettingsText("The reader didn\u{2019}t start, so quota can\u{2019}t be read and your choices can\u{2019}t be saved yet.",
                                                  "读取引擎没能启动，暂时读不了额度，选择也保存不了。")
    public static let retry = SettingsText("Try again", "重试")
    public static let waitingForReader = SettingsText("Detected on this Mac · read when the reader is ready", "本机已检测到 · 等引擎就绪后读取")
    public static let finding = SettingsText("Looking…", "正在查找…")
    public static let reading = SettingsText("Detected on this Mac · reading…", "本机已检测到 · 正在读取…")
    public static func readingSlow(_ seconds: Int) -> SettingsText {
        .init("Still reading · \(seconds) s. You can press Done now; it joins the Quota Widget when it arrives.",
              "还在读取 · 已等 \(seconds) 秒。可以先点\u{201C}完成\u{201D}，读到后会自动出现在额度挂件上。")
    }
    public static let couldNotRead = SettingsText("Couldn\u{2019}t read it this time (waited 15 s). It\u{2019}s retried in the background after Done.",
                                                  "这次没读到（等了 15 秒）。完成后会在后台再试。")
    public static let notRead = SettingsText("Not read", "不读取")
    public static func notFound(names: [String]) -> SettingsText {
        let shown = names.prefix(3).joined(separator: ", "), rest = names.count - 3
        return .init("Not on this Mac: " + shown + (rest > 0 ? " and \(rest) more" : "") + " ›",
                     "本机没找到：" + names.prefix(3).joined(separator: "、") + (rest > 0 ? " 等 \(names.count) 个" : "") + " ›")
    }
    public static let notFoundOpen = SettingsText("Not on this Mac (read automatically once installed):", "本机没找到这些（装好后会自动读取）：")
    public static let emptyTitle = SettingsText("No supported tools found on this Mac yet", "这台 Mac 上还没找到支持的工具")
    public static let emptyBody = SettingsText(
        "ModelPlan supports 13 tools, including Claude Code, Codex and ZCode / GLM. Once one is installed and signed in, it\u{2019}s read automatically; no need to come back here.",
        "ModelPlan 支持 Claude Code、Codex、ZCode / GLM 等 13 个工具。装好并登录后会自动读取，不用回到这里。")
    public static let lookAgain = SettingsText("Look again", "重新查找")
    // Why Done is disabled (owner 11-12, answer 3).
    public static let needEngine = SettingsText("Your choices can be saved once the reader is ready.", "读取引擎就绪后才能保存选择。")
    public static let needOne = SettingsText("Tick at least one tool.", "至少勾选一个工具。")
    public static let rejected = SettingsText("Your choices couldn\u{2019}t be saved. Press Done again.", "选择没能保存，请再点一次\u{201C}完成\u{201D}。")
    // The menu bar while setup is not finished (E6).
    public static let menuSettingUp = SettingsText("ModelPlan is setting up\u{2026}", "ModelPlan 正在设置\u{2026}")
    public static let menuContinue = SettingsText("Continue Setup\u{2026}", "继续设置\u{2026}")
    public static let menuTip = SettingsText("ModelPlan is setting up · click to return to setup", "ModelPlan 正在设置 · 点按回到设置窗口")
}
