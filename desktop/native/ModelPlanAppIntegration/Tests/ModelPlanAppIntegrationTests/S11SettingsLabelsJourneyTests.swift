// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class S11SettingsLabelsJourneyTests: XCTestCase {
    private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
    func testS11LegacyThresholdUsesSpecChoicesAndEffectiveDefault() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("s11-legacy-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let directory = profile.appendingPathComponent("ModelPlan", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let legacy = #"{"schemaVersion":1,"settings":{"redBelow":16},"core":{"favouriteModelIDs":[]}}"#
        try Data(legacy.utf8).write(to: directory.appendingPathComponent("settings.json"))
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        let config = EngineClientConfiguration(executableURL: profile.appendingPathComponent("synthetic"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true)
        let app = EngineRowsEntry.make(configuration: config, settingsStore: store, createsNativePanels: false,
            dockEnvironment: normalEntryTestEnvironment,
            makeClient: { _, engineStore in SettingsJourneyClient(store: engineStore, rows: rows) }, activateSettings: {})
        await app.prepare()
        defer { app.composition.dock.close() }
        let before = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
        await app.settingsHost.present(paneID: "dock", origin: .userInitiated)
        let window = try XCTUnwrap(NSApplication.shared.windows.first { !before.contains(ObjectIdentifier($0)) && $0.isVisible })
        defer { window.close() }
        let controller = try XCTUnwrap(window.windowController as? SettingsWindowController)
        let critical = try XCTUnwrap(controller.choice(key: .redBelow))
        XCTAssertEqual(critical.itemArray.compactMap { $0.representedObject as? String }, ["40", "30", "25", "20", "15", "10"])
        XCTAssertEqual(critical.selectedItem?.representedObject as? String, "25")
        XCTAssertEqual(app.composition.latestSettings?.effective.redBelow, 25)
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("settings.json")), Data(legacy.utf8), "Display fallback must not rewrite the saved document")
        await app.composition.stop()
    }
    func testNormalSettingsKeepsThresholdAndPersistsPercentageBasis() async throws {
        for threshold in [25, 16] {
            let profile = FileManager.default.temporaryDirectory.appendingPathComponent("s11-numbers-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: profile) }
            let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
            let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
            let config = EngineClientConfiguration(executableURL: profile.appendingPathComponent("synthetic"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true)
            let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
            if threshold == 16 { _ = try await store.update { $0.redBelow = 16 } }
            let app = EngineRowsEntry.make(configuration: config, settingsStore: store, createsNativePanels: false,
                dockEnvironment: normalEntryTestEnvironment,
                makeClient: { _, engineStore in SettingsJourneyClient(store: engineStore, rows: rows) }, activateSettings: {})
            await app.prepare()
            defer { app.composition.dock.close() }
            let before = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
            await app.settingsHost.present(paneID: "dock", origin: .userInitiated)
            let window = try XCTUnwrap(NSApplication.shared.windows.first { !before.contains(ObjectIdentifier($0)) && $0.isVisible })
            defer { window.close() }
            let controller = try XCTUnwrap(window.windowController as? SettingsWindowController)
            let critical = try XCTUnwrap(controller.choice(key: .redBelow))
            XCTAssertEqual(critical.itemArray.compactMap { $0.representedObject as? String }, ["40", "30", "25", "20", "15", "10"])
            XCTAssertEqual(critical.selectedItem?.representedObject as? String, "25")
            XCTAssertEqual(app.composition.latestSettings?.effective.redBelow, 25)
            let basis = try XCTUnwrap(controller.choice(key: .percentageMode))
            XCTAssertTrue(basis.isEnabled)
            XCTAssertEqual(basis.selectedItem?.representedObject as? String, "remaining")
            let used = try XCTUnwrap(basis.itemArray.firstIndex { ($0.representedObject as? String) == "used" })
            basis.selectItem(at: used)
            XCTAssertTrue(NSApplication.shared.sendAction(try XCTUnwrap(basis.action), to: basis.target, from: basis))
            await controller.waitForPendingSave()
            let preserved = await store.snapshot()
            XCTAssertEqual(preserved.preferences.redBelow, threshold, "An unrelated edit must preserve the stored value")
            for value in [40, 30, 25, 20, 15, 10] {
                let popup = try XCTUnwrap(controller.choice(key: .redBelow))
                let index = try XCTUnwrap(popup.itemArray.firstIndex { ($0.representedObject as? String) == String(value) })
                popup.selectItem(at: index)
                XCTAssertTrue(NSApplication.shared.sendAction(try XCTUnwrap(popup.action), to: popup.target, from: popup))
                await controller.waitForPendingSave()
                let current = await store.snapshot()
                XCTAssertEqual(current.preferences.redBelow, value, "The actual Settings selection must be saved")
                XCTAssertEqual(app.composition.latestSettings?.effective.redBelow, value, "The saved selection must reach the effective Settings consumer")
            }
            let reopened = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
            let saved = await reopened.snapshot()
            XCTAssertEqual(saved.preferences.redBelow, 10)
            XCTAssertEqual(saved.preferences.percentageMode, .used)
            await app.composition.stop()
        }
    }
    func testNormalSettingsUsesWidgetPercentageLabelsInBothLanguages() async throws {
        for locale in ["en", "zh-CN"] {
            let profile = FileManager.default.temporaryDirectory.appendingPathComponent("s11-labels-" + UUID().uuidString)
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
            await app.settingsHost.present(paneID: "dock", origin: .userInitiated)
            let window = try XCTUnwrap(NSApplication.shared.windows.first { !before.contains(ObjectIdentifier($0)) && $0.isVisible })
            defer { window.close() }
            let controller = try XCTUnwrap(window.windowController as? SettingsWindowController)
            XCTAssertEqual(controller.selectedPaneID, "dock")
            let settingsRows = descendants(try XCTUnwrap(window.contentView)).compactMap { $0 as? SettingsNativeRow }
            let percentage = try XCTUnwrap(settingsRows.first { $0.key == .showPercentages })
            XCTAssertFalse(percentage.isHiddenOrHasHiddenAncestor)
            XCTAssertEqual(percentage.titleLabel.stringValue, locale == "en" ? "Quota Widget percentages" : "额度挂件百分比")
            let choice = try XCTUnwrap(percentage.choices[""])
            let titles = choice.itemArray.map(\.title)
            XCTAssertTrue(titles.contains(locale == "en" ? "Shown" : "显示"))
            XCTAssertTrue(titles.contains(locale == "en" ? "Hidden" : "隐藏"))
            let sliver = try XCTUnwrap(settingsRows.first { $0.key == .sliverAlert })
            XCTAssertEqual(sliver.titleLabel.stringValue, locale == "en" ? "Strip alerts" : "隐藏条提示")
            controller.selectPane("dock")
            let positionRows = descendants(try XCTUnwrap(window.contentView)).compactMap { $0 as? SettingsNativeRow }
            let widget = try XCTUnwrap(positionRows.first { $0.key == .showDock })
            XCTAssertFalse(widget.isHiddenOrHasHiddenAncestor)
            XCTAssertEqual(widget.titleLabel.stringValue, locale == "en" ? "Show Quota Widget" : "显示额度挂件")
            await app.composition.stop()
        }
    }
}
