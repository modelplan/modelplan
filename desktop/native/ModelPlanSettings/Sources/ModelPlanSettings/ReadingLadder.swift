// SPDX-License-Identifier: MIT
import Foundation

/// Master spec §3.4 (D474): one reading ladder, the same words on every surface. An unreadable subscription's card says
/// `读不到 · <why>` and the one step that fixes it. `action` is the step's words (a button only where one is wired:
/// "重新读取", and D41's "允许读取" for the Keychain); `title` is the card's state line.
public struct ReadingLadderEntry: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case needsPermission, signInNeeded, notRunning, cannotParse, needsCLI, notReported }
    public let kind: Kind
    public let title: SettingsText
    public let detail: SettingsText?
    public let action: SettingsText
}

public enum ReadingLadder {
    public static let noReading = SettingsText("No reading", "读不到")
    /// The rung for an engine failure code; nil keeps the cause table's own words.
    public static func entry(code rawCode: String, tool: String? = nil, toolName: String? = nil) -> ReadingLadderEntry? {
        let code = ReaderCauseTable.canonical(rawCode), id = (tool ?? "").lowercased()
        let name = toolName.flatMap { $0.isEmpty ? nil : $0 } ?? (tool ?? "")
        func rung(_ kind: ReadingLadderEntry.Kind, _ en: String, _ zh: String, detail: SettingsText? = nil, action: SettingsText) -> ReadingLadderEntry {
            .init(kind: kind, title: .init("No reading · " + en, "读不到 · " + zh), detail: detail, action: action)
        }
        switch code {
        case "consent_required", "consent_denied", "consent_outdated", "consent_changed", "no_consent", "browser_session_consent_required",
             "privacy_blocked", "keychain_unset", "keychain_unavailable", "keychain_not_found", "keychain_denied":
            return rung(.needsPermission, "Needs permission", "需要授权", action: .init("Allow reading", "允许读取"))
        case "not_signed_in", "login_expired", "http_401":
            return rung(.signInNeeded, "Sign in needed", "需要登录", action: .init("Open \(name)", "打开 \(name)"))
        case "runtime_missing" where id == "antigravity":
            return rung(.notRunning, "Not running", "没在运行", action: .init("Open \(name)", "打开 \(name)"))
        case "runtime_missing" where id == "kiro", "not_found":
            return rung(.needsCLI, "Needs \(name) CLI", "需要安装 \(name) CLI", action: .init("Install guide", "安装说明"))
        case "schema_changed", "unknown_store_format", "update_required":
            return rung(.cannotParse, "Can't parse reading", "读数无法解析", action: .init("Read again", "重新读取"))
        case "no_usage_windows":
            // Build 6 said "未读取 / 未报告用量窗口 / 等待下一次可用读数" (master spec §3.4).
            return .init(kind: .notReported, title: noReading,
                         detail: .init("\(name) reported no quota this time", "\(name) 这次没有报告额度"), action: .init("Read again", "重新读取"))
        default:
            return nil
        }
    }
}
