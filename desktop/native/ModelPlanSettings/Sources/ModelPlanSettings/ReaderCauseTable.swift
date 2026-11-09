// SPDX-License-Identifier: MIT
import Foundation

/// Where a cause's one action leads. The card and the Settings row share this table (D87 slice 4);
/// the card keeps its single "Settings" entry button until the Subscriptions rows wire the targets.
public enum ReaderCauseTarget: String, Sendable, Equatable {
    case installNode, chooseToolLocation, retry, allowKeychain, openTool, openSettings, explain
    /// D87 slice 6: open the tool's install page (kiro-cli) or reveal the manual key entry (D90).
    case installTool, addKey
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

    private static func isKiro(_ tool: String?) -> Bool { (tool ?? "").lowercased() == "kiro" }
    private static func isKeyProvider(_ tool: String?) -> Bool { isGLM(tool) || ["opencodego", "opencode"].contains((tool ?? "").lowercased()) }

    /// `keyEntryAvailable`: the app can show the manual key entry (D90). A missing key then offers "Add key"
    /// for the key-based providers, after auto-detect found nothing.
    public static func entry(code rawCode: String, tool: String? = nil, toolName: String? = nil,
                             keyEntryAvailable: Bool = false) -> ReaderCauseEntry? {
        let name = toolName.flatMap { $0.isEmpty ? nil : $0 }
        let canon = canonical(rawCode)
        if isKiro(tool) {
            switch canon {
            case "not_found", "runtime_missing":
                return .init(reason: .init("kiro-cli was not found", "没有找到 kiro-cli"),
                             action: .init("Install kiro-cli", "安装 kiro-cli"), target: .installTool)
            case "not_signed_in", "login_expired", "unsupported_login":
                return .init(reason: .init("Not signed in to kiro-cli", "尚未登录 kiro-cli"),
                             action: .init("Sign in to kiro-cli", "登录 kiro-cli"), target: .explain)
            default: break
            }
        }
        if canon == "key_missing", keyEntryAvailable, isKeyProvider(tool) {
            return .init(reason: isGLM(tool) ? .init("No GLM Coding Plan sign-in found in ZCode", "ZCode 里没有找到 GLM 编程套餐的登录")
                                              : .init("No OpenCode Go key found", "没有找到 OpenCode Go 的密钥"),
                         action: .init("Add key", "添加密钥"), target: .addKey)
        }
        switch canon {
        case "not_found":
            return .init(reason: .init(name.map { "Can't find the \($0) command" } ?? "Can't find the tool command",
                                       name.map { "找不到 \($0) 命令" } ?? "找不到工具命令"),
                         action: .init(name.map { "Choose \($0) location…" } ?? "Choose location…",
                                       name.map { "选择 \($0) 位置…" } ?? "选择位置…"), target: .chooseToolLocation)
        case "runtime_missing":
            return .init(reason: .init("Node.js is required", "需要 Node.js"),
                         action: .init("Install Node.js", "安装 Node.js"), target: .installNode)
        case "timeout":
            return .init(reason: .init("The reading timed out; it will retry on its own", "读取超时，稍后自动重试"),
                         action: .init("Retry now", "立即重试"), target: .retry)
        case "rpc_error":
            return .init(reason: .init(name.map { "\($0)'s background service returned an error" } ?? "The tool's background service returned an error",
                                       name.map { "\($0) 后台服务出错" } ?? "工具后台服务出错"),
                         action: .init("Retry", "重试"), target: .retry)
        case "closed":
            return .init(reason: .init("The tool's background service closed unexpectedly", "工具后台服务意外退出"),
                         action: .init("Retry", "重试"), target: .retry)
        case "not_signed_in":
            return .init(reason: .init("Not signed in", "未登录"),
                         action: .init(name.map { "Open \($0)" } ?? "Open the tool", name.map { "打开 \($0)" } ?? "打开工具"), target: .openTool)
        case "login_expired":
            return .init(reason: .init("The sign-in has expired", "登录已过期"),
                         action: .init(name.map { "Open \($0)" } ?? "Open the tool", name.map { "打开 \($0)" } ?? "打开工具"), target: .openTool)
        case "keychain_unset", "keychain_unavailable", "keychain_not_found":
            return .init(reason: .init("Keychain access needed", "需要允许读取钥匙串"),
                         action: .init("Allow reading", "允许读取"), target: .allowKeychain)
        case "keychain_denied":
            return .init(reason: .init("Keychain access was denied", "钥匙串被拒绝"),
                         action: .init("How to allow it", "查看允许方法"), target: .explain)
        case "key_missing":
            if isGLM(tool) {
                return .init(reason: .init("Sign in to the GLM Coding Plan in ZCode", "在 ZCode 里登录 GLM 编程套餐"),
                             action: .init("Open ZCode", "打开 ZCode"), target: .openTool)
            }
            return .init(reason: .init("A key is needed", "需要配置密钥"),
                         action: .init("Open Settings", "在设置查看"), target: .openSettings)
        case "region_refused":
            return .init(reason: .init("This address is a third-party relay, so its quota can't be read", "这个地址是第三方转发服务，查不到额度"),
                         action: .init("Why?", "了解原因"), target: .explain)
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
