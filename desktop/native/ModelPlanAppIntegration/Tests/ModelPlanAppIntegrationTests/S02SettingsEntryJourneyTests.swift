// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class S02SettingsEntryJourneyTests: XCTestCase {
    private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }

    func testNormalSettingsSidebarShowsCurrentPaneOrderInBothLanguages() async throws {
        let ids = ["general", "dock", "cockpit", "appearance", "subscriptions", "notifications", "privacy", "diagnostics", "about"]
        let english = ["General", "Quota Widget", "Cockpit", "Appearance", "Subscriptions", "Notifications", "Data & Privacy", "Diagnostics", "About"]
        let chinese = ["通用", "额度挂件", "驾驶舱", "外观", "订阅", "通知", "数据与隐私", "诊断", "关于"]
        for locale in ["en", "zh-CN"] {
            let profile = FileManager.default.temporaryDirectory.appendingPathComponent("s02-sidebar-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: profile) }
            let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
            let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
            let config = EngineClientConfiguration(executableURL: profile.appendingPathComponent("synthetic"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true)
            let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: [locale])
            let app = EngineRowsEntry.make(configuration: config, settingsStore: store, createsNativePanels: false,
                dockEnvironment: normalEntryTestEnvironment,
                makeClient: { _, engineStore in SettingsJourneyClient(store: engineStore, rows: rows) }, activateSettings: {})
            await app.prepare()
            defer { app.composition.dock.close() }
            let before = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
            await app.settingsHost.present(paneID: nil, origin: .userInitiated)
            let window = try XCTUnwrap(NSApplication.shared.windows.first { !before.contains(ObjectIdentifier($0)) && $0.isVisible })
            defer { window.close() }
            let controller = try XCTUnwrap(window.windowController as? SettingsWindowController)
            XCTAssertEqual(controller.selectedPaneID, "general")
            let sidebar = try XCTUnwrap(descendants(try XCTUnwrap(window.contentView)).first {
                $0.accessibilityIdentifier() == "settings.sidebar"
            } as? NSTableView)
            XCTAssertEqual(sidebar.numberOfRows, ids.count)
            for (index, id) in ids.enumerated() {
                sidebar.scrollRowToVisible(index)
                let cell = try XCTUnwrap(sidebar.view(atColumn: 0, row: index, makeIfNecessary: true))
                let label = try XCTUnwrap(descendants(cell).compactMap { $0 as? NSTextField }.first {
                    $0.accessibilityIdentifier() == "settings.pane." + id
                })
                XCTAssertEqual(label.stringValue, locale == "en" ? english[index] : chinese[index])
            }
            await app.composition.stop()
        }
    }
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
