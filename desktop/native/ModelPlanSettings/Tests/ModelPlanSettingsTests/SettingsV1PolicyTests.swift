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
    func testV1NoEffectControlsAreDisabledWithVisibleReasons() throws {
        var context = SettingsPageContext(); context.configureV1NormalEntry()
        let rows = try SettingsCatalogue.rows(preferences: .init(), context: context)
        let keys: [SettingKey] = [.login, .automaticUpdates, .menuDisplay, .openShortcut, .dockShortcut,
            .resetHints, .magnification, .showPercentages, .sliverAlert, .percentagePin, .order,
            .visible, .alias, .notificationConsent, .forecast, .reset, .official, .expiring, .stale,
            .projectNames, .language, .motion, .transparency, .fullscreen, .redBelow,
            .websiteLink, .methodologyLink, .privacyLink, .repositoryLink, .feedback]
        for key in keys {
            let row = try XCTUnwrap(rows.first { $0.key == key }, "Missing visible key: \(key)")
            XCTAssertEqual(row.availability, .serviceUnavailable, "A no-effect control must not remain enabled: \(key)")
            XCTAssertTrue(row.subtitle.english.contains("Unavailable"), "Provide an English visible reason: \(key)")
            XCTAssertTrue(row.subtitle.chinese.contains("不可用"), "Provide a Chinese visible reason: \(key)")
        }
        for key in [SettingKey.size, .dockEdge, .dockDisplay, .dockPosition, .percentageMode] {
            XCTAssertEqual(try XCTUnwrap(rows.first { $0.key == key }).availability, .available)
        }
    }

}
