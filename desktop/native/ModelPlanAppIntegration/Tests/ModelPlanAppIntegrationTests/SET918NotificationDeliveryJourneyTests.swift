// SPDX-License-Identifier: MIT
import Foundation
import XCTest

/// SET-9-18 v1 delivery through the normal entry (real EngineRowsEntry composition, synthetic
/// engine): "Quota reset" and "Official extra reset" follow their toggles, deliver once per
/// event, and a denied system authorization shows the System Settings hint.
@MainActor final class SET918NotificationDeliveryJourneyTests:XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        await MainActor.run { S4QuotaJourney.onFailure = { XCTFail($0) } }
    }
    override func tearDown() async throws {
        await MainActor.run { S4QuotaJourney.onFailure = nil }
        try await super.tearDown()
    }
    private var capture:URL {
        URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
    }
    func testSET_9_18QuotaResetOnDeliversOncePerEpisode() async throws { try await S4QuotaJourney.quotaResetDelivery(capture:capture,kindOn:true) }
    func testSET_9_18QuotaResetOffDeliversNothing() async throws { try await S4QuotaJourney.quotaResetDelivery(capture:capture,kindOn:false) }
    func testSET_9_18OfficialResetOnDeliversOnce() async throws { try await S4QuotaJourney.officialResetDelivery(kindOn:true) }
    func testSET_9_18OfficialResetOffDeliversNothing() async throws { try await S4QuotaJourney.officialResetDelivery(kindOn:false) }
    func testSET_9_18DeniedAuthorizationShowsSystemSettingsHint() async throws { try await S4QuotaJourney.deniedAuthorizationHint() }
}
