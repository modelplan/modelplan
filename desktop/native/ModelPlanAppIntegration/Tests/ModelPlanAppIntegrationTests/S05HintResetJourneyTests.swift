// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class S05HintResetJourneyTests: XCTestCase {
    func testNormalSettingsResetClearsPersistedHintLedger() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("s05-hint-reset-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        _ = try await store.update { $0.helpHints = FirstUseHintPreferences(seen: [.findWidget, .ringRefresh], opens: 2, reveals: 2) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
        let configuration = EngineClientConfiguration(executableURL: profile.appendingPathComponent("synthetic"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true)
        let app = EngineRowsEntry.make(configuration: configuration, settingsStore: store,
            createsNativePanels: false, dockEnvironment: normalEntryTestEnvironment,
            makeClient: { _, engineStore in SettingsJourneyClient(store: engineStore, rows: rows) }, activateSettings: {})
        await app.prepare()
        defer { app.composition.dock.close() }
        XCTAssertTrue(app.settingsHost.application.editor.context.capabilities.helpMapAvailable, "The normal entry must install its help coordinator")
        let before = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
        await app.settingsHost.present(paneID: "general", origin: .userInitiated)
        let window = try XCTUnwrap(NSApplication.shared.windows.first { !before.contains(ObjectIdentifier($0)) && $0.isVisible })
        defer { window.close() }
        let controller = try XCTUnwrap(window.windowController as? SettingsWindowController)
        let button = try XCTUnwrap(controller.hintsResetControl)
        XCTAssertFalse(button.isHiddenOrHasHiddenAncestor)
        guard button.isEnabled else { XCTFail("Show hints again must be enabled when the help coordinator is installed"); return }
        button.performClick(nil)
        await controller.waitForPendingSave()
        let after = await store.snapshot()
        XCTAssertEqual(after.preferences.helpHints, FirstUseHintPreferences())
        let reopened = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        let restored = await reopened.snapshot()
        XCTAssertEqual(restored.preferences.helpHints, FirstUseHintPreferences())
        await app.composition.stop()
    }
}
