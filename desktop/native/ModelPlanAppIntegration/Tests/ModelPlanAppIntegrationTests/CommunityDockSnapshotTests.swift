// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCore
import ModelPlanDock
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class CommunityDockSnapshotTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func instant(_ offset: TimeInterval) -> String {
        ISO8601DateFormatter().string(from: now.addingTimeInterval(offset))
    }
    private func window(_ kind: String = "five_hour", remaining: Double = 75) -> [String: Any] {
        ["kind": kind, "remainingPercent": remaining, "observedAt": instant(-5),
         "resetsAt": instant(900), "windowMinutes": 300]
    }
    private func account(_ id: String?, source: String = "tool", verified: Bool = true,
                         windows: [[String: Any]]) -> [String: Any] {
        var result: [String: Any] = ["source": source, "plan": "Plan", "observedAt": instant(-5), "windows": windows]
        if let id { result["subscription"] = ["subscriptionRef": id, "status": verified ? "verified" : "unknown"] }
        return result
    }
    private func snapshot(accounts: [[String: Any]], memberships: [String] = [],
                          generated: TimeInterval = -10, valid: TimeInterval = 300,
                          extras: [String: Any] = [:]) throws -> JoinedSnapshot {
        var object: [String: Any] = ["schemaVersion": 1, "kind": "modelplan.personal-snapshot",
            "generatedAt": instant(generated), "validUntil": instant(valid), "accounts": accounts,
            "subscriptions": memberships.map { ["subscriptionRef": $0, "sources": ["tool"]] }]
        for (key, value) in extras { object[key] = value }
        let personal = try FeedDecoder.personal(JSONSerialization.data(withJSONObject: object))
        var ledger = ExpiryLedger()
        return .make(personal: personal,
            presentation: PersonalProjection.evaluate(personal, now: now, ledger: &ledger), publication: nil)
    }
    private func adapt(_ snapshot: JoinedSnapshot?, diagnostics: StoreDiagnostics? = nil) -> CommunityDockSnapshot {
        var ready = StoreDiagnostics(); ready.personal = nil
        return CommunityDockSnapshot(snapshot: snapshot, diagnostics: diagnostics ?? ready, now: now)
    }
    func testNoFeedNeverCreatesDemoOrPublicSubscriptions() {
        let result = adapt(nil)
        XCTAssertTrue(result.inputs.isEmpty); XCTAssertTrue(result.subscriptions.isEmpty)
        XCTAssertEqual(result.unavailableReason, "personal-not-loaded")
    }
    func testMembershipUsesOnlyRealExplicitRefsAndUnverifiedQuotaCannotBecomeReading() throws {
        let joined = try snapshot(accounts: [
            account("bound", windows: [window()]),
            account(nil, source: "unowned", windows: [window(remaining: 1)]),
            account("uncertain", verified: false, windows: [window(remaining: 2)]),
        ], memberships: ["member-only", "bound", "bound"])
        let result = adapt(joined)
        XCTAssertEqual(result.inputs.map(\.id), ["member-only", "bound", "uncertain"])
        XCTAssertEqual(result.subscriptions.map(\.id), result.inputs.map(\.id))
        XCTAssertTrue(result.inputs[0].windows.isEmpty)
        XCTAssertEqual(result.inputs[0].dataState, .unavailable)
        XCTAssertEqual(try DockInstrumentProjection.evaluate(result.inputs[1], now: now).remainingPercent, 75)
        XCTAssertTrue(result.inputs[2].windows.isEmpty)
        XCTAssertEqual(try DockInstrumentProjection.evaluate(result.inputs[2], now: now).readout, "--")
        XCTAssertFalse(result.inputs.contains { $0.id == "unowned" })
    }
    func testQuotaRowsStayWithTheirOwnerAcrossDifferentAccountsAndPeriods() throws {
        let result = adapt(try snapshot(accounts: [
            account("one", source: "first", windows: [window(remaining: 82)]),
            account("two", source: "second", windows: [window(remaining: 14), window("weekly", remaining: 50)]),
            account("one", source: "third", windows: [window("weekly", remaining: 67)]),
        ]))
        XCTAssertEqual(result.inputs.map(\.id), ["one", "two"])
        let first = try DockInstrumentProjection.evaluate(result.inputs[0], now: now)
        let second = try DockInstrumentProjection.evaluate(result.inputs[1], now: now)
        XCTAssertEqual(first.remainingPercent, 67); XCTAssertEqual(second.remainingPercent, 14)
        XCTAssertEqual(result.inputs[0].windows.map(\.remainingPercent), [82, 67])
        XCTAssertEqual(result.inputs[1].windows.map(\.remainingPercent), [14, 50])
    }
    func testExpiredFutureOrFailedReadRetainsMembershipWithoutActionableQuota() throws {
        for joined in [try snapshot(accounts: [account("real", windows: [window()])], valid: -1),
                       try snapshot(accounts: [account("real", windows: [window()])], generated: 10)] {
            let result = adapt(joined), reading = try DockInstrumentProjection.evaluate(result.inputs[0], now: now)
            XCTAssertEqual(reading.subscriptionID, "real"); XCTAssertEqual(reading.readout, "--")
            XCTAssertNil(reading.timeLeftFraction); XCTAssertNotNil(result.unavailableReason)
        }
        var failed = StoreDiagnostics(); failed.personal = "personal-read-unavailable"
        let result = adapt(try snapshot(accounts: [account("real", windows: [window()])]), diagnostics: failed)
        XCTAssertEqual(try DockInstrumentProjection.evaluate(result.inputs[0], now: now).readout, "--")
        XCTAssertEqual(result.unavailableReason, "personal-read-unavailable")
    }
    func testStaleFutureOrUnknownWindowCannotLeakTimeWhenAnotherWindowIsFresh() throws {
        var old = window("weekly", remaining: 3); old["resetsAt"] = instant(-1)
        var future = window("monthly", remaining: 4); future["observedAt"] = instant(10)
        var unknown = window("daily", remaining: 5); unknown["unknownReason"] = "not-reported"
        let result = adapt(try snapshot(accounts: [account("real", windows: [window(), old, future, unknown])]))
        XCTAssertEqual(result.inputs[0].dataState, .fresh)
        for bad in result.inputs[0].windows.dropFirst() {
            XCTAssertNil(bad.remainingPercent); XCTAssertNil(bad.resetsAt); XCTAssertNil(bad.durationSeconds)
            var pinned = result.inputs[0]; pinned.selectedWindowID = bad.id
            let reading = try DockInstrumentProjection.evaluate(pinned, now: now)
            XCTAssertEqual(reading.readout, "--"); XCTAssertNil(reading.timeLeftFraction)
        }
    }
    func testPeriodNameAndRelativeResetDoNotInventDurationOrResetInstant() throws {
        var missing = window(); missing.removeValue(forKey: "windowMinutes"); missing.removeValue(forKey: "resetsAt")
        missing["resetsInMinutes"] = 15; missing["elapsedPercent"] = 50
        let result = adapt(try snapshot(accounts: [account("real", windows: [missing])]))
        let reading = try DockInstrumentProjection.evaluate(result.inputs[0], now: now)
        XCTAssertEqual(result.inputs[0].windows[0].period, .fiveHour)
        XCTAssertNil(result.inputs[0].windows[0].durationSeconds)
        XCTAssertNil(reading.selectedResetAt); XCTAssertNil(reading.timeLeftFraction)
        XCTAssertEqual(reading.readout, "75%")
    }
    func testRunningSessionDoesNotFabricateObservedOutputOrWorkingJet() throws {
        let joined = try snapshot(accounts: [account("real", windows: [window()])], extras: [
            "liveSessions": [["ref": "session", "source": "tool", "subscriptionRef": "real",
                "status": "running", "lastAt": instant(-1)]],
        ])
        XCTAssertTrue(joined.presentation.live[0].working)
        let input = adapt(joined).inputs[0], reading = try DockInstrumentProjection.evaluate(input, now: now)
        XCTAssertNil(input.working); XCTAssertFalse(reading.isWorking); XCTAssertFalse(reading.jetEligible)
    }
    func testRepeatedKindsKeepDistinctReportedRowsAndNeverMixTheirValues() throws {
        let result = adapt(try snapshot(accounts: [account("real", windows: [window(remaining: 60), window(remaining: 20)])]))
        XCTAssertEqual(Set(result.inputs[0].windows.map(\.id)).count, 2)
        XCTAssertEqual(result.inputs[0].windows.map(\.remainingPercent), [60, 20])
        XCTAssertEqual(try DockInstrumentProjection.evaluate(result.inputs[0], now: now).remainingPercent, 20)
    }
    func testAdapterFeedsTheExistingOneStorePreferencesAndThresholdProjection() async throws {
        let result = adapt(try snapshot(accounts: [account("real", windows: [window(remaining: 19), window("weekly", remaining: 80)])]))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("dock-adapter-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var context = SettingsPageContext(); context.subscriptions = result.subscriptions
        let coordinator = SettingsApplicationCoordinator(store: try SettingsStore(url: directory.appendingPathComponent("settings.json")),
            context: context) { _ in }
        await coordinator.reload()
        try await coordinator.commit(.percentageMode(.used))
        try await coordinator.commit(.redBelow(20))
        try await coordinator.commit(.percentagePin("real", .fiveHour))
        let application = try XCTUnwrap(coordinator.latest)
        let reading = try application.dockReading(for: result.inputs[0], at: now)
        XCTAssertEqual(reading.readout, "81%"); XCTAssertEqual(reading.status, .critical)
        XCTAssertEqual(reading.selectedWindowID, result.inputs[0].windows[0].id)
        XCTAssertEqual(application.context.subscriptions.map(\.id), ["real"])
    }
    func testHostUsesSameSettingsOrderAndRetiresViewWithoutCreatingWindows() async throws {
        let joined = try snapshot(accounts: [account("a", windows: [window()]), account("b", windows: [window()])])
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("dock-host-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try SettingsStore(url: directory.appendingPathComponent("settings.json"))
        let host = StaticDockPreviewHost(currentDate: { self.now })
        var observed: [[String]] = []
        host.catalogueChanged = { observed.append($0.map(\.id)) }
        var ready = StoreDiagnostics(); ready.personal = nil
        host.render(snapshot: joined, diagnostics: ready)
        XCTAssertNil(host.dockView.window)
        XCTAssertEqual(host.dockView.accessibilityChildren()?.count, 2)
        var context = SettingsPageContext(); context.subscriptions = adapt(joined).subscriptions
        let coordinator = SettingsApplicationCoordinator(store: store, context: context) { host.apply($0) }
        await coordinator.reload()
        let original = try XCTUnwrap(coordinator.latest)
        _ = try await coordinator.editor.commit(.visible("a", false))
        XCTAssertEqual(host.dockView.accessibilityChildren()?.count, 1)
        host.apply(original)
        XCTAssertEqual(host.dockView.accessibilityChildren()?.count, 1, "old settings cannot restore a hidden row")
        XCTAssertEqual(observed, [["a", "b"]])
        host.close(); host.render(snapshot: joined, diagnostics: ready)
        XCTAssertEqual(host.dockView.accessibilityChildren()?.count, 0)
        XCTAssertNil(host.dockView.window)
    }
    func testExactKnownVendorSourceDoesNotGuessUnknownOrMixedIdentity() throws {
        XCTAssertEqual(adapt(try snapshot(accounts: [account("a", source: "codex", windows: [])])).inputs[0].vendorResourceKey, "openai")
        XCTAssertNil(adapt(try snapshot(accounts: [account("a", source: "my-tool", windows: [])])).inputs[0].vendorResourceKey)
        XCTAssertNil(adapt(try snapshot(accounts: [account("a", source: "codex", windows: []), account("a", source: "claude", windows: [])])).inputs[0].vendorResourceKey)
    }

}
