// SPDX-License-Identifier: MIT
import AppKit
import CryptoKit
import XCTest
import ModelPlanSettings
import ModelPlanShell
import ModelPlanEngineStore
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanAppIntegration

private actor SettingsJourneyClient: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { false }
    let store: EngineStore
    let rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "synthetic-entry", floor: .init(storeEpoch: "synthetic-entry", generation: 1), revision: 1)
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context)))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context), invalidRowCount: 0))
        return context
    }
    func stop() async {}
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("synthetic-rows")) }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
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
    func prepare() async {}
    func show(paneID: String?) { shows += 1 }
    func hide() {}
}

@MainActor final class NormalEntrySettingsJourneyTests: XCTestCase {
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
        func makeApp() throws -> EngineDockMenuApplication {
            EngineRowsEntry.make(configuration: configuration,
                settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en-US"]),
                createsNativePanels: false,
                makeClient: { _, store in SettingsJourneyClient(store: store, rows: fixture) },
                activateSettings: {})
        }

        let first = try makeApp()
        let login = JourneyLoginService()
        let notifications = JourneyNotificationService()
        first.notificationAuthorizationService = notifications
        first.loginServiceAdapter = CommunityLoginServiceAdapter(item: .init(isAppBundle: true, service: login))
        let firstRun = JourneyFirstRunSurface()
        first.makeFirstRunSurface = { _ in firstRun }
        await first.prepare()
        first.composition.dock.setPresentationAllowed(true)
        await first.composition.start()
        await first.restoreFirstRunIfNeeded()
        XCTAssertEqual(firstRun.shows, 1, "A fresh normal entry presents first run")
        let dock = first.composition.dock
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
        XCTAssertTrue(editor.context.v1NormalEntry)
        XCTAssertTrue(try XCTUnwrap(editor.effective).darkAppearance)
        XCTAssertEqual(try XCTUnwrap(editor.effective).opening, .quick)
        let visible = try SettingsCatalogue.rows(preferences: try XCTUnwrap(editor.snapshot).preferences, context: editor.context)
        XCTAssertFalse(visible.contains { [.theme, .opening, .countdown].contains($0.key) })
        XCTAssertEqual(visible.first { $0.key == .openShortcut }?.availability, .serviceUnavailable)
        XCTAssertTrue(visible.first { $0.key == .openShortcut }?.subtitle.english.contains("Unavailable") == true)
        for key in [SettingKey.login, .notificationConsent, .feedback, .websiteLink, .methodologyLink, .privacyLink, .repositoryLink] {
            XCTAssertEqual(visible.first { $0.key == key }?.availability, .available, "Connected S3 services must enable their controls: \(key)")
        }
        XCTAssertEqual(first.composition.provider.dockContent.dockRows.map(\.id), ["codex"])
        XCTExpectFailure("#697: member projection has not yet been integrated") {
            XCTAssertTrue(editor.context.subscriptions.contains { $0.id == "0123456789abcdef" }, "The Settings catalogue must reflect the Dock's detected subscription")
        }
        let initialNozzle = dock.dockView.requestedNozzleDiameter
        _ = try await editor.commit(SettingsB20Edit.size(.large))
        XCTAssertEqual(dock.currentMenuBarPreferences?.size, .large)
        XCTAssertNotEqual(dock.dockView.requestedNozzleDiameter, initialNozzle, "A Settings size edit changes the retained Dock presentation")

        // The host receives the same committed-placement event its real drag controller produces.
        dock.commitDisplayPlacement?("synthetic-display", .left, 0.3)
        for _ in 0..<40 {
            if (await first.foundationStore.snapshot()).preferences.dockEdge == .left { break }
            try await Task.sleep(for: .milliseconds(25))
        }
        XCTAssertEqual(dock.currentMenuBarPreferences?.dockEdge, .left, "The dragged edge applies without a restart")
        _ = try await editor.commit(SettingsB21Edit.language(.chinese))
        await editor.reload()
        let beforeDone = try XCTUnwrap(editor.snapshot)
        let done = try await editor.completeFirstRun(options: .init(preferences: beforeDone.preferences),
            action: .done, host: .popup, expectedRevision: beforeDone.revision)
        XCTAssertTrue(done.snapshot.preferences.onboarding.completed)
        XCTAssertEqual(login.registrations, 1, "Completing first run must not repeat an already applied login choice")
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
}
