// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
@testable import ModelPlanAppIntegration

/// The cockpit as the ignition sees it: showing or not, attached to the menu bar or detached (D204 v3).
@MainActor private final class IgnitionConsole: EngineRowsConsoleSurface {
    var opens: [Bool] = [], closes = 0
    var showing = false, detached = false
    /// Covered by other windows, on another Space or minimised; an open brings it to the front.
    var behindOtherWindows = false
    var onShowingChanged: (() -> Void)?
    func show() { show(fromStatusItem: false) }
    func show(fromStatusItem: Bool) { opens.append(fromStatusItem); showing = true; behindOtherWindows = false }
    func render() {}
    func hide() { showing = false }
    var isShowing: Bool { showing }
    var isDetached: Bool { detached }
    func requestClose() { closes += 1; showing = false; onShowingChanged?() }
    /// The page's own close (the title strip's close key, an outside click).
    func closeFromPage() { showing = false; onShowingChanged?() }
}

/// D204 v3 (G3-94): attached to the menu bar, the widget's red ignition toggles the cockpit like a menu bar popover;
/// detached, it always brings the cockpit to the front and never closes it. Normal entry: the real application and
/// Dock host; the ignition is pressed through the Dock button's own action. Only the cockpit window is a stand-in
/// (its bring-to-front and placement are tested on the real controller in `CockpitIgnitionVisibilityTests`).
@MainActor final class IgnitionEntryTests: XCTestCase {
    private var console: IgnitionConsole?

    private func makeApp() async throws -> EngineDockMenuApplication {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ign-entry-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = try SettingsStore(url: root.appendingPathComponent("settings.json"))
        try await store.update { $0.language = .english; $0.autoHide = false }
        let app = EngineRowsEntry.make(
            configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true),
            settingsStore: store, createsNativePanels: false, cockpitEntryEnabled: true, dockEnvironment: normalEntryTestEnvironment,
            makeConsole: { [weak self] _ in let surface = IgnitionConsole(); self?.console = surface; return surface }, activateSettings: {})
        await app.prepare(); app.allowDockPresentation()
        addTeardownBlock { @MainActor in app.composition.dock.close() }
        return app
    }
    /// The ignition button's own action, as a click on it sends it.
    private func pressIgnition(_ app: EngineDockMenuApplication) {
        XCTAssertTrue(NSApp.sendAction(NSSelectorFromString("ignitionPressed"), to: app.composition.dock, from: nil))
    }

    /// G3-94: attached, a press opens and a press while it is open closes it (it used to open it again).
    func testAttachedPressOpensAndPressAgainCloses() async throws {
        _ = NSApplication.shared
        let app = try await makeApp()
        pressIgnition(app)
        let console = try XCTUnwrap(console)
        XCTAssertEqual(console.opens, [false], "the first press opens, with the ignition's own entrance")
        pressIgnition(app)
        XCTAssertEqual(console.closes, 1, "a press on the open attached cockpit closes it")
        XCTAssertEqual(console.opens.count, 1, "and does not open it again")
        XCTAssertFalse(console.isShowing)
        pressIgnition(app)
        XCTAssertEqual(console.opens.count, 2, "closed: the next press opens again")
    }

    /// Opened attached from the menu bar icon, the ignition closes it like the icon does.
    func testIconOpenThenIgnitionCloses() async throws {
        _ = NSApplication.shared
        let app = try await makeApp()
        app.toggleConsole()
        let console = try XCTUnwrap(console)
        XCTAssertEqual(console.opens, [true], "the icon opens by growing out of itself")
        pressIgnition(app)
        XCTAssertEqual(console.closes, 1)
        XCTAssertEqual(console.opens.count, 1)
    }

    /// Closed by its own title-strip close key, the cockpit opens again on the next press.
    func testTitleStripCloseThenIgnitionOpens() async throws {
        _ = NSApplication.shared
        let app = try await makeApp()
        pressIgnition(app)
        let console = try XCTUnwrap(console)
        console.closeFromPage()
        pressIgnition(app)
        XCTAssertEqual(console.closes, 0, "nothing to close")
        XCTAssertEqual(console.opens.count, 2, "the press opens it")
    }

    /// Detached and already in front, a press keeps it open (it is brought to the front again, nothing closes).
    func testDetachedPressWhenInFrontStaysOpen() async throws {
        _ = NSApplication.shared
        let app = try await makeApp()
        pressIgnition(app)
        let console = try XCTUnwrap(console)
        console.detached = true
        pressIgnition(app); pressIgnition(app)
        XCTAssertEqual(console.closes, 0, "the ignition never closes a detached cockpit")
        XCTAssertTrue(console.isShowing)
        XCTAssertEqual(console.opens.count, 3, "each press brings it to the front")
    }

    /// Detached and covered (or on another Space, or minimised): a press brings it to the front.
    func testDetachedCoveredComesToFront() async throws {
        _ = NSApplication.shared
        let app = try await makeApp()
        pressIgnition(app)
        let console = try XCTUnwrap(console)
        console.detached = true; console.behindOtherWindows = true
        pressIgnition(app)
        XCTAssertEqual(console.closes, 0)
        XCTAssertFalse(console.behindOtherWindows, "brought to the front")
        XCTAssertTrue(console.isShowing)
    }

    /// Detached and closed from its title strip: the next press opens it again (at its last position: the shell
    /// session keeps the detached place, see `CockpitIgnitionVisibilityTests`).
    func testClosedDetachedOpensOnPress() async throws {
        _ = NSApplication.shared
        let app = try await makeApp()
        pressIgnition(app)
        let console = try XCTUnwrap(console)
        console.detached = true
        console.closeFromPage()
        pressIgnition(app)
        XCTAssertEqual(console.opens.count, 2)
        XCTAssertTrue(console.isShowing)
    }

    /// Two displays: the open carries the point the ignition was pressed at, so an attached cockpit opens under the
    /// icon of that display (placement: `CockpitIgnitionVisibilityTests` in ModelPlanCockpitWeb).
    func testThePressPointGoesWithTheOpen() async throws {
        _ = NSApplication.shared
        let app = try await makeApp()
        let onSecondDisplay = CGPoint(x: 3990, y: 700)
        let press = try XCTUnwrap(app.composition.dock.pressIgnition)
        press(onSecondDisplay)
        XCTAssertEqual(app.cockpitOpenPoint, onSecondDisplay)
        press(CGPoint(x: 10, y: 10))
        XCTAssertEqual(console?.closes, 1)
        XCTAssertEqual(app.cockpitOpenPoint, onSecondDisplay, "closing keeps the last open's display")
        app.toggleConsole()
        XCTAssertNil(app.cockpitOpenPoint, "the menu bar icon opens on its own display")
    }
}
