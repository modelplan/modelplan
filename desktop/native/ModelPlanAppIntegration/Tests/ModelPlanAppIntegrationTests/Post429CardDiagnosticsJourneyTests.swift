// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
@_spi(DockResourceChecks) import ModelPlanDock
@testable import ModelPlanAppIntegration

@MainActor private final class Post429Clock {
    var wall = Date(timeIntervalSince1970: 1_800_000_000)
    var elapsed = 10.0
}
@MainActor private final class Post429Timer: DockEdgeScheduling {
    var deadline: Double?, action: (@MainActor () -> Void)?
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) { self.deadline = deadline; self.action = action }
    func cancel() { deadline = nil; action = nil }
    func fireIfDue(_ now: Double) { if let deadline, now >= deadline { let saved = action; cancel(); saved?() } }
}
private actor Post429Engine: EngineClient {
    let store: EngineStore
    let context = EngineDeliveryContext(sessionID: "g1-d", floor: .init(storeEpoch: "g1-d", generation: 1), revision: 1)
    var rows: WireRowsSnapshot
    var requests: [String] = []
    let refreshDecisions: [WireRefreshDecision]?
    init(store: EngineStore, rows: WireRowsSnapshot, refreshDecisions: [WireRefreshDecision]? = nil) { self.store = store; self.rows = rows; self.refreshDecisions = refreshDecisions }
    nonisolated func isCurrent(_ value: EngineDeliveryContext) -> Bool { value.sessionID == "g1-d" && value.revision == 1 }
    func supportsCapability(_ value: String) async -> Bool { value == "memberRefreshV1" || (value == "refreshDecisionsV1" && refreshDecisions != nil) }
    func start() async throws -> EngineDeliveryContext { requests.append("start"); await store.consume(.connection(.ready(context))); await store.consume(.context(context)); return context }
    func stop() async { requests.append("stop") }
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func deliver(_ value: WireRowsSnapshot) async throws { rows = value; await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: value), delivery: context), invalidRowCount: 0)) }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { requests.append("rows"); try await deliver(rows); return .init(requestID: .string("rows")) }
    func consent(timeout: Duration?) throws -> EngineRequestCompletion { requests.append("consent"); throw EngineClientError.unsupportedCapability }
    func grant(_ value: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ value: WireRefreshRequestParams, timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ value: WireRefreshRequestParams, timeout: Duration?, prepared: @escaping @Sendable (WireRequestID) async -> Void) async throws -> EngineRequestCompletion {
        guard value.member != nil else { throw EngineClientError.unsupportedCapability }
        requests.append("member-refresh"); let id = WireRequestID.string("refresh-\(requests.count)")
        await prepared(id)
        await store.consume(.response(requestID: id, .memberRefresh(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: WireMemberRefreshResult(outcome: .started)), delivery: context))))
        return .init(requestID: id)
    }
    func trace() -> [String] { requests }
    func history(_ value: WireHistoryQueryParams, timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ value: WirePluginInstallParams, timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion {
        guard let refreshDecisions else { throw EngineClientError.unsupportedCapability }
        requests.append("diagnostics")
        let data = try WireDiagnostics(refreshDecisions: refreshDecisions, protocolVersion: "1.0", serverVersion: "synthetic", uptimeSeconds: 0, scopes: [])
        await store.consume(.response(requestID: .string("diagnostics"), .diagnostics(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: data), delivery: context))))
        return .init(requestID: .string("diagnostics"))
    }
}
@MainActor private final class Post429Fixture {
    static let ids = ["aaaaaaaaaaaaaaaa", "bbbbbbbbbbbbbbbb", "cccccccccccccccc"]
    let clock = Post429Clock(), timer = Post429Timer()
    let root: URL, store: SettingsStore
    var app: EngineDockMenuApplication!
    var engine: Post429Engine!
    var refreshDecisions: [WireRefreshDecision]?
    var raw: [String: Any]
    var pointer = CGPoint(x: 700, y: 400), cardFrame: CGRect?, presence = DockPresence()
    var displays = [DockDisplayArea(id: "primary", frame: .init(x: 0,y: 0,width: 1440,height: 900), visibleFrame: .init(x: 0,y: 80,width: 1440,height: 820))]
    var notificationRequests: [String] = []
    var host: StaticDockPreviewHost { app.composition.dock }
    var editor: SettingsEditor { app.settingsHost.application.editor }
    static func stamp(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }
    init(profile: URL? = nil, wall: Date? = nil) throws {
        root = profile ?? FileManager.default.temporaryDirectory.appendingPathComponent("g1-d-" + UUID().uuidString)
        store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../..").standardizedFileURL
        raw = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: repo.appendingPathComponent("schema/app-cli/captures/WireRowsSnapshot.json"))) as? [String: Any])
        if let wall { clock.wall = wall }
        var projection = try XCTUnwrap(raw["projection"] as? [String: Any])
        let base = try XCTUnwrap((projection["rows"] as? [[String: Any]])?.first)
        let account = try XCTUnwrap((base["accounts"] as? [[String: Any]])?.first)
        let window = try XCTUnwrap((account["windows"] as? [[String: Any]])?.first)
        var rows: [[String: Any]] = []
        for rowIndex in 0..<2 {
            var row = base; row["id"] = rowIndex == 0 ? "codex" : "claude-code"; row["order"] = rowIndex
            row["name"] = ["en": rowIndex == 0 ? "Synthetic Alpha" : "Synthetic Beta", "zh": rowIndex == 0 ? "合成甲" : "合成乙"]
            row["state"] = "fresh"; row["consent"] = "allowed"; row["surfaces"] = ["dock","menu","settings"]; row["expiresAt"] = "2099-01-01T00:00:00Z"
            row["accounts"] = (rowIndex == 0 ? [0,1] : [2]).map { index -> [String: Any] in
                var a = account; a["subscriptionRef"] = Self.ids[index]; a["route"] = "runtime_rpc"; a["valueState"] = "current"
                a["observedAt"] = Self.stamp(clock.wall.addingTimeInterval(-60)); a["freshUntil"] = "2099-01-01T00:00:00Z"
                a["plan"] = ["id":"pro", "name":["en":"Synthetic Pro","zh":"合成专业"]]
                a["credits"] = ["balance":1500,"unit":"credits"]
                a["windows"] = [0,1].map { number -> [String: Any] in
                    var w = window; w["id"] = number == 0 ? "short" : "week"; w["role"] = number == 0 ? "session" : "weekly"
                    w["durationSeconds"] = number == 0 ? 18000 : 604800; w["limitKey"] = number == 0 ? "five_hour" : "weekly"; w["poolKey"] = "main"
                    w["remainingPercent"] = number == 0 ? [41,26,0][index] : [70,60,50][index]
                    w["current"] = true; w["observedAt"] = Self.stamp(clock.wall.addingTimeInterval(-60)); w["validUntil"] = "2099-01-01T00:00:00Z"
                    w["resetsAt"] = Self.stamp(clock.wall.addingTimeInterval(number == 0 ? 8040 : 86400)); w["validUntil"] = w["resetsAt"]; w.removeValue(forKey:"modelScope")
                    return w
                }
                return a
            }
            rows.append(row)
        }
        projection["rows"] = rows; projection["resetEvents"] = []; raw["projection"] = projection
    }
    func open(autoHide: Bool = false, cockpitEnabled: Bool = false, notifications: Bool = false, windowEntry: Bool = false) async throws {
        _ = try await store.update { p in p.autoHide = autoHide; p.showDock = true; p.language = .english; p.motion = .on; if notifications { p.notifications.optedIn = true }; for _ in 0..<16 { p.onboarding.next() } }
        let rows = try decode()
        app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true), settingsStore: store, createsNativePanels: windowEntry, cockpitEntryEnabled: cockpitEnabled,
            dockEnvironment: { [weak self] in guard let self else { return .init(displays: [], layouts: []) }; return .init(displays: self.displays, layouts: [], primaryDisplayID: "primary", pointer: self.pointer, presence: self.presence, cardFrame: self.cardFrame) },
            deadlineNow: { [clock] in clock.wall }, deadlineElapsed: { [clock] in clock.elapsed }, deadlineScheduling: timer,
            makeClient: { [weak self] _, store in let engine = Post429Engine(store: store, rows: rows, refreshDecisions: self?.refreshDecisions); self?.engine = engine; return engine }, activateSettings: {})
        app.composition.setResetNotificationDelivery { [weak self] in self?.notificationRequests.append($0) }
        if windowEntry {
            // Exercise the WINDOW composition and real notifier without presenting any window or reading OS authorization.
            await app.composition.start()
        } else { await app.prepare(); app.allowDockPresentation(); await app.composition.start(); tick(0.5) }
    }
    func decode() throws -> WireRowsSnapshot { try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: raw)) }
    func publish() async throws { raw["sequence"] = ((raw["sequence"] as? Int) ?? 1) + 1; try await engine.deliver(decode()) }
    func mutateFirst(_ edit: (inout [String: Any]) -> Void) {
        var p = raw["projection"] as! [String: Any], rows = p["rows"] as! [[String: Any]], accounts = rows[0]["accounts"] as! [[String: Any]]
        edit(&accounts[0]); rows[0]["accounts"] = accounts; p["rows"] = rows; raw["projection"] = p
    }
    func tick(_ seconds: Double) { clock.elapsed += seconds; clock.wall.addTimeInterval(seconds); timer.fireIfDue(clock.elapsed); host.refreshPresence(); host.interactionControllerForChecks?.refresh() }
    func card(_ selectedID: String? = nil) throws -> DockCardContent { try XCTUnwrap(host.cardContent(for: selectedID ?? Self.ids[0], at: clock.wall)) }
    func close() async { if let app { await app.composition.stop() }; try? FileManager.default.removeItem(at: root) }
}


