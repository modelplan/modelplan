// SPDX-License-Identifier: MIT
import AppKit
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
    static func rows(weekly: Double, secondWeekly: Double? = nil, sequence: Int = 7, weeklyDeadline: String = "2028-12-01T00:00:00Z", resetID: String? = nil, unbound: Bool = false, reserveBalance: Double? = nil) throws -> WireRowsSnapshot {
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
        XCTAssertTrue(app.composition.menuPresentation.detail.contains("unavailable"))
        XCTAssertTrue(app.composition.menuPresentation.detail.contains("Settings"))
        let failedDockMenu = app.composition.dock.menu()
        XCTAssertFalse(failedDockMenu.items.contains { $0.title.contains("unavailable") && $0.title.contains("Settings") })
        _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.language(.chinese))
        XCTAssertTrue(app.composition.menuPresentation.detail.contains("不可用"))
        XCTAssertTrue(app.composition.menuPresentation.detail.contains("设置"))
        await app.composition.stop()
    }

}
