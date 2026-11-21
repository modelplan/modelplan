// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanSettings

/// SET-9-18: the v1 normal entry hides the two v1.1 notification kinds; other entries (and the
/// saved preference) keep all five, so nothing is lost when v1.1 turns them on.
final class SettingsV1NotificationKindsTests: XCTestCase {
    func testSET_9_18V1HidesResetsExpiringAndDataStopped() throws {
        var v1 = SettingsPageContext(); v1.configureV1NormalEntry()
        let rows = try SettingsCatalogue.rows(preferences: .init(), context: v1)
        XCTAssertFalse(rows.contains { [.expiring, .stale].contains($0.key) })
        XCTAssertEqual(Set(rows.map(\.key)).intersection([.forecast, .reset, .official, .expiring, .stale]), [.reset, .official])
        let full = try SettingsCatalogue.rows(preferences: .init(), context: .init())
        XCTAssertTrue(full.contains { $0.key == .expiring } && full.contains { $0.key == .stale })
        XCTAssertEqual(SettingsPreferences().notifications.kinds, Set(NotificationKind.allCases), "The saved preference keeps every kind")
    }
    /// ALR-52 (WP-11, supersedes SET-9-29): v1 sends only the reset and official-extra-reset kinds, so the forecast
    /// kind has no v1 row even when the engine reports its forecast producer (the forecast shows on the ALERT lamp).
    func testALR_52V1OffersOnlyTheTwoDeliveredKinds() throws {
        XCTAssertEqual(NotificationKind.delivered, [.reset, .official])
        var v1 = SettingsPageContext(); v1.configureV1NormalEntry()
        for producer in [false, true] {
            v1.observeForecastProducer(producer)
            let kinds = try SettingsCatalogue.rows(preferences: .init(), context: v1).compactMap { NotificationKind(rawValue: $0.key.rawValue) }
            XCTAssertEqual(Set(kinds), NotificationKind.delivered, "producer \(producer)")
        }
        // Outside the v1 entry nothing is hidden, and the saved preference keeps every kind.
        XCTAssertTrue(try SettingsCatalogue.rows(preferences: .init(), context: .init()).contains { $0.key == .forecast })
        XCTAssertEqual(SettingsPreferences().notifications.kinds, Set(NotificationKind.allCases))
    }
}
