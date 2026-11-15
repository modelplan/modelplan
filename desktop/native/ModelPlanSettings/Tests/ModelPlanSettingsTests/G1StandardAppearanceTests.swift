// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanSettings

/// v1 gate G1, batch 2 (test-only): THM-10-03 and DOCK-3.4-08. Offscreen AppKit only.
@MainActor final class G1StandardAppearanceTests: XCTestCase {
    private func store() throws -> SettingsStore {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("g1-b2-settings-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return try SettingsStore(url: directory.appendingPathComponent("preferences.json"))
    }

    /// THM-10-03: a standard titled macOS window (no panel, HUD, utility or borderless style) whose appearance is
    /// inherited from macOS (nil) unless the Theme setting says otherwise.
    func testSettingsWindowIsStandardAndFollowsOnlyTheThemeSetting() async throws {
        let store = try store()
        let editor = SettingsEditor(store: store)
        let controller = SettingsWindowController(editor: editor, environmentProvider: { SettingsEnvironment() })
        await controller.prepare()
        let window = try XCTUnwrap(controller.window)
        XCTAssertFalse(window is NSPanel)
        XCTAssertTrue(window.styleMask.isSuperset(of: [.titled, .closable, .miniaturizable, .resizable]))
        XCTAssertTrue(window.styleMask.isDisjoint(with: [.borderless, .hudWindow, .utilityWindow, .nonactivatingPanel, .fullSizeContentView]))
        XCTAssertNil(window.appearance, "theme System: the window inherits the macOS appearance")
        for (theme, name) in [(SettingsTheme.night, NSAppearance.Name.darkAqua), (.day, .aqua)] {
            try await store.update { $0.theme = theme }
            await editor.reload()
            XCTAssertEqual(window.appearance?.name, name, "\(theme)")
        }
        try await store.update { $0.theme = .system }
        await editor.reload()
        XCTAssertNil(window.appearance, "back to System: macOS decides again")
        controller.close()
    }

    /// DOCK-3.4-08: no auxiliary nozzle or ear exists as a setting, in the catalogue or on any pane.
    func testNoAuxNozzleOrEarsSettingExists() async throws {
        let forbidden = ["aux", "nozzle", "ears"]
        for key in SettingKey.allCases {
            XCTAssertFalse(forbidden.contains { key.rawValue.lowercased().contains($0) }, "\(key.rawValue) must not be an auxiliary nozzle or ear setting")
        }
        let controller = SettingsWindowController(editor: SettingsEditor(store: try store()), environmentProvider: { SettingsEnvironment() })
        await controller.prepare()
        for pane in ["dock", "appearance", "notifications"] {
            controller.selectPane(pane)
            for key in controller.visibleSettingKeys {
                XCTAssertFalse(forbidden.contains { key.rawValue.lowercased().contains($0) }, "\(pane): \(key.rawValue)")
            }
        }
        controller.close()
    }
}
