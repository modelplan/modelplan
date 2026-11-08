// SPDX-License-Identifier: MIT
import AppKit
import Foundation
import XCTest
@testable import ModelPlanCockpitWeb
import ModelPlanSettings
@testable import ModelPlanAppIntegration

#if MODELPLAN_TEST_ONLY_SPI
/// CKP-SHELL-28..31 at the normal entry: `EngineRowsEntry.make` with `cockpitEntryEnabled: true`, the production
/// factory, the real CLI on synthetic data and the real cockpit page and window. They need the same canonical
/// official cockpit and synthetic-test CLI as the G3-42 tests and skip without them.
extension CommunityCockpitEntryTests {
    private final class MenuProbe { var made: [CockpitWindowController] = [] }

    @MainActor private func withComposedCockpit(
        _ body: (_ entry: EngineDockMenuApplication, _ page: CockpitWindowController, _ settings: SettingsStore) async throws -> Void
    ) async throws {
        let official = Self.repoRoot().appendingPathComponent("desktop/cockpit/.tmp/official")
        guard let path = ProcessInfo.processInfo.environment["MODELPLAN_U11_TEST_CLI"],
              FileManager.default.isExecutableFile(atPath: path),
              FileManager.default.fileExists(atPath: official.appendingPathComponent("bundle-manifest.json").path) else {
            throw XCTSkip("The real page needs the canonical official cockpit and the synthetic-test CLI")
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("shell-menus-" + UUID().uuidString).resolvingSymlinksInPath()
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try Self.ownerTestShapedApp(at: root.appendingPathComponent("package"), helper: URL(fileURLWithPath: path), ownerTest: true, official: official)
        let helper = app.appendingPathComponent("Contents/Helpers/modelplan")
        let environment = try await Self.syntheticHome(root, helper: helper)
        let probe = MenuProbe()
        let saved = CommunityCockpitApplicationFactory.verificationPage
        CommunityCockpitApplicationFactory.verificationPage = { [weak probe] page in probe?.made.append(page) }
        defer { CommunityCockpitApplicationFactory.verificationPage = saved }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root.appendingPathComponent("support"), preferredLanguages: ["en"])
        let entry = EngineRowsEntry.make(configuration: .init(executableURL: helper, applicationVersion: "synthetic-shell-menus",
            allowedEnvironment: environment, offline: true, readOnly: true), settingsStore: settings,
            createsNativePanels: false, bundleURL: app, cockpitEntryEnabled: true)
        await entry.prepare()
        await entry.composition.start()
        entry.composition.dock.setPresentationAllowed(true)
        for _ in 0..<1500 where entry.composition.store.snapshot.delivery == nil { try await Task.sleep(for: .milliseconds(10)) }
        entry.showConsole()
        func shown() -> CockpitWindowController? {
            guard let page = probe.made.last, page.bridge.ready, page.window?.isVisible == true else { return nil }
            return page
        }
        for _ in 0..<3000 where shown() == nil { try await Task.sleep(for: .milliseconds(10)) }
        let page = try XCTUnwrap(shown(), "the click shows the real cockpit page")
        try await Task.sleep(for: .milliseconds(500))
        do { try await body(entry, page, settings) }
        catch { await entry.composition.stop(); throw error }
        await entry.composition.stop()
    }

