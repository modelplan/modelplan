// SPDX-License-Identifier: MIT
import Foundation
import XCTest

@MainActor final class U8ConsentJourneyTests:XCTestCase {
    func testNormalEntrySharesOneConsentAndNeverBulkSelectsBrowserSessions() async throws {
        let capture=URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireConsentFacts.json").standardizedFileURL
        try await U8ConsentJourney.run(capture:capture)
    }
    func testConsentWrapperRetainsLiveSettingsMenuTitle() async throws { try await U8ConsentJourney.menu() }
}
