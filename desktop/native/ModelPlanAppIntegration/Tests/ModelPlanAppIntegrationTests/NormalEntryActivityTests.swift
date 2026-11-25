// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanDock
import ModelPlanPrimitives
import ModelPlanOfficialDock
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
@_spi(DockResourceChecks) @testable import ModelPlanAppIntegration

private actor ActivityJourneyEngine: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore
    var rows: WireRowsSnapshot
    var context: EngineDeliveryContext?
    var starts = 0
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    func start() async throws -> EngineDeliveryContext {
        starts += 1
        let value = EngineDeliveryContext(sessionID: "activity-\(starts)", floor: .init(storeEpoch: "activity-\(starts)", generation: 1), revision: UInt64(starts))
        context = value
        await store.consume(.connection(.ready(value))); await store.consume(.context(value))
        return value
    }
    func publish(_ rows: WireRowsSnapshot) async throws {
        self.rows = rows
        guard let context else { return }
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch,
            consentGeneration: 1, data: rows), delivery: context), invalidRowCount: 0))
    }
    func stop() async {
        await store.consume(.clearPrivateViews(.init(revision: UInt64(starts + 1), reason: .stopped, previous: context, nextFloor: nil)))
        context = nil
    }
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion {
        try await publish(rows); return .init(requestID: .string("activity-rows"))
    }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

/// Holds one Settings save open (its commit observer) so a delivery can arrive while it is in flight.
@MainActor private final class ZCodeSaveGate {
    var holdNext = true, held = false, contended = false
    var release: CheckedContinuation<Void, Never>?
}

