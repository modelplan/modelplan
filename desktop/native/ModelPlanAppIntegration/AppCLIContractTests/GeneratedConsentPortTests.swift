// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCore
import ModelPlanSettings
import ModelPlanAppIntegration

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
        for entry in try GeneratedAppCLIFixtures.manifest().entries where entry.schema == "consent-grant-response" {
            let payload = try GeneratedAppCLIFixtures.data(XCTUnwrap(entry.request))
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
    }
}
