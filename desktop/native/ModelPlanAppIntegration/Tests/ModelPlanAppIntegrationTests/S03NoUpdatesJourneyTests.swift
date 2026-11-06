// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class S03NoUpdatesJourneyTests: XCTestCase {
    func testNormalSettingsNeverExposesUpdateRowsWhenCapabilityIsPresent() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("s03-no-updates-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
        let config = EngineClientConfiguration(executableURL: profile.appendingPathComponent("synthetic"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true)
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        let app = EngineRowsEntry.make(configuration: config, settingsStore: store, createsNativePanels: false,
            dockEnvironment: normalEntryTestEnvironment,
            makeClient: { _, engineStore in SettingsJourneyClient(store: engineStore, rows: rows) }, activateSettings: {})
        await app.prepare()
        defer { app.composition.dock.close() }
        var context = app.settingsHost.application.editor.context
        XCTAssertTrue(context.v1NormalEntry)
        context.capabilities.updateServiceAvailable = true
        context.unavailableControls.removeValue(forKey: .automaticUpdates)
        context.unavailableControls.removeValue(forKey: .updateStatus)
        app.settingsHost.application.update(context: context)
        let before = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
        await app.settingsHost.present(paneID: "general", origin: .userInitiated)
        let window = try XCTUnwrap(NSApplication.shared.windows.first { !before.contains(ObjectIdentifier($0)) && $0.isVisible })
        defer { window.close() }
        let controller = try XCTUnwrap(window.windowController as? SettingsWindowController)
        for pane in SettingsStructure.task65.panes {
            controller.selectPane(pane.id)
            XCTAssertFalse(controller.visibleSettingKeys.contains(.automaticUpdates), "Automatic update row leaked into \(pane.id)")
            XCTAssertFalse(controller.visibleSettingKeys.contains(.updateStatus), "Update action leaked into \(pane.id)")
        }
        await app.composition.stop()
    }
}
