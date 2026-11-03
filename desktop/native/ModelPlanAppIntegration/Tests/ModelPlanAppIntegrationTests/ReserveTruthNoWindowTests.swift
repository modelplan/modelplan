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
    private enum FixtureState { case fresh, retained, retainedExpired, unknownDeadline, malformedDeadline, currentUnknownDeadline, currentMalformedDeadline, currentAccountMissing, currentAccountMalformed, currentWindowMissing, currentWindowMalformed, currentWindowMissingObservation, atExpiry, expired, refreshed, revoked, revokedWithValues, revokedFreshWithValues, retiredWithValues }
    private enum ProofMutation { case fallbackMember, missingLatch, nonStaleLatch, missingReset, malformedReset, mismatchReset, laterReset, missingValidUntil, malformedValidUntil, futureAccountObservation, malformedAccountObservation, futureWindowObservation, malformedWindowObservation, duplicateWindowID }
    private func projection(balance: Any?, unit: String, english: Bool, state: FixtureState = .fresh, clearAfter: Bool = false, mixedTransition: Bool = false, deadlineOnlyMixed: Bool = false, multiWindowTransition: Bool = false, proofTwoWindows: Bool = false, proofMutation: ProofMutation? = nil, overrideNow: Date? = nil, resetEvents: [EngineResetEvent] = [], replacementEvents: [EngineResetEvent]? = nil, providerProbe: ((EngineDockContentProvider, DockContent, Date) -> Void)? = nil, deadlineProbe: (([RowsRow], Date) -> Void)? = nil) async throws -> (DockInstrumentInput?, DockCardRow?) {
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
        let currentUnknown = state == .currentUnknownDeadline || state == .currentMalformedDeadline
        let malformed = state == .malformedDeadline || state == .currentMalformedDeadline
        let unknownDeadline = state == .unknownDeadline || state == .malformedDeadline || currentUnknown
        let isRetained = state == .retained || state == .retainedExpired || (unknownDeadline && !currentUnknown)
        let isRevoked = state == .revoked || state == .revokedWithValues || state == .revokedFreshWithValues
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
        if multiWindowTransition || proofTwoWindows {
            account["freshUntil"] = "2028-12-01T00:00:00Z"
            var weekly = window
            weekly["id"] = "weekly:604800:main:main"; weekly["role"] = "weekly"; weekly["durationSeconds"] = 604800
            weekly["label"] = ["en": "Weekly", "zh": "每周"]; weekly["remainingPercent"] = 75.0
            weekly["resetsAt"] = "2028-12-01T00:00:00Z"; weekly["validUntil"] = "2028-12-01T00:00:00Z"
            account["windows"] = [window, weekly]
        }
        if unknownDeadline {
            if isRetained {
                row["reason"] = ["code": "observation_time_unknown", "text": ["en": "The observation time is unknown", "zh": "观测时间未知"]]
                account["observedAt"] = NSNull(); window["observedAt"] = NSNull()
            }
            row["expiresAt"] = malformed ? "invalid-deadline" as Any : NSNull()
            account["freshUntil"] = malformed ? "invalid-deadline" as Any : NSNull()
            window["validUntil"] = malformed ? "invalid-deadline" as Any : NSNull(); window["current"] = currentUnknown
            account["windows"] = [window]
        }
        // Isolated contradictory wire fields: separate account and window
        // decoder failures from the case where both deadlines are absent.
        if state == .currentAccountMissing || state == .currentAccountMalformed {
            account["freshUntil"] = state == .currentAccountMalformed ? "invalid-deadline" as Any : NSNull()
        }
        if state == .currentWindowMissing || state == .currentWindowMalformed {
            window["validUntil"] = state == .currentWindowMalformed ? "invalid-deadline" as Any : NSNull()
            account["windows"] = [window]
        }
        if state == .currentWindowMissingObservation {
            window["observedAt"] = NSNull(); account["windows"] = [window]
        }
        if let proofMutation {
            var altered = account["windows"] as! [[String: Any]]
            switch proofMutation {
            case .fallbackMember: account["subscriptionRef"] = NSNull()
            case .missingLatch: row["stateAfterExpiry"] = NSNull()
            case .nonStaleLatch: row["stateAfterExpiry"] = ["state": "needs_action", "reason": staleReason, "nextStep": refresh]
            case .missingReset: altered[0]["resetsAt"] = NSNull()
            case .malformedReset: altered[0]["resetsAt"] = "invalid-deadline"
            case .mismatchReset: altered[0]["resetsAt"] = "2027-06-01T00:00:00Z"
            case .laterReset: altered[0]["resetsAt"] = "2028-12-01T00:00:00Z"
            case .missingValidUntil: altered[0]["validUntil"] = NSNull()
            case .malformedValidUntil: altered[0]["validUntil"] = "invalid-deadline"
            case .futureAccountObservation: account["observedAt"] = "2028-01-01T00:00:00Z"
            case .malformedAccountObservation: account["observedAt"] = "invalid-observation"
            case .futureWindowObservation: altered[0]["observedAt"] = "2028-01-01T00:00:00Z"
            case .malformedWindowObservation: altered[0]["observedAt"] = "invalid-observation"
            case .duplicateWindowID: altered.append(altered[0])
            }
            account["windows"] = altered
        }
        row["accounts"] = state == .revoked ? [] : [account]
        if mixedTransition || deadlineOnlyMixed {
            var second = account
            second["subscriptionRef"] = "bbbbbbbbbbbbbbbb"; second["freshUntil"] = "2028-12-01T00:00:00Z"
            var secondWindow = window
            secondWindow["validUntil"] = "2028-12-01T00:00:00Z"; secondWindow["resetsAt"] = "2028-12-01T00:00:00Z"
            second["windows"] = [secondWindow]
            row["accounts"] = [account, second]
        }
        if isRevoked {
            row["consent"] = "denied"
            if state != .revokedFreshWithValues {
                row["state"] = "needs_consent"
                row["reason"] = ["code": "consent_denied", "text": ["en": "Reader consent is denied", "zh": "读取授权已拒绝"]]
                row["nextStep"] = ["action": "open_settings_consent", "text": ["en": "Review reader consent in Settings", "zh": "在设置中检查读取授权"], "availableAt": NSNull(), "disabledReason": NSNull()]
            }
            row["expiresAt"] = NSNull(); row["stateAfterExpiry"] = NSNull()
        }
        if state == .retiredWithValues {
            row["consent"] = "retired"; row["state"] = "needs_action"
            row["reason"] = ["code": "catalogue_retired", "text": ["en": "The allowed tool was retired from the catalogue", "zh": "已授权工具已从目录移除"]]
            row["nextStep"] = ["action": "open_settings_consent", "text": ["en": "Review reader consent in Settings", "zh": "在设置中检查读取授权"], "availableAt": NSNull(), "disabledReason": NSNull()]
        }
        projection["rows"] = [row]
        let summaryText = ["en": "Readings and actions are available", "zh": "读数或操作可用"]
        projection["rowsSummary"] = ["state": "ok", "reason": ["code": "ok", "text": summaryText], "text": summaryText, "nextStep": NSNull()]
        if isRevoked {
            let noConsent = ["en": "Choose tools to allow in Settings", "zh": "在设置中选择允许读取的工具"]
            let consentStep: [String: Any] = ["action": "open_settings_consent", "text": ["en": "Review reader consent in Settings", "zh": "在设置中检查读取授权"], "availableAt": NSNull(), "disabledReason": NSNull()]
            projection["rowsSummary"] = ["state": "no_consent", "reason": ["code": "no_consent", "text": noConsent], "text": noConsent, "nextStep": consentStep]
        }
        projection.removeValue(forKey: "resetEvents"); root["projection"] = projection
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
        if state == .revokedWithValues || state == .revokedFreshWithValues {
            XCTAssertEqual(rows.projection.invalidRowCount, 1)
            XCTAssertEqual(rows.projection.rows.first?.invalid, true)
            XCTAssertTrue(rows.projection.rows.first?.accounts.isEmpty == true)
        }
        if unknownDeadline {
            // Generated optional timestamp decoding currently turns malformed strings into nil.
            XCTAssertNil(rows.projection.rows.first?.expiresAt)
            XCTAssertNil(rows.projection.rows.first?.accounts.first?.freshUntil)
        }
        let store = EngineStore(), source = EngineDockMenuProvider(store: store), provider = EngineDockContentProvider(source: source)
        provider.language = english ? "en" : "zh-CN"
        var currentResetEvents = resetEvents
        provider.resetEventState = { .available(currentResetEvents) }
        let context = EngineDeliveryContext(sessionID: "synthetic", floor: .init(storeEpoch: "synthetic", generation: 1), revision: 1)
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch,
            consentGeneration: 1, data: rows), delivery: context), invalidRowCount: rows.projection.invalidRowCount))
        // The expired case holds the same valid fresh snapshot past its deadline;
        // it does not pretend the producer emitted current=true after expiry.
        let seconds: TimeInterval = (state == .expired || state == .refreshed) ? 1_830_000_000 : 1_800_000_000
        let now: Date
        if state == .atExpiry { now = try XCTUnwrap(ISO8601DateFormatter().date(from: deadline)) }
        else { now = overrideNow ?? Date(timeIntervalSince1970: seconds) }
        deadlineProbe?(rows.projection.rows, now)
        let paired = provider.makeContentAndDeadline(.init(snapshot: nil, diagnostics: .init(), now: now))
        let content = paired.content
        XCTAssertEqual(paired.deadline, provider.recomputeDeadline)
        providerProbe?(provider, content, now)
        if unknownDeadline {
            if isRetained { XCTAssertEqual(provider.recomputeDeadline, .unknown) }
            XCTAssertTrue(paired.verifiedWindows.isEmpty)
        }
        if isRetained { XCTAssertTrue(paired.verifiedWindows.isEmpty) }
        if isRevoked { XCTAssertEqual(provider.recomputeDeadline, .none); XCTAssertTrue(paired.verifiedWindows.isEmpty) }
        let input = content.snapshot.inputs.first { $0.id == "aaaaaaaaaaaaaaaa" }
        if let replacementEvents {
            let initial = try XCTUnwrap(resetEvents.first), replacement = try XCTUnwrap(replacementEvents.first)
            XCTAssertEqual(paired.deadline, .scheduled(initial.publishedAt, hasUnknownDeadline: false))
            currentResetEvents = replacementEvents
            let replaced = provider.makeContentAndDeadline(.init(snapshot: nil, diagnostics: .init(), now: now))
            XCTAssertEqual(replaced.deadline, .scheduled(replacement.publishedAt, hasUnknownDeadline: false))
            XCTAssertEqual(paired.deadline, .scheduled(initial.publishedAt, hasUnknownDeadline: false))
            currentResetEvents = []
            let noEvent = provider.makeContentAndDeadline(.init(snapshot: nil, diagnostics: .init(), now: now))
            let rowDeadline = try XCTUnwrap(ISO8601DateFormatter().date(from: deadline))
            XCTAssertEqual(noEvent.deadline, .scheduled(rowDeadline, hasUnknownDeadline: false))
            XCTAssertNil(provider.signals.first?.reset)
            currentResetEvents = replacementEvents
            await store.consume(.clearPrivateViews(.init(revision: 2, reason: .generationAdvanced, previous: context,
                nextFloor: .init(storeEpoch: "synthetic", generation: 2))))
            let cleared = provider.makeContentAndDeadline(.init(snapshot: nil, diagnostics: .init(), now: now))
            XCTAssertEqual(cleared.deadline, .none); XCTAssertTrue(cleared.content.snapshot.inputs.isEmpty)
        }
        if multiWindowTransition {
            let firstDeadline = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-12-01T00:00:00Z"))
            let secondDeadline = try XCTUnwrap(ISO8601DateFormatter().date(from: "2028-12-01T00:00:00Z"))
            XCTAssertEqual(content.snapshot.inputs.count, 1)
            XCTAssertEqual(input?.windows.count, 2)
            XCTAssertEqual(provider.recomputeDeadline, .scheduled(firstDeadline, hasUnknownDeadline: false))
            XCTAssertEqual(Set(paired.verifiedWindows.map(\.windowID)), Set(["session:18000:main:main", "weekly:604800:main:main"]))
            XCTAssertTrue(paired.verifiedWindows.allSatisfy { $0.memberID == "aaaaaaaaaaaaaaaa" })
            XCTAssertTrue(paired.verifiedWindows.allSatisfy { $0.until == firstDeadline && $0.issuedAt == now })
            let initialWeekly = try XCTUnwrap(paired.verifiedWindows.first { $0.windowID == "weekly:604800:main:main" })
            XCTAssertTrue(initialWeekly.isValid(memberID: "aaaaaaaaaaaaaaaa", windowID: initialWeekly.windowID, at: now))
            XCTAssertFalse(initialWeekly.isValid(memberID: "bbbbbbbbbbbbbbbb", windowID: initialWeekly.windowID, at: now))
            XCTAssertFalse(initialWeekly.isValid(memberID: "aaaaaaaaaaaaaaaa", windowID: "another-window", at: now))
            XCTAssertFalse(initialWeekly.isValid(memberID: "aaaaaaaaaaaaaaaa", windowID: initialWeekly.windowID, at: now.addingTimeInterval(-1)))
            XCTAssertFalse(initialWeekly.isValid(memberID: "aaaaaaaaaaaaaaaa", windowID: initialWeekly.windowID, at: firstDeadline))
            XCTAssertFalse(initialWeekly.isValid(memberID: "aaaaaaaaaaaaaaaa", windowID: initialWeekly.windowID, at: Date(timeIntervalSinceReferenceDate: .nan)))
            XCTAssertEqual(input?.windows.first { $0.period == .fiveHour }?.remainingPercent, 42.5)
            XCTAssertEqual(input?.windows.first { $0.period == .week }?.remainingPercent, 75.0)
            XCTAssertEqual(EngineDeadlineFacts.evaluate(rows: rows.projection.rows, now: now), .scheduled(firstDeadline, hasUnknownDeadline: false))
            let heldPair = provider.makeContentAndDeadline(.init(snapshot: nil, diagnostics: .init(), now: firstDeadline))
            let held = heldPair.content
            XCTAssertEqual(held.snapshot.inputs.count, 1)
            XCTAssertEqual(provider.recomputeDeadline, .scheduled(secondDeadline, hasUnknownDeadline: false))
            XCTAssertEqual(heldPair.deadline, .scheduled(secondDeadline, hasUnknownDeadline: false))
            XCTAssertEqual(paired.deadline, .scheduled(firstDeadline, hasUnknownDeadline: false))
            XCTAssertEqual(heldPair.verifiedWindows.count, 1)
            XCTAssertEqual(heldPair.verifiedWindows.first?.memberID, "aaaaaaaaaaaaaaaa")
            XCTAssertEqual(heldPair.verifiedWindows.first?.windowID, "weekly:604800:main:main")
            XCTAssertEqual(heldPair.verifiedWindows.first?.remainingPercent, 75.0)
            XCTAssertEqual(heldPair.verifiedWindows.first?.until, secondDeadline)
            XCTAssertEqual(EngineDeadlineFacts.evaluate(rows: rows.projection.rows, now: firstDeadline), .scheduled(secondDeadline, hasUnknownDeadline: false))
            // The row-level reason and overall input remain non-fresh. The
            // later weekly window is still time-valid on the wire, but the
            // current Dock model cannot present it under a non-fresh input.
            let heldInput = try XCTUnwrap(held.snapshot.inputs.first)
            XCTAssertNil(heldInput.windows.first { $0.period == .fiveHour }?.remainingPercent)
            XCTAssertEqual(heldInput.dataState, .unavailable)
            XCTAssertNil(heldInput.windows.first { $0.period == .week }?.remainingPercent)
            XCTAssertEqual(try DockInstrumentProjection.evaluate(heldInput, now: firstDeadline).readout, "--")
            XCTAssertEqual(held.snapshot.presentationRows["aaaaaaaaaaaaaaaa"]?.reason, "A retained reading is shown")
            XCTAssertEqual(held.snapshot.subscriptions.first?.source, .stale)
            XCTAssertNil(held.snapshot.presentationRows["aaaaaaaaaaaaaaaa"]?.additionalRows.first { $0.kind == .reserve })
            // Isolate the representation gap: even an explicitly supplied valid
            // weekly value is suppressed when overall state is stale.
            var staleProbe = heldInput
            staleProbe.dataState = .stale
            let weeklyIndex = try XCTUnwrap(staleProbe.windows.firstIndex { $0.period == .week })
            staleProbe.windows[weeklyIndex].remainingPercent = 75.0
            staleProbe.windows[weeklyIndex].resetsAt = secondDeadline
            let staleReading = try DockInstrumentProjection.evaluate(staleProbe, now: firstDeadline)
            XCTAssertEqual(staleReading.dataState, .stale); XCTAssertEqual(staleReading.readout, "--")
            XCTAssertEqual(staleReading.status, .unknown)
            let card = try DockCardProjection.content(input: staleProbe, stateLabel: "A retained reading is shown", at: firstDeadline)
            XCTAssertEqual(card.stateLabel, "A retained reading is shown")
            XCTAssertEqual(card.rows.first { $0.id == "quota:weekly:604800:main:main" }?.value, "--")
            let fullyExpired = provider.makeContent(.init(snapshot: nil, diagnostics: .init(), now: secondDeadline))
            XCTAssertNil(fullyExpired.snapshot.inputs.first?.windows.first { $0.period == .week }?.remainingPercent)
            XCTAssertTrue(provider.verifiedWindows.isEmpty)

            var refreshedAccount = account
            refreshedAccount["observedAt"] = "2027-12-20T00:00:00Z"
            var refreshedWindows = account["windows"] as! [[String: Any]]
            refreshedWindows[0]["observedAt"] = "2027-12-20T00:00:00Z"
            refreshedWindows[0]["resetsAt"] = "2028-02-01T00:00:00Z"; refreshedWindows[0]["validUntil"] = "2028-02-01T00:00:00Z"
            refreshedWindows[1]["observedAt"] = "2027-12-20T00:00:00Z"
            refreshedAccount["windows"] = refreshedWindows
            row["accounts"] = [refreshedAccount]; row["expiresAt"] = "2028-02-01T00:00:00Z"
            projection["rows"] = [row]; root["projection"] = projection
            let refreshedRows = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
            await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch,
                consentGeneration: 1, data: refreshedRows), delivery: context), invalidRowCount: 0))
            let after = Date(timeIntervalSince1970: 1_830_000_000)
            let refreshedPair = provider.makeContentAndDeadline(.init(snapshot: nil, diagnostics: .init(), now: after))
            let refreshed = refreshedPair.content
            let refreshedDeadline = try XCTUnwrap(ISO8601DateFormatter().date(from: "2028-02-01T00:00:00Z"))
            XCTAssertEqual(provider.recomputeDeadline, .scheduled(refreshedDeadline, hasUnknownDeadline: false))
            XCTAssertEqual(refreshedPair.deadline, .scheduled(refreshedDeadline, hasUnknownDeadline: false))
            XCTAssertEqual(refreshedPair.verifiedWindows.count, 2)
            XCTAssertEqual(heldPair.deadline, .scheduled(secondDeadline, hasUnknownDeadline: false))
            XCTAssertEqual(refreshed.snapshot.inputs.count, 1)
            let refreshedInput = try XCTUnwrap(refreshed.snapshot.inputs.first)
            XCTAssertEqual(refreshedInput.dataState, .fresh)
            XCTAssertEqual(refreshedInput.windows.first { $0.period == .week }?.remainingPercent, 75.0)
            XCTAssertNotNil(refreshed.snapshot.presentationRows["aaaaaaaaaaaaaaaa"]?.additionalRows.first { $0.kind == .reserve })
            await store.consume(.clearPrivateViews(.init(revision: 2, reason: .generationAdvanced, previous: context,
                nextFloor: .init(storeEpoch: "synthetic", generation: 2))))
            let withdrawnPair = provider.makeContentAndDeadline(.init(snapshot: nil, diagnostics: .init(), now: after))
            let withdrawn = withdrawnPair.content
            XCTAssertTrue(withdrawn.snapshot.inputs.isEmpty)
            XCTAssertNil(withdrawn.snapshot.presentationRows["aaaaaaaaaaaaaaaa"])
            XCTAssertEqual(provider.recomputeDeadline, .none)
            XCTAssertEqual(withdrawnPair.deadline, .none)
            XCTAssertTrue(withdrawnPair.verifiedWindows.isEmpty)
            XCTAssertEqual(refreshedPair.deadline, .scheduled(refreshedDeadline, hasUnknownDeadline: false))
        }
        if mixedTransition {
            XCTAssertTrue(paired.verifiedWindows.isEmpty)
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

    func testDeniedConsentWithContradictoryFreshQuotaBecomesEmptyPlaceholder() async throws {
        // Noncanonical wire: decoder isolates this row before Provider admission.
        let result = try await projection(balance: 12.5, unit: "credits", english: true, state: .revokedFreshWithValues)
        XCTAssertNil(result.0)
        XCTAssertNil(result.1)
        // The public row constructor also rejects a denied row with accounts;
        // bypassing it to reach the defensive Provider branch is not a safe seam.
        _ = try await projection(balance: 12.5, unit: "credits", english: true) { rows, _ in
            guard let row = rows.first else { return XCTFail("missing synthetic row") }
            XCTAssertThrowsError(try RowsRow(id: row.id, kind: row.kind, order: row.order, name: row.name,
                vendorKey: row.vendorKey, surfaces: row.surfaces, consent: .denied, state: .fresh,
                reason: row.reason, nextStep: row.nextStep, accounts: row.accounts,
                expiresAt: row.expiresAt, stateAfterExpiry: row.stateAfterExpiry))
        }
    }

    func testConsentGenerationClearWithdrawsReserveFromSameStoreAndProvider() async throws {
        let cleared = try await projection(balance: 12.5, unit: "credits", english: true, clearAfter: true)
        XCTAssertNil(cleared.0); XCTAssertNil(cleared.1)
    }

    func testMixedAccountDeadlinesHeldRefreshAndClearInSameStore() async throws {
        _ = try await projection(balance: 12.5, unit: "credits", english: true, mixedTransition: true)
    }

    func testOneSubscriptionMultipleWindowsDeadlineAndRefresh() async throws {
        _ = try await projection(balance: 12.5, unit: "credits", english: true, multiWindowTransition: true)
    }

    func testWindowProofRejectsAmbiguousIdentityAndNoncanonicalFacts() async throws {
        // These mutations are defensive noncanonical wire inputs, not claims
        // about an observed user account or a producer output.
        let earlierReset = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-06-01T00:00:00Z"))
        for mutation in [ProofMutation.fallbackMember, .missingReset, .malformedReset, .mismatchReset,
                         .missingValidUntil, .malformedValidUntil, .futureAccountObservation,
                         .malformedAccountObservation, .futureWindowObservation, .malformedWindowObservation,
                         .duplicateWindowID] {
            _ = try await projection(balance: 12.5, unit: "credits", english: true, proofMutation: mutation,
                providerProbe: { provider, _, _ in
                    XCTAssertTrue(provider.verifiedWindows.isEmpty)
                    if mutation == .mismatchReset {
                        XCTAssertEqual(provider.recomputeDeadline, .scheduled(earlierReset, hasUnknownDeadline: false))
                    }
                })
        }
        _ = try await projection(balance: 12.5, unit: "credits", english: true, proofMutation: .laterReset,
            providerProbe: { provider, _, _ in
                XCTAssertEqual(provider.verifiedWindows.count, 1)
                XCTAssertEqual(provider.verifiedWindows.first?.until, ISO8601DateFormatter().date(from: "2027-12-01T00:00:00Z"))
            })
    }

    func testWindowProofStopsAtRowLatchWhenLatchIsMissingOrNonStale() async throws {
        let deadline = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-12-01T00:00:00Z"))
        for mutation in [ProofMutation.missingLatch, .nonStaleLatch] {
            _ = try await projection(balance: 12.5, unit: "credits", english: true, proofTwoWindows: true,
                proofMutation: mutation, overrideNow: deadline.addingTimeInterval(-1), providerProbe: { provider, _, _ in
                    XCTAssertEqual(provider.verifiedWindows.count, 2)
                    XCTAssertTrue(provider.verifiedWindows.allSatisfy { $0.until == deadline })
                })
            _ = try await projection(balance: 12.5, unit: "credits", english: true, proofTwoWindows: true,
                proofMutation: mutation, overrideNow: deadline, providerProbe: { provider, _, _ in
                    XCTAssertTrue(provider.verifiedWindows.isEmpty)
                })
        }
    }

    func testRetainedNullAndMalformedDeadlinesCharacterizeCurrentExposure() async throws {
        // Negative/ambiguous inputs: null is permitted for retained; malformed is
        // intentionally noncanonical and currently decodes as nil. Neither proves freshness.
        for state in [FixtureState.unknownDeadline, .malformedDeadline] {
            let early = try await projection(balance: 12.5, unit: "credits", english: true, state: state)
            let later = try await projection(balance: 12.5, unit: "credits", english: true, state: state,
                overrideNow: Date(timeIntervalSince1970: 1_900_000_000))
            XCTAssertEqual(early.0?.dataState, .unavailable); XCTAssertEqual(later.0?.dataState, .unavailable)
            // Characterizes the existing gap; it does not approve indefinite retention.
            XCTAssertEqual(early.1?.value, "12.5 credits"); XCTAssertEqual(later.1?.value, "12.5 credits")
        }
    }

    func testCurrentWithMissingOrMalformedDeadlineCharacterizesUnprovenFreshness() async throws {
        // Deliberately noncanonical: producer validation requires current accounts
        // and current windows to carry valid future deadlines.
        let knownDeadline = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-12-01T00:00:00Z"))
        for state in [FixtureState.currentUnknownDeadline, .currentMalformedDeadline, .currentAccountMissing, .currentAccountMalformed, .currentWindowMissing, .currentWindowMalformed] {
            let projected = try await projection(balance: 12.5, unit: "credits", english: true, state: state, providerProbe: { provider, _, _ in
                let expected: EngineRecomputeDeadline = .scheduled(knownDeadline, hasUnknownDeadline: true)
                XCTAssertEqual(provider.recomputeDeadline, expected)
                XCTAssertTrue(provider.verifiedWindows.isEmpty)
            })
            XCTAssertEqual(projected.0?.dataState, .fresh)
            XCTAssertEqual(projected.0?.windows.first?.remainingPercent, 42.5)
            XCTAssertEqual(projected.1?.value, "12.5 credits")
            // These characterize today's nil fallbacks, not approval of the result.
        }
        _ = try await projection(balance: 12.5, unit: "credits", english: true, state: .currentWindowMissingObservation,
            providerProbe: { provider, _, _ in XCTAssertTrue(provider.verifiedWindows.isEmpty) })
    }

    func testResetEventPublicationAndExpiryAreRecomputeDeadlines() async throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let published = start.addingTimeInterval(10), expires = start.addingTimeInterval(20)
        let rowDeadline = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-12-01T00:00:00Z"))
        let event = EngineResetEvent(id: "synthetic", rowID: "codex", provider: "synthetic", status: "announced",
                                     publishedAt: published, expiresAt: expires, planIDs: nil, confirms: nil)
        _ = try await projection(balance: 12.5, unit: "credits", english: true, overrideNow: start, resetEvents: [event], providerProbe: { provider, _, _ in
            XCTAssertEqual(provider.recomputeDeadline, .scheduled(published, hasUnknownDeadline: false))
            XCTAssertNil(provider.signals.first?.reset)
        })
        _ = try await projection(balance: 12.5, unit: "credits", english: true, overrideNow: published, resetEvents: [event], providerProbe: { provider, content, _ in
            XCTAssertEqual(provider.recomputeDeadline, .scheduled(expires, hasUnknownDeadline: false))
            XCTAssertNotNil(provider.signals.first?.reset)
            XCTAssertNotNil(content.snapshot.presentationRows["aaaaaaaaaaaaaaaa"]?.additionalRows.first { $0.id == "reset-event:synthetic:announced" })
        })
        _ = try await projection(balance: 12.5, unit: "credits", english: true, overrideNow: expires, resetEvents: [event], providerProbe: { provider, content, _ in
            XCTAssertEqual(provider.recomputeDeadline, .scheduled(rowDeadline, hasUnknownDeadline: false))
            XCTAssertNil(provider.signals.first?.reset)
            XCTAssertNil(content.snapshot.presentationRows["aaaaaaaaaaaaaaaa"]?.additionalRows.first { $0.id == "reset-event:synthetic:announced" })
        })
    }

    func testRetiredMemberResetAndPlanMismatchUseSameAdmissionForDisplayAndDeadline() async throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let published = start.addingTimeInterval(10), expires = start.addingTimeInterval(20)
        let admitted = EngineResetEvent(id: "synthetic", rowID: "codex", provider: "synthetic", status: "announced",
                                        publishedAt: published, expiresAt: expires, planIDs: nil, confirms: nil)
        let mismatch = EngineResetEvent(id: "other-plan", rowID: "codex", provider: "synthetic", status: "announced",
                                        publishedAt: published, expiresAt: expires, planIDs: ["different-plan"], confirms: nil)
        _ = try await projection(balance: 12.5, unit: "credits", english: true, state: .retiredWithValues,
            overrideNow: start, resetEvents: [admitted], providerProbe: { provider, _, _ in
                XCTAssertEqual(provider.recomputeDeadline, .scheduled(published, hasUnknownDeadline: false))
                XCTAssertNil(provider.signals.first?.reset)
            })
        _ = try await projection(balance: 12.5, unit: "credits", english: true, state: .retiredWithValues,
            overrideNow: published, resetEvents: [admitted], providerProbe: { provider, content, _ in
                XCTAssertEqual(provider.recomputeDeadline, .scheduled(expires, hasUnknownDeadline: false))
                XCTAssertNotNil(provider.signals.first?.reset)
                XCTAssertNotNil(content.snapshot.presentationRows["aaaaaaaaaaaaaaaa"]?.additionalRows.first { $0.id == "reset-event:synthetic:announced" })
            })
        _ = try await projection(balance: 12.5, unit: "credits", english: true, state: .retiredWithValues,
            overrideNow: expires, resetEvents: [admitted], providerProbe: { provider, _, _ in
                XCTAssertEqual(provider.recomputeDeadline, .none)
                XCTAssertNil(provider.signals.first?.reset)
            })
        _ = try await projection(balance: 12.5, unit: "credits", english: true, state: .retiredWithValues,
            overrideNow: start, resetEvents: [mismatch], providerProbe: { provider, _, _ in
                XCTAssertEqual(provider.recomputeDeadline, .none)
                XCTAssertNil(provider.signals.first?.reset)
            })
    }

    func testResetEventReplacementRemovalAndStoreClearRecomputePairedDeadline() async throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let first = EngineResetEvent(id: "first", rowID: "codex", provider: "synthetic", status: "announced",
                                     publishedAt: start.addingTimeInterval(10), expiresAt: start.addingTimeInterval(20), planIDs: nil, confirms: nil)
        let replacement = EngineResetEvent(id: "replacement", rowID: "codex", provider: "synthetic", status: "announced",
                                           publishedAt: start.addingTimeInterval(15), expiresAt: start.addingTimeInterval(30), planIDs: nil, confirms: nil)
        _ = try await projection(balance: 12.5, unit: "credits", english: true, overrideNow: start,
                                 resetEvents: [first], replacementEvents: [replacement])
    }

    func testRecomputeDeadlineFactsUseOnlyFutureAndReportUnknown() async throws {
        let first = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-12-01T00:00:00Z"))
        let second = try XCTUnwrap(ISO8601DateFormatter().date(from: "2028-12-01T00:00:00Z"))
        XCTAssertEqual(EngineDeadlineFacts.evaluate(rows: [], now: first), .none)
        XCTAssertEqual(EngineDeadlineFacts.evaluate(rows: [], now: Date(timeIntervalSinceReferenceDate: .nan)), .unknown)
        XCTAssertEqual(EngineDeadlineFacts.evaluate(rows: [], now: Date(timeIntervalSinceReferenceDate: .infinity)), .unknown)
        _ = try await projection(balance: 12.5, unit: "credits", english: true, mixedTransition: true) { rows, now in
            XCTAssertEqual(EngineDeadlineFacts.evaluate(rows: rows, now: now), .scheduled(first, hasUnknownDeadline: false))
            // Once the row latch is due, a different account's later deadline remains a fact.
            XCTAssertEqual(EngineDeadlineFacts.evaluate(rows: rows, now: first), .scheduled(second, hasUnknownDeadline: false))
            XCTAssertEqual(EngineDeadlineFacts.evaluate(rows: rows, now: second), .none)
        }
        for state in [FixtureState.unknownDeadline, .malformedDeadline] {
            _ = try await projection(balance: 12.5, unit: "credits", english: true, state: state) { rows, now in
                XCTAssertEqual(EngineDeadlineFacts.evaluate(rows: rows, now: now), .unknown)
            }
        }
        _ = try await projection(balance: 12.5, unit: "credits", english: true, state: .retained, deadlineOnlyMixed: true) { rows, now in
            XCTAssertEqual(EngineDeadlineFacts.evaluate(rows: rows, now: now), .scheduled(first, hasUnknownDeadline: true))
        }
        _ = try await projection(balance: 12.5, unit: "credits", english: true, state: .refreshed) { rows, now in
            XCTAssertEqual(EngineDeadlineFacts.evaluate(rows: rows, now: now), .scheduled(second, hasUnknownDeadline: false))
        }
        _ = try await projection(balance: 12.5, unit: "credits", english: true, state: .revokedWithValues) { rows, now in
            XCTAssertEqual(EngineDeadlineFacts.evaluate(rows: rows, now: now), .none)
        }
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
