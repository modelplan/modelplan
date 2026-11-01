// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanSettings

final class SettingsV1PolicyTests: XCTestCase {
    func testV1HidesUnsupportedAppearanceAndIgnitionChoices() throws {
        var context = SettingsPageContext(); context.v1NormalEntry = true
        let defaults = SettingsPreferences()
        let rows = try SettingsCatalogue.rows(preferences: defaults, context: context)
        XCTAssertFalse(rows.contains { $0.key == .theme })
        XCTAssertFalse(rows.contains { $0.key == .opening })
        XCTAssertFalse(rows.contains { $0.key == .countdown })
        XCTAssertEqual(defaults.percentageMode, .remaining)
        guard case .choice(let selected, let options) = try XCTUnwrap(rows.first { $0.key == .percentageMode }).value else {
            return XCTFail("Percentage choice must stay available")
        }
        XCTAssertEqual(selected, "remaining"); XCTAssertTrue(options.contains("used"))
        var old = defaults; old.theme = .day; old.opening = .hold
        var environment = SettingsEnvironment(); environment.v1NormalEntry = true
        environment.macOSMajor = 15; environment.entranceAccepted = true
        let effective = EffectiveSettings(old, environment: environment)
        XCTAssertTrue(effective.darkAppearance, "V1 is night only even for a retained day preference")
        XCTAssertEqual(effective.opening, .quick, "V1 opens quickly even with a retained hold preference")
        XCTAssertNil(effective.ignitionSeconds)
    }
}
