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
    public init(reason: SettingsText, action: SettingsText, target: RowFixTarget) {
        self.reason = reason; self.action = action; self.target = target
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
        let name = toolName.flatMap { $0.isEmpty ? nil : $0 }
        let canon = canonical(rawCode)
        if rowIsKiro(tool) {
            switch canon {
            case "not_found", "runtime_missing":
                return .init(reason: .init("kiro-cli was not found", "没有找到 Kiro 命令行工具"),
                             action: .init("Install kiro-cli", "安装 Kiro 命令行工具"), target: .installTool)
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
        switch canon {
        case "not_found":
            // No path setting exists in the engine, so the hint says what to do and links to the install page.
            let codex = (tool ?? "").lowercased() == "codex"
            let reason: SettingsText
            if codex { reason = .init("Install the Codex CLI, or make sure Codex runs from a terminal", "安装 Codex CLI，或确认 Codex 在命令行里能运行") }
            else if let name { reason = .init("Install \(name), or make sure it runs from a terminal", "安装 \(name)，或确认它在命令行里能运行") }
            else { reason = .init("Install the tool, or make sure it runs from a terminal", "安装这个工具，或确认它在命令行里能运行") }
            return .init(reason: reason, action: .init("Open install page", "打开安装页面"), target: .installTool)
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
            if rowIsGLM(tool) {
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
}
