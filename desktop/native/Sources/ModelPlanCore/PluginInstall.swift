// SPDX-License-Identifier: MIT
import Foundation

public enum PluginInstallTool: String, Codable, CaseIterable, Sendable {
    case claudeCode = "claude-code", codex
    public var arguments: [String] {
        switch self {
        case .claudeCode: return ["plugin", "install", "claude-code", "--json"]
        case .codex: return ["plugin", "install", "codex", "--json"]
        }
    }
    public var documentationURL: URL { URL(string: "https://github.com/modelplan/modelplan/tree/main/" + (self == .claudeCode ? "claude-code" : "codex"))! }
    var commands: [[String]] {
        switch self {
        case .claudeCode: return [["claude","plugin","marketplace","add","modelplan/modelplan"],["claude","plugin","install","modelplan@modelplan"]]
        case .codex: return [["codex","plugin","marketplace","add","modelplan/modelplan","--sparse",".agents","--sparse","codex"],["codex","plugin","add","modelplan-codex@modelplan"]]
        }
    }
    public var instructionText: String { commands.map { $0.joined(separator: " ") }.joined(separator: "\n") }
}
public enum PluginInstallStatus: String, Decodable, Sendable { case installed, instructions, planned, failed }
public struct PluginInstallReceipt: Decodable, Sendable {
    public let schemaVersion: Int, tool: PluginInstallTool, status: PluginInstallStatus
    public let commands: [[String]], completed: Int, docs: String
}
/// A separately scheduled explicit command port, never a SnapshotStore command.
public protocol PluginInstallJSONTransport: Sendable {
    func installPluginJSON(_ tool: PluginInstallTool) async throws -> CommandResult
}
