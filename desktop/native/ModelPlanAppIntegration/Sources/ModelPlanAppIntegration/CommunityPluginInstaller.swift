// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanCore
import ModelPlanSettings

@MainActor public protocol CommunityPluginGuidance: AnyObject {
    func copy(_ tool: PluginInstallTool) -> Bool
    func openDocumentation(_ tool: PluginInstallTool) -> Bool
}
@MainActor public protocol CommunityPluginInstalling: SettingsPluginGuiding {
    var supportedTools: Set<SettingsPluginTool> { get }
    func install(_ tool: SettingsPluginTool) async throws -> SettingsPluginInstallResult
}
@MainActor final class SystemPluginGuidance: CommunityPluginGuidance {
    func copy(_ tool: PluginInstallTool) -> Bool {
        let board = NSPasteboard.general; board.clearContents()
        return board.setString(tool.instructionText, forType: .string)
    }
    func openDocumentation(_ tool: PluginInstallTool) -> Bool { NSWorkspace.shared.open(tool.documentationURL) }
}
/// The existing verified bundle helper owns host discovery and fixed marketplace execution.
@MainActor public final class CommunityPluginInstaller: CommunityPluginInstalling {
    private let transport: any PluginInstallJSONTransport
    private let apiAvailable: Bool
    private let guidance: any CommunityPluginGuidance
    private let canPresent: @MainActor () -> Bool
    public init(transport: any PluginInstallJSONTransport, apiAvailable: Bool = false,
                guidance: any CommunityPluginGuidance, canPresent: @escaping @MainActor () -> Bool) {
        self.transport = transport; self.apiAvailable = apiAvailable; self.guidance = guidance; self.canPresent = canPresent
    }
    static func live(bundle: URL, canPresent: @escaping @MainActor () -> Bool) -> CommunityPluginInstaller {
        .init(transport: BundledCLI(bundle: bundle), apiAvailable: CommunityConsentBundleIdentity.matches(bundle: bundle),
              guidance: SystemPluginGuidance(), canPresent: canPresent)
    }
    public var supportedTools: Set<SettingsPluginTool> { apiAvailable ? Set(SettingsPluginTool.allCases) : [] }
    private func wireTool(_ tool: SettingsPluginTool) -> PluginInstallTool { tool == .claudeCode ? .claudeCode : .codex }
    public func canGuidePlugin(_ tool: SettingsPluginTool) -> Bool { supportedTools.contains(tool) && canPresent() }
    public func copyPluginInstructions(_ tool: SettingsPluginTool) -> Bool {
        guard canGuidePlugin(tool) else { return false }; return guidance.copy(wireTool(tool))
    }
    public func openPluginDocumentation(_ tool: SettingsPluginTool) -> Bool {
        guard canGuidePlugin(tool) else { return false }; return guidance.openDocumentation(wireTool(tool))
    }
    public func install(_ tool: SettingsPluginTool) async throws -> SettingsPluginInstallResult {
        guard supportedTools.contains(tool) else { throw SettingsConnectionFailure.unavailable }
        guard canPresent(), !Task.isCancelled else { throw SettingsConnectionFailure.cancelled }
        let result = try await transport.installPluginJSON(wireTool(tool))
        try Task.checkCancellation()
        let receipt: PluginInstallReceipt
        do { receipt = try FeedDecoder.pluginInstall(result.stdout) }
        catch { throw SettingsConnectionFailure.invalidResponse }
        let expectedExit: Int32 = receipt.status == .failed ? 1 : 0
        guard receipt.tool == wireTool(tool), result.exitCode == expectedExit,
              let status = SettingsPluginInstallStatus(rawValue: receipt.status.rawValue) else { throw SettingsConnectionFailure.invalidResponse }
        var delivery: SettingsPluginGuideDelivery?
        if status == .instructions, canPresent() {
            let copied = copyPluginInstructions(tool)
            let requested = openPluginDocumentation(tool)
            delivery = .init(copied: copied, documentationRequested: requested)
        }
        return .init(tool: tool, status: status, completedSteps: receipt.completed, guideDelivery: delivery)
    }
}
