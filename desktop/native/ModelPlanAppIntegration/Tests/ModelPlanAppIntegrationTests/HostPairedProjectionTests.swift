// SPDX-License-Identifier: MIT
import AppKit
import CoreGraphics
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
    static func rows(weekly: Double, secondWeekly: Double? = nil, sequence: Int = 7, weeklyDeadline: String = "2028-12-01T00:00:00Z", resetID: String? = nil, unbound: Bool = false, readerFailed: Bool = false) throws -> WireRowsSnapshot {
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
        let english = ["Refresh", "Show Quota Widget", "Open Cockpit", "Website", "Methodology", "Privacy", "Help…", "Settings…", "About", "Quit"]
        let chinese = ["刷新", "显示额度挂件", "打开驾驶舱", "网站", "方法论", "隐私", "说明…", "设置…", "关于", "退出"]
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

    func testNormalEntryMagnifiesNozzleWithoutMovingItsReadout() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("paired-magnification-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let clock = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-02T00:00:00Z"))
        let readings = try Self.rows(weekly: 75, secondWeekly: 55)
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
        let skin = try XCTUnwrap(view.presentedSkinForChecks)
        let hull = try XCTUnwrap(view.registeredHullBounds)
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
            XCTAssertLessThanOrEqual(restingInk.symmetricDifference(hoverInk).count, max(1, restingInk.count / 50),
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
        let dx = hull.midX - nozzle.midX, dy = hull.midY - nozzle.midY
        let distance = hypot(dx, dy)
        XCTAssertGreaterThan(distance, 0)
        XCTAssertEqual(subtle.offset.x, 6 * dx / distance, accuracy: 0.001)
        XCTAssertEqual(subtle.offset.y, 6 * dy / distance, accuracy: 0.001)
        XCTAssertGreaterThan(try XCTUnwrap(view.presentedImageForChecks).width, restingWidth)
        XCTAssertTrue(view.isPainted(atLocal: CGPoint(x: nozzle.midX, y: nozzle.midY)))
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
