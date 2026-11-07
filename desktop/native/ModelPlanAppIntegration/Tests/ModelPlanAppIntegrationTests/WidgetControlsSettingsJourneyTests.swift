// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanEngineClient
@testable import ModelPlanAppIntegration
import ModelPlanSettings

/// Settings side of the Quota Widget controls through the normal entry: the widget host reports
/// the keys it consumes, each row is usable, and a committed change reaches the widget.
@MainActor final class WidgetControlsSettingsJourneyTests: XCTestCase {
    func testWidgetControlsAreUsableAtNormalEntryAndReachTheWidget() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("widget-controls-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let config = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic",
                                               allowedEnvironment: [:], offline: true, readOnly: true)
        let app = EngineRowsEntry.make(configuration: config,
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en-US"]),
            createsNativePanels: false, dockEnvironment: normalEntryTestEnvironment, activateSettings: {})
        await app.prepare()
        let settings = app.settingsHost.application
        func row(_ key: SettingKey) throws -> SettingsRow {
            let preferences = try XCTUnwrap(settings.editor.snapshot).preferences
            return try XCTUnwrap(try SettingsCatalogue.rows(preferences: preferences, context: settings.editor.context).first { $0.key == key }, "\(key)")
        }
        for key in SettingsPageContext.widgetConsumedKeys { XCTAssertEqual(try row(key).availability, .available, "\(key)") }
        try await settings.commit(.redBelow(16))
        for _ in 0..<200 where app.composition.dock.currentMenuBarPreferences?.redBelow != 16 {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(app.composition.dock.currentMenuBarPreferences?.redBelow, 16, "the committed threshold did not reach the widget")
        await app.composition.stop()
    }
}
