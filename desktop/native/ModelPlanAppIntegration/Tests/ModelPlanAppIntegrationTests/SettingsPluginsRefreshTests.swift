// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
@testable import ModelPlanAppIntegration

/// D376 / CKP-PLG-54 (post-merge sampling 11-24, 1152 finding): a plugin turned off from the widget ("Turn Off <plugin>…",
/// confirmed) shows Off, with its controls disabled, in an already open Settings Plugins pane. Runs the real Settings
/// surface and window controller. Fails before the fix and when the observeChoices hookup is removed: the bridge owns the
/// model's only onChange and nothing else redraws the pane.
@MainActor final class SettingsPluginsRefreshTests: XCTestCase {
    private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
    private func settle() async throws { for _ in 0..<10 { await Task.yield(); try await Task.sleep(for: .milliseconds(20)) } }

    func testClosingAPluginFromTheWidgetTurnsTheOpenSettingsPluginsPaneOff() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("settings-plugins-refresh-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let app = SettingsApplicationCoordinator(store: try SettingsStore(url: dir.appendingPathComponent("preferences.json"))) { _ in }
        let host = SettingsWindowHost(application: app, canPresent: { true }, environment: { .init() }, activate: {})
        let model = await CockpitPluginSettingsModel.load(from: CockpitPluginStore(directory: dir))
        let bridge = CockpitPluginBridge(model: model, coordinator: nil)
        host.attachCockpitPlugins(bridge)
        await host.present(paneID: "plugins")
        let native = try XCTUnwrap(host.surface as? NativeSettingsWindowSurface, "the real Settings surface")
        defer { native.controller.close() }
        let view = try XCTUnwrap(native.controller.cockpitPluginsView, "the Plugins pane is attached")
        let plugin = try XCTUnwrap(CockpitPluginCatalogue.listed(model.catalogue).first, "a listed plugin")
        func enabledSwitch() throws -> NSButton {
            try XCTUnwrap(descendants(view).first { $0.accessibilityIdentifier() == "settings.cockpitPlugins.\(plugin.id).enabled" } as? NSButton)
        }
        // Setup: turn it on through the model and let every queued redraw run, so the baseline is settled.
        _ = await model.perform(.setEnabled(plugin.id, true))
        try await settle()
        XCTAssertEqual(try enabledSwitch().state, .on, "setup: the open pane shows the plugin On")

        // Act: the widget path (confirmed close through the closer), nothing touches the Settings window.
        let closer = CockpitPluginCloser(model: model, language: { .english })
        closer.presenter = { _ in true }
        let closed = await closer.requestClose(plugin.id)
        XCTAssertTrue(closed)
        try await settle()
        XCTAssertEqual(try enabledSwitch().state, .off, "the open pane shows the plugin Off without being reopened")
    }
}
