// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanSettings

@MainActor final class DockPlacementTests: XCTestCase {
    func testMissingFieldsAndSavedChoices() throws {
        let missing = try JSONDecoder().decode(SettingsPreferences.self, from: Data("{}".utf8))
        XCTAssertNil(missing.dockDisplayID); XCTAssertEqual(missing.dockAlongFraction, 0.5)
        XCTAssertFalse(missing.followActiveDisplay)
        var saved = missing
        saved.dockDisplayID = "display-negative-origin"; saved.dockAlongFraction = 0.327
        saved.dockEdge = .left; saved.followActiveDisplay = true
        let restored = try JSONDecoder().decode(SettingsPreferences.self, from: JSONEncoder().encode(saved))
        XCTAssertEqual(restored.dockDisplayID, saved.dockDisplayID)
        XCTAssertEqual(restored.dockAlongFraction, 0.327)
        XCTAssertEqual(restored.dockEdge, .left); XCTAssertTrue(restored.followActiveDisplay)
        for bad in [-0.01, 1.01, .nan, .infinity] {
            saved.dockAlongFraction = bad; XCTAssertThrowsError(try saved.validate())
        }
    }
    func testPlacementCommitsAtomicallyAndSurvivesDisconnectedDisplay() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("settings.json")
        let editor = SettingsEditor(store: try SettingsStore(url: url))
        await editor.reload()
        _ = try await editor.commit(.dockPlacement(displayID: "external", edge: .bottom, alongFraction: 0.37))
        let store = try SettingsStore(url: url)
        let snapshot = await store.snapshot()
        let saved = snapshot.preferences
        XCTAssertEqual(saved.dockDisplayID, "external"); XCTAssertEqual(saved.dockEdge, .bottom)
        XCTAssertEqual(saved.dockAlongFraction, 0.37)
        var context = SettingsPageContext()
        let disconnected = try SettingsCatalogue.rows(preferences: saved, context: context)
        XCTAssertEqual(disconnected.first { $0.key == .dockDisplay }?.value, .choice("external", options: ["primary", "external"]))
        XCTAssertEqual(disconnected.first { $0.key == .dockPosition }?.paneID, "dock")
        context.displays = [.init(id: "external", name: "External")]
        let reconnected = try SettingsCatalogue.rows(preferences: saved, context: context)
        XCTAssertEqual(reconnected.first { $0.key == .dockDisplay }?.value, .choice("external", options: ["primary", "external"]))
        _ = try await editor.commit(.activeDisplay(true))
        XCTAssertEqual(editor.snapshot?.preferences.dockAlongFraction, 0.37)
        _ = try await editor.commit(.dockDisplay("other"))
        XCTAssertFalse(try XCTUnwrap(editor.snapshot).preferences.followActiveDisplay)
        XCTAssertEqual(editor.snapshot?.preferences.dockAlongFraction, 0.37)
    }
}
