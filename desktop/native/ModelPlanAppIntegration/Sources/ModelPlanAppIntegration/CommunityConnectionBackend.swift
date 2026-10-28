// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanCore
import ModelPlanSettings

/// The executable adapter must verify its containing release before supplying this port.
/// Neither method may implement interactive prompts or convert omitted decisions into denial.
@MainActor public protocol CommunityConsentCommandPort: AnyObject {
    var availability: SettingsConnectionAvailability { get }
    func readCanonicalConsent() async throws -> ConsentPreview
    func applyConsentJSON(_ payload: Data) async throws
}
public extension CommunityConsentCommandPort {
    var availability: SettingsConnectionAvailability { .unverified }
}

/// Single Settings service over canonical consent and the same runtime's desktop gate.
@MainActor public final class CommunityConnectionBackend: SettingsConnectionAllowing, SettingsConnectionAvailabilityProviding {
    private let port: any CommunityConsentCommandPort
    private let desktop: ConsentGatedDesktopTransport
    private var revision: UInt64 = 0
    /// Composition routes this into the existing runtime store, never a second producer or timer.
    public var onCanonicalReadback: (@MainActor (ConsentPreview) -> Void)?
    public init(port: any CommunityConsentCommandPort, desktop: ConsentGatedDesktopTransport) {
        self.port = port; self.desktop = desktop
    }
    public var settingsConnectionAvailability: SettingsConnectionAvailability { port.availability }
    public func detect() async throws -> SettingsConnectionSnapshot {
        guard port.availability.canInspect else { throw SettingsConnectionFailure.unavailable }
        revision &+= 1; let token = revision
        let gate = await desktop.invalidateConsent()
        let value = try await port.readCanonicalConsent()
        try check(token)
        let facts = try CommunityConsentPreviewFacts(canonical: value)
        let snapshot = try facts.projecting()
        guard await desktop.installCanonicalReadback(value, revision: gate) else { throw SettingsConnectionFailure.stale }
        try check(token)
        onCanonicalReadback?(value)
        try check(token)
        return snapshot
    }
    public func applyStandardConsent(allow: [SettingsConnectionTool], deny: [SettingsConnectionTool],
                                     request: SettingsConnectionRequestContext) async throws -> SettingsConnectionSnapshot {
        // A deny-only request is the separately confirmed Forget flow. First-run omission
        // never becomes denial, and granting and deleting are never combined by this service.
        guard deny.isEmpty || allow.isEmpty else { throw SettingsConnectionFailure.unavailable }
        guard deny.isEmpty ? port.availability.canGrant : port.availability.canForget else {
            throw SettingsConnectionFailure.unavailable
        }
        revision &+= 1; let token = revision
        let gate = await desktop.invalidateConsent()
        let before = try await port.readCanonicalConsent()
        try check(token)
        let payload = try CommunityConsentGrantPayload(preview: .init(canonical: before), allow: allow, deny: deny, request: request)
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
        onCanonicalReadback?(after)
        try check(token)
        return snapshot
    }
    public func connect(_ tool: SettingsConnectionTool, access: SettingsConnectionAccess,
                        request: SettingsConnectionRequestContext) async throws -> SettingsConnectionSnapshot {
        guard access == .standard else { throw SettingsConnectionFailure.unavailable }
        return try await applyStandardConsent(allow: [tool], deny: [], request: request)
    }
    public func disconnect(_ tool: SettingsConnectionTool, request: SettingsConnectionRequestContext) async throws -> SettingsConnectionSnapshot {
        try await applyStandardConsent(allow: [], deny: [tool], request: request)
    }
    public func installPlugin(_ tool: SettingsPluginTool, request: SettingsConnectionRequestContext) async throws -> SettingsPluginInstallResult {
        throw SettingsConnectionFailure.unavailable
    }
    private func check(_ token: UInt64) throws {
        try Task.checkCancellation()
        guard token == revision else { throw SettingsConnectionFailure.stale }
    }
}
