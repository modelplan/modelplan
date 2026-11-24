// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanSettings
import ModelPlanResources
@testable import ModelPlanAppIntegration

#if MODELPLAN_TEST_ONLY_SPI
/// D376 / CKP-PLG-54 (post-merge sampling 11-24, 1152 finding), through the normal factory composition: with Settings open
/// on the Plugins pane, the Resources ring's confirmed "Turn Off Resources…" shows the plugin Off in that same window and
/// disables its sampling controls. Fails when the factory's Settings hookup (SettingsWindowHost.attachCockpitPlugins) is
/// removed: the bridge owns the model's only onChange, so nothing else redraws the pane.
@MainActor final class SettingsPluginsRefreshTests: XCTestCase {
    private final class IdleReader: ResourceReader { func read(uptime: TimeInterval, unixMs: Int64) -> ResourceSample? { nil } }
    private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }

    func testTheWidgetsConfirmedTurnOffShowsOffInTheOpenResourcesPane() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("settings-plugins-refresh-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = try SettingsStore(url: root.appendingPathComponent("settings.json"))
        try await store.update { $0.language = .english; $0.autoHide = false }
        let configuration = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic",
                                                      allowedEnvironment: [:], offline: true, readOnly: true)
        var prompts: [String] = []
        CommunityCockpitApplicationFactory.verificationClosePresenter = { prompts.append($0.menuTitle); return true }
        addTeardownBlock { CommunityCockpitApplicationFactory.verificationClosePresenter = nil }
        let app = EngineRowsEntry.make(configuration: configuration, settingsStore: store, createsNativePanels: false,
                                       dockEnvironment: normalEntryTestEnvironment, installsResourcePlugin: true,
                                       resourceReader: { IdleReader() }, activateSettings: {})
        await app.prepare(); app.allowDockPresentation()
        let dock = app.composition.dock; defer { dock.close() }
        for _ in 0..<300 where app.cockpitPluginModel == nil { try await Task.sleep(for: .milliseconds(20)) }
        let model = try XCTUnwrap(app.cockpitPluginModel, "the factory installed the plugin choices")

        let before = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
        await app.settingsHost.present(paneID: "plugins", origin: .userInitiated)
        let window = try XCTUnwrap(NSApplication.shared.windows.first { !before.contains(ObjectIdentifier($0)) && $0.isVisible }, "Settings is open")
        addTeardownBlock { @MainActor in window.close() }
        let content = try XCTUnwrap(window.contentView)
        func control(_ suffix: String) -> NSControl? {
            descendants(content).first { $0.accessibilityIdentifier() == "settings.cockpitPlugins.resources" + suffix } as? NSControl
        }
        func samplingControls() -> [NSControl] {
            descendants(content).compactMap { $0 as? NSControl }.filter {
                let id = $0.accessibilityIdentifier()
                return id.hasPrefix("settings.cockpitPlugins.resources.") && ($0 is NSSegmentedControl || $0 is NSStepper)
            }
        }
        XCTAssertTrue(model.preferences.enabledIDs(model.catalogue).contains("resources"), "Resources is on (default on)")
        let on = try XCTUnwrap(control(".enabled") as? NSButton, "the Resources switch is in the open pane")
        XCTAssertEqual(on.state, .on)
        let controls = samplingControls()
        XCTAssertFalse(controls.isEmpty, "the Resources sampling control is in the pane")
        XCTAssertTrue(controls.allSatisfy(\.isEnabled), "setup: its sampling controls are enabled while On")
        for _ in 0..<10 { await Task.yield(); try await Task.sleep(for: .milliseconds(20)) }

        // The widget path: the ring's confirmed "Turn Off Resources…"; nothing touches the Settings window.
        let closeRequested = try XCTUnwrap(dock.pluginCloseRequested, "the factory wired the ring's Turn Off")
        closeRequested(ResourceDockBridge.subscriptionID)
        for _ in 0..<150 where model.preferences.enabledIDs(model.catalogue).contains("resources") { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(prompts.count, 1, "the close asked first")
        XCTAssertFalse(model.preferences.enabledIDs(model.catalogue).contains("resources"), "Resources is off in the saved choices")
        for _ in 0..<150 where (control(".enabled") as? NSButton)?.state != .off { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual((control(".enabled") as? NSButton)?.state, .off, "the open pane shows Resources Off without being reopened")
        let after = samplingControls()
        XCTAssertFalse(after.isEmpty)
        XCTAssertTrue(after.allSatisfy { !$0.isEnabled }, "its sampling controls are disabled")
    }
}
#endif
