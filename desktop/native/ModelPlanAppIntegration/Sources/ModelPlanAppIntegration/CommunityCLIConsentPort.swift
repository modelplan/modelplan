// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanCore
import ModelPlanSettings

/// Bounded JSON adapter. Composition enables it only for the verified containing helper release.
@MainActor public final class CommunityCLIConsentPort: CommunityConsentCommandPort {
    private let transport: any ConsentJSONTransport
    private let apiAvailable: Bool
    public init(transport: any ConsentJSONTransport, apiAvailable: Bool = false) {
        self.transport = transport; self.apiAvailable = apiAvailable
    }
    public func readCanonicalConsent() async throws -> ConsentPreview {
        guard apiAvailable else { throw SettingsConnectionFailure.unavailable }
        let result = try await transport.readConsentJSON()
        try Task.checkCancellation()
        guard result.exitCode == 0 else { throw SettingsConnectionFailure.requestFailed }
        do { return try FeedDecoder.consentPreview(result.stdout) }
        catch { throw SettingsConnectionFailure.invalidResponse }
    }
    public func applyConsentJSON(_ payload: Data) async throws {
        guard apiAvailable else { throw SettingsConnectionFailure.unavailable }
        guard !payload.isEmpty, payload.count <= 65536,
              let request = try? JSONDecoder().decode(RequestIdentity.self, from: payload),
              let requestID = UUID(uuidString: request.requestId) else { throw SettingsConnectionFailure.invalidResponse }
        let result = try await transport.grantConsentJSON(payload)
        try Task.checkCancellation()
        guard result.exitCode == 0 else { throw SettingsConnectionFailure.requestFailed }
        guard result.stdout.count <= 65536,
              let receipt = try? JSONDecoder().decode(Receipt.self, from: result.stdout), receipt.ok,
              UUID(uuidString: receipt.requestId) == requestID else { throw SettingsConnectionFailure.invalidResponse }
        // Receipt generation is validated, but only a subsequent canonical read enables the desktop gate.
        _ = receipt.generation
    }
    private struct RequestIdentity: Decodable { let requestId: String }
    private struct Receipt: Decodable { let ok: Bool; let requestId: String; let generation: UInt64 }
}
