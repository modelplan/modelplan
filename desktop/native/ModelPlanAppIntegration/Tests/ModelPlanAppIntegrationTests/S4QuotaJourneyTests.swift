// SPDX-License-Identifier: MIT
import Foundation
import XCTest

@MainActor final class S4QuotaJourneyTests:XCTestCase {
    func testFailureIsReportedBeforeThrowingScratchTeardown() {
        struct SyntheticCleanupError:Error {}
        let existingFixture=URL(fileURLWithPath:#filePath)
        XCTExpectFailure("The synthetic journey failure is reported") {
            do {
                defer {
                    XCTExpectFailure("The synthetic cleanup failure is reported") {
                        S4QuotaJourney.removeScratch(existingFixture,remove:{ _ in throw SyntheticCleanupError() })
                    }
                }
                throw S4QuotaJourney.Failure(description:"original synthetic journey failure")
            } catch let failure as S4QuotaJourney.Failure {
                XCTAssertEqual(failure.description,"original synthetic journey failure")
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
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
