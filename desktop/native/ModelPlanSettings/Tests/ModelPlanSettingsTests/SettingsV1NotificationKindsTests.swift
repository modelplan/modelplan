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
    func testSET_9_29ForecastKindFollowsTheEngineForecastProducer() throws {
        var v1 = SettingsPageContext(); v1.configureV1NormalEntry()
        XCTAssertFalse(try SettingsCatalogue.rows(preferences: .init(), context: v1).contains { $0.key == .forecast })
        v1.observeForecastProducer(true)
        let shown = try XCTUnwrap(try SettingsCatalogue.rows(preferences: .init(), context: v1).first { $0.key == .forecast })
        XCTAssertEqual(shown.availability, .available)
        XCTAssertEqual(shown.value, .toggle(true))
        v1.observeForecastProducer(false)
        XCTAssertFalse(try SettingsCatalogue.rows(preferences: .init(), context: v1).contains { $0.key == .forecast })
        XCTAssertNotNil(v1.unavailableControls[.forecast])
        // Outside the v1 entry nothing is hidden.
        XCTAssertTrue(try SettingsCatalogue.rows(preferences: .init(), context: .init()).contains { $0.key == .forecast })
    }
}
