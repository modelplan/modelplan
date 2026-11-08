// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
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
    func show() { shows += 1; isShowing = true }
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

    /// G3-46: when macOS hides the icon behind a full menu bar, the cockpit has no anchor to open under and
    /// uses the top-right fallback; once the icon shows again it anchors on the icon.
    func testG3_46HiddenIconGivesNoCockpitAnchor() async throws {
        let app = try await application(cockpitEntryEnabled: true)
        defer { app.removeStatusItem(); app.composition.dock.close() }
        app.installStatusItem(); app.renderMenu()
        var visible = false
        app.statusItemVisibility = { visible }
        app.checkStatusItemVisibility()
        XCTAssertNil(app.cockpitAnchor, "a hidden icon is not an anchor")
        visible = true
        app.checkStatusItemVisibility()
        if app.statusButtonForTesting?.window?.isVisible == true { XCTAssertNotNil(app.cockpitAnchor, "a visible icon anchors again") }
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
        app.macOSMajorVersion = { 26 }
        app.checkStatusItemVisibility()
        // G3-52: the covered icon cannot be dragged; the menu points to Settings, which has the steps.
        let notice = "The menu bar is full and the ModelPlan icon is hidden. Settings shows how to fix it."
        let menu = app.composition.dock.menu().items
        XCTAssertEqual(menu.first?.title, notice); XCTAssertFalse(menu.first?.isEnabled ?? true)
        XCTAssertEqual(app.settingsHost.application.editor.context.statusItemNotice?.chinese,
                       "菜单栏已满，macOS 把 ModelPlan 图标藏起来了。腾出位置：在「系统设置 › 菜单栏」里关掉一些图标，或按住 ⌘ 把系统图标拖出菜单栏。在此之前，右键点额度挂件可打开设置。")
        visible = true
        app.checkStatusItemVisibility()
        XCTAssertFalse(app.composition.dock.menu().items.contains { $0.title == notice }, "the notice clears once the icon is visible")
        XCTAssertNil(app.settingsHost.application.editor.context.statusItemNotice)
    }

    /// G3-52 (owner 11-08): the "menu bar full" notice was right but told the user to drag an icon
    /// they cannot see. It now says how to make room on this macOS version and where the Cockpit and
    /// Settings are meanwhile. This checks the wording per version and per build, and that each named
    /// way in works with the status item covered: the widget's Ignition and its right-click menu
    /// (Open Cockpit, Settings…), the Cockpit shortcut and opening the app again (MENU-07b).
    func testG352HiddenIconNoticeNamesWaysInThatWorkWhileTheIconIsHidden() async throws {
        XCTAssertEqual(EngineRowsText.statusItemHidden(macOSMajor: 26, cockpit: true, shortcut: "⌥⌘M").english,
                       "The menu bar is full, so macOS hides the ModelPlan icon. To make room, turn some icons off in System Settings > Menu Bar, or hold ⌘ and drag system icons off the menu bar. Until then, open the Cockpit with the Ignition on the Quota Widget, by opening ModelPlan again from Spotlight, or with ⌥⌘M, and right-click the Quota Widget for Settings.")
        XCTAssertEqual(EngineRowsText.statusItemHidden(macOSMajor: 26, cockpit: true, shortcut: nil).chinese,
                       "菜单栏已满，macOS 把 ModelPlan 图标藏起来了。腾出位置：在「系统设置 › 菜单栏」里关掉一些图标，或按住 ⌘ 把系统图标拖出菜单栏。在此之前，点额度挂件上的点火钮或用聚焦搜索再次打开 ModelPlan，都能打开驾驶舱；右键点额度挂件可打开设置。")
        let sequoia = EngineRowsText.statusItemHidden(macOSMajor: 15, cockpit: true, shortcut: nil)
        XCTAssertTrue(sequoia.english.contains("System Settings > Control Center"), sequoia.english)
        XCTAssertFalse(sequoia.english.contains("System Settings > Menu Bar"), "macOS 15 has no Menu Bar pane")
        XCTAssertTrue(sequoia.chinese.contains("「系统设置 › 控制中心」"), sequoia.chinese)
        for text in [sequoia, EngineRowsText.statusItemHidden(macOSMajor: 26, cockpit: false, shortcut: nil)] {
            XCTAssertFalse(text.english.contains("drag it"), "never ask to drag the hidden icon")
            XCTAssertFalse(text.chinese.contains("把它拖"), "never ask to drag the hidden icon")
        }
        XCTAssertFalse(EngineRowsText.statusItemHidden(macOSMajor: 26, cockpit: false, shortcut: nil).english.contains("Cockpit"),
                       "a build without the Cockpit entry does not offer it")
        XCTAssertEqual(EngineRowsText.chordLabel(ShortcutChord("M", modifiers: [.command, .option])), "⌥⌘M")
        XCTAssertNil(EngineRowsText.chordLabel(.unassigned))

        let console = StatusClickConsole()
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("status-hidden-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        _ = try await store.update { p in p.openShortcut = ShortcutChord("M", modifiers: [.command, .option]) }
        let surface = StatusHiddenSettingsSurface()
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true),
                                       settingsStore: store, createsNativePanels: false, cockpitEntryEnabled: true, dockEnvironment: normalEntryTestEnvironment,
                                       makeSettingsSurface: { _ in surface }, makeConsole: { _ in console }, activateSettings: {})
        let shortcuts = StatusHiddenShortcuts()
        app.shortcutRegistrar = shortcuts
        await app.prepare()
        defer { app.removeStatusItem(); app.composition.dock.close() }
        app.allowDockPresentation()
        app.installStatusItem(); app.renderMenu()
        app.statusItemVisibility = { false }
        app.macOSMajorVersion = { 26 }
        app.checkStatusItemVisibility()
        XCTAssertTrue(app.statusItemHidden)
        XCTAssertEqual(app.settingsHost.application.editor.context.statusItemNotice,
                       EngineRowsText.statusItemHidden(macOSMajor: 26, cockpit: true, shortcut: "⌥⌘M"))

        let dock = app.composition.dock
        _ = dock.perform(NSSelectorFromString("openConsole"))
        XCTAssertEqual(console.shows, 1, "the Ignition opens the Cockpit with the icon covered")
        let menu = dock.menu()
        let open = try XCTUnwrap(menu.items.firstIndex { $0.title == "Open Cockpit" })
        XCTAssertTrue(menu.items[open].isEnabled)
        menu.performActionForItem(at: open)
        XCTAssertEqual(console.shows, 2, "the widget menu opens the Cockpit with the icon covered")
        let settingsIndex = try XCTUnwrap(menu.items.firstIndex { $0.accessibilityIdentifier() == "dock.menu.settings" })
        XCTAssertTrue(menu.items[settingsIndex].isEnabled)
        menu.performActionForItem(at: settingsIndex)
        for _ in 0..<200 where surface.shows == 0 { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(surface.shows, 1, "the widget menu opens Settings with the icon covered")
        XCTAssertEqual(shortcuts.registered[.openCockpit], ShortcutChord("M", modifiers: [.command, .option]))
        shortcuts.onPress?(.openCockpit)
        XCTAssertEqual(console.shows, 3, "the Cockpit shortcut works with the icon covered")
        XCTAssertFalse(app.applicationShouldHandleReopen(.shared, hasVisibleWindows: false))
        XCTAssertEqual(console.shows, 4, "opening the app again opens the Cockpit with the icon covered")
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

@MainActor private final class StatusHiddenSettingsSurface: SettingsWindowSurface {
    var shows = 0
    func prepare() async {}
    func show(paneID: String?) { shows += 1 }
    func hide() {}
}

@MainActor private final class StatusHiddenShortcuts: EngineShortcutRegistering {
    var onPress: ((ShortcutAction) -> Void)?
    var registered: [ShortcutAction: ShortcutChord] = [:]
    func register(_ chord: ShortcutChord, action: ShortcutAction) -> ShortcutRegistration { registered[action] = chord; return .registered }
    func unregisterAll() { registered = [:] }
}
