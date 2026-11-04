// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings
import ModelPlanWire
@testable import ModelPlanAppIntegration

private actor M6BatchEngine: EngineClient {
    let store: EngineStore
    let rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "g1-m6-batch", floor: .init(storeEpoch: "g1-m6-batch", generation: 1), revision: 1)
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context), invalidRowCount: rows.projection.invalidRowCount))
        return context
    }
    func stop() async {}
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("g1-m6-rows")) }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

/// These window journeys require the admitted GUI CI runner; no actual account is used.
@MainActor final class G1M6Batch1Journeys: XCTestCase {
    private func entry(automaticLaunch: Bool = false, profile: URL? = nil, syntheticMember: Bool = false) async throws -> EngineDockMenuApplication {
        let root = profile ?? FileManager.default.temporaryDirectory.appendingPathComponent("g1-m6-batch-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        if syntheticMember {
            var projection = try XCTUnwrap(object["projection"] as? [String: Any])
            var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
            var row = try XCTUnwrap(rows.first)
            var accounts = try XCTUnwrap(row["accounts"] as? [[String: Any]])
            var account = try XCTUnwrap(accounts.first)
            row["state"] = "fresh"; row["consent"] = "allowed"; row["surfaces"] = ["dock", "menu", "settings"]
            row["expiresAt"] = "2099-01-01T00:00:00Z"
            account["subscriptionRef"] = "1111111111111111"; account["valueState"] = "current"
            account["freshUntil"] = "2099-01-01T00:00:00Z"
            accounts = [account]; row["accounts"] = accounts; rows = [row]; projection["rows"] = rows; object["projection"] = projection
        }
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en-US"])
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true), settingsStore: store, createsNativePanels: false, bundleURL: root.appendingPathComponent("Synthetic.app"), makeClient: { _, target in M6BatchEngine(store: target, rows: rows) }, activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        if automaticLaunch {
            app.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        } else {
            await app.prepare(); await app.composition.start()
        }
        return app
    }
    private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
    private func visibleWindow(after before: Set<ObjectIdentifier>) throws -> NSWindow {
        let window = try XCTUnwrap(NSApplication.shared.windows.first { !before.contains(ObjectIdentifier($0)) && $0.isVisible })
        addTeardownBlock { @MainActor in window.close() }
        return window
    }
    private func firstRun(_ app: EngineDockMenuApplication) async throws -> NSWindow {
        let before = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
        await app.restoreFirstRunIfNeeded()
        return try visibleWindow(after: before)
    }
    private func settings(_ app: EngineDockMenuApplication, pane: String) async throws -> NSWindow {
        let before = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
        await app.settingsHost.present(paneID: pane, origin: .userInitiated)
        return try visibleWindow(after: before)
    }
    private func views(_ window: NSWindow) throws -> [NSView] { descendants(try XCTUnwrap(window.contentView)).filter { !$0.isHiddenOrHasHiddenAncestor } }

    func testG1_FR_9_01_FirstRunIsOnePage() async throws {
        let app = try await entry(), window = try await firstRun(app)
        let visible = try views(window)
        XCTAssertEqual(visible.filter { $0.accessibilityIdentifier() == "firstRun.done" }.count, 1)
        XCTAssertEqual(visible.filter { $0.accessibilityIdentifier() == "firstRun.title" }.count, 1)
        let buttons = visible.compactMap { ($0 as? NSButton)?.title.lowercased() }
        XCTAssertFalse(buttons.contains("next")); XCTAssertFalse(buttons.contains("back"))
        XCTAssertFalse(buttons.contains("continue"))
    }

    func testG1_FR_9_07_ExplorationActionIsAvailable() async throws {
        let app = try await entry(), window = try await firstRun(app)
        let visible = try views(window)
        let done = try XCTUnwrap(visible.first { $0.accessibilityIdentifier() == "firstRun.done" } as? NSButton)
        let help = try XCTUnwrap(descendants(try XCTUnwrap(window.contentView)).first { $0.accessibilityIdentifier() == "firstRun.help" } as? NSButton)
        XCTAssertEqual(done.title, "Done")
        // XCTest expected failures are strict by default.
        XCTExpectFailure("FR-9-07 product-missing: exploration action is hidden") {
            XCTAssertFalse(help.isHiddenOrHasHiddenAncestor)
        }
        guard !help.isHiddenOrHasHiddenAncestor else { return }
        XCTAssertEqual(help.title, "See what's here")
        XCTAssertTrue(help.isEnabled)
        XCTAssertEqual(done.superview, help.superview)
    }

    func testG1_FR_9_09_FirstLaunchPresentsFirstRun() async throws {
        let before = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
        let app = try await entry(automaticLaunch: true)
        for _ in 0..<300 {
            if NSApplication.shared.windows.contains(where: { !before.contains(ObjectIdentifier($0)) && $0.isVisible }) { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let window = try visibleWindow(after: before)
        XCTAssertNotNil(try views(window).first { $0.accessibilityIdentifier() == "firstRun.title" })
        let saved = await app.foundationStore.snapshot().preferences
        XCTAssertFalse(saved.onboarding.completed)
    }

    func testG1_SET_9_02_ActualSettingsSidebarOrder() async throws {
        let app = try await entry(), window = try await settings(app, pane: "general")
        let sidebar = try XCTUnwrap(try views(window).first { $0.accessibilityIdentifier() == "settings.sidebar" } as? NSTableView)
        XCTAssertEqual(sidebar.numberOfRows, 8)
        let names = try (0..<sidebar.numberOfRows).map { index -> String in
            let cell = try XCTUnwrap(sidebar.view(atColumn: 0, row: index, makeIfNecessary: true))
            return try XCTUnwrap(descendants(cell).compactMap { ($0 as? NSTextField)?.stringValue }.first)
        }
        XCTAssertEqual(names, ["General", "Dock", "Cockpit", "Appearance", "Subscriptions", "Notifications", "Data & Privacy", "About"])
    }

    func testG1_SET_9_09_ActualDockDefaultsAndControls() async throws {
        let app = try await entry(), window = try await settings(app, pane: "dock")
        let visible = try views(window)
        for id in ["settings.showDock", "settings.autoHide", "settings.reveal", "settings.magnification", "settings.size"] {
            XCTAssertNotNil(visible.first { $0.accessibilityIdentifier() == id }, "Missing \(id)")
        }
        let saved = await app.foundationStore.snapshot().preferences
        XCTAssertTrue(saved.showDock)
        let show = try XCTUnwrap(visible.first { $0.accessibilityIdentifier() == "settings.showDock" } as? NSPopUpButton)
        let hide = try XCTUnwrap(visible.first { $0.accessibilityIdentifier() == "settings.autoHide" } as? NSPopUpButton)
        XCTAssertEqual(show.selectedItem?.representedObject as? String, "true")
        XCTExpectFailure("SET-9-09 product-missing: auto-hide defaults on") {
            XCTAssertFalse(saved.autoHide)
            XCTAssertEqual(hide.selectedItem?.representedObject as? String, "false")
        }
    }

    func testG1_SET_9_29_UnavailableUpdatesAreHidden() async throws {
        let app = try await entry(), window = try await settings(app, pane: "general")
        XCTAssertFalse(try views(window).contains { $0.accessibilityIdentifier() == "settings.automaticUpdates" })
        await app.settingsHost.present(paneID: "about", origin: .userInitiated)
        XCTAssertFalse(try views(window).contains { $0.accessibilityIdentifier() == "settings.updateStatus" })
    }

    func testG1_SET_9_21_ActualSettingsDiagnosticPayloadIsAllowlisted() async throws {
        let app = try await entry()
        var context = app.settingsHost.application.editor.context
        context.about.appVersion = "1.2.3+private-sentinel"
        context.about.cliVersion = "/synthetic/account-secret"
        context.about.macOSVersion = "14.7.0"
        context.about.enabledReaders = [.codex, .cursor]
        context.about.enabledConnectionTools = []
        context.about.recentErrorCodes = [.stale, .readerUnavailable]
        app.settingsHost.application.update(context: context)
        let window = try await settings(app, pane: "about")
        let controller = try XCTUnwrap(window.windowController as? SettingsWindowController)
        let payload = controller.diagnosticPayloadForChecks
        XCTAssertEqual(payload, "app=1.2.3\ncli=unknown\nmacOS=14.7.0\nreaders=codex,cursor\nerrors=stale,readerUnavailable")
        XCTAssertFalse(payload.contains("private-sentinel"))
        XCTAssertFalse(payload.contains("account-secret"))
    }

    func testG1_SET_9_16_SubscriptionControlsUseActualEntry() async throws {
        let app = try await entry(syntheticMember: true)
        let window = try await settings(app, pane: "subscriptions")
        let all = try views(window)
        let visibility = try XCTUnwrap(all.first { $0.accessibilityIdentifier() == "settings.visible.1111111111111111" } as? NSPopUpButton)
        let alias = try XCTUnwrap(all.first { $0.accessibilityIdentifier() == "settings.alias.1111111111111111" } as? NSTextField)
        let text = all.compactMap { ($0 as? NSTextField)?.stringValue }.joined(separator: "\n")
        XCTAssertTrue(text.contains("Current"), "The source state must be visible")
        XCTExpectFailure("SET-9-16 product-missing: subscription controls are disabled") {
            XCTAssertTrue(visibility.isEnabled); XCTAssertTrue(alias.isEnabled)
        }
        guard visibility.isEnabled && alias.isEnabled else { return }
        let hidden = try XCTUnwrap(visibility.itemArray.first { ($0.representedObject as? String) == "false" })
        visibility.select(hidden); XCTAssertTrue(visibility.sendAction(visibility.action, to: visibility.target))
        for _ in 0..<300 {
            if await app.foundationStore.snapshot().preferences.subscriptions.hiddenIDs.contains("1111111111111111") { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let hiddenPreferences = await app.foundationStore.snapshot().preferences
        XCTAssertTrue(hiddenPreferences.subscriptions.hiddenIDs.contains("1111111111111111"))
        let currentAlias = try XCTUnwrap(try views(window).first { $0.accessibilityIdentifier() == "settings.alias.1111111111111111" } as? NSTextField)
        XCTAssertTrue(window.makeFirstResponder(currentAlias)); currentAlias.stringValue = "Synthetic alias"
        XCTAssertTrue(window.makeFirstResponder(nil))
        for _ in 0..<300 {
            if await app.foundationStore.snapshot().preferences.subscriptionSettings["1111111111111111"]?.alias == "Synthetic alias" { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let saved = await app.foundationStore.snapshot().preferences
        XCTAssertEqual(saved.subscriptionSettings["1111111111111111"]?.alias, "Synthetic alias")
    }

    func testG1_HINT_9_07_ActualSettingsResetPersists() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("g1-m6-hints-" + UUID().uuidString)
        let app = try await entry(profile: root)
        try await app.foundationStore.update { $0.helpHints = .init(seen: [.ignition, .drag], opens: 20, reveals: 20) }
        await app.settingsHost.application.reload()
        let initial = await app.foundationStore.snapshot().preferences.helpHints
        XCTAssertEqual(initial.opens, 2); XCTAssertEqual(initial.reveals, 2)
        let location = try FoundationPreferenceLocation(applicationSupport: root, product: .community)
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: location.target)) as? [String: Any])
        let persistedSettings = try XCTUnwrap(document["settings"] as? [String: Any])
        let hints = try XCTUnwrap(persistedSettings["helpHints"] as? [String: Any])
        XCTAssertEqual(Set(hints.keys), Set(["seen", "opens", "reveals"]))
        let window = try await settings(app, pane: "general")
        let reset = try XCTUnwrap(try views(window).first { $0.accessibilityIdentifier() == "settings.resetHints" } as? NSButton)
        XCTExpectFailure("HINT-9-07 product-missing: reset action is disabled") {
            XCTAssertTrue(reset.isEnabled, "The normal entry must make the reset action available")
        }
        guard reset.isEnabled else { return }
        reset.performClick(nil)
        var saved = await app.foundationStore.snapshot().preferences.helpHints
        for _ in 0..<300 where saved != .init() {
            try await Task.sleep(for: .milliseconds(10))
            saved = await app.foundationStore.snapshot().preferences.helpHints
        }
        XCTAssertEqual(saved, .init())
        let reopened = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en-US"])
        let restored = await reopened.snapshot().preferences.helpHints
        XCTAssertEqual(restored, .init())
    }

    func testG1_LBL_2_2_21_ActualSettingsSurfaceName() async throws {
        let app = try await entry(), window = try await settings(app, pane: "dock")
        let sidebar = try XCTUnwrap(try views(window).first { $0.accessibilityIdentifier() == "settings.sidebar" } as? NSTableView)
        let cell = try XCTUnwrap(sidebar.view(atColumn: 0, row: 1, makeIfNecessary: true))
        let title = try XCTUnwrap(descendants(cell).compactMap { ($0 as? NSTextField)?.stringValue }.first)
        XCTExpectFailure("LBL-2.2-21 product-missing: Settings uses Dock for the surface") {
            XCTAssertEqual(title, "Quota Widget")
        }
    }

    func testG1_FR_9_08_RealDockReveal() throws { throw XCTSkip("FR-9-08 seam-needed: EngineRowsEntry.make task-owned reset-cache input with native panels") }
    func testG1_SET_9_01_AllSettingsEntryRoutes() throws { throw XCTSkip("SET-9-01 seam-needed: EngineDockMenuApplication.statusMenuForChecks and shortcut action receipt") }
    func testG1_SET_9_26_AllActualControlConsumers() throws { throw XCTSkip("SET-9-26 seam-needed: SettingsWindowController actual control-to-consumer action receipts") }
    func testG1_SET_9_29_PackagedCapabilityVisibility() throws { throw XCTSkip("SET-9-29 seam-needed: EngineDockMenuApplication packaged capability and signing observation") }
    func testG1_MOT_2_3_01_DataMotion() throws { throw XCTSkip("MOT-2.3-01 seam-needed: DockInstrumentView animation receipts with role and cause") }
    func testG1_MOT_2_3_02_InteractionFeedback() throws { throw XCTSkip("MOT-2.3-02 seam-needed: DockInteractionController actual presentation feedback receipts") }
    func testG1_MOT_2_3_03_ReduceMotionPresentation() throws { throw XCTSkip("MOT-2.3-03 seam-needed: DockInstrumentView active animation roles and timings") }
    func testG1_MOT_2_3_04_AppAndSystemMotion() throws { throw XCTSkip("MOT-2.3-04 seam-needed: DockInstrumentView actual motion and fade receipts") }
    func testG1_MOT_2_3_08_HiddenMotion() throws { throw XCTSkip("MOT-2.3-08 seam-needed: DockInstrumentView active animation roles and pause state") }
    func testG1_LBL_2_2_01_StripControls() throws { throw XCTSkip("LBL-2.2-01 seam-needed: cockpit page readback for strip control symbols and frames; M3") }
    func testG1_LBL_2_2_03_ToggleStates() throws { throw XCTSkip("LBL-2.2-03 seam-needed: cockpit page readback for toggle labels, active state and frames; M3") }
    func testG1_LBL_2_2_05_LocalizedVisibleStrings() throws { throw XCTSkip("LBL-2.2-05 seam-needed: cockpit page readback for rendered localized strings; M3") }
    func testG1_LBL_2_2_08_Wordmark() throws { throw XCTSkip("LBL-2.2-08 seam-needed: cockpit page readback for wordmark text and colour; M3") }
    func testG1_LBL_2_2_10_CrossSurfaceNames() throws { throw XCTSkip("LBL-2.2-10 seam-needed: real cockpit, notification and Dock label readbacks; M2/M3") }
    func testG1_LBL_2_2_13_SurfaceNames() throws { throw XCTSkip("LBL-2.2-13 seam-needed: cockpit and Dock component name readbacks; M2/M3") }
    func testG1_LBL_2_2_14_ResetCopy() throws { throw XCTSkip("LBL-2.2-14 seam-needed: EngineDockMenuComposition controlled input clock and cockpit reset label readback; M2/M3") }
    func testG1_LBL_2_2_16_AlertLamp() throws { throw XCTSkip("LBL-2.2-16 seam-needed: cockpit page readback for visible alert lamp face; M3") }
    func testG1_LBL_2_2_17_FigureBasisHelp() throws { throw XCTSkip("LBL-2.2-17 seam-needed: cockpit page readback for actual speed/today help; M3") }
    func testG1_HINT_9_01_MapAndAutomaticBudget() throws { throw XCTSkip("HINT-9-01 seam-needed: normal-entry Dock help-map and visible-hint observation; M2") }
    func testG1_HINT_9_03_FirstAutomaticHint() throws { throw XCTSkip("HINT-9-03 seam-needed: normal-entry Dock visible-hint text and anchor; M2") }
    func testG1_HINT_9_04_SecondAutomaticHint() throws { throw XCTSkip("HINT-9-04 seam-needed: normal-entry Dock visible-hint text and anchor; M2") }
    func testG1_HINT_9_05_AutomaticPriority() throws { throw XCTSkip("HINT-9-05 seam-needed: normal-entry Dock committed hint visibility sequence; M2") }
    func testG1_HINT_9_06_AutomaticBudget() throws { throw XCTSkip("HINT-9-06 seam-needed: normal-entry Dock committed hint visibility sequence and concurrency; M2") }
    func testG1_SET_9_20_ActualAboutActions() throws { throw XCTSkip("SET-9-20 seam-needed: normal-entry update-service and public-link action receipts") }
}
