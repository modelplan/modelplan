// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCore
import ModelPlanSettings
import ModelPlanAppIntegration

@MainActor final class CanonicalConnectionBackendTests: XCTestCase {
    private actor Probe: CLITransport {
        let code: Int32
        init(_ code: Int32) { self.code = code }
        func execute(_ command: CLICommand) async throws -> CommandResult { .init(exitCode: code, stdout: Data()) }
    }
    private final class Port: CommunityConsentCommandPort {
        var availability: SettingsConnectionAvailability { .init(canInspect: true, canGrant: true, canForget: true) }
        var reads = 0, writes = 0
        var expectedDeny: [String] = []
        let value: ConsentPreview
        init() throws {
            value = try FeedDecoder.consentPreview(Data(#"{"generation":1,"consentTextVersion":2,"mode":"automatic","consentText":{"en":"Allow","zh":"允许"},"tools":[{"id":"codex","displayName":"Codex","accessClass":"standard","detected":true,"allowed":false,"backend":"native","readerId":"native:codex","keychain":"unset","hosts":["example.test"]}]}"#.utf8))
        }
        func readCanonicalConsent() async throws -> ConsentPreview { reads += 1; return value }
        func applyConsentJSON(_ payload: Data) async throws {
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])
            XCTAssertEqual(object["deny"] as? [String], expectedDeny)
            writes += 1 // Successful receipt intentionally does not change canonical permission.
        }
    }
    func testSuccessfulReceiptCannotActivateWithoutCanonicalReadback() async throws {
        let port = try Port(), gate = ConsentGatedDesktopTransport(readOnly: Probe(69), normal: Probe(0))
        let service = CommunityConnectionBackend(port: port, desktop: gate)
        _ = try await service.applyStandardConsent(allow: [.codex], deny: [], request: .init(id: UUID(), expectedConsentGeneration: 1, consentTextVersion: 2))
        XCTAssertEqual(port.reads, 2); XCTAssertEqual(port.writes, 1)
        let result = try await gate.execute(.desktop)
        XCTAssertEqual(result.exitCode, 69)
    }
    func testStaleGenerationAndImplicitForgetCannotReachMutation() async throws {
        let port = try Port(), gate = ConsentGatedDesktopTransport(readOnly: Probe(69), normal: Probe(0))
        let service = CommunityConnectionBackend(port: port, desktop: gate)
        for (generation, deny) in [(UInt64(0), [SettingsConnectionTool]()), (UInt64(1), [.codex])] {
            do {
                _ = try await service.applyStandardConsent(allow: [.codex], deny: deny, request: .init(id: UUID(), expectedConsentGeneration: generation, consentTextVersion: 2))
                XCTFail("Must refuse before mutation")
            } catch { }
        }
        XCTAssertEqual(port.writes, 0)
    }
    func testExplicitDisconnectSendsOnlyConfirmedDenialAndRereads() async throws {
        let port = try Port(); port.expectedDeny = ["codex"]
        let desktop = Probe(69)
        let service = CommunityConnectionBackend(port: port, desktop: .init(readOnly: desktop, normal: desktop))
        _ = try await service.disconnect(.codex, request: .init(id: UUID(), expectedConsentGeneration: 1, consentTextVersion: 2))
        XCTAssertEqual(port.reads, 2); XCTAssertEqual(port.writes, 1)
    }
}
