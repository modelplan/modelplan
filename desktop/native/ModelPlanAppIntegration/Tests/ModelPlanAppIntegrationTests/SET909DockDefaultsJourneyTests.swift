// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanEngineClient
@testable import ModelPlanAppIntegration
import ModelPlanSettings

/// SET-9-09 defaults through the normal entry: on a fresh profile the packaged app's Settings
/// show the Quota Widget visible with auto-collapse on (D56, owner 2026-11-08, reversed the
/// earlier "off"), and the Dock receives the same committed values. The hover-magnification control itself is enabled by #537 (its consumer).
@MainActor final class SET909DockDefaultsJourneyTests: XCTestCase {
    func testSET_9_09FreshProfileWidgetVisibleAndAutoCollapseOn() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("set-9-09-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let config = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic",
                                               allowedEnvironment: [:], offline: true, readOnly: true)
        let app = EngineRowsEntry.make(configuration: config,
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en-US"]),
            createsNativePanels: false, dockEnvironment: normalEntryTestEnvironment, activateSettings: {})
        await app.prepare()
        let editor = app.settingsHost.application.editor
        let preferences = try XCTUnwrap(editor.snapshot).preferences
        XCTAssertTrue(preferences.showDock, "SET-9-09: the Quota Widget is visible by default")
        XCTAssertTrue(preferences.autoHide, "SET-9-09 / D56: auto-collapse is on by default")
        let rows = try SettingsCatalogue.rows(preferences: preferences, context: editor.context, paneID: "dock")
        func row(_ key: SettingKey) throws -> SettingsRow { try XCTUnwrap(rows.first { $0.key == key }, "Quota Widget pane lacks \(key)") }
        XCTAssertEqual(try row(.showDock).value, .toggle(true))
        XCTAssertEqual(try row(.autoHide).value, .toggle(true))
        for key in [SettingKey.showDock, .autoHide, .reveal, .size] {
            XCTAssertEqual(try row(key).availability, .available, "SET-9-09 control is not usable at normal entry: \(key)")
        }
        for _ in 0..<200 where app.composition.dock.currentMenuBarPreferences == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        let applied = try XCTUnwrap(app.composition.dock.currentMenuBarPreferences, "The Dock did not receive the committed settings")
        XCTAssertTrue(applied.showDock); XCTAssertTrue(applied.autoHide)
        await app.composition.stop()
    }
}
