// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class S08SettingsAccessibilityJourneyTests: XCTestCase {
    private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
    func testNormalSettingsTransparencyChoiceChangesSidebarLive() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("s08-settings-" + UUID().uuidString)
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
        let before = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
        await app.settingsHost.present(paneID: "appearance", origin: .userInitiated)
        let window = try XCTUnwrap(NSApplication.shared.windows.first { !before.contains(ObjectIdentifier($0)) && $0.isVisible })
        defer { window.close() }
        let controller = try XCTUnwrap(window.windowController as? SettingsWindowController)
        let popup = try XCTUnwrap(controller.choice(key: .transparency))
        XCTAssertTrue(popup.isEnabled)
        let index = try XCTUnwrap(popup.itemArray.firstIndex { ($0.representedObject as? String) == "on" })
        popup.selectItem(at: index)
        XCTAssertTrue(NSApplication.shared.sendAction(try XCTUnwrap(popup.action), to: popup.target, from: popup))
        await controller.waitForPendingSave()
        let sidebar = try XCTUnwrap(descendants(try XCTUnwrap(window.contentView)).compactMap { $0 as? NSVisualEffectView }.first { $0.material == .sidebar })
        XCTAssertTrue(sidebar.isHidden, "The actual Settings sidebar must immediately reduce transparency")
        XCTAssertEqual(app.settingsHost.application.editor.snapshot?.preferences.transparency, .on)
        await app.composition.stop()
    }
}
