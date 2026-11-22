// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanSettings

/// G3-161 (WP-17 / G3-147 follow-up): every engine rows/changed delivery reached `SettingsWindowController.refresh` and
/// rebuilt the whole Plugins section (656 samples in the owner's `sample`). Invariant: unchanged inputs cause no Settings
/// rebuild. The engine update is `SettingsEditor.update(context:)`, the call the app makes for each delivery.
final class G3161SettingsRefreshTests: XCTestCase {
    private func directory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("g3161-settings-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir
    }
    @MainActor private func makeController() async throws -> (SettingsWindowController, SettingsCockpitPluginsView, SettingsEditor) {
        let dir = try directory()
        let editor = SettingsEditor(store: try SettingsStore(url: dir.appendingPathComponent("preferences.json")))
        let controller = SettingsWindowController(editor: editor, environmentProvider: { .init() })
        await controller.prepare()
        controller.attachCockpitPlugins(CockpitPluginSettingsModel(store: CockpitPluginStore(directory: dir)))
        controller.selectPane("subscriptions")
        return (controller, try XCTUnwrap(controller.cockpitPluginsView), editor)
    }

    /// N engine updates with an unchanged plugin catalogue and state rebuild the plugins section 0 times.
    @MainActor func testEngineUpdatesWithAnUnchangedCatalogueDoNotRebuildThePluginsView() async throws {
        let (controller, view, editor) = try await makeController()
        let rebuilds = view.rebuildCountForChecks
        for _ in 0..<20 { editor.update(context: editor.context) }
        XCTAssertEqual(view.rebuildCountForChecks, rebuilds, "G3-161: unchanged inputs cause no plugin view rebuild")
        // A change of what the section shows still rebuilds it.
        controller.selectPane("general")
        controller.selectPane("subscriptions")
        XCTAssertGreaterThan(view.rebuildCountForChecks, rebuilds, "a pane change that changes the section still rebuilds it")
        controller.close()
    }

    /// A hidden Settings window does no rebuild for an engine update; showing it brings it up to date once.
    @MainActor func testAHiddenWindowDoesNoRebuildForEngineUpdates() async throws {
        let (controller, view, editor) = try await makeController()
        controller.defersContextRefreshWhileHidden = true
        XCTAssertNotEqual(controller.window?.isVisible, true, "the window is not on screen")
        let refreshes = controller.refreshCountForChecks, rebuilds = view.rebuildCountForChecks
        var context = editor.context
        context.statusItemNotice = SettingsText("Covered", "被遮挡")
        for _ in 0..<5 { editor.update(context: context) }
        XCTAssertEqual(controller.refreshCountForChecks, refreshes, "G3-161: a hidden window does not refresh its content")
        XCTAssertEqual(view.rebuildCountForChecks, rebuilds, "and rebuilds nothing")
        XCTAssertEqual(editor.context.statusItemNotice?.value(.english), "Covered", "the editor still has the latest context")
        controller.showWindow(nil)
        XCTAssertEqual(controller.refreshCountForChecks, refreshes + 1, "showing the window brings it up to date, once")
        controller.close()
    }
}
