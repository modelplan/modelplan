// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanAppIntegration

/// G3-22: the menu bar item must never be blank. Uses the window server (status bar), so GUI leg.
@MainActor private final class StatusClickConsole: EngineRowsConsoleSurface {
    var shows = 0
    func show() { shows += 1 }
    func render() {}
    func hide() {}
}

@MainActor private final class TogglingStatusConsole: EngineRowsConsoleSurface {
    var shows = 0, closes = 0, hides = 0
    private(set) var isShowing = false
    var onShowingChanged: (() -> Void)?
    func show() { shows += 1; isShowing = true }
    /// The page closing by itself (its X key or an outside press).
    func pageClosed() { isShowing = false; onShowingChanged?() }
    func render() {}
    func hide() { hides += 1; isShowing = false }
    func requestClose() { closes += 1; isShowing = false }
}

@MainActor final class StatusItemLaunchTests: XCTestCase {
    private func click(_ type: NSEvent.EventType, on button: NSButton, flags: NSEvent.ModifierFlags = []) throws -> NSEvent {
        try XCTUnwrap(NSEvent.mouseEvent(with: type, location: .zero, modifierFlags: flags, timestamp: 0,
            windowNumber: button.window?.windowNumber ?? 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
    }

    /// D44: both halves of a click are claimed, so AppKit never starts menu tracking for a left click.
    func testLeftClickOpensTheCockpitWithoutTheMenu() async throws {
        let console = StatusClickConsole()
        let app = try await application(cockpitEntryEnabled: true, console: console)
        defer { app.removeStatusItem(); app.composition.dock.close() }
        app.installStatusItem(); app.renderMenu()
        let button = try XCTUnwrap(app.statusButtonForTesting)
        XCTAssertTrue(app.handleStatusClick(try click(.leftMouseDown, on: button)))
        XCTAssertEqual(console.shows, 0, "the cockpit opens on mouse-up")
        XCTAssertTrue(app.handleStatusClick(try click(.leftMouseUp, on: button)))
        XCTAssertEqual(console.shows, 1)
        XCTAssertFalse(app.handleStatusClick(try click(.leftMouseUp, on: button)), "an unpaired mouse-up is not a click")
    }

    /// MENU-07 at the entry: the cockpit opens from the icon's own frame, on release however long the press,
    /// and each later click reaches the same console, which toggles it.
    func testMENU_07ClickOpensBelowTheIconQuickOnlyAndAgainToggles() async throws {
        let console = StatusClickConsole()
        let app = try await application(cockpitEntryEnabled: true, console: console)
        defer { app.removeStatusItem(); app.composition.dock.close() }
        app.installStatusItem(); app.renderMenu()
        let button = try XCTUnwrap(app.statusButtonForTesting), window = try XCTUnwrap(button.window)
        XCTAssertEqual(app.cockpitAnchor, window.convertToScreen(button.convert(button.bounds, to: nil)), "the anchor is the icon itself")
        XCTAssertTrue(app.handleStatusClick(try click(.leftMouseDown, on: button)))
        try await Task.sleep(for: .milliseconds(700)) // longer than a hold would need: there is no hold in v1
        XCTAssertEqual(console.shows, 0, "holding does nothing")
        XCTAssertTrue(app.handleStatusClick(try click(.leftMouseUp, on: button)))
        XCTAssertEqual(console.shows, 1)
        XCTAssertTrue(app.handleStatusClick(try click(.leftMouseDown, on: button)))
        XCTAssertTrue(app.handleStatusClick(try click(.leftMouseUp, on: button)))
        XCTAssertEqual(console.shows, 2, "the second click reaches the console, which owns the toggle")
    }

    /// G3-40 / MENU-07: a click on the icon while the cockpit is open closes it, through the user close so
    /// its fade and saved position hold; the next click opens it again. Other entries only ever open.
    func testG3_40SecondClickOnTheIconClosesAndThirdReopens() async throws {
        let console = TogglingStatusConsole()
        let app = try await application(cockpitEntryEnabled: true, console: console)
        defer { app.removeStatusItem(); app.composition.dock.close() }
        app.installStatusItem(); app.renderMenu()
        let button = try XCTUnwrap(app.statusButtonForTesting)
        func press() throws {
            XCTAssertTrue(app.handleStatusClick(try click(.leftMouseDown, on: button)))
            XCTAssertTrue(app.handleStatusClick(try click(.leftMouseUp, on: button)))
        }
        try press()
        XCTAssertEqual(console.shows, 1); XCTAssertTrue(console.isShowing)
        try press()
        XCTAssertEqual(console.closes, 1, "the second click closes"); XCTAssertEqual(console.shows, 1)
        XCTAssertEqual(console.hides, 0, "a user close, not the immediate teardown"); XCTAssertFalse(console.isShowing)
        try press()
        XCTAssertEqual(console.shows, 2, "the third click opens again"); XCTAssertTrue(console.isShowing)
        app.showConsole()
        XCTAssertEqual(console.shows, 3); XCTAssertEqual(console.closes, 1, "the Open Cockpit entries never close")
    }

    /// G3-49: the icon's tooltip covered the porthole. It is withdrawn while the cockpit shows, and comes
    /// back on every way the cockpit closes; the accessible help is never withdrawn.
    func testG3_49IconTooltipIsWithdrawnWhileTheCockpitShows() async throws {
        let console = TogglingStatusConsole()
        let app = try await application(cockpitEntryEnabled: true, console: console)
        defer { app.removeStatusItem(); app.composition.dock.close() }
        app.installStatusItem(); app.renderMenu()
        let button = try XCTUnwrap(app.statusButtonForTesting)
        let tooltip = try XCTUnwrap(button.toolTip, "the icon has a tooltip while the cockpit is closed")
        func press() throws {
            XCTAssertTrue(app.handleStatusClick(try click(.leftMouseDown, on: button)))
            XCTAssertTrue(app.handleStatusClick(try click(.leftMouseUp, on: button)))
        }
        try press()
        XCTAssertNil(button.toolTip, "no tooltip over the open cockpit")
        XCTAssertEqual(button.accessibilityHelp(), tooltip)
        app.renderMenu()
        XCTAssertNil(button.toolTip, "a menu refresh does not bring it back while open")
        try press()
        XCTAssertEqual(button.toolTip, tooltip, "back after the icon closes the cockpit")
        app.showConsole()
        XCTAssertNil(button.toolTip)
        console.pageClosed()
        XCTAssertEqual(button.toolTip, tooltip, "back after the cockpit closes itself")
    }

    /// D44: these clicks are left to AppKit, which shows the attached menu; sending them would start real tracking.
    func testRightAndControlClickKeepTheMenu() async throws {
        let console = StatusClickConsole()
        let app = try await application(cockpitEntryEnabled: true, console: console)
        defer { app.removeStatusItem(); app.composition.dock.close() }
        app.installStatusItem(); app.renderMenu()
        let button = try XCTUnwrap(app.statusButtonForTesting)
        XCTAssertTrue(app.statusMenuForTesting === app.liveStatusMenu, "the menu stays attached for right-click and accessibility")
        XCTAssertFalse(app.handleStatusClick(try click(.leftMouseDown, on: button, flags: .control)))
        XCTAssertFalse(app.handleStatusClick(try click(.leftMouseUp, on: button, flags: .control)))
        XCTAssertFalse(app.handleStatusClick(try click(.rightMouseDown, on: button)))
        XCTAssertFalse(app.handleStatusClick(try click(.leftMouseDown, on: button, flags: .command)), "Command-drag moves the icon")
        XCTAssertEqual(console.shows, 0)
    }

    func testLeftClickKeepsTheMenuWhileTheCockpitEntryIsOff() async throws {
        let console = StatusClickConsole()
        let app = try await application(cockpitEntryEnabled: false, console: console)
        defer { app.removeStatusItem(); app.composition.dock.close() }
        app.installStatusItem(); app.renderMenu()
        let button = try XCTUnwrap(app.statusButtonForTesting)
        XCTAssertTrue(app.statusMenuForTesting === app.liveStatusMenu)
        XCTAssertFalse(app.handleStatusClick(try click(.leftMouseDown, on: button)))
        XCTAssertFalse(app.handleStatusClick(try click(.leftMouseUp, on: button)))
        XCTAssertEqual(console.shows, 0)
    }

    func testReopeningTheAppOpensTheCockpitOnlyWhenTheEntryIsOn() async throws {
        for enabled in [true, false] {
            let console = StatusClickConsole()
            let app = try await application(cockpitEntryEnabled: enabled, console: console)
            defer { app.composition.dock.close() }
            XCTAssertFalse(app.applicationShouldHandleReopen(.shared, hasVisibleWindows: false))
            XCTAssertEqual(console.shows, enabled ? 1 : 0)
        }
    }

    private func application(cockpitEntryEnabled: Bool? = nil,
                             console: (any EngineRowsConsoleSurface)? = nil) async throws -> EngineDockMenuApplication {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("status-item-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true), settingsStore: store, createsNativePanels: false, cockpitEntryEnabled: cockpitEntryEnabled, dockEnvironment: normalEntryTestEnvironment, makeConsole: console.map { surface in { _ in surface } }, activateSettings: {})
        await app.prepare()
        return app
    }

    func testLaunchedStatusButtonShowsTheTemplateImageOrAVisibleTitle() async throws {
        let app = try await application()
        defer { app.removeStatusItem(); app.composition.dock.close() }
        // The same install + first render applicationDidFinishLaunching runs, without starting the engine lifecycle.
        app.installStatusItem()
        app.renderMenu()
        let button = try XCTUnwrap(app.statusButtonForTesting)
        if let image = button.image {
            XCTAssertTrue(image.isTemplate)
            XCTAssertGreaterThan(image.size.width, 0); XCTAssertGreaterThan(image.size.height, 0)
            XCTAssertFalse(image.representations.isEmpty)
        } else {
            XCTAssertEqual(button.title, EngineDockMenuApplication.statusFallbackTitle)
        }
        XCTAssertTrue(button.image != nil || !button.title.isEmpty, "The status item must never be zero-width")
        XCTAssertNotNil(button.image, "Template image lookup: \(CommunityMenuBarResources.lastLookup)")
    }

    /// G3-22 (owner Mac, build 5): the item exists but sits behind the notch of a full menu bar.
    /// An icon-only item is square, and a covered item is announced in the widget menu and Settings.
    func testCoveredStatusItemIsAnnouncedAndIconOnlyItemIsSquare() async throws {
        let app = try await application()
        defer { app.removeStatusItem(); app.composition.dock.close() }
        app.installStatusItem()
        app.renderMenu()
        let button = try XCTUnwrap(app.statusButtonForTesting)
        if button.title.isEmpty, button.image != nil {
            XCTAssertEqual(app.statusLengthForTesting, NSStatusItem.squareLength, "an icon-only item uses the square length")
            XCTAssertEqual(button.imagePosition, .imageOnly)
        }
        var visible = false
        app.statusItemVisibility = { visible }
        app.checkStatusItemVisibility()
        let notice = "The menu bar is full and the ModelPlan icon is hidden. Hold ⌘ and drag it to the right."
        let menu = app.composition.dock.menu().items
        XCTAssertEqual(menu.first?.title, notice); XCTAssertFalse(menu.first?.isEnabled ?? true)
        XCTAssertEqual(app.settingsHost.application.editor.context.statusItemNotice?.chinese, "菜单栏已满，ModelPlan 图标被挡住了。按住 ⌘ 把它拖到右边。")
        visible = true
        app.checkStatusItemVisibility()
        XCTAssertFalse(app.composition.dock.menu().items.contains { $0.title == notice }, "the notice clears once the icon is visible")
        XCTAssertNil(app.settingsHost.application.editor.context.statusItemNotice)
    }

    func testMissingTemplateImageFallsBackToAVisibleTitle() async throws {
        let app = try await application()
        defer { app.composition.dock.close() }
        let button = NSButton(title: "", target: nil, action: nil)
        EngineDockMenuApplication.configureStatusButton(button, image: nil, barThickness: 22)
        app.applyStatusContent(to: button, detail: "")
        XCTAssertNil(button.image)
        let presented = app.composition.menuPresentation.title
        XCTAssertEqual(button.title, presented.isEmpty ? EngineDockMenuApplication.statusFallbackTitle : presented)
        XCTAssertFalse(button.title.isEmpty)
    }

    func testPackagedLookupResolvesFromTheAppResourceDirectoryAtAnyInstallPath() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("status-install-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        for parent in ["Applications", "Downloads/nested folder"] {
            let app = root.appendingPathComponent(parent).appendingPathComponent("ModelPlan Community.app")
            let resources = app.appendingPathComponent("Contents/Resources")
            try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
            let main = try XCTUnwrap(Bundle(url: app))
            let resolved = try XCTUnwrap(CommunityMenuBarResources.packagedBundleURL(main: main))
            XCTAssertEqual(resolved.lastPathComponent, CommunityMenuBarResources.bundleName)
            XCTAssertEqual(resolved.deletingLastPathComponent().resolvingSymlinksInPath().path, resources.resolvingSymlinksInPath().path)
            XCTAssertNil(CommunityMenuBarResources.templateImage(appURL: app))
            XCTAssertTrue(CommunityMenuBarResources.lastLookup.hasPrefix("missing"))
            try FileManager.default.copyItem(at: CommunityMenuBarResources.buildBundleURL, to: resources.appendingPathComponent(CommunityMenuBarResources.bundleName))
            XCTAssertTrue(try XCTUnwrap(CommunityMenuBarResources.templateImage(appURL: app)).isTemplate)
            XCTAssertTrue(CommunityMenuBarResources.lastLookup.hasPrefix("loaded"))
        }
        XCTAssertNil(CommunityMenuBarResources.packagedBundleURL(main: try XCTUnwrap(Bundle(url: root))), "Outside an .app the build bundle is used")
    }
}
