// SPDX-License-Identifier: MIT
import AppKit
import CryptoKit
import XCTest
import ModelPlanSettings
import ModelPlanDock
import ModelPlanShell
import ModelPlanEngineStore
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanAppIntegration

private actor SettingsJourneyClient: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore
    let rows: WireRowsSnapshot
    private(set) var grantCalls = 0
    func grantCount() -> Int { grantCalls }
    let context = EngineDeliveryContext(sessionID: "synthetic-entry", floor: .init(storeEpoch: "synthetic-entry", generation: 1), revision: 1)
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context)))
        await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context), invalidRowCount: 0))
        return context
    }
    func stop() async {}
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("synthetic-rows")) }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { grantCalls += 1; throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("synthetic-refresh")) }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

@MainActor private final class JourneyLoginService: PulseLoginService {
    var state: PulseLoginState = .off
    private(set) var registrations = 0
    func register() throws { registrations += 1; state = .on }
    func unregister() throws { state = .off }
}

@MainActor private final class JourneyNotificationService: SettingsNotificationAuthorizationServing {
    var state: NotificationAuthorization = .notDetermined
    private(set) var requests = 0
    func authorization() async -> NotificationAuthorization { state }
    func requestAuthorization() async -> NotificationAuthorization { requests += 1; state = .authorized; return state }
}

@MainActor private final class JourneyFirstRunSurface: SettingsWindowSurface {
    private(set) var shows = 0
    var scopeEntry: ScopeConsentEntry?
    private(set) var scopePresentation: FirstRunConsentPresentation?
    var scopeView: SettingsScopeConsentView? { scopePresentation?.view }
    func prepare() async {
        if let scopeEntry {
            let presentation = FirstRunConsentPresentation(entry: scopeEntry)
            try? presentation.prepare(language: .english); scopePresentation = presentation
        }
    }
    func show(paneID: String?) { shows += 1 }
    func hide() { scopePresentation?.suspend(); scopePresentation = nil }
}

@MainActor private final class JourneyAppearanceConsumer: EngineRowsConsoleSurface {
    var applied: EffectiveSettings?
    private(set) var shows = 0
    func show() { shows += 1 }
    func render() {}
    func hide() {}
    func applySettings(_ value: SettingsApplication) { applied = value.effective }
}

