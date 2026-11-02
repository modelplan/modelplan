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

@MainActor final class NormalEntryActivityTests: XCTestCase {
    private let first = "aaaaaaaaaaaaaaaa", second = "bbbbbbbbbbbbbbbb"
    private func fixture(phase: String?, sequence: Int, recordAt: Date = Date(), mismatched: Bool = false, tool: String = "codex") throws -> WireRowsSnapshot {
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
        account["subscriptionRef"] = first; account["valueState"] = "current"; account["freshUntil"] = "2099-01-01T00:00:00Z"
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
        row["accounts"] = [account, peer]; projection["rows"] = [row]; projection.removeValue(forKey: "resetEvents")
        root["projection"] = projection; root["sequence"] = sequence
        return try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
    }
    private func entry(_ rows: WireRowsSnapshot, root: URL, systemReduceMotion: @escaping () -> Bool = { false }) throws -> EngineDockMenuApplication {
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/not-launched"), applicationVersion: "activity-test", allowedEnvironment: [:]),
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"]), createsNativePanels: false,
            makeClient: { _, store in ActivityJourneyEngine(store: store, rows: rows) }, activateSettings: {})
        // Keep the production batch-013 frame source; inject only the OS motion preference.
        app.composition.dock.installWorkingEffectsForChecks(pool: EffectResourcePool(), provider: try T2FlameFrameProvider.bundled(), systemReduceMotion: systemReduceMotion)
        return app
    }
    private func wait(_ condition: @escaping @MainActor () -> Bool) async throws {
        for _ in 0..<200 { if condition() { return }; try await Task.sleep(for: .milliseconds(20)) }
        XCTFail("Normal entry did not reach the expected activity state within 4 seconds")
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
        try await wait { rotations == [self.first:1] }
        XCTAssertLessThan(started.duration(to: clock.now), .seconds(5))
        XCTAssertLessThan(Date().timeIntervalSince(turnStarted),5)
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
        try await engine.publish(fixture(phase: "model", sequence: 6, recordAt: Date().addingTimeInterval(-88)))
        try await wait { rotations == [self.first:1] }
        // No further rows arrive. The UI must retire the expired signal on its own.
        try await wait { host.activeWorkingEffectIDs.isEmpty }
        XCTAssertTrue(rotations.isEmpty)
        try await engine.publish(fixture(phase: "tool", sequence: 7))
        try await wait { rotations == [self.first:1] }
        try await app.foundationStore.update { $0.motion = .on }
        await app.prepare()
        app.updateSystemAccessibility(.init())
        XCTAssertTrue(rotations.isEmpty)
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
        try await wait { rotations == [self.first:1] }
        workspace.post(name: NSWorkspace.willSleepNotification, object: nil)
        XCTAssertTrue(app.lifecyclePaused); XCTAssertTrue(app.composition.dock.activeWorkingEffectIDs.isEmpty)
        workspace.post(name: NSWorkspace.didWakeNotification, object: nil)
        try await wait { !app.lifecyclePaused }
        try await wait { rotations == [self.first:1] }
        locks.post(name: Notification.Name("com.apple.screenIsLocked"), object: nil)
        XCTAssertTrue(app.lifecyclePaused); XCTAssertTrue(app.composition.dock.activeWorkingEffectIDs.isEmpty)
        await app.stopLifecycle(); await app.composition.stop()
    }
    func testClaudeAndZCodeActivityUseVerifiedMembersAndSystemReduceMotion() async throws {
        _ = NSApplication.shared
        for tool in ["claude","zai"] {
            let root=FileManager.default.temporaryDirectory.appendingPathComponent("activity-"+tool+"-"+UUID().uuidString)
            defer { try? FileManager.default.removeItem(at:root) }
            var osReduced=false
            let app=try entry(fixture(phase:"tool",sequence:1,tool:tool),root:root,systemReduceMotion:{osReduced})
            try await app.foundationStore.update { $0.autoHide=false }
            let host=app.composition.dock
            var rotations:[String:Double]=[:]
            host.workingEffectsDidConfigureForChecks = { [weak host] in rotations=host?.workingEffectRotationPeriodsForChecks ?? [:] }
            await app.prepare(); app.updateSystemAccessibility(.init())
            await app.composition.start(); app.allowDockPresentation()
            host.refreshDockContent()
            XCTAssertEqual(rotations,[first:1],tool)
            osReduced=true;host.refreshDockContent()
            XCTAssertTrue(rotations.isEmpty,tool)
            XCTAssertTrue(host.animatingWorkingEffectIDs.isEmpty,tool)
            XCTAssertEqual(host.activeWorkingEffectIDs,[first],"Reduce Motion holds the approved frame static")
            osReduced=false;host.refreshDockContent()
            XCTAssertEqual(rotations,[first:1],tool)
            let engine=try XCTUnwrap(app.composition.client as? ActivityJourneyEngine)
            try await engine.publish(fixture(phase:nil,sequence:2,tool:tool))
            XCTAssertTrue(host.activeWorkingEffectIDs.isEmpty,tool)
            await app.composition.stop()
        }
    }
}
