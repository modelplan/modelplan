// SPDX-License-Identifier: MIT
import XCTest
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor private final class RefreshCountingSurface: SettingsWindowSurface, SettingsPluginsRefreshing {
    var refreshes = 0
    func prepare() async {}
    func show(paneID: String?) {}
    func hide() {}
    func refreshPlugins() { refreshes += 1 }
}

/// D376 (post-merge sampling 11-24, 1152 finding): a plugin turned off from the widget ("Turn Off <plugin>…", confirmed)
/// must redraw an open Settings Plugins pane. Fails before the fix: the bridge owns the model's only onChange and nothing
/// told the Settings window to refresh.
@MainActor final class SettingsPluginsRefreshTests: XCTestCase {
    func testClosingAPluginFromTheWidgetRefreshesTheOpenSettingsPluginsPane() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("settings-plugins-refresh-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let app = SettingsApplicationCoordinator(store: try SettingsStore(url: dir.appendingPathComponent("preferences.json"))) { _ in }
        let surface = RefreshCountingSurface()
        let host = SettingsWindowHost(application: app, canPresent: { true }, environment: { .init() }, makeSurface: { _ in surface })
        let model = await CockpitPluginSettingsModel.load(from: CockpitPluginStore(directory: dir))
        let bridge = CockpitPluginBridge(model: model, coordinator: nil)
        host.attachCockpitPlugins(bridge)
        await host.present(paneID: "plugins")
        let plugin = try XCTUnwrap(CockpitPluginCatalogue.listed(model.catalogue).first, "a listed plugin")
        _ = await model.perform(.setEnabled(plugin.id, true))
        let before = surface.refreshes
        let closer = CockpitPluginCloser(model: model, language: { .english })
        closer.presenter = { _ in true }
        XCTAssertNotNil(closer.prompt(plugin.id), "the plugin is on")
        let closed = await closer.requestClose(plugin.id)
        XCTAssertTrue(closed)
        for _ in 0..<200 where surface.refreshes == before { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertGreaterThan(surface.refreshes, before, "the open Plugins pane redraws after the widget closes a plugin")
    }
}
