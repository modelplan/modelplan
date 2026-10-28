// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanCore
import ModelPlanSettings

/// A matched committed-denial receipt. The backend still must obtain current canonical state.
public struct CommunityConsentCleanupPending: Error, Sendable {
    public let requestID: UUID, generation: UInt64, toolIDs: [String]
    public init(requestID: UUID, generation: UInt64, toolIDs: [String]) {
        self.requestID = requestID; self.generation = generation; self.toolIDs = toolIDs
    }
}

/// Bounded JSON adapter. Composition enables it only for the verified containing helper release.
@MainActor public final class CommunityCLIConsentPort: CommunityConsentCommandPort {
    private let transport: any ConsentJSONTransport
    private let apiAvailable: Bool
    public init(transport: any ConsentJSONTransport, apiAvailable: Bool = false) {
        self.transport = transport; self.apiAvailable = apiAvailable
    }
    public var availability: SettingsConnectionAvailability {
        apiAvailable ? .init(canInspect: true, canGrant: true, canForget: true) : .unverified
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
        guard result.stdout.count <= 65536,
              let receipt = try? JSONDecoder().decode(Receipt.self, from: result.stdout),
              UUID(uuidString: receipt.requestId) == requestID else {
            throw result.exitCode == 0 ? SettingsConnectionFailure.invalidResponse : SettingsConnectionFailure.requestFailed
        }
        let pending = receipt.pendingForget ?? []
        if result.exitCode != 0, !receipt.ok, receipt.error == "cleanup_pending",
           request.allow?.isEmpty == true, let denied = request.deny, !pending.isEmpty, pending.count <= 32,
           Set(pending).count == pending.count, Set(pending).isSubset(of: Set(denied)) {
            throw CommunityConsentCleanupPending(requestID: requestID, generation: receipt.generation, toolIDs: pending)
        }
        guard result.exitCode == 0, receipt.ok, receipt.error == nil, pending.isEmpty else {
            throw SettingsConnectionFailure.requestFailed
        }
        // Receipt generation is not current permission. The backend always reads canonical state.
    }
    private struct RequestIdentity: Decodable { let requestId: String; let allow: [String]?; let deny: [String]? }
    private struct Receipt: Decodable {
        let ok: Bool; let requestId: String; let generation: UInt64
        let error: String?; let pendingForget: [String]?
    }
}
