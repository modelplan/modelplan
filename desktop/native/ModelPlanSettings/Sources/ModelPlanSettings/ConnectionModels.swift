// SPDX-License-Identifier: MIT
import Foundation

/// Public UI vocabulary, not CLI arguments. The runtime adapter owns routing and admission.
public enum SettingsConnectionTool: String, CaseIterable, Sendable {
    case codex, claude, gemini, cursor, qwen, copilot, kiro, zai, opencodego, antigravity, grok, kimi, minimax
    public var title: String {
        switch self {
        case .codex: return "Codex"
        case .claude: return "Claude Code"
        case .gemini: return "Gemini CLI"
        case .cursor: return "Cursor"
        case .qwen: return "Qwen"
        case .copilot: return "GitHub Copilot"
        case .kiro: return "Kiro"
        case .zai: return "Z.ai"
        case .opencodego: return "OpenCode Go"
        case .antigravity: return "Antigravity"
        case .grok: return "Grok"
        case .kimi: return "Kimi"
        case .minimax: return "MiniMax"
        }
    }
}
public enum SettingsConnectionAccess: String, Sendable { case standard, browserSession }
public enum SettingsToolPresence: String, Sendable { case detected, notDetected, unknown, unsupported }
public enum SettingsSharedAuthorization: String, Sendable { case allowed, noConsent, denied, unknown, notApplicable }
public enum SettingsToolConnectionState: String, Sendable { case connected, notConnectedYet, off, unknown }
public enum SettingsToolQuotaState: String, Sendable { case available, stale, unavailable, unknown, notApplicable }
public enum SettingsToolSupport: String, Sendable { case full, sessionsOnly, quotaOnly, detectedOnly, unknown }

