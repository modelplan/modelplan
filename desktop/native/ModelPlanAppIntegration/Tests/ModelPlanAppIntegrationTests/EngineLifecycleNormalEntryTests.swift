// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanEngineStore
import ModelPlanEngineClient
import ModelPlanWire
import ModelPlanCockpitWeb
@testable import ModelPlanAppIntegration

private actor LifecycleEngine: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore
    let rows: WireRowsSnapshot?
    private var current: EngineDeliveryContext?
    private var first: EngineDeliveryContext?
    private var starts = 0, stops = 0
    private var consentError: EngineClientError = .unsupportedCapability
    private var consentCalls = 0
    func consentCount() -> Int { consentCalls }
    func failConsent() { consentError = .protocolViolation }
    private var holdStop = false
    private var stopGate: CheckedContinuation<Void, Never>?
    func holdNextStop() { holdStop = true }
    func releaseStop() { stopGate?.resume(); stopGate = nil }
    init(store: EngineStore, rows: WireRowsSnapshot? = nil) { self.store = store; self.rows = rows }
    func counts() -> (Int, Int) { (starts, stops) }
    func start() async throws -> EngineDeliveryContext {
        starts += 1
        let value = EngineDeliveryContext(sessionID: "synthetic-\(starts)", floor: .init(storeEpoch: "synthetic-\(starts)", generation: 1), revision: UInt64(starts))
        current = value; if first == nil { first = value }
        await store.consume(.connection(.ready(value))); await store.consume(.context(value)); return value
    }
    func stop() async {
        stops += 1
        if holdStop { holdStop = false; await withCheckedContinuation { stopGate = $0 } }
        await store.consume(.clearPrivateViews(.init(revision: UInt64(starts + 1), reason: .stopped, previous: current, nextFloor: nil)))
        current = nil
    }
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func publish(_ value: EngineDeliveryContext) async throws {
        guard let rows else { return }
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: value.sessionID, storeEpoch: value.floor.storeEpoch, consentGeneration: value.floor.generation, data: rows), delivery: value), invalidRowCount: 0))
    }
    func publishOld() async throws { if let first { try await publish(first) } }
    func publishFresh() async throws { if let current { try await publish(current) } }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion {
        if starts == 1, let current { try await publish(current) }
        return .init(requestID: .string("synthetic-subscribe-\(starts)"))
    }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { consentCalls += 1; throw consentError }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

@MainActor private final class LifecycleFirstRunProbe: SettingsWindowSurface {
    var shows = 0, hides = 0
    func prepare() async {}
    func show(paneID: String?) { shows += 1 }
    func hide() { hides += 1 }
}

