// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
import ModelPlanCore
import ModelPlanShell
@testable import ModelPlanAppIntegration

/// Counts starts and stops; a start either publishes rows or fails like a missing or incompatible helper.
private actor CountingEngine: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore, rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "review-1124", floor: .init(storeEpoch: "review-1124", generation: 1), revision: 1)
    private var starts = 0, stops = 0
    private let fails: Bool
    init(store: EngineStore, rows: WireRowsSnapshot, fails: Bool) { self.store = store; self.rows = rows; self.fails = fails }
    func counts() -> (starts: Int, stops: Int) { (starts, stops) }
    func start() async throws -> EngineDeliveryContext {
        starts += 1
        if fails { throw EngineClientError.protocolViolation }
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch,
            consentGeneration: 1, data: rows), delivery: context), invalidRowCount: 0))
        return context
    }
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func stop() async { stops += 1 }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("review-rows")) }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

@MainActor private final class ReviewNoWindowSurface: SettingsWindowSurface {
    func prepare() async {}
    func show(paneID: String?) {}
    func hide() {}
}

/// v1 full review 11-24: #4 (the early engine start ran before the OS pause gate) and #10 (a failed engine start
/// disabled Settings while the OS gate was open).
@MainActor final class Review1124LaunchGateTests: XCTestCase {
    private var engine: CountingEngine?
    private func makeEntry(_ name: String, fails: Bool = false, settingsSurface: SettingsWindowSurface? = nil) async throws -> EngineDockMenuApplication {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(name + "-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let settings = try await completedOnboarding(expandedWidgetSettingsStore(applicationSupport: root, preferredLanguages: ["en"]))
        let rows = try HostPairedProjectionTests.rows(weekly: 75)
        let wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-02T00:00:00Z"))
        let surface = settingsSurface ?? ReviewNoWindowSurface()
        var made: CountingEngine?
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: false,
            cockpitEntryEnabled: true, dockEnvironment: normalEntryTestEnvironment, deadlineNow: { wall },
            makeClient: { _, store in let engine = CountingEngine(store: store, rows: rows, fails: fails); made = engine; return engine },
            makeSettingsSurface: { _ in surface }, activateSettings: {})
        engine = try XCTUnwrap(made)
        app.makeFirstRunSurface = { _ in ReviewNoWindowSurface() }
        app.makeFirstRunSurfaceWithConsent = { _, _ in ReviewNoWindowSurface() }
        // The pause notifications of the early window go to private centres, never the real session.
        app.earlyPauseWorkspace = NotificationCenter(); app.earlyPauseLockEvents = NotificationCenter(); app.earlyPauseLocal = NotificationCenter()
        app.earlyPauseSeed = { [] }; app.earlyDisplayIDs = { [1] }
        addTeardownBlock { @MainActor in await app.stopLifecycle(); await app.composition.stop() }
        return app
    }
    private func counts() async throws -> (starts: Int, stops: Int) { try await XCTUnwrap(engine).counts() }
    private func settle() async throws { for _ in 0..<5 { await Task.yield() }; try await Task.sleep(for: .milliseconds(50)) }

    /// #4: a completed profile launched during a locked screen (or an inactive session, asleep displays) starts no helper
    /// before the lifecycle, and the lifecycle's own lock seed keeps it stopped until the unlock.
    func testACompletedProfileLaunchStartsNoEngineWhileTheOSGateIsClosed() async throws {
        let app = try await makeEntry("review-1124-closed-launch")
        app.earlyPauseSeed = { [.sessionInactive] }
        await app.startEngineAlongsidePreparation()
        await app.prepare(); try await settle()
        let observed1 = try await counts().starts
        XCTAssertEqual(observed1, 0, "no early start while the OS gate is closed")
        let locks = NotificationCenter()
        app.startLifecycle(workspace: NotificationCenter(), local: NotificationCenter(), lockEvents: locks, displayIDs: { [1] },
                           onConsole: { true }, displaysAsleep: { _ in false }, screenLocked: { true })
        try await settle()
        let observed2 = try await counts().starts
        XCTAssertEqual(observed2, 0, "the seeded lock keeps the engine stopped")
        XCTAssertTrue(app.lifecyclePaused)
        locks.post(name: Notification.Name("com.apple.screenIsUnlocked"), object: nil)
        for _ in 0..<500 where app.lifecyclePaused { try await Task.sleep(for: .milliseconds(10)) }
        let observed3 = try await counts().starts
        XCTAssertEqual(observed3, 1, "the unlock is the first start")
        XCTAssertFalse(app.lifecyclePaused)
    }

