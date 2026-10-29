// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCore

final class GeneratedDecoderTests: XCTestCase {
    func testEveryGeneratedAppJSONResponseUsesTheProductionDecoder() throws {
        let manifest = try GeneratedAppCLIFixtures.manifest()
        var covered = Set<String>()
        for entry in manifest.entries where entry.exitCode == 0 && entry.encoding == "json" {
            let data = try GeneratedAppCLIFixtures.data(entry.file)
            switch entry.schema {
            case "desktop":
                let snapshot = try FeedDecoder.personal(data)
                if entry.state == "refreshed" {
                    let account = try XCTUnwrap(snapshot.accounts?.first)
                    XCTAssertEqual(account.source, "native:copilot")
                    XCTAssertEqual(account.windows?.first?.remainingPercent, 75)
                } else {
                    XCTAssertTrue((snapshot.accounts ?? []).isEmpty, entry.file)
                }
                if entry.state == "unreadable" {
                    let source = try XCTUnwrap(snapshot.sources?.first { $0.source == "native:copilot" })
                    XCTAssertNotEqual(source.status, "ok")
                    XCTAssertEqual(source.reason, "parse_error")
                    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
                    let sources = try XCTUnwrap(object["sources"] as? [[String: Any]])
                    let wireSource = try XCTUnwrap(sources.first { $0["source"] as? String == "native:copilot" })
                    XCTAssertEqual(wireSource["errorCode"] as? String, "parse_error")
                }
            case "consent":
                let preview = try FeedDecoder.consentPreview(data)
                if ["consented", "refreshed", "unreadable"].contains(entry.state) {
                    XCTAssertEqual(preview.tools.first { $0.id == "codex" }?.allowed, true)
                } else { XCTAssertFalse(preview.tools.contains { $0.allowed }) }
            case "publication": _ = try FeedDecoder.publication(data)
            case "detect": _ = try FeedDecoder.detection(data)
            default: continue // Supporting diagnostics and grant receipts have different consumers.
            }
            covered.insert(entry.schema + ":" + entry.state)
        }
        for state in manifest.states {
            for schema in ["desktop", "consent", "publication", "detect"] {
                XCTAssertTrue(covered.contains(schema + ":" + state), schema + ":" + state)
            }
        }
    }
    func testCurrentTransportArgumentsAllHaveGeneratedCaptures() throws {
        let entries = try GeneratedAppCLIFixtures.manifest().entries
        for command in CLICommand.allCases {
            XCTAssertTrue(entries.contains { $0.arguments == command.arguments }, command.rawValue)
        }
    }
    func testNegativeDecoderCasesMutateRealBinaryCapture() throws {
        var object = try GeneratedAppCLIFixtures.object("refreshed-desktop-read-only.json")
        object["contractVersion"] = 999
        XCTAssertThrowsError(try FeedDecoder.personal(JSONSerialization.data(withJSONObject: object)))
    }
}
