// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanCore
import ModelPlanSettings

/// The executable adapter must verify its containing release before supplying this port.
/// Neither method may implement interactive prompts or convert omitted decisions into denial.
@MainActor public protocol CommunityConsentCommandPort: AnyObject {
    func readCanonicalConsent() async throws -> ConsentPreview
    func applyConsentJSON(_ payload: Data) async throws
}

/// Single Settings service over canonical consent and the same runtime's desktop gate.
@MainActor public final class CommunityConnectionBackend: SettingsConnectionAllowing {
    private let port: any CommunityConsentCommandPort
    private let desktop: ConsentGatedDesktopTransport
    private var revision: UInt64 = 0
    public init(port: any CommunityConsentCommandPort, desktop: ConsentGatedDesktopTransport) {
        self.port = port; self.desktop = desktop
    }
    public func detect() async throws -> SettingsConnectionSnapshot {
        revision &+= 1; let token = revision
        let gate = await desktop.invalidateConsent()
        let value = try await port.readCanonicalConsent()
        try check(token)
        let facts = try CommunityConsentPreviewFacts(canonical: value)
        let snapshot = try facts.projecting()
        guard await desktop.installCanonicalReadback(value, revision: gate) else { throw SettingsConnectionFailure.stale }
        try check(token)
        return snapshot
    }
    public func applyStandardConsent(allow: [SettingsConnectionTool], deny: [SettingsConnectionTool],
                                     request: SettingsConnectionRequestContext) async throws -> SettingsConnectionSnapshot {
        // Forget is a separate explicit flow, never generated from first-run unchecked items.
        guard deny.isEmpty else { throw SettingsConnectionFailure.unavailable }
        revision &+= 1; let token = revision
        let gate = await desktop.invalidateConsent()
        let before = try await port.readCanonicalConsent()
        try check(token)
        let payload = try CommunityConsentGrantPayload(preview: .init(canonical: before), allow: allow, deny: [], request: request)
        let bytes = try JSONEncoder().encode(payload)
        try check(token)
        try await port.applyConsentJSON(bytes)
        try check(token)
        // A successful or replayed receipt is not current canonical permission.
        let after = try await port.readCanonicalConsent()
        try check(token)
        let snapshot = try CommunityConsentPreviewFacts(canonical: after).projecting()
        guard await desktop.installCanonicalReadback(after, revision: gate) else { throw SettingsConnectionFailure.stale }
        try check(token)
        return snapshot
    }
    public func connect(_ tool: SettingsConnectionTool, access: SettingsConnectionAccess,
                        request: SettingsConnectionRequestContext) async throws -> SettingsConnectionSnapshot {
        guard access == .standard else { throw SettingsConnectionFailure.unavailable }
        return try await applyStandardConsent(allow: [tool], deny: [], request: request)
    }
    public func disconnect(_ tool: SettingsConnectionTool, request: SettingsConnectionRequestContext) async throws -> SettingsConnectionSnapshot {
        throw SettingsConnectionFailure.unavailable
    }
    public func installPlugin(_ tool: SettingsPluginTool, request: SettingsConnectionRequestContext) async throws -> SettingsPluginInstallResult {
        throw SettingsConnectionFailure.unavailable
    }
    private func check(_ token: UInt64) throws {
        try Task.checkCancellation()
        guard token == revision else { throw SettingsConnectionFailure.stale }
    }
}
