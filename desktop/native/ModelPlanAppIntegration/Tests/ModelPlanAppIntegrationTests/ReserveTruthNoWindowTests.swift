// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCore
import ModelPlanDock
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
@testable import ModelPlanAppIntegration

/// Detached Store → production provider only. No application, view, window,
/// system event, real reader or process is constructed.
@MainActor final class ReserveTruthNoWindowTests: XCTestCase {
    private enum FixtureState { case fresh, retained, expired }
    private func projection(balance: Any?, unit: String, english: Bool, state: FixtureState = .fresh) async throws -> (DockDataState, DockCardRow?) {
        let captures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures")
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: captures.appendingPathComponent("WireRowsSnapshot.json"))) as? [String: Any])
        var projection = root["projection"] as! [String: Any], row = (projection["rows"] as! [[String: Any]])[0]
        var account = (row["accounts"] as! [[String: Any]])[0]
        row["id"] = "codex"; row["consent"] = "allowed"; row["surfaces"] = ["dock"]
        row["name"] = ["en": "Codex", "zh": "Codex"]; row["vendorKey"] = "openai"
        let deadline = state == .retained ? "2027-01-01T00:00:00Z" : "2027-12-01T00:00:00Z"
        let staleReason: [String: Any] = ["code": "stale_reading", "text": ["en": "A retained reading is shown", "zh": "正在显示保留的旧读数"]]
        let refresh: [String: Any] = ["action": "refresh", "text": ["en": "Refresh when permitted", "zh": "在允许时刷新"], "availableAt": NSNull(), "disabledReason": NSNull()]
        row["state"] = state == .retained ? "stale" : "fresh"
        row["reason"] = state == .retained ? staleReason : ["code": "ok", "text": ["en": "Reading available", "zh": "读数可用"]]
        if state == .retained {
            row["nextStep"] = refresh; row["expiresAt"] = NSNull(); row["stateAfterExpiry"] = NSNull()
        } else {
            row["nextStep"] = NSNull(); row["expiresAt"] = deadline
            row["stateAfterExpiry"] = ["state": "stale", "reason": staleReason, "nextStep": refresh]
        }
        account["subscriptionRef"] = "aaaaaaaaaaaaaaaa"; account["valueState"] = state == .retained ? "retained" : "current"
        account["observedAt"] = "2026-12-01T00:00:00Z"; account["freshUntil"] = deadline
        account["lastFailure"] = NSNull(); account["plan"] = ["id": "unknown", "name": NSNull()]
        var window = (account["windows"] as! [[String: Any]])[0]
        window["id"] = "session:18000:main:main"; window["role"] = "session"; window["durationSeconds"] = 18000
        window["label"] = ["en": "Session", "zh": "会话"]; window["limitKey"] = "main"; window["poolKey"] = "main"
        window.removeValue(forKey: "modelScope")
        window["current"] = state != .retained; window["observedAt"] = "2026-12-01T00:00:00Z"; window["validUntil"] = deadline
        window["resetsAt"] = deadline; window["remainingPercent"] = 42.5
        account["windows"] = [window]
        account["credits"] = ["balance": balance ?? NSNull(), "unit": unit]
        row["accounts"] = [account]; projection["rows"] = [row]; projection.removeValue(forKey: "resetEvents"); root["projection"] = projection
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
        let store = EngineStore(), source = EngineDockMenuProvider(store: store), provider = EngineDockContentProvider(source: source)
        provider.language = english ? "en" : "zh-CN"
        let context = EngineDeliveryContext(sessionID: "synthetic", floor: .init(storeEpoch: "synthetic", generation: 1), revision: 1)
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch,
            consentGeneration: 1, data: rows), delivery: context), invalidRowCount: 0))
        // The expired case holds the same valid fresh snapshot past its deadline;
        // it does not pretend the producer emitted current=true after expiry.
        let now: TimeInterval = state == .expired ? 1_830_000_000 : 1_800_000_000
        let content = provider.makeContent(.init(snapshot: nil, diagnostics: .init(), now: Date(timeIntervalSince1970: now)))
        let input = try XCTUnwrap(content.snapshot.inputs.first { $0.id == "aaaaaaaaaaaaaaaa" })
        return (input.dataState, content.snapshot.presentationRows["aaaaaaaaaaaaaaaa"]?.additionalRows.first { $0.kind == .reserve })
    }

    private func reserve(balance: Any?, unit: String, english: Bool) async throws -> DockCardRow? {
        try await projection(balance: balance, unit: unit, english: english).1
    }

    func testZeroAndFiniteBalancesRemainReportedAndNegativeIsWithheld() async throws {
        let zero = try await reserve(balance: 0, unit: "credits", english: true)
        XCTAssertEqual(zero?.value, "0.0 credits")
        let amount = try await reserve(balance: 12.5, unit: "money", english: true)
        XCTAssertEqual(amount?.value, "12.5")
        XCTAssertEqual(amount?.detail, "Currency not reported")
        let missing = try await reserve(balance: nil, unit: "credits", english: true)
        XCTAssertNil(missing)
        let negative = try await reserve(balance: -1, unit: "credits", english: true)
        XCTAssertNil(negative)
        let boundary = try await reserve(balance: 1_000_000_000_000_000.0, unit: "credits", english: true)
        XCTAssertEqual(boundary?.value, String(1_000_000_000_000_000.0) + " credits")
        let outsideBound = try await reserve(balance: 1_000_000_000_000_001.0, unit: "credits", english: true)
        XCTAssertNil(outsideBound)
    }

    func testFreshRetainedAndExpiredProjectionStatesAndReserve() async throws {
        let fresh = try await projection(balance: 12.5, unit: "credits", english: true, state: .fresh)
        XCTAssertEqual(fresh.0, .fresh); XCTAssertEqual(fresh.1?.value, "12.5 credits")
        let retained = try await projection(balance: 12.5, unit: "credits", english: true, state: .retained)
        XCTAssertEqual(retained.0, .unavailable); XCTAssertEqual(retained.1?.value, "12.5 credits")
        let expired = try await projection(balance: 12.5, unit: "credits", english: true, state: .expired)
        XCTAssertEqual(expired.0, .unavailable); XCTAssertEqual(expired.1?.value, "12.5 credits")
    }

    // Empty and unrecognized units are decoder-boundary inputs; the current
    // producer normalizes both to "other" and does not emit them directly.
    func testUnknownAndEmptyUnitAreNotMisreportedOrEchoed() async throws {
        let other = try await reserve(balance: 12.5, unit: "other", english: true)
        XCTAssertEqual(other?.value, "12.5"); XCTAssertEqual(other?.detail, "Unit unavailable")
        let otherZH = try await reserve(balance: 12.5, unit: "other", english: false)
        XCTAssertEqual(otherZH?.detail, "单位不可用")
        let empty = try await reserve(balance: 12.5, unit: "", english: true)
        XCTAssertEqual(empty?.detail, "Unit not reported")
        let emptyZH = try await reserve(balance: 12.5, unit: "", english: false)
        XCTAssertEqual(emptyZH?.detail, "未报告单位")
        let unrecognized = try await reserve(balance: 12.5, unit: "PRIVATE-UNIT-CANARY", english: true)
        XCTAssertEqual(unrecognized?.value, "12.5"); XCTAssertEqual(unrecognized?.detail, "Unit not recognized")
        XCTAssertFalse(unrecognized?.detail.contains("CANARY") ?? true)
        let unrecognizedZH = try await reserve(balance: 12.5, unit: "PRIVATE-UNIT-CANARY", english: false)
        XCTAssertEqual(unrecognizedZH?.detail, "单位未识别")
    }
}
