// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class S02SettingsEntryJourneyTests: XCTestCase {
    func testNormalStatusMenuReopensSameSettingsWindowOnGeneral() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("s02-settings-entry-" + UUID().uuidString)
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
        await app.settingsHost.present(paneID: "general", origin: .userInitiated)
        let window = try XCTUnwrap(NSApplication.shared.windows.first { !before.contains(ObjectIdentifier($0)) && $0.isVisible })
        defer { window.close() }
        let controller = try XCTUnwrap(window.windowController as? SettingsWindowController)
        XCTAssertTrue(controller.visibleSettingKeys.contains(.login))
        controller.selectPane("about")
        XCTAssertFalse(controller.visibleSettingKeys.contains(.login))
        let menu = try XCTUnwrap(app.liveStatusMenu)
        let item = try XCTUnwrap(menu.items.first { $0.title == "Settings…" })
        XCTAssertTrue(item.isEnabled)
        _ = try XCTUnwrap(item.target as? NSObject).perform(try XCTUnwrap(item.action), with: item)
        for _ in 0..<200 where !controller.visibleSettingKeys.contains(.login) {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(window.isVisible)
        XCTAssertTrue(controller.visibleSettingKeys.contains(.login), "A menu request returns the existing window to General")
        XCTAssertEqual(NSApplication.shared.windows.filter { $0.windowController === controller }.count, 1)
        await app.composition.stop()
    }
}
