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
    private enum FixtureState { case fresh, retained, retainedExpired, atExpiry, expired, refreshed, revoked, revokedWithValues }
    private func projection(balance: Any?, unit: String, english: Bool, state: FixtureState = .fresh, clearAfter: Bool = false, mixedTransition: Bool = false) async throws -> (DockInstrumentInput?, DockCardRow?) {
        let captures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures")
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: captures.appendingPathComponent("WireRowsSnapshot.json"))) as? [String: Any])
        var projection = root["projection"] as! [String: Any], row = (projection["rows"] as! [[String: Any]])[0]
        var account = (row["accounts"] as! [[String: Any]])[0]
        row["id"] = "codex"; row["consent"] = "allowed"; row["surfaces"] = ["dock"]
        row["name"] = ["en": "Codex", "zh": "Codex"]; row["vendorKey"] = "openai"
        let deadline = state == .retainedExpired ? "2027-01-01T00:00:00Z" : (state == .refreshed ? "2028-12-01T00:00:00Z" : "2027-12-01T00:00:00Z")
        let observed = state == .refreshed ? "2027-12-20T00:00:00Z" : "2026-12-01T00:00:00Z"
        let staleReason: [String: Any] = ["code": "stale_reading", "text": ["en": "A retained reading is shown", "zh": "正在显示保留的旧读数"]]
        let refresh: [String: Any] = ["action": "refresh", "text": ["en": "Refresh when permitted", "zh": "在允许时刷新"], "availableAt": NSNull(), "disabledReason": NSNull()]
        let isRetained = state == .retained || state == .retainedExpired
        let isRevoked = state == .revoked || state == .revokedWithValues
        row["state"] = isRetained ? "stale" : "fresh"
        row["reason"] = isRetained ? staleReason : ["code": "ok", "text": ["en": "Reading available", "zh": "读数可用"]]
        if isRetained {
            row["nextStep"] = refresh; row["expiresAt"] = NSNull(); row["stateAfterExpiry"] = NSNull()
        } else {
            row["nextStep"] = NSNull(); row["expiresAt"] = deadline
            row["stateAfterExpiry"] = ["state": "stale", "reason": staleReason, "nextStep": refresh]
        }
        account["subscriptionRef"] = "aaaaaaaaaaaaaaaa"; account["valueState"] = isRetained ? "retained" : "current"
        account["observedAt"] = observed; account["freshUntil"] = deadline
        account["lastFailure"] = NSNull(); account["plan"] = ["id": "unknown", "name": NSNull()]
        var window = (account["windows"] as! [[String: Any]])[0]
        window["id"] = "session:18000:main:main"; window["role"] = "session"; window["durationSeconds"] = 18000
        window["label"] = ["en": "Session", "zh": "会话"]; window["limitKey"] = "main"; window["poolKey"] = "main"
        window.removeValue(forKey: "modelScope")
        window["current"] = !isRetained; window["observedAt"] = observed; window["validUntil"] = deadline
        window["resetsAt"] = deadline; window["remainingPercent"] = 42.5
        account["windows"] = [window]
        account["credits"] = ["balance": balance ?? NSNull(), "unit": unit]
        row["accounts"] = state == .revoked ? [] : [account]
        if mixedTransition {
            var second = account
            second["subscriptionRef"] = "bbbbbbbbbbbbbbbb"; second["freshUntil"] = "2028-12-01T00:00:00Z"
            var secondWindow = window
            secondWindow["validUntil"] = "2028-12-01T00:00:00Z"; secondWindow["resetsAt"] = "2028-12-01T00:00:00Z"
            second["windows"] = [secondWindow]
            row["accounts"] = [account, second]
        }
        if isRevoked {
            row["consent"] = "denied"; row["state"] = "needs_consent"
            row["reason"] = ["code": "consent_denied", "text": ["en": "Reader consent is denied", "zh": "读取授权已拒绝"]]
            row["nextStep"] = ["action": "open_settings_consent", "text": ["en": "Review reader consent in Settings", "zh": "在设置中检查读取授权"], "availableAt": NSNull(), "disabledReason": NSNull()]
            row["expiresAt"] = NSNull(); row["stateAfterExpiry"] = NSNull()
        }
        projection["rows"] = [row]
        let summaryText = ["en": "Readings and actions are available", "zh": "读数或操作可用"]
        projection["rowsSummary"] = ["state": "ok", "reason": ["code": "ok", "text": summaryText], "text": summaryText, "nextStep": NSNull()]
        if isRevoked {
            let noConsent = ["en": "Choose tools to allow in Settings", "zh": "在设置中选择允许读取的工具"]
            projection["rowsSummary"] = ["state": "no_consent", "reason": ["code": "no_consent", "text": noConsent], "text": noConsent, "nextStep": row["nextStep"]!]
        }
        projection.removeValue(forKey: "resetEvents"); root["projection"] = projection
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
        let store = EngineStore(), source = EngineDockMenuProvider(store: store), provider = EngineDockContentProvider(source: source)
        provider.language = english ? "en" : "zh-CN"
        let context = EngineDeliveryContext(sessionID: "synthetic", floor: .init(storeEpoch: "synthetic", generation: 1), revision: 1)
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch,
            consentGeneration: 1, data: rows), delivery: context), invalidRowCount: 0))
        // The expired case holds the same valid fresh snapshot past its deadline;
        // it does not pretend the producer emitted current=true after expiry.
        let seconds: TimeInterval = (state == .expired || state == .refreshed) ? 1_830_000_000 : 1_800_000_000
        let now: Date
        if state == .atExpiry { now = try XCTUnwrap(ISO8601DateFormatter().date(from: deadline)) }
        else { now = Date(timeIntervalSince1970: seconds) }
        let content = provider.makeContent(.init(snapshot: nil, diagnostics: .init(), now: now))
        let input = content.snapshot.inputs.first { $0.id == "aaaaaaaaaaaaaaaa" }
        if mixedTransition {
            func reserveRow(_ snapshot: CommunityDockSnapshot, _ id: String) -> DockCardRow? {
                snapshot.presentationRows[id]?.additionalRows.first { $0.kind == .reserve }
            }
            XCTAssertNotNil(reserveRow(content.snapshot, "aaaaaaaaaaaaaaaa"))
            XCTAssertNotNil(reserveRow(content.snapshot, "bbbbbbbbbbbbbbbb"))
            let firstDeadline = try XCTUnwrap(ISO8601DateFormatter().date(from: deadline))
            let held = provider.makeContent(.init(snapshot: nil, diagnostics: .init(), now: firstDeadline))
            // Current behaviour, not an adjudication of the second account's reserve policy.
            XCTAssertNil(reserveRow(held.snapshot, "aaaaaaaaaaaaaaaa"))
            XCTAssertNil(reserveRow(held.snapshot, "bbbbbbbbbbbbbbbb"))
            let secondDeadline = try XCTUnwrap(ISO8601DateFormatter().date(from: "2028-12-01T00:00:00Z"))
            XCTAssertLessThan(firstDeadline, secondDeadline)

            var refreshedAccount = account
            refreshedAccount["observedAt"] = "2027-12-20T00:00:00Z"; refreshedAccount["freshUntil"] = "2028-12-01T00:00:00Z"
            var refreshedWindow = window
            refreshedWindow["observedAt"] = "2027-12-20T00:00:00Z"; refreshedWindow["validUntil"] = "2028-12-01T00:00:00Z"
            refreshedWindow["resetsAt"] = "2028-12-01T00:00:00Z"
            refreshedAccount["windows"] = [refreshedWindow]
            var second = refreshedAccount; second["subscriptionRef"] = "bbbbbbbbbbbbbbbb"
            row["accounts"] = [refreshedAccount, second]; row["expiresAt"] = "2028-12-01T00:00:00Z"
            projection["rows"] = [row]; root["projection"] = projection
            let refreshedRows = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
            await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch,
                consentGeneration: 1, data: refreshedRows), delivery: context), invalidRowCount: 0))
            let after = Date(timeIntervalSince1970: 1_830_000_000)
            let refreshed = provider.makeContent(.init(snapshot: nil, diagnostics: .init(), now: after))
            XCTAssertNotNil(reserveRow(refreshed.snapshot, "aaaaaaaaaaaaaaaa"))
            XCTAssertNotNil(reserveRow(refreshed.snapshot, "bbbbbbbbbbbbbbbb"))
            await store.consume(.clearPrivateViews(.init(revision: 2, reason: .generationAdvanced, previous: context,
                nextFloor: .init(storeEpoch: "synthetic", generation: 2))))
            let cleared = provider.makeContent(.init(snapshot: nil, diagnostics: .init(), now: after))
            XCTAssertNil(reserveRow(cleared.snapshot, "aaaaaaaaaaaaaaaa"))
            XCTAssertNil(reserveRow(cleared.snapshot, "bbbbbbbbbbbbbbbb"))
            XCTAssertTrue(source.dockContent.dockRows.isEmpty)
        }
        if clearAfter {
            XCTAssertNotNil(content.snapshot.presentationRows["aaaaaaaaaaaaaaaa"]?.additionalRows.first { $0.kind == .reserve })
            await store.consume(.clearPrivateViews(.init(revision: 2, reason: .generationAdvanced, previous: context,
                nextFloor: .init(storeEpoch: "synthetic", generation: 2))))
            let cleared = provider.makeContent(.init(snapshot: nil, diagnostics: .init(), now: now))
            XCTAssertTrue(source.dockContent.dockRows.isEmpty)
            XCTAssertNil(cleared.snapshot.presentationRows["aaaaaaaaaaaaaaaa"])
            return (cleared.snapshot.inputs.first { $0.id == "aaaaaaaaaaaaaaaa" },
                    cleared.snapshot.presentationRows["aaaaaaaaaaaaaaaa"]?.additionalRows.first { $0.kind == .reserve })
        }
        return (input, content.snapshot.presentationRows["aaaaaaaaaaaaaaaa"]?.additionalRows.first { $0.kind == .reserve })
    }

    private func reserve(balance: Any?, unit: String, english: Bool) async throws -> DockCardRow? {
        try await projection(balance: balance, unit: unit, english: english).1
    }

    func testZeroAndFiniteBalancesRemainReportedAndNegativeIsWithheld() async throws {
        let zero = try await reserve(balance: 0, unit: "credits", english: true)
        XCTAssertEqual(zero?.value, "0 credits")
        let thousands = try await reserve(balance: 1_500, unit: "credits", english: true)
        XCTAssertEqual(thousands?.value, "2k credits")
        let fractional = try await reserve(balance: 12.5, unit: "credits", english: true)
        XCTAssertEqual(fractional?.value, "12.5 credits")
        let amount = try await reserve(balance: 12.5, unit: "money", english: true)
        XCTAssertEqual(amount?.value, "12.5")
        XCTAssertEqual(amount?.detail, "Currency not reported")
        let missing = try await reserve(balance: nil, unit: "credits", english: true)
        XCTAssertNil(missing)
        let negative = try await reserve(balance: -1, unit: "credits", english: true)
        XCTAssertNil(negative)
        let boundary = try await reserve(balance: 1_000_000_000_000_000.0, unit: "credits", english: true)
        XCTAssertEqual(boundary?.value, "1000000000.0M credits")
        let outsideBound = try await reserve(balance: 1_000_000_000_000_001.0, unit: "credits", english: true)
        XCTAssertNotNil(outsideBound)
        let fallback = try await reserve(balance: 1e21, unit: "credits", english: true)
        XCTAssertEqual(fallback?.value, String(1e21) + " credits")
        let largeOther = try await reserve(balance: 1_000_000_000_000_001.0, unit: "other", english: true)
        XCTAssertEqual(largeOther?.value, "1000000000000001")
    }

    func testExpiredAndRevokedDoNotExposeReserveForAnyUnit() async throws {
        for unit in ["credits", "other", "money"] {
            let expired = try await projection(balance: 12.5, unit: unit, english: true, state: .expired)
            XCTAssertNil(expired.1)
            let revoked = try await projection(balance: 12.5, unit: unit, english: true, state: .revoked)
            XCTAssertNil(revoked.1)
            // Deliberately contradictory wire: denied consent must not expose retained values.
            let forged = try await projection(balance: 12.5, unit: unit, english: true, state: .revokedWithValues)
            XCTAssertNil(forged.1)
        }
        let money = try await reserve(balance: 12.5, unit: "money", english: true)
        XCTAssertEqual(money?.value, "12.5"); XCTAssertEqual(money?.detail, "Currency not reported")
    }

    func testConsentGenerationClearWithdrawsReserveFromSameStoreAndProvider() async throws {
        let cleared = try await projection(balance: 12.5, unit: "credits", english: true, clearAfter: true)
        XCTAssertNil(cleared.0); XCTAssertNil(cleared.1)
    }

    func testMixedAccountDeadlinesHeldRefreshAndClearInSameStore() async throws {
        _ = try await projection(balance: 12.5, unit: "credits", english: true, mixedTransition: true)
    }

    func testFreshRetainedAndExpiredProjectionStatesAndReserve() async throws {
        let fresh = try await projection(balance: 12.5, unit: "credits", english: true, state: .fresh)
        XCTAssertEqual(fresh.0?.dataState, .fresh); XCTAssertEqual(fresh.1?.value, "12.5 credits")
        let retained = try await projection(balance: 12.5, unit: "credits", english: true, state: .retained)
        XCTAssertEqual(retained.0?.dataState, .unavailable); XCTAssertEqual(retained.1?.value, "12.5 credits")
        let retainedDeadline = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-12-01T00:00:00Z"))
        XCTAssertLessThan(Date(timeIntervalSince1970: 1_800_000_000), retainedDeadline)
        let atExpiry = try await projection(balance: 12.5, unit: "credits", english: true, state: .atExpiry)
        XCTAssertEqual(atExpiry.0?.dataState, .unavailable); XCTAssertNil(atExpiry.1)
        let retainedExpired = try await projection(balance: 12.5, unit: "credits", english: true, state: .retainedExpired)
        XCTAssertEqual(retainedExpired.0?.dataState, .unavailable); XCTAssertNil(retainedExpired.1)
        let expired = try await projection(balance: 12.5, unit: "credits", english: true, state: .expired)
        XCTAssertEqual(expired.0?.dataState, .unavailable); XCTAssertNil(expired.1)
        let refreshed = try await projection(balance: 12.5, unit: "credits", english: true, state: .refreshed)
        XCTAssertEqual(refreshed.0?.dataState, .fresh); XCTAssertEqual(refreshed.1?.value, "12.5 credits")
        let beforeExpiry = Date(timeIntervalSince1970: 1_800_000_000)
        let afterExpiry = Date(timeIntervalSince1970: 1_830_000_000)
        let freshReading = try DockInstrumentProjection.evaluate(XCTUnwrap(fresh.0), now: beforeExpiry)
        let retainedReading = try DockInstrumentProjection.evaluate(XCTUnwrap(retained.0), now: beforeExpiry)
        let expiredReading = try DockInstrumentProjection.evaluate(XCTUnwrap(expired.0), now: afterExpiry)
        let refreshedReading = try DockInstrumentProjection.evaluate(XCTUnwrap(refreshed.0), now: afterExpiry)
        XCTAssertEqual(freshReading.readout, "42.5%")
        XCTAssertEqual(retainedReading.readout, "--"); XCTAssertEqual(expiredReading.readout, "--")
        // Pure projection sequence, not a claim about a live store update or GUI rendering.
        XCTAssertEqual([retainedReading.readout, freshReading.readout], ["--", "42.5%"])
        XCTAssertEqual([expiredReading.readout, refreshedReading.readout], ["--", "42.5%"])
    }

    // Empty and unrecognized units are decoder-boundary inputs; the current
    // producer normalizes both to "other" and does not emit them directly.
    func testUnknownAndEmptyUnitAreNotMisreportedOrEchoed() async throws {
        let other = try await reserve(balance: 12.5, unit: "other", english: true)
        XCTAssertEqual(other?.value, "12.5"); XCTAssertEqual(other?.detail, "Unit unavailable")
        let otherZH = try await reserve(balance: 12.5, unit: "other", english: false)
        XCTAssertEqual(otherZH?.detail, "单位不可用")
        let rounded = try await reserve(balance: 247.538, unit: "other", english: true)
        XCTAssertEqual(rounded?.value, "≈247.54"); XCTAssertEqual(rounded?.detail, "Unit unavailable")
        let tiny = try await reserve(balance: 0.004, unit: "other", english: false)
        XCTAssertEqual(tiny?.value, "≈0"); XCTAssertEqual(tiny?.detail, "单位不可用")
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
