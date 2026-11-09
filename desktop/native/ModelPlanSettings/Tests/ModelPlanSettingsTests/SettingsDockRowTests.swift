// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanSettings

/// DOCK-3.3-05 through the real window: the per-subscription pin's options and default.
@MainActor final class SettingsDockRowTests: XCTestCase {
    func testPinOptionsAreAutoFiveHourWeeklyInBothLanguagesAndDefaultToAuto() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("settings-pin-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = try SettingsStore(url: directory.appendingPathComponent("preferences.json"))
        for (language, titles) in [(SettingsLanguage.english, ["Auto (tightest)", "5h", "Weekly"]), (.chinese, ["自动（最紧的）", "5小时", "每周"])] {
            try await store.update { $0.language = language }
            var context = SettingsPageContext()
            context.subscriptions = [.init(id: "sample", name: .init("Sample", "示例"), plan: "Plan")]
            let controller = SettingsWindowController(editor: SettingsEditor(store: store, context: context), environmentProvider: { .init() })
            await controller.prepare(); controller.selectPane("dock")
            controller.searchField.stringValue = language == .english ? "Percentage window" : "百分比窗口"
            controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: controller.searchField))
            let popup = try XCTUnwrap(controller.choice(key: .percentagePin, subscriptionID: "sample"))
            XCTAssertEqual(popup.itemTitles, titles)
            XCTAssertEqual(popup.titleOfSelectedItem, titles[0])
            controller.close()
        }
    }
}
