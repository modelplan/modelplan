// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanEngineClient
@testable import ModelPlanAppIntegration
import ModelPlanSettings

/// SET-9-16 / SET-9-26 through the normal entry: the packaged app's subscription controls are
/// usable, because the Dock, its card and the menu bar all consume them.
@MainActor final class SET916SubscriptionControlsJourneyTests: XCTestCase {
    func testSET_9_16NormalEntryEnablesSubscriptionControls() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("set-9-16-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let config = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic",
                                               allowedEnvironment: [:], offline: true, readOnly: true)
        let app = EngineRowsEntry.make(configuration: config,
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en-US"]),
            createsNativePanels: false, dockEnvironment: normalEntryTestEnvironment, activateSettings: {})
        await app.prepare()
        let editor = app.settingsHost.application.editor
        XCTAssertTrue(editor.context.v1NormalEntry)
        let rows = try SettingsCatalogue.rows(preferences: try XCTUnwrap(editor.snapshot).preferences, context: editor.context)
        for key in [SettingKey.percentagePin, .order, .visible, .alias] {
            XCTAssertNil(editor.context.unavailableControls[key], "still disabled: \(key)")
            XCTAssertEqual(rows.first { $0.key == key }?.availability, .available, "not usable: \(key)")
        }
        await app.composition.stop()
    }
}
