// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCore

final class ConsentPreviewTests: XCTestCase {
    func testRealReadbackPreservesUnknownKeychainAndExactNotice() throws {
        let data = try GeneratedAppCLIFixtures.data("consented-consent.json")
        let value = try FeedDecoder.consentPreview(data)
        let raw = try GeneratedAppCLIFixtures.object("consented-consent.json")
        XCTAssertEqual(value.mode, .automatic)
        let claude = try XCTUnwrap(value.tools.first { $0.id == "claude" })
        XCTAssertEqual(claude.keychain, .unset)
        XCTAssertFalse(claude.allowed)
        XCTAssertEqual(value.consentText.zh, (raw["consentText"] as? [String: String])?["zh"])
        XCTAssertEqual(claude.hosts, ["https://api.anthropic.com"])
    }
    func testUnknownCanonicalModesAndInventedKeychainStatesFailClosed() throws {
        let data = try GeneratedAppCLIFixtures.data("consented-consent.json")
        let valid = try XCTUnwrap(String(data: data, encoding: .utf8))
        for text in [valid.replacingOccurrences(of: "\"automatic\"", with: "\"enabled\""),
                     valid.replacingOccurrences(of: "\"unset\"", with: "\"notRequired\"")] {
            XCTAssertThrowsError(try FeedDecoder.consentPreview(Data(text.utf8)))
        }
    }
}
