// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanCore

/// Presentation facts supplied by the runtime owner; these values never grant reader access.
public enum CommunityReaderDetection: Sendable, Equatable {
    case unknown, detected, notDetected, noSafeSignal, updateRequired
}
public enum CommunityReaderConsent: Sendable, Equatable { case unknown, allowed, denied }
public enum CommunityReaderFreshness: Sendable, Equatable { case unknown, fresh, stale }

public struct CommunityReaderFacts: Sendable, Equatable {
    public let providerID: String
    public let detection: CommunityReaderDetection
    public let consent: CommunityReaderConsent
    public let blockedCode: String?
    public let reasonCode: String?
    public let beta: Bool?
    public init(providerID: String, detection: CommunityReaderDetection = .unknown,
                consent: CommunityReaderConsent = .unknown, blockedCode: String? = nil,
                reasonCode: String? = nil, beta: Bool? = nil) {
        self.providerID = providerID; self.detection = detection; self.consent = consent
        self.blockedCode = blockedCode; self.reasonCode = reasonCode; self.beta = beta
    }
}

public enum CommunityReaderReasonCategory: Sendable, Equatable {
    case unknown, notDetected, noSafeSignal, noConsent, consentOrPrivacy, readersOff,
         consentChanged, updateRequired, notEnabled, notConnectedYet, fresh, stale, unbound, unavailable, notLoaded, noSubscriptions
}

/// Only fixed bilingual copy is exposed. Raw reasons/paths/identities are never UI copy.
public struct CommunityReaderDiagnostic: Sendable, Equatable {
    public let providerID: String?
    public let category: CommunityReaderReasonCategory
    public let detection: CommunityReaderDetection
    public let consent: CommunityReaderConsent
    public let freshness: CommunityReaderFreshness
    public let beta: Bool?
    public var english: String {
        switch category {
        case .unknown: return "Reader status is unknown."
        case .notDetected: return "Tool not detected."
        case .noSafeSignal: return "No safe detection signal is available."
        case .noConsent: return "Usage access was not granted."
        case .consentOrPrivacy: return "Usage access is blocked by consent or privacy settings."
        case .readersOff: return "Reader access is off."
        case .consentChanged: return "Reader permissions changed; a new reading is needed."
        case .updateRequired: return "Update required for this reader."
        case .notEnabled: return "Reader is not enabled."
        case .notConnectedYet: return "Reader connection is not complete yet."
        case .fresh: return "A current local reading is available."
        case .stale: return "The reading is stale."
        case .unbound: return "Subscription binding is not verified."
        case .unavailable: return "The reading is unavailable."
        case .notLoaded: return "The personal feed has not loaded."
        case .noSubscriptions: return "No confirmed subscription reading is available."
        }
    }
    public var chinese: String {
        switch category {
        case .unknown: return "读取器状态未知。"
        case .notDetected: return "未检测到工具。"
        case .noSafeSignal: return "没有可安全使用的检测信号。"
        case .noConsent: return "未授权读取用量。"
        case .consentOrPrivacy: return "授权或隐私设置阻止了用量读取。"
        case .readersOff: return "用量读取已停用。"
        case .consentChanged: return "读取权限已变化，需重新获取读数。"
        case .updateRequired: return "此读取器需要更新。"
        case .notEnabled: return "读取器未启用。"
        case .notConnectedYet: return "读取器连接尚未完成。"
        case .fresh: return "有当前有效的本地读数。"
        case .stale: return "读数已过期。"
        case .unbound: return "订阅归属尚未验证。"
        case .unavailable: return "读数不可用。"
        case .notLoaded: return "个人数据尚未加载。"
        case .noSubscriptions: return "暂无可确认的订阅读数。"
        }
    }
}
public struct CommunityReaderReasonProjection: Sendable, Equatable {
    public let readers: [CommunityReaderDiagnostic]
    public let empty: CommunityReaderDiagnostic?
}

