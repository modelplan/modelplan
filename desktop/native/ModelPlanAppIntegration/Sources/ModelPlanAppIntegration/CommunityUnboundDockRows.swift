// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanCore
import ModelPlanDock
import ModelPlanSettings

/// Presentation locators never assert a subscription ref or verified account join.
public enum DockCardReadingState: Equatable, Sendable { case ok, loading, stale, errorLastGood, error }
public struct DockWindowObservation: Sendable {
    public let sourceName: String
    public let observedAt: Date?
    // Retained provenance conveys neither a numeric reading nor an active reset deadline.
    var verifiedRetained = false
}

public struct DockContentRow: Sendable {
    public let input: DockInstrumentInput
    public let reason: String
    public let nextStep: String
    /// D41: the label of a local action the card offers for this row; empty when none.
    public var actionLabel = ""
    public let originalObservedAt: Date?
    public let plan:String, sourceName:String
    public let resetTimes:[String:Date]
    public let windowDescriptions:[String:String]
    public let additionalRows:[DockCardRow]
    let resetCountExpiry: Date?
    public let links: [DockCardLink]
    public let windowObservations: [String: DockWindowObservation]?
    public let cardReadingState: DockCardReadingState
    public init(input: DockInstrumentInput, reason: String, nextStep: String, originalObservedAt: Date? = nil,
                plan:String="",sourceName:String="",resetTimes:[String:Date]=[:],windowDescriptions:[String:String]=[:],additionalRows:[DockCardRow]=[],resetCountExpiry: Date? = nil,links:[DockCardLink]=[],windowObservations:[String:DockWindowObservation]?=nil,cardReadingState:DockCardReadingState?=nil) {
        self.input = input; self.reason = reason; self.nextStep = nextStep
        self.originalObservedAt = originalObservedAt
        self.plan=plan;self.sourceName=sourceName;self.resetTimes=resetTimes;self.windowDescriptions=windowDescriptions;self.additionalRows=additionalRows;self.resetCountExpiry=resetCountExpiry;self.links=links
        self.windowObservations = windowObservations
        self.cardReadingState = cardReadingState ?? {
            switch input.dataState { case .fresh: return .ok; case .loading: return .loading; case .stale: return .stale; case .unavailable: return .error }
        }()
    }
    private func cardAge(at now:Date,english:Bool) -> String {
        CommunityObservationAge.cardText(observedAt: originalObservedAt, now: now, english: english)
    }
    public func cardSourceAndAge(at now:Date,english:Bool,selectedWindowID:String?=nil) -> String {
        if let selectedWindowID, windowObservations != nil {
            return observationText(for: selectedWindowID, at: now, english: english)
        }
        let age = cardAge(at: now, english: english)
        return sourceName.isEmpty ? age : sourceName + " · " + age
    }
    private func observationText(for windowID: String?, at now: Date, english: Bool) -> String {
        let fact = windowID.flatMap { id -> DockWindowObservation? in
            guard let window = input.windows.first(where: { $0.id == id }) else { return nil }
            if case .verifiedCurrent(let until) = window.validity, now >= until { return nil }
            return windowObservations?[id]
        }
        let source = fact?.sourceName ?? (english ? "Unknown source" : "未知来源")
        let age = CommunityObservationAge.cardText(observedAt: fact?.observedAt, now: now, english: english)
        return source + " · " + age
    }

