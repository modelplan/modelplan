// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanWire

/// D87 slice 5: what the engine's accepted rows say about one tool, reduced to fixed words.
/// `code` is the row's reason code (`keychain_unset`, `not_found`, ...), never provider text.
public struct ToolRowFacts: Equatable, Sendable {
    public let consent: RowsConsent?
    public let state: RowsState?
    public let code: String?
    public init(consent: RowsConsent? = nil, state: RowsState? = nil, code: String? = nil) {
        self.consent = consent; self.state = state; self.code = code
    }
}

public enum SubscriptionRowSection: String, Sendable, Equatable { case added, detected, notInstalled }

/// One line of the Subscriptions pane: a subscription that is added, a tool that is detected but not
/// added yet, or a supported tool this Mac does not have. Display state only; it never grants or
/// revokes anything by itself (visibility is a display switch, D87).
public struct SubscriptionRow: Equatable, Sendable, Identifiable {
    public let id: String
    public let tool: String
    public let name: SettingsText
    public let plan: String
    public let section: SubscriptionRowSection
    public let consent: RowsConsent?
    public let state: RowsState?
    /// The fixed cause code behind the status line, when there is one.
    public let causeCode: String?
    public let visible: Bool
    /// Zero-based place among the added rows; nil for the other sections.
    public let position: Int?
    public let addedCount: Int
    /// The status line (what is wrong, or that reading works).
    public let status: SettingsText
    /// True when the status line is a problem to fix rather than a plain fact.
    public let needsAttention: Bool
    /// The one fix action, from the shared ReaderCauseTable.
    public let fix: ReaderCauseEntry?
    /// Detected rows only: the tool can be added now (readable, with at least one standard path).
    public let canAdd: Bool
    /// A row for a tool that is reading but has no subscription yet: no visibility switch or order controls.
    public var isPending: Bool { section == .added && position == nil }
    public var canMoveUp: Bool { section == .added && (position.map { $0 > 0 } ?? false) }
    public var canMoveDown: Bool { section == .added && (position.map { $0 < addedCount - 1 } ?? false) }
}

public struct SubscriptionRowModel: Equatable, Sendable {
    public let added: [SubscriptionRow]
    public let detected: [SubscriptionRow]
    public let notInstalled: [SubscriptionRow]
    public var all: [SubscriptionRow] { added + detected + notInstalled }
    public func row(id: String) -> SubscriptionRow? { all.first { $0.id == id } }
    /// The row a widget card's reason links to: that tool's added subscription, else its detected row.
    public func row(forTool tool: String) -> SubscriptionRow? {
        let key = tool.lowercased()
        return added.first { $0.tool.lowercased() == key } ?? (detected + notInstalled).first { $0.tool.lowercased() == key }
    }

    /// Codes that describe consent or timing, not a prerequisite: first run asks for consent itself.
    private static let notPrerequisite: Set<String> = [
        "ok", "estimated", "stale_reading", "observation_time_unknown", "not_read_yet", "reader_busy", "consent_changed",
        "no_manual_reading", "no_usage_windows", "consent_required", "consent_denied", "consent_outdated", "readers_off",
        "no_consent", "no_dock_rows", "other", "policy_pending",
    ]
    private static func isKeychain(_ code: String) -> Bool { code.hasPrefix("keychain_") }

    /// Only a code with something to fix survives; the rest keep the plain state text.
    static func actionableCode(_ code: String?) -> String? {
        guard let code, !code.isEmpty, !notPrerequisite.contains(code) else { return nil }
        return code
    }

    /// D87 slice 8: one prerequisite line per tool on the first-run list, from the same table as the rows.
    /// What it says: a problem to fix first (not signed in, command missing, ...), else that a Keychain
    /// prompt will appear, else that nothing more is needed.
    public static func prerequisite(tool: FirstRunTool, name: String, facts: ToolRowFacts?,
                                    keyEntryAvailable: Bool = false) -> (text: SettingsText, needsAttention: Bool) {
        if let block = tool.block {
            switch block {
            case .notSignedIn:
                return (SettingsText("Not signed in to \(name). Sign in first.", "尚未登录 \(name)，请先登录。"), true)
            case .unsupportedLogin:
                return (SettingsText("This sign-in type cannot be read yet.", "这种登录方式暂不支持读取。"), true)
            }
        }
        if let code = actionableCode(facts?.code), !isKeychain(code),
           let entry = ReaderCauseTable.entry(code: code, tool: tool.tool, toolName: name, keyEntryAvailable: keyEntryAvailable) {
            return (entry.reason, true)
        }
        if tool.promptsKeychain {
            return (SettingsText("A Keychain prompt will appear once; choose Always Allow.", "会弹出一次钥匙串授权，请选“始终允许”。"), false)
        }
        return (SettingsText("Ready: nothing else is needed.", "已就绪，无需其他操作。"), false)
    }

