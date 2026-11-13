// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanEngineClient
@testable import ModelPlanAppIntegration
import ModelPlanSettings

/// SET-9-06 defaults through the normal entry (owner decision D37, 2026-11-06: no default
/// shortcuts). On a fresh profile the packaged app's Settings keep both the open-cockpit and
/// the show-Quota-Widget shortcut unassigned, General shows them as unset, and no key chord,
/// local or global, triggers either action. The ⌘, Settings menu key (S-02) is a menu key
/// equivalent, not one of these preferences.
@MainActor final class SET906ShortcutDefaultsJourneyTests: XCTestCase {
    func testSET_9_06FreshProfileAssignsNoShortcuts() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("set-9-06-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let config = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic",
                                               allowedEnvironment: [:], offline: true, readOnly: true)
        let app = EngineRowsEntry.make(configuration: config,
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en-US"]),
            createsNativePanels: false, dockEnvironment: normalEntryTestEnvironment, activateSettings: {})
        await app.prepare()
        let editor = app.settingsHost.application.editor
        let preferences = try XCTUnwrap(editor.snapshot).preferences
        XCTAssertTrue(preferences.openShortcut.isUnassigned, "SET-9-06: no default open-cockpit shortcut")
        XCTAssertTrue(preferences.dockShortcut.isUnassigned, "SET-9-06: no default show-Quota-Widget shortcut")
        let rows = try SettingsCatalogue.rows(preferences: preferences, context: editor.context, paneID: "general")
        for key in [SettingKey.openShortcut, .dockShortcut] {
            let row = try XCTUnwrap(rows.first { $0.key == key }, "General lacks \(key)")
            XCTAssertEqual(row.value, .text("--"), "SET-9-06: \(key) is shown unset")
        }
        let policy = ShortcutPolicy()
        for modifiers in [[ShortcutChord.Modifier.command, .shift], [.command, .option], [.control, .option]] {
            for key in ["M", "D", "K", "P"] {
                let chord = ShortcutChord(key, modifiers: Set(modifiers))
                for global in [false, true] {
                    XCTAssertNil(policy.action(for: chord, preferences: preferences, global: global),
                                 "SET-9-06: \(modifiers)+\(key) triggers an action on a fresh profile")
                }
            }
        }
        await app.composition.stop()
    }
}
