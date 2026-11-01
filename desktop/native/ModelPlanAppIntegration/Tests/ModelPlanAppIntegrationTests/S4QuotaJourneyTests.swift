// SPDX-License-Identifier: MIT
import Foundation
import XCTest

@MainActor final class S4QuotaJourneyTests:XCTestCase {
    func testNormalEntryRolesAndGeneralTightest() async throws {
        let capture=URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        try await S4QuotaJourney.roles(capture:capture)
    }
    func testNormalEntryHasOneNozzlePerAccountMember() async throws {
        let capture=URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        try await S4QuotaJourney.members(capture:capture)
    }
}
