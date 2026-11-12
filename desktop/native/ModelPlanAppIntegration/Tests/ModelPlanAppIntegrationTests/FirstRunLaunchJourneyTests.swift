// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
@testable import ModelPlanAppIntegration

/// Synthetic engine with a start gate, so a test decides when the reader "answers". Nothing on the machine is read.
private actor LaunchEngine: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore, facts: WireConsentFacts, rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "fr-launch", floor: .init(storeEpoch: "fr-launch", generation: 1), revision: 1)
    private var released = false, failStart = false, holdRows = false
    private var gate: CheckedContinuation<Void, Never>?
    private var grants: [WireConsentGrantParams] = []
    init(store: EngineStore, facts: WireConsentFacts, rows: WireRowsSnapshot, holdRows: Bool = false, failStart: Bool = false) {
        self.store = store; self.facts = facts; self.rows = rows; self.holdRows = holdRows; self.failStart = failStart
    }
    /// The reader answers its handshake.
    func release() { released = true; gate?.resume(); gate = nil }
    func recordedGrants() -> [WireConsentGrantParams] { grants }
    func deliverRows(_ snapshot: WireRowsSnapshot? = nil) async throws {
        holdRows = false
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: snapshot ?? rows), delivery: context), invalidRowCount: 0))
    }
    func start() async throws -> EngineDeliveryContext {
        if failStart { throw EngineClientError.notReady }
        if !released { await withCheckedContinuation { gate = $0 } }
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        await store.consume(.consentChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: facts), delivery: context)))
        return context
    }
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func stop() async {}
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion {
        if !holdRows { try await deliverRows() }
        return .init(requestID: .string("fr-rows"))
    }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("fr-facts")) }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion {
        grants.append(request); return .init(requestID: .string(request.requestId))
    }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