    /// #4: a pause that arrives while preparation is still running stops the early session before the lifecycle exists.
    func testAPauseDuringPreparationStopsTheEarlyEngine() async throws {
        let app = try await makeEntry("review-1124-pause-in-prep")
        app.earlyPauseSeed = { [] }
        await app.startEngineAlongsidePreparation(); try await settle()
        let observed4 = try await counts().starts
        XCTAssertEqual(observed4, 1, "an open gate keeps the WP-17 early start")
        app.earlyPauseWorkspace.post(name: NSWorkspace.screensDidSleepNotification, object: nil)
        await app.finishEarlyStartWindow()
        let observed5 = try await counts().stops
        XCTAssertEqual(observed5, 1, "the pause stops the early session before the lifecycle starts")
    }

    /// #10: with the OS gate open and an engine that cannot start, Settings, About and diagnostics stay reachable; no
    /// private row is shown, and an OS pause still closes Settings.
    func testSettingsOpenWhenTheEngineCannotStartAndTheOSGateIsOpen() async throws {
        let surface = TestSettingsSurface()
        let app = try await makeEntry("review-1124-failed-engine", fails: true, settingsSurface: surface)
        await app.prepare()
        let locks = NotificationCenter()
        app.startLifecycle(workspace: NotificationCenter(), local: NotificationCenter(), lockEvents: locks, displayIDs: { [1] },
                           onConsole: { true }, displaysAsleep: { _ in false })
        for _ in 0..<200 { if try await counts().starts > 0 { break }; try await Task.sleep(for: .milliseconds(10)) }
        try await settle()
        XCTAssertTrue(app.lifecyclePaused, "the engine never became ready")
        XCTAssertTrue(app.settingsAvailable, "Cmd-, and the tray item stay enabled")
        await app.settingsHost.present(origin: .userInitiated)
        XCTAssertEqual(surface.shown.count, 1, "Settings opens on a failed engine start")
        XCTAssertTrue(app.composition.provider.dockContent.dockRows.allSatisfy { $0.accounts.isEmpty }, "no private rows")
        let hidden = surface.hidden
        app.perform(NSSelectorFromString("refreshRows")); try await settle()
        XCTAssertEqual(surface.hidden, hidden, "a retry with the OS gate open does not close Settings")
        locks.post(name: Notification.Name("com.apple.screenIsLocked"), object: nil); try await settle()
        XCTAssertFalse(app.settingsAvailable, "an OS pause gates Settings again")
        XCTAssertGreaterThan(surface.hidden, hidden, "and closes it")
    }

    /// macrevb-1215-1: no private Window Server property. An unknown lock state is open (the app never stays paused on a
    /// guess); a lock edge seen during preparation stops the early helper and seeds the lifecycle, which then starts the
    /// helper only on the unlock.
    func testALockDuringPreparationIsTrackedFromTheDocumentedEdgesAndUnknownIsOpen() async throws {
        XCTAssertTrue(SystemEvents.pauseReasons(displayIDs: [1], onConsole: true, screenLocked: nil).isEmpty, "unknown lock = open")
        XCTAssertFalse(SystemEvents.pauseReasonsNow().contains(.screenLocked), "no lock query: the live seed never reports a lock")
        let app = try await makeEntry("review-1124-lock-edge")
        await app.startEngineAlongsidePreparation(); try await settle()
        let started = try await counts()
        XCTAssertEqual(started.starts, 1, "an unknown lock does not hold the early start")
        app.earlyPauseLockEvents.post(name: SystemEvents.screenLockedNotification, object: nil); try await settle()
        let locked = try await counts()
        XCTAssertEqual(locked.stops, 1, "the lock edge stops the early helper")
        XCTAssertTrue(app.earlyOSPaused)
        await app.prepare(); await app.finishEarlyStartWindow()
        let locks = NotificationCenter()
        app.startLifecycle(workspace: NotificationCenter(), local: NotificationCenter(), lockEvents: locks, displayIDs: { [1] },
                           onConsole: { true }, displaysAsleep: { _ in false })
        try await settle()
        let seeded = try await counts()
        XCTAssertEqual(seeded.starts, 1, "the tracked lock seeds the lifecycle: zero starts before the unlock")
        XCTAssertTrue(app.lifecyclePaused)
        XCTAssertFalse(app.settingsAvailable)
        locks.post(name: SystemEvents.screenUnlockedNotification, object: nil)
        for _ in 0..<500 where app.lifecyclePaused { try await Task.sleep(for: .milliseconds(10)) }
        let unlocked = try await counts()
        XCTAssertEqual(unlocked.starts, 2, "the unlock is the one start after the lock")
        XCTAssertFalse(app.lifecyclePaused)
    }

