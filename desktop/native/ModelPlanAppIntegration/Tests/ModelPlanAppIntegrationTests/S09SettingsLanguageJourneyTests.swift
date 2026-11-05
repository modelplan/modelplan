// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class S09SettingsLanguageJourneyTests: XCTestCase {
    private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
    private func containsHan(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }
    }

    func testS09NormalSettingsRowCopyUsesOneLanguageOnEveryPane() async throws {
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
        for locale in ["en", "zh-CN"] {
            let profile = FileManager.default.temporaryDirectory.appendingPathComponent("s09-settings-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: profile) }
            let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: [locale])
            let config = EngineClientConfiguration(executableURL: profile.appendingPathComponent("not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true)
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
            var checked = 0
            for pane in SettingsStructure.task65.panes {
                controller.selectPane(pane.id)
                XCTAssertEqual(controller.selectedPaneID, pane.id)
                let content = try XCTUnwrap(window.contentView)
                content.layoutSubtreeIfNeeded()
                let visibleRows = descendants(content).compactMap { $0 as? SettingsNativeRow }.filter { !$0.isHiddenOrHasHiddenAncestor }
                for row in visibleRows {
                    let title = row.titleLabel.stringValue
                    let subtitle = row.subtitle.stringValue
                    XCTAssertFalse(title.isEmpty, "Every rendered Settings row needs a title")
                    if locale == "en" {
                        XCTAssertFalse(containsHan(title), "English Settings title contains Chinese: \(row.key.rawValue)")
                        XCTAssertFalse(containsHan(subtitle), "English Settings subtitle contains Chinese: \(row.key.rawValue)")
                    } else {
                        XCTAssertTrue(containsHan(title), "Chinese Settings title needs localized text: \(row.key.rawValue)")
                    }
                    for copy in [title, subtitle] {
                        XCTAssertFalse(copy.localizedCaseInsensitiveContains("backend"), "Internal backend terminology is not user-facing copy")
                        XCTAssertFalse(copy.localizedCaseInsensitiveContains("engine-owned"), "Internal ownership terminology is not user-facing copy")
                    }
                    checked += 1
                }
            }
            XCTAssertGreaterThan(checked, 0, "The normal Settings window must supply rows to inspect")
            await app.composition.stop()
        }
    }
}