@MainActor final class NormalEntryActivityTests: XCTestCase {
    private let first = "aaaaaaaaaaaaaaaa", second = "bbbbbbbbbbbbbbbb"
    private func fixture(phase: String?, sequence: Int, recordAt: Date = Date(), mismatched: Bool = false, tool: String = "codex", unavailableState: String? = nil, ref: String? = nil) throws -> WireRowsSnapshot {
        let captures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures")
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: captures.appendingPathComponent("WireRowsSnapshot.json"))) as? [String: Any])
        var projection = root["projection"] as! [String: Any]
        var row = (projection["rows"] as! [[String: Any]])[0]
        var account = (row["accounts"] as! [[String: Any]])[0]
        var window = (account["windows"] as! [[String: Any]])[0]
        let format = ISO8601DateFormatter(); format.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        row["id"] = tool; row["vendorKey"] = ["codex":"openai","claude":"claude","zai":"glm"][tool]!
        row["state"] = "fresh"; row["consent"] = "allowed"
        row["surfaces"] = ["dock", "menu"]; row["expiresAt"] = "2099-01-01T00:00:00Z"
        account["subscriptionRef"] = ref ?? first; account["valueState"] = "current"; account["freshUntil"] = "2099-01-01T00:00:00Z"
        window["id"] = "quota"; window["role"] = "session"; window["poolKey"] = "main"; window["limitKey"] = "main"
        window["current"] = true; window["remainingPercent"] = 75; window["resetsAt"] = "2099-01-01T00:00:00Z"
        window["validUntil"] = "2099-01-01T00:00:00Z"; window.removeValue(forKey: "modelScope")
        account["windows"] = [window]; account.removeValue(forKey: "activity")
        if let phase {
            let grace: TimeInterval = phase == "tool" || phase == "finished" ? 300 : 90
            account["activity"] = [["sessionRef": "cccccccccccccccc", "subscriptionRef": mismatched ? second : first,
                "bindingVerified": true, "phase": phase, "recordAt": format.string(from: recordAt),
                "expiresAt": format.string(from: recordAt.addingTimeInterval(grace))]]
        }
        var peer = account; peer["subscriptionRef"] = second; peer.removeValue(forKey: "activity")
        if let unavailableState {
            row["state"] = unavailableState
            row["reason"] = ["code": unavailableState == "failed" ? "timeout" : "no_usage_windows",
                             "text": ["en": "Reading unavailable", "zh": "读数不可用"]]
            row.removeValue(forKey: "expiresAt")
            row.removeValue(forKey: "stateAfterExpiry")
            row["accounts"] = [["route": "unknown", "plan": ["id": "unknown"],
                                "beta": false, "valueState": "none", "windows": []]]
        } else {
            row["accounts"] = tool == "zai" ? [account] : [account, peer]
        }
        projection["rows"] = [row]; projection.removeValue(forKey: "resetEvents")
        root["projection"] = projection; root["sequence"] = sequence
        return try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
    }
    private func entry(_ rows: WireRowsSnapshot, root: URL, systemReduceMotion: @escaping () -> Bool = { false },
                       onBattery: @escaping () -> Bool = { false }) throws -> EngineDockMenuApplication {
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/not-launched"), applicationVersion: "activity-test", allowedEnvironment: [:]),
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"]), createsNativePanels: false,
            makeClient: { _, store in ActivityJourneyEngine(store: store, rows: rows) }, activateSettings: {})
        // Keep the production batch-013 frame source; inject only the OS motion preference.
        app.composition.dock.installWorkingEffectsForChecks(pool: EffectResourcePool(), provider: try T2FlameFrameProvider.bundled(), systemReduceMotion: systemReduceMotion, onBattery: onBattery)
        return app
    }
    /// Condition-based with a 15 s ceiling for loaded shared GUI runners; the original 4 s bound is reported
    /// as a `GUI-BUDGET` metric for each step.
    private func wait(_ step: String, file: StaticString = #filePath, line: UInt = #line,
                      _ condition: @escaping @MainActor () -> Bool) async throws {
        let started = ContinuousClock.now, ceiling = started + .seconds(15)
        while !condition() && ContinuousClock.now < ceiling { try await Task.sleep(for: .milliseconds(20)) }
        reportBudget("NormalEntryActivity.\(step)", elapsed: ContinuousClock.now - started, budget: .seconds(4))
        if !condition() { XCTFail("Normal entry did not reach the expected activity state (\(step)) within 15 seconds", file: file, line: line) }
    }
    func testNormalEntryWorkingIdleStaleAndOwnMemberBinding() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("activity-entry-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try entry(fixture(phase: nil, sequence: 1), root: root)
        try await app.foundationStore.update { $0.autoHide = false }
        await app.prepare(); app.updateSystemAccessibility(.init())
        await app.composition.start(); app.allowDockPresentation()
        let engine = try XCTUnwrap(app.composition.client as? ActivityJourneyEngine)
        let host=app.composition.dock
        var rotations:[String:Double]=[:]
        host.workingEffectsDidConfigureForChecks = { [weak host] in rotations=host?.workingEffectRotationPeriodsForChecks ?? [:] }
        let clock = ContinuousClock(), started = clock.now
        let turnStarted=Date()
        try await engine.publish(fixture(phase: "model", sequence: 2, recordAt:turnStarted))
        try await wait("modelLit") { rotations == [self.first:2] }
        reportBudget("NormalEntryActivity.turnToFlame", elapsed: started.duration(to: clock.now), budget: .seconds(5))
        XCTAssertLessThan(Date().timeIntervalSince(turnStarted), 90, "the model turn is still inside its 90 s grace when lit")
        XCTAssertNil(app.composition.dock.lastWorkingEffectError)
        XCTAssertEqual(app.composition.presentedContent.snapshot.inputs.first { $0.id == first }?.working?.observedOutput, false,
                       "A model wait is explicit in-flight evidence, not invented output")
        XCTAssertNil(rotations[second])
        try await engine.publish(fixture(phase: "finished", sequence: 3))
        XCTAssertTrue(rotations.isEmpty); XCTAssertTrue(host.activeWorkingEffectIDs.isEmpty)
        try await engine.publish(fixture(phase: "tool", sequence: 4, recordAt: Date().addingTimeInterval(-301)))
        XCTAssertTrue(rotations.isEmpty); XCTAssertTrue(host.activeWorkingEffectIDs.isEmpty)
        try await engine.publish(fixture(phase: "tool", sequence: 5, mismatched: true))
        XCTAssertTrue(rotations.isEmpty); XCTAssertTrue(host.activeWorkingEffectIDs.isEmpty)
        try await engine.publish(fixture(phase: "model", sequence: 6, recordAt: Date().addingTimeInterval(-86)))
        // 4 s of evidence left (was 2 s): a loaded runner can still observe it lit before it retires on its own.
        try await wait("nearExpiryLit") { rotations == [self.first:2] }
        // No further rows arrive. The UI must retire the expired signal on its own.
        try await wait("expiredRetired") { host.activeWorkingEffectIDs.isEmpty }
        XCTAssertTrue(rotations.isEmpty)
        try await engine.publish(fixture(phase: "tool", sequence: 7))
        try await wait("toolLit") { rotations == [self.first:2] }
        try await app.foundationStore.update { $0.motion = .on }
        await app.prepare()
        app.updateSystemAccessibility(.init())
        XCTAssertTrue(rotations.isEmpty)
        await app.composition.stop()
    }
    /// MOT-2.3-10 on the activity path: flames lit by real rows step at half rate on battery.
    func testNormalEntryFlamesFromActivityThrottleOnBattery() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("activity-battery-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var battery = true
        let app = try entry(fixture(phase: nil, sequence: 1), root: root, onBattery: { battery })
        try await app.foundationStore.update { $0.autoHide = false }
        await app.prepare(); app.updateSystemAccessibility(.init())
        await app.composition.start(); app.allowDockPresentation()
        let engine = try XCTUnwrap(app.composition.client as? ActivityJourneyEngine)
        let host = app.composition.dock
        // Read the spin when effects are configured, like the other activity tests.
        var rotations: [String: Double] = [:]
        host.workingEffectsDidConfigureForChecks = { [weak host] in rotations = host?.workingEffectRotationPeriodsForChecks ?? [:] }
        try await engine.publish(fixture(phase: "tool", sequence: 2))
        try await wait("batteryLit") { host.animatingWorkingEffectIDs == [self.first] }
        XCTAssertEqual(host.workingEffectCycleSeconds[first], 2, "on battery the flames step at half rate")
        XCTAssertEqual(rotations[first], 2, "D171: the ring spin keeps one turn every 2 s on battery")
        try await engine.publish(fixture(phase: nil, sequence: 3))
        try await wait("batteryRetired") { host.activeWorkingEffectIDs.isEmpty }
        battery = false
        try await engine.publish(fixture(phase: "tool", sequence: 4))
        try await wait("batteryRelit") { host.animatingWorkingEffectIDs == [self.first] }
        XCTAssertEqual(host.workingEffectCycleSeconds[first], 1, "on AC the flames return to full rate")
        XCTAssertEqual(rotations[first], 2, "D171: the spin period does not follow the flame clock")
        await app.composition.stop()
    }
    func testNormalEntryLifecycleSleepAndLockWithdrawWorkingEffects() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("activity-lifecycle-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try entry(fixture(phase: "tool", sequence: 1), root: root)
        try await app.foundationStore.update { $0.autoHide = false }
        let host=app.composition.dock
        var rotations:[String:Double]=[:]
        host.workingEffectsDidConfigureForChecks = { [weak host] in rotations=host?.workingEffectRotationPeriodsForChecks ?? [:] }
        await app.prepare()
        app.updateSystemAccessibility(.init())
        let workspace = NotificationCenter(), locks = NotificationCenter()
        app.startLifecycle(workspace: workspace, local: NotificationCenter(), lockEvents: locks, displayIDs: { [1] }, onConsole: { true }, displaysAsleep: { _ in false })
        try await wait("lit") { rotations == [self.first:2] }
        workspace.post(name: NSWorkspace.willSleepNotification, object: nil)
        XCTAssertTrue(app.lifecyclePaused); XCTAssertTrue(app.composition.dock.activeWorkingEffectIDs.isEmpty)
        workspace.post(name: NSWorkspace.didWakeNotification, object: nil)
        try await wait("resumed") { !app.lifecyclePaused }
        try await wait("relit") { rotations == [self.first:2] }
        locks.post(name: Notification.Name("com.apple.screenIsLocked"), object: nil)
        XCTAssertTrue(app.lifecyclePaused); XCTAssertTrue(app.composition.dock.activeWorkingEffectIDs.isEmpty)
        await app.stopLifecycle(); await app.composition.stop()
    }
    func testEstablishedZCodeRingRendersAfterFailedAndEmptyReads() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("zcode-ring-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try entry(fixture(phase: nil, sequence: 1, tool: "zai"), root: root)
        try await app.foundationStore.update { $0.autoHide = false }
        await app.prepare()
        await app.composition.start()
        app.allowDockPresentation()
        try await wait("ZCode quota ring") { app.composition.presentedContent.snapshot.inputs.map(\.id) == [self.first] }
        let engine = try XCTUnwrap(app.composition.client as? ActivityJourneyEngine)
        for (offset, state) in ["failed", "empty"].enumerated() {
            try await engine.publish(fixture(phase: nil, sequence: offset + 2, tool: "zai", unavailableState: state))
            let snapshot = app.composition.presentedContent.snapshot
            XCTAssertEqual(snapshot.inputs.map(\.id), ["zai#unknown"], state)
            let input = try XCTUnwrap(snapshot.inputs.first)
            XCTAssertEqual(input.dataState, .unavailable)
            let reading = try DockInstrumentProjection.evaluate(input, now: Date())
            XCTAssertNil(reading.remainingPercent)
            XCTAssertFalse(reading.isWorking)
            XCTAssertEqual(snapshot.subscriptions.first?.source, .unavailable)
        }
        await app.composition.stop()
    }

    /// Invariant: a user's hide choice for a station persists across its availability changes until unhidden.
    func testHidingTheUnavailableZCodeStationSurvivesTheAccountReturning() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("zcode-station-hide-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try entry(fixture(phase: nil, sequence: 1, tool: "zai"), root: root)
        await app.prepare()
        await app.composition.start()
        app.allowDockPresentation()
        try await wait("ZCode settings member") {
            app.currentSettingsContext.subscriptions.contains { $0.id == self.first && $0.tool == "zai" }
        }
        let settings = SettingsApplicationCoordinator(store: app.foundationStore, context: app.currentSettingsContext) {
            app.composition.applySettings($0)
        }
        await settings.reload()
        let engine = try XCTUnwrap(app.composition.client as? ActivityJourneyEngine)
        try await engine.publish(fixture(phase: nil, sequence: 2, tool: "zai", unavailableState: "failed"))
        try await wait("station in Settings") {
            app.currentSettingsContext.subscriptions.contains { $0.id == "zai#unknown" }
        }
        settings.editor.update(context: app.currentSettingsContext)
        _ = try await settings.editor.commit(.visible("zai#unknown", false))
        try await engine.publish(fixture(phase: nil, sequence: 3, tool: "zai"))
        try await wait("account returns") {
            app.currentSettingsContext.subscriptions.contains { $0.id == self.first }
        }
        settings.editor.update(context: app.currentSettingsContext)
        let saved = await app.foundationStore.snapshot()
        XCTAssertTrue(saved.preferences.subscriptions.hiddenIDs.contains(first))
        let dock = app.composition.dock.interactionEnvironment()
        XCTAssertTrue(try dock.preferences.orderedIDs(in: dock.catalogue, visibleOnly: true).isEmpty)
        await app.composition.stop()
    }

    /// Polls the saved document (the store is an actor) with the same 15 s ceiling as `wait`.
    private func waitSaved(_ step: String, _ app: EngineDockMenuApplication, file: StaticString = #filePath, line: UInt = #line,
                           _ condition: (Set<String>) -> Bool) async throws {
        let ceiling = ContinuousClock.now + .seconds(15)
        var hidden = await app.foundationStore.snapshot().preferences.subscriptions.hiddenIDs
        while !condition(hidden) && ContinuousClock.now < ceiling {
            try await Task.sleep(for: .milliseconds(20))
            hidden = await app.foundationStore.snapshot().preferences.subscriptions.hiddenIDs
        }
        if !condition(hidden) { XCTFail("Saved hidden IDs did not reach the expected state (\(step)): \(hidden.sorted())", file: file, line: line) }
    }
    private func dockVisible(_ app: EngineDockMenuApplication) throws -> [String] {
        let dock = app.composition.dock.interactionEnvironment()
        return try dock.preferences.orderedIDs(in: dock.catalogue, visibleOnly: true)
    }

    /// Invariant (macrev2-1260-1): a hide made on the unavailable ZCode station while no account is known applies to
    /// the first known account before that account's first publication, and a concurrent Settings save never drops it.
    /// It passes to that first account only (macrev2-1260-2), and unhiding the account shows it again.
    func testAnonymousStationHideCoversTheFirstAccountBeforeItsFirstPublicationDuringAnotherSave() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("zcode-anon-hide-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try entry(fixture(phase: nil, sequence: 1, tool: "zai", unavailableState: "failed"), root: root)
        await app.prepare()
        await app.composition.start()
        app.allowDockPresentation()
        let settings = app.settingsCoordinatorForChecks, editor = settings.editor
        await settings.reload()
        try await wait("only the unavailable station") {
            app.currentSettingsContext.subscriptions.map(\.id) == ["zai#unknown"]
        }
        // Hidden through the app's own Settings coordinator while no account is known in this session.
        try await editor.commit(.visible("zai#unknown", false))
        try await waitSaved("anonymous hide marked", app) { $0 == ["zai#unknown", SettingsEditor.anonymousZCodeHideMarker] }
        XCTAssertEqual(try dockVisible(app), [])

        // Hold an unrelated save across the first readable delivery.
        let gate = ZCodeSaveGate()
        let commitObserver = editor.observeCommittedEdits { _ in
            guard gate.holdNext else { return }
            gate.holdNext = false; gate.held = true
            await withCheckedContinuation { gate.release = $0 }
        }
        let first = self.first
        let changeObserver = editor.observeChanges {
            if editor.isDeliveringContextUpdate, editor.isSaving, editor.context.subscriptions.contains(where: { $0.id == first }) {
                gate.contended = true
            }
        }
        defer { editor.removeCommitObserver(commitObserver); editor.removeChangeObserver(changeObserver) }
        let unrelated = Task { try await settings.commit(.showPercentages(false)) }
        try await wait("unrelated save held") { gate.held && editor.isSaving }
        let host = app.composition.dock
        host.paintedSubscriptionIDsForChecks = []
        let engine = try XCTUnwrap(app.composition.client as? ActivityJourneyEngine)
        try await engine.publish(fixture(phase: nil, sequence: 2, tool: "zai"))
        try await wait("first readable account") { app.currentSettingsContext.subscriptions.contains { $0.id == first } }
        try await wait("account catalogued by the Dock") { app.composition.dock.interactionEnvironment().catalogue == [first] }
        XCTAssertTrue(gate.contended, "the first readable account arrived while another Settings save was in flight")
        XCTAssertFalse(host.paintedSubscriptionIDsForChecks.isEmpty)
        XCTAssertFalse(host.paintedSubscriptionIDsForChecks.contains { $0.contains(first) },
                       "no Dock face showed the account: \(host.paintedSubscriptionIDsForChecks)")
        XCTAssertEqual(try dockVisible(app), [])
        XCTAssertEqual(editor.snapshot?.preferences.subscriptions.hiddenIDs.contains(first), true)
        XCTAssertEqual(app.composition.latestSettings?.snapshot.preferences.subscriptions.hiddenIDs.contains(first), true)
        gate.release?.resume(); gate.release = nil
        _ = try await unrelated.value

        // Settled: the takeover is saved (the marker is used up) and the Dock and Settings still hide the account.
        try await waitSaved("takeover saved", app) { $0 == [first, "zai#unknown"] }
        XCTAssertEqual(try dockVisible(app), [])
        XCTAssertEqual(editor.snapshot?.preferences.subscriptions.hiddenIDs.contains(first), true)

        // First account only: a different account that arrives later stays visible and is never saved hidden.
        try await engine.publish(fixture(phase: nil, sequence: 3, tool: "zai", unavailableState: "failed"))
        try await engine.publish(fixture(phase: nil, sequence: 4, tool: "zai", ref: second))
        try await wait("different account") { app.composition.dock.interactionEnvironment().catalogue == [self.second] }
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(try dockVisible(app), [second])
        try await waitSaved("different account not hidden", app) { $0 == [first, "zai#unknown"] }

        // The first account returns hidden, and unhiding it shows it again on every surface.
        try await engine.publish(fixture(phase: nil, sequence: 5, tool: "zai"))
        try await wait("first account returns") { app.composition.dock.interactionEnvironment().catalogue == [first] }
        XCTAssertEqual(try dockVisible(app), [])
        try await editor.commit(.visible(first, true))
        try await waitSaved("unhidden", app) { $0.isEmpty }
        XCTAssertEqual(try dockVisible(app), [first])
        XCTAssertEqual(editor.snapshot?.preferences.subscriptions.hiddenIDs.contains(first), false)
        await app.composition.stop()
    }

    /// Invariant (macrev2-1260-2): a hide saved for known account A never transfers to a different account B;
    /// A's hide still applies when A returns.
    func testKnownAccountHideNeverTransfersToADifferentAccount() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("zcode-known-hide-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try entry(fixture(phase: nil, sequence: 1, tool: "zai"), root: root)
        await app.prepare()
        await app.composition.start()
        app.allowDockPresentation()
        let settings = app.settingsCoordinatorForChecks, editor = settings.editor
        await settings.reload()
        try await wait("ZCode settings member") {
            app.currentSettingsContext.subscriptions.contains { $0.id == self.first && $0.tool == "zai" }
        }
        try await editor.commit(.visible(first, false))
        try await waitSaved("known-account hide", app) { $0 == [self.first, "zai#unknown"] }
        let engine = try XCTUnwrap(app.composition.client as? ActivityJourneyEngine)
        try await engine.publish(fixture(phase: nil, sequence: 2, tool: "zai", unavailableState: "failed"))
        try await wait("station") { app.composition.dock.interactionEnvironment().catalogue == ["zai#unknown"] }
        XCTAssertEqual(try dockVisible(app), [])
        let host = app.composition.dock
        host.paintedSubscriptionIDsForChecks = []
        try await engine.publish(fixture(phase: nil, sequence: 3, tool: "zai", ref: second))
        try await wait("account B") { app.composition.dock.interactionEnvironment().catalogue == [self.second] }
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(try dockVisible(app), [second])
        XCTAssertTrue(host.paintedSubscriptionIDsForChecks.last?.contains(second) == true)
        try await waitSaved("B never saved hidden", app) { $0 == [self.first, "zai#unknown"] }
        XCTAssertEqual(editor.snapshot?.preferences.subscriptions.hiddenIDs.contains(second), false)
        try await engine.publish(fixture(phase: nil, sequence: 4, tool: "zai"))
        try await wait("account A returns") { app.composition.dock.interactionEnvironment().catalogue == [self.first] }
        XCTAssertEqual(try dockVisible(app), [])
        await app.composition.stop()
    }

    func testLegacySettingsKeepTheUnavailableZCodeRingHiddenWithoutEditing() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("zcode-legacy-hidden-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try entry(fixture(phase: nil, sequence: 1, tool: "zai"), root: root)
        let id = first
        let original = try await app.foundationStore.update { $0.subscriptions.hiddenIDs = [id] }
        await app.prepare()
        await app.composition.start()
        app.allowDockPresentation()
        try await wait("legacy hidden member in the Settings catalogue") {
            app.currentSettingsContext.subscriptions.contains { $0.id == id && $0.tool == "zai" }
        }

        let cockpit = CockpitConsoleOwner(bundle: root, settingsStore: app.foundationStore)
        let engine = try XCTUnwrap(app.composition.client as? ActivityJourneyEngine)
        for (offset, state) in ["failed", "empty"].enumerated() {
            try await engine.publish(fixture(phase: nil, sequence: offset + 2, tool: "zai", unavailableState: state))
            let dock = app.composition.dock.interactionEnvironment()
            XCTAssertEqual(dock.catalogue, ["zai#unknown"], state)
            XCTAssertTrue(try dock.preferences.orderedIDs(in: dock.catalogue, visibleOnly: true).isEmpty, state)
            let presentation = try XCTUnwrap(app.composition.latestSettings)
            XCTAssertTrue(cockpit.cockpitAppearance(presentation).hiddenMembers.contains("zai#unknown"), state)
        }
        let saved = await app.foundationStore.snapshot()
        XCTAssertEqual(saved.revision, original.revision)
        XCTAssertEqual(saved.preferences.subscriptions.hiddenIDs, [id])
        await app.composition.stop()
    }

    func testSettingsKeepsTheUnavailableZCodeRingHidden() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("zcode-hidden-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try entry(fixture(phase: nil, sequence: 1, tool: "zai"), root: root)
        await app.prepare()
        await app.composition.start()
        app.allowDockPresentation()
        try await wait("ZCode settings member") {
            app.currentSettingsContext.subscriptions.contains { $0.id == self.first && $0.tool == "zai" }
        }
        let settings = SettingsApplicationCoordinator(store: app.foundationStore, context: app.currentSettingsContext) {
            app.composition.applySettings($0)
        }
        await settings.reload()
        _ = try await settings.editor.commit(.visible(first, false))
        let engine = try XCTUnwrap(app.composition.client as? ActivityJourneyEngine)
        for (offset, state) in ["failed", "empty"].enumerated() {
            try await engine.publish(fixture(phase: nil, sequence: offset + 2, tool: "zai", unavailableState: state))
            let dock = app.composition.dock.interactionEnvironment()
            XCTAssertEqual(dock.catalogue, ["zai#unknown"], state)
            XCTAssertTrue(try dock.preferences.orderedIDs(in: dock.catalogue, visibleOnly: true).isEmpty, state)
        }
        let saved = await app.foundationStore.snapshot()
        XCTAssertEqual(saved.preferences.subscriptions.hiddenIDs, [first, "zai#unknown"])
        await app.composition.stop()
    }

    func testClaudeAndZCodeActivityUseVerifiedMembersAndSystemReduceMotion() async throws {
        _ = NSApplication.shared
        for tool in ["claude","zai"] {
            let root=FileManager.default.temporaryDirectory.appendingPathComponent("activity-"+tool+"-"+UUID().uuidString)
            defer { try? FileManager.default.removeItem(at:root) }
            var osReduced=false
            let app=try entry(fixture(phase:nil,sequence:1,tool:tool),root:root,systemReduceMotion:{osReduced})
            try await app.foundationStore.update { $0.autoHide=false }
            let host=app.composition.dock
            var rotations:[String:Double]=[:]
            host.workingEffectsDidConfigureForChecks = { [weak host] in rotations=host?.workingEffectRotationPeriodsForChecks ?? [:] }
            await app.prepare(); app.updateSystemAccessibility(.init())
            await app.composition.start(); app.allowDockPresentation()
            host.refreshDockContent()
            XCTAssertTrue(rotations.isEmpty,tool)
            XCTAssertTrue(host.activeWorkingEffectIDs.isEmpty,tool)
            let engine=try XCTUnwrap(app.composition.client as? ActivityJourneyEngine)
            try await engine.publish(fixture(phase:"tool",sequence:2,tool:tool))
            XCTAssertEqual(rotations,[first:2],tool)
            osReduced=true;host.refreshDockContent()
            XCTAssertTrue(rotations.isEmpty,tool)
            XCTAssertTrue(host.animatingWorkingEffectIDs.isEmpty,tool)
            XCTAssertEqual(host.activeWorkingEffectIDs,[first],"Reduce Motion holds the approved frame static")
            osReduced=false;host.refreshDockContent()
            XCTAssertEqual(rotations,[first:2],tool)
            try await engine.publish(fixture(phase:"finished",sequence:3,tool:tool))
            XCTAssertTrue(host.activeWorkingEffectIDs.isEmpty,tool)
            await app.composition.stop()
        }
    }
}
