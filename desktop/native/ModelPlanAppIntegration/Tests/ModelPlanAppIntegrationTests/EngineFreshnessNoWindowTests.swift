// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCore
import ModelPlanDock
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
@testable import ModelPlanAppIntegration

private actor FreshnessFakeEngine: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore
    var context: EngineDeliveryContext?
    var starts = 0
    init(store: EngineStore) { self.store = store }
    func start() async throws -> EngineDeliveryContext {
        starts += 1
        let value = EngineDeliveryContext(sessionID: "synthetic-\(starts)", floor: .init(storeEpoch: "synthetic-epoch", generation: 1), revision: UInt64(starts))
        context = value
        await store.consume(.connection(.ready(value))); await store.consume(.context(value))
        return value
    }
    func publish(_ value: WireRowsSnapshot) async throws {
        guard let context else { return }
        let envelope = try WireEnvelope(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: context.floor.generation, data: value)
        await store.consume(.rowsChanged(.init(envelope: envelope, delivery: context), invalidRowCount: 0))
    }
    func stop() async {
        await store.consume(.clearPrivateViews(.init(revision: UInt64(starts + 1), reason: .stopped, previous: context, nextFloor: nil)))
        context = nil
    }
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("synthetic")) }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

/// Exercises the production Store → Dock provider seam with synthetic events.
/// It creates no NSApplication, view, window, panel, OS event, reader or process.
@MainActor final class EngineFreshnessNoWindowTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let a = "aaaaaaaaaaaaaaaa", b = "bbbbbbbbbbbbbbbb"
    private func stamp(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }

    private func rows(sequence: Int, rowState: String = "fresh", firstState: String = "current",
                      secondState: String? = nil, deadline: Date, value: Double = 75) throws -> WireRowsSnapshot {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json")
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        var projection = root["projection"] as! [String: Any], row = (projection["rows"] as! [[String: Any]])[0]
        var account = (row["accounts"] as! [[String: Any]])[0], window = (account["windows"] as! [[String: Any]])[0]
        row["id"] = "codex"; row["state"] = rowState; row["consent"] = "allowed"; row["surfaces"] = ["dock", "menu"]
        row["expiresAt"] = stamp(deadline)
        if rowState == "stale" { row["reason"] = ["code": "stale_reading", "text": ["en": "A retained reading is shown", "zh": "正在显示保留的旧读数"]] }
        account["subscriptionRef"] = a; account["valueState"] = firstState
        account["observedAt"] = stamp(now.addingTimeInterval(-10)); account["freshUntil"] = stamp(deadline)
        window["id"] = "main"; window["role"] = "session"; window["poolKey"] = "main"; window["limitKey"] = "main"
        window["current"] = firstState == "current"; window["remainingPercent"] = value
        window["observedAt"] = stamp(now.addingTimeInterval(-10)); window["validUntil"] = stamp(deadline)
        window["resetsAt"] = stamp(now.addingTimeInterval(3600)); window.removeValue(forKey: "modelScope")
        account["windows"] = [window]
        var accounts = [account]
        if let secondState {
            var peer = account; peer["subscriptionRef"] = b; peer["valueState"] = secondState
            var peerWindow = window; peerWindow["current"] = secondState == "current"; peer["windows"] = [peerWindow]
            accounts.append(peer)
        }
        row["accounts"] = accounts; projection["rows"] = [row]; projection.removeValue(forKey: "resetEvents")
        root["projection"] = projection; root["sequence"] = sequence
        return try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
    }

    func testPerAccountFreshnessAndRecoveryAfterExpiryOrReconnect() async throws {
        let store = EngineStore(), source = EngineDockMenuProvider(store: store), provider = EngineDockContentProvider(source: source)
        let engine = FreshnessFakeEngine(store: store)
        _ = try await engine.start()
        func content(_ time: Date) -> DockContent { provider.makeContent(.init(snapshot: nil, diagnostics: .init(), now: time)) }
        func input(_ id: String, at time: Date) throws -> DockInstrumentInput { try XCTUnwrap(content(time).snapshot.inputs.first { $0.id == id }) }

        // Producer's contract: a retained peer makes the row stale, but its
        // distinct current member/window remains authoritative until its deadline.
        try await engine.publish(rows(sequence: 1, rowState: "stale", secondState: "retained", deadline: now.addingTimeInterval(60)))
        XCTAssertEqual(try input(a, at: now).dataState, .fresh)
        XCTAssertEqual(try input(a, at: now).windows.first?.remainingPercent, 75)
        XCTAssertNotEqual(try input(b, at: now).dataState, .fresh)

        // A real deadline is never promoted; a fresh replacement, even with an
        // unchanged value, must recover without an optimistic Refresh outcome.
        try await engine.publish(rows(sequence: 2, deadline: now.addingTimeInterval(60)))
        XCTAssertEqual(try input(a, at: now).dataState, .fresh)
        XCTAssertNotEqual(try input(a, at: now.addingTimeInterval(61)).dataState, .fresh)
        try await engine.publish(rows(sequence: 3, deadline: now.addingTimeInterval(180)))
        XCTAssertEqual(try input(a, at: now.addingTimeInterval(61)).dataState, .fresh)
        XCTAssertEqual(try input(a, at: now.addingTimeInterval(61)).windows.first?.remainingPercent, 75)

        // An actual retained member cannot be made fresh by its peer or by time.
        try await engine.publish(rows(sequence: 4, firstState: "retained", deadline: now.addingTimeInterval(180)))
        XCTAssertNotEqual(try input(a, at: now.addingTimeInterval(61)).dataState, .fresh)

        await engine.stop()
        XCTAssertTrue(content(now).snapshot.inputs.isEmpty)
        _ = try await engine.start()
        try await engine.publish(rows(sequence: 1, deadline: now.addingTimeInterval(180)))
        XCTAssertEqual(try input(a, at: now.addingTimeInterval(61)).dataState, .fresh)
    }
}
