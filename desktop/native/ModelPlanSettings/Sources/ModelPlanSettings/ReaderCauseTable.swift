// SPDX-License-Identifier: MIT
import Foundation

/// What a cause's next step is. Only the card's existing "Settings" entry button is a real control today, so a
/// step that points there is `.openSettings`; every other step is plain guidance text and renders no control
/// (a dead "Retry now" or "Why?" button was the D87 slice 4 review finding).
public enum ReaderCauseTarget: String, Sendable, Equatable {
    case openSettings, guidance
    /// Whether the card or row may draw a control for this step. Only the existing Settings entry is wired.
    public var rendersControl: Bool { self == .openSettings }
}

/// One cause: a short reason and one action, in both languages.
public struct ReaderCauseEntry: Equatable, Sendable {
    public let reason: SettingsText
    public let action: SettingsText
    public let target: ReaderCauseTarget
    public init(reason: SettingsText, action: SettingsText, target: ReaderCauseTarget) {
        self.reason = reason; self.action = action; self.target = target
    }
}

/// The shared next-step table: a fixed, data-free engine cause code to a plain reason and action.
/// Codes are the engine's wire codes (`runtime_missing`, `not_found`, `rpc_error`, `region_refused`,
/// `key_missing`, `keychain_*`, ...); the ledger names `keychain_needed`, `no_key` and `consent_needed`
/// are accepted as aliases. A code without an entry returns nil and keeps the engine's own text.
public enum ReaderCauseTable {
    public static func canonical(_ code: String) -> String {
        switch code {
        case "no_key": return "key_missing"
        case "consent_needed": return "consent_required"
        case "keychain_needed", "keychain_choice_needed", "keychain_canceled", "keychain_confirmation_needed": return "keychain_unset"
        case "tool_not_found": return "not_found"
        default: return code
        }
    }

    private static func isGLM(_ tool: String?) -> Bool { ["zai", "zcode", "glm"].contains((tool ?? "").lowercased()) }

