// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCore

final class ConsentGatedDesktopTransportTests: XCTestCase {
    private actor Probe: CLITransport {
        let code: Int32
        init(_ code: Int32) { self.code = code }
        func execute(_ command: CLICommand) async throws -> CommandResult { .init(exitCode: code, stdout: Data()) }
    }
    private func preview(mode: String = "automatic", allowed: Bool = true, access: String = "standard") throws -> ConsentPreview {
        var data = try GeneratedAppCLIFixtures.object("consented-consent.json")
        let tools = try XCTUnwrap(data["tools"] as? [[String: Any]])
        var codex = try XCTUnwrap(tools.first { $0["id"] as? String == "codex" })
        codex["allowed"] = allowed; codex["accessClass"] = access
        data["mode"] = mode; data["tools"] = [codex]
        return try FeedDecoder.consentPreview(JSONSerialization.data(withJSONObject: data))
    }
    func testNormalRequiresCanonicalAdmissionAndInvalidationClosesIt() async throws {
        let port = ConsentGatedDesktopTransport(readOnly: Probe(69), normal: Probe(0))
        let absent = try await port.execute(.desktop)
        XCTAssertEqual(absent.exitCode, 69)
        let revision = await port.invalidateConsent()
        await port.installCanonicalReadback(try preview(), revision: revision)
        let admitted = try await port.execute(.desktop)
        XCTAssertEqual(admitted.exitCode, 0)
        let other = try await port.execute(.refreshAccount)
        XCTAssertEqual(other.exitCode, 69)
        await port.invalidateConsent()
        let acceptedLate = await port.installCanonicalReadback(try preview(), revision: revision)
        XCTAssertFalse(acceptedLate)
        let revoked = try await port.execute(.desktop)
        XCTAssertEqual(revoked.exitCode, 69)
    }
    func testOffUnallowedAndBrowserReadbacksNeverSelectNormalPort() async throws {
        let port = ConsentGatedDesktopTransport(readOnly: Probe(69), normal: Probe(0))
        for value in [try preview(mode: "off"), try preview(allowed: false), try preview(access: "browser-session")] {
            let revision = await port.invalidateConsent()
            await port.installCanonicalReadback(value, revision: revision)
            let result = try await port.execute(.desktop)
            XCTAssertEqual(result.exitCode, 69)
        }
    }
}