public enum CommunityReaderReason {
    /// Projects presentation only. Facts do not enable collection, create membership or rewrite quota values.
    public static func project(snapshot: JoinedSnapshot?, diagnostics: StoreDiagnostics,
                               now: Date, facts: [CommunityReaderFacts] = []) -> CommunityReaderReasonProjection {
        let personal = snapshot?.personal
        let accounts = personal?.accounts ?? [], sources = personal?.sources ?? []
        let connections = personal?.connections ?? []
        var keys: [String] = [], seen = Set<String>()
        for raw in facts.map(\.providerID) + accounts.map(\.source) + sources.map(\.source) + connections.map(\.id) {
            let key = readerKey(raw)
            if seen.insert(key).inserted { keys.append(key) }
        }
        let readable = snapshot.map { isReadable($0, diagnostics: diagnostics, now: now) } ?? false
        let readers = keys.map { key -> CommunityReaderDiagnostic in
            let id = key.hasPrefix("unknown:") ? nil : key
            let supplied = facts.filter { readerKey($0.providerID) == key }
            let stages = connections.filter { readerKey($0.id) == key }
            let observedDetection = stages.map { stage -> CommunityReaderDetection in
                if stage.installed?.status == "yes" { return .detected }
                if stage.installed?.status == "no", stage.installed?.reason == "not-found" { return .notDetected }
                return .unknown
            }
            let detection = consensus(supplied.map(\.detection) + observedDetection, unknown: .unknown)
            let consent = consensus(supplied.map(\.consent), unknown: .unknown)
            let evidence = CommunityReaderFacts(providerID: id ?? "", detection: detection, consent: consent,
                blockedCode: consensus(supplied.compactMap(\.blockedCode).map(Optional.some), unknown: nil),
                reasonCode: consensus(supplied.compactMap(\.reasonCode).map(Optional.some), unknown: nil),
                beta: consensus(supplied.compactMap(\.beta).map(Optional.some), unknown: nil))
            let ownAccounts = accounts.filter { readerKey($0.source) == key }
            let ownSources = sources.filter { readerKey($0.source) == key }
            let freshness = freshness(snapshot: snapshot, key: key, readable: readable, now: now)
            var category = category(for: evidence)
            // A raw CLI reason cannot assert that an integration is wired or missing. Only explicit facts can.
            if category == .unknown {
                let codes = (ownSources + sources.filter { $0.source == "readers" && id != "readers" }).compactMap(\.reason) +
                    stages.flatMap { [$0.authorization?.reason, $0.quota?.reason] }.compactMap { $0 }
                category = codes.compactMap { codeCategory($0, permitsIntegrationFact: false) }.first ?? .unknown
            }
            if category == .unknown {
                if !ownAccounts.isEmpty && !ownAccounts.contains(where: hasVerifiedBinding) { category = .unbound }
                else if freshness == .fresh { category = .fresh }
                else if freshness == .stale { category = .stale }
                else if !ownAccounts.isEmpty || ownSources.contains(where: { unavailableStatuses.contains($0.status) }) ||
                    stages.contains(where: { $0.quota?.status == "no" || $0.quota?.status == "off" }) { category = .unavailable }
            }
            return .init(providerID: id, category: category, detection: detection, consent: consent,
                         freshness: freshness, beta: evidence.beta)
        }
        let hasMembership = (personal?.subscriptions ?? []).contains { !$0.subscriptionRef.isEmpty } ||
            accounts.contains { !($0.subscription?.subscriptionRef ?? "").isEmpty }
        let empty: CommunityReaderDiagnostic?
        if hasMembership { empty = nil }
        else if snapshot == nil, readers.count == 1, readers[0].category != .unknown { empty = readers[0] }
        else if snapshot == nil {
            empty = diagnostic(diagnostics.personal == "not-loaded" || diagnostics.personal == "personal-not-loaded" || diagnostics.personal == nil ? .notLoaded : .unavailable)
        } else if !accounts.isEmpty { empty = diagnostic(.unbound) }
        else if let global = readers.first(where: { $0.providerID == "readers" && $0.category != .unknown }) { empty = global }
        else if readers.count == 1 { empty = readers.first }
        else { empty = diagnostic(readers.isEmpty ? .unknown : .noSubscriptions) }
        return .init(readers: readers, empty: empty)
    }

