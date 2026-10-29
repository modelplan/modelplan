// SPDX-License-Identifier: MIT
import Foundation
import AppKit
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
    private func adapt(_ snapshot: JoinedSnapshot?, diagnostics: StoreDiagnostics? = nil, canonicalConsent: ConsentPreview? = nil) -> CommunityDockSnapshot {
        var ready = StoreDiagnostics(); ready.personal = nil
        return CommunityDockSnapshot(snapshot: snapshot, diagnostics: diagnostics ?? ready, now: now, canonicalConsent: canonicalConsent)
    }
    private func canonicalConsent(_ ids: [String]) throws -> ConsentPreview {
        var capture = try GeneratedAppCLIFixtures.object("consented-consent.json")
        var tools = try XCTUnwrap(capture["tools"] as? [[String: Any]])
        for index in tools.indices { tools[index]["allowed"] = ids.contains(tools[index]["id"] as? String ?? "") }
        capture["mode"] = "automatic"; capture["tools"] = tools
        return try FeedDecoder.consentPreview(JSONSerialization.data(withJSONObject: capture))
    }
    func testAccountPresentationWithoutMembershipKeepsRealValueAndNoInventedSubscription() throws {
        let joined = try snapshot(accounts: [account(nil, source: "codex", windows: [window()])])
        let result = adapt(joined)
        XCTAssertEqual(result.inputs.count, 1)
        XCTAssertTrue(result.subscriptions.isEmpty)
        XCTAssertEqual(result.inputs[0].windows.first?.remainingPercent, 75)
        XCTAssertEqual(result.inputs[0].dataState, .fresh)
        XCTAssertNotNil(result.presentationRows[result.inputs[0].id])
    }
    func testConsentedUnreadableConnectionHasReasonAndNextStepWithoutQuotaOrMembership() throws {
        let joined = try snapshot(accounts: [], extras: ["connections": [
            ["id": "claude", "authorization": ["status": "yes"], "quota": ["status": "no", "reason": "consent_required"]],
            ["id": "codex", "authorization": ["status": "no"], "quota": ["status": "missing"]]
        ]])
        let result = adapt(joined, canonicalConsent: try canonicalConsent(["claude"]))
        XCTAssertEqual(result.inputs.count, 1)
        XCTAssertTrue(result.subscriptions.isEmpty)
        let status = try XCTUnwrap(result.presentationRows[result.inputs[0].id])
        XCTAssertTrue(status.reason.contains("Keychain"))
        XCTAssertTrue(status.nextStep.contains("Settings"))
        XCTAssertTrue(status.input.windows.isEmpty)
        XCTAssertEqual(status.input.dataState, .unavailable)
    }

    func testAccountAgePreservesOriginalObservationAndNeverUsesRenderTime() throws {
        let joined = try snapshot(accounts: [account(nil, source: "codex", windows: [window()])])
        let row = try XCTUnwrap(adapt(joined).presentationRows.values.first)
        XCTAssertEqual(row.originalObservedAt, now.addingTimeInterval(-5))
        XCTAssertTrue(row.sourceAndAge(at: now).contains("<1m"))
        XCTAssertTrue(row.sourceAndAge(at: now.addingTimeInterval(10)).contains("<1m"))
        XCTAssertTrue(row.sourceAndAge(at: now.addingTimeInterval(60)).contains("1m"))
        XCTAssertTrue(row.sourceAndAge(at: now.addingTimeInterval(3600)).contains("1h"))
        XCTAssertTrue(row.sourceAndAge(at: now.addingTimeInterval(-10)).contains("unknown"))
    }
    func testReaderDiagnosticsUseDecodedCurrentZeroWithoutAddingMembership() throws {
        let joined = try readerSnapshot(accounts: [account("real", source: "codex", windows: [window(remaining: 0)])],
            extras: ["sources": [["source": "codex", "status": "ok"]]])
        var ready = StoreDiagnostics(); ready.personal = nil
        let result = CommunityDockSnapshot(snapshot: joined, diagnostics: ready, now: now,
            readerFacts: [.init(providerID: "codex", consent: .allowed, beta: true)])
        XCTAssertEqual(result.inputs.map(\.id), ["real"])
        XCTAssertEqual(result.inputs[0].windows[0].remainingPercent, 0)
        XCTAssertEqual(result.readerDiagnostics.first?.freshness, .fresh)
        XCTAssertEqual(result.readerDiagnostics.first?.english, "A current local reading is available.")
        XCTAssertEqual(result.readerDiagnostics.first?.beta, true)
        XCTAssertNil(result.emptyDiagnostic)
        XCTAssertNil(result.unavailableReason)
    }
    func testReaderExplicitConnectionGapHasEmptyCopyWithoutInventingRowOrDenial() throws {
        var ready = StoreDiagnostics(); ready.personal = nil
        let result = CommunityDockSnapshot(snapshot: nil, diagnostics: ready, now: now,
            readerFacts: [.init(providerID: "claude", blockedCode: "not-connected-yet")])
        XCTAssertTrue(result.inputs.isEmpty)
        XCTAssertTrue(result.subscriptions.isEmpty)
        XCTAssertEqual(result.emptyDiagnostic?.english, "Reader connection is not complete yet.")
        XCTAssertEqual(result.emptyDiagnostic?.consent, .unknown)
        XCTAssertEqual(result.emptyDiagnostic?.detection, .unknown)
        XCTAssertEqual(result.unavailableReason, "personal-not-loaded", "legacy raw contract is unchanged")
    }
    func testReaderUnboundStaleMeterKeepsOwnershipAndFreshnessSeparate() throws {
        let joined = try readerSnapshot(accounts: [account(nil, source: "codex", windows: [window()])],
            extras: ["sources": [["source": "codex", "status": "stale"]]])
        let result = adapt(joined), reader = try XCTUnwrap(result.readerDiagnostics.first)
        XCTAssertEqual(reader.category, .unbound)
        XCTAssertEqual(reader.freshness, .stale)
        XCTAssertEqual(reader.consent, .unknown)
        XCTAssertEqual(result.emptyDiagnostic?.category, .unbound)
        XCTAssertEqual(result.inputs.count, 1)
        XCTAssertTrue(result.subscriptions.isEmpty)
        XCTAssertNil(result.inputs[0].windows.first?.remainingPercent)
    }
    func testReaderUnknownSourceStatusDoesNotInventFailureOrDenial() throws {
        let joined = try readerSnapshot(accounts: [], extras: ["sources": [["source": "codex",
            "status": "future-status", "reason": "/synthetic/private/alice@example.invalid"]]])
        let result = adapt(joined), reader = try XCTUnwrap(result.readerDiagnostics.first)
        XCTAssertEqual(reader.category, .unknown)
        XCTAssertEqual(reader.freshness, .unknown)
        XCTAssertEqual(reader.consent, .unknown)
        XCTAssertEqual(reader.english, "Reader status is unknown.")
        XCTAssertTrue(result.inputs.isEmpty)
    }
    func testReaderUnverifiedAccountMetadataDoesNotClaimUsageWasRead() throws {
        let result = adapt(try readerSnapshot(accounts: [account(nil, source: "codex", windows: [])]))
        XCTAssertEqual(result.emptyDiagnostic?.english, "Subscription binding is not verified.")
        XCTAssertEqual(result.emptyDiagnostic?.chinese, "订阅归属尚未验证。")
        XCTAssertEqual(result.inputs.count, 1)
        XCTAssertTrue(result.subscriptions.isEmpty)
        XCTAssertTrue(result.inputs[0].windows.isEmpty)
    }
    private func readerSnapshot(accounts: [[String: Any]], generated: TimeInterval = -10,
                                valid: TimeInterval = 300, extras: [String: Any] = [:]) throws -> JoinedSnapshot {
        var v1 = extras; v1["contractVersion"] = 1
        return try snapshot(accounts: accounts, generated: generated, valid: valid, extras: v1)
    }
    func testReaderDecodedPresenceAndAuthorizationCapabilityDoNotProveConsentOrBinding() throws {
        let joined = try readerSnapshot(accounts: [account(nil, source: "codex", windows: [window(remaining: 0)])], extras: [
            "connections": [["id": "codex", "installed": ["status": "yes"],
                "authorization": ["status": "yes", "via": "agent-owned-reader"],
                "quota": ["status": "yes", "binding": "unknown"]]],
        ])
        let result = adapt(joined), reader = try XCTUnwrap(result.readerDiagnostics.first)
        XCTAssertEqual(reader.detection, .detected)
        XCTAssertEqual(reader.consent, .unknown)
        XCTAssertEqual(reader.category, .unbound)
        XCTAssertEqual(result.emptyDiagnostic?.category, .unbound)
        XCTAssertNil(result.unavailableReason)
        XCTAssertEqual(result.inputs.count, 1)
        XCTAssertTrue(result.subscriptions.isEmpty)
        XCTAssertTrue(result.subscriptions.isEmpty)
    }
    func testReaderNotDetectedRequiresExplicitPresenceEvidence() throws {
        let missing = adapt(try readerSnapshot(accounts: [], extras: [
            "sources": [["source": "codex", "status": "missing", "reason": "not-found"]],
        ]))
        XCTAssertEqual(missing.readerDiagnostics.first?.detection, .unknown)
        XCTAssertEqual(missing.readerDiagnostics.first?.category, .unavailable)
        let absent = adapt(try readerSnapshot(accounts: [], extras: [
            "connections": [["id": "codex", "installed": ["status": "no", "reason": "not-found"]]],
        ]))
        XCTAssertEqual(absent.readerDiagnostics.first?.detection, .notDetected)
        XCTAssertEqual(absent.emptyDiagnostic?.category, .notDetected)
        XCTAssertEqual(absent.readerDiagnostics.first?.consent, .unknown)
    }
    func testReaderGlobalOffAndConsentChangedRemainDifferentFromDenial() throws {
        let cases: [(String, CommunityReaderReasonCategory)] = [
            ("reader-privacy", .readersOff), ("consent-changed", .consentChanged),
        ]
        for (code, expected) in cases {
            let result = adapt(try readerSnapshot(accounts: [], extras: [
                "sources": [["source": "readers", "status": "off", "reason": code]],
            ]))
            XCTAssertEqual(result.emptyDiagnostic?.category, expected)
            XCTAssertEqual(result.readerDiagnostics.first?.consent, .unknown)
            XCTAssertTrue(result.inputs.isEmpty)
        }
    }
    func testReaderEmptyOrRawReasonCannotInventAnIntegrationGap() throws {
        let empty = adapt(try readerSnapshot(accounts: []))
        XCTAssertEqual(empty.emptyDiagnostic?.category, .unknown)
        XCTAssertTrue(empty.readerDiagnostics.isEmpty)
        let raw = adapt(try readerSnapshot(accounts: [], extras: [
            "sources": [["source": "claude-code", "status": "ok", "reason": "not-connected-yet"]],
        ]))
        XCTAssertEqual(raw.emptyDiagnostic?.category, .unknown)
        XCTAssertEqual(raw.readerDiagnostics.first?.consent, .unknown)
        XCTAssertTrue(raw.inputs.isEmpty)
    }
    func testReaderStaleAndUnknownObservationCannotSupplyCurrentValues() throws {
        let expired = adapt(try readerSnapshot(accounts: [account("real", source: "codex", windows: [window()])], valid: -1))
        XCTAssertEqual(expired.readerDiagnostics.first?.freshness, .stale)
        XCTAssertEqual(expired.readerDiagnostics.first?.category, .stale)
        XCTAssertEqual(expired.inputs.map(\.id), ["real"])
        XCTAssertNil(expired.inputs[0].windows[0].remainingPercent)
        var unknownTime = account("real", source: "codex", windows: [window()])
        unknownTime.removeValue(forKey: "observedAt")
        var unknownWindow = window(); unknownWindow.removeValue(forKey: "observedAt")
        unknownTime["windows"] = [unknownWindow]
        let unknown = adapt(try readerSnapshot(accounts: [unknownTime]))
        XCTAssertEqual(unknown.readerDiagnostics.first?.freshness, .unknown)
        XCTAssertNil(unknown.inputs[0].windows[0].remainingPercent)
        XCTAssertNil(unknown.emptyDiagnostic)
    }
    func testReaderMissingRevisionAndMismatchedPublicationCannotCreateMembershipOrQuota() throws {
        let publication = try FeedDecoder.publication(Data(#"{"schemaVersion":1,"contractVersion":1,"publicationId":"synthetic-public-other","units":{"ability":"points","cost":"reference","time":"seconds"},"models":[{"id":"public-only"}],"lineups":[]}"#.utf8))
        for id in [nil, "real"] as [String?] {
            let source = try readerSnapshot(accounts: [account(id, source: "codex", windows: [window(remaining: 0)])],
                extras: ["publication": ["publicationId": "synthetic-personal"]])
            XCTAssertNil(source.personal.dataRevision)
            let joined = JoinedSnapshot.make(personal: source.personal, presentation: source.presentation, publication: publication)
            XCTAssertEqual(joined.scoredUnavailableReason, "publication-mismatch")
            let result = adapt(joined)
            XCTAssertEqual(result.inputs.map(\.id), id.map { [$0] } ?? ["presentation.account.0"])
            XCTAssertEqual(result.subscriptions.map(\.id), id.map { [$0] } ?? [])
            XCTAssertFalse(result.inputs.contains { $0.id == "public-only" })
            if id == nil {
                XCTAssertEqual(result.emptyDiagnostic?.category, .unbound)
            } else {
                XCTAssertEqual(result.inputs[0].windows[0].remainingPercent, 0)
                XCTAssertNil(result.emptyDiagnostic)
            }
        }
    }
    func testReaderRawLegacyFailureAndUnknownBetaNeverBecomeDiagnosticCopy() throws {
        let raw = "/synthetic/private/alice@example.invalid/auth.json"
        var failed = StoreDiagnostics(); failed.personal = raw
        let missing = adapt(nil, diagnostics: failed)
        XCTAssertEqual(missing.unavailableReason, raw, "the existing raw contract is preserved")
        XCTAssertEqual(missing.emptyDiagnostic?.category, .unavailable)
        XCTAssertFalse((missing.emptyDiagnostic!.english + missing.emptyDiagnostic!.chinese).contains(raw))
        let joined = try readerSnapshot(accounts: [account(nil, source: raw, windows: [])], extras: [
            "sources": [["source": raw, "status": "unreadable", "reason": raw, "beta": true]],
        ])
        let result = adapt(joined), reader = try XCTUnwrap(result.readerDiagnostics.first)
        XCTAssertNil(reader.providerID)
        XCTAssertNil(reader.beta, "Core does not expose beta yet; the mapper must not infer it")
        XCTAssertFalse(String(reflecting: reader).contains(raw))
        XCTAssertEqual(result.inputs.count, 1)
        XCTAssertTrue(result.subscriptions.isEmpty)
        XCTAssertFalse(result.inputs[0].name.contains(raw))
    }
    func testReaderEmptyAuthorizationDoesNotBecomeGranted() throws {
        let result = adapt(try readerSnapshot(accounts: [], extras: [
            "connections": [["id": "native:cursor", "installed": ["status": "yes"],
                "authorization": ["status": ""], "quota": ["status": "no", "binding": "unknown"]]],
        ]))
        XCTAssertEqual(result.readerDiagnostics.first?.consent, .unknown)
        XCTAssertTrue(result.inputs.isEmpty)
    }
    func testReaderMissingLifetimeRemainsUnknownRatherThanClaimingOldAge() throws {
        let object: [String: Any] = ["schemaVersion": 1, "contractVersion": 1,
            "kind": "modelplan.personal-snapshot", "generatedAt": instant(-10),
            "accounts": [account("real", source: "codex", windows: [window()])]]
        let personal = try FeedDecoder.personal(JSONSerialization.data(withJSONObject: object))
        XCTAssertFalse(personal.validUntilReported)
        var ledger = ExpiryLedger()
        let joined = JoinedSnapshot.make(personal: personal,
            presentation: PersonalProjection.evaluate(personal, now: now, ledger: &ledger), publication: nil)
        let result = adapt(joined)
        XCTAssertEqual(result.readerDiagnostics.first?.freshness, .unknown)
        XCTAssertEqual(result.readerDiagnostics.first?.category, .unavailable)
        XCTAssertEqual(result.inputs.map(\.id), ["real"])
        XCTAssertNil(result.inputs[0].windows[0].remainingPercent)
        XCTAssertEqual(result.unavailableReason, "unknown-lifetime")
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
        XCTAssertEqual(result.inputs.map(\.id), ["member-only", "bound", "uncertain", "presentation.account.1"])
        XCTAssertEqual(result.subscriptions.map(\.id), ["member-only", "bound", "uncertain"])
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
        XCTAssertEqual(host.dockView.accessibilityChildren()?.count ?? 0, 0, "no editable default pixels before authoritative Settings restore")
        var context = SettingsPageContext(); context.subscriptions = adapt(joined).subscriptions
        let coordinator = SettingsApplicationCoordinator(store: store, context: context) { host.apply($0) }
        await coordinator.reload()
        XCTAssertEqual(host.dockView.accessibilityChildren()?.count, 2)
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

    func testReentrantAppearanceReplacementFeedPublishesNewestRows() async throws {
        let first = try snapshot(accounts: [account("a", windows: [window()])])
        let replacement = try snapshot(accounts: [account("b", windows: [window()])])
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("dock-reentrant-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var host: StaticDockPreviewHost!
        var replaced = false, rowsSeen: [[String]] = []
        var ready = StoreDiagnostics(); ready.personal = nil
        host = StaticDockPreviewHost(appearance: { view, rows, _ in
            if !replaced { replaced = true; host.render(snapshot: replacement, diagnostics: ready) }
            try view.applyCommunity(rows)
            rowsSeen.append(rows.map(\.subscriptionID))
            return .init(hoverRects: [view.bounds])
        }, currentDate: { self.now }, createsNativePanels: false)
        let coordinator = SettingsApplicationCoordinator(store: try SettingsStore(url: directory.appendingPathComponent("settings.json"))) { host.apply($0) }
        host.render(snapshot: first, diagnostics: ready)
        await coordinator.reload()
        XCTAssertEqual(rowsSeen.last, ["b"], "nested feed must queue another pass")
        host.close()
    }
    func testReentrantAppearanceSettingsAndCloseCannotPublishOldState() async throws {
        let joined = try snapshot(accounts: [account("a", windows: [window()])])
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("dock-reentrant-settings-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var context = SettingsPageContext(); context.subscriptions = adapt(joined).subscriptions
        let coordinator = SettingsApplicationCoordinator(store: try SettingsStore(url: directory.appendingPathComponent("settings.json")), context: context) { _ in }
        await coordinator.reload(); let original = try XCTUnwrap(coordinator.latest)
        _ = try await coordinator.editor.commit(.alias(AliasDraft(subscriptionID: "a", committed: "new alias")))
        let newer = try XCTUnwrap(coordinator.latest)
        var host: StaticDockPreviewHost!, replaced = false, aliases: [String?] = []
        host = StaticDockPreviewHost(appearance: { view, rows, _ in
            if !replaced { replaced = true; host.apply(newer) }
            try view.applyCommunity(rows); aliases.append(rows.first?.alias)
            return .init(hoverRects: [view.bounds])
        }, currentDate: { self.now }, createsNativePanels: false)
        var ready = StoreDiagnostics(); ready.personal = nil
        host.render(snapshot: joined, diagnostics: ready); host.apply(original)
        XCTAssertEqual(aliases.last!, "new alias")
        host.close()
        var closing: StaticDockPreviewHost!
        closing = StaticDockPreviewHost(appearance: { view, rows, _ in
            closing.close(); try view.applyCommunity(rows)
            return .init(hoverRects: [view.bounds])
        }, currentDate: { self.now }, createsNativePanels: false)
        closing.render(snapshot: joined, diagnostics: ready); closing.apply(original)
        XCTAssertEqual(closing.dockView.accessibilityChildren()?.count ?? 0, 0, "appearance callout cannot resurrect a closed view")
    }
    func testActualHostPresentsAccountAndConnectionRowsWithAgeAndLiveSettingsActions() async throws {
        _ = NSApplication.shared
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        for official in [false, true] {
            for accountRow in [false, true] {
                let joined = try snapshot(accounts: accountRow ? [account(nil, source: "codex", windows: [window()])] : [],
                    extras: accountRow ? [:] : ["connections": [["id": "claude", "authorization": ["status": "yes"],
                        "quota": ["status": "no", "reason": "consent_required"]]]])
                let readback = try canonicalConsent(accountRow ? [] : ["claude"])
                let id = try XCTUnwrap(adapt(joined, canonicalConsent: readback).inputs.first?.id)
                var supplied = [DockInstrumentReading]()
                let appearance: StaticDockPreviewHost.Appearance?
                if official {
                    appearance = { view, rows, _ in
                        supplied = rows; try view.applyCommunity(rows)
                        return StaticDockGeometry(hoverRects: [view.bounds])
                    }
                } else { appearance = nil }
                let host = StaticDockPreviewHost(appearance: appearance, currentDate: { self.now }, createsNativePanels: false)
                defer { host.close() }
                let folder = FileManager.default.temporaryDirectory.appendingPathComponent("source-row-host-" + UUID().uuidString)
                defer { try? FileManager.default.removeItem(at: folder) }
                let coordinator = SettingsApplicationCoordinator(store: try SettingsStore(url: folder.appendingPathComponent("settings.json"))) { host.apply($0) }
                var settings = 0, console = 0
                host.showSettings = { settings += 1 }; host.showConsole = { console += 1 }
                await coordinator.reload()
                var ready = StoreDiagnostics(); ready.personal = nil
                host.updateDockConsent(readback)
                host.render(snapshot: joined, diagnostics: ready); host.setPresentationAllowed(true)
                if official { XCTAssertEqual(supplied.map(\.subscriptionID), [id]) }
                XCTAssertNil(host.nativePanel)
                host.dockView.onAction?(.subscription(id))
                let labels = descendants(host.card).compactMap { $0 as? NSTextField }
                let source = try XCTUnwrap(labels.first { $0.accessibilityIdentifier() == "dock.card.text.source" })
                XCTAssertTrue(source.stringValue.contains(accountRow ? "<1m" : "unknown"))
                XCTAssertEqual(source.accessibilityLabel(), source.stringValue)
                if !accountRow { XCTAssertTrue(labels.contains { $0.stringValue.contains("Keychain") }) }
                let button = try XCTUnwrap(descendants(host.card).compactMap { $0 as? NSButton }.first { $0.title == "Settings / 设置" })
                let target = try XCTUnwrap(button.target as? NSObject), action = try XCTUnwrap(button.action)
                _ = target.perform(action, with: button)
                XCTAssertEqual(settings, 1); XCTAssertEqual(console, 0)
                host.dockView.onAction?(.subscription(id))
                let retained = try XCTUnwrap(descendants(host.card).compactMap { $0 as? NSButton }.first { $0.title == "Settings / 设置" })
                let retainedTarget = try XCTUnwrap(retained.target as? NSObject), retainedAction = try XCTUnwrap(retained.action)
                _ = try await coordinator.editor.commit(.showDock(false))
                _ = retainedTarget.perform(retainedAction, with: retained)
                XCTAssertEqual(settings, 1, "retired card action must not open Settings")
                XCTAssertNil(host.nativePanel)
            }
        }
    }

    func testNativeReaderNamesAndUnavailableAccountKeepSpecificConnectionRemedy() async throws {
        _ = NSApplication.shared
        for membership in [false, true] {
            var stale = account(membership ? "real" : nil, source: "codexbar:claude", windows: [window()])
            stale["stale"] = true
            let joined = try snapshot(accounts: [stale, account(nil, source: "native:cursor", windows: [window()])],
                extras: ["connections": [["id": "native:claude", "authorization": ["status": "yes"],
                    "quota": ["status": "no", "reason": "consent_required"]]]])
            let model = adapt(joined)
            let status = model.presentationRows.values.first { $0.reason.contains("Keychain") }
            XCTAssertNotNil(status, "an unavailable account must retain its connection's specific remedy")
            guard let status else { continue }
            XCTAssertEqual(status.input.name, "Claude Code")
            XCTAssertTrue(model.inputs.contains { $0.name == "Cursor" && $0.windows.first?.remainingPercent == 75 })
            XCTAssertEqual(model.subscriptions.map(\.id), membership ? ["real"] : [])
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("native-status-host-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: folder) }
            let host = StaticDockPreviewHost(appearance: { view, rows, _ in
                try view.applyCommunity(rows); return StaticDockGeometry(hoverRects: [view.bounds])
            }, currentDate: { self.now }, createsNativePanels: false)
            defer { host.close() }
            let app = SettingsApplicationCoordinator(store: try SettingsStore(url: folder.appendingPathComponent("settings.json"))) { host.apply($0) }
            await app.reload()
            var ready = StoreDiagnostics(); ready.personal = nil
            host.render(snapshot: joined, diagnostics: ready); host.setPresentationAllowed(true)
            let titles = host.menu().items.map(\.title).joined(separator: " ")
            XCTAssertTrue(titles.contains("Claude Code")); XCTAssertTrue(titles.contains("Keychain"))
            XCTAssertFalse(titles.contains("native:")); XCTAssertFalse(titles.contains("consent_required"))
            host.dockView.onAction?(.subscription(status.input.id))
            func labels(_ v: NSView) -> [NSTextField] { (v as? NSTextField).map { [$0] } ?? v.subviews.flatMap(labels) }
            XCTAssertTrue(labels(host.card).contains { $0.stringValue.contains("Keychain") })
            XCTAssertNil(host.nativePanel)
        }
    }

    private func retainedConsoleButton(in view: NSView) throws -> NSButton {
        if let button = view as? NSButton, button.title == "Console / 控制台" { return button }
        for child in view.subviews { if let value = try? retainedConsoleButton(in: child) { return value } }
        throw NSError(domain: "missing-card-console-button", code: 1)
    }
    func testRetainedCardButtonCannotEnterAfterDockHideOrMembershipRemoval() async throws {
        for hide in [true, false] {
            let joined = try snapshot(accounts: [account("a", windows: [window()])])
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("dock-retained-action-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: directory) }
            var context = SettingsPageContext(); context.subscriptions = adapt(joined).subscriptions
            let host = StaticDockPreviewHost(currentDate: { self.now }, createsNativePanels: false)
            var opens = 0; host.showConsole = { opens += 1 }
            let coordinator = SettingsApplicationCoordinator(store: try SettingsStore(url: directory.appendingPathComponent("settings.json")), context: context) { host.apply($0) }
            await coordinator.reload()
            var ready = StoreDiagnostics(); ready.personal = nil
            host.render(snapshot: joined, diagnostics: ready); host.setPresentationAllowed(true)
            host.dockView.onAction?(.subscription("a"))
            let enter = try XCTUnwrap(host.card.onEnter), revision = try XCTUnwrap(coordinator.latest).snapshot.revision
            enter("other", revision); enter("a", revision + 1)
            XCTAssertEqual(opens, 0, "identity/revision mismatches cannot enter")
            let live = try retainedConsoleButton(in: host.card)
            _ = (try XCTUnwrap(live.target as? NSObject)).perform(try XCTUnwrap(live.action), with: live)
            XCTAssertEqual(opens, 1, "a current selector still enters once")
            opens = 0
            host.dockView.onAction?(.subscription("a"))
            let button = try retainedConsoleButton(in: host.card)
            let target = try XCTUnwrap(button.target as? NSObject), action = try XCTUnwrap(button.action)
            if hide { _ = try await coordinator.editor.commit(.showDock(false)) }
            else { host.render(snapshot: try snapshot(accounts: []), diagnostics: ready) }
            _ = target.perform(action, with: button)
            XCTAssertEqual(opens, 0, hide ? "held selector after hide" : "held selector after membership removal")
            host.close()
        }
    }

}