@MainActor final class EngineLifecycleNormalEntryTests: XCTestCase {
    func testFirstRunWaitsForFreshRowsAndWithdrawsOnPause() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("first-run-gate-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let fixture = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
        var client: LifecycleEngine?
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"]), createsNativePanels: false, makeClient: { _, store in let value = LifecycleEngine(store: store, rows: fixture); client = value; return value }, activateSettings: {})
        let surface = LifecycleFirstRunProbe(); app.makeFirstRunSurfaceWithConsent = { _, _ in surface }
        await app.prepare(); let engine = try XCTUnwrap(client)
        app.setActivityPaused(true)
        let workspace = NotificationCenter()
        app.startLifecycle(workspace: workspace, local: NotificationCenter(), lockEvents: NotificationCenter(), displayIDs: { [1] }, onConsole: { true }, displaysAsleep: { _ in false })
        await app.restoreFirstRunIfNeeded()
        XCTAssertEqual(surface.shows, 0, "A blocked gate must not present first run")
        app.setActivityPaused(false)
        for _ in 0..<1000 { if surface.shows > 0 { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(surface.shows, 1, "First run resumes only after current rows")
        workspace.post(name: NSWorkspace.willSleepNotification, object: nil)
        XCTAssertTrue(app.lifecyclePaused); XCTAssertGreaterThan(surface.hides, 0, "Pause withdraws an already visible first run")
        await app.restoreFirstRunIfNeeded(); XCTAssertEqual(surface.shows, 1)
        workspace.post(name: NSWorkspace.didWakeNotification, object: nil)
        for _ in 0..<1000 { if await engine.counts().0 >= 2 { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(surface.shows, 1, "Wake without fresh rows must not present first run")
        try await engine.publishFresh()
        for _ in 0..<1000 { if surface.shows >= 2 { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(surface.shows, 2)
        try app.settingsHost.application.editor.request(.previewFirstRun)
        for _ in 0..<1000 { if surface.shows >= 3 { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(surface.shows, 3, "Explicit navigation remains available after resumption")
        await app.stopLifecycle()
    }

    func testConsentFailureWithdrawsNormalEntryUntilRetry() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("lifecycle-consent-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let fixture = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
        var client: LifecycleEngine?
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"]), createsNativePanels: false, makeClient: { _, store in let value = LifecycleEngine(store: store, rows: fixture); client = value; return value }, activateSettings: {})
        await app.prepare(); let engine = try XCTUnwrap(client); await engine.failConsent()
        app.startLifecycle(workspace: NotificationCenter(), local: NotificationCenter(), lockEvents: NotificationCenter(), displayIDs: { [1] }, onConsole: { true }, displaysAsleep: { _ in false })
        for _ in 0..<1000 { if await engine.consentCount() > 0 { break }; try await Task.sleep(for: .milliseconds(10)) }
        let count = await engine.consentCount(); XCTAssertEqual(count, 1)
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertTrue(app.lifecyclePaused, "A real consent failure must withdraw the normal presentation")
        XCTAssertEqual(app.liveStatusMenu?.items.first?.title, "Waiting for current readings. Refresh to retry.")
        await app.stopLifecycle()
    }

    func testSleepWakeAndActivityGateNeverReshowOldRows() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("lifecycle-journey-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(object["projection"] as? [String: Any])
        var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
        rows[0]["surfaces"] = ["dock", "menu"]; rows[0]["expiresAt"] = "2027-01-01T00:00:00Z"
        projection["rows"] = rows; object["projection"] = projection
        let fixture = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
        var client: LifecycleEngine?
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true),
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en-US"]), createsNativePanels: false,
            makeClient: { _, store in let result = LifecycleEngine(store: store, rows: fixture); client = result; return result }, activateSettings: {})
        let workspace = NotificationCenter(), local = NotificationCenter(), lockEvents = NotificationCenter()
        var displayIDs: Set<UInt32> = [1]
        await app.prepare()
        app.startLifecycle(workspace: workspace, local: local, lockEvents: lockEvents,
                           displayIDs: { displayIDs }, onConsole: { true }, displaysAsleep: { _ in false })
        let engine = try XCTUnwrap(client)
        for _ in 0..<100 where app.lifecyclePaused { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(app.lifecyclePaused)
        XCTAssertEqual(app.composition.provider.dockContent.dockRows.map(\.id), ["codex"])
        let oldStatus = try XCTUnwrap(app.liveStatusMenu?.items.first)
        let oldDock = app.composition.dock.menu()
        let retainedDockItems = oldDock.items
        let unrelated = NSMenu(); unrelated.addItem(withTitle: "Unrelated synthetic menu", action: nil, keyEquivalent: "")
        await engine.holdNextStop()
        workspace.post(name: NSWorkspace.willSleepNotification, object: nil)
        XCTAssertTrue(app.lifecyclePaused, "Sleep must immediately withdraw the presentation")
        XCTAssertEqual(oldStatus.title, "", "A retained old status item must be scrubbed immediately")
        XCTAssertTrue(retainedDockItems.allSatisfy { $0.title.isEmpty }, "Retained Dock menu items must not expose old readings")
        XCTAssertEqual(unrelated.items.first?.title, "Unrelated synthetic menu")
        for _ in 0..<100 { if await engine.counts().1 > 0 { break }; try await Task.sleep(for: .milliseconds(10)) }
        let afterSleep = await engine.counts()
        XCTAssertGreaterThan(afterSleep.1, 0)
        app.setActivityPaused(true)
        workspace.post(name: NSWorkspace.didWakeNotification, object: nil)
        try await Task.sleep(for: .milliseconds(30))
        let whileActivityPaused = await engine.counts()
        XCTAssertEqual(whileActivityPaused.0, 1, "Wake must not clear another pause reason")
        app.setActivityPaused(false)
        try await Task.sleep(for: .milliseconds(30))
        let beforeStopFinishes = await engine.counts()
        XCTAssertEqual(beforeStopFinishes.0, 1, "Wake must wait until the old process is stopped")
        await engine.releaseStop()
        for _ in 0..<100 { if await engine.counts().0 >= 2 { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(app.lifecyclePaused, "A new process without fresh rows must not reveal stale content")
        try await engine.publishOld()
        XCTAssertTrue(app.lifecyclePaused, "Late rows from the old session cannot reopen the Dock")
        XCTAssertEqual(app.liveStatusMenu?.items.first?.title, "Waiting for current readings. Refresh to retry.")
        XCTAssertFalse(app.composition.dock.menu().items.contains { $0.title.contains("synthetic") }, "A paused Dock menu must not reconstruct the stale row")
        try await engine.publishFresh()
        for _ in 0..<100 where app.lifecyclePaused { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(app.lifecyclePaused)
        lockEvents.post(name: Notification.Name("com.apple.screenIsLocked"), object: nil)
        XCTAssertTrue(app.lifecyclePaused, "Lock must withdraw the presentation")
        for _ in 0..<100 { if await engine.counts().1 >= 2 { break }; try await Task.sleep(for: .milliseconds(10)) }
        displayIDs = []
        local.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        lockEvents.post(name: Notification.Name("com.apple.screenIsUnlocked"), object: nil)
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertTrue(app.lifecyclePaused, "Unlock must not clear the no-display reason")
        let blockedRefresh = try XCTUnwrap(app.liveStatusMenu?.items.first { $0.title == "Refresh" })
        XCTAssertFalse(blockedRefresh.isEnabled, "An OS pause must not offer a no-op refresh")
        let whileNoDisplay = await engine.counts()
        XCTAssertEqual(whileNoDisplay.0, 2)
        displayIDs = [1]
        local.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        for _ in 0..<100 { if await engine.counts().0 >= 3 { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(app.lifecyclePaused, "A restored display still waits for current rows")
        let retry = try XCTUnwrap(app.liveStatusMenu?.items.first { $0.title == "Refresh" })
        XCTAssertTrue(retry.isEnabled, "A foreground retry must be available while waiting for fresh data")
        _ = (try XCTUnwrap(retry.target as? NSObject)).perform(try XCTUnwrap(retry.action), with: retry)
        for _ in 0..<100 { if await engine.counts().0 >= 4 { break }; try await Task.sleep(for: .milliseconds(10)) }
        let afterRetry = await engine.counts()
        XCTAssertEqual(afterRetry.0, 4)
        try await engine.publishFresh()
        for _ in 0..<100 where app.lifecyclePaused { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(app.lifecyclePaused)
        await app.stopLifecycle()
    }
}

/// Normal entry with detached native views. The admitted M1 run covers actual windows and displays.
@MainActor final class DockPulsePlacementNormalEntryTests: XCTestCase {
    private final class RowsReplyProbe: EngineStoreEventSink {
        private(set) var count = 0
        func clearPrivateViews(_ invalidation: EngineInvalidation) {}
        func apply(_ snapshot: EngineStoreSnapshot) {}
        func acceptedEvent(_ event: EngineClientEvent) {
            switch event {
            case .rowsChanged, .response(_, .rows): count += 1
            default: break
            }
        }
    }

    private final class Topology {
        var primary = DockDisplayArea(id: "A", frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: CGRect(x: 0, y: 70, width: 1512, height: 875), backingScale: 2)
        let neighbour = DockDisplayArea(id: "B", frame: CGRect(x: 1512, y: -300, width: 2560, height: 1440),
            visibleFrame: CGRect(x: 1512, y: -300, width: 2560, height: 1415))
        var joined = false
        var fullscreen = false
        var cockpitClosed = true
        var pointer = CGPoint(x: 750, y: 450)
        func read() -> DockEdgeEnvironment {
            var presence = DockPresence()
            presence.allowedOverFullscreen = !fullscreen
            presence.cockpitClosed = cockpitClosed
            return .init(displays: joined ? [primary, neighbour] : [primary], layouts: [],
                         primaryDisplayID: primary.id, pointer: pointer, presence: presence)
        }
    }

    private func profile() -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dock-pulse-" + UUID().uuidString)
        addTeardownBlock { if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) } }
        return root
    }

    private func make(_ root: URL, topology: Topology, rows: WireRowsSnapshot? = nil, native: Bool = false,
                      beforePrepare: ((EngineDockMenuApplication) -> Void)? = nil, edit: ((inout SettingsPreferences) -> Void)? = nil)
        async throws -> EngineDockMenuApplication {
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        if let edit { _ = try await store.update { edit(&$0) } }
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("synthetic-engine"),
            applicationVersion: "test", allowedEnvironment: [:], offline: true, readOnly: true),
            settingsStore: store, createsNativePanels: native, dockEnvironment: topology.read,
            makeClient: { _, store in LifecycleEngine(store: store, rows: rows) }, activateSettings: {})
        beforePrepare?(app)
        await app.prepare()
        addTeardownBlock { @MainActor in await app.stopLifecycle(); app.composition.dock.close() }
        return app
    }

    private func start(_ app: EngineDockMenuApplication) -> NotificationCenter {
        let workspace = NotificationCenter()
        app.startLifecycle(workspace: workspace, local: NotificationCenter(), lockEvents: NotificationCenter(),
            displayIDs: { [1] }, onConsole: { true }, displaysAsleep: { _ in false })
        return workspace
    }

    private func select(_ title: String, in menu: NSMenu) throws {
        let item = try XCTUnwrap(menu.items.first { $0.title == title })
        XCTAssertTrue(item.isEnabled, title)
        _ = try XCTUnwrap(item.target as? NSObject).perform(try XCTUnwrap(item.action), with: item)
    }

    private func expanded(_ app: EngineDockMenuApplication) throws -> DockEdgePlacement {
        let value = try XCTUnwrap(app.composition.dock.edgePresentation)
        XCTAssertEqual(value.state, .expanded)
        return try XCTUnwrap(value.placement)
    }

    private func wait(_ predicate: @escaping @MainActor () -> Bool, seconds: Double = 2) async throws {
        let end = ContinuousClock.now + .seconds(seconds)
        while !predicate() && ContinuousClock.now < end { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(predicate(), "Expected presentation did not arrive within the bound")
    }

    func testD01FreshProfileShowsEmptyStationBeforeRows() async throws {
        let topology = Topology()
        let app = try await make(profile(), topology: topology)
        let replies = RowsReplyProbe()
        let observation = app.composition.store.attach(replies)
        defer { app.composition.store.detach(observation) }
        let launched = ContinuousClock.now
        _ = start(app)
        try await wait { app.composition.dock.edgePresentation?.state == .expanded }
        XCTAssertLessThan(ContinuousClock.now - launched, .seconds(2))
        XCTAssertEqual(replies.count, 0)
        let place = try expanded(app)
        XCTAssertEqual(place.displayID, "A")
        XCTAssertEqual(place.edge, .right)
        XCTAssertEqual(place.sliverFrame.midY, topology.primary.visibleFrame.midY, accuracy: 0.5)
        XCTAssertNil(app.composition.store.snapshot.rows)
        let skin = try XCTUnwrap(app.composition.dock.dockView.presentedSkinForChecks)
        XCTAssertTrue(skin.stations.contains { $0.placeholderLabel != nil && $0.subscriptionID == nil })
    }

    private func showDockRow(_ app: EngineDockMenuApplication) throws -> SettingsRowValue? {
        let editor = app.settingsHost.application.editor
        let snapshot = try XCTUnwrap(editor.snapshot)
        return try SettingsCatalogue.rows(preferences: snapshot.preferences, context: editor.context, paneID: "dock")
            .first { $0.key == .showDock }?.value
    }

    /// G3-17 (a) / D-01: no settings document exists; the first launch creates one with the
    /// Quota Widget switch on, shows the widget, and offers Show from the status menu.
    func testG317TrulyFreshProfileEnablesAndShowsTheWidget() async throws {
        let topology = Topology(), root = profile()
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path), "Precondition: no profile at all")
        let app = try await make(root, topology: topology)
        _ = start(app)
        try await wait { app.composition.dock.edgePresentation?.state == .expanded }
        let editor = app.settingsHost.application.editor
        XCTAssertEqual(editor.snapshot?.preferences.showDock, true)
        XCTAssertEqual(try showDockRow(app), .toggle(true), "Settings shows the Quota Widget switch on")
        let status = await app.foundationStore.foundationStatus()
        let document = try XCTUnwrap(status?.path)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: document)) as? [String: Any])
        XCTAssertEqual((object["settings"] as? [String: Any])?["showDock"] as? Bool, true, "The created document saves the switch on")
        XCTAssertEqual(try XCTUnwrap(app.liveStatusMenu?.items.first { $0.title == "Show Quota Widget" }).isEnabled, true)
        XCTAssertNotNil(app.composition.dock.edgePresentation?.paintedFrame)
    }

    /// G3-17 (c) / D-01: first run with every optional reader declined still shows the widget,
    /// before and after Done, and leaves the switch on.
    func testG317FirstRunWithAllReadersDeclinedShowsTheWidget() async throws {
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let fixture = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
        let topology = Topology(), surface = LifecycleFirstRunProbe()
        let app = try await make(profile(), topology: topology, rows: fixture,
                                 beforePrepare: { $0.makeFirstRunSurfaceWithConsent = { _, _ in surface } })
        _ = start(app)
        try await wait({ surface.shows > 0 }, seconds: 5)
        try await wait { app.composition.dock.edgePresentation?.state == .expanded }
        let editor = app.settingsHost.application.editor
        let before = try XCTUnwrap(editor.snapshot)
        XCTAssertFalse(before.preferences.onboarding.completed)
        var declined = OnboardingOptions(preferences: before.preferences)
        declined.readerConsent = ReaderConsent()
        _ = try await editor.completeFirstRun(options: declined, action: .done, host: .popup, expectedRevision: before.revision)
        try await waitForSettings(editor) { editor.snapshot?.preferences.onboarding.completed == true && !editor.isSaving }
        try await wait { app.composition.dock.edgePresentation?.state == .expanded }
        XCTAssertEqual(editor.snapshot?.preferences.showDock, true)
        XCTAssertEqual(try showDockRow(app), .toggle(true))
        let saved = await app.foundationStore.snapshot()
        XCTAssertTrue(saved.preferences.showDock)
        XCTAssertEqual(saved.preferences.readerConsent, ReaderConsent())
    }

    /// G3-17/G3-18 (b) / D-14, from a truly empty profile. Once first run is done and the
    /// widget is concealed, the Help host offers "Find it again from the menu" and saves its
    /// hint ledger through the shared store, outside the Settings editor. Show Quota Widget
    /// chosen before the editor reloads must still show the widget and turn the switch on:
    /// in session (Hide, then menu Show) and after a relaunch with the widget hidden.
    /// At abd90787 the request compared the editor's stale revision with the store, reloaded
    /// and returned .changed, so showDock stayed false ("did nothing", switch off).
    func testG318HideThenMenuShowFromFreshProfileSurvivesHintLedgerWrites() async throws {
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let fixture = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
        let topology = Topology(), root = profile(), surface = LifecycleFirstRunProbe()
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path), "Precondition: no profile at all")
        let app = try await make(root, topology: topology, rows: fixture,
                                 beforePrepare: { $0.makeFirstRunSurfaceWithConsent = { _, _ in surface } })
        _ = start(app)
        try await wait({ surface.shows > 0 }, seconds: 5)
        let editor = app.settingsHost.application.editor
        let fresh = try XCTUnwrap(editor.snapshot)
        XCTAssertTrue(fresh.preferences.showDock)
        _ = try await editor.completeFirstRun(options: .init(preferences: fresh.preferences), action: .done,
                                              host: .popup, expectedRevision: fresh.revision)
        try await waitForSettings(editor) { editor.snapshot?.preferences.onboarding.completed == true && !editor.isSaving }
        try await wait { app.composition.dock.edgePresentation?.state == .expanded }

        func ledgerWrite(_ application: EngineDockMenuApplication, _ hints: FirstUseHintPreferences) async throws {
            let current = await application.foundationStore.snapshot()
            let saved = try await application.foundationStore.saveHints(hints, expectedRevision: current.revision)
            XCTAssertNotEqual(application.settingsHost.application.editor.snapshot?.revision, saved.revision,
                              "Precondition: the editor has not reloaded the ledger write")
        }
        func showFromMenu(_ application: EngineDockMenuApplication, hints: FirstUseHintPreferences) async throws {
            let editor = application.settingsHost.application.editor
            try select("Show Quota Widget", in: XCTUnwrap(application.liveStatusMenu))
            try await waitForSettings(editor) { editor.snapshot?.preferences.showDock == true && !editor.isSaving }
            try await wait { application.composition.dock.edgePresentation?.state == .expanded }
            XCTAssertEqual(try showDockRow(application), .toggle(true), "Show turns the Settings switch on")
            let saved = await application.foundationStore.snapshot()
            XCTAssertTrue(saved.preferences.showDock)
            XCTAssertEqual(saved.preferences.helpHints, hints, "The ledger write is kept")
            XCTAssertFalse(application.liveStatusMenu?.items.contains { $0.title == "Settings changed. Choose Show Quota Widget again." } ?? true)
        }

        // In session: Hide from the widget menu, the hint ledger saves, then menu Show.
        try await ledgerWrite(app, .init(seen: [.ringRefresh]))
        try select("Hide Quota Widget", in: app.composition.dock.menu())
        try await waitForSettings(editor) { editor.snapshot?.preferences.showDock == false && !editor.isSaving }
        XCTAssertEqual(try showDockRow(app), .toggle(false))
        try await ledgerWrite(app, .init(seen: [.ringRefresh, .findWidget]))
        try await showFromMenu(app, hints: .init(seen: [.ringRefresh, .findWidget]))

        // Relaunch hidden: the saved Hide is kept, then the same ledger write and menu Show.
        try select("Hide Quota Widget", in: app.composition.dock.menu())
        try await waitForSettings(editor) { editor.snapshot?.preferences.showDock == false && !editor.isSaving }
        await app.stopLifecycle(); app.composition.dock.close()
        let relaunched = try await make(root, topology: topology, rows: fixture)
        _ = start(relaunched)
        let reopened = relaunched.settingsHost.application.editor
        XCTAssertEqual(reopened.snapshot?.preferences.showDock, false)
        XCTAssertEqual(reopened.snapshot?.preferences.onboarding.completed, true)
        XCTAssertNil(relaunched.composition.dock.edgePresentation?.paintedFrame)
        try await ledgerWrite(relaunched, .init(seen: [.ringRefresh, .findWidget], reveals: 1))
        try await showFromMenu(relaunched, hints: .init(seen: [.ringRefresh, .findWidget], reveals: 1))
    }

    func testD02RightEdgeSurvivesNeighbourDockMoveAndRelaunch() async throws {
        let topology = Topology(); topology.joined = true
        let root = profile()
        let first = try await make(root, topology: topology) { $0.dockDisplayID = "A"; $0.dockEdge = .right }
        first.allowDockPresentation()
        XCTAssertEqual(try expanded(first).edge, .right)
        first.composition.dock.close()
        let app = try await make(root, topology: topology)
        app.allowDockPresentation()
        let original = topology.primary
        let dockLeft = DockDisplayArea(id: "A", frame: original.frame,
            visibleFrame: CGRect(x: 70, y: 0, width: 1442, height: 945))
        for (display, joined) in [(original, true), (dockLeft, true), (original, true), (original, false), (original, true)] {
            topology.primary = display; topology.joined = joined
            NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
            let place = try expanded(app)
            XCTAssertEqual(place.edge, .right)
            XCTAssertEqual(place.displayID, "A")
            XCTAssertEqual(place.frame.maxX, display.visibleFrame.maxX, accuracy: 0.5)
            XCTAssertEqual(app.settingsHost.application.editor.snapshot?.preferences.dockEdge, .right)
        }
    }

    func testD02ThirtyAliasesFitRightWithReservedDockAndResize() async throws {
        try await checkThirtyAliases(native: false)
    }

    #if MODELPLAN_DOCK_NATIVE_JOURNEY
    func testD02NativeThirtyAliasesKeepVisibleRightPanel() async throws {
        _ = NSApplication.shared
        try await checkThirtyAliases(native: true)
    }
    #endif

    private func checkThirtyAliases(native: Bool) async throws {
        let root = profile()
        #if MODELPLAN_DOCK_NATIVE_JOURNEY
        if native {
            EngineRowsEntry.nativeJourneyProfile = root
            addTeardownBlock { @MainActor in EngineRowsEntry.nativeJourneyProfile = nil }
        }
        #endif
        let topology = Topology()
        topology.primary = .init(id: "A", frame: CGRect(x: 0, y: 0, width: 1470, height: 956),
            visibleFrame: CGRect(x: 0, y: 70, width: 1470, height: 860))
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(json["projection"] as? [String: Any])
        var row = try XCTUnwrap((projection["rows"] as? [[String: Any]])?.first)
        let account = try XCTUnwrap((row["accounts"] as? [[String: Any]])?.first)
        let ids = (0..<30).map { String(format: "%016x", $0 + 1) }
        row["surfaces"] = ["dock", "menu"]
        row["expiresAt"] = "2099-01-01T00:00:00Z"
        row["accounts"] = ids.map { id in
            var member = account
            member["subscriptionRef"] = id
            return member
        }
        projection["rows"] = [row]
        json["projection"] = projection
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
        let app = try await make(root, topology: topology, rows: rows, native: native) {
            $0.dockEdge = .right
            $0.size = .medium
            for (index, id) in ids.enumerated() { $0.subscriptionSettings[id] = .init(alias: "Alias \(index)") }
        }
        _ = start(app)
        try await wait { !app.lifecyclePaused }
        for available in [CGRect(x: 0, y: 70, width: 1470, height: 860),
                          CGRect(x: 70, y: 0, width: 1400, height: 930),
                          CGRect(x: 0, y: 70, width: 1280, height: 704)] {
            topology.primary = .init(id: "A", frame: CGRect(x: 0, y: 0, width: available.maxX, height: available.maxY + 26),
                visibleFrame: available)
            NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
            let place = try expanded(app)
            XCTAssertEqual(place.edge, .right)
            XCTAssertTrue(available.contains(place.frame))
            XCTAssertFalse(app.composition.dock.dockView.interactionOverflowIDs.isEmpty)
            if native {
                let panel = try XCTUnwrap(app.composition.dock.nativePanel)
                XCTAssertTrue(panel.isVisible)
                XCTAssertEqual(panel.frame.maxX, available.maxX, accuracy: 1)
                XCTAssertGreaterThanOrEqual(panel.frame.minY, available.minY + 23)
            }
        }
    }

    func testD03BottomUsesVisibleFloorAndStableTopologyDoesNotJump() async throws {
        let topology = Topology()
        let app = try await make(profile(), topology: topology) { $0.dockEdge = .bottom }
        app.allowDockPresentation()
        let place = try expanded(app)
        XCTAssertEqual(place.edge, .bottom)
        XCTAssertEqual(place.frame.minY, topology.primary.visibleFrame.minY, accuracy: 0.5)
        let original = topology.primary
        for floor in [4.0, 70.0] {
            topology.primary = DockDisplayArea(id: "A", frame: original.frame,
                visibleFrame: CGRect(x: 0, y: floor, width: 1512, height: 945 - floor))
            NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
            let changed = try expanded(app)
            XCTAssertEqual(changed.edge, .bottom)
            XCTAssertEqual(changed.frame.minY, floor, accuracy: 0.5)
            XCTAssertEqual(changed.alongFraction, place.alongFraction, accuracy: 0.001)
        }
    }

    func testD12FullscreenResizeAndWakeKeepSavedPlace() async throws {
        let topology = Topology()
        let app = try await make(profile(), topology: topology) {
            $0.dockDisplayID = "A"; $0.dockEdge = .bottom; $0.dockAlongFraction = 0.62
        }
        let workspace = start(app)
        app.allowDockPresentation()
        let before = try expanded(app)
        XCTAssertEqual(app.composition.dock.dockView.layer?.contentsScale, 2)
        topology.fullscreen = true; app.composition.dock.refreshPresence()
        XCTAssertNil(app.composition.dock.edgePresentation?.paintedFrame)
        topology.fullscreen = false; app.composition.dock.refreshPresence()
        XCTAssertEqual(try expanded(app).frame, before.frame)
        topology.primary = DockDisplayArea(id: "A", frame: CGRect(x: 0, y: 0, width: 1280, height: 800),
            visibleFrame: CGRect(x: 0, y: 70, width: 1280, height: 693))
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let resized = try expanded(app)
        XCTAssertEqual(app.composition.dock.dockView.layer?.contentsScale, 1)
        XCTAssertEqual(resized.edge, .bottom)
        XCTAssertEqual(resized.alongFraction, 0.62, accuracy: 0.001)
        XCTAssertNotEqual(resized.frame.size, before.frame.size)
        workspace.post(name: NSWorkspace.willSleepNotification, object: nil)
        XCTAssertNil(app.composition.dock.edgePresentation?.paintedFrame)
        workspace.post(name: NSWorkspace.didWakeNotification, object: nil)
        XCTAssertEqual(try expanded(app).frame, resized.frame)
        XCTAssertNil(app.composition.store.snapshot.rows)
    }

    func testD14ShowRestoresHiddenExpandsStripAndHighlightsExpanded() async throws {
        let topology = Topology(), root = profile()
        let initial = try await make(root, topology: topology) { $0.motion = .on }
        initial.allowDockPresentation()
        let saved = try expanded(initial).frame
        try select("Hide Quota Widget", in: initial.composition.dock.menu())
        try await waitForSettings(initial.settingsHost.application.editor) { initial.settingsHost.application.editor.snapshot?.preferences.showDock == false }
        initial.composition.dock.close()
        let app = try await make(root, topology: topology)
        _ = start(app)
        let editor = app.settingsHost.application.editor
        XCTAssertEqual(editor.snapshot?.preferences.showDock, false)
        XCTAssertNil(app.composition.dock.edgePresentation?.paintedFrame)
        func show(_ application: EngineDockMenuApplication) throws {
            try select("Show Quota Widget", in: XCTUnwrap(application.liveStatusMenu))
        }
        func highlight(_ application: EngineDockMenuApplication) -> CALayer? {
            application.composition.dock.dockView.layer?.sublayers?.first { $0.name == "dock.locate-highlight" }
        }
        try show(app)
        try await wait { highlight(app) != nil }
        XCTAssertEqual(try expanded(app).frame, saved)
        XCTAssertEqual(app.settingsHost.application.editor.snapshot?.preferences.showDock, true)
        let first = try XCTUnwrap(highlight(app))
        XCTAssertTrue(first.animationKeys()?.isEmpty ?? true)
        try show(app)
        try await wait { highlight(app) != nil && highlight(app) !== first }
        XCTAssertEqual(try expanded(app).frame, saved)
        for shown in [false, true] {
            _ = try await editor.commit(SettingsB21Edit.showDock(shown))
            let snapshot = await editor.store.snapshot()
            XCTAssertEqual(snapshot.preferences.showDock, shown)
            let rows = try SettingsCatalogue.rows(preferences: snapshot.preferences, context: editor.context, paneID: "dock")
            XCTAssertEqual(rows.first { $0.key == .showDock }?.value, .toggle(shown))
            XCTAssertEqual(app.composition.dock.edgePresentation?.paintedFrame != nil, shown)
            let menu = try XCTUnwrap(app.liveStatusMenu)
            XCTAssertEqual(menu.items.first { $0.title == "Show Quota Widget" }?.isEnabled, true)
        }

        let strip = try await make(profile(), topology: topology) { $0.autoHide = true; $0.motion = .on }
        _ = start(strip)
        XCTAssertEqual(strip.composition.dock.edgePresentation?.state, .sliver)
        try show(strip)
        try await wait { highlight(strip) != nil }
        XCTAssertEqual(strip.composition.dock.edgePresentation?.state, .expanded)
        XCTAssertTrue(try XCTUnwrap(highlight(strip)).animationKeys()?.isEmpty ?? true)
        try await wait({ strip.composition.dock.edgePresentation?.state == .sliver }, seconds: 4)
        XCTAssertEqual(strip.settingsHost.application.editor.snapshot?.preferences.autoHide, true)
        XCTAssertNil(strip.composition.store.snapshot.rows)
    }

    func testD14ShowQueuesWhileSystemOrCockpitBlocks() async throws {
        let topology = Topology()
        let app = try await make(profile(), topology: topology) {
            $0.showDock = false
            $0.autoHide = true
            $0.motion = .on
        }
        let workspace = start(app)
        let editor = app.settingsHost.application.editor
        func exercise(block: () -> Void, unblock: () -> Void) async throws {
            block()
            try select("Show Quota Widget", in: XCTUnwrap(app.liveStatusMenu))
            try await waitForSettings(editor) { editor.snapshot?.preferences.showDock == true && !editor.isSaving }
            let saved = await editor.store.snapshot()
            XCTAssertTrue(saved.preferences.showDock)
            XCTAssertNil(app.composition.dock.edgePresentation?.paintedFrame)
            unblock()
            try await wait {
                app.composition.dock.edgePresentation?.state == .expanded &&
                app.composition.dock.dockView.layer?.sublayers?.contains { $0.name == "dock.locate-highlight" } == true
            }
            XCTAssertNotNil(app.composition.dock.dockView.emptyStationRectForChecks)
            XCTAssertNil(app.composition.store.snapshot.rows)
            _ = try await editor.commit(SettingsB21Edit.showDock(false))
        }
        try await exercise(block: { workspace.post(name: NSWorkspace.willSleepNotification, object: nil) },
                           unblock: { workspace.post(name: NSWorkspace.didWakeNotification, object: nil) })
        try await exercise(block: { workspace.post(name: NSWorkspace.sessionDidResignActiveNotification, object: nil) },
                           unblock: { workspace.post(name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil) })
        try await exercise(block: { topology.cockpitClosed = false; app.composition.dock.refreshPresence() },
                           unblock: { topology.cockpitClosed = true; app.composition.dock.refreshPresence() })
    }

    func testDockWaitsForTheCockpitOpenAttemptAndRestoresAfterFailure() async throws {
        let root = profile()
        let app = try await make(root, topology: Topology()) { $0.theme = .night }
        _ = start(app)
        let saved = try expanded(app).frame
        let owner = CockpitConsoleOwner(bundle: root, settingsStore: app.settingsHost.application.editor.store)
        owner.coordinator = EngineCockpitCoordinator { _ in throw CockpitBridgeError.unavailable }
        let console = SharedEngineCockpitConsole(owner: owner, composition: app.composition,
            isForeground: { false }, activate: {})
        defer { console.hide() }
        console.show()
        XCTAssertNil(app.composition.dock.edgePresentation?.paintedFrame, "Opening the cockpit blocks presentation immediately")
        console.hide()
        XCTAssertEqual(try expanded(app).frame, saved)
        console.show()
        XCTAssertNil(app.composition.dock.edgePresentation?.paintedFrame)
        try await wait { console.showTask == nil }
        XCTAssertEqual(try expanded(app).frame, saved, "An unavailable cockpit releases the presentation gate")
    }

    func testD17FollowSamplesPreserveSavedPlace() async throws {
        let topology = Topology()
        topology.joined = true
        let app = try await make(profile(), topology: topology) {
            $0.dockDisplayID = "A"
            $0.dockEdge = .right
            $0.dockAlongFraction = 0.62
        }
        _ = start(app)
        let editor = app.settingsHost.application.editor
        let initial = try expanded(app)
        let original = await editor.store.snapshot()
        topology.pointer = CGPoint(x: topology.neighbour.frame.midX, y: topology.neighbour.frame.midY)
        app.composition.dock.refreshPresence()
        XCTAssertEqual(try expanded(app), initial)
        let afterFixedSample = await editor.store.snapshot()
        XCTAssertEqual(afterFixedSample.revision, original.revision)
        _ = try await editor.commit(SettingsB21Edit.activeDisplay(true))
        let following = await editor.store.snapshot()
        let followed = try expanded(app)
        XCTAssertEqual(followed.displayID, "B")
        XCTAssertEqual(followed.edge, initial.edge)
        XCTAssertEqual(followed.alongFraction, initial.alongFraction, accuracy: 0.001)
        topology.pointer = CGPoint(x: topology.primary.frame.midX, y: topology.primary.frame.midY)
        app.composition.dock.refreshPresence()
        XCTAssertEqual(try expanded(app), initial)
        let afterFollow = await editor.store.snapshot()
        XCTAssertEqual(afterFollow.revision, following.revision)
        XCTAssertEqual(afterFollow.preferences.dockDisplayID, original.preferences.dockDisplayID)
        XCTAssertEqual(afterFollow.preferences.dockEdge, original.preferences.dockEdge)
        XCTAssertEqual(afterFollow.preferences.dockAlongFraction, original.preferences.dockAlongFraction)
    }
}