    public func cardBadge(at now:Date,english:Bool) -> String {
        let age=cardAge(at:now,english:english)
        switch cardReadingState {
        case .ok: return ""
        case .loading: return english ? "Reading" : "读取中"
        case .stale: return (english ? "Stale · " : "过期 · ") + age
        case .errorLastGood: return english ? "Read failed · showing " + age : "读取失败 · 保留 " + age + "的读数"
        case .error: return reason.isEmpty ? (english ? "Read failed · no reading" : "读取失败 · 无可用读数") : reason
        }
    }
    /// card.js: one reserve line, reset cards and credits on the left and the earliest expiry on the right.
    func cardAdditionalRows(at now: Date, english: Bool) -> [DockCardRow] {
        let count = additionalRows.first { $0.id == "reset-count" }, credits = additionalRows.first { $0.id == "credits" }
        guard count != nil || credits != nil else { return additionalRows }
        var expiryText = ""
        if let expiry = resetCountExpiry, count != nil {
            let seconds = expiry.timeIntervalSince(now)
            if seconds.isFinite, seconds < Double(Int.max) {
                if seconds <= 0 { expiryText = english ? "expired" : "已到期" }
                else {
                    let duration = Self.expiryDuration(Int(ceil(seconds / 60)))
                    expiryText = english ? "exp in " + duration : duration + " 后到期"
                }
            }
        }
        // The count and the credits can carry the same note; the folded line says it once.
        var seen = Set<String>()
        let notes = ([expiryText] + [count?.detail ?? "", credits?.detail ?? ""].flatMap { $0.components(separatedBy: " · ") })
            .filter { !$0.isEmpty && seen.insert($0).inserted }
        // The prototype has no money row: a money balance keeps its own name on the one line.
        let reserve = DockCardRow(id: "reserve", kind: .reserve, label: credits?.label ?? (english ? "Reserve" : "储备"),
            value: [count?.value ?? "", credits?.value ?? ""].filter { !$0.isEmpty }.joined(separator: " · "),
            detail: notes.joined(separator: " · "),
            hint: Self.reserveHint(hasResets: count != nil, hasCredits: credits != nil, english: english))
        var placed = false
        return additionalRows.flatMap { row -> [DockCardRow] in
            guard row.id == "reset-count" || row.id == "credits" else { return [row] }
            if placed { return [] }
            placed = true
            return [reserve]
        }
    }
    /// What the reserve line's figures mean, in the card (the line shows only "↺1 · 3,903").
    static func reserveHint(hasResets: Bool, hasCredits: Bool, english: Bool) -> String {
        switch (hasResets, hasCredits) {
        case (true, true): return english ? "↺ extra resets left · then top-up credits" : "↺ 剩余额外重置次数 · 之后是充值点数"
        case (true, false): return english ? "↺ extra resets left" : "↺ 剩余额外重置次数"
        case (false, true): return english ? "Top-up credits left" : "剩余充值点数"
        case (false, false): return ""
        }
    }
    public func resetDetails(at now:Date,english:Bool,selectedWindowID:String?=nil) -> [String:String] {
        let selectedObservation = selectedWindowID.map { observationText(for: $0, at: now, english: english) }
        return input.windows.reduce(into:[:]) { result,window in
            let reset=Self.resetDetail(resetTimes[window.id] ?? window.resetsAt,now:now,english:english)
            var detail = reset
            if let description = windowDescriptions[window.id], !description.isEmpty, description != window.label {
                detail = description + " · " + detail
            }
            // The header names the selected window's source and age; a row repeats it only when it differs.
            if windowObservations != nil {
                let own = observationText(for: window.id, at: now, english: english)
                if own != selectedObservation { detail += " · " + own }
            }
            result[window.id] = detail
        }
    }
    private static func resetDetail(_ reset:Date?,now:Date,english:Bool) -> String {
        guard let reset else { return "--" }
        let seconds=reset.timeIntervalSince(now)
        guard seconds.isFinite,seconds < Double(Int.max/60) else { return "--" }
        guard seconds > 0 else { return english ? "Reset time passed":"已过重置时间" }
        // D40: the card's compact form, so it fits the 85 pt column: "18m", "3h18", "5d20h";
        // "5d20h 后重置" / "resets 5d20h". Prototype: opus-r7/src/rocket-r1/window-time.js:6
        // (duration, imported as dhm by card.js:46) and strings/card.js:13 (card.resetIn).
        let minutes=Int(ceil(seconds/60))
        return english ? "resets "+compactDuration(minutes):compactDuration(minutes)+" 后重置"
    }
    /// card.js expiryDuration: an expiry under two days stays in hours, "30h", "30h05".
    static func expiryDuration(_ minutes:Int) -> String {
        guard minutes >= 60, minutes < 48*60 else { return compactDuration(minutes) }
        return "\(minutes/60)h"+(minutes%60 == 0 ? "":String(format:"%02d",minutes%60))
    }
    static func compactDuration(_ minutes:Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        if minutes < 1440 { return "\(minutes/60)h"+String(format:"%02d",minutes%60) }
        return "\(minutes/1440)d\(minutes%1440/60)h"
    }
    public func sourceAndAge(at now: Date) -> String {
        CommunityObservationAge.text(observedAt: originalObservedAt, now: now)
    }
}
typealias CommunityUnboundDockRow = DockContentRow

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
            let pendingCodes: Set<String> = ["missing", "no-reading", "not-enabled", "not read yet", "not-read-yet", "not_read_yet", "pending"]
            let machineCodes = pendingCodes.union(["consent_required", "keychain_choice_needed", "keychain_denied", "not_detected", "expired", "stale", "unsupported_schema", "reader_error", "parse_error", "timeout", "runtime_missing", "error", "unavailable"])
            let reasonCode = (source?.reason).flatMap { machineCodes.contains($0) ? $0 : nil }
            func next(_ fallback: String) -> String {
                let nativeRemedy = source.flatMap { value -> String? in
                    guard ["consent_required", "keychain_choice_needed", "keychain_denied"].contains(value.status),
                          let reason = value.reason, !machineCodes.contains(reason) else { return nil }
                    return reason
                }
                guard let text = nativeRemedy ?? connection?.quota?.nextStep,
                      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.utf8.count <= 512,
                      !text.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else { return fallback }
                return text
            }
            if current { return ("Local account reading / 本地账户读数", next("Check connected tools in Settings / 在设置检查已连接工具")) }
            let status = source?.status ?? connection?.quota?.status
            let nativeFailure = source.map { ["consent_required", "unavailable", "error", "stale", "expired", "unsupported_schema", "keychain_choice_needed", "keychain_denied"].contains($0.status) || reasonCode.map { !pendingCodes.contains($0) } == true } ?? false
            let code = nativeFailure ? reasonCode ?? source?.status : reasonCode ?? connection?.quota?.reason ?? connection?.quotaAccess?.blocked ?? status
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
