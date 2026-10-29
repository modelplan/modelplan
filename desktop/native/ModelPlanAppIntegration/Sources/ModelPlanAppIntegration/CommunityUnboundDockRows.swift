// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanCore
import ModelPlanDock

/// Presentation locators are not subscription refs or verified account joins.
struct CommunityUnboundDockRow: Sendable {
    let input: DockInstrumentInput
    let reason: String
    let nextStep: String
    let originalObservedAt: Date?
    func sourceAndAge(at now: Date) -> String {
        guard let originalObservedAt else { return "Observation time unknown / 观测时间未知" }
        let age = now.timeIntervalSince(originalObservedAt)
        guard age.isFinite, age >= 0, age < Double(Int.max) else { return "Observation time unknown / 观测时间未知" }
        return "Observed \(Int(age))s ago / \(Int(age))秒前观测"
    }
}
enum CommunityUnboundDockRows {
    static func make(_ snapshot: JoinedSnapshot, diagnostics: StoreDiagnostics, now: Date) -> [CommunityUnboundDockRow] {
        let readable = CommunityReaderReason.isReadable(snapshot, diagnostics: diagnostics, now: now)
        var result: [CommunityUnboundDockRow] = []
        var offset = 0
        var represented = Set<String>()
        var used = Set((snapshot.personal.subscriptions ?? []).map(\.subscriptionRef) +
                       (snapshot.personal.accounts ?? []).compactMap { $0.subscription?.subscriptionRef })
        func locator(_ base: String) -> String {
            var value = base
            while used.contains(value) { value += "." }
            used.insert(value); return value
        }
        for (index, account) in (snapshot.personal.accounts ?? []).enumerated() {
            let windows = account.windows ?? []
            defer { offset += windows.count }
            if account.subscription?.subscriptionRef.isEmpty == false { represented.insert(account.source); continue }
            let provider = account.source
            var current = false
            let values = windows.enumerated().map { wi, window -> DockQuotaWindowInput in
                let position = offset + wi
                let quota = snapshot.presentation.quotas.indices.contains(position) ? snapshot.presentation.quotas[position] : nil
                let valid = readable && account.stale != true && quota?.source == provider &&
                    quota?.kind == window.kind && quota?.reason == nil &&
                    quota?.observedAt.map { $0 <= now } == true &&
                    window.reason == nil && window.unknownReason == nil
                current = current || (valid && quota?.remaining != nil)
                return .init(id: "account.\(index).window.\(wi)", period: .other, label: window.kind,
                    remainingPercent: valid ? quota?.remaining : nil,
                    resetsAt: valid ? window.resetsAt?.date : nil, durationSeconds: nil)
            }
            var input = DockInstrumentInput(id: locator("presentation.account.\(index)"), name: title(provider), windows: values)
            input.vendorResourceKey = provider == "codex" || provider == "openai" ? "openai" : provider == "claude" || provider == "claude-code" ? "claude" : nil
            input.dataState = current ? .fresh : .unavailable
            if !current { input.alias = "Check Settings / 检查设置" }
            result.append(.init(input: input,
                reason: current ? "Local account reading / 本地账户读数" : "Account reading unavailable / 账户读数不可用",
                nextStep: "Check connected tools in Settings / 在设置检查已连接工具",
                originalObservedAt: account.observedAt?.date))
            represented.insert(provider)
        }
        for (index, connection) in (snapshot.personal.connections ?? []).enumerated() {
            guard connection.authorization?.status == "yes", !represented.contains(connection.id) else { continue }
            let reason: String
            switch connection.quota?.reason ?? connection.quotaAccess?.blocked {
            case "consent_required": reason = connection.id == "claude" || connection.id == "claude-code" ?
                "Allow Keychain for Claude Code in Settings / 在设置允许Claude Code使用钥匙串" :
                "Review reader consent in Settings / 在设置检查读取授权"
            case "not_detected", "missing": reason = "Reader not detected / 未检测到读取组件"
            case "reader_error": reason = "Reader could not obtain a reading / 读取组件未能取得读数"
            default: reason = "No current reading / 暂无当前读数"
            }
            var input = DockInstrumentInput(id: locator("presentation.connection.\(index)"), name: title(connection.id), windows: [])
            input.dataState = .unavailable
            input.alias = "Check Settings / 检查设置"
            result.append(.init(input: input, reason: reason,
                nextStep: "Open Settings to check this tool / 打开设置检查此工具",
                originalObservedAt: connection.quota?.at?.date))
            represented.insert(connection.id)
        }
        return result
    }
    private static func title(_ id: String) -> String {
        switch id {
        case "codex", "openai": return "Codex"
        case "claude", "claude-code": return "Claude Code"
        case "copilot": return "Copilot"
        case "cursor": return "Cursor"
        case "gemini": return "Gemini"
        case "grok": return "Grok"
        case "kimi": return "Kimi"
        case "kiro": return "Kiro"
        case "opencodego": return "OpenCode"
        case "zai": return "Z.ai"
        default: return "Reader / 用量读取"
        }
    }
}

