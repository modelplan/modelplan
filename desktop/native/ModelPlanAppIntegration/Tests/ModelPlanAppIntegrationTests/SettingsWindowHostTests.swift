// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
import ModelPlanEngineClient
@testable import ModelPlanAppIntegration

@MainActor final class TestSettingsSurface: SettingsWindowSurface {
    var prepared = 0, hidden = 0
    var shown: [String?] = []
    var preparation: (() async -> Void)?
    var onShow: (() -> Void)?
    func prepare() async { prepared += 1; await preparation?() }
    func show(paneID: String?) { shown.append(paneID); onShow?() }
    func hide() { hidden += 1 }
}

@MainActor final class SettingsWindowHostTests: XCTestCase {
    private func application() throws -> SettingsApplicationCoordinator {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("settings-host-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return SettingsApplicationCoordinator(store: try SettingsStore(url: directory.appendingPathComponent("preferences.json"))) { _ in }
    }

    func testEntryPointsReuseOneEditorAndLazySurface() async throws {
        let app = try application(), surface = TestSettingsSurface()
        var builds = 0
        let host = SettingsWindowHost(application: app, canPresent: { true }, environment: { .init() }) { editor in
            XCTAssertTrue(editor === app.editor); builds += 1; return surface
        }
        XCTAssertEqual(builds, 0)
        await host.present(paneID: "dock")
        try await app.commit(.size(.large))
        await host.present(paneID: "appearance")
        XCTAssertEqual(builds, 1); XCTAssertEqual(surface.prepared, 2)
        XCTAssertEqual(surface.shown.compactMap { $0 }, ["dock", "appearance"])
        XCTAssertEqual(app.editor.effective?.size, .large)
        let item = host.menuItem(title: "Settings…")
        XCTAssertTrue(item.target === host); XCTAssertNotNil(item.action)
        XCTAssertEqual(item.keyEquivalent, ","); XCTAssertEqual(item.keyEquivalentModifierMask, .command)
    }

    func testBlockedEntryDoesNotLoadOrConstructAWindow() async throws {
        let app = try application()
        let host = SettingsWindowHost(application: app, canPresent: { false }, environment: { .init() }) { _ in
            XCTFail("ineligible entry constructed a window"); return TestSettingsSurface()
        }
        await host.present()
        XCTAssertNil(app.editor.snapshot)
    }

    func testEligibilityIsRecheckedAfterPreparation() async throws {
        let app = try application(), surface = TestSettingsSurface()
        var allowed = true
        surface.preparation = { allowed = false }
        let host = SettingsWindowHost(application: app, canPresent: { allowed }, environment: { .init() }, makeSurface: { _ in surface })
        await host.present()
        XCTAssertEqual(surface.prepared, 1); XCTAssertTrue(surface.shown.isEmpty)
    }

    func testSuspendRetiresPendingPresentationAndKeepsSingleton() async throws {
        let app = try application(), surface = TestSettingsSurface()
        var host: SettingsWindowHost!
        var builds = 0
        host = SettingsWindowHost(application: app, canPresent: { true }, environment: { .init() }) { _ in builds += 1; return surface }
        surface.preparation = { host.suspend() }
        await host.present()
        XCTAssertTrue(surface.shown.isEmpty); XCTAssertEqual(surface.hidden, 1)
        surface.preparation = nil
        await host.present()
        XCTAssertEqual(builds, 1); XCTAssertEqual(surface.shown.count, 1)
    }

    func testLatestConcurrentEntryWinsWithoutOrderingAnOldPane() async throws {
        let app = try application(), surface = TestSettingsSurface()
        var waiting: CheckedContinuation<Void, Never>?
        let reached = expectation(description: "first preparation suspended")
        surface.preparation = {
            if surface.prepared == 1 { await withCheckedContinuation { waiting = $0; reached.fulfill() } }
        }
        let host = SettingsWindowHost(application: app, canPresent: { true }, environment: { .init() }, makeSurface: { _ in surface })
        let first = Task { await host.present(paneID: "general") }
        await fulfillment(of: [reached], timeout: 2)
        await host.present(paneID: "appearance")
        waiting?.resume(); await first.value
        XCTAssertEqual(surface.shown.compactMap { $0 }, ["appearance"])
    }

    func testReadOnlyEnvironmentFeedsSameApplicationWithoutPreferenceCommit() async throws {
        let app = try application(), surface = TestSettingsSurface()
        var environment = SettingsEnvironment(); environment.reduceMotion = true; environment.darkAppearance = true
        let host = SettingsWindowHost(application: app, canPresent: { true }, environment: { environment }, makeSurface: { _ in surface })
        await host.present()
        XCTAssertTrue(app.latest?.effective.reduceMotion == true)
        XCTAssertTrue(app.latest?.effective.darkAppearance == true)
        XCTAssertEqual(app.latest?.snapshot.revision, 0)
        XCTAssertEqual(app.latest?.reason, .restore)
    }
    func testPreparationCannotLeaveConsumersBehindTheSharedEditor() async throws {
        let app = try application(), surface = TestSettingsSurface()
        surface.preparation = {
            do { _ = try await app.editor.store.update { $0.size = .small } }
            catch { XCTFail("preparation write failed: \(error)") }
            await app.editor.reload()
        }
        let host = SettingsWindowHost(application: app, canPresent: { true }, environment: { .init() }, makeSurface: { _ in surface })
        await host.present()
        XCTAssertEqual(app.editor.effective?.size, .small)
        XCTAssertEqual(app.latest?.effective.size, .small)
        XCTAssertEqual(app.latest?.snapshot.revision, app.editor.snapshot?.revision)
        XCTAssertEqual(surface.shown.count, 1)
    }

    func testMenuAndGearActionsReachTheSameHost() async throws {
        let app = try application(), surface = TestSettingsSurface()
        var builds = 0
        let host = SettingsWindowHost(application: app, canPresent: { true }, environment: { .init() }, activate: {}) { _ in builds += 1; return surface }
        let gear = expectation(description: "gear action shown")
        surface.onShow = { gear.fulfill() }; host.action()
        await fulfillment(of: [gear], timeout: 2)
        let menu = expectation(description: "menu action shown")
        surface.onShow = { menu.fulfill() }
        let item = host.menuItem(title: "Settings…")
        _ = host.perform(try XCTUnwrap(item.action), with: item)
        await fulfillment(of: [menu], timeout: 2)
        XCTAssertEqual(builds, 1); XCTAssertEqual(surface.shown.count, 2)
    }

    func testNormalEntrySettingsMenuAndWidgetActionShareTheWindow() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("settings-entry-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try await expandedWidgetSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let surface = TestSettingsSurface()
        var builds = 0
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: store, createsNativePanels: false,
            dockEnvironment: normalEntryTestEnvironment, makeSettingsSurface: { _ in builds += 1; return surface },
            activateSettings: {})
        await app.prepare()
        app.allowDockPresentation()
        defer { app.composition.dock.close() }

        let menu = try XCTUnwrap(app.liveStatusMenu)
        let settings = try XCTUnwrap(menu.items.first { $0.title == "Settings…" })
        XCTAssertEqual(settings.keyEquivalent, ",")
        XCTAssertEqual(settings.keyEquivalentModifierMask, .command)
        let menuShown = expectation(description: "Settings menu opens the actual shared host")
        surface.onShow = { menuShown.fulfill() }
        _ = try XCTUnwrap(settings.target as? NSObject).perform(try XCTUnwrap(settings.action), with: settings)
        await fulfillment(of: [menuShown], timeout: 2)

        let widgetShown = expectation(description: "Widget Settings action opens the same host")
        surface.onShow = { widgetShown.fulfill() }
        let nodes = try XCTUnwrap(app.composition.dock.dockView.accessibilityChildren() as? [NSAccessibilityElement])
        let entry = try XCTUnwrap(nodes.first { $0.accessibilityIdentifier() == "dock.empty" })
        XCTAssertTrue(entry.accessibilityPerformPress())
        await fulfillment(of: [widgetShown], timeout: 2)
        XCTAssertEqual(builds, 1)
        XCTAssertEqual(surface.shown.count, 2)
    }