    private func titles(_ menu: NSMenu) -> [String] { menu.items.map { $0.isSeparatorItem ? "—" : $0.title } }
    private func event(_ type: NSEvent.EventType, _ window: NSWindow, at point: CGPoint) throws -> NSEvent {
        try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
            context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
    }
    private func titleDrag(_ window: NSWindow) throws -> CockpitTitleDrag {
        try XCTUnwrap(window.contentView?.subviews.compactMap { $0 as? CockpitTitleDrag }.first, "the drag strip is installed on the composed window")
    }
    /// Drags the real cockpit out from under the icon through its own drag strip.
    @MainActor private func dragAway(_ window: NSWindow) throws {
        let strip = try titleDrag(window)
        let start = CGPoint(x: strip.frame.midX, y: strip.frame.midY)
        strip.mouseDown(with: try event(.leftMouseDown, window, at: start))
        strip.mouseDragged(with: try event(.leftMouseDragged, window, at: CGPoint(x: start.x - 90, y: start.y - 120)))
        strip.mouseDragged(with: try event(.leftMouseDragged, window, at: CGPoint(x: start.x - 180, y: start.y - 240)))
        strip.mouseUp(with: try event(.leftMouseUp, window, at: CGPoint(x: start.x - 180, y: start.y - 240)))
    }
    @MainActor private func waitUntil(_ what: String, _ condition: () -> Bool) async throws {
        for _ in 0..<300 where !condition() { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(condition(), what)
    }
    @MainActor private func newVisibleWindows(since before: Set<Int>, except window: NSWindow) -> [NSWindow] {
        NSApp.windows.filter { $0.isVisible && $0 !== window && !before.contains($0.windowNumber) }
    }

    /// CKP-SHELL-28: the right-click menu of the composed cockpit and what each item does.
    @MainActor func testShell28CockpitRightClickMenuItemsAndActions() async throws {
        try await withComposedCockpit { entry, page, settings in
            let window = try XCTUnwrap(page.window)
            let menu = try XCTUnwrap(page.contextMenuProvider?(), "the composed cockpit supplies its own right-click menu")
            XCTAssertEqual(titles(menu), ["Settings…", "Reset Position", "Quota Widget Size", "—", "Help"])
            let sizes = try XCTUnwrap(menu.items[2].submenu)
            XCTAssertEqual(sizes.items.map(\.title), ["Small", "Medium", "Large"])
            XCTAssertEqual(sizes.items.map(\.state), [.off, .on, .off], "the stored size (Medium by default) is checked")
            sizes.performActionForItem(at: 2)
            for _ in 0..<300 { if await settings.snapshot().preferences.size == .large { break }; try await Task.sleep(for: .milliseconds(10)) }
            let stored = await settings.snapshot().preferences.size
            XCTAssertEqual(stored, .large, "choosing Large writes the stored size")
            // Help shows the page's own help map even though the panel may not be the key window.
            menu.performActionForItem(at: 4)
            var mapShown = false
            for _ in 0..<300 where !mapShown {
                mapShown = (try? await page.verificationWebView?.evaluateJavaScript("(()=>{const m=document.getElementById('help-map');return !!m&&!m.hidden})()") as? Bool) == true
                if !mapShown { try await Task.sleep(for: .milliseconds(10)) }
            }
            XCTAssertTrue(mapShown, "Help shows the Option help map")
            // Settings opens the Settings window (the app becomes a regular app while it is open).
            let before = Set(NSApp.windows.map(\.windowNumber))
            menu.performActionForItem(at: 0)
            try await waitUntil("Settings opens") { !self.newVisibleWindows(since: before, except: window).isEmpty }
            newVisibleWindows(since: before, except: window).forEach { $0.close() }
            _ = entry
        }
    }

    /// CKP-SHELL-29: Reset Position in the cockpit, widget and status menus returns the cockpit to its anchor.
    @MainActor func testShell29ResetPositionInAllThreeMenusReturnsTheCockpitToItsAnchor() async throws {
        try await withComposedCockpit { entry, page, _ in
            let window = try XCTUnwrap(page.window)
            let home = window.frame.origin
            let cockpitMenu = try XCTUnwrap(page.contextMenuProvider?())
            let status = try XCTUnwrap(entry.liveStatusMenu)
            let widget = entry.composition.dock.menu()
            let menus: [(String, NSMenu)] = [("cockpit", cockpitMenu), ("status", status), ("widget", widget)]
            for (name, menu) in menus {
                try dragAway(window)
                XCTAssertGreaterThan(hypot(window.frame.origin.x - home.x, window.frame.origin.y - home.y), 20, "\(name): the cockpit was dragged away")
                let index = try XCTUnwrap(menu.items.firstIndex { $0.title == "Reset Position" }, "\(name) menu has Reset Position")
                menu.performActionForItem(at: index)
                try await waitUntil("\(name): the cockpit returns to its anchor") {
                    abs(window.frame.origin.x - home.x) < 1.5 && abs(window.frame.origin.y - home.y) < 1.5
                }
            }
        }
    }

    /// CKP-SHELL-30: opening Settings from the normal entry makes the app regular; closing it makes it an accessory again.
    @MainActor func testShell30SettingsOpenActivationPolicyRoundTrip() async throws {
        try await withComposedCockpit { entry, page, _ in
            let window = try XCTUnwrap(page.window)
            let previous = NSApp.activationPolicy()
            defer { NSApp.setActivationPolicy(previous) }
            NSApp.setActivationPolicy(.accessory)
            let before = Set(NSApp.windows.map(\.windowNumber))
            let status = try XCTUnwrap(entry.liveStatusMenu)
            let settingsIndex = try XCTUnwrap(status.items.firstIndex { $0.title == "Settings…" })
            status.performActionForItem(at: settingsIndex)
            try await waitUntil("Settings is open") { !self.newVisibleWindows(since: before, except: window).isEmpty }
            XCTAssertEqual(NSApp.activationPolicy(), .regular, "while Settings is open the app has a Dock icon and the standard menu")
            let main = try XCTUnwrap(NSApp.mainMenu?.items.first?.submenu)
            XCTAssertTrue(main.items.contains { $0.keyEquivalent == "," }, "Command-comma opens Settings")
            XCTAssertTrue(main.items.contains { $0.keyEquivalent == "w" }, "Command-W closes the window")
            XCTAssertTrue(main.items.contains { $0.keyEquivalent == "q" }, "Command-Q quits")
            newVisibleWindows(since: before, except: window).forEach { $0.close() }
            try await waitUntil("closing Settings returns the app to an accessory") { NSApp.activationPolicy() == .accessory }
        }
    }

    /// CKP-SHELL-31: the drag strip is installed on the composed window; hovering shows the open hand and the grip.
    @MainActor func testShell31DragStripHoverShowsOpenHandAndGripOnTheComposedWindow() async throws {
        try await withComposedCockpit { _, page, _ in
            let window = try XCTUnwrap(page.window)
            let strip = try titleDrag(window)
            XCTAssertFalse(strip.showsGrip, "nothing shows without hover")
            strip.mouseEntered(with: try XCTUnwrap(NSEvent.enterExitEvent(with: .mouseEntered, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, trackingNumber: 0, userData: nil)))
            XCTAssertTrue(strip.showsGrip); XCTAssertTrue(strip.currentCursor === NSCursor.openHand)
            strip.mouseDown(with: try event(.leftMouseDown, window, at: CGPoint(x: strip.frame.midX, y: strip.frame.midY)))
            XCTAssertTrue(strip.currentCursor === NSCursor.closedHand, "a closed hand while dragging")
            strip.mouseUp(with: try event(.leftMouseUp, window, at: CGPoint(x: strip.frame.midX, y: strip.frame.midY)))
            XCTAssertTrue(strip.currentCursor === NSCursor.openHand)
            strip.mouseExited(with: try XCTUnwrap(NSEvent.enterExitEvent(with: .mouseExited, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, trackingNumber: 0, userData: nil)))
            XCTAssertFalse(strip.showsGrip)
        }
    }
}
#endif
