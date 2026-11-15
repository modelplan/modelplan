// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanSettings

/// Settings side of the Quota Widget controls (SET-9 widget group): each control becomes usable
/// in v1 once the widget reports it consumes that key, and loses that state again when it stops.
final class SettingsWidgetConsumersTests: XCTestCase {
    func testWidgetControlsFollowTheReportedConsumers() throws {
        var v1 = SettingsPageContext(); v1.configureV1NormalEntry()
        func availability(_ key: SettingKey) throws -> SettingAvailability {
            try XCTUnwrap(try SettingsCatalogue.rows(preferences: .init(), context: v1).first { $0.key == key }).availability
        }
        // The widget already applies the percentage switch and the red threshold (#476), so those two
        // are usable from the start; the dock-only keys stay disabled until the widget reports them.
        for key in [SettingKey.showPercentages, .redBelow] { XCTAssertEqual(try availability(key), .available, "\(key)") }
        for key in [SettingKey.magnification, .sliverAlert, .fullscreen] { XCTAssertEqual(try availability(key), .serviceUnavailable, "\(key)") }
        v1.observeWidgetConsumers([.redBelow, .showPercentages, .size])
        XCTAssertEqual(try availability(.redBelow), .available)
        XCTAssertEqual(try availability(.showPercentages), .available)
        for key in [SettingKey.magnification, .sliverAlert, .fullscreen] { XCTAssertEqual(try availability(key), .serviceUnavailable, "\(key)") }
        XCTAssertEqual(try availability(.size), .available, "keys outside the widget group are unaffected")
        v1.observeWidgetConsumers(SettingsPageContext.widgetConsumedKeys)
        for key in SettingsPageContext.widgetConsumedKeys { XCTAssertEqual(try availability(key), .available, "\(key)") }
        v1.observeWidgetConsumers([])
        for key in SettingsPageContext.widgetConsumedKeys { XCTAssertEqual(try availability(key), .serviceUnavailable, "\(key)") }
    }
}
