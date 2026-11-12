// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanSettings

/// SET-9-12: hide-from-screen-capture is OFF by default (owner decision C19, 2026-11-01: "off, so
/// screenshots show the Dock as users expect"). v1 has no switch for it: the Settings row stays
/// visible with its not-supported reason and there is no writable preference, so "off" cannot drift.
final class SET912CaptureHidingDefaultTests: XCTestCase {
    func testSET_9_12CaptureHidingRowIsVisibleUnsupportedAndUnwritable() throws {
        var context = SettingsPageContext(); context.configureV1NormalEntry()
        let rows = try SettingsCatalogue.rows(preferences: .init(), context: context, paneID: "dock")
        let row = try XCTUnwrap(rows.first { $0.key == .captureHiding }, "SET-9-12: the capture-hiding row must stay visible with its reason")
        XCTAssertEqual(row.availability, .unsupportedCaptureHiding, "SET-9-12: no v1 control can turn capture hiding on")
        XCTAssertTrue(row.subtitle.english.contains("not supported"), "The English reason must say hiding is not supported")
        XCTAssertTrue(row.subtitle.chinese.contains("不支持"), "The Chinese reason must say hiding is not supported")
        let value = try SettingsCatalogue.rows(preferences: .init(), context: context, paneID: "dock", query: "capture").first { $0.key == .captureHiding }
        XCTAssertEqual(value?.availability, .unsupportedCaptureHiding, "Search must surface the same unsupported row, not a hidden toggle")
    }

    func testSET_9_12CaptureHidingStaysUnsupportedInEveryEntryMode() throws {
        // Off is the only state: the persisted defaults expose no capture-hiding field to flip,
        // and the full (non-v1) catalogue keeps the row unsupported too, so nothing can enable it.
        let preferences = SettingsPreferences()
        var v1 = SettingsPageContext(); v1.configureV1NormalEntry()
        for context in [v1, SettingsPageContext()] {
            let rows = try SettingsCatalogue.rows(preferences: preferences, context: context)
            let row = try XCTUnwrap(rows.first { $0.key == .captureHiding })
            XCTAssertEqual(row.availability, .unsupportedCaptureHiding, "Capture hiding stays unsupported in every entry mode")
        }
    }
}
