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
    private func expectedOption(_ raw: String, key: SettingKey, chinese: Bool) -> String? {
        if raw == "system" { return chinese ? "跟随系统" : key == .theme ? "System" : "Follow system" }
        if raw == "true" { return chinese ? (key == .showPercentages ? "显示" : "开启") : (key == .showPercentages ? "Shown" : "On") }
        if raw == "false" { return chinese ? (key == .showPercentages ? "隐藏" : "关闭") : (key == .showPercentages ? "Hidden" : "Off") }
        if raw == "primary", key == .dockDisplay { return chinese ? "主显示器" : "Primary display" }
        let words: [String: (String, String)] = [
            "day": ("Day", "白天"), "night": ("Night", "夜间"), "on": ("On", "开启"),
            "remaining": ("Remaining", "剩余"), "used": ("Used", "已用"),
            "auto": ("Auto (tightest)", "自动（最紧的）"), "5h": ("5h", "5小时"), "week": ("Weekly", "每周"),
            "right": ("Right", "右侧"), "left": ("Left", "左侧"), "bottom": ("Bottom", "底部"),
            "none": ("None", "无"), "subtle": ("Subtle", "轻微"), "strong": ("Strong", "明显"),
            "icon": ("Icon only", "仅图标"), "tightest": ("Tightest percentage", "最紧的百分比"),
            "twoWindows": ("Two windows", "两个窗口"), "zh-CN": ("Simplified Chinese", "简体中文"), "en": ("English", "英语"),
            "hold": ("Hold to ignite", "按住点火"), "quick": ("Always quick", "始终快速打开")
        ]
        guard let pair = words[raw] else { return nil }
        return chinese ? pair.1 : pair.0
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
            var context = app.settingsHost.application.editor.context
            context.subscriptions = [
                .init(id: "s09-first", name: .init("First sample", "示例一")),
                .init(id: "s09-second", name: .init("Second sample", "示例二"))
            ]
            app.settingsHost.application.update(context: context)
            defer { app.composition.dock.close() }
            let before = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
            await app.settingsHost.present(paneID: "general", origin: .userInitiated)
            let window = try XCTUnwrap(NSApplication.shared.windows.first { !before.contains(ObjectIdentifier($0)) && $0.isVisible })
            defer { window.close() }
            let controller = try XCTUnwrap(window.windowController as? SettingsWindowController)
            var checked = 0, checkedOptions = 0
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
                        for term in ["backend", "engine-owned", "source scope", "read here", "observation", "fixture", "envelope"] {
                            XCTAssertFalse(copy.localizedCaseInsensitiveContains(term),
                                           "Internal terminology must not appear in Settings copy: \(row.key.rawValue)")
                        }
                    }
                    for popup in row.choices.values where !popup.isHiddenOrHasHiddenAncestor {
                        for item in popup.itemArray {
                            guard let raw = item.representedObject as? String,
                                  let expected = expectedOption(raw, key: row.key, chinese: locale != "en") else { continue }
                            XCTAssertEqual(item.title, expected, "The visible option must use the selected language: \(row.key.rawValue)")
                            checkedOptions += 1
                        }
                    }
                    checked += 1
                }
            }
            XCTAssertGreaterThan(checked, 0, "The normal Settings window must supply rows to inspect")
            XCTAssertGreaterThan(checkedOptions, 0, "The normal Settings window must supply localized options to inspect")
            await app.composition.stop()
        }
    }
}