    func testNormalEntryApplicationMenuDispatchesCommandComma() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("settings-key-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = try await expandedWidgetSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let surface = TestSettingsSurface()
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: store, createsNativePanels: false,
            dockEnvironment: normalEntryTestEnvironment, makeSettingsSurface: { _ in surface }, activateSettings: {})
        addTeardownBlock { @MainActor in await app.stopLifecycle(); await app.composition.stop() }
        await app.prepare()
        let key = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
            timestamp: 0, windowNumber: 0, context: nil, characters: ",", charactersIgnoringModifiers: ",",
            isARepeat: false, keyCode: 43))
        let command = try XCTUnwrap(app.applicationMenu.items.first?.submenu?.items.first)
        XCTAssertEqual(command.title, "Settings…")
        XCTAssertTrue(command.target === app.settingsHost)
        let shown = expectation(description: "Command-comma opened the shared Settings host")
        surface.onShow = { shown.fulfill() }
        XCTAssertTrue(app.applicationMenu.performKeyEquivalent(with: key))
        await fulfillment(of: [shown], timeout: 2)
        XCTAssertEqual(surface.shown.count, 1)

        _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.language(.chinese))
        XCTAssertEqual(command.title, "设置…")
        let localized = expectation(description: "Localized application command still opens the same host")
        surface.onShow = { localized.fulfill() }
        XCTAssertTrue(app.applicationMenu.performKeyEquivalent(with: key))
        await fulfillment(of: [localized], timeout: 2)

        surface.onShow = { XCTFail("Paused Command-comma reopened Settings") }
        app.setActivityPaused(true)
        app.startLifecycle(workspace: NotificationCenter(), local: NotificationCenter(), lockEvents: NotificationCenter(),
                           displayIDs: { [1] }, onConsole: { false }, displaysAsleep: { _ in false })
        XCTAssertTrue(app.lifecyclePaused)
        XCTAssertFalse(command.isEnabled)
        XCTAssertFalse(app.applicationMenu.performKeyEquivalent(with: key))
        XCTAssertEqual(surface.shown.count, 2)
    }

    func testNormalEntryDoesNotOfferUpdateActionWithAnAdvertisedCapability() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("no-updates-entry-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try await expandedWidgetSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: store, createsNativePanels: false,
            dockEnvironment: normalEntryTestEnvironment, activateSettings: {})
        defer { app.composition.dock.close() }
        var context = app.settingsHost.application.editor.context
        context.capabilities.updateServiceAvailable = true
        app.settingsHost.application.update(context: context)
        await app.prepare()
        XCTAssertTrue(app.settingsHost.application.editor.context.capabilities.updateServiceAvailable)
        let menu = try XCTUnwrap(app.liveStatusMenu)
        XCTAssertFalse(menu.items.contains { $0.title == "Check for updates" || $0.title == "检查更新" })
        XCTAssertTrue(menu.items.contains { $0.title == "About ModelPlan" })
    }

    func testSuspendAlsoRetiresAnEntryStillQueuedOnTheMainActor() async throws {
        let app = try application(), surface = TestSettingsSurface()
        let unexpected = expectation(description: "suspended queued action ordered a window"); unexpected.isInverted = true
        surface.onShow = { unexpected.fulfill() }
        let host = SettingsWindowHost(application: app, canPresent: { true }, environment: { .init() }, activate: {}, makeSurface: { _ in surface })
        host.action(); host.suspend()
        await fulfillment(of: [unexpected], timeout: 0.05)
        XCTAssertNil(app.editor.snapshot)
    }

    func testDefaultUIObservationPreservesAuthoritativeWindowAndEntranceGates() async throws {
        let app = try application(), surface = TestSettingsSurface()
        var environment = SettingsEnvironment(); environment.fullscreen = true; environment.entranceAccepted = true
        app.update(environment: environment)
        let host = SettingsWindowHost(application: app, canPresent: { true }, makeSurface: { _ in surface })
        await host.present()
        XCTAssertTrue(app.editor.environment.fullscreen)
        XCTAssertTrue(app.editor.environment.entranceAccepted)
        XCTAssertFalse(try XCTUnwrap(app.latest).effective.dockAllowed)
    }

    func testActivationOccursOnlyImmediatelyBeforeAnExplicitUserShow() async throws {
        let app = try application(), surface = TestSettingsSurface()
        var events: [String] = []
        surface.preparation = { events.append("prepare") }; surface.onShow = { events.append("show") }
        let host = SettingsWindowHost(application: app, canPresent: { true }, environment: { .init() },
            activate: { events.append("activate") }, makeSurface: { _ in surface })
        await host.present(origin: .userInitiated)
        // A second activation follows the show: Settings has by then made the app regular.
        XCTAssertEqual(events, ["prepare", "activate", "show", "activate"])
        events = []; await host.present(origin: .restoration)
        XCTAssertEqual(events, ["prepare", "show"])
        events = []; await host.present()
        XCTAssertEqual(events, ["prepare", "show"])
    }

    func testLostEligibilityDoesNotActivateForAUserRequest() async throws {
        let app = try application(), surface = TestSettingsSurface()
        var allowed = true, activations = 0
        surface.preparation = { allowed = false }
        let host = SettingsWindowHost(application: app, canPresent: { allowed }, environment: { .init() },
            activate: { activations += 1 }, makeSurface: { _ in surface })
        await host.present(origin: .userInitiated)
        XCTAssertEqual(activations, 0); XCTAssertTrue(surface.shown.isEmpty)
    }

    func testActivationReentrancyCannotOrderASuspendedWindow() async throws {
        let app = try application(), surface = TestSettingsSurface()
        weak var current: SettingsWindowHost?
        let host = SettingsWindowHost(application: app, canPresent: { true }, environment: { .init() },
            activate: { current?.suspend() }, makeSurface: { _ in surface })
        current = host
        await host.present(origin: .userInitiated)
        XCTAssertTrue(surface.shown.isEmpty); XCTAssertEqual(surface.hidden, 1)
    }

}