    public static func entry(code rawCode: String, tool: String? = nil, toolName: String? = nil) -> ReaderCauseEntry? {
        let name = toolName.flatMap { $0.isEmpty ? nil : $0 }
        switch canonical(rawCode) {
        case "not_found":
            return .init(reason: .init(name.map { "Can't find the \($0) command" } ?? "Can't find the tool command",
                                       name.map { "找不到 \($0) 命令" } ?? "找不到工具命令"),
                         action: .init("Check connected tools in Settings", "在设置检查已连接工具"), target: .openSettings)
        case "runtime_missing":
            return .init(reason: .init("Node.js is required", "需要 Node.js"),
                         action: .init("Install Node.js, then refresh", "安装 Node.js 后刷新"), target: .guidance)
        case "timeout":
            return .init(reason: .init("The reading timed out; it will retry on its own", "读取超时，稍后自动重试"),
                         action: .init("No action needed; it retries on its own", "无需操作，会自动重试"), target: .guidance)
        case "rpc_error":
            return .init(reason: .init(name.map { "\($0)'s background service returned an error" } ?? "The tool's background service returned an error",
                                       name.map { "\($0) 后台服务出错" } ?? "工具后台服务出错"),
                         action: .init("It retries on its own; reopen the tool if it keeps failing", "会自动重试；若持续失败请重新打开该工具"), target: .guidance)
        case "closed":
            return .init(reason: .init("The tool's background service closed unexpectedly", "工具后台服务意外退出"),
                         action: .init("It retries on its own; reopen the tool if it keeps failing", "会自动重试；若持续失败请重新打开该工具"), target: .guidance)
        case "not_signed_in":
            return .init(reason: .init("Not signed in", "未登录"),
                         action: .init(name.map { "Open \($0) and sign in" } ?? "Open the tool and sign in", name.map { "打开 \($0) 并登录" } ?? "打开工具并登录"), target: .guidance)
        case "login_expired":
            return .init(reason: .init("The sign-in has expired", "登录已过期"),
                         action: .init(name.map { "Open \($0) and sign in again" } ?? "Open the tool and sign in again", name.map { "打开 \($0) 并重新登录" } ?? "打开工具并重新登录"), target: .guidance)
        case "keychain_unset", "keychain_unavailable", "keychain_not_found":
            return .init(reason: .init("Keychain access needed", "需要允许读取钥匙串"),
                         action: .init("Allow Keychain reading in Settings", "在设置允许读取钥匙串"), target: .openSettings)
        case "keychain_denied":
            return .init(reason: .init("Keychain access was denied", "钥匙串被拒绝"),
                         action: .init("Allow it again in Settings", "在设置重新允许"), target: .openSettings)
        case "key_missing":
            if isGLM(tool) {
                return .init(reason: .init("Sign in to the GLM Coding Plan in ZCode", "在 ZCode 里登录 GLM 编程套餐"),
                             action: .init("Open ZCode and sign in", "打开 ZCode 并登录"), target: .guidance)
            }
            return .init(reason: .init("A key is needed", "需要配置密钥"),
                         action: .init("Open Settings", "在设置查看"), target: .openSettings)
        case "region_refused":
            return .init(reason: .init("This address is a third-party relay, so its quota can't be read", "这个地址是第三方转发服务，查不到额度"),
                         action: .init("Use the official address to read its quota", "改用官方地址才能读取额度"), target: .guidance)
        case "no_plan":
            // z.ai answers a key without a Coding Plan with a body code, not a server error.
            if isGLM(tool) {
                return .init(reason: .init("This key has no GLM Coding Plan", "这个密钥没有开通 GLM 编程套餐"),
                             action: .init("Use a key with a GLM Coding Plan, or subscribe to one", "换用已开通 GLM 编程套餐的密钥，或开通套餐"), target: .guidance)
            }
            return .init(reason: .init("This account has no plan to read", "这个账户没有可读取的套餐"),
                         action: .init("Check the plan with the provider", "到服务商处查看套餐"), target: .guidance)
        case "usage_not_reported":
            // D228: a current reading that has a balance but no usage percentage. Grok's X Subscription
            // billing reports only the prepaid balance, so its card says that in one line instead of "--" rows.
            let reason: SettingsText = (tool ?? "").lowercased() == "grok"
                ? .init("The X Subscription reports no usage percentage; only the balance is shown", "X 订阅不提供用量百分比，只显示余额")
                : .init(name.map { "\($0) reports no usage percentage; only the balance is shown" } ?? "No usage percentage is reported; only the balance is shown",
                        name.map { "\($0) 不提供用量百分比，只显示余额" } ?? "不提供用量百分比，只显示余额")
            return .init(reason: reason, action: .init("No action needed", "无需操作"), target: .guidance)
        case "consent_required":
            return .init(reason: .init("Reading permission needed", "需要读取授权"),
                         action: .init("Review permission in Settings", "在设置检查授权"), target: .openSettings)
        default:
            return nil
        }
    }

    /// "Last good reading 3h ago · cause: …" / "上次成功读取：3 小时前 · 原因：…" for a stale reading.
    public static func staleLine(entry: ReaderCauseEntry, ageSeconds: Int, language: SettingsLanguage) -> String {
        let age = ageText(ageSeconds, language)
        let cause = entry.reason.value(language)
        return language == .english ? "Last good reading \(age) · cause: \(cause)" : "上次成功读取：\(age) · 原因：\(cause)"
    }

    static func ageText(_ seconds: Int, _ language: SettingsLanguage) -> String {
        let minutes = max(0, seconds) / 60
        let en: String, zh: String
        if minutes < 1 { en = "under a minute ago"; zh = "不到 1 分钟前" }
        else if minutes < 60 { en = "\(minutes)m ago"; zh = "\(minutes) 分钟前" }
        else if minutes < 48 * 60 { en = "\(minutes / 60)h ago"; zh = "\(minutes / 60) 小时前" }
        else { en = "\(minutes / 1440)d ago"; zh = "\(minutes / 1440) 天前" }
        return language == .english ? en : zh
    }
}