/// First run v1 (owner OK 2026-11-12, D216; FR-9-09/10/11/12): the guide window comes first, the reader fills it in,
/// Done is the one consent, and the Quota Widget, the cockpit prewarm and the menu bar follow the setup state.
/// Every test goes through the normal entry (`EngineRowsEntry.make`, `beginSetupAtLaunch`, the real first-run window).
@MainActor final class FirstRunLaunchJourneyTests: XCTestCase {
    private func captures() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures", isDirectory: true).standardizedFileURL
    }
    private func facts(tools: Bool) throws -> WireConsentFacts {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: captures().appendingPathComponent("WireConsentFacts.json"))) as? [String: Any])
        let base = try XCTUnwrap((object["scopes"] as? [[String: Any]])?.first)
        object["scopes"] = tools ? [("codex.local_history", "codex", "local_log")].map { id, tool, route -> [String: Any] in
            var scope = base
            scope["scope"] = id; scope["tool"] = tool; scope["route"] = route; scope["state"] = "unset"; scope["detected"] = true
            scope["retired"] = false; scope["defaultCheck"] = true; scope["cleanupPending"] = false
            scope.removeValue(forKey: "disabledReason"); scope.removeValue(forKey: "keychain")
            return scope
        } : [[String: Any]]()
        return try WireDecoder.decode(WireConsentFacts.self, from: JSONSerialization.data(withJSONObject: object))
    }
    /// The captured Codex row, with its account windows, on the Dock and menu surfaces; `empty` has no row at all.
    private func rows(empty: Bool = false) throws -> WireRowsSnapshot {
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: captures().appendingPathComponent("WireRowsSnapshot.json"))) as? [String: Any])
        var projection = try XCTUnwrap(root["projection"] as? [String: Any])
        var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
        rows[0]["surfaces"] = ["dock", "menu"]; rows[0]["expiresAt"] = "2099-01-01T00:00:00Z"
        projection["rows"] = empty ? [[String: Any]]() : rows; root["projection"] = projection
        return try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
    }
    private struct Launch { let app: EngineDockMenuApplication; let engine: LaunchEngine; let profile: URL }
    private func make(profile: URL? = nil, tools: Bool = true, holdRows: Bool = false, failStart: Bool = false, emptyRows: Bool = false,
                      present: Set<String> = ["/h/.codex"], locale: String = "en-US") async throws -> Launch {
        let profile = profile ?? FileManager.default.temporaryDirectory.appendingPathComponent("first-run-launch-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: profile) }
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: [locale])
        let consent = try facts(tools: tools), snapshot = try rows(empty: emptyRows)
        final class Holder: @unchecked Sendable { var engine: LaunchEngine? }
        let holder = Holder()
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:]),
            settingsStore: store, createsNativePanels: false, cockpitEntryEnabled: false, dockEnvironment: normalEntryTestEnvironment,
            makeClient: { _, target in
                let value = LaunchEngine(store: target, facts: consent, rows: snapshot, holdRows: holdRows, failStart: failStart)
                holder.engine = value; return value
            }, activateSettings: {})
        app.firstRunPresence = FirstRunPresenceDetector(home: "/h", searchDirectories: []) { present.contains($0) }
        await app.prepare()
        addTeardownBlock { @MainActor in
            for window in self.firstRunWindows() { window.close() }
            await app.stopLifecycle(); await app.composition.stop(); app.composition.dock.close()
        }
        return Launch(app: app, engine: try XCTUnwrap(holder.engine), profile: profile)
    }
    private func startLifecycle(_ app: EngineDockMenuApplication) {
        app.startLifecycle(workspace: NotificationCenter(), local: NotificationCenter(), lockEvents: NotificationCenter(),
                           displayIDs: { [1] }, onConsole: { true }, displaysAsleep: { _ in false })
    }
    private func wait(seconds: Double = 5, file: StaticString = #filePath, line: UInt = #line, _ predicate: @escaping @MainActor () -> Bool) async throws {
        let end = ContinuousClock.now + .seconds(seconds)
        while !predicate(), ContinuousClock.now < end { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(predicate(), "condition not reached", file: file, line: line)
    }
    private func firstRunWindows() -> [NSWindow] {
        NSApplication.shared.windows.filter { ["First run", "首次运行"].contains($0.title) && $0.isVisible }
    }
    private func views(_ root: NSView) -> [NSView] { [root] + root.subviews.flatMap(views) }
    private func find<T: NSView>(_ id: String, in window: NSWindow, as type: T.Type) -> T? {
        window.contentView.flatMap { views($0).first { $0.accessibilityIdentifier() == id } as? T }
    }
    private func find(_ id: String, in window: NSWindow) -> NSView? { find(id, in: window, as: NSView.self) }
    private func menuTitles(_ app: EngineDockMenuApplication) throws -> [String] {
        try XCTUnwrap(app.liveStatusMenu).items.filter { !$0.isSeparatorItem }.map(\.title)
    }

    func testWindowComesBeforeTheReaderThenRowsFillInAndDoneOpensWithTheHandshake() async throws {
        let launch = try await make()
        let app = launch.app
        XCTAssertTrue(firstRunWindows().isEmpty)
        await app.beginSetupAtLaunch()
        // The reader has not been asked anything yet, and the page is already up with the local check's row.
        let window = try XCTUnwrap(firstRunWindows().first, "FR-9-09: the window is shown before the reader is ready")
        XCTAssertTrue(app.setupActive)
        XCTAssertNil(app.scopeConsentEntry.controller.facts)
        XCTAssertNotNil(find("scope.firstRun.row.codex", in: window), "E2: the tool row is listed from the local presence check")
        XCTAssertNil(find("scope.firstRun.row.claude", in: window), "a tool that is not here is not a row")
        let done = try XCTUnwrap(find("firstRun.done", in: window, as: NSButton.self))
        XCTAssertFalse(done.isEnabled, "owner 11-12 answer 3: Done waits for the reader's handshake")
        let reason = try XCTUnwrap(find("firstRun.doneReason", in: window, as: NSTextField.self))
        XCTAssertFalse(reason.isHidden); XCTAssertEqual(reason.stringValue, FirstRunCopy.needEngine.english)
        // The reader starts behind the window; the window and the page stay as they are, and the widget stays away.
        startLifecycle(app)
        XCTAssertEqual(firstRunWindows().count, 1, "the launch's own withdrawal does not hide the guide")
        XCTAssertNil(app.composition.dock.edgePresentation?.paintedFrame, "no Quota Widget before Done")
        await launch.engine.release()
        try await wait { !app.lifecyclePaused && app.scopeConsentEntry.controller.facts != nil }
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(firstRunWindows().count, 1, "the reader's arrival does not re-prepare the page")
        XCTAssertTrue(done.isEnabled, "Done opens at the handshake")
        XCTAssertNil(app.composition.dock.edgePresentation?.paintedFrame, "still no Quota Widget: it waits for Done")
        // Done saves the one consent, closes the window and brings the widget, with data.
        done.performClick(nil)
        try await wait { !app.setupActive }
        try await wait { app.composition.dock.edgePresentation?.paintedFrame != nil }
        XCTAssertNil(app.pendingFirstWidget)
        let grants = await launch.engine.recordedGrants()
        XCTAssertEqual(grants.count, 1, "Done is the one consent request")
    }

    func testReaderThatNeverStartsKeepsTheWindowWithReasonAndRetry() async throws {
        let launch = try await make(failStart: true)
        let app = launch.app
        await app.beginSetupAtLaunch()
        let window = try XCTUnwrap(firstRunWindows().first)
        startLifecycle(app)
        try await wait { app.scopeConsentEntry.controller.firstRunEngine == .failed }
        XCTAssertEqual(firstRunWindows().count, 1, "a failed start does not close the guide")
        XCTAssertNotNil(find("scope.firstRun.engine.retry", in: window), "Try again is on the page")
        XCTAssertFalse(try XCTUnwrap(find("firstRun.done", in: window, as: NSButton.self)).isEnabled)
        XCTAssertEqual(app.scopeConsentEntry.controller.firstRunDoneBlock, .engineFailed)
    }

    func testClosingMidScanSavesNothingAndTheGuideComesBackFromTheIconAndTheNextLaunch() async throws {
        let launch = try await make()
        let app = launch.app
        var released = 0
        app.releaseCockpitPrewarm = { released += 1 }
        await app.beginSetupAtLaunch()
        let window = try XCTUnwrap(firstRunWindows().first)
        window.close()
        XCTAssertTrue(firstRunWindows().isEmpty)
        let saved = await app.foundationStore.snapshot()
        XCTAssertFalse(saved.preferences.onboarding.completed, "owner 11-12 answer 1: closing is not done; nothing is saved")
        let grants = await launch.engine.recordedGrants(); XCTAssertEqual(grants.count, 0)
        XCTAssertTrue(app.setupActive, "the icon stays in the setting-up state")
        XCTAssertEqual(released, 1, "the held cockpit prewarm no longer waits")
        XCTAssertNil(app.composition.dock.edgePresentation?.paintedFrame, "no widget")
        // The reader becoming ready later does not bring the window back by itself.
        await app.restoreFirstRunIfNeeded()
        XCTAssertTrue(firstRunWindows().isEmpty)
        // The icon (and a second launch of the app) does.
        await app.reopenSetup()
        XCTAssertEqual(firstRunWindows().count, 1)
        firstRunWindows().forEach { $0.close() }
        XCTAssertFalse(app.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false), "reopening returns to the guide, not the cockpit")
        try await wait { self.firstRunWindows().count == 1 }
        firstRunWindows().forEach { $0.close() }
        // Next launch: the same profile still has setup unfinished, so the guide shows again.
        let next = try await make(profile: launch.profile)
        await next.app.beginSetupAtLaunch()
        XCTAssertEqual(firstRunWindows().count, 1, "FR-9-09: the guide returns on the next launch")
    }

    func testMenuBarSaysSettingUpAndOffersOnlyTheWayBackAboutAndQuit() async throws {
        let launch = try await make()
        let app = launch.app
        await app.beginSetupAtLaunch()
        XCTAssertEqual(try menuTitles(app), ["ModelPlan is setting up\u{2026}", "Continue Setup\u{2026}", "About ModelPlan", "Quit ModelPlan"])
        let button = NSButton()
        app.applyStatusContent(to: button, detail: "")
        XCTAssertEqual(button.title, "\u{00B7}\u{00B7}\u{00B7}", "three small dots, never a number")
        XCTAssertEqual(button.alphaValue, 0.5, accuracy: 0.01, "the same icon, dimmed")
        // Continue Setup brings a closed window back.
        firstRunWindows().forEach { $0.close() }
        let item = try XCTUnwrap(app.liveStatusMenu?.items.first { $0.title == "Continue Setup\u{2026}" })
        _ = (item.target as? NSObject)?.perform(item.action, with: item)
        try await wait { self.firstRunWindows().count == 1 }
    }

    func testNoToolsMeansNoWidgetUntilTheFirstToolIsReadThenItAppears() async throws {
        let launch = try await make(tools: false, holdRows: false, emptyRows: true, present: [])
        let app = launch.app
        await app.beginSetupAtLaunch()
        let window = try XCTUnwrap(firstRunWindows().first)
        XCTAssertNotNil(find("scope.firstRun.none", in: window), "no blank page: it says what is supported")
        XCTAssertNotNil(find("scope.firstRun.lookAgain", in: window))
        startLifecycle(app); await launch.engine.release()
        try await wait { !app.lifecyclePaused }
        let done = try XCTUnwrap(find("firstRun.done", in: window, as: NSButton.self))
        try await wait { done.isEnabled }
        done.performClick(nil)
        try await wait { !app.setupActive }
        XCTAssertNotNil(app.pendingFirstWidget, "owner 11-12 answer 2: nothing is read, so the widget waits")
        XCTAssertNil(app.composition.dock.edgePresentation?.paintedFrame)
        XCTAssertFalse(try menuTitles(app).contains("ModelPlan is setting up\u{2026}"), "the icon is back to normal")
        // The first tool is read: the widget appears.
        try await launch.engine.deliverRows(try rows())
        try await wait { app.pendingFirstWidget == nil }
    }

    func testCockpitPrewarmWaitsUntilEveryRowHasAnAnswer() async throws {
        let launch = try await make(holdRows: true)
        let app = launch.app
        var released = 0
        app.releaseCockpitPrewarm = { released += 1 }
        await app.beginSetupAtLaunch()
        await launch.engine.release()
        await app.composition.start()
        try await wait { app.scopeConsentEntry.controller.facts != nil }
        XCTAssertEqual(app.scopeConsentEntry.controller.firstRunToolStatus("codex"), .reading(0), "listed, still being read")
        XCTAssertEqual(released, 0, "E4: the prewarm does not compete with the reader while the scan runs")
        try await launch.engine.deliverRows()
        try await wait { released == 1 }
        XCTAssertTrue(app.scopeConsentEntry.controller.firstRunScanSettled)
    }

    func testReturningUserSeesNoFirstRunAndNormalMenu() async throws {
        let first = try await make()
        let editor = first.app.settingsHost.application.editor
        await editor.reload()
        let fresh = try XCTUnwrap(editor.snapshot)
        _ = try await editor.completeFirstRun(options: .init(preferences: fresh.preferences), action: .done, host: .popup, expectedRevision: fresh.revision)
        let again = try await make(profile: first.profile)
        await again.app.beginSetupAtLaunch()
        XCTAssertTrue(firstRunWindows().isEmpty, "a returning user never sees first run")
        XCTAssertFalse(again.app.setupActive)
        XCTAssertTrue(try menuTitles(again.app).contains("Refresh"), "the normal menu")
    }
}
