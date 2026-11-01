// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class OfficialDockEntryJourneyTests: XCTestCase {
    func testNormalEngineRowsEntryPresentsOfficialDockHull() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("official-dock-entry-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = EngineRowsEntry.make(
            configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true),
            settingsStore: try SettingsStore(url: root.appendingPathComponent("settings.json")), createsNativePanels: false)
        await app.prepare()
        defer { app.composition.dock.close() }
        XCTAssertNil(app.composition.dock.lastAppearanceError, "Official appearance failed: \(String(describing: app.composition.dock.lastAppearanceError))")
        XCTAssertNotNil(app.composition.dock.dockView.registeredHullPath,
                        "The normal engine-rows entry must present the official Dock hull")
        XCTAssertNotNil(app.composition.dock.dockView.registeredMovePreviewImage,
                        "The official material must be available from the real production host")
        XCTAssertNil(app.composition.dock.nativePanel)
    }
}
