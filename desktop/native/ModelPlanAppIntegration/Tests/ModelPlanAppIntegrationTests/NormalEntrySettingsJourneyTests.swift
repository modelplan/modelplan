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

actor SettingsJourneyClient: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore
    let rows: WireRowsSnapshot
    private(set) var grantCalls = 0
    private(set) var starts = 0
    func grantCount() -> Int { grantCalls }
    func startCount() -> Int { starts }
    let context = EngineDeliveryContext(sessionID: "synthetic-entry", floor: .init(storeEpoch: "synthetic-entry", generation: 1), revision: 1)
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    func start() async throws -> EngineDeliveryContext {
        starts += 1
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

@MainActor final class JourneyLoginService: PulseLoginService {
    var state: PulseLoginState = .off
    private(set) var registrations = 0
    func register() throws { registrations += 1; state = .on }
    func unregister() throws { state = .off }
}

@MainActor final class JourneyNotificationService: SettingsNotificationAuthorizationServing {
    var state: NotificationAuthorization = .notDetermined
    private(set) var requests = 0
    func authorization() async -> NotificationAuthorization { state }
    func requestAuthorization() async -> NotificationAuthorization { requests += 1; state = .authorized; return state }
}

@MainActor final class JourneyFirstRunSurface: SettingsWindowSurface {
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

@MainActor final class JourneyAppearanceConsumer: EngineRowsConsoleSurface {
    var applied: EffectiveSettings?
    private(set) var shows = 0
    func show() { shows += 1 }
    func render() {}
    func hide() {}
    func applySettings(_ value: SettingsApplication) { applied = value.effective }
}

@MainActor final class NormalEntrySettingsJourneyTests: XCTestCase {
    func testSyntheticTwoInstallSelectionAndWritableSettingsAfterReplacement() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g4-two-installs-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
        let config = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true)
        var firstClient: SettingsJourneyClient?, secondClient: SettingsJourneyClient?
        func makeApp(_ name: String, client: @escaping @MainActor (SettingsJourneyClient) -> Void) throws -> EngineDockMenuApplication {
            EngineRowsEntry.make(configuration: config,
                settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"]),
                createsNativePanels: false, bundleURL: profile.appendingPathComponent(name + ".app"),
                dockEnvironment: normalEntryTestEnvironment,
                makeClient: { _, store in let value = SettingsJourneyClient(store: store, rows: rows); client(value); return value },
                activateSettings: {})
        }
        let interim = try makeApp("Interim") { firstClient = $0 }
        let candidate = try makeApp("Candidate") { secondClient = $0 }
        interim.notificationAuthorizationService = JourneyNotificationService()
        candidate.notificationAuthorizationService = JourneyNotificationService()
        let firstLogin = JourneyLoginService(), secondLogin = JourneyLoginService()
        interim.loginServiceAdapter = CommunityLoginServiceAdapter(item: PulseLoginItem(isAppBundle: true, service: firstLogin))
        candidate.loginServiceAdapter = CommunityLoginServiceAdapter(item: PulseLoginItem(isAppBundle: true, service: secondLogin))
        defer { interim.composition.dock.close(); candidate.composition.dock.close() }
        await interim.prepare(); await candidate.prepare()
        _ = try await interim.settingsHost.application.editor.commit(SettingsB21Edit.login(true))
        XCTAssertEqual(firstLogin.registrations, 1); XCTAssertEqual(secondLogin.registrations, 0)
        interim.allowDockPresentation()
        await interim.composition.start()
        let active = await (try XCTUnwrap(firstClient)).startCount()
        let inactive = await (try XCTUnwrap(secondClient)).startCount()
        XCTAssertEqual(active, 1); XCTAssertEqual(inactive, 0)
        XCTAssertTrue(interim.composition.dock.interactionEnvironment().active)
        XCTAssertFalse(candidate.composition.dock.interactionEnvironment().active)
        _ = try await interim.settingsHost.application.editor.commit(SettingsB21Edit.autoHide(false))
        await interim.composition.stop(); interim.composition.dock.close()
        let replaced = try makeApp("Interim") { _ in }
        replaced.notificationAuthorizationService = JourneyNotificationService()
        defer { replaced.composition.dock.close() }
        await replaced.prepare()
        XCTAssertEqual(replaced.settingsHost.application.editor.snapshot?.preferences.autoHide, false)
    }
    func testTranslocatedNormalEntryKeepsLoginUnavailableWithoutRegistration() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g4-translocated-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
        let path = URL(fileURLWithPath: "/private/var/folders/synthetic/AppTranslocation/A/d/ModelPlan.app")
        let config = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true)
        let app = EngineRowsEntry.make(configuration: config,
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"]),
            createsNativePanels: false, bundleURL: path, dockEnvironment: normalEntryTestEnvironment,
            makeClient: { _, store in SettingsJourneyClient(store: store, rows: rows) }, activateSettings: {})
        let service = JourneyLoginService()
        app.loginServiceAdapter = CommunityLoginServiceAdapter(item: PulseLoginItem(isAppBundle: true, bundleURL: path, service: service))
        app.notificationAuthorizationService = JourneyNotificationService()
        defer { app.composition.dock.close() }
        await app.prepare()
        XCTAssertEqual(app.currentSettingsContext.capabilities.login, .unavailable)
        XCTAssertEqual(service.registrations, 0)
    }
    func testFoundationStoreFinishesFirstRunWithCheckedReaderWithoutSavingConsent() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("first-run-foundation-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en-US"])
        let before = await store.snapshot()
        var options = OnboardingOptions(preferences: before.preferences)
        XCTAssertFalse(options.readerConsent[.cursor])
        options.readerConsent[.cursor] = true
        let result = try await store.completeFirstRun(options: options, action: .done, host: .popup,
                                                       capabilities: .init(), expectedRevision: before.revision)
        XCTAssertTrue(result.snapshot.preferences.onboarding.completed)
        XCTAssertEqual(result.snapshot.preferences.readerConsent, before.preferences.readerConsent)
        let reopened = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en-US"])
        let restored = await reopened.snapshot()
        XCTAssertTrue(restored.preferences.onboarding.completed)
        XCTAssertEqual(restored.preferences.readerConsent, before.preferences.readerConsent)
    }
    func testHiddenWidgetCanBeRestoredFromMenuAndSettingsAcrossRelaunch() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("widget-recovery-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
        let config = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true)
        func makeApp() throws -> EngineDockMenuApplication {
            EngineRowsEntry.make(configuration: config,
                settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"]),
                createsNativePanels: false, dockEnvironment:normalEntryTestEnvironment, makeClient: { _, store in SettingsJourneyClient(store: store, rows: rows) }, activateSettings: {})
        }
        func select(_ title: String, in menu: NSMenu) throws {
            let item = try XCTUnwrap(menu.items.first { $0.title == title }, "Missing menu item: \(title)")
            XCTAssertTrue(item.isEnabled, "\(title) must be actionable")
            _ = try XCTUnwrap(item.target as? NSObject).perform(try XCTUnwrap(item.action), with: item)
        }
        func waitFor(_ app: EngineDockMenuApplication, shown: Bool) async throws {
            let editor=app.settingsHost.application.editor
            try await waitForSettings(editor) { editor.snapshot?.preferences.showDock == shown && !editor.isSaving }
        }
        func showFromStatusMenu(_ app: EngineDockMenuApplication) async throws {
            try select("Show Quota Widget", in: XCTUnwrap(app.liveStatusMenu))
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
    func testFreshChineseNormalEntryShowsChineseDockCardAge() async throws {
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
        let display = DockDisplayArea(id: "synthetic", frame: .init(x: 0, y: 0, width: 1440, height: 900), visibleFrame: .init(x: 0, y: 80, width: 1440, height: 820))
        var pointer = CGPoint(x: 700, y: 450), elapsed = 0.0
        let app = EngineRowsEntry.make(configuration: configuration,
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["zh-CN"]),
            createsNativePanels: false, dockEnvironment: { .init(displays: [display], layouts: [], primaryDisplayID: "synthetic", pointer: pointer) }, deadlineElapsed:{elapsed}, makeClient: { _, store in SettingsJourneyClient(store: store, rows: fixture) }, activateSettings: {})
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
        let placement = try XCTUnwrap(dock.edgePresentation?.placement)
        let anchor = try XCTUnwrap(dock.dockView.interactionAnchor("0123456789abcdef"))
        pointer = CGPoint(x: placement.frame.minX + anchor.midX - dock.dockView.bounds.minX,
            y: placement.frame.maxY - anchor.midY + dock.dockView.bounds.minY)
        nozzle.hoverNozzle("0123456789abcdef")
        elapsed += 0.251; dock.interactionControllerForChecks?.refresh()
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
