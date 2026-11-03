// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCore
import ModelPlanDock
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings
import ModelPlanWire
@testable import ModelPlanAppIntegration

private actor PairedSyntheticClient: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    func start() throws -> EngineDeliveryContext { throw EngineClientError.notReady }
    func retry() throws -> EngineDeliveryContext { throw EngineClientError.notReady }
    func stop() {}
    func subscribeRows(timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func consent(timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

@MainActor private final class EntryDeadlineTimer: DockEdgeScheduling {
    private(set) var action: (@MainActor () -> Void)?
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) { self.action = action }
    func cancel() { action = nil }
    func fire() { let saved = action; action = nil; saved?() }
}
private actor EntrySyntheticClient: EngineClient {
    let store: EngineStore, rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "synthetic", floor: .init(storeEpoch: "synthetic", generation: 1), revision: 1)
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        let reply = try EngineReply(envelope: .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch,
            consentGeneration: 1, data: rows), delivery: context)
        await store.consume(.rowsChanged(reply, invalidRowCount: rows.projection.invalidRowCount))
        return context
    }
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func stop() {}
    func subscribeRows(timeout: Duration?) -> EngineRequestCompletion { .init(requestID: .string("synthetic")) }
    func consent(timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

@MainActor final class HostPairedProjectionTests: XCTestCase {
    private func rows(weekly: Double, secondWeekly: Double? = nil, sequence: Int = 7, weeklyDeadline: String = "2028-12-01T00:00:00Z", resetID: String? = nil) throws -> WireRowsSnapshot {
        let captures = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json")
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: captures)) as? [String: Any])
        root["sequence"] = sequence
        var projection = try XCTUnwrap(root["projection"] as? [String: Any])
        if let resetID {
            projection["resetEvents"] = [["version": 1, "id": resetID, "provider": "synthetic",
                "rowId": "codex", "status": "announced",
                "publishedAt": "2027-05-01T00:00:00Z", "expiresAt": "2027-07-01T00:00:00Z",
                "source": ["kind": "public", "publicationId": "synthetic"]]]
        } else { projection.removeValue(forKey: "resetEvents") }
        var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
        var row = rows[0], accounts = try XCTUnwrap(row["accounts"] as? [[String: Any]])
        var account = accounts[0], windows = try XCTUnwrap(account["windows"] as? [[String: Any]])
        var session = windows[0]
        row["consent"] = "allowed"; row["state"] = "fresh"; row["surfaces"] = ["dock"]
        row["expiresAt"] = "2027-01-01T00:00:00Z"
        row["stateAfterExpiry"] = ["state": "stale",
            "reason": ["code": "stale_reading", "text": ["en": "Last known", "zh": "旧读数"]],
            "nextStep": NSNull()]
        account["subscriptionRef"] = "aaaaaaaaaaaaaaaa"; account["valueState"] = "current"
        account["observedAt"] = "2026-12-01T00:00:00Z"; account["freshUntil"] = weeklyDeadline
        account["lastFailure"] = NSNull()
        session["id"] = "session:18000:main:main"; session["role"] = "session"
        session["durationSeconds"] = 18000; session["limitKey"] = "main"; session["poolKey"] = "main"
        session.removeValue(forKey: "modelScope"); session["current"] = true
        session["observedAt"] = "2026-12-01T00:00:00Z"
        session["validUntil"] = "2027-01-01T00:00:00Z"; session["resetsAt"] = "2027-01-01T00:00:00Z"
        var week = session
        week["id"] = "weekly:604800:main:main"; week["role"] = "weekly"; week["durationSeconds"] = 604800
        week["remainingPercent"] = weekly; week["validUntil"] = weeklyDeadline
        week["resetsAt"] = weeklyDeadline
        windows = [session, week]; account["windows"] = windows; accounts = [account]
        if let secondWeekly {
            var other = account, otherWeek = week
            other["subscriptionRef"] = "bbbbbbbbbbbbbbbb"; other["accountLocator"] = "bbbbbbbbbbbbbbbb"
            otherWeek["remainingPercent"] = secondWeekly
            other["windows"] = [session, otherWeek]; accounts.append(other)
        }
        row["accounts"] = accounts; rows = [row]; projection["rows"] = rows; root["projection"] = projection
        return try JSONDecoder().decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
    }

    func testAcceptedPairKeepsWeeklyAndFencesReplacementEvenWithSameSequence() async throws {
        let store = EngineStore(), source = EngineDockMenuProvider(store: store)
        let provider = EngineDockContentProvider(source: source), client = PairedSyntheticClient()
        let paired = HostPairedProjection(store: store, source: source, provider: provider, client: client)
        let context = EngineDeliveryContext(sessionID: "synthetic", floor: .init(storeEpoch: "synthetic", generation: 1), revision: 1)
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        func deliver(_ snapshot: WireRowsSnapshot) async throws {
            let reply = try EngineReply(envelope: .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch,
                consentGeneration: 1, data: snapshot), delivery: context)
            await store.consume(.rowsChanged(reply, invalidRowCount: snapshot.projection.invalidRowCount))
        }
        try await deliver(rows(weekly: 75))
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-06-01T00:00:00Z"))
        let first = try paired.make(.init(snapshot: nil, diagnostics: .init(), now: now))
        let input = try XCTUnwrap(first.value.snapshot.inputs.first)
        let reading = try DockInstrumentProjection.evaluate(input, now: now)
        XCTAssertEqual(reading.dataState, .stale); XCTAssertEqual(reading.remainingPercent, 75)
        XCTAssertTrue(paired.isCurrent(first.sourceToken))
        try await deliver(rows(weekly: 33))
        XCTAssertFalse(paired.isCurrent(first.sourceToken), "same sequence cannot hide different admitted bytes")
        paired.invalidate()
        let second = try paired.make(.init(snapshot: nil, diagnostics: .init(), now: now))
        XCTAssertEqual(try DockInstrumentProjection.evaluate(XCTUnwrap(second.value.snapshot.inputs.first), now: now).remainingPercent, 33)
        await store.consume(.clearPrivateViews(.init(revision: 2, reason: .generationAdvanced, previous: context, nextFloor: nil)))
        XCTAssertFalse(paired.isCurrent(second.sourceToken))
    }
    func testNormalEntryReprojectsAtVerifiedDeadlineWithoutNewRowsAndClearsOnRevoke() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("paired-entry-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        var wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-06-01T00:00:00Z")), elapsed = 0.0
        let timer = EntryDeadlineTimer(), snapshot = try rows(weekly: 75)
        var acceptedStore: EngineStore?
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: false,
            deadlineNow: { wall }, deadlineElapsed: { elapsed }, deadlineScheduling: timer,
            makeClient: { _, store in acceptedStore = store; return EntrySyntheticClient(store: store, rows: snapshot) },
            activateSettings: {})
        await app.prepare()
        await app.composition.start()
        let id = "aaaaaaaaaaaaaaaa"
        let initial = try XCTUnwrap(app.composition.dock.cardContent(for: id, at: wall))
        XCTAssertEqual(initial.rows.first(where: { $0.id == "quota:weekly:604800:main:main" })?.value, "75%")
        XCTAssertNotNil(timer.action)
        wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2028-12-01T00:00:00Z"))
        elapsed = 50_000_000; timer.fire()
        let expired = try XCTUnwrap(app.composition.dock.cardContent(for: id, at: wall))
        XCTAssertEqual(expired.rows.first(where: { $0.id == "quota:weekly:604800:main:main" })?.value, "--")
        let store = try XCTUnwrap(acceptedStore)
        let context = EngineDeliveryContext(sessionID: "synthetic", floor: .init(storeEpoch: "synthetic", generation: 1), revision: 1)
        await store.consume(.clearPrivateViews(.init(revision: 2, reason: .generationAdvanced, previous: context, nextFloor: nil)))
        XCTAssertNil(try app.composition.dock.cardContent(for: id, at: wall))
        await app.composition.stop()
    }

    func testNormalEntryPreservesTwoStableAccountsAndClearsBothOnRevocation() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("paired-multi-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        var wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-06-01T00:00:00Z")), elapsed = 0.0
        let timer = EntryDeadlineTimer(), snapshot = try rows(weekly: 75, secondWeekly: 33)
        var acceptedStore: EngineStore?
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: false,
            deadlineNow: { wall }, deadlineElapsed: { elapsed }, deadlineScheduling: timer,
            makeClient: { _, store in acceptedStore = store; return EntrySyntheticClient(store: store, rows: snapshot) },
            activateSettings: {})
        await app.prepare(); await app.composition.start()
        for (id, value) in [("aaaaaaaaaaaaaaaa", "75%"), ("bbbbbbbbbbbbbbbb", "33%")] {
            let card = try XCTUnwrap(app.composition.dock.cardContent(for: id, at: wall))
            XCTAssertEqual(card.rows.first(where: { $0.id == "quota:weekly:604800:main:main" })?.value, value)
        }
        let store = try XCTUnwrap(acceptedStore)
        let context = EngineDeliveryContext(sessionID: "synthetic", floor: .init(storeEpoch: "synthetic", generation: 1), revision: 1)
        func replace(_ snapshot: WireRowsSnapshot) async throws {
            let reply = try EngineReply(envelope: .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch,
                consentGeneration: 1, data: snapshot), delivery: context)
            await store.consume(.rowsChanged(reply, invalidRowCount: snapshot.projection.invalidRowCount))
        }
        try await replace(rows(weekly: 66, secondWeekly: 22, sequence: 8))
        for (id, value) in [("aaaaaaaaaaaaaaaa", "66%"), ("bbbbbbbbbbbbbbbb", "22%")] {
            let card = try XCTUnwrap(app.composition.dock.cardContent(for: id, at: wall))
            XCTAssertEqual(card.rows.first(where: { $0.id == "quota:weekly:604800:main:main" })?.value, value)
        }
        XCTAssertNotNil(timer.action)
        wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2028-12-01T00:00:00Z"))
        elapsed = 50_000_000; timer.fire()
        for id in ["aaaaaaaaaaaaaaaa", "bbbbbbbbbbbbbbbb"] {
            let card = try XCTUnwrap(app.composition.dock.cardContent(for: id, at: wall))
            XCTAssertEqual(card.rows.first(where: { $0.id == "quota:weekly:604800:main:main" })?.value, "--")
        }
        try await replace(rows(weekly: 55, secondWeekly: 11, sequence: 9, weeklyDeadline: "2029-12-01T00:00:00Z"))
        for (id, value) in [("aaaaaaaaaaaaaaaa", "55%"), ("bbbbbbbbbbbbbbbb", "11%")] {
            let card = try XCTUnwrap(app.composition.dock.cardContent(for: id, at: wall))
            XCTAssertEqual(card.rows.first(where: { $0.id == "quota:weekly:604800:main:main" })?.value, value)
        }
        await store.consume(.clearPrivateViews(.init(revision: 2, reason: .generationAdvanced, previous: context, nextFloor: nil)))
        XCTAssertNil(try app.composition.dock.cardContent(for: "aaaaaaaaaaaaaaaa", at: wall))
        XCTAssertNil(try app.composition.dock.cardContent(for: "bbbbbbbbbbbbbbbb", at: wall))
        await app.composition.stop()
    }

    func testResetOnlyReplacementWithSameSequenceFencesPriorPair() async throws {
        let store = EngineStore(), source = EngineDockMenuProvider(store: store)
        let provider = EngineDockContentProvider(source: source), client = PairedSyntheticClient()
        let paired = HostPairedProjection(store: store, source: source, provider: provider, client: client)
        let context = EngineDeliveryContext(sessionID: "synthetic", floor: .init(storeEpoch: "synthetic", generation: 1), revision: 1)
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        func deliver(_ snapshot: WireRowsSnapshot) async throws {
            let reply = try EngineReply(envelope: .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch,
                consentGeneration: 1, data: snapshot), delivery: context)
            await store.consume(.rowsChanged(reply, invalidRowCount: snapshot.projection.invalidRowCount))
        }
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-06-01T00:00:00Z"))
        try await deliver(rows(weekly: 75, resetID: "reset-one"))
        let first = try paired.make(.init(snapshot: nil, diagnostics: .init(), now: now))
        XCTAssertEqual(first.value.signals.first?.reset?.id, "reset-one")
        try await deliver(rows(weekly: 75, resetID: "reset-two"))
        XCTAssertFalse(paired.isCurrent(first.sourceToken), "reset event bytes belong to the same delivery as rows")
        paired.invalidate()
        let second = try paired.make(.init(snapshot: nil, diagnostics: .init(), now: now))
        XCTAssertEqual(second.value.signals.first?.reset?.id, "reset-two")
    }

}
