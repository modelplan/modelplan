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
    private func reserve(balance: Any?, unit: String, english: Bool) async throws -> DockCardRow? {
        let captures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures")
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: captures.appendingPathComponent("WireRowsSnapshot.json"))) as? [String: Any])
        var projection = root["projection"] as! [String: Any], row = (projection["rows"] as! [[String: Any]])[0]
        var account = (row["accounts"] as! [[String: Any]])[0]
        row["id"] = "codex"; row["state"] = "fresh"; row["consent"] = "allowed"; row["surfaces"] = ["dock"]
        row["expiresAt"] = "2099-01-01T00:00:00Z"
        account["subscriptionRef"] = "aaaaaaaaaaaaaaaa"; account["valueState"] = "current"
        account["credits"] = ["balance": balance ?? NSNull(), "unit": unit]
        row["accounts"] = [account]; projection["rows"] = [row]; projection.removeValue(forKey: "resetEvents"); root["projection"] = projection
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
        let store = EngineStore(), source = EngineDockMenuProvider(store: store), provider = EngineDockContentProvider(source: source)
        provider.language = english ? "en" : "zh-CN"
        let context = EngineDeliveryContext(sessionID: "synthetic", floor: .init(storeEpoch: "synthetic", generation: 1), revision: 1)
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch,
            consentGeneration: 1, data: rows), delivery: context), invalidRowCount: 0))
        let content = provider.makeContent(.init(snapshot: nil, diagnostics: .init(), now: Date(timeIntervalSince1970: 1_800_000_000)))
        return content.snapshot.presentationRows["aaaaaaaaaaaaaaaa"]?.additionalRows.first { $0.kind == .reserve }
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
        let outsideBound = try await reserve(balance: 1_000_000_000_000_001.0, unit: "credits", english: true)
        XCTAssertNil(outsideBound)
    }

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
