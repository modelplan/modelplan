// SPDX-License-Identifier: MIT
import Foundation

/// D87 slice 6: where one fix button on a Subscriptions row leads. The Settings rows are real, wired controls,
/// so they carry the full set; the widget card and Settings source column keep `ReaderCauseTarget`, where only
/// the Settings entry is a control (D87 slice 4 review).
public enum RowFixTarget: String, Sendable, Equatable {
    case installNode, retry, allowKeychain, openTool, openSettings, explain
    /// Open the tool's install page (kiro-cli) or reveal the manual key entry (D90).
    case installTool, addKey
}

/// One row cause: a short reason and one fix action, in both languages.
public struct RowFixEntry: Equatable, Sendable {
    public let reason: SettingsText
    public let action: SettingsText
    public let target: RowFixTarget
    /// A plain fact with nothing to fix (the card says "No action needed"): no attention flag and no button.
    public let isInformational: Bool
    public init(reason: SettingsText, action: SettingsText, target: RowFixTarget, isInformational: Bool = false) {
        self.reason = reason; self.action = action; self.target = target; self.isInformational = isInformational
    }
}

extension ReaderCauseTable {
    private static func rowIsGLM(_ tool: String?) -> Bool { ["zai", "zcode", "glm"].contains((tool ?? "").lowercased()) }
    private static func rowIsKiro(_ tool: String?) -> Bool { (tool ?? "").lowercased() == "kiro" }
    private static func rowIsKeyProvider(_ tool: String?) -> Bool { rowIsGLM(tool) || ["opencodego", "opencode"].contains((tool ?? "").lowercased()) }

    /// `keyEntryAvailable`: the app can show the manual key entry (D90). A missing key then offers "Add key"
    /// for the key-based providers, after auto-detect found nothing.
    public static func rowEntry(code rawCode: String, tool: String? = nil, toolName: String? = nil,
                             keyEntryAvailable: Bool = false) -> RowFixEntry? {
        let card = entry(code: rawCode, tool: tool, toolName: toolName)
        guard let fix = rowFix(code: rawCode, tool: tool, toolName: toolName, keyEntryAvailable: keyEntryAvailable) else {
            // A cause only the card knows (usage_not_reported): the card's sentence and its own (no-action) text, explain-only.
            return card.map { .init(reason: $0.reason, action: $0.action, target: .explain, isInformational: true) }
        }
        // WP-16 / SET-9-51: the cause sentence is the card's (`entry`); only the action and target are the row's own.
        guard let card else { return fix }
        return .init(reason: card.reason, action: fix.action, target: fix.target)
    }

