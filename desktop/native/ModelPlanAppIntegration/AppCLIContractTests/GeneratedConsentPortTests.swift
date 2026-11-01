// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCore
import ModelPlanSettings
import ModelPlanAppIntegration
import ModelPlanWire

@MainActor final class GeneratedConsentPortTests: XCTestCase {
    private actor Wire: ConsentJSONTransport {
        let entry: GeneratedAppCLIFixtures.Entry
        let response: Data
        let expectedRequest: Data?
        init(_ entry: GeneratedAppCLIFixtures.Entry) throws {
            self.entry = entry
            self.response = try GeneratedAppCLIFixtures.data(entry.file)
            self.expectedRequest = try entry.request.map { try GeneratedAppCLIFixtures.data($0) }
        }
        func readConsentJSON() async throws -> CommandResult { .init(exitCode: entry.exitCode, stdout: response) }
        func grantConsentJSON(_ payload: Data) async throws -> CommandResult {
            XCTAssertEqual(payload, expectedRequest, "Replay the binary's actual stdin with its matching receipt")
            return .init(exitCode: entry.exitCode, stdout: response)
        }
    }
    func testGeneratedCanonicalReadbacksProjectThroughProductionSettingsMapping() async throws {
        for entry in try GeneratedAppCLIFixtures.manifest().entries where entry.schema == "consent" && entry.exitCode == 0 {
            let port = CommunityCLIConsentPort(transport: try Wire(entry), apiAvailable: true)
            let canonical = try await port.readCanonicalConsent()
            let snapshot = try CommunityConsentPreviewFacts(canonical: canonical).projecting()
            XCTAssertEqual(snapshot.consentGeneration, canonical.generation)
            if entry.state == "consented" {
                let codex = try XCTUnwrap(snapshot.tools.first { $0.tool == .codex })
                XCTAssertEqual(codex.providerHosts, ["chatgpt.com (Codex runtime)"])
            }
        }
    }
    func testGeneratedGrantAndForgetReceiptsIncludingCommittedCleanupFailure() async throws {
        var sawSuccess = false, sawFailure = false, sawPending = false
        var scopedMutations = Set<String>()
        for entry in try GeneratedAppCLIFixtures.manifest().entries where entry.schema == "consent-grant-response" {
            let payload = try GeneratedAppCLIFixtures.data(XCTUnwrap(entry.request))
            let request = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])
            let allow = request["allow"] as? [String] ?? []
            let deny = request["deny"] as? [String] ?? []
            let forget = request["forget"] as? [String] ?? []
            // Match the CLI's grantScopes dispatch, not the manifest's shared response schema name.
            // Scope receipts use the engine wire contract; the legacy tool port requires ok/generation.
            if !forget.isEmpty || (allow + deny).contains(where: { $0.contains(".") }) {
                let grant = try WireDecoder.decode(WireConsentGrantParams.self, from: payload)
                let result = try await Wire(entry).grantConsentJSON(payload)
                let receipt = try WireDecoder.decode(WireConsentReceipt.self, from: result.stdout)
                XCTAssertEqual(result.exitCode, 0, entry.file)
                XCTAssertEqual(receipt.requestId, grant.requestId, entry.file)
                XCTAssertTrue(receipt.committed, entry.file)
                XCTAssertEqual(receipt.committedGeneration, grant.expectGeneration + 1, entry.file)
                XCTAssertEqual(receipt.code, .ok, entry.file)
                XCTAssertTrue(receipt.cleanupPending?.isEmpty ?? true, entry.file)
                let response = try GeneratedAppCLIFixtures.object(entry.file)
                XCTAssertEqual(response["storeEpoch"] as? String, grant.expectStoreEpoch, entry.file)
                scopedMutations.insert(!forget.isEmpty ? "forget" : !allow.isEmpty ? "grant" : "revoke")
                continue
            }
            let port = CommunityCLIConsentPort(transport: try Wire(entry), apiAvailable: true)
            do {
                try await port.applyConsentJSON(payload)
                XCTAssertEqual(entry.exitCode, 0, entry.file); sawSuccess = true
            } catch let pending as CommunityConsentCleanupPending {
                XCTAssertEqual(entry.state, "cleanup-pending")
                XCTAssertEqual(pending.generation, 2)
                XCTAssertEqual(Set(pending.toolIDs), Set(["copilot", "codex"]))
                XCTAssertNotEqual(entry.exitCode, 0); sawPending = true
            } catch {
                XCTAssertNotEqual(entry.exitCode, 0, entry.file); sawFailure = true
            }
        }
        XCTAssertTrue(sawSuccess); XCTAssertTrue(sawFailure); XCTAssertTrue(sawPending)
        XCTAssertEqual(scopedMutations, Set(["grant", "revoke", "forget"]))
    }
}
