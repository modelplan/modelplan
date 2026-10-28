// SPDX-License-Identifier: MIT
import Foundation

/// A page draft over a particular observation. Checked items are intentions, never shared authorization.
public struct SettingsConnectionIntent: Equatable, Sendable {
    public let basis: SettingsConnectionSnapshot
    public private(set) var selected: Set<SettingsConnectionTool>
    public private(set) var keychainAllowedTools: Set<SettingsConnectionTool> = []
    public init(snapshot: SettingsConnectionSnapshot) {
        basis = snapshot
        selected = Set(snapshot.standardTools.filter(\.canRequestConnection).map(\.tool))
    }
    public mutating func select(_ tool: SettingsConnectionTool, enabled: Bool) {
        guard basis.standardTools.contains(where: { $0.tool == tool && $0.canRequestConnection }) else { return }
        // Omitted tools keep their records. Unchecking must never become destructive deny/Forget.
        if enabled { selected.insert(tool) } else { selected.remove(tool); keychainAllowedTools.remove(tool) }
    }
    public mutating func selectKeychain(_ tool: SettingsConnectionTool, enabled: Bool) {
        guard enabled else { keychainAllowedTools.remove(tool); return }
        guard tool == .claude, selected.contains(tool),
              basis.standardTools.contains(where: { $0.tool == tool && $0.canRequestConnection && $0.keychainEligible }) else { return }
        keychainAllowedTools.insert(tool)
    }
    public var orderedKeychainTools: [SettingsConnectionTool] { orderedTools.filter { keychainAllowedTools.contains($0) } }
    public var orderedTools: [SettingsConnectionTool] { SettingsConnectionTool.allCases.filter { selected.contains($0) } }
}