/// A quota reading alone cannot construct this evidence. The adapter must supply a verified ref.
public enum SettingsSubscriptionBinding: Equatable, Sendable {
    case unknown, verified(references: Set<String>)
}
public struct SettingsConnectionToolState: Equatable, Sendable {
    public let tool: SettingsConnectionTool
    public var presence: SettingsToolPresence
    public var authorization: SettingsSharedAuthorization
    public var connection: SettingsToolConnectionState
    public var quota: SettingsToolQuotaState
    public var support: SettingsToolSupport
    public var binding: SettingsSubscriptionBinding
    public var access: SettingsConnectionAccess
    public var beta: Bool
    public init(tool: SettingsConnectionTool, presence: SettingsToolPresence = .unknown,
                authorization: SettingsSharedAuthorization = .unknown,
                connection: SettingsToolConnectionState = .unknown, quota: SettingsToolQuotaState = .unknown,
                support: SettingsToolSupport = .unknown, binding: SettingsSubscriptionBinding = .unknown,
                access: SettingsConnectionAccess = .standard, beta: Bool = false) {
        self.tool = tool; self.presence = presence; self.authorization = authorization
        self.connection = connection; self.quota = quota; self.support = support
        self.binding = binding; self.access = access; self.beta = beta
    }
    /// Draft selection is not a grant, including when detect/preview says selected=true.
    public var canRequestConnection: Bool { presence == .detected && support != .detectedOnly && support != .unknown }
}
public struct SettingsVerifiedSubscription: Equatable, Sendable {
    public let reference: String
    public let tool: SettingsConnectionTool
    public let name: SettingsText
    public let plan: String
    public init(reference: String, tool: SettingsConnectionTool, name: SettingsText, plan: String = "") {
        self.reference = reference; self.tool = tool; self.name = name; self.plan = plan
    }
}
/// Future catalogue entries remain visible and inert; their strings can never become action IDs.
public struct SettingsUnrecognizedTool: Equatable, Sendable {
    public let id: String, title: String
    public let presence: SettingsToolPresence
    public let access: SettingsConnectionAccess
    public init(id: String, title: String, presence: SettingsToolPresence = .unknown,
                access: SettingsConnectionAccess = .standard) {
        self.id = id; self.title = title; self.presence = presence; self.access = access
    }
}
public struct SettingsConnectionSnapshot: Equatable, Sendable {
    /// Canonical CLI consent generation, supplied by the same runtime. Nil is unknown, never a grant.
    public let consentGeneration: UInt64?
    public let tools: [SettingsConnectionToolState]
    public let subscriptions: [SettingsVerifiedSubscription]
    public let unrecognizedTools: [SettingsUnrecognizedTool]
    public init(consentGeneration: UInt64? = nil, tools: [SettingsConnectionToolState] = [],
                subscriptions: [SettingsVerifiedSubscription] = [], unrecognizedTools: [SettingsUnrecognizedTool] = []) throws {
        guard tools.count <= SettingsConnectionTool.allCases.count,
              unrecognizedTools.count <= 512, Set(unrecognizedTools.map(\.id)).count == unrecognizedTools.count,
              unrecognizedTools.allSatisfy({ tool in
                  tool.id.range(of: #"^[a-z][a-z0-9-]{0,47}$"#, options: .regularExpression) != nil
                      && SettingsConnectionTool(rawValue: tool.id) == nil && !tool.title.isEmpty
                      && tool.title.utf8.count <= 96 && !tool.title.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
              }),
              Set(tools.map(\.tool)).count == tools.count, subscriptions.count <= 1000,
              Set(subscriptions.map(\.reference)).count == subscriptions.count,
              subscriptions.allSatisfy({ sub in
                  Self.validReference(sub.reference) && tools.contains {
                      guard $0.tool == sub.tool, case .verified(let references) = $0.binding else { return false }
                      return references.contains(sub.reference)
                  }
              }), tools.allSatisfy({ row in
                  if case .verified(let refs) = row.binding { return !refs.isEmpty && refs.count <= 1000 && refs.allSatisfy(Self.validReference) }
                  return true
              }) else { throw SettingsConnectionFailure.invalidResponse }
        self.consentGeneration = consentGeneration; self.tools = tools; self.subscriptions = subscriptions
        self.unrecognizedTools = unrecognizedTools
    }
    private static func validReference(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 256 && !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
    }
    public var standardTools: [SettingsConnectionToolState] { tools.filter { $0.access == .standard } }
    public var advancedTools: [SettingsConnectionToolState] { tools.filter { $0.access == .browserSession } }
}
public enum SettingsPluginTool: String, CaseIterable, Sendable {
    case claudeCode = "claude-code", codex
    public var title: String { self == .claudeCode ? "Claude Code" : "Codex" }
}
public enum SettingsPluginInstallStatus: String, Sendable { case installed, planned, instructions, failed }
/// No command arrays, paths, URLs or raw error text cross this boundary.
public struct SettingsPluginInstallResult: Equatable, Sendable {
    public let tool: SettingsPluginTool
    public let status: SettingsPluginInstallStatus
    public init(tool: SettingsPluginTool, status: SettingsPluginInstallStatus) { self.tool = tool; self.status = status }
    public var isInstalled: Bool { status == .installed }
}
public enum SettingsConnectionFailure: String, Error, Sendable {
    case unavailable, requestFailed, invalidResponse, stale, cancelled
}
public enum SettingsConnectionAction: Equatable, Sendable {
    case connect(SettingsConnectionTool, SettingsConnectionAccess)
    case disconnect(SettingsConnectionTool)
    case installPlugin(SettingsPluginTool)
}
public struct SettingsConnectionConfirmation: Equatable, Sendable {
    public let id: UUID
    public let action: SettingsConnectionAction
    let observation: UInt64
}
public struct SettingsConnectionRequestContext: Equatable, Sendable {
    public let id: UUID
    /// The host must revalidate this against its shared consent before admitting an effect.
    public let expectedConsentGeneration: UInt64?
    public init(id: UUID, expectedConsentGeneration: UInt64?) {
        self.id = id; self.expectedConsentGeneration = expectedConsentGeneration
    }
}

/// Injection boundary only. It does not authorize execution; the host must enforce its own policy.
/// Snapshot fields are independent observations, not an interpretation of app-owned readerConsent.
/// connect/disconnect must return current canonical consent and preserve verified ownership evidence.
@MainActor public protocol SettingsConnectionService: AnyObject {
    func detect() async throws -> SettingsConnectionSnapshot
    func connect(_ tool: SettingsConnectionTool, access: SettingsConnectionAccess, request: SettingsConnectionRequestContext) async throws -> SettingsConnectionSnapshot
    func disconnect(_ tool: SettingsConnectionTool, request: SettingsConnectionRequestContext) async throws -> SettingsConnectionSnapshot
    func installPlugin(_ tool: SettingsPluginTool, request: SettingsConnectionRequestContext) async throws -> SettingsPluginInstallResult
}
