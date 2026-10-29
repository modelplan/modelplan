// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanCore

/// Supplied by packaging only from the verified bundled helper's capabilities.
/// Empty means unknown; neither absence of rows nor a tool's presence sets a gap.
public struct CommunityReaderCapabilities: Sendable {
    public let unconnectedProviders: [String]
    public init(unconnectedProviders: [String] = []) { self.unconnectedProviders = unconnectedProviders }
}

/// Pure adaptation of the same store observation; no consent file, process or secondary reader.
public enum CommunityReaderFactsBinding {
    public static func make(snapshot: JoinedSnapshot?, diagnostics: StoreDiagnostics,
                            capabilities: CommunityReaderCapabilities = .init()) -> [CommunityReaderFacts] {
        var result: [CommunityReaderFacts] = []
        if diagnostics.detection == nil, diagnostics.detectionReadAt != nil,
           let report = diagnostics.detectionReport {
            result += report.tools.map {
                CommunityReaderFacts(providerID: $0.providerId, detection: detection($0), beta: $0.beta)
            }
        }
        result += (snapshot?.personal.sources ?? []).map {
            CommunityReaderFacts(providerID: $0.source, beta: $0.beta)
        }
        result += (snapshot?.personal.accounts ?? []).map {
            CommunityReaderFacts(providerID: $0.source, beta: $0.beta)
        }
        result += (snapshot?.personal.connections ?? []).map {
            CommunityReaderFacts(providerID: $0.id, blockedCode: $0.quotaAccess?.blocked)
        }
        result += capabilities.unconnectedProviders.map {
            CommunityReaderFacts(providerID: $0, blockedCode: "not-connected-yet")
        }
        // No connect-preview flag or authorization capability is a canonical consent grant.
        return result
    }
    private static func detection(_ tool: DetectedTool) -> CommunityReaderDetection {
        switch (tool.status, tool.detected) {
        case ("detected", true): return .detected
        case ("not-detected", false): return .notDetected
        case ("no-safe-signal", false): return .noSafeSignal
        case ("update-required", false): return .updateRequired
        default: return .unknown
        }
    }
}

public enum CommunityReaderStatusPresentation {
    /// Official appearance keeps its supplied empty hull; its menu still needs a truthful reason.
    /// Existing per-reader rows already supply that reason when evidence identifies any reader.
    public static func emptyMenuLine(_ model: CommunityDockSnapshot, english: Bool) -> String? {
        guard model.inputs.isEmpty, model.readerDiagnostics.isEmpty else { return nil }
        return emptyText(model, english: english)
    }
    public static func menuLines(_ model: CommunityDockSnapshot, english: Bool) -> [String] {
        Array(model.readerDiagnostics.prefix(16)).map { diagnostic in
            let name = toolName(diagnostic.providerID, english: english)
            return name + ": " + (english ? diagnostic.english + " Open Settings to check this tool." : diagnostic.chinese + " 打开设置检查此工具。")
        }
    }
    public static func emptyText(_ model: CommunityDockSnapshot, english: Bool) -> String {
        let reason = model.emptyDiagnostic.map { english ? $0.english : $0.chinese } ?? (english ? "No subscriptions are shown." : "当前未显示订阅。")
        return reason + (english ? " Open Settings to check connected tools." : " 打开设置检查已连接工具。")
    }
    private static func toolName(_ id: String?, english: Bool) -> String {
        switch id {
        case "codex": return "Codex"
        case "claude": return "Claude"
        case "cursor": return "Cursor"
        case "gemini": return "Gemini"
        case "qwen": return "Qwen"
        case "kimi": return "Kimi"
        case "zai": return "Z.ai"
        case "opencodego": return "OpenCode"
        case "kiro": return "Kiro"
        case "copilot": return "Copilot"
        case "minimax": return "MiniMax"
        case "grok": return "Grok"
        case "antigravity": return "Antigravity"
        case "amp": return "Amp"
        default: return english ? "Reader" : "用量读取"
        }
    }
}