    static func isReadable(_ snapshot: JoinedSnapshot, diagnostics: StoreDiagnostics, now: Date) -> Bool {
        let personal = snapshot.personal
        return diagnostics.personal == nil && snapshot.presentation.actionable &&
            now.timeIntervalSinceReferenceDate.isFinite && personal.generatedAt.date <= now &&
            personal.validUntilReported && personal.validUntil.map { $0.date > now } == true
    }
    static func currentReading(account: QuotaAccount, window: QuotaWindow, quota: QuotaReading?,
                               readable: Bool, now: Date) -> Bool {
        guard hasVerifiedBinding(account), let quota else { return false }
        return readable && quota.source == account.source && quota.subscription == account.subscription?.subscriptionRef &&
            quota.kind == window.kind && quota.reason == nil && quota.observedAt.map { $0 <= now } == true &&
            window.unknownReason == nil && window.reason == nil
    }
    private static func hasVerifiedBinding(_ account: QuotaAccount) -> Bool {
        account.subscription?.status == "verified" && !(account.subscription?.subscriptionRef ?? "").isEmpty
    }
    private static func freshness(snapshot: JoinedSnapshot?, key: String, readable: Bool, now: Date) -> CommunityReaderFreshness {
        guard let snapshot else { return .unknown }
        var offset = 0, old = false
        for account in snapshot.personal.accounts ?? [] {
            let windows = account.windows ?? []
            defer { offset += windows.count }
            guard readerKey(account.source) == key else { continue }
            old = old || account.stale == true
            for (index, window) in windows.enumerated() {
                let quota = snapshot.presentation.quotas.indices.contains(offset + index) ? snapshot.presentation.quotas[offset + index] : nil
                if currentReading(account: account, window: window, quota: quota, readable: readable, now: now) { return .fresh }
                let expiredLifetime = snapshot.personal.validUntilReported &&
                    (snapshot.presentation.unavailableReason == "personal-expired" ||
                     snapshot.personal.validUntil.map { $0.date <= now } == true)
                old = old || ["reset_passed", "stale"].contains(quota?.reason ?? "") ||
                    (quota?.reason == "snapshot-expired" && expiredLifetime)
            }
        }
        old = old || (snapshot.personal.sources ?? []).contains { readerKey($0.source) == key && $0.status == "stale" }
        return old ? .stale : .unknown
    }
    private static let unavailableStatuses: Set<String> = [
        "missing", "empty", "invalid", "unreadable", "unsafe_path", "too_large", "unsupported_schema", "unavailable", "error",
    ]
    private static func diagnostic(_ category: CommunityReaderReasonCategory) -> CommunityReaderDiagnostic {
        .init(providerID: nil, category: category, detection: .unknown, consent: .unknown, freshness: .unknown, beta: nil)
    }
    // No chronology is invented for conflicting simultaneous inputs. Missing evidence is not a contradiction.
    private static func consensus<T: Equatable>(_ values: [T], unknown: T) -> T {
        let known = values.filter { $0 != unknown }
        guard let first = known.first, known.allSatisfy({ $0 == first }) else { return unknown }
        return first
    }

    private static func category(for facts: CommunityReaderFacts) -> CommunityReaderReasonCategory {
        if facts.consent == .denied { return .noConsent }
        if let known = [facts.blockedCode, facts.reasonCode].compactMap({ $0 }).compactMap({ codeCategory($0, permitsIntegrationFact: true) }).first { return known }
        switch facts.detection {
        case .notDetected: return .notDetected
        case .noSafeSignal: return .noSafeSignal
        case .updateRequired: return .updateRequired
        case .unknown, .detected: return .unknown
        }
    }

    private static func codeCategory(_ code: String, permitsIntegrationFact: Bool) -> CommunityReaderReasonCategory? {
        switch code {
        case "reader-consent-or-privacy": return .consentOrPrivacy
        case "reader-privacy": return .readersOff
        case "consent-changed": return .consentChanged
        case "update-required": return .updateRequired
        case "not-enabled": return .notEnabled
        case "not-connected-yet" where permitsIntegrationFact: return .notConnectedYet
        default: return nil
        }
    }

    private static func readerKey(_ raw: String) -> String {
        // Unknown logical tools stay isolated internally; their untrusted identifiers never leave this mapper.
        providerID(raw) ?? "unknown:" + raw
    }

    private static func providerID(_ raw: String) -> String? {
        let value = raw.hasPrefix("native:") ? String(raw.dropFirst(7)) :
            raw.hasPrefix("codexbar:") ? String(raw.dropFirst(9)) : raw
        switch value {
        case "claude-code": return "claude"
        case "zcode": return "zai"
        case "opencode": return "opencodego"
        case "codex", "claude", "cursor", "gemini", "qwen", "kimi", "zai", "opencodego",
             "kiro", "copilot", "minimax", "grok", "antigravity", "amp", "readers": return value
        default: return nil
        }
    }

}
