// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCore
import ModelPlanSettings
import ModelPlanAppIntegration

@MainActor final class CLIConsentPortTests: XCTestCase {
    private actor Desktop: CLITransport {
        func execute(_ command: CLICommand) async throws -> CommandResult { throw TransportError.launchFailed }
    }
    private actor Port: ConsentJSONTransport {
        let reply: Data
        var calls = 0
        init(_ reply: Data) { self.reply = reply }
        func readConsentJSON() async throws -> CommandResult { calls += 1; return .init(exitCode: 0, stdout: reply) }
        func grantConsentJSON(_ payload: Data) async throws -> CommandResult { calls += 1; return .init(exitCode: 0, stdout: reply) }
        func count() -> Int { calls }
    }
    func testDefaultUnavailableNeverCallsHelper() async {
        let transport = Port(Data()), port = CommunityCLIConsentPort(transport: transport)
        do { _ = try await port.readCanonicalConsent(); XCTFail("Unavailable release must refuse") } catch { }
        let calls = await transport.count(); XCTAssertEqual(calls, 0)
    }
    func testProductionBackendPropagatesDisabledCapabilityWithoutRetrying() async throws {
        let transport = Port(Data()), port = CommunityCLIConsentPort(transport: transport)
        let desktop = Desktop()
        let backend = CommunityConnectionBackend(port: port, desktop: .init(readOnly: desktop, normal: desktop))
        let controller = SettingsConnectionController(service: backend)
        XCTAssertEqual(controller.availability.reason, .componentUnverified)
        XCTAssertFalse(controller.availability.hasAnyAction)
        await controller.refresh()
        do { _ = try await backend.detect(); XCTFail("Must refuse") } catch { }
        let calls = await transport.count(); XCTAssertEqual(calls, 0)
        let copy = try XCTUnwrap(SettingsConnectionPresentation.availability(controller.availability))
        XCTAssertTrue(copy.chinese.contains("关于")); XCTAssertFalse(copy.english.contains("Request unavailable:"))
    }
    func testGrantReceiptMustMatchRequestAndContainCanonicalGeneration() async throws {
        let payload = try GeneratedAppCLIFixtures.data("consented-grant.request.json")
        let success = try GeneratedAppCLIFixtures.object("consented-grant.json")
        for mutation in ["mismatchedID", "missingGeneration", "failed"] {
            var reply = success
            if mutation == "mismatchedID" { reply["requestId"] = UUID().uuidString }
            if mutation == "missingGeneration" { reply.removeValue(forKey: "generation") }
            if mutation == "failed" { reply["ok"] = false }
            let port = CommunityCLIConsentPort(transport: Port(try JSONSerialization.data(withJSONObject: reply)), apiAvailable: true)
            do { try await port.applyConsentJSON(payload); XCTFail("Malformed/mismatched receipt must refuse") } catch { }
        }
        let port = CommunityCLIConsentPort(transport: Port(try GeneratedAppCLIFixtures.data("consented-grant.json")), apiAvailable: true)
        try await port.applyConsentJSON(payload)
    }
}
