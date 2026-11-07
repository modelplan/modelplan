// SPDX-License-Identifier: MIT
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import XCTest
import ModelPlanCore
@_spi(DockResourceChecks) import ModelPlanDock
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
@MainActor private final class DiagnosticSettingsSurface: SettingsWindowSurface {
    var pane: String?
    private var waiter: CheckedContinuation<Void,Never>?
    func waitForShow() async { if pane != nil{return};await withCheckedContinuation{waiter=$0} }
    func prepare() async {}
    func show(paneID: String?) { pane = paneID;waiter?.resume();waiter=nil }
    func hide() {}
}
actor EntrySyntheticClient: EngineClient {
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
    enum WindowSources { case captured, distinct, restrictedWithLegacyMember, legacy }

    struct ResetFactsFixture {
        var count = 2
        var expiresIn: TimeInterval = 108_000
        var retainedPartial = false
        var restarted = false
    }

    static func rows(weekly: Double, fiveHour: Double? = nil, secondWeekly: Double? = nil, sequence: Int = 7, weeklyDeadline: String = "2028-12-01T00:00:00Z", resetID: String? = nil, unbound: Bool = false, reserveBalance: Double? = nil, reserveUnit: String = "unknown", resetCardClock: Date? = nil, resetConfirmed: Bool = false, resetFacts: ResetFactsFixture = .init(), windowSources: WindowSources = .captured, readerFailed: Bool = false, includeSession: Bool = true, extraWindow: Bool = false) throws -> WireRowsSnapshot {
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
        row["consent"] = "allowed"; row["state"] = readerFailed ? "failed" : "fresh"; row["surfaces"] = ["dock"]
        row["name"] = ["en": "Synthetic account", "zh": "合成账户"]
        row["expiresAt"] = "2027-01-01T00:00:00Z"
        row["stateAfterExpiry"] = ["state": "stale",
            "reason": ["code": "stale_reading", "text": ["en": "Last known", "zh": "旧读数"]],
            "nextStep": NSNull()]
        if unbound { account["subscriptionRef"] = NSNull() }
        else { account["subscriptionRef"] = "aaaaaaaaaaaaaaaa" }
        account["valueState"] = readerFailed ? "retained" : "current"
        account["observedAt"] = "2026-12-01T00:00:00Z"; account["freshUntil"] = weeklyDeadline
        account["lastFailure"] = NSNull()
        if let reserveBalance { account["credits"] = ["balance": reserveBalance, "unit": reserveUnit] }
        session["id"] = "session:18000:main:main"; session["role"] = "session"
        session["durationSeconds"] = 18000; session["limitKey"] = "main"; session["poolKey"] = "main"
        session.removeValue(forKey: "modelScope"); session["current"] = true
        session["observedAt"] = "2026-12-01T00:00:00Z"
        session["validUntil"] = "2027-01-01T00:00:00Z"; session["resetsAt"] = "2027-01-01T00:00:00Z"
        if let fiveHour { session["remainingPercent"] = fiveHour }
        var week = session
        week["id"] = "weekly:604800:main:main"; week["role"] = "weekly"; week["durationSeconds"] = 604800
        week["remainingPercent"] = weekly; week["validUntil"] = weeklyDeadline
        week["resetsAt"] = weeklyDeadline
        if let wall = resetCardClock {
            let stamp = ISO8601DateFormatter()
            let scheduled = stamp.string(from: wall.addingTimeInterval(3600))
            var event: [String: Any] = ["version": 1, "id": "synthetic-card-reset", "provider": "openai",
                "rowId": "codex", "status": "announced", "publishedAt": stamp.string(from: wall.addingTimeInterval(-60)),
                "expiresAt": stamp.string(from: wall.addingTimeInterval(7200)),
                "schedule": ["precision": "deadline", "from": scheduled, "through": scheduled],
                "source": ["kind": "publication", "publicationId": "synthetic",
                    "url": "https://example.invalid/digest", "links": [
                        ["type": "aihot", "url": "https://aihot.news/example-reset"],
                        ["type": "official", "url": "https://status.openai.com/incidents/demo-reset"],
                        ["type": "original", "url": "https://x.com/OpenAI/status/123"],
                        ["type": "original", "url": "https://x.com/OpenAI/status/123"],
                        ["type": "original", "url": "https://x.com/OpenAI/status/456?token=canary"],
                        ["type": "official", "url": "https://status.openai.com:8443/incidents/demo-reset"],
                        ["type": "official", "url": "https://status.openai.com/incidents/demo-reset#section"],
                        ["type": "publication", "url": "https://example.invalid/invalid-type"]]]]
            if resetConfirmed {
                event["status"] = "confirmed"
                event["confirms"] = "synthetic-card-reset"
                event.removeValue(forKey: "schedule")
            }
            projection["resetEvents"] = [event]
            account["resetCards"] = ["state": resetFacts.retainedPartial ? "partial" : "complete",
                "count": resetFacts.count, "earliestExpiresAt": stamp.string(from: wall.addingTimeInterval(resetFacts.expiresIn)),
                "truncated": resetFacts.retainedPartial, "sources": []]
            if resetFacts.retainedPartial { account["valueState"] = "retained" }
            if resetFacts.restarted {
                let fresh = stamp.string(from: wall.addingTimeInterval(-5))
                account["observedAt"] = fresh
                session["observedAt"] = fresh
                week["observedAt"] = fresh
            }
        }
        if windowSources == .legacy {
            session.removeValue(forKey: "source"); week.removeValue(forKey: "source")
        }
        windows = includeSession ? [session, week] : [week]
        if extraWindow {
            var extra = week
            extra["id"] = "extra"; extra["role"] = "other"; extra["durationSeconds"] = 60; extra["remainingPercent"] = 1
            windows.append(extra)
        }
        if windowSources == .distinct || windowSources == .restrictedWithLegacyMember {
            session["source"] = "local_history"; session["observedAt"] = "2026-12-01T23:23:00Z"
            session["remainingPercent"] = 9
            week["source"] = "runtime"; week["observedAt"] = "2026-12-01T23:49:00Z"
            var extra = week
            extra["id"] = "missing-provenance"; extra["limitKey"] = "code_review"; extra["poolKey"] = "code_review"
            extra.removeValue(forKey: "source"); extra.removeValue(forKey: "observedAt")
            windows = [session, week, extra]
        }
        if windowSources == .restrictedWithLegacyMember {
            var scoped = session
            scoped["id"] = "restricted-runtime"; scoped["limitKey"] = "code_review"; scoped["poolKey"] = "code_review"
            scoped["remainingPercent"] = 38
            windows = [scoped]
        }
        account["windows"] = windows; accounts = [account]
        if let secondWeekly {
            var other = account, otherWeek = week
            other["subscriptionRef"] = "bbbbbbbbbbbbbbbb"; other["accountLocator"] = "bbbbbbbbbbbbbbbb"
            otherWeek["remainingPercent"] = secondWeekly
            var otherSession = session
            if windowSources == .restrictedWithLegacyMember {
                other["route"] = "saved_login_api"
                other["observedAt"] = "2026-12-01T23:37:00Z"
                otherSession.removeValue(forKey: "source")
                otherWeek.removeValue(forKey: "source")
            }
            other["windows"] = [otherSession, otherWeek]; accounts.append(other)
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
        try await deliver(Self.rows(weekly: 75))
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-06-01T00:00:00Z"))
        let first = try paired.make(.init(snapshot: nil, diagnostics: .init(), now: now))
        let input = try XCTUnwrap(first.value.snapshot.inputs.first)
        let reading = try DockInstrumentProjection.evaluate(input, now: now)
        XCTAssertEqual(reading.dataState, .stale); XCTAssertEqual(reading.remainingPercent, 75)
        XCTAssertTrue(paired.isCurrent(first.sourceToken))
        try await deliver(Self.rows(weekly: 33))
        XCTAssertFalse(paired.isCurrent(first.sourceToken), "same sequence cannot hide different admitted bytes")
        paired.invalidate()
        let second = try paired.make(.init(snapshot: nil, diagnostics: .init(), now: now))
        XCTAssertEqual(try DockInstrumentProjection.evaluate(XCTUnwrap(second.value.snapshot.inputs.first), now: now).remainingPercent, 33)
        await store.consume(.clearPrivateViews(.init(revision: 2, reason: .generationAdvanced, previous: context, nextFloor: nil)))
        XCTAssertFalse(paired.isCurrent(second.sourceToken))
    }
    func testD18NormalOptionArrowsSaveAndAnnounceWithEitherReduceMotionSource() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dock-keyboard-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-02T00:00:00Z"))
        let snapshot = try Self.rows(weekly: 75, secondWeekly: 55)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: false,
            dockEnvironment: normalEntryTestEnvironment, deadlineNow: { wall },
            makeClient: { _, store in EntrySyntheticClient(store: store, rows: snapshot) }, activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()

        let application = app.settingsHost.application
        let dock = app.composition.dock, view = dock.dockView
        let first = "aaaaaaaaaaaaaaaa", second = "bbbbbbbbbbbbbbbb"
        var environment = application.editor.environment
        func optionArrow(keyCode: UInt16, order: [String], announcement: String) async throws {
            XCTAssertTrue(dock.interactionEnvironment().reducedMotion)
            let children = (view.accessibilityChildren() ?? []).compactMap { $0 as? NSAccessibilityElement }
            let focused = try XCTUnwrap(children.first { $0.accessibilityIdentifier() == "dock.subscription." + first })
            XCTAssertFalse(try XCTUnwrap(focused.accessibilityLabel()).isEmpty)
            focused.setAccessibilityFocused(true)
            let key = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.option],
                timestamp: 0, windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
                isARepeat: false, keyCode: keyCode))
            view.keyDown(with: key)
            let deadline = ContinuousClock.now + .seconds(2)
            while (view.accessibilityValue() as? String)?.hasSuffix(announcement) != true && ContinuousClock.now < deadline {
                try await Task.sleep(for: .milliseconds(10))
            }
            let saved = await settings.snapshot()
            XCTAssertEqual(saved.preferences.subscriptions.order, order)
            XCTAssertTrue((view.accessibilityValue() as? String)?.hasSuffix(announcement) == true)
        }

        environment.reduceMotion = true
        application.update(environment: environment)
        XCTAssertEqual(application.editor.snapshot?.preferences.motion, .system)
        try await optionArrow(keyCode: 125, order: [second, first], announcement: "position 2 of 2")

        environment.reduceMotion = false
        application.update(environment: environment)
        _ = try await application.editor.commit(SettingsB20Edit.motion(.on))
        try await optionArrow(keyCode: 126, order: [first, second], announcement: "position 1 of 2")
    }

    func testNormalSettingsQuotaControlsDriveTheDisplayedMembers() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("quota-settings-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-02T00:00:00Z"))
        let snapshot = try Self.rows(weekly: 25, secondWeekly: 20)
        func start() async throws -> EngineDockMenuApplication {
            let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
            let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
                applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: store, createsNativePanels: false,
                dockEnvironment: normalEntryTestEnvironment, deadlineNow: { wall },
                makeClient: { _, store in EntrySyntheticClient(store: store, rows: snapshot) }, activateSettings: {})
            addTeardownBlock { @MainActor in await app.composition.stop() }
            await app.prepare(); app.allowDockPresentation(); await app.composition.start()
            return app
        }
        let app = try await start()
        let editor = app.settingsHost.application.editor
        let original = try XCTUnwrap(editor.snapshot)
        let rows = try SettingsCatalogue.rows(preferences: original.preferences, context: editor.context)
        for key in [SettingKey.redBelow, .showPercentages, .percentageMode, .percentagePin] {
            XCTAssertEqual(rows.first { $0.key == key }?.availability, .available, key.rawValue)
        }
        XCTAssertEqual(original.preferences.redBelow, 25)

        let view = app.composition.dock.dockView
        let first = "aaaaaaaaaaaaaaaa", second = "bbbbbbbbbbbbbbbb"
        func reading(_ id: String) throws -> DockInstrumentReading { try XCTUnwrap(view.presentedReadingsForChecks[id]) }
        XCTAssertEqual(try reading(first).readout, "25%")
        XCTAssertEqual(try reading(first).status, .critical)
        XCTAssertNotNil(view.helpReadoutAnchor(first))
        let thresholdRow = try XCTUnwrap(rows.first { $0.key == .redBelow })
        guard case .choice(let selected, let options) = thresholdRow.value else { return XCTFail("Expected threshold choices") }
        XCTAssertEqual(selected, "25")
        for option in options {
            let threshold = try XCTUnwrap(Int(option))
            _ = try await editor.commit(SettingsB20Edit.redBelow(threshold))
            XCTAssertEqual(try reading(first).status, threshold >= 25 ? .critical : .warning, option)
            XCTAssertEqual(try reading(second).status, threshold >= 20 ? .critical : .warning, option)
        }
        _ = try await editor.commit(SettingsB20Edit.redBelow(20))
        XCTAssertEqual(try reading(first).status, .warning)
        XCTAssertEqual(try reading(second).readout, "20%")
        XCTAssertEqual(try reading(second).status, .critical)
        _ = try await editor.commit(SettingsB20Edit.percentagePin(first, .fiveHour))
        XCTAssertEqual(try reading(first).selectedWindowID, "session:18000:main:main")
        XCTAssertEqual(try reading(second).selectedWindowID, "weekly:604800:main:main")
        _ = try await editor.commit(SettingsB20Edit.percentagePin(first, .week))
        XCTAssertEqual(try reading(first).readout, "25%")
        _ = try await editor.commit(SettingsB20Edit.percentageMode(.used))
        XCTAssertEqual(try reading(first).readout, "75%")
        XCTAssertEqual(try reading(second).readout, "80%")
        XCTAssertEqual(try reading(second).status, .critical, "the threshold still applies to remaining quota")
        _ = try await editor.commit(SettingsB20Edit.showPercentages(false))
        XCTAssertNil(view.helpReadoutAnchor(first))
        XCTAssertNil(view.helpReadoutAnchor(second))
        _ = try await editor.commit(SettingsB20Edit.showPercentages(true))
        XCTAssertNotNil(view.helpReadoutAnchor(first))
        await app.composition.stop()

        let relaunched = try await start()
        let restored = try XCTUnwrap(relaunched.settingsHost.application.editor.snapshot)
        XCTAssertEqual(restored.preferences.redBelow, 20)
        let restoredReadings = relaunched.composition.dock.dockView.presentedReadingsForChecks
        XCTAssertEqual(restoredReadings[first]?.status, .warning)
        XCTAssertEqual(restoredReadings[second]?.status, .critical)
        XCTAssertEqual(restoredReadings[first]?.readout, "75%")

    }

    func testS11PulseBandsReachTheRenderedRingsReadoutsAndCardRows() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dock-bands-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-02T00:00:00Z"))
        let fixture = try Self.rows(weekly: 50, secondWeekly: 51)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: false,
            dockEnvironment: normalEntryTestEnvironment, deadlineNow: { wall }, deadlineScheduling: EntryDeadlineTimer(),
            makeClient: { _, store in EntrySyntheticClient(store: store, rows: fixture) }, activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        let dock = app.composition.dock, view = dock.dockView
        let first = "aaaaaaaaaaaaaaaa", second = "bbbbbbbbbbbbbbbb"
        let editor = app.settingsHost.application.editor
        for id in [first, second] { _ = try await editor.commit(SettingsB20Edit.percentagePin(id, .week)) }

        func assertBand(_ id: String, _ expected: DockQuotaStatus, line: UInt = #line) throws {
            let reading = try XCTUnwrap(view.presentedReadingsForChecks[id], line: line)
            XCTAssertEqual(reading.status, expected, line: line)
            XCTAssertEqual(reading.inner?.status, expected, line: line)
            let card = try XCTUnwrap(dock.cardContent(for: id, at: wall), line: line)
            XCTAssertEqual(card.rows.first { $0.id == "quota:weekly:604800:main:main" }?.tone, expected, line: line)
        }
        try assertBand(first, .warning)
        try assertBand(second, .normal)

        let delivery = try XCTUnwrap(app.composition.store.snapshot.delivery)
        var sequence = Int(fixture.sequence)
        func deliver(weekly: Double, secondWeekly: Double) async throws {
            sequence += 1
            let snapshot = try Self.rows(weekly: weekly, secondWeekly: secondWeekly, sequence: sequence)
            let reply = try EngineReply(envelope: .init(sessionId: delivery.sessionID, storeEpoch: delivery.floor.storeEpoch,
                consentGeneration: delivery.floor.generation, data: snapshot), delivery: delivery)
            await app.composition.store.consume(.rowsChanged(reply, invalidRowCount: snapshot.projection.invalidRowCount))
        }
        try await deliver(weekly: 25, secondWeekly: 10)
        try assertBand(first, .critical)
        try assertBand(second, .critical)
        _ = try await editor.commit(SettingsB20Edit.redBelow(10))
        try assertBand(first, .warning)
        try assertBand(second, .critical)

        let saved = try XCTUnwrap(editor.snapshot)
        let settingsRows = try SettingsCatalogue.rows(preferences: saved.preferences, context: editor.context)
        let thresholdRow = try XCTUnwrap(settingsRows.first { $0.key == .redBelow })
        guard case .choice(_, let options) = thresholdRow.value else { return XCTFail("Expected threshold choices") }
        for option in options {
            let threshold = try XCTUnwrap(Int(option))
            _ = try await editor.commit(SettingsB20Edit.redBelow(threshold))
            try await deliver(weekly: Double(threshold), secondWeekly: Double(threshold) + 1)
            try assertBand(first, .critical)
            try assertBand(second, .warning)
        }
    }

    func testNormalEntryReprojectsAtVerifiedDeadlineWithoutNewRowsAndClearsOnRevoke() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("paired-entry-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        var wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-06-01T00:00:00Z")), elapsed = 0.0
        let timer = EntryDeadlineTimer(), snapshot = try Self.rows(weekly: 75)
        var acceptedStore: EngineStore?
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: false,
            dockEnvironment:normalEntryTestEnvironment, deadlineNow: { wall }, deadlineElapsed: { elapsed }, deadlineScheduling: timer,
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
        let timer = EntryDeadlineTimer(), snapshot = try Self.rows(weekly: 75, secondWeekly: 33)
        var acceptedStore: EngineStore?
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: false,
            dockEnvironment:normalEntryTestEnvironment, deadlineNow: { wall }, deadlineElapsed: { elapsed }, deadlineScheduling: timer,
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
        try await replace(Self.rows(weekly: 66, secondWeekly: 22, sequence: 8))
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
        try await replace(Self.rows(weekly: 55, secondWeekly: 11, sequence: 9, weeklyDeadline: "2029-12-01T00:00:00Z"))
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
        try await deliver(Self.rows(weekly: 75, resetID: "reset-one"))
        let first = try paired.make(.init(snapshot: nil, diagnostics: .init(), now: now))
        XCTAssertEqual(first.value.signals.first?.reset?.id, "reset-one")
        try await deliver(Self.rows(weekly: 75, resetID: "reset-two"))
        XCTAssertFalse(paired.isCurrent(first.sourceToken), "reset event bytes belong to the same delivery as rows")
        paired.invalidate()
        let second = try paired.make(.init(snapshot: nil, diagnostics: .init(), now: now))
        XCTAssertEqual(second.value.signals.first?.reset?.id, "reset-two")
    }

    func testNormalCardShowsEachAdmittedWindowsOwnSourceAndAge() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("window-provenance-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-02T00:00:00Z"))
        let readings = try Self.rows(weekly: 75, windowSources: .distinct)
        var elapsed = 0.0
        let display = DockDisplayArea(id: "synthetic", frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 880))
        var pointer = CGPoint(x: 700, y: 450)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: false,
            dockEnvironment: { .init(displays: [display], layouts: [], primaryDisplayID: display.id, pointer: pointer) },
            deadlineNow: { wall }, deadlineElapsed: { elapsed }, deadlineScheduling: EntryDeadlineTimer(),
            makeClient: { _, store in EntrySyntheticClient(store: store, rows: readings) }, activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()

        let id = "aaaaaaaaaaaaaaaa", dock = app.composition.dock, view = dock.dockView
        let placement = try XCTUnwrap(dock.edgePresentation?.placement)
        let anchor = try XCTUnwrap(view.interactionAnchor(id))
        pointer = CGPoint(x: placement.frame.minX + anchor.midX - view.bounds.minX,
            y: placement.frame.maxY - anchor.midY + view.bounds.minY)
        try XCTUnwrap(view.nozzleEventDelegate).hoverNozzle(id)
        elapsed += 0.251; dock.interactionControllerForChecks?.refresh()
        XCTAssertFalse(dock.card.isHidden)
        func text(_ root: NSView, named name: String) -> String? {
            if let field = root as? NSTextField, field.accessibilityIdentifier() == "dock.card.text." + name { return field.stringValue }
            return root.subviews.lazy.compactMap { text($0, named: name) }.first
        }
        XCTAssertEqual(text(dock.card, named: "source"), "Local history · 37m ago")
        XCTAssertTrue(text(dock.card, named: "row.quota:session:18000:main:main.detail")?.contains("Local history · 37m ago") == true)
        XCTAssertTrue(text(dock.card, named: "row.quota:weekly:604800:main:main.detail")?.contains("Tool runtime · 11m ago") == true)
        XCTAssertTrue(text(dock.card, named: "row.quota:missing-provenance.detail")?.contains("Unknown source · Reading time unknown") == true)
        _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.language(.chinese))
        XCTAssertEqual(text(dock.card, named: "source"), "本地历史 · 37分钟前")
        XCTAssertTrue(text(dock.card, named: "row.quota:weekly:604800:main:main.detail")?.contains("工具运行时 · 11分钟前") == true)
        XCTAssertTrue(text(dock.card, named: "row.quota:missing-provenance.detail")?.contains("未知来源 · 读数时间未知") == true)
        _ = try await app.settingsHost.application.editor.commit(SettingsB20Edit.percentagePin(id, .week))
        XCTAssertEqual(text(dock.card, named: "source"), "工具运行时 · 11分钟前")
    }

    func testNormalCardRetainsAccountProvenanceForRestrictedAndSourceLessMembers() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dock-restricted-provenance-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-02T00:00:00Z"))
        let snapshot = try Self.rows(weekly: 75, secondWeekly: 55, windowSources: .restrictedWithLegacyMember)
        let display = DockDisplayArea(id: "synthetic", frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 880))
        var pointer = CGPoint(x: 700, y: 450), elapsed = 0.0
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: false,
            dockEnvironment: { .init(displays: [display], layouts: [], primaryDisplayID: display.id, pointer: pointer) },
            deadlineNow: { wall }, deadlineElapsed: { elapsed }, deadlineScheduling: EntryDeadlineTimer(),
            makeClient: { _, store in EntrySyntheticClient(store: store, rows: snapshot) }, activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()

        let dock = app.composition.dock, view = dock.dockView
        let placement = try XCTUnwrap(dock.edgePresentation?.placement)
        let events = try XCTUnwrap(view.nozzleEventDelegate)
        func open(_ id: String) throws {
            let anchor = try XCTUnwrap(view.interactionAnchor(id))
            pointer = CGPoint(x: placement.frame.minX + anchor.midX - view.bounds.minX,
                y: placement.frame.maxY - anchor.midY + view.bounds.minY)
            events.hoverNozzle(id)
            elapsed += 0.251
            dock.interactionControllerForChecks?.refresh()
            XCTAssertFalse(dock.card.isHidden)
        }
        func text(_ name: String, in root: NSView) -> String? {
            if let field = root as? NSTextField, field.accessibilityIdentifier() == "dock.card.text." + name { return field.stringValue }
            return root.subviews.lazy.compactMap { text(name, in: $0) }.first
        }

        let restricted = "aaaaaaaaaaaaaaaa"
        XCTAssertNil(try XCTUnwrap(view.presentedReadingsForChecks[restricted]).outer)
        try open(restricted)
        XCTAssertEqual(text("source", in: dock.card), "Saved sign-in · 24h ago")
        XCTAssertEqual(text("row.quota:restricted-runtime.value", in: dock.card), "38%")
        XCTAssertTrue(text("row.quota:restricted-runtime.detail", in: dock.card)?.contains("Local history · 37m ago") == true)
        let editor = app.settingsHost.application.editor
        _ = try await editor.commit(SettingsB21Edit.language(.chinese))
        XCTAssertEqual(text("source", in: dock.card), "已有登录 · 24小时前")
        XCTAssertEqual(text("row.quota:restricted-runtime.value", in: dock.card), "38%")
        XCTAssertTrue(text("row.quota:restricted-runtime.detail", in: dock.card)?.contains("本地历史 · 37分钟前") == true)
        XCTAssertNil(try XCTUnwrap(view.presentedReadingsForChecks[restricted]).outer)
        _ = try await editor.commit(SettingsB21Edit.language(.english))

        dock.interactionControllerForChecks?.dismissCard()
        events.hoverNozzle(nil)
        try open("bbbbbbbbbbbbbbbb")
        XCTAssertEqual(text("source", in: dock.card), "Saved sign-in · 23m ago")
        XCTAssertEqual(text("row.source.label", in: dock.card), "Source")
        XCTAssertEqual(text("row.source.value", in: dock.card), "Saved sign-in")
        _ = try await editor.commit(SettingsB21Edit.language(.chinese))
        XCTAssertEqual(text("source", in: dock.card), "已有登录 · 23分钟前")
        XCTAssertEqual(text("row.source.label", in: dock.card), "来源")
        XCTAssertEqual(text("row.source.value", in: dock.card), "已有登录")
        _ = try await editor.commit(SettingsB21Edit.language(.english))

        dock.interactionControllerForChecks?.dismissCard()
        events.hoverNozzle(nil)
        let legacy = try Self.rows(weekly: 55, sequence: 8, windowSources: .legacy)
        XCTAssertTrue(legacy.projection.rows.flatMap(\.accounts).flatMap(\.windows).allSatisfy { $0.source == nil })
        let delivery = try XCTUnwrap(app.composition.store.snapshot.delivery)
        let reply = try EngineReply(envelope: .init(sessionId: delivery.sessionID, storeEpoch: delivery.floor.storeEpoch,
            consentGeneration: delivery.floor.generation, data: legacy), delivery: delivery)
        await app.composition.store.consume(.rowsChanged(reply, invalidRowCount: legacy.projection.invalidRowCount))
        try open(restricted)
        XCTAssertEqual(text("source", in: dock.card), "Saved sign-in · 24h ago")
        XCTAssertEqual(text("row.source.value", in: dock.card), "Saved sign-in")
        _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.language(.chinese))
        XCTAssertEqual(text("source", in: dock.card), "已有登录 · 24小时前")
        XCTAssertEqual(text("row.source.value", in: dock.card), "已有登录")
    }

    /// DOCK-3.8-07 / D40: the card's reset time uses the prototype's compact form in both languages.
    func testNormalCardResetTimeUsesTheCompactPrototypeFormat() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("reset-copy-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-02T00:00:00Z"))
        let resets = ISO8601DateFormatter().string(from: wall.addingTimeInterval(2 * 3600 + 14 * 60))
        let snapshot = try Self.rows(weekly: 75, weeklyDeadline: resets)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: false,
            dockEnvironment: normalEntryTestEnvironment, deadlineNow: { wall }, deadlineScheduling: EntryDeadlineTimer(),
            makeClient: { _, store in EntrySyntheticClient(store: store, rows: snapshot) }, activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        let id = "aaaaaaaaaaaaaaaa", dock = app.composition.dock
        func weekly() throws -> String {
            let content = try XCTUnwrap(try dock.cardContent(for: id, at: wall))
            return try XCTUnwrap(content.rows.first { $0.id == "quota:weekly:604800:main:main" }?.detail)
        }
        let english = try weekly()
        XCTAssertTrue(english.hasPrefix("resets 2h14"), english)
        _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.language(.chinese))
        let chinese = try weekly()
        XCTAssertTrue(chinese.hasPrefix("2h14 后重置"), chinese)
    }

    /// G3-06 residual (DOCK-3.8-08): a money balance without a currency is grouped with at
    /// most two decimals, never the raw floating-point value.
    func testNormalCardShowsAMoneyBalanceWithoutTheRawFloat() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("money-balance-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-02T00:00:00Z"))
        let snapshot = try Self.rows(weekly: 75, reserveBalance: 14_207.8550653333, reserveUnit: "money")
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: false,
            dockEnvironment: normalEntryTestEnvironment, deadlineNow: { wall }, deadlineScheduling: EntryDeadlineTimer(),
            makeClient: { _, store in EntrySyntheticClient(store: store, rows: snapshot) }, activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        let id = "aaaaaaaaaaaaaaaa", dock = app.composition.dock
        func balance() throws -> DockCardRow {
            let content = try XCTUnwrap(try dock.cardContent(for: id, at: wall))
            return try XCTUnwrap(content.rows.first { $0.id == "credits" })
        }
        XCTAssertEqual(try balance().label, "Balance")
        XCTAssertEqual(try balance().value, "14,207.86")
        _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.language(.chinese))
        XCTAssertEqual(try balance().label, "余额")
        XCTAssertEqual(try balance().value, "14,207.86")
    }

    /// DOCK-3.6-18: an open card, including its scoped extra-quota rows, shows no native tooltip.
    func testNormalCardShowsNoNativeTooltips() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("card-tooltips-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-02T00:00:00Z"))
        let readings = try Self.rows(weekly: 75, extraWindow: true)
        var elapsed = 0.0
        let display = DockDisplayArea(id: "synthetic", frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 880))
        var pointer = CGPoint(x: 700, y: 450)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: false,
            dockEnvironment: { .init(displays: [display], layouts: [], primaryDisplayID: display.id, pointer: pointer) },
            deadlineNow: { wall }, deadlineElapsed: { elapsed }, deadlineScheduling: EntryDeadlineTimer(),
            makeClient: { _, store in EntrySyntheticClient(store: store, rows: readings) }, activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        let id = "aaaaaaaaaaaaaaaa", dock = app.composition.dock, view = dock.dockView
        let placement = try XCTUnwrap(dock.edgePresentation?.placement)
        let anchor = try XCTUnwrap(view.interactionAnchor(id))
        pointer = CGPoint(x: placement.frame.minX + anchor.midX - view.bounds.minX,
            y: placement.frame.maxY - anchor.midY + view.bounds.minY)
        try XCTUnwrap(view.nozzleEventDelegate).hoverNozzle(id)
        elapsed += 0.251; dock.interactionControllerForChecks?.refresh()
        XCTAssertFalse(dock.card.isHidden)
        let content = try XCTUnwrap(try dock.cardContent(for: id, at: wall))
        XCTAssertTrue(content.rows.contains { $0.kind == .extraQuota }, "precondition: the card has a scoped extra row")
        func tooltips(_ root: NSView) -> [String] { (root.toolTip.map { [$0] } ?? []) + root.subviews.flatMap(tooltips) }
        XCTAssertEqual(tooltips(dock.card), [])
    }

    func testNormalReserveLabelAndNumberHaveVisibleRoomInBothLanguages() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("reserve-extent-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-02T00:00:00Z"))
        let snapshot = try Self.rows(weekly: 75, reserveBalance: 19_613.9573653333)
        let display = DockDisplayArea(id: "synthetic", frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 80, width: 1440, height: 820))
        var pointer = CGPoint(x: 700, y: 450)
        var elapsed = 0.0
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: false,
            dockEnvironment: { .init(displays: [display], layouts: [], primaryDisplayID: display.id, pointer: pointer) },
            deadlineNow: { wall }, deadlineElapsed: { elapsed }, deadlineScheduling: EntryDeadlineTimer(),
            makeClient: { _, store in EntrySyntheticClient(store: store, rows: snapshot) }, activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()

        let dock = app.composition.dock, view = dock.dockView
        let id = "aaaaaaaaaaaaaaaa"
        let placement = try XCTUnwrap(dock.edgePresentation?.placement)
        let nozzle = try XCTUnwrap(view.interactionAnchor(id))
        pointer = CGPoint(x: placement.frame.minX + nozzle.midX - view.bounds.minX,
            y: placement.frame.maxY - nozzle.midY + view.bounds.minY)
        try XCTUnwrap(view.nozzleEventDelegate).hoverNozzle(id)
        elapsed += 0.251; dock.interactionControllerForChecks?.refresh()
        XCTAssertFalse(dock.card.isHidden)

        func field(_ root: NSView, id: String) -> NSTextField? {
            if let field = root as? NSTextField, field.accessibilityIdentifier() == "dock.card.text." + id { return field }
            return root.subviews.lazy.compactMap { field($0, id: id) }.first
        }
        func assertVisible(_ field: NSTextField, text: String) throws {
            XCTAssertEqual(field.stringValue, text)
            XCTAssertFalse(field.isHiddenOrHasHiddenAncestor)
            let font = try XCTUnwrap(field.font)
            let glyphs = (text as NSString).size(withAttributes: [.font: font])
            let visible = dock.card.convert(field.bounds, from: field).intersection(dock.card.bounds)
            XCTAssertGreaterThanOrEqual(visible.width, floor(glyphs.width), "\(text) needs visible horizontal space")
            XCTAssertGreaterThanOrEqual(visible.height, floor(glyphs.height), "\(text) needs visible vertical space")
        }
        for (language, title) in [(SettingsLanguage.english, "Reserve"), (.chinese, "储备")] {
            _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.language(language))
            let name = try XCTUnwrap(field(dock.card, id: "row.credits.label"))
            let value = try XCTUnwrap(field(dock.card, id: "row.credits.value"))
            try assertVisible(name, text: title)
            try assertVisible(value, text: "19,614")
            XCTAssertLessThanOrEqual(dock.card.convert(name.bounds, from: name).maxX,
                dock.card.convert(value.bounds, from: value).minX)
        }
    }

    func testResetSourceURLRejectsUnsafeAddressParts() throws {
        for raw in [
            "http://status.openai.com/incidents/demo",
            "https://user:password@status.openai.com/incidents/demo",
            "https://status.openai.com:8443/incidents/demo",
            "https://status.openai.com/incidents/demo?token=canary",
            "https://status.openai.com/incidents/demo#fragment",
        ] {
            XCTAssertFalse(EngineRowsEventDecoder.isHTTPSSourceURL(try XCTUnwrap(URL(string: raw))), raw)
        }
    }

    func testNormalOpenCardUpdatesReportedResetExpiryWithoutNewRows() async throws {
        let captureDirectory = ProcessInfo.processInfo.environment["MODELPLAN_546_CARD_CAPTURE_DIR"].map { URL(fileURLWithPath: $0) }
        for (language, labels) in [
            ("en", ["1 reset · expire in 12m", "1 reset · expire in 9m", "1 reset · expired"]),
            ("zh", ["重置 1 次 · 12 分钟后到期", "重置 1 次 · 9 分钟后到期", "重置 1 次 · 已到期"]),
        ] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("reset-expiry-" + UUID().uuidString)
            addTeardownBlock { try? FileManager.default.removeItem(at: root) }
            let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: [language])
            let start = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-02T16:00:00Z"))
            var wall = start
            let snapshot = try Self.rows(weekly: 75, resetCardClock: start, resetFacts: .init(count: 1, expiresIn: 12 * 60))
            let display = DockDisplayArea(id: "synthetic", frame: .init(x: 0, y: 0, width: 1440, height: 900),
                visibleFrame: .init(x: 0, y: 0, width: 1440, height: 880))
            var pointer = CGPoint(x: 700, y: 450)
            let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
                applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings,
                createsNativePanels: false, bundleURL: root.appendingPathComponent("Synthetic.app"),
                dockEnvironment: { .init(displays: [display], layouts: [], primaryDisplayID: display.id, pointer: pointer) },
                deadlineNow: { wall }, deadlineScheduling: EntryDeadlineTimer(),
                makeClient: { _, store in EntrySyntheticClient(store: store, rows: snapshot) }, activateSettings: {})
            addTeardownBlock { @MainActor in await app.composition.stop() }
            await app.prepare(); app.allowDockPresentation(); await app.composition.start()
            let dock = app.composition.dock, view = dock.dockView
            let id = "aaaaaaaaaaaaaaaa"
            let placement = try XCTUnwrap(dock.edgePresentation?.placement)
            let anchor = try XCTUnwrap(view.interactionAnchor(id))
            pointer = CGPoint(x: placement.frame.minX + anchor.midX - view.bounds.minX,
                              y: placement.frame.maxY - anchor.midY + view.bounds.minY)
            try XCTUnwrap(view.nozzleEventDelegate).hoverNozzle(id)
            let delivery = try XCTUnwrap(app.composition.store.snapshot.delivery)
            let revision = try XCTUnwrap(app.settingsHost.application.editor.snapshot?.revision)

            func text(_ view: NSView) -> [String] {
                (view as? NSTextField).map { [$0.stringValue] } ?? view.subviews.flatMap(text)
            }
            for (offset, label) in zip([0.0, 180, 720], labels) {
                wall = start.addingTimeInterval(offset)
                let deadline = ContinuousClock.now + .seconds(2)
                while (dock.card.isHidden || !text(dock.card).contains(label)) && ContinuousClock.now < deadline {
                    try await Task.sleep(for: .milliseconds(10))
                }
                XCTAssertFalse(dock.card.isHidden, language)
                XCTAssertTrue(text(dock.card).contains(label), "Expected drawn label: " + label)
                XCTAssertEqual(try dock.cardContent(for: id, at: wall)?.rows.first { $0.id == "reset-count" }?.label, label)
                XCTAssertEqual(app.composition.store.snapshot.delivery, delivery)
                XCTAssertEqual(app.composition.store.snapshot.rows?.sequence, snapshot.sequence)
                XCTAssertEqual(app.settingsHost.application.editor.snapshot?.revision, revision)
                if let captureDirectory {
                    let bitmap = try XCTUnwrap(dock.card.bitmapImageRepForCachingDisplay(in: dock.card.bounds))
                    dock.card.cacheDisplay(in: dock.card.bounds, to: bitmap)
                    let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                    try png.write(to: captureDirectory.appendingPathComponent("\(language)-\(Int(offset)).png"))
                }
            }
            await app.composition.stop()
        }
    }

    func testNormalCardAdmitsOnlyVerifiedResetFactsAndLinks() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("reset-card-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let wall = try XCTUnwrap(Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 12, day: 2, hour: 16)))
        let snapshot = try Self.rows(weekly: 75, resetCardClock: wall)
        let officialURL = "https://status.openai.com/incidents/demo-reset"
        let originalURL = "https://x.com/OpenAI/status/123"
        let aihotURL = "https://aihot.news/example-reset"
        let publicationURL = "https://example.invalid/digest"
        guard case .available(let decoded) = EngineRowsEventDecoder.decode(snapshot) else {
            return XCTFail("Expected the explicit reset event")
        }
        XCTAssertEqual(Set(try XCTUnwrap(decoded.first).sourceLinks.map(\.url.absoluteString)),
                       Set([officialURL, originalURL, aihotURL, publicationURL]))
        XCTAssertEqual(decoded.first?.sourceLinks.filter { $0.kind == "official" }.map(\.url.absoluteString), [officialURL])
        var elapsed = 0.0
        let display = DockDisplayArea(id: "synthetic", frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 880))
        var pointer = CGPoint(x: 700, y: 450)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: false,
            cockpitEntryEnabled: true,
            dockEnvironment: { .init(displays: [display], layouts: [], primaryDisplayID: display.id, pointer: pointer) },
            deadlineNow: { wall }, deadlineElapsed: { elapsed }, deadlineScheduling: EntryDeadlineTimer(),
            makeClient: { _, store in EntrySyntheticClient(store: store, rows: snapshot) }, activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.prepare(); app.allowDockPresentation()
        let dock = app.composition.dock
        var opened: [URL] = []
        dock.openCardSourceURL = { opened.append($0) }
        var cockpitOpens = 0
        dock.showConsole = { cockpitOpens += 1 }
        await app.composition.start()
        XCTAssertTrue(dock.card.isHidden, "an admitted public event must not open the card")
        XCTAssertEqual(cockpitOpens, 0)
        let id = "aaaaaaaaaaaaaaaa", view = dock.dockView
        XCTAssertEqual(view.presentedNoticesForChecks[id]?.key.kind, .resetAnnounced)
        let placement = try XCTUnwrap(dock.edgePresentation?.placement)
        let anchor = try XCTUnwrap(view.interactionAnchor(id))
        pointer = CGPoint(x: placement.frame.minX + anchor.midX - view.bounds.minX,
            y: placement.frame.maxY - anchor.midY + view.bounds.minY)
        try XCTUnwrap(view.nozzleEventDelegate).hoverNozzle(id)
        elapsed += 0.251; dock.interactionControllerForChecks?.refresh()
        XCTAssertFalse(dock.card.isHidden)
        func text(_ root: NSView) -> [String] {
            (root as? NSTextField).map { [$0.stringValue] } ?? root.subviews.flatMap(text)
        }
        XCTAssertTrue(text(dock.card).contains("Reset 17:00 announced"))
        XCTAssertTrue(text(dock.card).contains("2 resets · expire in 30h"))
        // DOCK-3.8-11: the announced reset is its own section: the title spans the readout window in reset blue.
        func fields(_ root: NSView) -> [NSTextField] { ((root as? NSTextField).map { [$0] } ?? []) + root.subviews.flatMap(fields) }
        let resetTitle = try XCTUnwrap(fields(dock.card).first { $0.accessibilityIdentifier().hasPrefix("dock.card.text.row.reset-event:") && $0.accessibilityIdentifier().hasSuffix(".label") })
        XCTAssertGreaterThan(resetTitle.frame.width, 200, "the reset title is not squeezed into the label column")
        let ink = try XCTUnwrap(resetTitle.textColor?.usingColorSpace(.sRGB))
        XCTAssertEqual(ink.blueComponent, 1, accuracy: 0.02); XCTAssertEqual(ink.redComponent * 255, 0x9f, accuracy: 3)
        let content = try XCTUnwrap(dock.cardContent(for: id, at: wall))
        XCTAssertEqual(content.links.map(\.url.absoluteString), [originalURL, aihotURL, officialURL, publicationURL])
        XCTAssertEqual(content.links.map(\.label), ["Original", "AIHot", "Official source", "Source"])
        func buttons(_ root: NSView) -> [NSButton] {
            (root as? NSButton).map { [$0] } ?? root.subviews.flatMap(buttons)
        }
        // Links flow in reading order: top to bottom, then left to right.
        func arrangedLinkLabels() -> [String] {
            dock.card.subviews.compactMap { $0 as? NSButton }
                .filter { $0.accessibilityIdentifier().hasPrefix("dock.card.link.") }
                .sorted { $0.frame.minY != $1.frame.minY ? $0.frame.minY < $1.frame.minY : $0.frame.minX < $1.frame.minX }
                .map(\.title)
        }
        XCTAssertEqual(arrangedLinkLabels(), content.links.map(\.label))
        let official = try XCTUnwrap(buttons(dock.card).first { $0.title == "Official source" })
        official.performClick(nil)
        XCTAssertEqual(opened.map(\.absoluteString), [officialURL])
        let oldAction = try XCTUnwrap(dock.card.onOpenURL)
        oldAction(URL(string: "https://example.invalid/unlisted")!)
        XCTAssertEqual(opened.count, 1)
        _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.language(.chinese))
        XCTAssertTrue(text(dock.card).contains("预告 17:00 重置"))
        XCTAssertTrue(text(dock.card).contains("重置 2 次 · 30 小时后到期"))
        let chinese = try XCTUnwrap(dock.cardContent(for: id, at: wall))
        XCTAssertEqual(chinese.links.map(\.url.absoluteString), [aihotURL, officialURL, originalURL, publicationURL])
        XCTAssertEqual(chinese.links.map(\.label), ["AIHot", "官方来源", "原文", "来源"])
        XCTAssertEqual(arrangedLinkLabels(), chinese.links.map(\.label))
        oldAction(try XCTUnwrap(URL(string: officialURL)))
        XCTAssertEqual(opened.count, 1, "rebuilding the card retires the old link action")

        let store = app.composition.store
        let delivery = try XCTUnwrap(store.snapshot.delivery)
        func render(_ snapshot: WireRowsSnapshot) async throws {
            let reply = try EngineReply(envelope: .init(sessionId: delivery.sessionID, storeEpoch: delivery.floor.storeEpoch,
                consentGeneration: delivery.floor.generation, data: snapshot), delivery: delivery)
            await store.consume(.rowsChanged(reply, invalidRowCount: snapshot.projection.invalidRowCount))
            let delegate = try XCTUnwrap(view.nozzleEventDelegate)
            delegate.hoverNozzle(nil)
            delegate.hoverNozzle(id)
            elapsed += 0.251; dock.interactionControllerForChecks?.refresh()
            XCTAssertFalse(dock.card.isHidden)
        }
        try await render(Self.rows(weekly: 75, sequence: 8, resetCardClock: wall, resetConfirmed: true))
        XCTAssertTrue(text(dock.card).contains("已重置 · 等读数"))
        XCTAssertFalse(text(dock.card).contains("预告 17:00 重置"))
        _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.language(.english))
        try await render(Self.rows(weekly: 75, sequence: 9, resetCardClock: wall, resetConfirmed: true,
            resetFacts: .init(count: 1, expiresIn: 12 * 60, retainedPartial: true)))
        XCTAssertTrue(text(dock.card).contains("1 reset · expire in 12m"))
        XCTAssertTrue(text(dock.card).contains("Reported subset · Details truncated · Last known reading"))
        try await render(Self.rows(weekly: 75, sequence: 10, resetCardClock: wall, resetConfirmed: true,
            resetFacts: .init(count: 1, expiresIn: -60, restarted: true)))
        XCTAssertTrue(text(dock.card).contains("Reset confirmed"))
        XCTAssertTrue(text(dock.card).contains("1 reset · expired"))
        let confirmedAction = try XCTUnwrap(dock.card.onOpenURL)
        await store.consume(.clearPrivateViews(.init(revision: 2, reason: .generationAdvanced, previous: delivery, nextFloor: nil)))
        XCTAssertTrue(dock.card.isHidden)
        confirmedAction(content.links[1].url)
        XCTAssertEqual(opened.count, 1, "a withdrawn card cannot open its old source")
    }

    func testNormalEntryMagnifiesNozzleWithoutMovingItsReadout() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("paired-magnification-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let clock = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-02T00:00:00Z"))
        // Keep the tightest window above the 50 % amber band (#562), so the readout is neutral
        // ink, with ink-heavy digits ("58%") like the original 42.5 % fixture had.
        let readings = try Self.rows(weekly: 75, fiveHour: 58, secondWeekly: 55)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: false,
            dockEnvironment: {
                // Test each committed edge. This branch predates the bottom-reservation placement port.
                let display = DockDisplayArea(id: "synthetic-display", frame: .init(x: 0, y: 0, width: 1440, height: 900),
                    visibleFrame: .init(x: 0, y: 0, width: 1440, height: 875))
                return .init(displays: [display], layouts: [], primaryDisplayID: display.id, pointer: .init(x: 700, y: 400))
            }, deadlineNow: { clock },
            makeClient: { _, store in EntrySyntheticClient(store: store, rows: readings) }, activateSettings: {})
        await app.prepare()
        let application = app.settingsHost.application
        var environment = application.editor.environment
        environment.reduceMotion = false
        application.update(environment: environment)
        app.allowDockPresentation()
        await app.composition.start()
        addTeardownBlock { @MainActor in await app.composition.stop() }

        let view = app.composition.dock.dockView
        let id = "aaaaaaaaaaaaaaaa"
        let restingReadout = try XCTUnwrap(view.helpReadoutAnchor(id))
        func pixels() throws -> Data {
            try XCTUnwrap(view.presentedImageForChecks?.dataProvider?.data) as Data
        }
        let resting = try pixels()
        // Evidence for review: what the ring looks like at rest and magnified, under dock-visual/.
        func capture(_ name: String) throws {
            let root = ProcessInfo.processInfo.environment["RUNNER_TEMP"].map { URL(fileURLWithPath: $0, isDirectory: true) } ?? FileManager.default.temporaryDirectory
            let output = root.appendingPathComponent("dock-instrument-checks/dock-visual/magnification", isDirectory: true)
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            guard let image = view.presentedImageForChecks,
                  let writer = CGImageDestinationCreateWithURL(output.appendingPathComponent(name + ".png") as CFURL, "public.png" as CFString, 1, nil) else { return }
            CGImageDestinationAddImage(writer, image, nil); CGImageDestinationFinalize(writer)
        }
        try capture("resting")
        let skin = try XCTUnwrap(view.presentedSkinForChecks)
        XCTAssertNotNil(view.registeredHullBounds)
        let nozzle = try XCTUnwrap(view.interactionAnchor(id))
        let restingWidth = try XCTUnwrap(view.presentedImageForChecks).width
        let station = try XCTUnwrap(skin.stations.first { $0.subscriptionID == id })
        let viewportOrigin = CGPoint(x: station.centre.x - nozzle.midX, y: station.centre.y - nozzle.midY)
        let scale = CGFloat(try XCTUnwrap(view.presentationBackingScale))
        func crop(_ frame: CGRect, origin: CGPoint) throws -> Data {
            let image = try XCTUnwrap(view.presentedImageForChecks)
            let region = frame.offsetBy(dx: -origin.x, dy: -origin.y)
                .applying(.init(scaleX: scale, y: scale)).integral
            let cropped = try XCTUnwrap(image.cropping(to: region))
            XCTAssertEqual(cropped.width, Int(region.width))
            XCTAssertEqual(cropped.height, Int(region.height))
            // CGImage crops may retain parent storage. Compare tightly packed RGBA bytes.
            let stride = cropped.width * 4
            let context = try XCTUnwrap(CGContext(data: nil, width: cropped.width, height: cropped.height,
                bitsPerComponent: 8, bytesPerRow: stride, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
            context.setBlendMode(.copy)
            context.interpolationQuality = .none
            context.draw(cropped, in: CGRect(x: 0, y: 0, width: cropped.width, height: cropped.height))
            return Data(bytes: try XCTUnwrap(context.data), count: stride * cropped.height)
        }
        let nozzleFrame = nozzle.offsetBy(dx: viewportOrigin.x, dy: viewportOrigin.y)
        let restingNozzle = try crop(nozzleFrame, origin: skin.bounds.origin)
        func inkMask(_ rgba: Data) -> Set<Int> {
            // The fixture paints bright, neutral text over the dark backing.
            // Ignore anti-aliased edge noise and lower-intensity material.
            let pixels = Array(rgba)
            return Set(stride(from: 0, to: pixels.count, by: 4).filter {
                min(pixels[$0], pixels[$0 + 1], pixels[$0 + 2]) >= 220
            })
        }
        let restingInk = inkMask(try crop(station.readout, origin: skin.bounds.origin))
        XCTAssertFalse(restingInk.isEmpty, "The registered readout crop must contain painted glyphs")
        func assertHoverPixels(line: UInt = #line) throws {
            XCTAssertNotEqual(try crop(nozzleFrame, origin: viewportOrigin), restingNozzle,
                              "Hover must transform pixels inside the registered nozzle, even with the viewport shift removed", line: line)
            let hoverInk = inkMask(try crop(station.readout, origin: viewportOrigin))
            // A moved readout changes most of its ink; two edge pixels are anti-aliasing next to
            // the magnified neighbour (strong mode).
            XCTAssertLessThanOrEqual(restingInk.symmetricDifference(hoverInk).count, max(2, restingInk.count / 50),
                                     "The painted readout must stay fixed in the skin coordinate space", line: line)
        }
        XCTAssertGreaterThan(view.bounds.width, skin.bounds.width, "The view reserves hover space beyond the approved skin")
        XCTAssertEqual(restingWidth, Int(ceil(skin.bounds.width * CGFloat(view.presentationBackingScale ?? 1))))
        let events = try XCTUnwrap(view.nozzleEventDelegate)
        events.hoverNozzle(id)
        try assertHoverPixels()
        XCTAssertEqual(view.helpReadoutAnchor(id), restingReadout)
        let subtle = try XCTUnwrap(view.nozzlePosesForChecks[id])
        XCTAssertEqual(subtle.scale, 1.15)
        XCTAssertEqual(hypot(subtle.offset.x, subtle.offset.y), 6, accuracy: 0.001)
        // R64 D-2: the pose eases over 0.12 s (prototype dock.css:38), not an instant swap.
        XCTAssertTrue(view.animatesPoses)
        XCTAssertEqual(try XCTUnwrap(view.lastPoseTransitionForChecks), 0.12, accuracy: 0.0001)
        // G3-29: on the right edge the ring moves left, away from the edge, not down onto its text.
        XCTAssertLessThan(subtle.offset.x, -5.5, "subtle hover grows outward from the screen edge")
        XCTAssertLessThan(abs(subtle.offset.y), 1.5, "subtle hover does not slide along the edge")
        let grown = CGRect(x: nozzle.midX + subtle.offset.x - nozzle.width * subtle.scale / 2,
                           y: nozzle.midY + subtle.offset.y - nozzle.height * subtle.scale / 2,
                           width: nozzle.width * subtle.scale, height: nozzle.height * subtle.scale)
        XCTAssertFalse(grown.intersects(try XCTUnwrap(view.helpReadoutAnchor(id))), "the magnified ring never covers its readout")
        XCTAssertGreaterThan(try XCTUnwrap(view.presentedImageForChecks).width, restingWidth)
        XCTAssertTrue(view.isPainted(atLocal: CGPoint(x: nozzle.midX, y: nozzle.midY)))
        try capture("subtle")
        XCTAssertNil(view.nozzlePosesForChecks["bbbbbbbbbbbbbbbb"])
        events.hoverNozzle(nil)
        XCTAssertEqual(try pixels(), resting)

        _ = try await application.editor.commit(SettingsB21Edit.magnification(.none))
        events.hoverNozzle(id)
        XCTAssertTrue(view.nozzlePosesForChecks.isEmpty)
        XCTAssertEqual(try pixels(), resting)
        _ = try await application.editor.commit(SettingsB21Edit.magnification(.strong))
        events.hoverNozzle(id)
        XCTAssertEqual(view.nozzlePosesForChecks[id]?.scale, 1.5)
        try capture("strong")
        let neighbour = try XCTUnwrap(view.nozzlePosesForChecks["bbbbbbbbbbbbbbbb"])
        XCTAssertGreaterThan(neighbour.scale, 1)
        XCTAssertLessThan(neighbour.scale, 1.5)
        XCTAssertEqual(view.helpReadoutAnchor(id), restingReadout)
        try assertHoverPixels()
        _ = try await application.editor.commit(SettingsB20Edit.motion(.on))
        events.hoverNozzle(id)
        XCTAssertTrue(view.nozzlePosesForChecks.isEmpty)
        XCTAssertEqual(try pixels(), resting)

        _ = try await application.editor.commit(SettingsB20Edit.motion(.system))
        _ = try await application.editor.commit(SettingsB20Edit.size(.large))
        let edges: [(SettingsDockEdge, DockEdge)] = [(.left, .left), (.right, .right), (.bottom, .bottom)]
        for (edge, expectedPlacement) in edges {
            _ = try await application.editor.commit(SettingsB21Edit.dockEdge(edge))
            XCTAssertEqual(app.composition.dock.edgePresentation?.placement?.edge, expectedPlacement)
            let edgeEvents = try XCTUnwrap(view.nozzleEventDelegate)
            for hoveredID in ["aaaaaaaaaaaaaaaa", "bbbbbbbbbbbbbbbb"] {
                edgeEvents.hoverNozzle(hoveredID)
                XCTAssertEqual(view.nozzlePosesForChecks[hoveredID]?.scale, 1.5, "\(edge) \(hoveredID)")
                for (id, pose) in view.nozzlePosesForChecks {
                    let anchor = try XCTUnwrap(view.interactionAnchor(id))
                    let width = anchor.width * pose.scale, height = anchor.height * pose.scale
                    let posed = CGRect(x: anchor.midX + pose.offset.x - width / 2,
                                       y: anchor.midY + pose.offset.y - height / 2, width: width, height: height)
                    XCTAssertTrue(view.bounds.contains(posed), "\(edge) \(id) pose \(posed) outside \(view.bounds)")
                }
                edgeEvents.hoverNozzle(nil)
            }
        }
    }

    func testNormalMenuKeepsActionsAndLocalizesOneLinePerFailedReader() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("paired-menu-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let clock = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-02T00:00:00Z"))
        let healthy = try Self.rows(weekly: 75, secondWeekly: 55)
        let failed = try Self.rows(weekly: 75, secondWeekly: 55, sequence: 8, readerFailed: true)
        let surface = DiagnosticSettingsSurface()
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: false,
            cockpitEntryEnabled: true, dockEnvironment: normalEntryTestEnvironment, deadlineNow: { clock },
            makeClient: { _, store in EntrySyntheticClient(store: store, rows: healthy) },
            makeSettingsSurface: { _ in surface }, activateSettings: {})
        await app.prepare()
        await app.composition.start()
        addTeardownBlock { @MainActor in await app.composition.stop() }
        let editor = app.settingsHost.application.editor

        func items() throws -> [NSMenuItem] {
            try XCTUnwrap(app.liveStatusMenu).items.filter { !$0.isSeparatorItem }
        }
        let english = ["Refresh", "Show Quota Widget", "Open Cockpit", "Website", "Methodology", "Privacy", "Help…", "Settings…", "About ModelPlan", "Quit ModelPlan"]
        let chinese = ["刷新", "显示额度挂件", "打开驾驶舱", "网站", "方法论", "隐私", "说明…", "设置…", "关于 ModelPlan", "退出 ModelPlan"]
        XCTAssertEqual(try items().map(\.title), english)
        _ = try await editor.commit(SettingsB21Edit.language(.chinese))
        XCTAssertEqual(try items().map(\.title), chinese)

        let delivery = try XCTUnwrap(app.composition.store.snapshot.delivery)
        let reply = try EngineReply(envelope: .init(sessionId: delivery.sessionID, storeEpoch: delivery.floor.storeEpoch,
            consentGeneration: 1, data: failed), delivery: delivery)
        await app.composition.store.consume(.rowsChanged(reply, invalidRowCount: failed.projection.invalidRowCount))
        let zhProblem = "合成账户：读取失败 · 查看…"
        XCTAssertEqual(try items().filter { $0.title == zhProblem }.count, 1)
        XCTAssertEqual(try items().filter { $0.title != zhProblem }.map(\.title), chinese)
        _ = try await editor.commit(SettingsB21Edit.language(.english))
        let enProblem = "Synthetic account: Couldn't read · Details…"
        XCTAssertEqual(try items().filter { $0.title == enProblem }.count, 1)
        XCTAssertEqual(try items().filter { $0.title != enProblem }.map(\.title), english)
        let problem = try XCTUnwrap(try items().first { $0.title == enProblem })
        _ = try XCTUnwrap(problem.target as? NSObject).perform(try XCTUnwrap(problem.action), with: problem)
        await surface.waitForShow()
        XCTAssertEqual(surface.pane, "diagnostics")
    }

    func testS07NormalEntryDistinguishesPaintedHelpTargetsAndFocus() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dock-help-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-06-01T00:00:00Z"))
        let snapshot = try Self.rows(weekly: 75, resetID: "synthetic-dock-help")
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: false,
            dockEnvironment: normalEntryTestEnvironment, deadlineNow: { wall }, deadlineScheduling: EntryDeadlineTimer(),
            makeClient: { _, store in EntrySyntheticClient(store: store, rows: snapshot) }, activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()

        let view = app.composition.dock.dockView
        let id = "aaaaaaaaaaaaaaaa"
        let skin = try XCTUnwrap(view.presentedSkinForChecks)
        let station = try XCTUnwrap(skin.stations.first(where: { $0.subscriptionID == id }))
        let origin = view.layoutOriginForChecks
        let center = CGPoint(x: station.centre.x - origin.x, y: station.centre.y - origin.y)
        let number = try XCTUnwrap(view.helpReadoutAnchor(id))
        let event = try XCTUnwrap(view.helpNoticeAnchor(id))
        let ring = try XCTUnwrap([0.0, .pi / 2, .pi, .pi * 1.5].map { angle in
            CGPoint(x: center.x + cos(angle) * station.outer.radius, y: center.y + sin(angle) * station.outer.radius)
        }.first { view.isPainted(atLocal: $0) && !number.contains($0) && !event.contains($0) })
        XCTAssertEqual(view.helpAnchorID(atLocal: center), "dock.nozzle." + id)
        XCTAssertEqual(view.helpAnchorID(atLocal: ring), "dock.rings." + id)
        XCTAssertEqual(view.helpAnchorID(atLocal: CGPoint(x: number.midX, y: number.midY)), "dock.number." + id)
        XCTAssertEqual(view.helpAnchorID(atLocal: CGPoint(x: event.midX, y: event.midY)), "dock.notice." + id)
        XCTAssertNil(view.helpAnchorID(atLocal: CGPoint(x: view.bounds.maxX + 1, y: view.bounds.maxY + 1)))

        let nodes = (view.accessibilityChildren() ?? []).compactMap { $0 as? NSAccessibilityElement }
        let subscription = try XCTUnwrap(nodes.first { $0.accessibilityIdentifier() == "dock.subscription." + id })
        let quotaValue = try XCTUnwrap(subscription.accessibilityValue() as? String)
        let quotaHelp = subscription.accessibilityHelp()
        let ringHelp = "额度环\n查看当前用量。"
        subscription.setAccessibilityFocused(true)
        XCTAssertEqual(view.focusedHelpAnchorID, "dock.rings." + id)
        XCTAssertTrue(view.setFocusedHelpExplanation(ringHelp, for: "dock.rings." + id))
        XCTAssertEqual(subscription.accessibilityHelp(), ringHelp)
        XCTAssertEqual(subscription.accessibilityValue() as? String, quotaValue)
        app.composition.dock.refreshDockContent()
        XCTAssertEqual(subscription.accessibilityHelp(), ringHelp, "A same-target redraw preserves the active explanation")
        subscription.setAccessibilityFocused(false)
        XCTAssertNil(view.focusedHelpAnchorID)
        XCTAssertEqual(subscription.accessibilityHelp(), quotaHelp)
        XCTAssertFalse(view.setFocusedHelpExplanation(ringHelp, for: "dock.rings." + id))

        let notice = try XCTUnwrap(nodes.first { $0.accessibilityIdentifier() == "dock.notice." + id })
        notice.setAccessibilityFocused(true)
        XCTAssertEqual(view.focusedHelpAnchorID, "dock.notice." + id)
        notice.setAccessibilityFocused(false)
        XCTAssertNil(view.focusedHelpAnchorID)

        let nozzleEvents = try XCTUnwrap(view.nozzleEventDelegate)
        XCTAssertTrue(nozzleEvents.beginNozzle(id: id, local: ring))
        nozzleEvents.moveNozzle(local: CGPoint(x: ring.x + 12, y: ring.y + 12))
        XCTAssertNil(view.helpAnchorID(atLocal: ring))
        nozzleEvents.cancelNozzle()
        XCTAssertEqual(view.helpAnchorID(atLocal: ring), "dock.rings." + id)

        let grip = try XCTUnwrap(view.registeredGripRects.first)
        XCTAssertEqual(view.helpAnchorID(atLocal: CGPoint(x: grip.midX, y: grip.midY)), "dock.grip.0")
        let gripNode = try XCTUnwrap(nodes.first { $0.accessibilityIdentifier() == "dock.grip.0" })
        gripNode.setAccessibilityFocused(true)
        XCTAssertEqual(view.focusedHelpAnchorID, "dock.grip.0")
        let gripHelp = "Move the widget\nDrag the grip to another edge."
        XCTAssertTrue(view.setFocusedHelpExplanation(gripHelp, for: "dock.grip.0"))
        XCTAssertFalse(view.setFocusedHelpExplanation(nil, for: "dock.rings." + id))
        XCTAssertEqual(gripNode.accessibilityHelp(), gripHelp)
        XCTAssertTrue(view.setFocusedHelpExplanation(nil, for: "dock.grip.0"))
        XCTAssertNil(gripNode.accessibilityHelp())
        XCTAssertTrue(view.setFocusedHelpExplanation(gripHelp, for: "dock.grip.0"))

        app.composition.dock.close()
        XCTAssertNil(gripNode.accessibilityHelp(), "Retirement must clear even a retained AX node")
        XCTAssertNil(view.helpAnchorID(atLocal: ring))
        XCTAssertNil(view.focusedHelpAnchorID)
    }

    func testNormalEntryLanguageChangeReprojectsSameAdmittedDelivery() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("paired-language-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-06-01T00:00:00Z"))
        var interactionElapsed=0.0
        let timer = EntryDeadlineTimer(), snapshot = try Self.rows(weekly: 75, secondWeekly: 55)
        let surface = DiagnosticSettingsSurface()
        let display = DockDisplayArea(id: "synthetic", frame: .init(x: 0, y: 0, width: 1440, height: 900), visibleFrame: .init(x: 0, y: 80, width: 1440, height: 820))
        var pointer = CGPoint(x: 700, y: 450)
        var acceptedStore: EngineStore?
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: false,
            dockEnvironment: { .init(displays: [display], layouts: [], primaryDisplayID: "synthetic", pointer: pointer) },
            deadlineNow: { wall }, deadlineElapsed: { interactionElapsed }, deadlineScheduling: timer,
            makeClient: { _, store in acceptedStore = store; return EntrySyntheticClient(store: store, rows: snapshot) },
            makeSettingsSurface: { _ in surface },
            activateSettings: {})
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        let problems = try XCTUnwrap(app.liveStatusMenu).items.filter { $0.title == "Synthetic account: Reading stale · Details…" }
        XCTAssertEqual(problems.count, 1, "Multiple members from one provider produce one diagnostic line")
        let problem = try XCTUnwrap(problems.first)
        _ = try XCTUnwrap(problem.target as? NSObject).perform(try XCTUnwrap(problem.action), with: problem)
        await surface.waitForShow()
        XCTAssertEqual(surface.pane, "diagnostics")
        let id = "aaaaaaaaaaaaaaaa"
        XCTAssertEqual(try app.composition.dock.cardContent(for: id, at: wall)?.name, "Synthetic account")
        XCTAssertEqual(try app.composition.dock.cardContent(for: id, at: wall)?.stateLabel, "Stale · over 30 days ago")
        let dockView = app.composition.dock.dockView
        let placement = try XCTUnwrap(app.composition.dock.edgePresentation?.placement)
        let anchor = try XCTUnwrap(dockView.interactionAnchor(id))
        pointer = CGPoint(x: placement.frame.minX + anchor.midX - dockView.bounds.minX,
            y: placement.frame.maxY - anchor.midY + dockView.bounds.minY)
        try XCTUnwrap(app.composition.dock.dockView.nozzleEventDelegate).hoverNozzle(id)
        interactionElapsed += 0.251; app.composition.dock.interactionControllerForChecks?.refresh()
        XCTAssertFalse(app.composition.dock.card.isHidden)
        let store = try XCTUnwrap(acceptedStore), before = store.snapshot.rows?.sequence
        _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.language(.chinese))
        XCTAssertEqual(store.snapshot.rows?.sequence, before, "no new engine delivery")
        XCTAssertFalse(app.composition.dock.card.isHidden, "A same-delivery language change preserves the hovered card")
        let card = try XCTUnwrap(app.composition.dock.cardContent(for: id, at: wall))
        XCTAssertEqual(card.name, "合成账户")
        XCTAssertEqual(card.stateLabel, "过期 · 超过 30 天前", "The stale badge follows the Chinese prototype while preserving the original observation age")
        XCTAssertTrue(app.composition.menuPresentation.detail.contains("合成账户"))
        let context = EngineDeliveryContext(sessionID: "synthetic", floor: .init(storeEpoch: "synthetic", generation: 1), revision: 1)
        await store.consume(.clearPrivateViews(.init(revision: 2, reason: .generationAdvanced, previous: context, nextFloor: nil)))
        XCTAssertNil(try app.composition.dock.cardContent(for: id, at: wall))
        XCTAssertFalse(app.composition.menuPresentation.detail.contains("合成账户"))
        await app.composition.stop()
    }

    func testNormalEntryUniqueUnboundMemberUsesSnapshotScopedProofAndClears() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("paired-unbound-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-06-01T00:00:00Z"))
        let timer = EntryDeadlineTimer(), snapshot = try Self.rows(weekly: 75, unbound: true)
        var acceptedStore: EngineStore?
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: false,
            dockEnvironment:normalEntryTestEnvironment, deadlineNow: { wall }, deadlineElapsed: { 0 }, deadlineScheduling: timer,
            makeClient: { _, store in acceptedStore = store; return EntrySyntheticClient(store: store, rows: snapshot) },
            activateSettings: {})
        await app.prepare(); await app.composition.start()
        let id = "codex#saved_login_api"
        let card = try XCTUnwrap(app.composition.dock.cardContent(for: id, at: wall))
        XCTAssertEqual(card.rows.first(where: { $0.id == "quota:weekly:604800:main:main" })?.value, "75%")
        let store = try XCTUnwrap(acceptedStore)
        let context = EngineDeliveryContext(sessionID: "synthetic", floor: .init(storeEpoch: "synthetic", generation: 1), revision: 1)
        await store.consume(.clearPrivateViews(.init(revision: 2, reason: .generationAdvanced, previous: context, nextFloor: nil)))
        XCTAssertNil(try app.composition.dock.cardContent(for: id, at: wall))
        await app.composition.stop()
    }

    func testNormalHostCloseCancelsDeadlineAndRetiresCachedContent() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("paired-close-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-06-01T00:00:00Z"))
        let timer = EntryDeadlineTimer(), snapshot = try Self.rows(weekly: 75)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: false,
            dockEnvironment:normalEntryTestEnvironment, deadlineNow: { wall }, deadlineElapsed: { 0 }, deadlineScheduling: timer,
            makeClient: { _, store in EntrySyntheticClient(store: store, rows: snapshot) }, activateSettings: {})
        await app.prepare(); await app.composition.start()
        XCTAssertFalse(app.composition.presentedContent.snapshot.inputs.isEmpty)
        let late = try XCTUnwrap(timer.action)
        app.composition.dock.close()
        XCTAssertNil(timer.action)
        XCTAssertTrue(app.composition.presentedContent.snapshot.inputs.isEmpty)
        late()
        XCTAssertTrue(app.composition.presentedContent.snapshot.inputs.isEmpty)
        await app.composition.stop()
    }

    func testV17StatusButtonUsesCommittedModeAndAdmittedRemainingQuota() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("status-display-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-02T00:00:00Z"))
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let fixture = try Self.rows(weekly: 15, fiveHour: 9)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: store, createsNativePanels: false,
            dockEnvironment: normalEntryTestEnvironment, deadlineNow: { wall },
            makeClient: { _, store in EntrySyntheticClient(store: store, rows: fixture) }, activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.prepare()
        app.allowDockPresentation()
        await app.composition.start()

        let button = NSButton(), icon = NSImage(size: .init(width: 16, height: 16))
        EngineDockMenuApplication.configureStatusButton(button, image: icon, barThickness: 22)
        let editor = app.settingsHost.application.editor
        // MENU-04: the person can choose the display in Settings, not only through a commit.
        XCTAssertNil(app.currentSettingsContext.unavailableControls[.menuDisplay])
        let settingsRows = try SettingsCatalogue.rows(preferences: try XCTUnwrap(editor.snapshot).preferences, context: editor.context)
        let menuDisplayRow = try XCTUnwrap(settingsRows.first { $0.key == .menuDisplay })
        XCTAssertEqual(menuDisplayRow.availability, .available, "the menu-bar display control must be usable")
        func assertStatus(_ expected: String, line: UInt = #line) {
            app.applyStatusContent(to: button, detail: "")
            XCTAssertEqual(button.title, expected, line: line)
            XCTAssertTrue(button.image?.isTemplate == true, line: line)
        }
        _ = try await editor.commit(SettingsB21Edit.menuDisplay(.tightest))
        assertStatus("9%")
        // MENU-06: with the default tightest title, the reset dot stays at the icon's top right
        // instead of moving to the end of "9%".
        button.sizeToFit()
        app.noticeIndicator.attach(to: button)
        let iconRect = try XCTUnwrap(button.cell?.imageRect(forBounds: button.bounds))
        XCTAssertEqual(app.noticeIndicator.frame.maxX, iconRect.maxX, accuracy: 0.5)
        XCTAssertLessThan(app.noticeIndicator.frame.maxX, button.bounds.maxX - 8, "the dot must not sit after the percentage")
        app.noticeIndicator.removeFromSuperview()
        _ = try await editor.commit(SettingsB20Edit.percentageMode(.used))
        _ = try await editor.commit(SettingsB20Edit.percentagePin("aaaaaaaaaaaaaaaa", .week))
        assertStatus("9%")
        _ = try await editor.commit(SettingsB21Edit.menuDisplay(.twoWindows))
        assertStatus("5h 9% Week 15%")
        _ = try await editor.commit(SettingsB21Edit.language(.chinese))
        assertStatus("5h 9% 周 15%")
        _ = try await editor.commit(SettingsB21Edit.menuDisplay(.icon))
        assertStatus("")
        _ = try await editor.commit(SettingsB21Edit.menuDisplay(.tightest))
        assertStatus("9%")
        let delivery = try XCTUnwrap(app.composition.store.snapshot.delivery)
        await app.composition.store.consume(.clearPrivateViews(.init(revision: delivery.revision + 1,
            reason: .generationAdvanced, previous: delivery, nextFloor: nil)))
        assertStatus("")
    }

    func testV17ExpiredOnlyReadingLeavesAnIconWithoutRevocation() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("status-expiry-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let iso = ISO8601DateFormatter()
        var wall = try XCTUnwrap(iso.date(from: "2026-12-02T00:00:00Z"))
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let fixture = try Self.rows(weekly: 15, weeklyDeadline: "2026-12-02T00:01:00Z", includeSession: false)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: store, createsNativePanels: false,
            dockEnvironment: normalEntryTestEnvironment, deadlineNow: { wall },
            makeClient: { _, store in EntrySyntheticClient(store: store, rows: fixture) }, activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.prepare()
        app.allowDockPresentation()
        await app.composition.start()
        _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.menuDisplay(.tightest))
        let button = NSButton()
        EngineDockMenuApplication.configureStatusButton(button, image: NSImage(size: .init(width: 16, height: 16)), barThickness: 22)
        app.applyStatusContent(to: button, detail: "")
        XCTAssertEqual(button.title, "15%")
        let delivery = try XCTUnwrap(app.composition.store.snapshot.delivery)

        wall = try XCTUnwrap(iso.date(from: "2026-12-02T00:02:00Z"))
        app.applyStatusContent(to: button, detail: "")
        XCTAssertEqual(button.title, "")
        XCTAssertTrue(button.image?.isTemplate == true)
        XCTAssertEqual(app.composition.store.snapshot.delivery, delivery)
        XCTAssertNotNil(app.composition.store.snapshot.rows)
    }

    func testNormalEntryKeepsLoadingAndFailureOutOfMenusWithoutAdmittedRows() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("paired-first-open-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        var acceptedStore: EngineStore?
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: false,
            dockEnvironment:normalEntryTestEnvironment, makeClient: { _, store in acceptedStore = store; return PairedSyntheticClient() }, activateSettings: {})
        await app.prepare()
        XCTAssertTrue(app.composition.menuPresentation.detail.contains("Loading"))
        XCTAssertTrue(app.composition.menuPresentation.detail.contains("Settings"))
        app.renderMenu()
        XCTAssertFalse(app.liveStatusMenu?.items.first?.title.isEmpty ?? true)
        XCTAssertFalse(app.liveStatusMenu?.items.contains { $0.title.contains("Loading") && $0.title.contains("Settings") } ?? true)
        let initialDockMenu = app.composition.dock.menu()
        XCTAssertFalse(initialDockMenu.items.contains { $0.title.contains("Loading") && $0.title.contains("Settings") })
        let store = try XCTUnwrap(acceptedStore)
        await store.consume(.connection(.stopped(.requested)))
        let projected = EngineDockContentProvider(source: app.composition.provider)
        let status = NSButton()
        func assertFailureCopy(_ expected: String, language: SettingsLanguage, line: UInt = #line) {
            let detail = app.composition.menuPresentation.detail
            app.applyStatusContent(to: status, detail: detail)
            XCTAssertEqual(status.toolTip, expected, line: line)
            XCTAssertEqual(status.accessibilityHelp(), expected, line: line)
            XCTAssertEqual(app.composition.presentedContent.emptyText, expected, line: line)
            projected.language = language.rawValue
            let content = projected.makeContent(.init(snapshot: nil, diagnostics: .init(), now: Date()))
            XCTAssertEqual(content.emptyText, expected, line: line)
            XCTAssertEqual(content.menuStatusLines, [expected], line: line)
            XCTAssertFalse(app.liveStatusMenu?.items.contains { $0.title == expected } ?? true, line: line)
            XCTAssertFalse(app.composition.dock.menu().items.contains { $0.title == expected }, line: line)
        }
        assertFailureCopy("Readings unavailable. Check the reading service connection in Settings.", language: .english)
        _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.language(.chinese))
        assertFailureCopy("读数不可用，请在设置中检查读取服务连接。", language: .chinese)
        await app.composition.stop()
    }

}
