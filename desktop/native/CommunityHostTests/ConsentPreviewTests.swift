// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCore

final class ConsentPreviewTests: XCTestCase {
    private let valid = #"{"generation":0,"consentTextVersion":2,"mode":"off","consentText":{"en":"Allow","zh":"允许"},"tools":[{"id":"codex","displayName":"Codex","accessClass":"standard","detected":true,"allowed":false,"backend":"native","readerId":"native:codex","keychain":"unset","hosts":["example.test"]}]}"#
    func testFreshOffReadbackPreservesUnknownPermissionAndExactNotice() throws {
        let value = try FeedDecoder.consentPreview(Data(valid.utf8))
        XCTAssertEqual(value.mode, .off)
        XCTAssertEqual(value.tools[0].keychain, .unset)
        XCTAssertFalse(value.tools[0].allowed)
        XCTAssertEqual(value.consentText.zh, "允许")
        XCTAssertEqual(value.tools[0].hosts, ["example.test"])
    }
    func testUnknownCanonicalModesAndInventedKeychainStatesFailClosed() {
        for text in [valid.replacingOccurrences(of: "\"off\"", with: "\"enabled\""),
                     valid.replacingOccurrences(of: "\"unset\"", with: "\"notRequired\"")] {
            XCTAssertThrowsError(try FeedDecoder.consentPreview(Data(text.utf8)))
        }
    }
}
