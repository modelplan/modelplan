// SPDX-License-Identifier: MIT
import Foundation
import XCTest

@MainActor final class S4QuotaJourneyTests:XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        await MainActor.run { S4QuotaJourney.onFailure = { XCTFail($0) } }
    }
    override func tearDown() async throws {
        await MainActor.run { S4QuotaJourney.onFailure = nil }
        try await super.tearDown()
    }
    func testFailureIsReportedBeforeThrowingScratchTeardown() {
        struct SyntheticCleanupError:Error {}
        let existingFixture=URL(fileURLWithPath:#filePath)
        let oldHook=S4QuotaJourney.onFailure
        defer { S4QuotaJourney.onFailure=oldHook }
        var reported:[String]=[]
        S4QuotaJourney.onFailure={ reported.append($0) }
        func journey() throws {
            defer { S4QuotaJourney.removeScratch(existingFixture,remove:{ _ in throw SyntheticCleanupError() }) }
            throw S4QuotaJourney.Failure(description:"original synthetic journey failure")
        }
        XCTAssertThrowsError(try journey()) { error in
            guard let failure=error as? S4QuotaJourney.Failure else { return XCTFail("Unexpected error: \(error)") }
            XCTAssertEqual(failure.description,"original synthetic journey failure")
        }
        XCTAssertEqual(reported,["original synthetic journey failure"])
    }
    func testNormalEntryStrictScopeAndResetEvents() async throws {
        let capture=URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        try await S4QuotaJourney.strictScopeAndEvents(capture:capture)
    }
    func testNormalEntryAnnouncedResetShowsMenuIndicator() async throws {
        let capture=URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let displayed=try await S4QuotaJourney.announcedMenuIndicator(capture:capture)
        XCTAssertTrue(displayed,"an announced reset must reach the normal menu-bar indicator")
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
    func testDOCK_3_3_04NormalEntryUsesTightestIncludingMonthly() async throws {
        let capture=URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        try await S4QuotaJourney.roles(capture:capture,verifyMonthlyMinimum:true)
    }
    func testDOCK_3_4_09NormalEntryProjectsSnapshotEvent() async throws {
        let capture=URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        try await S4QuotaJourney.strictScopeAndEvents(capture:capture)
    }
    func testDOCK_3_7_06AnnouncementDoesNotRefillPersonalReading() async throws {
        let capture=URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        try await S4QuotaJourney.strictScopeAndEvents(capture:capture)
    }
    func testDOCK_3_8_09NormalEntryTodayRow() throws {
        throw XCTSkip("Account-scoped today wire and Dock consumer are pending #481 and #485; no account data may be invented.")
    }
    func testDOCK_3_8_12NormalEntryKeepsScopedExtrasInCard() async throws {
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