@MainActor final class NormalEntrySettingsJourneyTests: XCTestCase {
    func testHiddenWidgetCanBeRestoredFromMenuAndSettingsAcrossRelaunch() async throws {
        _ = NSApplication.shared
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("widget-recovery-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
        let config = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true)
        func makeApp() throws -> EngineDockMenuApplication {
            EngineRowsEntry.make(configuration: config,
                settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"]),
                createsNativePanels: false, makeClient: { _, store in SettingsJourneyClient(store: store, rows: rows) }, activateSettings: {})
        }
        func select(_ title: String, in menu: NSMenu) throws {
            let item = try XCTUnwrap(menu.items.first { $0.title == title }, "Missing menu item: \(title)")
            XCTAssertTrue(item.isEnabled, "\(title) must be actionable")
            _ = try XCTUnwrap(item.target as? NSObject).perform(try XCTUnwrap(item.action), with: item)
        }
        func waitFor(_ app: EngineDockMenuApplication, shown: Bool) async throws {
            for _ in 0..<250 {
                let editor = app.settingsHost.application.editor
                if editor.snapshot?.preferences.showDock == shown && !editor.isSaving { return }
                try await Task.sleep(for: .milliseconds(20))
            }
            XCTFail("showDock did not become \(shown)")
        }
        func showFromStatusMenu(_ app: EngineDockMenuApplication) async throws {
            for _ in 0..<250 {
                if let menu = app.liveStatusMenu, let item = menu.items.first(where: { $0.title == "Show Quota Widget" }), item.isEnabled {
                    try select("Show Quota Widget", in: menu); return
                }
                try await Task.sleep(for: .milliseconds(20))
            }
            XCTFail("Show Quota Widget did not become available")
        }
        let first = try makeApp(); defer { first.composition.dock.close() }
        await first.prepare(); first.allowDockPresentation()
        await first.composition.start()
        try select("Hide Quota Widget", in: first.composition.dock.menu())
        try await waitFor(first, shown: false)
        XCTAssertFalse(first.composition.dock.interactionEnvironment().active)
        try await showFromStatusMenu(first)
        try await waitFor(first, shown: true)
        XCTAssertTrue(first.composition.dock.interactionEnvironment().active)

        try select("Hide Quota Widget", in: first.composition.dock.menu())
        try await waitFor(first, shown: false)
        let editor = first.settingsHost.application.editor
        let snapshot = try XCTUnwrap(editor.snapshot)
        let settingsRows = try SettingsCatalogue.rows(preferences: snapshot.preferences, context: editor.context, paneID: nil)
        XCTAssertEqual(settingsRows.first { $0.key == .showDock }?.availability, .available)
        _ = try await editor.commit(SettingsB21Edit.showDock(true))
        XCTAssertTrue(first.composition.dock.interactionEnvironment().active)

        try select("Hide Quota Widget", in: first.composition.dock.menu())
        try await waitFor(first, shown: false)
        await first.composition.stop()
        first.composition.dock.close()
        let reopened = try makeApp(); await reopened.prepare(); reopened.allowDockPresentation()
        defer { reopened.composition.dock.close() }
        XCTAssertEqual(reopened.settingsHost.application.editor.snapshot?.preferences.showDock, false)
        try await showFromStatusMenu(reopened)
        try await waitFor(reopened, shown: true)
        XCTAssertTrue(reopened.composition.dock.interactionEnvironment().active)
    }
    func testNormalEntrySettingsAndDragUpdateTheDockAndSurviveRelaunch() async throws {
        _ = NSApplication.shared
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("settings-journey-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(root["projection"] as? [String: Any])
        var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
        rows[0]["surfaces"] = ["dock", "menu"]
        rows[0]["expiresAt"] = "2027-01-01T00:00:00Z"
        projection["rows"] = rows; root["projection"] = projection
        let fixture = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
        let configuration = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true)
        let appearanceConsumer = JourneyAppearanceConsumer()
        func makeApp() throws -> EngineDockMenuApplication {
            EngineRowsEntry.make(configuration: configuration,
                settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en-US"]),
                createsNativePanels: false, cockpitEntryEnabled: true,
                makeClient: { _, store in SettingsJourneyClient(store: store, rows: fixture) },
                makeConsole: { _ in appearanceConsumer },
                activateSettings: {})
        }

        let first = try makeApp()
        let login = JourneyLoginService()
        let notifications = JourneyNotificationService()
        first.notificationAuthorizationService = notifications
        first.loginServiceAdapter = CommunityLoginServiceAdapter(item: .init(isAppBundle: true, service: login))
        let firstRun = JourneyFirstRunSurface()
        first.makeFirstRunSurfaceWithConsent = { _, entry in firstRun.scopeEntry = entry; return firstRun }
        await first.prepare()
        first.composition.dock.setPresentationAllowed(true)
        await first.composition.start()
        let consentCapture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireConsentFacts.json").standardizedFileURL
        var consentObject = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: consentCapture)) as? [String: Any])
        let baseScope = try XCTUnwrap((consentObject["scopes"] as? [[String: Any]])?.first)
        consentObject["scopes"] = [("codex.local_history", "local_log"), ("cursor.saved_login", "saved_login_api"), ("cursor.browser_session", "browser_session"), ("cursor.unknown_path", "unknown")].map { id, route in
            var scope = baseScope; scope["scope"] = id; scope["tool"] = id.hasPrefix("codex") ? "codex" : "cursor"
            scope["route"] = route; scope["state"] = "unset"; scope["detected"] = true; scope["retired"] = false
            scope["defaultCheck"] = true; scope["cleanupPending"] = false; scope.removeValue(forKey: "disabledReason"); scope.removeValue(forKey: "keychain")
            return scope
        }
        let facts = try WireDecoder.decode(WireConsentFacts.self, from: JSONSerialization.data(withJSONObject: consentObject))
        let delivery = try XCTUnwrap(first.composition.store.snapshot.delivery)
        await first.composition.store.consume(.response(requestID: .string("synthetic-consent"), .consent(.init(envelope: try .init(sessionId: delivery.sessionID, storeEpoch: delivery.floor.storeEpoch, consentGeneration: delivery.floor.generation, data: facts), delivery: delivery))))
        await first.restoreFirstRunIfNeeded()
        XCTAssertEqual(firstRun.shows, 1, "A fresh normal entry presents first run")
        XCTAssertTrue(firstRun.scopeEntry === first.scopeConsentEntry, "First run must use the app's accepted consent controller")
        XCTAssertNotNil(firstRun.scopeView, "First run must construct its own consent view")
        XCTAssertTrue(firstRun.scopeView?.superview === firstRun.scopePresentation?.container, "The first-run consent view must be mounted in its actual presentation container")
        XCTAssertFalse(firstRun.scopeView === first.scopeConsentEntry.view, "First run must not steal the Settings view")
        XCTAssertTrue(first.scopeConsentEntry.controller.selectedIDs.isEmpty, "Restoration must not select or grant any scope")
        first.scopeConsentEntry.controller.selectAll()
        XCTAssertEqual(first.scopeConsentEntry.controller.selectedIDs, ["codex.local_history", "cursor.saved_login"], "Select all must exclude browser and unknown paths")
        let syntheticClient = try XCTUnwrap(first.composition.client as? SettingsJourneyClient)
        let grantsBeforeConfirmation = await syntheticClient.grantCount()
        XCTAssertEqual(grantsBeforeConfirmation, 0, "Presenting or selecting must not grant permission")
        let dock = first.composition.dock
        XCTAssertTrue(dock.interactionBindingInstalled, "Normal entry must install the real host port")
        XCTAssertTrue(dock.interactionEnvironment().active, "The normal entry must expose the official interaction projection")
        XCTAssertNotNil(dock.dockView.registeredHullPath)
        let cockpitButton = try XCTUnwrap(dock.dockView.superview?.subviews.compactMap { $0 as? NSButton }.first)
        XCTAssertEqual(cockpitButton.accessibilityLabel(), "Open cockpit")
        let englishMenu = try XCTUnwrap(first.liveStatusMenu)
        XCTAssertTrue(englishMenu.delegate is DockStatusMenu, "The normal status menu must use the shared component")
        let englishDockMenu = dock.menu()
        XCTAssertTrue(englishDockMenu.delegate is DockSliverMenu, "The Dock menu must use the shared component")
        XCTAssertEqual(englishMenu.items.filter { !$0.isSeparatorItem }.map(\.title), ["Refresh", "Show Quota Widget", "Open Cockpit", "Website", "Methodology", "Privacy", "Help…", "Settings…", "About", "Quit"])
        let refreshItem = try XCTUnwrap(englishMenu.items.first { $0.title == "Refresh" })
        XCTAssertEqual(refreshItem.action, NSSelectorFromString("refreshRows"), "The existing Refresh arrival observer must retain its native selector")
        XCTAssertEqual(Array(englishDockMenu.items.filter { !$0.isSeparatorItem }.suffix(3)).map(\.title), ["Open Cockpit", "Settings…", "Hide Quota Widget"])
        let statusCockpit = try XCTUnwrap(englishMenu.items.first { $0.title == "Open Cockpit" })
        _ = (try XCTUnwrap(statusCockpit.target as? NSObject)).perform(try XCTUnwrap(statusCockpit.action), with: statusCockpit)
        let dockCockpit = try XCTUnwrap(englishDockMenu.items.first { $0.title == "Open Cockpit" })
        _ = (try XCTUnwrap(dockCockpit.target as? NSObject)).perform(try XCTUnwrap(dockCockpit.action), with: dockCockpit)
        XCTAssertEqual(appearanceConsumer.shows, 2, "Both shared menu components must dispatch the retained cockpit route")
        XCTAssertTrue(englishMenu.items.contains { $0.title == "Settings…" })
        XCTAssertTrue(englishMenu.items.contains { $0.title == "Open Cockpit" })
        XCTAssertFalse(englishMenu.items.contains { $0.title.contains(" / ") })
        let editor = first.settingsHost.application.editor
        XCTAssertEqual(editor.snapshot?.preferences.language, .english, "A fresh install follows the macOS preferred language")
        XCTAssertEqual(login.registrations, 0, "Restoring settings must not register an OS service")
        XCTAssertEqual(notifications.requests, 0, "Restoration must not request notification authorization")
        _ = try await editor.commit(SettingsB22Edit.notificationConsent(true))
        for _ in 0..<40 {
            if editor.context.notificationAuthorization == .authorized { break }
            try await Task.sleep(for: .milliseconds(25))
        }
        XCTAssertEqual(notifications.requests, 1, "Only explicit opt-in requests notification authorization")
        XCTAssertEqual(editor.context.notificationAuthorization, .authorized)
        _ = try await editor.commit(SettingsB22Edit.notificationConsent(true))
        XCTAssertEqual(notifications.requests, 1, "Repeated opt-in must not prompt again")
        _ = try await editor.commit(SettingsB21Edit.login(true))
        XCTAssertEqual(login.registrations, 1, "An explicit login choice reaches the system-service adapter")
        XCTAssertEqual(editor.context.capabilities.login, .enabled, "Settings reports the observed service result")
        XCTAssertTrue(editor.canPresentFirstRun, "The normal entry must route the first-run action")
        XCTAssertTrue(editor.context.capabilities.firstRunPreviewAvailable, "First-run navigation must be available from Settings")
        first.showConsole()
        var syntheticSystem = editor.environment
        syntheticSystem.reduceMotion = true; syntheticSystem.reduceTransparency = true
        first.updateSystemAccessibility(syntheticSystem)
        XCTAssertEqual(appearanceConsumer.applied?.reduceMotion, true)
        XCTAssertEqual(appearanceConsumer.applied?.reduceTransparency, true)
        syntheticSystem.reduceMotion = false; syntheticSystem.reduceTransparency = false
        first.updateSystemAccessibility(syntheticSystem)
        _ = try await editor.commit(SettingsB20Edit.motion(.on))
        _ = try await editor.commit(SettingsB20Edit.transparency(.on))
        XCTAssertEqual(appearanceConsumer.applied?.reduceMotion, true)
        XCTAssertEqual(appearanceConsumer.applied?.reduceTransparency, true)
        XCTAssertEqual(first.composition.latestSettings?.effective.reduceMotion, true)
        XCTAssertEqual(first.composition.latestSettings?.effective.reduceTransparency, true)
        XCTAssertTrue(editor.context.v1NormalEntry)
        let firstRunPage = try FirstRunPage(preferences: try XCTUnwrap(editor.snapshot).preferences, context: editor.context)
        XCTAssertTrue(firstRunPage.showsExploration, "Normal entry exposes the installed Help-map action")
        XCTAssertTrue(try XCTUnwrap(editor.effective).darkAppearance)
        XCTAssertEqual(try XCTUnwrap(editor.effective).opening, .quick)
        let visible = try SettingsCatalogue.rows(preferences: try XCTUnwrap(editor.snapshot).preferences, context: editor.context)
        XCTAssertFalse(visible.contains { [.theme, .opening, .countdown].contains($0.key) })
        XCTAssertEqual(visible.first { $0.key == .motion }?.availability, .available)
        XCTAssertEqual(visible.first { $0.key == .transparency }?.availability, .available)
        XCTAssertEqual(visible.first { $0.key == .openShortcut }?.availability, .serviceUnavailable)
        XCTAssertTrue(visible.first { $0.key == .openShortcut }?.subtitle.english.contains("Unavailable") == true)
        for key in [SettingKey.login, .notificationConsent, .feedback, .websiteLink, .methodologyLink, .privacyLink, .repositoryLink] {
            XCTAssertEqual(visible.first { $0.key == key }?.availability, .available, "Connected S3 services must enable their controls: \(key)")
        }
        XCTAssertEqual(first.composition.provider.dockContent.dockRows.map(\.id), ["codex"])
        // Member identity rule: Settings now receives the verified subscription member ID.
        XCTAssertTrue(editor.context.subscriptions.contains { $0.id == "0123456789abcdef" }, "The Settings catalogue must reflect the Dock's detected subscription")
        XCTAssertEqual(editor.snapshot?.preferences.language, .english, "A fresh install follows the macOS preferred language")
        XCTAssertEqual(editor.snapshot?.preferences.percentageMode, .remaining)
        _ = try await editor.commit(SettingsB20Edit.percentageMode(.used))
        XCTAssertEqual(dock.currentMenuBarPreferences?.percentageMode, .used)
        let initialNozzle = dock.dockView.requestedNozzleDiameter
        _ = try await editor.commit(SettingsB20Edit.size(.large))
        XCTAssertEqual(dock.currentMenuBarPreferences?.size, .large)
        XCTAssertNotEqual(dock.dockView.requestedNozzleDiameter, initialNozzle, "A Settings size edit changes the retained Dock presentation")

        // The host receives the same committed-placement event its real drag controller produces.
        dock.commitDisplayPlacement?("synthetic-display", .left, 0.3)
        for _ in 0..<250 {
            if !editor.isSaving, editor.snapshot?.preferences.dockEdge == .left,
               editor.snapshot?.preferences.dockDisplayID == "synthetic-display" { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertFalse(editor.isSaving, "The placement commit must finish before the next Settings edit")
        XCTAssertEqual(editor.snapshot?.preferences.dockDisplayID, "synthetic-display")
        XCTAssertEqual(dock.currentMenuBarPreferences?.dockEdge, .left, "The dragged edge applies without a restart")
        _ = try await editor.commit(SettingsB21Edit.language(.chinese))
        await editor.reload()
        let beforeDone = try XCTUnwrap(editor.snapshot)
        let done = try await editor.completeFirstRun(options: .init(preferences: beforeDone.preferences),
            action: .done, host: .popup, expectedRevision: beforeDone.revision)
        XCTAssertTrue(done.snapshot.preferences.onboarding.completed)
        XCTAssertEqual(login.registrations, 1, "Completing first run must not repeat an already applied login choice")
        let retiredScope = try XCTUnwrap(firstRun.scopeView)
        firstRun.hide()
        XCTAssertTrue(retiredScope.arrangedSubviews.isEmpty, "Closing first run retires its presentation")
        let grantsAfterDone = await syntheticClient.grantCount()
        XCTAssertEqual(grantsAfterDone, 0, "Completing first run must not implicitly authorize selected scopes")
        XCTAssertFalse(first.scopeConsentEntry.view.arrangedSubviews.isEmpty, "Settings retains its separate consent view")
        XCTAssertEqual(cockpitButton.accessibilityLabel(), "打开驾驶舱")
        let chineseMenu = try XCTUnwrap(first.liveStatusMenu)
        XCTAssertTrue(chineseMenu.delegate is DockStatusMenu)
        let chineseDockMenu = dock.menu()
        XCTAssertTrue(chineseDockMenu.delegate is DockSliverMenu)
        XCTAssertEqual(chineseMenu.items.filter { !$0.isSeparatorItem }.map(\.title), ["刷新", "显示额度挂件", "打开驾驶舱", "网站", "方法论", "隐私", "说明…", "设置…", "关于", "退出"])
        XCTAssertEqual(Array(chineseDockMenu.items.filter { !$0.isSeparatorItem }.suffix(3)).map(\.title), ["打开驾驶舱", "设置…", "隐藏额度挂件"])
        XCTAssertTrue(chineseMenu.items.contains { $0.title == "设置…" })
        XCTAssertTrue(chineseMenu.items.contains { $0.title == "打开驾驶舱" })
        XCTAssertFalse(chineseMenu.items.contains { $0.title.contains(" / ") || $0.title.contains("Dock") })
        await first.composition.stop()

        let reopened = try makeApp()
        let reopenedLogin = JourneyLoginService()
        let reopenedNotifications = JourneyNotificationService()
        let reopenedFirstRun = JourneyFirstRunSurface()
        reopened.notificationAuthorizationService = reopenedNotifications
        reopened.loginServiceAdapter = CommunityLoginServiceAdapter(item: .init(isAppBundle: true, service: reopenedLogin))
        reopened.makeFirstRunSurface = { _ in reopenedFirstRun }
        await reopened.prepare()
        reopened.composition.dock.setPresentationAllowed(true)
        await reopened.composition.start()
        await reopened.restoreFirstRunIfNeeded()
        XCTAssertEqual(reopenedFirstRun.shows, 0, "Completed first run stays completed after relaunch")
        XCTAssertEqual(reopenedLogin.registrations, 0, "Restoration must not register the login service")
        XCTAssertEqual(reopenedNotifications.requests, 0, "Restoration must not request notification authorization")
        let saved = await reopened.foundationStore.snapshot()
        XCTAssertEqual(saved.preferences.size, .large)
        XCTAssertEqual(saved.preferences.language, .chinese, "An explicit choice survives relaunch even when the OS prefers English")
        XCTAssertEqual(saved.preferences.language, .chinese, "An explicit choice survives relaunch")
        XCTAssertEqual(saved.preferences.percentageMode, .used)
        XCTAssertEqual(saved.preferences.motion, .on)
        XCTAssertEqual(saved.preferences.transparency, .on)
        XCTAssertEqual(EngineRowsText.readingsTitle.value(.chinese), "额度挂件读数")
        XCTAssertEqual(EngineRowsText.waiting.value(.chinese), "等待读数")
        XCTAssertEqual(saved.preferences.dockEdge, .left)
        XCTAssertEqual(saved.preferences.dockDisplayID, "synthetic-display")
        XCTAssertEqual(saved.preferences.dockAlongFraction, 0.3, accuracy: 0.0001)
        XCTAssertEqual(reopened.composition.dock.currentMenuBarPreferences?.dockEdge, .left)
        XCTAssertEqual(reopened.composition.dock.dockView.requestedNozzleDiameter, dock.dockView.requestedNozzleDiameter)
        await reopened.composition.stop()

        let unavailable = EngineRowsEntry.make(configuration: configuration,
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile.appendingPathComponent("unavailable"), preferredLanguages: ["en-US"]),
            createsNativePanels: false, makeClient: { _, store in SettingsJourneyClient(store: store, rows: fixture) }, activateSettings: {})
        let unavailableLogin = JourneyLoginService(); unavailableLogin.state = .unavailable
        let unavailableNotifications = JourneyNotificationService(); unavailableNotifications.state = .unavailable
        unavailable.loginServiceAdapter = CommunityLoginServiceAdapter(item: .init(isAppBundle: true, service: unavailableLogin))
        unavailable.notificationAuthorizationService = unavailableNotifications
        await unavailable.prepare()
        let unavailableEditor = unavailable.settingsHost.application.editor
        let unavailableRows = try SettingsCatalogue.rows(preferences: try XCTUnwrap(unavailableEditor.snapshot).preferences, context: unavailableEditor.context)
        for key in [SettingKey.login, .notificationConsent] {
            XCTAssertEqual(unavailableRows.first { $0.key == key }?.availability, .serviceUnavailable)
            XCTAssertTrue(unavailableRows.first { $0.key == key }?.subtitle.english.contains("Unavailable") == true)
        }
        XCTAssertEqual(unavailableLogin.registrations, 0); XCTAssertEqual(unavailableNotifications.requests, 0)
        await unavailable.composition.stop()

        let otherProfile = profile.appendingPathComponent("system-language")
        let chineseStore = try EngineRowsEntry.makeSettingsStore(applicationSupport: otherProfile,
            preferredLanguages: ["zh-Hans", "en-US"])
        let chinese = await chineseStore.snapshot()
        XCTAssertEqual(chinese.preferences.language, .chinese, "Use Chinese when the Mac prefers Chinese")
        let otherLanguage = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile.appendingPathComponent("other-language"),
            preferredLanguages: ["fr-FR", "zh-Hans", "en-US"])
        let otherSnapshot = await otherLanguage.snapshot()
        XCTAssertEqual(otherSnapshot.preferences.language, .english, "A non-Chinese Mac preference defaults to English")
        let noLanguage = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile.appendingPathComponent("no-language"), preferredLanguages: [])
        let noLanguageSnapshot = await noLanguage.snapshot()
        XCTAssertEqual(noLanguageSnapshot.preferences.language, .english, "A missing Mac preference defaults to English")
        let legacyProfile = profile.appendingPathComponent("legacy-language")
        let legacyFile = legacyProfile.appendingPathComponent("ModelPlan/Native/settings-v1.json")
        try FileManager.default.createDirectory(at: legacyFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        let legacyBytes = Data(#"{"schemaVersion":1,"preferences":{"language":"zh-CN"}}"#.utf8)
        try legacyBytes.write(to: legacyFile)
        let migrated = try EngineRowsEntry.makeSettingsStore(applicationSupport: legacyProfile, preferredLanguages: ["en-US"])
        let migratedSnapshot = await migrated.snapshot()
        XCTAssertEqual(migratedSnapshot.preferences.language, .chinese,
                       "A migrated language choice takes precedence over the system default")
        XCTAssertEqual(try Data(contentsOf: legacyFile), legacyBytes)
    }
    func testFreshChineseNormalEntryShowsChineseDockCardAge() async throws {
        _ = NSApplication.shared
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("chinese-card-age-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(root["projection"] as? [String: Any])
        var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
        rows[0]["surfaces"] = ["dock", "menu"]; rows[0]["expiresAt"] = "2027-01-01T00:00:00Z"
        projection["rows"] = rows; root["projection"] = projection
        let fixture = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
        let configuration = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true)
        let app = EngineRowsEntry.make(configuration: configuration,
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["zh-CN"]),
            createsNativePanels: false, makeClient: { _, store in SettingsJourneyClient(store: store, rows: fixture) }, activateSettings: {})
        await app.prepare()
        // Preserve the fresh Chinese language while opening the real interactive surface.
        _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.autoHide(false))
        // The normal entry also starts the interaction controller; bypassing it
        // leaves the official nozzle unable to dispatch its card action.
        app.allowDockPresentation(); await app.composition.start()
        defer { app.composition.dock.close() }
        let dock = app.composition.dock
        XCTAssertEqual(app.settingsHost.application.editor.snapshot?.preferences.language, .chinese)
        XCTAssertTrue(dock.interactionEnvironment().active)
        XCTAssertTrue(dock.interactionEnvironment().parentExpanded)
        let interaction = dock.interactionEnvironment()
        // Member identity rule: the verified subscription ref keys the normal-entry card.
        XCTAssertTrue(interaction.catalogue.contains("0123456789abcdef"), "The synthetic member must reach the real controller")
        // Member identity rule: card content uses the same member key.
        XCTAssertNotNil(interaction.contents["0123456789abcdef"], "The real controller must receive card content")
        XCTAssertTrue(dock.interactionControllerRunning)
        XCTAssertNotNil(dock.dockView.nozzleEventDelegate)
        // Member identity rule: interaction targets the member, not its tool row.
        let nozzle = try XCTUnwrap(dock.dockView.nozzleEventDelegate)
        nozzle.hoverNozzle("0123456789abcdef")
        for _ in 0..<100 { if !dock.card.isHidden { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(dock.card.isHidden)
        func field(_ view: NSView) -> NSTextField? {
            if let value = view as? NSTextField, value.accessibilityIdentifier() == "dock.card.text.source" { return value }
            return view.subviews.lazy.compactMap(field).first
        }
        let age = try XCTUnwrap(field(dock.card)?.stringValue)
        XCTAssertTrue(age.contains("读数时间未知") || age.contains("刚刚") || age.contains("分钟前") || age.contains("小时前"), "Fresh Chinese entry must render the actual card age in Chinese: \(age)")
        _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.language(.english))
        XCTAssertFalse(dock.card.isHidden, "The hovered card must survive the language change")
        let englishAge = try XCTUnwrap(field(dock.card)?.stringValue)
        XCTAssertTrue(englishAge.contains("Reading time unknown") || englishAge.contains("just now") || englishAge.contains(" ago"), "The same card must follow an explicit English choice: \(englishAge)")
        await app.composition.stop()
    }

}
