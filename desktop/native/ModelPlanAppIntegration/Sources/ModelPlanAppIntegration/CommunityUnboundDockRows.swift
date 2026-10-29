// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanCore
import ModelPlanDock
import ModelPlanSettings

/// Presentation locators never assert a subscription ref or verified account join.
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
    static func make(_ snapshot: JoinedSnapshot, diagnostics: StoreDiagnostics, now: Date,
                     canonicalConsent: ConsentPreview? = nil) -> [CommunityUnboundDockRow] {
        let readable = CommunityReaderReason.isReadable(snapshot, diagnostics: diagnostics, now: now)
        let allowed = Set((canonicalConsent?.mode == .off ? [] : canonicalConsent?.tools ?? []).filter(\.allowed).map { canonical($0.id) })
        let connections = snapshot.personal.connections ?? []
        let sources = snapshot.personal.sources ?? []
        func guidance(_ provider: String, current: Bool) -> (String, String) {
            let source = sources.first { $0.source == "native:" + provider }
            let connection = connections.first { canonical($0.id) == provider }
            func next(_ fallback: String) -> String {
                guard let text = source?.nextStep ?? connection?.quota?.nextStep,
                      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.utf8.count <= 512,
                      !text.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else { return fallback }
                return text
            }
            if current { return ("Local account reading / 本地账户读数", next("Check connected tools in Settings / 在设置检查已连接工具")) }
            let status = source?.status ?? connection?.quota?.status
            let nativeFailure = source.map { ["consent_required", "unavailable", "error", "stale", "expired", "unsupported_schema", "keychain_choice_needed", "keychain_denied"].contains($0.status) } ?? false
            let code = nativeFailure ? source?.reason ?? source?.status : source?.reason ?? connection?.quota?.reason ?? connection?.quotaAccess?.blocked ?? status
            if provider == "claude", ["consent_required", "keychain_choice_needed", "keychain_denied"].contains(code ?? "") {
                return (code == "keychain_denied" ? "Keychain permission denied / 钥匙串许可被拒绝" : "Keychain permission required / 需要钥匙串许可",
                        next("Allow Keychain for Claude Code in Settings / 在设置允许Claude Code使用钥匙串"))
            }
            if !nativeFailure, allowed.contains(provider),
               ["missing", "no-reading", "not-enabled", "not read yet", "not-read-yet", "not_read_yet", "pending"].contains(status ?? "") || ["missing", "not read yet", "not-read-yet", "not_read_yet", "pending"].contains(code ?? "") || code == nil {
                return ("Waiting for first reading / 等待首次读取", next("Check this tool in Settings / 在设置检查此工具"))
            }
            switch code {
            case "consent_required": return ("Reader permission required / 需要读取许可", next("Review consent in Settings / 在设置检查授权"))
            case "not_detected": return ("Reader not detected / 未检测到读取组件", next("Sign in to the tool, then check Settings / 登录工具后在设置检查"))
            case "expired", "stale": return ("Reading expired / 读数已过期", next("Check this tool in Settings / 在设置检查此工具"))
            case "unsupported_schema": return ("Reader update required / 需要更新读取组件", next("Check component updates in Settings / 在设置检查组件更新"))
            case "reader_error", "parse_error", "timeout", "runtime_missing", "error", "unavailable": return ("Reading unavailable / 读取暂不可用", next("Check reader status in Settings / 在设置检查读取状态"))
            default: return ("No current reading / 暂无当前读数", next("Check connected tools in Settings / 在设置检查已连接工具"))
            }
        }
        var result: [CommunityUnboundDockRow] = [], represented = Set<String>(), emitted = Set<String>()
        var used = Set((snapshot.personal.subscriptions ?? []).map(\.subscriptionRef) + (snapshot.personal.accounts ?? []).compactMap { $0.subscription?.subscriptionRef })
        func locator(_ base: String) -> String { var id = base; while used.contains(id) { id += "." }; used.insert(id); return id }
        var offset = 0
        for (index, account) in (snapshot.personal.accounts ?? []).enumerated() {
            let provider = canonical(account.source), windows = account.windows ?? []
            defer { offset += windows.count }
            represented.insert(provider)
            var current = false
            let values = windows.enumerated().map { wi, window -> DockQuotaWindowInput in
                let position = offset + wi
                let quota = snapshot.presentation.quotas.indices.contains(position) ? snapshot.presentation.quotas[position] : nil
                let bound = account.subscription?.subscriptionRef.isEmpty == false
                let valid = readable && account.stale != true && quota?.source == account.source && quota?.kind == window.kind && quota?.reason == nil && quota?.observedAt.map { $0 <= now } == true && window.reason == nil && window.unknownReason == nil && (!bound || account.subscription?.status == "verified")
                current = current || (valid && quota?.remaining != nil)
                return .init(id: "account.\(index).window.\(wi)", period: .other, label: window.kind, remainingPercent: valid ? quota?.remaining : nil, resetsAt: valid ? window.resetsAt?.date : nil, durationSeconds: nil)
            }
            let id: String
            if let ref = account.subscription?.subscriptionRef, !ref.isEmpty { id = ref }
            else { id = locator("presentation.account.\(index)") }
            guard emitted.insert(id).inserted else { continue }
            let (reason, next) = guidance(provider, current: current)
            var input = DockInstrumentInput(id: id, name: title(provider), windows: values)
            input.vendorResourceKey = provider == "codex" ? "openai" : provider == "claude" ? "claude" : nil
            input.dataState = current ? .fresh : .unavailable
            if !current { input.alias = title(provider) + " · " + reason }
            result.append(.init(input: input, reason: reason, nextStep: next, originalObservedAt: account.observedAt?.date))
        }
        var providers: [String] = []
        for tool in canonicalConsent?.tools ?? [] where allowed.contains(canonical(tool.id)) {
            let key = canonical(tool.id); if !providers.contains(key) { providers.append(key) }
        }
        for source in sources where source.source.hasPrefix("native:") {
            let key = canonical(source.source); if !providers.contains(key) { providers.append(key) }
        }
        for connection in connections where allowed.contains(canonical(connection.id)) {
            let key = canonical(connection.id); if !providers.contains(key) { providers.append(key) }
        }
        for (index, provider) in providers.enumerated() where !represented.contains(provider) {
            let (reason, next) = guidance(provider, current: false)
            var input = DockInstrumentInput(id: locator("presentation.connection.\(index)"), name: title(provider), windows: [])
            input.alias = title(provider) + " · " + reason; input.dataState = .unavailable
            result.append(.init(input: input, reason: reason, nextStep: next, originalObservedAt: connections.first { canonical($0.id) == provider }?.quota?.at?.date))
        }
        return result
    }
    private static func canonical(_ value: String) -> String {
        var id = value.lowercased()
        for prefix in ["native:", "codexbar:"] where id.hasPrefix(prefix) { id = String(id.dropFirst(prefix.count)) }
        return id == "claude-code" ? "claude" : id == "openai" ? "codex" : id
    }
    private static func title(_ id: String) -> String {
        SettingsConnectionTool(rawValue: id)?.title ?? (id == "amp" ? "Amp" : "Reader / 用量读取")
    }
}
