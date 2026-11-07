// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanSettings

/// SET-9-18: the reset and official kinds are usable in v1 once the app reports delivery; a
/// denied system authorization shows the System Settings hint on the opt-in row.
final class SettingsV1NotificationDeliveryTests: XCTestCase {
    func testResetAndOfficialFollowReportedDelivery() throws {
        var v1 = SettingsPageContext(); v1.configureV1NormalEntry()
        func availability(_ key: SettingKey) throws -> SettingAvailability? {
            try SettingsCatalogue.rows(preferences: .init(), context: v1).first { $0.key == key }?.availability
        }
        XCTAssertEqual(try availability(.reset), .serviceUnavailable)
        XCTAssertEqual(try availability(.official), .serviceUnavailable)
        v1.observeNotificationDelivery(true)
        XCTAssertEqual(try availability(.reset), .available)
        XCTAssertEqual(try availability(.official), .available)
        v1.observeNotificationDelivery(false)
        XCTAssertEqual(try availability(.reset), .serviceUnavailable)
        XCTAssertEqual(SettingsPreferences().notifications.kinds, Set(NotificationKind.allCases))
    }
}