    /// macrevb-1215-2: the screen-parameter change that reports the last display gone during preparation stops the
    /// early helper before preparation finishes, the same `.noDisplay` reason the lifecycle uses.
    func testLosingTheLastDisplayDuringPreparationStopsTheEarlyEngine() async throws {
        let app = try await makeEntry("review-1124-no-display")
        await app.startEngineAlongsidePreparation(); try await settle()
        let started = try await counts()
        XCTAssertEqual(started.starts, 1)
        var displays: Set<UInt32> = [1]
        app.earlyDisplayIDs = { displays }
        displays = []
        app.earlyPauseLocal.post(name: NSApplication.didChangeScreenParametersNotification, object: nil); try await settle()
        let stopped = try await counts()
        XCTAssertEqual(stopped.stops, 1, "losing the last display stops the early helper before preparation ends")
        XCTAssertEqual(app.earlyPauseReasons, [.noDisplay])
        XCTAssertFalse(app.settingsAvailable, "and gates Settings")
        displays = [2]
        app.earlyPauseLocal.post(name: NSApplication.didChangeScreenParametersNotification, object: nil); try await settle()
        XCTAssertTrue(app.earlyPauseReasons.isEmpty, "a display coming back reopens the early gate")
        let after = try await counts()
        XCTAssertEqual(after.starts, 1, "the early window never restarts the helper; the lifecycle does")
    }

    /// macrevb-1215-3: before the lifecycle exists, an OS pause retires an in-flight Settings request, refuses new ones and
    /// closes an open Settings window; the gate reopening never opens Settings by itself.
    func testAnEarlyOSPauseGatesSettingsIncludingRequestsInFlight() async throws {
        let surface = TestSettingsSurface()
        let app = try await makeEntry("review-1124-early-settings", settingsSurface: surface)
        await app.startEngineAlongsidePreparation(); await app.prepare(); try await settle()
        XCTAssertTrue(app.settingsAvailable, "the open OS gate admits Settings before the lifecycle")
        let lockCentre = app.earlyPauseLockEvents
        surface.preparation = {
            lockCentre.post(name: SystemEvents.screenLockedNotification, object: nil)
            for _ in 0..<5 { await Task.yield() }; try? await Task.sleep(for: .milliseconds(50))
        }
        await app.settingsHost.present(origin: .userInitiated)
        XCTAssertEqual(surface.shown.count, 0, "a request in flight when the gate closes never presents")
        XCTAssertFalse(app.settingsAvailable, "Command-comma and the tray item are disabled")
        surface.preparation = nil
        await app.settingsHost.present(origin: .userInitiated)
        XCTAssertEqual(surface.shown.count, 0, "a new request is refused while paused")
        app.earlyPauseLockEvents.post(name: SystemEvents.screenUnlockedNotification, object: nil); try await settle()
        XCTAssertTrue(app.settingsAvailable)
        XCTAssertEqual(surface.shown.count, 0, "reopening the gate does not open Settings")
        await app.settingsHost.present(origin: .userInitiated)
        XCTAssertEqual(surface.shown.count, 1)
        let hidden = surface.hidden
        app.earlyPauseWorkspace.post(name: NSWorkspace.screensDidSleepNotification, object: nil); try await settle()
        XCTAssertFalse(app.settingsAvailable)
        XCTAssertGreaterThan(surface.hidden, hidden, "an open Settings window is closed by the early pause")
    }
}
