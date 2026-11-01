// SPDX-License-Identifier: MIT
import Foundation
import XCTest

@MainActor final class S4QuotaJourneyTests:XCTestCase {
    func testNormalEntryAnnouncedResetShowsMenuIndicator() async throws {
        let capture=URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let title=try await S4QuotaJourney.announcedMenuIndicator(capture:capture)
        let options=XCTExpectedFailure.Options()
        options.isStrict=true
        XCTExpectFailure("completed by #412 (menu notice indicator)",options:options) {
            XCTAssertFalse(title.isEmpty,"an announced reset must show the normal menu-bar indicator")
        }
    }
    func testNormalEntryRejectsUnstableMemberPersistenceAcrossRefreshAndRestart() async throws {
        let capture=URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        try await S4QuotaJourney.unstablePersistence(capture:capture)
    }
    func testNormalEntrySettingsSourceStates() async throws {
        let capture=URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        try await S4QuotaJourney.sourceStates(capture:capture)
    }
    func testNormalEntryResetEvents() async throws {
        let capture=URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        try await S4QuotaJourney.resetEvents(capture:capture)
    }
    func testNormalEntryRolesAndGeneralTightest() async throws {
        let capture=URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        try await S4QuotaJourney.roles(capture:capture)
    }
    func testNormalEntryHasOneNozzlePerAccountMember() async throws {
        let capture=URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        try await S4QuotaJourney.members(capture:capture)
    }
    func testNormalEntryLeavesMissingCardFactsUnknown() async throws {
        let capture=URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        try await S4QuotaJourney.unknownFacts(capture:capture)
    }
    func testNormalEntryRetainsCollidingUnboundMemberNozzles() async throws {
        let capture=URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        try await S4QuotaJourney.collisions(capture:capture)
    }
    func testNormalEntryUsesOneLanguageAndGlossaryPerSurface() async throws {
        let capture=URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        try await S4QuotaJourney.language(capture:capture)
    }
}
