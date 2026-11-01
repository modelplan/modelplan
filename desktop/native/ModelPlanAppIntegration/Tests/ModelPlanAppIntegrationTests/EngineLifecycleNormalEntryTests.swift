// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
import ModelPlanEngineStore
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanAppIntegration

private actor LifecycleEngine: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore
    let rows: WireRowsSnapshot
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
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
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