    /// Merge the engine's consent facts, row status, cause code and visibility into one row per subscription.
    /// - subscriptions/orderedIDs: the shared order (hidden ones keep their place);
    /// - tools: `ScopeConsentController.settingsTools` (detected tools, then supported absent ones).
    public static func build(subscriptions: [SettingsSubscription], orderedIDs: [String], hiddenIDs: Set<String>,
                             tools: [FirstRunTool], facts: [String: ToolRowFacts], isReading: (String) -> Bool,
                             keyEntryAvailable: Bool = false, name: (String) -> SettingsText) -> SubscriptionRowModel {
        let byID = Dictionary(subscriptions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let ordered = orderedIDs.filter { byID[$0] != nil }
        let addedTools = Set(ordered.compactMap { byID[$0]?.vendor.lowercased() })
        let english = SettingsLanguage.english

        let added: [SubscriptionRow] = ordered.enumerated().map { index, id in
            let sub = byID[id]!
            let tool = sub.vendor
            let toolFacts = facts[tool]
            var code = actionableCode(sub.causeCode) ?? actionableCode(toolFacts?.code)
            if code == nil, let state = toolFacts?.state {
                if state == .needsKeychain { code = "keychain_unset" }
                if state == .needsConsent { code = "consent_required" }
            }
            let displayName = sub.name.english.isEmpty ? name(tool) : sub.name
            let fix = code.flatMap { ReaderCauseTable.entry(code: $0, tool: tool, toolName: displayName.value(english), keyEntryAvailable: keyEntryAvailable) }
            let status: SettingsText
            if let fix { status = fix.reason }
            else {
                switch sub.source {
                case .fresh: status = SettingsText("Reading works", "读取正常")
                case .stale: status = SettingsText("The last reading is old", "上次读数已过期")
                case .denied: status = SettingsText("Reading is not allowed", "未允许读取")
                case .readerDisabled: status = SettingsText("Reading is off", "读取已关闭")
                case .unavailable: status = SettingsText("Waiting for the first reading", "等待首次读取")
                }
            }
            return SubscriptionRow(id: id, tool: tool, name: displayName, plan: sub.plan, section: .added,
                                   consent: toolFacts?.consent, state: toolFacts?.state, causeCode: code,
                                   visible: !hiddenIDs.contains(id), position: index, addedCount: ordered.count,
                                   status: status, needsAttention: fix != nil, fix: fix, canAdd: false)
        }

        var detected: [SubscriptionRow] = [], absent: [SubscriptionRow] = [], pending: [SubscriptionRow] = []
        for tool in tools where !addedTools.contains(tool.tool.lowercased()) {
            let toolFacts = facts[tool.tool]
            let displayName = name(tool.tool)
            if tool.detected {
                if tool.canRead && isReading(tool.tool) {
                    // Reading by default but no engine row yet: it belongs under "My subscriptions", without order controls.
                    pending.append(SubscriptionRow(id: tool.tool, tool: tool.tool, name: displayName, plan: "", section: .added,
                                                   consent: toolFacts?.consent, state: toolFacts?.state, causeCode: nil, visible: true,
                                                   position: nil, addedCount: ordered.count,
                                                   status: SettingsText("Reading…", "正在读取…"), needsAttention: false, fix: nil, canAdd: false))
                    continue
                }
                let pre = prerequisite(tool: tool, name: displayName.english, facts: toolFacts, keyEntryAvailable: keyEntryAvailable)
                var fix: ReaderCauseEntry?
                let fixCode: String? = tool.block == .notSignedIn ? "not_signed_in" : (tool.block == nil ? actionableCode(toolFacts?.code) : nil)
                if pre.needsAttention, let code = fixCode {
                    fix = ReaderCauseTable.entry(code: code, tool: tool.tool, toolName: displayName.english, keyEntryAvailable: keyEntryAvailable)
                }
                detected.append(SubscriptionRow(id: tool.tool, tool: tool.tool, name: displayName, plan: "", section: .detected,
                                                consent: toolFacts?.consent, state: toolFacts?.state, causeCode: nil, visible: true,
                                                position: nil, addedCount: ordered.count, status: pre.text,
                                                needsAttention: pre.needsAttention, fix: fix, canAdd: tool.canRead))
            } else {
                absent.append(SubscriptionRow(id: tool.tool, tool: tool.tool, name: displayName, plan: "", section: .notInstalled,
                                              consent: toolFacts?.consent, state: toolFacts?.state, causeCode: nil, visible: true,
                                              position: nil, addedCount: ordered.count,
                                              status: SettingsText("Not installed on this Mac", "本机未安装"),
                                              needsAttention: false, fix: nil, canAdd: false))
            }
        }
        return SubscriptionRowModel(added: added + pending, detected: detected, notInstalled: absent)
    }
}
