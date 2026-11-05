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

/// These inherited main regressions create actual first-run windows.
/// They remain on the default GUI leg, separate from no-window Settings journeys.
@MainActor final class NormalEntryFirstRunWindowJourneyTests: XCTestCase {
    func testNormalEntrySettingsAndDragUpdateTheDockAndSurviveRelaunch() async throws {
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
                createsNativePanels: false, cockpitEntryEnabled: true, dockEnvironment:normalEntryTestEnvironment,
                makeClient: { _, store in SettingsJourneyClient(store: store, rows: fixture) },
                makeConsole: { _ in appearanceConsumer },
                activateSettings: {})
        }

        let first = try makeApp()
        let login = JourneyLoginService()
        let notifications = JourneyNotificationService()
        first.notificationAuthorizationService = notifications
        first.loginServiceAdapter = CommunityLoginServiceAdapter(item: .init(isAppBundle: true, service: login))
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
        let existingWindows = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
        await first.restoreFirstRunIfNeeded()
        let firstRunWindow = try XCTUnwrap(NSApplication.shared.windows.first { !existingWindows.contains(ObjectIdentifier($0)) && $0.isVisible })
        addTeardownBlock { @MainActor in firstRunWindow.close() }
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        func firstRunViews() throws -> [NSView] { descendants(try XCTUnwrap(firstRunWindow.contentView)) }
        let scopeView = try XCTUnwrap(try firstRunViews().first { $0.accessibilityIdentifier() == "settings.scopeConsent" } as? SettingsScopeConsentView)
        XCTAssertFalse(scopeView.isHiddenOrHasHiddenAncestor)
        XCTAssertFalse(scopeView === first.scopeConsentEntry.view, "First run must not steal the Settings view")
        XCTAssertTrue(first.scopeConsentEntry.controller.selectedIDs.isEmpty, "Restoration must not select or grant any scope")
        let checkbox = try XCTUnwrap(try firstRunViews().first { $0.accessibilityIdentifier() == "scope.allow.codex.local_history" } as? NSButton)
        XCTAssertTrue(checkbox.isEnabled); XCTAssertFalse(checkbox.isHiddenOrHasHiddenAncestor)
        checkbox.performClick(nil)
        XCTAssertEqual(first.scopeConsentEntry.controller.selectedIDs, ["codex.local_history"])
        let syntheticClient = try XCTUnwrap(first.composition.client as? SettingsJourneyClient)
        let grantsBeforeConfirmation = await syntheticClient.grantCount()
        XCTAssertEqual(grantsBeforeConfirmation, 0, "Presenting or selecting must not grant permission")
        let selectedReader = try XCTUnwrap(try firstRunViews().first { $0.accessibilityIdentifier() == "scope.allow.codex.local_history" } as? NSButton)
        selectedReader.performClick(nil)
        XCTAssertTrue(first.scopeConsentEntry.controller.selectedIDs.isEmpty)
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
        try await waitForSettings(editor) { editor.context.notificationAuthorization == .authorized }
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
        try await waitForSettings(editor) {
            !editor.isSaving && editor.snapshot?.preferences.dockEdge == .left && editor.snapshot?.preferences.dockDisplayID == "synthetic-display"
        }
        XCTAssertFalse(editor.isSaving, "The placement commit must finish before the next Settings edit")
        XCTAssertEqual(editor.snapshot?.preferences.dockDisplayID, "synthetic-display")
        XCTAssertEqual(dock.currentMenuBarPreferences?.dockEdge, .left, "The dragged edge applies without a restart")
        _ = try await editor.commit(SettingsB21Edit.language(.chinese))
        await editor.reload()
        let beforeDone = try XCTUnwrap(editor.snapshot)
        let doneButton = try XCTUnwrap(try firstRunViews().first { $0.accessibilityIdentifier() == "firstRun.done" } as? NSButton)
        XCTAssertTrue(doneButton.isEnabled); XCTAssertFalse(doneButton.isHiddenOrHasHiddenAncestor)
        doneButton.performClick(nil)
        var afterDone = await first.foundationStore.snapshot()
        for _ in 0..<200 where !afterDone.preferences.onboarding.completed {
            try await Task.sleep(for: .milliseconds(10)); afterDone = await first.foundationStore.snapshot()
        }
        XCTAssertTrue(afterDone.preferences.onboarding.completed)
        XCTAssertEqual(afterDone.preferences.readerConsent, beforeDone.preferences.readerConsent)
        XCTAssertEqual(login.registrations, 1, "Completing first run must not repeat an already applied login choice")
        for _ in 0..<200 where firstRunWindow.isVisible { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(firstRunWindow.isVisible)
        XCTAssertTrue(scopeView.arrangedSubviews.isEmpty, "Closing first run retires its presentation")
        let grantsAfterDone = await syntheticClient.grantCount()
        XCTAssertEqual(grantsAfterDone, 0, "Completing first run without selected readers must not grant permission")
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
            createsNativePanels: false, dockEnvironment:normalEntryTestEnvironment, makeClient: { _, store in SettingsJourneyClient(store: store, rows: fixture) }, activateSettings: {})
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
    func testLegacyFirstRunControllerChecksReaderAndFinishesWithoutPersistingConsent() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("first-run-controller-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en-US"])
        let before = await store.snapshot()
        let editor = SettingsEditor(store: store)
        let controller = SettingsFirstRunController(editor: editor, host: .popup, scopeConsentEntry: nil)
        defer { controller.suspend(); controller.close() }
        await controller.present()
        let root = try XCTUnwrap(controller.window?.contentView)
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        let views = descendants(root)
        let reader = try XCTUnwrap(views.first { $0.accessibilityIdentifier() == "firstRun.reader.cursor" } as? NSButton)
        XCTAssertFalse(reader.isHiddenOrHasHiddenAncestor); XCTAssertTrue(reader.isEnabled)
        XCTAssertEqual(reader.state, .off)
        reader.performClick(nil)
        XCTAssertEqual(reader.state, .on)
        let done = try XCTUnwrap(views.first { $0.accessibilityIdentifier() == "firstRun.done" } as? NSButton)
        XCTAssertTrue(done.isEnabled); done.performClick(nil)
        var saved = await store.snapshot()
        for _ in 0..<200 where !saved.preferences.onboarding.completed {
            try await Task.sleep(for: .milliseconds(10)); saved = await store.snapshot()
        }
        XCTAssertTrue(saved.preferences.onboarding.completed)
        XCTAssertEqual(saved.preferences.readerConsent, before.preferences.readerConsent)
    }
}
