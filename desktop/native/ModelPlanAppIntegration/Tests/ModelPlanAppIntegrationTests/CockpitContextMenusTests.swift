// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
@testable import ModelPlanAppIntegration

/// The cockpit, widget and status menus: items, language and actions. No window or page is created.
@MainActor final class CockpitContextMenusTests: XCTestCase {
    private func menu(_ language: SettingsLanguage, size: SettingsSize? = .medium, log: @escaping (String) -> Void) -> CockpitContextMenu {
        CockpitContextMenu(language: language, size: size, actions: .init(
            settings: { log("settings") }, resetPosition: { log("reset") }, help: { log("help") }, setSize: { log("size:" + $0.rawValue) }))
    }
    private func titles(_ menu: NSMenu) -> [String] { menu.items.map { $0.isSeparatorItem ? "—" : $0.title } }

    func testCockpitMenuItemsFollowTheAppLanguage() throws {
        let english = menu(.english) { _ in }.menu, chinese = menu(.chinese) { _ in }.menu
        XCTAssertEqual(titles(english), ["Settings…", "Reset Position", "Quota Widget Size", "—", "Help"])
        XCTAssertEqual(titles(chinese), ["设置…", "重置位置", "额度挂件大小", "—", "说明"])
        XCTAssertEqual(try XCTUnwrap(english.items[2].submenu).items.map(\.title), ["Small", "Medium", "Large"])
        XCTAssertEqual(try XCTUnwrap(chinese.items[2].submenu).items.map(\.title), ["小", "中", "大"])
        XCTAssertTrue(english.items.allSatisfy { $0.keyEquivalent.isEmpty })
        for item in english.items + chinese.items where !item.isSeparatorItem { XCTAssertFalse(item.title.contains("Reload")) }
    }

    func testCockpitMenuActionsAndCurrentSizeCheckmark() throws {
        var log: [String] = []
        let value = menu(.english, size: .large) { log.append($0) }
        value.menu.performActionForItem(at: 0)
        value.menu.performActionForItem(at: 1)
        value.menu.performActionForItem(at: 4)
        let sizes = try XCTUnwrap(value.menu.items[2].submenu)
        XCTAssertEqual(sizes.items.map(\.state), [.off, .off, .on], "the stored size is the checked one")
        sizes.performActionForItem(at: 0)
        sizes.performActionForItem(at: 2)
        XCTAssertEqual(log, ["settings", "reset", "help", "size:S", "size:L"])
        XCTAssertEqual(menu(.english, size: nil) { _ in }.menu.items[2].submenu?.items.map(\.state), [.off, .off, .off])
    }

    func testSettingsOpenAppRoundTripsThroughRegularAndBackToAccessory() {
        var seen: [NSApplication.ActivationPolicy] = []
        let presence = SettingsAppPresence { seen.append($0) }
        presence.settingsClosed()
        XCTAssertEqual(seen, [], "closing while closed changes nothing")
        presence.settingsOpened(); presence.settingsOpened()
        XCTAssertEqual(seen, [.regular]); XCTAssertTrue(presence.isRegular)
        presence.settingsClosed(); presence.settingsClosed()
        XCTAssertEqual(seen, [.regular, .accessory]); XCTAssertFalse(presence.isRegular)
    }
}
