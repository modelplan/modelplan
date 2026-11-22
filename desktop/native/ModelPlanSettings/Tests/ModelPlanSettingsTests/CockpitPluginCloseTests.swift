// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanSettings

/// D376: "Turn Off <plugin>…" asks first (an app-modal NSAlert, Cancel the default, Turn Off destructive) and then
/// applies the same `setEnabled(id, false)` edit as the Settings switch. Fails before D376: there was no confirmation
/// and no closer.
@MainActor final class CockpitPluginCloseTests: XCTestCase {
    private func directory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("plugin-close-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir
    }

    func testPromptWordsInBothLanguages() {
        let resources = CockpitPluginCatalogue.builtIn.first { $0.id == "resources" }!.title
        let zh = CockpitPluginClosePrompt(plugin: resources, language: .chinese)
        XCTAssertEqual(zh.menuTitle, "关闭资源占用…")
        XCTAssertEqual(zh.messageText, "关闭资源占用？")
        XCTAssertEqual(zh.informativeText, "可以在 设置 › 插件 里重新打开。")
        XCTAssertEqual([zh.cancelTitle, zh.closeTitle], ["取消", "关闭"])
        let en = CockpitPluginClosePrompt(plugin: resources, language: .english)
        XCTAssertEqual(en.menuTitle, "Turn Off Resources…")
        XCTAssertEqual(en.messageText, "Turn off Resources?")
        XCTAssertEqual(en.informativeText, "You can turn it back on in Settings › Plugins.")
        XCTAssertEqual([en.cancelTitle, en.closeTitle], ["Cancel", "Turn Off"])
    }

    /// macOS destructive-action convention: Cancel first (default, Return), Turn Off second and destructive.
    func testAlertCancelIsDefaultAndTurnOffIsDestructive() {
        let prompt = CockpitPluginClosePrompt(plugin: .init("Resources", "资源占用"), language: .chinese)
        let alert = CockpitPluginCloseAlert.make(prompt)
        XCTAssertEqual(alert.messageText, "关闭资源占用？")
        XCTAssertEqual(alert.informativeText, "可以在 设置 › 插件 里重新打开。")
        XCTAssertEqual(alert.buttons.map(\.title), ["取消", "关闭"])
        // Cancel is added first (the default per NSAlert's order; AppKit may give a Cancel-titled first button Escape
        // instead of Return, so the key string is not asserted), Turn Off second and destructive.
        XCTAssertEqual(alert.buttons[0].accessibilityIdentifier(), "plugin.close.cancel")
        XCTAssertFalse(alert.buttons[0].hasDestructiveAction)
        XCTAssertEqual(alert.buttons[1].accessibilityIdentifier(), "plugin.close.confirm")
        XCTAssertTrue(alert.buttons[1].hasDestructiveAction, "Turn Off is marked destructive")
    }

    func testCancelChangesNothingAndTurnOffIsTheSettingsSwitchEdit() async throws {
        let model = CockpitPluginSettingsModel(store: CockpitPluginStore(directory: try directory()))
        let closer = CockpitPluginCloser(model: model, language: { .chinese })
        var asked: [CockpitPluginClosePrompt] = []
        var changes = 0
        model.onChange = { _ in changes += 1 }
        closer.presenter = { asked.append($0); return false }
        let cancelled = await closer.requestClose("resources")
        XCTAssertFalse(cancelled)
        XCTAssertEqual(asked.map(\.messageText), ["关闭资源占用？"])
        XCTAssertEqual(changes, 0, "Cancel changes nothing")
        XCTAssertTrue(model.preferences.enabledIDs(model.catalogue).contains("resources"))

        closer.presenter = { asked.append($0); return true }
        let closed = await closer.requestClose("resources")
        XCTAssertTrue(closed)
        XCTAssertEqual(changes, 1)
        var expected = CockpitPluginPreferences()
        XCTAssertTrue(expected.apply(.setEnabled("resources", false)))
        XCTAssertEqual(model.preferences, expected, "the same edit as the Settings switch")
        XCTAssertFalse(model.preferences.enabledIDs(model.catalogue).contains("resources"))

        // Off already, or never listed: no prompt, nothing asked.
        XCTAssertNil(closer.prompt("resources"))
        XCTAssertNil(closer.prompt("placeholder"), "the framework placeholder is never offered")
        XCTAssertNil(closer.prompt("unknown"))
        let again = await closer.requestClose("resources")
        XCTAssertFalse(again)
        XCTAssertEqual(asked.count, 2)
    }
}
