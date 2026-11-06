// SPDX-License-Identifier: MIT
import AppKit
import Foundation
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

    static func rows(weekly: Double, secondWeekly: Double? = nil, sequence: Int = 7, weeklyDeadline: String = "2028-12-01T00:00:00Z", resetID: String? = nil, unbound: Bool = false, reserveBalance: Double? = nil, resetCardClock: Date? = nil, resetConfirmed: Bool = false, resetFacts: ResetFactsFixture = .init(), windowSources: WindowSources = .captured) throws -> WireRowsSnapshot {
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
        row["name"] = ["en": "Synthetic account", "zh": "合成账户"]
        row["expiresAt"] = "2027-01-01T00:00:00Z"
        row["stateAfterExpiry"] = ["state": "stale",
            "reason": ["code": "stale_reading", "text": ["en": "Last known", "zh": "旧读数"]],
            "nextStep": NSNull()]
        if unbound { account["subscriptionRef"] = NSNull() }
        else { account["subscriptionRef"] = "aaaaaaaaaaaaaaaa" }
        account["valueState"] = "current"
        account["observedAt"] = "2026-12-01T00:00:00Z"; account["freshUntil"] = weeklyDeadline
        account["lastFailure"] = NSNull()
        if let reserveBalance { account["credits"] = ["balance": reserveBalance, "unit": "unknown"] }
        session["id"] = "session:18000:main:main"; session["role"] = "session"
        session["durationSeconds"] = 18000; session["limitKey"] = "main"; session["poolKey"] = "main"
        session.removeValue(forKey: "modelScope"); session["current"] = true
        session["observedAt"] = "2026-12-01T00:00:00Z"
        session["validUntil"] = "2027-01-01T00:00:00Z"; session["resetsAt"] = "2027-01-01T00:00:00Z"
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
        windows = [session, week]
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
        let content = try XCTUnwrap(dock.cardContent(for: id, at: wall))
        XCTAssertEqual(content.links.map(\.url.absoluteString), [originalURL, aihotURL, officialURL, publicationURL])
        XCTAssertEqual(content.links.map(\.label), ["Original", "AIHot", "Official source", "Source"])
        func buttons(_ root: NSView) -> [NSButton] {
            (root as? NSButton).map { [$0] } ?? root.subviews.flatMap(buttons)
        }
        let stack = try XCTUnwrap(dock.card.subviews.compactMap { $0 as? NSStackView }.first)
        func arrangedLinkLabels() -> [String] {
            stack.arrangedSubviews.compactMap { ($0 as? NSButton)?.title }
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
        XCTAssertEqual(try app.composition.dock.cardContent(for: id, at: wall)?.name, "Synthetic account · Account 1")
        XCTAssertEqual(try app.composition.dock.cardContent(for: id, at: wall)?.stateLabel, "Stale · 4368h ago")
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
        XCTAssertEqual(card.name, "合成账户 · 账号 1")
        XCTAssertEqual(card.stateLabel, "过期 · 4368小时前", "The stale badge follows the Chinese prototype while preserving the original observation age")
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