    private static func rowFix(code rawCode: String, tool: String?, toolName: String?, keyEntryAvailable: Bool) -> RowFixEntry? {
        let name = toolName.flatMap { $0.isEmpty ? nil : $0 }
        let canon = canonical(rawCode)
        if rowIsKiro(tool) {
            switch canon {
            case "not_found":
                return .init(reason: .init("kiro-cli was not found", "没有找到 Kiro 命令行工具"),
                             action: .init("Install kiro-cli", "安装 Kiro 命令行工具"), target: .installTool)
            case "runtime_missing":
                // Also the cause when the configured kiro-cli path names a file that cannot start: reinstalling would not help.
                return .init(reason: .init("kiro-cli was not found or could not start", "没有找到 Kiro 命令行工具，或它无法启动"),
                             action: .init("Install kiro-cli, or check the kiro-cli path you configured", "安装 Kiro 命令行工具，或检查你配置的 Kiro 命令行工具路径"), target: .installTool)
            case "not_signed_in", "login_expired", "unsupported_login":
                return .init(reason: .init("Not signed in to kiro-cli", "尚未登录 Kiro 命令行工具"),
                             action: .init("Sign in to kiro-cli", "登录 Kiro 命令行工具"), target: .explain)
            default: break
            }
        }
        if canon == "key_missing", keyEntryAvailable, rowIsKeyProvider(tool) {
            return .init(reason: rowIsGLM(tool) ? .init("No GLM Coding Plan sign-in found in ZCode", "ZCode 里没有找到 GLM 编程套餐的登录")
                                              : .init("No OpenCode Go key found", "没有找到 OpenCode Go 的密钥"),
                         action: .init("Add key", "添加密钥"), target: .addKey)
        }
        if rowIsGLM(tool), canon == "unsupported_login" || canon == "unknown_store_format" {
            // Owner 11-22: the action opens the D90 key field on this row directly; without key entry it opens Settings.
            return .init(reason: zcodeUnreadable.reason, action: .init("Paste key…", "粘贴 key…"), target: keyEntryAvailable ? .addKey : .openSettings)
        }
        if rowIsGLM(tool), ["keychain_unset", "keychain_unavailable", "keychain_denied"].contains(canon) {
            // D380: one button, the same Keychain consent as Claude Code's; macOS then asks (Always Allow).
            return .init(reason: .init("ZCode may keep its sign-in key in the Keychain", "ZCode 的登录密钥可能保存在钥匙串中"),
                         action: .init("Allow reading", "允许读取"), target: .allowKeychain)
        }
        if canon == "region_refused", keyEntryAvailable, rowIsKeyProvider(tool) {
            // SET-9-41: a third-party relay address cannot be read, but the user can still enter a key of their own, which goes
            // only to the official host; the row says why and offers the same Add key entry.
            return .init(reason: .init("This address is a third-party relay, so its quota can't be read", "这个地址是第三方转发服务，查不到额度"),
                         action: .init("Add key", "添加密钥"), target: .addKey)
        }
        switch canon {
        case "not_found":
            // No path setting exists in the engine, so the hint says what to do and links to the install page.
            let codex = (tool ?? "").lowercased() == "codex"
            let reason: SettingsText
            if codex { reason = .init("Install the Codex CLI, or make sure Codex runs from a terminal", "安装 Codex CLI，或确认 Codex 在命令行里能运行") }
            else if let name { reason = .init("Install \(name), or make sure it runs from a terminal", "安装 \(name)，或确认它在命令行里能运行") }
            else { reason = .init("Install the tool, or make sure it runs from a terminal", "安装这个工具，或确认它在命令行里能运行") }
            return .init(reason: reason, action: .init("Open install page", "打开安装页面"), target: .installTool)
        case "runtime_missing" where (tool ?? "").lowercased() == "antigravity":
            // The app is not open (no Node.js involved): the row's button opens Antigravity.
            return .init(reason: .init("Antigravity is not running, or its local service was not found", "没有检测到运行中的 Antigravity"),
                         action: .init("Open Antigravity", "打开 Antigravity"), target: .openTool)
        case "runtime_missing":
            return .init(reason: .init("Node.js is required", "需要运行环境"),
                         action: .init("Install Node.js", "安装运行环境"), target: .installNode)
        case "schema_changed" where (tool ?? "").lowercased() == "codex":
            // Owner bad case 2026-11-28: the row's button opens the install page to update the Codex CLI.
            return .init(reason: codexOutdated.reason, action: codexOutdated.action, target: .installTool)
        case "parse_error", "schema_changed":
            return .init(reason: .init("The saved reading could not be parsed", "无法解析保存的读数"),
                         action: .init("Open Settings", "打开设置"), target: .openSettings)
        case "http_401":
            return .init(reason: .init("The sign-in was rejected", "登录信息被拒绝"),
                         action: .init("Check the sign-in", "检查登录状态"), target: .openTool)
        case "http_403":
            return .init(reason: .init("The provider refused access", "服务商拒绝了访问"),
                         action: .init("Review access with the provider", "向服务商检查访问权限"), target: .explain)
        case "http_429":
            return .init(reason: .init("The provider is receiving too many requests", "服务商请求过于频繁"),
                         action: .init("Wait a moment, then retry", "稍后再试"), target: .retry)
        case "http_5xx":
            return .init(reason: .init("The provider service is unavailable", "服务商暂时不可用"),
                         action: .init("Retry later", "稍后重试"), target: .retry)
        case "network":
            return .init(reason: .init("The reading could not reach the provider", "无法连接服务商"),
                         action: .init("Check the connection, then retry", "检查连接后重试"), target: .retry)
        case "file_missing", "file_unreadable":
            return .init(reason: .init("The local sign-in data could not be read", "无法读取本地登录数据"),
                         action: .init("Open the tool and check its sign-in", "打开工具并检查登录状态"), target: .openTool)
        case "unsupported_login", "team_unsupported", "codex_custom_provider":
            return .init(reason: .init("This sign-in type is not supported for reading", "暂不支持读取此登录类型"),
                         action: .init("Use a supported sign-in", "改用受支持的登录方式"), target: .explain)
        case "other":
            return .init(reason: .init("The reading failed", "读取失败"),
                         action: .init("Retry the reading", "重试读取"), target: .retry)
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
            if rowIsGLM(tool) {
                // D369: ZCode's QR-code sign-in has ended; ModelPlan never renews it.
                return .init(reason: .init("The ZCode sign-in has ended", "ZCode 登录已失效"),
                             action: .init("Sign in to ZCode again", "重新登录 ZCode"), target: .openTool)
            }
            return .init(reason: .init("The sign-in has expired", "登录已过期"),
                         action: .init(name.map { "Open \($0)" } ?? "Open the tool", name.map { "打开 \($0)" } ?? "打开工具"), target: .openTool)
        case "keychain_unset", "keychain_unavailable", "keychain_not_found":
            return .init(reason: .init("Keychain access needed", "需要允许读取钥匙串"),
                         action: .init("Allow reading", "允许读取"), target: .allowKeychain)
        case "keychain_denied":
            return .init(reason: .init("Keychain access was denied", "钥匙串被拒绝"),
                         action: .init("How to allow it", "查看允许方法"), target: .explain)
        case "key_missing":
            if rowIsGLM(tool) {
                return .init(reason: .init("Sign in to the GLM Coding Plan in ZCode", "在 ZCode 里登录 GLM 编程套餐"),
                             action: .init("Open ZCode", "打开 ZCode"), target: .openTool)
            }
            return .init(reason: .init("A key is needed", "需要配置密钥"),
                         action: .init("Open Settings", "在设置查看"), target: .openSettings)
        case "no_plan":
            if rowIsGLM(tool) {
                return .init(reason: .init("This key has no GLM Coding Plan", "这个密钥没有开通 GLM 编程套餐"),
                             action: .init("Use a key with a GLM Coding Plan", "换用已开通 GLM 编程套餐的密钥"), target: .explain)
            }
            return .init(reason: .init("This account has no plan to read", "这个账户没有可读取的套餐"),
                         action: .init("Check the plan with the provider", "向服务商确认套餐"), target: .explain)
        case "region_refused":
            return .init(reason: .init("This address is a third-party relay, so its quota can't be read", "这个地址是第三方转发服务，查不到额度"),
                         action: .init("Why?", "了解原因"), target: .explain)
        case "consent_required":
            if rowIsGLM(tool) {
                // D369: ZCode's QR-code sign-in was found; its own permission is off by default.
                return .init(reason: .init("ZCode sign-in found; reading it needs your permission", "已找到 ZCode 登录，读取需要你的授权"),
                             action: .init("Allow in Settings", "在设置中允许"), target: .openSettings)
            }
            return .init(reason: .init("Reading permission needed", "需要读取授权"),
                         action: .init("Review permission in Settings", "在设置检查授权"), target: .openSettings)
        default:
            return nil
        }
    }
}
