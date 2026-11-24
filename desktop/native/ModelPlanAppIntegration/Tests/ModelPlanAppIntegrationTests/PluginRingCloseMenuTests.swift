// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanDock
import ModelPlanSettings
@testable import ModelPlanAppIntegration

/// D376: a plugin ring's right-click menu starts with "Turn Off <plugin>…" and a separator, then the widget menu
/// unchanged; a subscription ring gets nothing new; the plugin card's menu is that one item. Choosing it closes the
/// card and hands the ring's Dock ID to the app, which confirms and turns the plugin off (CockpitPluginCloser). Fails
/// before D376: the widget menu was the same for every ring and had no such item.
@MainActor final class PluginRingCloseMenuTests: XCTestCase {
    private func host() -> StaticDockPreviewHost {
        let host = StaticDockPreviewHost(currentDate: { Date() }, createsNativePanels: false)
        host.setPresentationAllowed(true)
        return host
    }
    private func titles(_ menu: NSMenu) -> [String] { menu.items.map { $0.isSeparatorItem ? "—" : $0.title } }

    func testPluginRingMenuStartsWithTurnOffThenTheWidgetMenuUnchanged() throws {
        let dock = host(); defer { dock.close() }
        var requested: [String] = []
        dock.pluginCloseTitle = { $0 == ResourceDockBridge.subscriptionID ? "关闭资源占用…" : nil }
        dock.pluginCloseRequested = { requested.append($0) }
        let plain = titles(dock.menu())
        XCTAssertFalse(plain.contains("关闭资源占用…"), "the plain widget menu is unchanged")

        let ring = try XCTUnwrap(dock.ringMenu(ResourceDockBridge.subscriptionID))
        XCTAssertEqual(titles(ring), ["关闭资源占用…", "—"] + plain)
        let item = ring.items[0]
        XCTAssertTrue(item.isEnabled)
        XCTAssertEqual(item.accessibilityIdentifier(), "dock.menu.closePlugin")
        let action = try XCTUnwrap(item.action), target = try XCTUnwrap(item.target as? NSObject)
        _ = target.perform(action, with: item)
        XCTAssertEqual(requested, [ResourceDockBridge.subscriptionID], "the ring's Dock ID goes to the app's confirmation")

        // A subscription ring keeps the plain menu (no ring menu of its own).
        XCTAssertNil(dock.ringMenu("synthetic-subscription"))
        // A plugin the app cannot turn off now (title nil) gets no item either.
        dock.pluginCloseTitle = { _ in nil }
        XCTAssertNil(dock.ringMenu(ResourceDockBridge.subscriptionID))
    }

    func testPluginCardMenuIsTheOneTurnOffItem() throws {
        let dock = host(); defer { dock.close() }
        dock.pluginCloseTitle = { _ in "Turn Off Resources…" }
        var requested: [String] = []
        dock.pluginCloseRequested = { requested.append($0) }
        let menu = try XCTUnwrap(dock.pluginCardMenu(ResourceDockBridge.subscriptionID))
        XCTAssertEqual(titles(menu), ["Turn Off Resources…"])
        XCTAssertNil(dock.pluginCardMenu("synthetic-subscription"), "a subscription card has no menu")
        let item = menu.items[0]
        _ = (item.target as? NSObject)?.perform(try XCTUnwrap(item.action), with: item)
        XCTAssertEqual(requested, [ResourceDockBridge.subscriptionID])
    }

    func testNoItemWithoutTheAppsCloseOrWhileNotPresented() {
        let dock = host(); defer { dock.close() }
        dock.pluginCloseTitle = { _ in "关闭资源占用…" }
        XCTAssertNil(dock.ringMenu(ResourceDockBridge.subscriptionID), "no close wired: no item")
        dock.pluginCloseRequested = { _ in }
        dock.setPresentationAllowed(false)
        XCTAssertNil(dock.ringMenu(ResourceDockBridge.subscriptionID), "the widget cannot act: no item")
    }

    /// The installed ring routes a right-click on the plugin ring to its ring menu and everything else to the plain menu.
    func testInstrumentViewAsksForTheRingMenu() {
        let view = DockInstrumentView(frame: NSRect(x: 0, y: 0, width: 80, height: 200))
        let plain = NSMenu(title: "plain")
        view.menu = plain
        XCTAssertNil(view.contextMenuForRing)
        let event = NSEvent.mouseEvent(with: .rightMouseDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
                                       context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
        XCTAssertTrue(view.menu(for: event) === plain, "no provider: the plain menu")
        view.contextMenuForRing = { _ in NSMenu(title: "ring") }
        XCTAssertTrue(view.menu(for: event) === plain, "no ring under the click: the plain menu")
    }
}