@MainActor final class Post429CardDiagnosticsJourneyTests:XCTestCase {
    func testPost429RecentRefreshesUseNegotiatedAdmittedDiagnostics() async throws {
        let f = try Post429Fixture(); addTeardownBlock { @MainActor in await f.close() }
        f.refreshDecisions = try (0..<24).map { try WireRefreshDecision(agoSeconds: Int64($0 * 60), scope: .codexRuntimeUsage, outcome: .succeeded, reason: .completed) }
        f.refreshDecisions?.append(try .init(agoSeconds: 0, scope: .unknown("untrusted-scope"), outcome: .succeeded, reason: .completed))
        try await f.open()
        try await complete { f.app.currentSettingsContext.refreshHistory != nil }
        let history = try XCTUnwrap(f.app.currentSettingsContext.refreshHistory)
        XCTAssertEqual(history.count, 20)
        XCTAssertTrue(history.allSatisfy { $0.scope == "codex.runtime_usage" && $0.outcome == "Succeeded" })
        let presented = try XCTUnwrap(SettingsCatalogue.rows(preferences: try XCTUnwrap(f.editor.snapshot).preferences, context: f.app.currentSettingsContext, paneID: "diagnostics").first { $0.key == .refreshHistory })
        guard case .text(let summary) = presented.value else { return XCTFail("History must be presented as text") }
        XCTAssertTrue(summary.contains("codex.runtime_usage")); XCTAssertFalse(summary.contains("untrusted-scope"))
        _ = try await f.editor.commit(SettingsB21Edit.language(.chinese))
        try await f.publish()
        XCTAssertEqual(f.app.currentSettingsContext.refreshHistory?.first?.outcome, "成功")
        XCTAssertEqual(f.app.currentSettingsContext.refreshHistory?.first?.reason, "已完成")
        await f.app.composition.store.consume(.clearPrivateViews(.init(revision:2,reason:.connectionLost,previous:nil,nextFloor:nil)))
        XCTAssertNil(f.app.currentSettingsContext.refreshHistory)
        XCTAssertFalse(try SettingsCatalogue.rows(preferences: try XCTUnwrap(f.editor.snapshot).preferences, context: f.app.currentSettingsContext, paneID: "diagnostics").contains { $0.key == .refreshHistory })
    }
    func testPost429RecentRefreshesHideWithoutCapabilityAndExplainEmptyHistory() async throws {
        let unsupported = try await fixture()
        XCTAssertNil(unsupported.app.currentSettingsContext.refreshHistory)
        let trace = await unsupported.engine.trace(); XCTAssertFalse(trace.contains("diagnostics"))
        let f = try Post429Fixture(); addTeardownBlock { @MainActor in await f.close() }; f.refreshDecisions = []
        try await f.open(); try await complete { f.app.currentSettingsContext.refreshHistory != nil }
        let row = try XCTUnwrap(SettingsCatalogue.rows(preferences: try XCTUnwrap(f.editor.snapshot).preferences, context: f.app.currentSettingsContext, paneID: "diagnostics").first { $0.key == .refreshHistory })
        XCTAssertEqual(row.value, .text("No recent refreshes"))
        _ = try await f.editor.commit(SettingsB21Edit.language(.chinese))
        XCTAssertEqual(try SettingsCatalogue.rows(preferences: try XCTUnwrap(f.editor.snapshot).preferences, context: f.app.currentSettingsContext, paneID: "diagnostics").first { $0.key == .refreshHistory }?.value, .text("暂无刷新记录"))
    }
    private func fixture(autoHide: Bool = false, cockpitEnabled: Bool = false) async throws -> Post429Fixture { let f = try Post429Fixture(); addTeardownBlock { @MainActor in await f.close() }; try await f.open(autoHide: autoHide, cockpitEnabled: cockpitEnabled); return f }
    private func complete(_ condition: @escaping @MainActor () async -> Bool) async throws { let deadline = ContinuousClock.now + .seconds(15); while !(await condition()) { guard ContinuousClock.now < deadline else { XCTFail("Async delivery did not complete"); return }; await Task.yield() } }
    func testPost429HeaderUsesSelectedWindowSourceAndObservation() async throws {
        let f=try await fixture()
        f.mutateFirst { account in
            account["observedAt"]=Post429Fixture.stamp(f.clock.wall.addingTimeInterval(-7200))
            var windows=account["windows"] as! [[String:Any]]
            windows[0]["source"]="local_history";windows[0]["observedAt"]=Post429Fixture.stamp(f.clock.wall.addingTimeInterval(-37*60))
            windows[1]["source"]="runtime";windows[1]["observedAt"]=Post429Fixture.stamp(f.clock.wall.addingTimeInterval(-11*60))
            account["windows"]=windows
        }
        try await f.publish()
        XCTAssertEqual(try f.card().sourceAndAge,"Local history · 37m ago")
        _ = try await f.editor.commit(SettingsB20Edit.percentagePin(Post429Fixture.ids[0],.week))
        XCTAssertEqual(try f.card().sourceAndAge,"Tool runtime · 11m ago")
        _ = try await f.editor.commit(SettingsB21Edit.language(.chinese))
        XCTAssertEqual(try f.card().sourceAndAge,"工具运行时 · 11分钟前")
        f.mutateFirst { account in var windows=account["windows"] as! [[String:Any]];windows[1].removeValue(forKey:"source");windows[1].removeValue(forKey:"observedAt");account["windows"]=windows }
        try await f.publish()
        XCTAssertEqual(try f.card().sourceAndAge,"未知来源 · 读数时间未知")
    }
    func testPost429DiagnosticsUseMemberRefreshNotBeforeAndClearIt() async throws {
        let f=try await fixture()
        let next=Date(timeIntervalSince1970:floor(f.clock.wall.timeIntervalSince1970)+120)
        var projection=f.raw["projection"] as! [String:Any], rows=projection["rows"] as! [[String:Any]], accounts=rows[0]["accounts"] as! [[String:Any]]
        accounts[1].removeValue(forKey:"refreshNotBefore");rows[0]["accounts"]=accounts;projection["rows"]=rows;f.raw["projection"]=projection
        f.mutateFirst { $0["refreshNotBefore"]=Post429Fixture.stamp(next) };try await f.publish()
        let readers=f.app.currentSettingsContext.readerDiagnostics
        XCTAssertEqual(readers.count,3)
        XCTAssertEqual(readers.first?.nextRefresh,next)
        XCTAssertNil(readers[1].nextRefresh,"No cross-member fallback")
        await f.app.composition.store.consume(.clearPrivateViews(.init(revision:2,reason:.connectionLost,previous:nil,nextFloor:nil)))
        XCTAssertTrue(f.app.currentSettingsContext.readerDiagnostics.isEmpty)
    }
    func testPost429MissingNextStepHasAnActualSettingsFallbackInBothLanguages() async throws {
        let f=try await fixture()
        var projection=f.raw["projection"] as! [String:Any], rows=projection["rows"] as! [[String:Any]]
        rows[0]["state"]="failed";rows[0].removeValue(forKey:"nextStep")
        rows[0]["reason"]=["code":"read_failed","text":["en":"Read failed","zh":"读取失败"]]
        projection["rows"]=rows;f.raw["projection"]=projection
        try await f.publish()
        XCTAssertEqual(f.app.composition.presentedContent.snapshot.presentationRows[Post429Fixture.ids[0]]?.nextStep,"Open Settings to review this subscription.")
        _ = try await f.editor.commit(SettingsB21Edit.language(.chinese))
        XCTAssertEqual(f.app.composition.presentedContent.snapshot.presentationRows[Post429Fixture.ids[0]]?.nextStep,"打开设置检查此订阅。")
        rows[0]["nextStep"]=["action":"none","text":["en":"  ","zh":"  "]]
        projection["rows"]=rows;f.raw["projection"]=projection;try await f.publish()
        XCTAssertEqual(f.app.composition.presentedContent.snapshot.presentationRows[Post429Fixture.ids[0]]?.nextStep,"打开设置检查此订阅。")
    }
}
