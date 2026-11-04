// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
@_spi(DockResourceChecks) import ModelPlanDock
@testable import ModelPlanAppIntegration

@MainActor private final class G1DClock {
    var wall = Date(timeIntervalSince1970: 1_800_000_000)
    var elapsed = 10.0
}
@MainActor private final class G1DTimer: DockEdgeScheduling {
    var deadline: Double?, action: (@MainActor () -> Void)?
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) { self.deadline = deadline; self.action = action }
    func cancel() { deadline = nil; action = nil }
    func fireIfDue(_ now: Double) { if let deadline, now >= deadline { let saved = action; cancel(); saved?() } }
}
private actor G1DEngine: EngineClient {
    let store: EngineStore
    let context = EngineDeliveryContext(sessionID: "g1-d", floor: .init(storeEpoch: "g1-d", generation: 1), revision: 1)
    var rows: WireRowsSnapshot
    var requests: [String] = []
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    nonisolated func isCurrent(_ value: EngineDeliveryContext) -> Bool { value.sessionID == "g1-d" && value.revision == 1 }
    func supportsCapability(_ value: String) async -> Bool { value == "memberRefreshV1" }
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
    func diagnostics(timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}
@MainActor private final class G1DFixture {
    static let ids = ["aaaaaaaaaaaaaaaa", "bbbbbbbbbbbbbbbb", "cccccccccccccccc"]
    let clock = G1DClock(), timer = G1DTimer()
    let root: URL, store: SettingsStore
    var app: EngineDockMenuApplication!
    var engine: G1DEngine!
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
        let previousLedger = EngineRowsEntry.isolatedNativeNotificationLedgerForChecks
        EngineRowsEntry.isolatedNativeNotificationLedgerForChecks = root.appendingPathComponent("g1-notifications.json")
        app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true), settingsStore: store, createsNativePanels: windowEntry, cockpitEntryEnabled: cockpitEnabled,
            dockEnvironment: { [weak self] in guard let self else { return .init(displays: [], layouts: []) }; return .init(displays: self.displays, layouts: [], primaryDisplayID: "primary", pointer: self.pointer, presence: self.presence, cardFrame: self.cardFrame) },
            deadlineNow: { [clock] in clock.wall }, deadlineElapsed: { [clock] in clock.elapsed }, deadlineScheduling: timer,
            makeClient: { [weak self] _, store in let engine = G1DEngine(store: store, rows: rows); self?.engine = engine; return engine }, activateSettings: {})
        EngineRowsEntry.isolatedNativeNotificationLedgerForChecks = previousLedger
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
    func event(status: String = "announced", lifetime: Double = 3600, restarted: Bool = false) async throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../..").standardizedFileURL
        let fixture = try JSONSerialization.jsonObject(with: Data(contentsOf: repo.appendingPathComponent("schema/app-cli/proposals/fixtures/scheduled-announcement.json"))) as! [String: Any]
        let data = (fixture["result"] as! [String: Any])["data"] as! [String: Any]
        var e = ((data["projection"] as! [String: Any])["resetEvents"] as! [[String: Any]])[0]
        e["status"] = status; e["publishedAt"] = Self.stamp(clock.wall.addingTimeInterval(-1)); e["expiresAt"] = Self.stamp(clock.wall.addingTimeInterval(lifetime))
        e["schedule"] = ["precision":"window", "from": Self.stamp(clock.wall.addingTimeInterval(-1)), "through":Self.stamp(clock.wall.addingTimeInterval(lifetime))]
        if status == "confirmed" { e["confirms"] = e["id"] }
        var p = raw["projection"] as! [String: Any]; p["resetEvents"] = [e]; raw["projection"] = p
        if restarted { mutateFirst { a in var windows = a["windows"] as! [[String: Any]]; for i in windows.indices { windows[i]["observedAt"] = Self.stamp(clock.wall); windows[i]["resetsAt"] = Self.stamp(clock.wall.addingTimeInterval(7200)); windows[i]["validUntil"] = windows[i]["resetsAt"] }; a["windows"] = windows } }
        try await publish()
    }
    func tick(_ seconds: Double) { clock.elapsed += seconds; clock.wall.addTimeInterval(seconds); timer.fireIfDue(clock.elapsed); host.refreshPresence(); host.interactionControllerForChecks?.refresh() }
    func hover(_ selectedID: String? = nil) throws {
        let id = selectedID ?? Self.ids[0]
        let placement = try XCTUnwrap(host.edgePresentation?.placement), rect = try XCTUnwrap(host.dockView.interactionAnchor(id))
        pointer = .init(x: placement.frame.minX + rect.midX, y: placement.frame.maxY - rect.midY)
        try XCTUnwrap(host.dockView.nozzleEventDelegate).hoverNozzle(id)
    }
    func revealFromWake() throws {
        let p = try XCTUnwrap(host.edgePresentation?.placement)
        pointer = .init(x: p.wakeFrame.midX, y: p.wakeFrame.midY)
        tick(0); tick(0.151)
        XCTAssertEqual(host.edgePresentation?.state, .expanded)
    }
    func card(_ selectedID: String? = nil) throws -> DockCardContent { try XCTUnwrap(host.cardContent(for: selectedID ?? Self.ids[0], at: clock.wall)) }
    func close() async { if let app { await app.composition.stop() }; try? FileManager.default.removeItem(at: root) }
}

@MainActor final class G1DockJourneysD: XCTestCase {
    private func fixture(autoHide: Bool = false, cockpitEnabled: Bool = false) async throws -> G1DFixture { let f = try G1DFixture(); addTeardownBlock { @MainActor in await f.close() }; try await f.open(autoHide: autoHide, cockpitEnabled: cockpitEnabled); return f }
    private func complete(_ condition: @escaping @MainActor () async -> Bool) async throws { let deadline = ContinuousClock.now + .seconds(15); while !(await condition()) { guard ContinuousClock.now < deadline else { XCTFail("Async delivery did not complete"); return }; await Task.yield() } }
    private func seam(_ id: String, _ reason: String) async throws {
        let f = try await fixture(); XCTAssertNotNil(f.host.edgePresentation)
        if id.hasPrefix("DOCK-3.8") { try f.hover(); f.tick(0.25); XCTAssertFalse(f.host.card.isHidden) }
        throw XCTSkip("\(id): SEAM-NEEDED \(reason)")
    }
    func testPost429HeaderUsesSelectedWindowSourceAndObservation() async throws {
        let f=try await fixture()
        f.mutateFirst { account in
            account["observedAt"]=G1DFixture.stamp(f.clock.wall.addingTimeInterval(-7200))
            var windows=account["windows"] as! [[String:Any]]
            windows[0]["source"]="local_history";windows[0]["observedAt"]=G1DFixture.stamp(f.clock.wall.addingTimeInterval(-37*60))
            windows[1]["source"]="runtime";windows[1]["observedAt"]=G1DFixture.stamp(f.clock.wall.addingTimeInterval(-11*60))
            account["windows"]=windows
        }
        try await f.publish()
        XCTAssertEqual(try f.card().sourceAndAge,"Local history · 37m ago")
        _ = try await f.editor.commit(SettingsB20Edit.percentagePin(G1DFixture.ids[0],.week))
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
        f.mutateFirst { $0["refreshNotBefore"]=G1DFixture.stamp(next) };try await f.publish()
        let readers=f.app.currentSettingsContext.readerDiagnostics
        XCTAssertEqual(readers.count,3)
        XCTAssertEqual(readers.first?.nextRefresh,next)
        XCTAssertNil(readers[1].nextRefresh,"No cross-member fallback")
        await f.app.composition.store.consume(.clearPrivateViews(.init(revision:2,reason:.connectionLost,previous:nil,nextFloor:nil)))
        XCTAssertTrue(f.app.currentSettingsContext.readerDiagnostics.isEmpty)
    }
    private func quotaSliverFixture() async throws -> G1DFixture {
        let f = try G1DFixture(); addTeardownBlock { @MainActor in await f.close() }
        var projection = f.raw["projection"] as! [String:Any]
        var row = (projection["rows"] as! [[String:Any]])[0]
        let account = (row["accounts"] as! [[String:Any]])[0]
        row["accounts"] = [41.0,40,26,25,0].enumerated().map { index, value -> [String:Any] in
            var next = account
            next["subscriptionRef"] = String(repeating:["a","b","c","d","e"][index],count:16)
            var windows = next["windows"] as! [[String:Any]]
            for i in windows.indices { windows[i]["remainingPercent"] = i == 0 ? value:90.0 }
            next["windows"] = windows
            return next
        }
        projection["rows"] = [row]; f.raw["projection"] = projection
        try await f.open(autoHide:true)
        return f
    }
    func testNormalEntrySliverQuotaColorsUseDefaultThreshold() async throws {
        let f = try await quotaSliverFixture()
        XCTAssertEqual(f.editor.snapshot?.preferences.redBelow,25)
        XCTAssertTrue(f.editor.snapshot?.preferences.sliverAlert == true)
        let size = try XCTUnwrap(f.host.edgePresentation?.placement).sliverFrame.size
        _ = try f.host.prepareSliver(size:size)
        let segments = f.host.sliverQuotaColorsForChecks
        XCTAssertEqual(segments.count,5)
        XCTAssertEqual(segments.compactMap(\.remainingPercent),[41,40,26,25,0])
        XCTAssertEqual(segments.map(\.quotaRole),[nil,.warning,.warning,.critical,.critical])
        XCTAssertNil(segments.first?.quotaRole,"41% must leave its pitch neutral; no teal segment")
        XCTAssertEqual(segments.first?.opacity,0)
        XCTAssertTrue(segments.filter { $0.quotaRole != nil }.allSatisfy { $0.opacity > 0 && $0.opacity < 0.5 })
        XCTAssertEqual(segments.map(\.rgbaHex),["","#EAC17BFF","#EAC17BFF","#EF4444FF","#EF4444FF"])
        XCTAssertEqual(segments.compactMap(\.subscriptionID), ["a","b","c","d","e"].map { String(repeating:$0,count:16) })
        let geometry = try XCTUnwrap(f.host.resolvedT2CurvatureForChecks)
        let station = try XCTUnwrap(geometry.stations.first { $0.subscription?.id == String(repeating:"b",count:16) })
        let amber = try XCTUnwrap(segments.first { $0.subscriptionID == station.subscription?.id })
        XCTAssertEqual((amber.through-amber.from)*Double(size.height),Double(station.pitch),accuracy:0.01,"Alert length must be its registered pitch, not one fifth of the whole strip")
        _ = try await f.editor.commit(SettingsB21Edit.dockEdge(.bottom))
        let horizontalSize = try XCTUnwrap(f.host.edgePresentation?.placement).sliverFrame.size
        _ = try f.host.prepareSliver(size:horizontalSize)
        XCTAssertEqual(f.host.sliverQuotaColorsForChecks.map(\.remainingPercent),segments.map(\.remainingPercent))
        XCTAssertEqual(f.host.sliverQuotaColorsForChecks.map(\.quotaRole),segments.map(\.quotaRole))

    }
    func testNormalEntrySliverQuotaColorsFollowLiveThreshold16() async throws {
        let f = try await quotaSliverFixture()
        _ = try f.host.prepareSliver(size:.init(width:4,height:240))
        _ = try await f.editor.commit(SettingsB20Edit.redBelow(16))
        let segments = f.host.sliverQuotaColorsForChecks
        XCTAssertEqual(segments.count,5)
        XCTAssertEqual(segments.compactMap(\.remainingPercent),[41,40,26,25,0])
        XCTAssertEqual(segments.map(\.quotaRole),[nil,.warning,.warning,.warning,.critical])
        f.mutateFirst { account in
            var windows = account["windows"] as! [[String:Any]]
            windows[0]["remainingPercent"] = 16.0; account["windows"] = windows
        }
        try await f.publish()
        XCTAssertEqual(f.host.sliverQuotaColorsForChecks.first?.remainingPercent,16)
        XCTAssertEqual(f.host.sliverQuotaColorsForChecks.first?.quotaRole,.critical)
        f.mutateFirst { account in
            var windows = account["windows"] as! [[String:Any]]
            windows[0]["remainingPercent"] = 17.0; account["windows"] = windows
        }
        try await f.publish()
        XCTAssertEqual(f.host.sliverQuotaColorsForChecks.first?.quotaRole,.warning)
        f.mutateFirst { account in
            var windows = account["windows"] as! [[String:Any]]
            windows[0]["remainingPercent"] = 41.0; account["windows"] = windows
        }
        try await f.publish()
        XCTAssertNil(f.host.sliverQuotaColorsForChecks.first?.quotaRole,"Improvement removes the quota alert")
        XCTAssertEqual(f.host.sliverQuotaColorsForChecks.first?.rgbaHex,"")
        _ = try await f.editor.commit(SettingsB20Edit.percentageMode(.used))
        XCTAssertEqual(f.host.sliverQuotaColorsForChecks.first?.remainingPercent,41,"Colour always uses remaining quota")
        _ = try await f.editor.commit(SettingsB20Edit.sliverAlert(false))
        XCTAssertTrue(f.host.sliverQuotaColorsForChecks.isEmpty)
        _ = try await f.editor.commit(SettingsB20Edit.sliverAlert(true))
        let ids = ["a","b","c","d","e"].map { String(repeating:$0,count:16) }
        _ = try await f.editor.commit(SettingsB21Edit.moveSubscription(ids[4],to:0,expectedOrder:ids))
        XCTAssertEqual(f.host.sliverQuotaColorsForChecks.first?.subscriptionID,ids[4])
        XCTAssertEqual(f.host.sliverQuotaColorsForChecks.first?.remainingPercent,0)
        XCTAssertEqual(f.host.sliverQuotaColorsForChecks.first?.quotaRole,.critical)

    }
    func testNormalEntrySliverWithholdsUnprovenValuesAndClearsBindings() async throws {
        let f = try await quotaSliverFixture()
        _ = try f.host.prepareSliver(size:.init(width:4,height:240))
        f.mutateFirst { account in
            var windows = account["windows"] as! [[String:Any]]
            for i in windows.indices { windows[i].removeValue(forKey:"remainingPercent") }
            account["windows"] = windows
        }
        try await f.publish()
        let segments = f.host.sliverQuotaColorsForChecks
        XCTAssertEqual(segments.count,5)
        let unknown = try XCTUnwrap(segments.first { $0.subscriptionID == String(repeating:"a",count:16) })
        XCTAssertNil(unknown.remainingPercent); XCTAssertNil(unknown.quotaRole)
        XCTAssertEqual(segments.first { $0.subscriptionID == String(repeating:"b",count:16) }?.remainingPercent,40)
        await f.app.composition.store.consume(.clearPrivateViews(.init(revision:2,reason:.connectionLost,previous:nil,nextFloor:nil)))
        XCTAssertTrue(f.host.sliverQuotaColorsForChecks.isEmpty)
    }
    func testNormalEntryReportsDrawOrderResourceFiltersNozzleMaterialsAndClockDots() async throws {
        let f = try await fixture(); let view = f.host.dockView, first = G1DFixture.ids[0]
        var projection = f.raw["projection"] as! [String:Any], rows = projection["rows"] as! [[String:Any]]
        rows[0]["vendorKey"] = "openai"; projection["rows"] = rows; f.raw["projection"] = projection
        try await f.publish()
        let roles = view.renderedLayerRolesForChecks
        XCTAssertEqual(roles.first?.role, "face.supplied-material")
        let outer = try XCTUnwrap(roles.firstIndex { $0.subscriptionID == first && $0.role == "quota.outer" })
        let inner = try XCTUnwrap(roles.firstIndex { $0.subscriptionID == first && $0.role == "quota.inner" })
        let readout = try XCTUnwrap(roles.firstIndex { $0.subscriptionID == first && $0.role == "readout" })
        XCTAssertLessThan(outer, inner); XCTAssertLessThan(inner, readout)
        let resources = view.renderedResourceFiltersForChecks
        XCTAssertTrue(resources.contains { $0.preservesSourcePixels && $0.interpolationQuality == .high })
        XCTAssertTrue(resources.contains { $0.fitsVisibleGlyph && $0.interpolationQuality == .none })
        XCTAssertTrue(resources.contains { $0.subscriptionID == first && !$0.fitsVisibleGlyph })
        let nozzle = try XCTUnwrap(view.renderedNozzleMaterialForChecks[first])
        XCTAssertEqual(nozzle.resources.count, 4); XCTAssertNil(nozzle.replacementResource)
        XCTAssertNotNil(nozzle.caseInk); XCTAssertNotNil(nozzle.radialOverlay)
        let clock = try XCTUnwrap(view.renderedClockDotsForChecks[first])
        XCTAssertGreaterThan(clock.positions, 0); XCTAssertGreaterThan(clock.litCentres.count, 0)
        XCTAssertLessThanOrEqual(clock.litCentres.count, clock.positions)
        XCTAssertGreaterThan(clock.dotRadius, 0); XCTAssertGreaterThan(clock.backingWidth, 0)
        let frame = view.frame
        _ = view.renderedResourceFiltersForChecks; _ = view.renderedClockDotsForChecks
        XCTAssertEqual(view.frame, frame)
        await f.app.composition.store.consume(.clearPrivateViews(.init(revision:2,reason:.connectionLost,previous:nil,nextFloor:nil)))
        XCTAssertTrue(view.renderedLayerRolesForChecks.allSatisfy { $0.subscriptionID == nil })
        XCTAssertTrue(view.renderedResourceFiltersForChecks.allSatisfy { $0.subscriptionID == nil })
        XCTAssertTrue(view.renderedNozzleMaterialForChecks.isEmpty); XCTAssertTrue(view.renderedClockDotsForChecks.isEmpty)
    }
    func testNormalEntryIgnitionInspectionFollowsTheBuildSwitchAndExposesActualGrip() async throws {
        for enabled in [false, true] {
            let f = try await fixture(cockpitEnabled:enabled)
            let ignition = try XCTUnwrap(f.host.ignitionPresentationForChecks)
            XCTAssertEqual(ignition.enabled, enabled); XCTAssertEqual(ignition.veilVisible, !enabled)
            XCTAssertTrue(ignition.visible); XCTAssertGreaterThan(ignition.frame.width, 0)
            let grip = try XCTUnwrap(f.host.resolvedT2GripForChecks)
            XCTAssertTrue(grip.x.isFinite && grip.y.isFinite)
            XCTAssertNotEqual(grip, f.host.resolvedT2CurvatureForChecks?.button)
            await f.app.composition.store.consume(.clearPrivateViews(.init(revision:2,reason:.connectionLost,previous:nil,nextFloor:nil)))
            XCTAssertNotNil(f.host.resolvedT2GripForChecks, "The actual empty widget still renders its public grip")
            XCTAssertTrue(f.host.resolvedT2GapAndOverflowForChecks?.shownIDs.isEmpty == true)
        }
    }
    func testNormalEntryExposesSuccessfulDrawMetadataAndRetiresItOnClear() async throws {
        let f = try await fixture()
        _ = try await f.editor.commit(SettingsB21Edit.alias(.init(subscriptionID: G1DFixture.ids[0], committed: "Alpha")))
        let view = f.host.dockView
        let face = try XCTUnwrap(view.renderedFaceMaterialForChecks)
        XCTAssertEqual(face.source, .suppliedMaterial)
        XCTAssertGreaterThan(face.pixelSize.width, 0)
        let readout = try XCTUnwrap(view.renderedReadoutBackingForChecks[G1DFixture.ids[0]])
        let alias = try XCTUnwrap(view.renderedAliasBackingForChecks[G1DFixture.ids[0]])
        XCTAssertFalse(readout.hasDedicatedBacking)
        XCTAssertFalse(alias.hasDedicatedBacking)
        let transform = try XCTUnwrap(view.renderedReadoutTransformsForChecks[G1DFixture.ids[0]])
        XCTAssertEqual(transform.b, 0); XCTAssertEqual(transform.c, 0)
        let gap = try XCTUnwrap(f.host.resolvedT2GapAndOverflowForChecks)
        XCTAssertGreaterThan(gap.gap, 0)
        XCTAssertEqual(gap.shownIDs, G1DFixture.ids); XCTAssertTrue(gap.overflowIDs.isEmpty)
        let curvature = try XCTUnwrap(f.host.resolvedT2CurvatureForChecks)
        XCTAssertGreaterThan(curvature.radius, 0); XCTAssertEqual(curvature.stations.count, 3)
        let frame = view.frame
        _ = view.renderedFaceMaterialForChecks; _ = f.host.resolvedT2CurvatureForChecks
        XCTAssertEqual(view.frame, frame)
        _ = try await f.editor.commit(SettingsB21Edit.dockEdge(.left))
        XCTAssertEqual(f.host.resolvedT2CurvatureForChecks?.input.coordinates.edge, .left)
        await f.app.composition.store.consume(.clearPrivateViews(.init(revision:2,reason:.connectionLost,previous:nil,nextFloor:nil)))
        XCTAssertTrue(view.renderedReadoutTransformsForChecks.isEmpty)
        XCTAssertTrue(view.renderedAliasBackingForChecks.isEmpty)
    }
    func testG1_DOCK_3_6_01() async throws {
        let f = try await fixture(autoHide: true)
        for (size, thickness) in [(SettingsSize.small, 4.0*36/44),(.medium,4),(.large,4.0*52/44)] {
            _ = try await f.editor.commit(SettingsB20Edit.size(size))
            let p = try XCTUnwrap(f.host.edgePresentation?.placement)
            XCTAssertEqual(Double(p.sliverFrame.width), thickness, accuracy: 0.05)
            XCTAssertEqual(p.sliverFrame.height, try XCTUnwrap(f.host.dockView.registeredHullBounds).height, accuracy: 0.05)
        }
    }
    func testG1_DOCK_3_6_03() async throws {
        let f = try await fixture(); let r = try XCTUnwrap(f.host.edgePresentation?.placement?.globalHoverRects.first)
        f.pointer = .init(x:r.minX-11,y:r.midY); f.tick(0); XCTAssertEqual(f.host.interactionEnvironment().insideShared,true)
        f.pointer = .init(x:r.minX-13,y:r.midY); f.tick(0); XCTAssertEqual(f.host.interactionEnvironment().insideShared,false)
    }
    func testG1_DOCK_3_6_04() async throws {
        let f = try await fixture(); try f.hover(); f.tick(0.25); XCTAssertFalse(f.host.card.isHidden)
        let p = try XCTUnwrap(f.host.edgePresentation?.placement)
        f.cardFrame = .init(x:p.frame.minX-312,y:p.frame.midY-90,width:300,height:180)
        f.pointer = .init(x:p.frame.minX-6,y:p.frame.midY); f.tick(1)
        XCTAssertEqual(f.host.interactionEnvironment().insideShared,true); XCTAssertFalse(f.host.card.isHidden)
        f.host.setPresentationAllowed(false); XCTAssertTrue(f.host.card.isHidden)
    }
    func testG1_DOCK_3_6_05() async throws {
        let f = try await fixture(autoHide:true); let p = try XCTUnwrap(f.host.edgePresentation?.placement)
        f.pointer = .init(x:p.wakeFrame.midX,y:p.wakeFrame.midY); f.tick(0); f.tick(0.149)
        XCTAssertEqual(f.host.edgePresentation?.state,.sliver); f.tick(0.002); XCTAssertEqual(f.host.edgePresentation?.state,.expanded)
    }
    func testG1_DOCK_3_6_06() async throws {
        let f = try await fixture(autoHide:true); try f.revealFromWake(); f.tick(0.301)
        f.pointer = .init(x:600,y:400); f.tick(0); f.tick(0.499); XCTAssertEqual(f.host.edgePresentation?.state,.expanded)
        f.tick(0.002); XCTAssertEqual(f.host.edgePresentation?.state,.sliver)
    }
    func testG1_DOCK_3_6_07() async throws { try await seam("DOCK-3.6-07","enabled cockpit lifecycle needs the post-429 Factory integration") }
    func testG1_DOCK_3_6_08() async throws {
        let f = try await fixture(autoHide:true,cockpitEnabled:true); try await f.event(); XCTAssertNotNil(f.app.noticeIndicator.notice)
        f.host.acknowledgeCockpitOpening(); XCTAssertNil(f.app.noticeIndicator.notice)
        _ = try f.host.prepareSliver(size: .init(width:4,height:180)); XCTAssertFalse(f.host.sliverNoticeMarksForChecks.isEmpty)
        let quotaBeforeReveal = f.host.sliverQuotaColorsForChecks.filter { $0.quotaRole != nil }
        XCTAssertFalse(quotaBeforeReveal.isEmpty)
        f.host.acknowledgeDockReveal(); _ = try f.host.prepareSliver(size:.init(width:4,height:180)); XCTAssertTrue(f.host.sliverNoticeMarksForChecks.isEmpty)
        XCTAssertEqual(f.host.sliverQuotaColorsForChecks.filter { $0.quotaRole != nil },quotaBeforeReveal)
    }
    func testG1_DOCK_3_6_09() async throws {
        let f = try await fixture(autoHide:true); try f.revealFromWake()
        let action = DockInstrumentAction.subscription(G1DFixture.ids[0])
        f.tick(0.299); XCTAssertEqual(f.host.dockView.permitsAction?(action,.pointer),false)
        f.tick(0.002); XCTAssertEqual(f.host.dockView.permitsAction?(action,.pointer),true)
    }
    func testG1_DOCK_3_6_10() async throws {
        let f = try await fixture(autoHide:true); try f.revealFromWake(); f.presence.mouseButtonDown=true
        f.pointer = .init(x:600,y:400); f.tick(3); XCTAssertEqual(f.host.edgePresentation?.state,.expanded)
        f.presence.mouseButtonDown=false; f.tick(3); XCTAssertEqual(f.host.edgePresentation?.state,.sliver)
    }
    func testG1_DOCK_3_6_11() async throws {
        let f = try await fixture(autoHide:true); _ = try f.host.prepareSliver(size:.init(width:4,height:180))
        XCTAssertTrue(f.editor.snapshot?.preferences.sliverAlert == true)
        XCTAssertTrue(f.host.sliverQuotaColorsForChecks.contains{$0.remainingPercent == 0})
    }
    func testG1_DOCK_3_6_12() async throws {
        let f = try await fixture(), first=G1DFixture.ids[0], second=G1DFixture.ids[1]
        let events = try XCTUnwrap(f.host.dockView.nozzleEventDelegate)
        let controller = try XCTUnwrap(f.host.interactionControllerForChecks)
        let source = try XCTUnwrap(f.host.dockView.interactionAnchor(first))
        let destination = try XCTUnwrap(f.host.dockView.interactionAnchor(second))
        let placement = try XCTUnwrap(f.host.edgePresentation?.placement)
        let begin=CGPoint(x:source.midX,y:source.midY), end=CGPoint(x:destination.midX,y:destination.midY)
        f.pointer = .init(x:placement.frame.minX+begin.x,y:placement.frame.maxY-begin.y)
        f.presence.mouseButtonDown=true
        XCTAssertTrue(events.beginNozzle(id:first,local:begin))
        events.moveNozzle(local:.init(x:begin.x,y:begin.y+5))
        XCTAssertNil(controller.presentation?.reorder,"Exactly five points is not a drag")
        f.pointer = .init(x:placement.frame.minX+end.x,y:placement.frame.maxY-end.y)
        events.moveNozzle(local:end)
        XCTAssertEqual(controller.presentation?.reorder?.order,[second,first,G1DFixture.ids[2]])
        XCTAssertEqual(controller.presentation?.reorder?.neighbourYieldSeconds,0,"Reduced Motion is instant")
        f.presence.mouseButtonDown=false
        events.endNozzle(global:f.pointer,currentID:first)
        try await complete { !f.editor.isSaving && f.editor.snapshot?.preferences.subscriptions.order == [second,first,G1DFixture.ids[2]] }
        let saved = await f.store.snapshot()
        XCTAssertEqual(saved.preferences.subscriptions.order,[second,first,G1DFixture.ids[2]])
        let trace = await f.engine.trace()
        XCTAssertFalse(trace.contains("member-refresh"),"Dragging must not refresh")
        _ = try await f.editor.commit(SettingsB20Edit.motion(.system))
        f.app.updateSystemAccessibility(SettingsEnvironment())
        // The original fixture reserves the bottom for the system Dock. Make it genuinely eligible.
        f.displays[0] = .init(id:"primary",frame:.init(x:0,y:0,width:1440,height:900),visibleFrame:.init(x:0,y:0,width:1440,height:820))
        f.tick(0)
        _ = try await f.editor.commit(SettingsB21Edit.dockEdge(.bottom))
        f.tick(0)
        try await complete { f.host.edgePresentation?.placement?.edge == .bottom }
        func reversePreview() throws -> (any DockNozzleEventHandling,CGPoint) {
            let port=try XCTUnwrap(f.host.dockView.nozzleEventDelegate)
            let source=try XCTUnwrap(f.host.dockView.interactionAnchor(first)), target=try XCTUnwrap(f.host.dockView.interactionAnchor(second))
            let place=try XCTUnwrap(f.host.edgePresentation?.placement)
            let local=CGPoint(x:source.midX,y:source.midY), destination=CGPoint(x:target.midX,y:target.midY)
            f.pointer = .init(x:place.frame.minX+local.x,y:place.frame.maxY-local.y);f.presence.mouseButtonDown=true
            XCTAssertTrue(port.beginNozzle(id:first,local:local))
            let global=CGPoint(x:place.frame.minX+destination.x,y:place.frame.maxY-destination.y)
            f.pointer=global;port.moveNozzle(local:destination)
            XCTAssertNotEqual(source.midX,target.midX)
            XCTAssertNotNil(controller.presentation?.reorder)
            XCTAssertEqual(controller.presentation?.reorder?.neighbourYieldSeconds,0.150)
            return (port,global)
        }
        _ = try reversePreview()
        f.host.dockView.cancelOperation(nil) // The production Escape command.
        f.presence.mouseButtonDown=false
        XCTAssertFalse(controller.hasCapture);XCTAssertNil(controller.presentation?.reorder)
        var current=await f.store.snapshot()
        XCTAssertEqual(current.preferences.subscriptions.order,saved.preferences.subscriptions.order)
        let (port,_) = try reversePreview()
        f.pointer = .init(x:-100,y:-100);f.presence.mouseButtonDown=false
        port.endNozzle(global:f.pointer,currentID:nil)
        XCTAssertFalse(controller.hasCapture);XCTAssertNil(controller.presentation?.reorder)
        await Task.yield();current=await f.store.snapshot()
        XCTAssertEqual(current.preferences.subscriptions.order,saved.preferences.subscriptions.order,"An outside release must cancel")
        let finalTrace=await f.engine.trace()
        XCTAssertFalse(finalTrace.contains("member-refresh"))

    }
    func testG1_DOCK_3_6_13() async throws {
        let f = try await fixture(); let first=G1DFixture.ids[0]
        XCTAssertTrue(try XCTUnwrap(f.host.dockView.nozzleEventDelegate).optionArrow(id:first,keyCode:125))
        try await complete { !f.editor.isSaving && f.editor.snapshot?.preferences.subscriptions.order.first == G1DFixture.ids[1] }
        XCTAssertTrue(f.host.orderAnnouncementInstalledForChecks)
        XCTAssertEqual(f.host.dockView.accessibilityValue() as? String, "Synthetic Alpha · Account 1, position 2 of 3")
        _ = try await f.editor.commit(SettingsB21Edit.language(.chinese))
        XCTAssertTrue(try XCTUnwrap(f.host.dockView.nozzleEventDelegate).optionArrow(id:first,keyCode:126))
        try await complete { !f.editor.isSaving && f.editor.snapshot?.preferences.subscriptions.order.first == first }
        XCTAssertEqual(f.host.dockView.accessibilityValue() as? String, "合成甲 · 账号 1，第 1 项，共 3 项")
        await f.app.composition.store.consume(.clearPrivateViews(.init(revision:2,reason:.connectionLost,previous:nil,nextFloor:nil)))
        XCTAssertNil(f.host.dockView.accessibilityValue())
    }
    func testG1_DOCK_3_6_14() async throws {
        let f = try await fixture(); let handler=try XCTUnwrap(f.host.dockView.backgroundDragDelegate), p=try XCTUnwrap(f.host.edgePresentation?.placement)
        let bounds=f.host.dockView.bounds
        let points=(0..<Int(bounds.height)).flatMap{y in (0..<Int(bounds.width)).map{x in CGPoint(x:Double(x)+0.5,y:Double(y)+0.5)}}
        let local=try XCTUnwrap(points.first{handler.backgroundCanDrag(local:$0)})
        f.pointer = .init(x:p.frame.minX+local.x,y:p.frame.maxY-local.y); f.presence.mouseButtonDown = true
        XCTAssertTrue(handler.beginBackgroundMove(local:local,global:f.pointer))
        f.pointer = .init(x:1,y:400)
        handler.updateBackgroundMove(global:f.pointer); XCTAssertNotNil(f.host.edgePresentation?.snapPreview)
        f.presence.mouseButtonDown = false; handler.endBackgroundMove(global:f.pointer)
        try await complete { !f.editor.isSaving && f.editor.snapshot?.preferences.dockEdge == .left }
    }
    func testG1_DOCK_3_6_15() async throws {
        let f = try await fixture(); f.displays.append(.init(id:"neighbour",frame:.init(x:1440,y:0,width:1200,height:900),visibleFrame:.init(x:1440,y:80,width:1200,height:820)))
        f.tick(0)
        let p=try XCTUnwrap(f.host.edgePresentation?.placement)
        XCTAssertFalse(p.displayID == "primary" && p.edge == .right)
        XCTAssertEqual(f.editor.snapshot?.preferences.dockEdge,.right,"Topology recovery must not become a preference edit")
    }
    func testG1_DOCK_3_6_16() async throws {
        let f = try await fixture(); f.displays.append(.init(id:"negative",frame:.init(x:-1200,y:-100,width:1200,height:1000),visibleFrame:.init(x:-1200,y:-20,width:1200,height:920)))
        f.tick(0); _ = try await f.editor.commit(SettingsB21Edit.dockDisplay("negative")); _ = try await f.editor.commit(SettingsB21Edit.dockEdge(.left))
        XCTAssertEqual(f.host.edgePresentation?.placement?.displayID,"negative"); XCTAssertLessThan(try XCTUnwrap(f.host.edgePresentation?.placement).frame.minX,0)
        f.displays.removeLast(); f.tick(0); XCTAssertEqual(f.host.edgePresentation?.placement?.displayID,"primary")
    }
    func testG1_DOCK_3_6_17() async throws { try await seam("DOCK-3.6-17","real cockpit attached/detached lifecycle is gated outside the interim Dock entry") }
    func testG1_DOCK_3_6_18() async throws {
        let f = try await fixture(); try f.hover(); f.tick(0.25)
        func all(_ view:NSView)->[NSView]{[view]+view.subviews.flatMap(all)}
        XCTAssertTrue((all(f.host.dockView)+all(f.host.card)).allSatisfy{$0.toolTip == nil})
        XCTAssertFalse((f.host.dockView.accessibilityChildren() ?? []).isEmpty)
    }
    func testG1_DOCK_3_7_02() async throws {
        let f = try await fixture(autoHide:true); try await f.event(); _ = try f.host.prepareSliver(size:.init(width:4,height:180))
        let mark=try XCTUnwrap(f.host.sliverNoticeMarksForChecks.first)
        XCTAssertEqual(mark.notice.tone,.blue); XCTAssertEqual(mark.notice.shape,.hollow)
        f.host.acknowledgeDockReveal(); _ = try f.host.prepareSliver(size:.init(width:4,height:180)); XCTAssertTrue(f.host.sliverNoticeMarksForChecks.isEmpty)
    }
    func testG1_DOCK_3_7_03() async throws {
        let f = try await fixture(); try await f.event(); XCTAssertNotNil(f.app.composition.resetSignals.first?.reset)
        try await f.event(status:"confirmed"); XCTAssertEqual(f.app.composition.resetSignals.first?.reset?.status,.confirmed)
        try await f.event(status:"confirmed",restarted:true); XCTAssertTrue(f.app.composition.resetSignals.first?.reset?.restartedReading == true)
        f.tick(3601); XCTAssertNil(f.app.composition.resetSignals.first?.reset)
    }
    func testG1_DOCK_3_7_04() async throws {
      for windowEntry in [false,true] {
        let first = try G1DFixture(wall: Date().addingTimeInterval(-5))
        addTeardownBlock { @MainActor in await first.close() }
        try await first.open(notifications: true,windowEntry:windowEntry)
        XCTAssertEqual(first.app.composition.nativeNotificationLedgerForChecks,first.root.appendingPathComponent("g1-notifications.json"))
        if windowEntry { XCTAssertNil(first.host.nativePanel) }
        try await first.event(); try await complete { first.notificationRequests.count == 1 }
        try await complete { FileManager.default.fileExists(atPath:first.root.appendingPathComponent("g1-notifications.json").path) }
        try await first.publish(); await Task.yield(); XCTAssertEqual(first.notificationRequests.count,1)
        await first.app.composition.stop()
        let second = try G1DFixture(profile:first.root,wall:first.clock.wall)
        addTeardownBlock { @MainActor in await second.close() }
        second.raw = first.raw
        try await second.open(notifications:true,windowEntry:windowEntry)
        // Queue a distinct event and await it: this also drains the preceding duplicate turn.
        var p = second.raw["projection"] as! [String:Any], events = p["resetEvents"] as! [[String:Any]]
        events[0]["id"] = String(repeating:"e",count:64); p["resetEvents"] = events; second.raw["projection"] = p
        try await second.publish(); try await complete { second.notificationRequests.count == 1 }
        XCTAssertTrue(second.notificationRequests[0].hasPrefix(String(repeating:"e",count:64)))
        if windowEntry { XCTAssertNil(first.host.nativePanel); XCTAssertNil(second.host.nativePanel) }
      }
    }
    func testG1_DOCK_3_7_05() async throws {
        for duration in [3600.0,48*3600,24*3600] as [Double] {
            let f = try await fixture(); try await f.event(status:duration == 24*3600 ? "confirmed":"announced",lifetime:duration)
            let expiry = try XCTUnwrap(f.app.composition.resetSignals.first?.reset?.expiresAt)
            let remaining = expiry.timeIntervalSince(f.clock.wall)
            XCTAssertEqual(remaining, duration, accuracy: 1, "Inspect the actual wire precision instead of inventing a subsecond deadline")
            f.tick(remaining-0.001); XCTAssertNotNil(f.app.composition.resetSignals.first?.reset)
            f.tick(0.002); XCTAssertNil(f.app.composition.resetSignals.first?.reset)
        }
    }
    func testG1_DOCK_3_7_06() async throws {
        let f = try await fixture(); let before=f.host.dockView.presentedReadingsForChecks[G1DFixture.ids[0]]?.remainingPercent
        try await f.event(); XCTAssertEqual(f.host.dockView.presentedReadingsForChecks[G1DFixture.ids[0]]?.remainingPercent,before)
        try await f.event(status:"confirmed"); XCTAssertEqual(f.host.dockView.presentedReadingsForChecks[G1DFixture.ids[0]]?.remainingPercent,before)
        f.mutateFirst { a in var w=a["windows"] as! [[String:Any]];w[0]["remainingPercent"]=90;a["windows"]=w }; try await f.publish()
        XCTAssertEqual(f.host.dockView.presentedReadingsForChecks[G1DFixture.ids[0]]?.remainingPercent,70)
    }
    func testG1_DOCK_3_7_07() async throws {
        let f = try await fixture(); let before=await f.engine.trace(); try await f.event()
        XCTAssertNotNil(f.app.noticeIndicator.notice); let after = await f.engine.trace(); XCTAssertEqual(after,before)
        await f.app.composition.store.consume(.clearPrivateViews(.init(revision:2,reason:.connectionLost,previous:nil,nextFloor:nil)))
        XCTAssertNil(f.app.noticeIndicator.notice)
    }
    func testG1_DOCK_3_8_01() async throws {
        let f = try await fixture(); let id=G1DFixture.ids[0]
        XCTAssertEqual(f.editor.snapshot?.preferences.magnification,.subtle)
        _ = try await f.editor.commit(SettingsB20Edit.motion(.system))
        f.app.updateSystemAccessibility(SettingsEnvironment())
        let before=try XCTUnwrap(f.host.dockView.renderedNozzleTransformsForChecks[id])
        try f.hover();f.tick(0.25)
        let after=try XCTUnwrap(f.host.dockView.renderedNozzleTransformsForChecks[id])
        XCTExpectFailure("DOCK-3.8-01 not implemented: baked nozzle raster has no per-nozzle hover transform; needs a counted independent nozzle compositor, not a fabricated inspection role") {
            XCTAssertEqual(abs(after.a/before.a),1.15,accuracy:0.001,"Subtle hover must change the actual nozzle draw transform")
        }
    }
    func testG1_DOCK_3_8_02() async throws {
        let f = try await fixture();let id=G1DFixture.ids[0]
        _ = try await f.editor.commit(SettingsB20Edit.motion(.system))
        f.app.updateSystemAccessibility(SettingsEnvironment())
        let nozzle=try XCTUnwrap(f.host.dockView.renderedNozzleTransformsForChecks[id])
        let readout=try XCTUnwrap(f.host.dockView.renderedReadoutTransformsForChecks[id])
        try f.hover();f.tick(0.25)
        XCTAssertEqual(f.host.dockView.renderedReadoutTransformsForChecks[id],readout)
        XCTExpectFailure("DOCK-3.8-02 not implemented: readout stays fixed, but independent nozzle magnification is missing in the shared raster renderer") {
            XCTAssertNotEqual(f.host.dockView.renderedNozzleTransformsForChecks[id],nozzle,"Fixed text alone does not establish an independently magnifying nozzle")
        }
        await f.app.composition.store.consume(.clearPrivateViews(.init(revision:2,reason:.connectionLost,previous:nil,nextFloor:nil)))
        XCTAssertTrue(f.host.dockView.renderedNozzleTransformsForChecks.isEmpty)
    }
    func testG1_DOCK_3_8_03() async throws {
        let f = try await fixture(); try f.hover(); f.tick(0.249); XCTAssertTrue(f.host.card.isHidden)
        f.tick(0.002); XCTAssertFalse(f.host.card.isHidden)
        f.pointer = .init(x:500,y:400); try XCTUnwrap(f.host.dockView.nozzleEventDelegate).hoverNozzle(nil)
        f.tick(0); f.tick(0.249); XCTAssertFalse(f.host.card.isHidden);f.tick(0.002);XCTAssertTrue(f.host.card.isHidden)
    }
    func testG1_DOCK_3_8_04() async throws {
        let f = try await fixture();try f.hover();f.tick(0.25)
        let material=try XCTUnwrap(f.host.card.renderedMaterialForChecks)
        XCTAssertEqual(material.passRoles,["background-fill"])
        XCTExpectFailure("DOCK-3.8-04 not implemented: actual card is one generic background fill; approved metal-plate/LCD appearance needs its own visual integration") {
            XCTAssertTrue(material.passRoles.contains("metal-plate") && material.lcdWindow != nil,"Actual card needs the approved metal plate and dark LCD material, not a role label on a solid fill")
        }
        await f.app.composition.store.consume(.clearPrivateViews(.init(revision:2,reason:.connectionLost,previous:nil,nextFloor:nil)))
        XCTAssertNil(f.host.card.renderedMaterialForChecks)
    }
    func testG1_DOCK_3_8_05() async throws {
        let f = try await fixture();try f.hover();f.tick(0.25)
        let card=try f.card();XCTAssertTrue(card.name.contains("Synthetic Alpha"));XCTAssertEqual(card.plan,"Synthetic Pro")
        XCTAssertTrue(card.sourceAndAge.contains(" · "));XCTAssertEqual(card.stateLabel,"")
        XCTAssertEqual(f.host.card.accessibilityLabel(),card.name)
    }
    func testG1_DOCK_3_8_06() async throws {
        let f = try await fixture();try f.hover();f.tick(0.25)
        XCTAssertEqual(f.host.card.quotaBarSegmentCountsForChecks,["quota:short":10,"quota:week":10])
        let card=try f.card();XCTAssertEqual(card.rows.first{$0.id == "quota:short"}?.value,"41%")
        XCTAssertEqual(card.rows.first{$0.id == "quota:week"}?.value,"70%")
    }
    func testG1_DOCK_3_8_07() async throws {
        let f = try await fixture(); let english=try f.card();XCTAssertTrue(english.rows.first{$0.id == "quota:short"}?.detail.contains("2h 14m") == true)
        _ = try await f.editor.commit(SettingsB21Edit.language(.chinese));let chinese=try f.card();XCTAssertTrue(chinese.rows.first{$0.id == "quota:short"}?.detail.contains("2小时14分") == true)
    }
    func testG1_DOCK_3_8_08() async throws {
        let f = try await fixture();let repo=URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("../../../../..").standardizedFileURL
        var facts=try JSONSerialization.jsonObject(with:Data(contentsOf:repo.appendingPathComponent("schema/app-cli/captures/RowsResetCards.json"))) as! [String:Any]
        facts["sources"]=[["source":"codex-account","observedAt":G1DFixture.stamp(f.clock.wall.addingTimeInterval(-60))]]
        facts["earliestExpiresAt"]=G1DFixture.stamp(f.clock.wall.addingTimeInterval(86400));facts["items"]=[["id":String(repeating:"d",count:64),"expiresAt":G1DFixture.stamp(f.clock.wall.addingTimeInterval(86400))]]
        var projection=f.raw["projection"] as! [String:Any], rows=projection["rows"] as! [[String:Any]], accounts=rows[0]["accounts"] as! [[String:Any]]
        accounts[1]["resetCards"]=["state":"unknown","count":NSNull(),"truncated":false,"sources":[]]
        rows[0]["accounts"]=accounts;projection["rows"]=rows;f.raw["projection"]=projection
        f.mutateFirst{$0["resetCards"]=facts};try await f.publish();let card=try f.card()
        XCTAssertTrue(card.rows.contains{$0.kind == .reserve && $0.value == "1,500"})
        let reset = try XCTUnwrap(card.rows.first { $0.id == "reset-cards" })
        XCTAssertEqual(reset.value,"1")
        XCTAssertTrue(reset.detail.contains(facts["earliestExpiresAt"] as! String))
        XCTAssertFalse(try f.card(G1DFixture.ids[1]).rows.contains { $0.id == "reset-cards" },"Do not borrow another account's reset cards")
        facts["state"]="partial"; facts["count"]=7; facts["truncated"]=true
        f.mutateFirst { $0["resetCards"]=facts }; try await f.publish()
        let partial = try XCTUnwrap(try f.card().rows.first { $0.id == "reset-cards" })
        XCTAssertEqual(partial.value,"7","Use the reported count, not the one retained opaque item")
        XCTAssertTrue(partial.detail.contains("Reported subset"))
        _ = try await f.editor.commit(SettingsB21Edit.language(.chinese))
        XCTAssertTrue(try f.card().rows.first { $0.id == "reset-cards" }?.detail.contains("已报告部分") == true)
        facts["state"]="unknown"; facts["count"]=NSNull(); facts.removeValue(forKey:"earliestExpiresAt")
        f.mutateFirst { $0["resetCards"]=facts }; try await f.publish()
        XCTAssertFalse(try f.card().rows.contains { $0.id == "reset-cards" },"Unknown never becomes zero or an inferred item count")
        facts["state"]="complete"; facts["count"]=0; facts["items"]=[]; facts["truncated"]=false
        f.mutateFirst { $0["resetCards"]=facts }; try await f.publish()
        XCTAssertEqual(try f.card().rows.first { $0.id == "reset-cards" }?.value,"0")
    }
    func testG1_DOCK_3_8_09() async throws {
        let f = try await fixture();let card=try f.card()
        XCTAssertFalse(card.rows.contains { ["today", "rate", "sessions"].contains($0.id) }, "Missing source statistics must not become invented numbers")
        throw XCTSkip("DOCK-3.8-09: SEAM-NEEDED RowsAccount carries no today/rate/session inputs for the positive journey; negative unknown state only")
    }
    func testG1_DOCK_3_8_10() async throws {
        let f = try await fixture();try await complete{f.app.memberRefreshAdapter != nil}
        let start=f.host.dockView.refreshSweepCountForChecks
        f.host.dockView.onAction?(.subscription(G1DFixture.ids[0]));try await complete{(await f.engine.trace()).contains("member-refresh")}
        XCTAssertEqual(f.host.dockView.refreshSweepCountForChecks,start+1);XCTAssertFalse(f.host.dockView.refreshSweepAnimatingForChecks)
        let count=(await f.engine.trace()).filter{$0 == "member-refresh"}.count
        f.mutateFirst{$0["refreshNotBefore"]=G1DFixture.stamp(f.clock.wall.addingTimeInterval(60))};try await f.publish()
        f.host.dockView.onAction?(.subscription(G1DFixture.ids[0]));await Task.yield()
        let after = await f.engine.trace()
        XCTAssertEqual(after.filter{$0 == "member-refresh"}.count,count)
        XCTAssertEqual(f.host.dockView.refreshSweepCountForChecks,start+2)
    }
    func testG1_DOCK_3_8_11() async throws {
        let f = try await fixture(); try await f.event(); let card = try f.card()
        XCTAssertTrue(card.rows.contains { $0.id.hasPrefix("reset-event:") })
        XCTAssertEqual(card.links.map(\.label), ["Source", "AIHot", "Original source"])
        XCTAssertTrue(card.rows.first { $0.id.hasPrefix("reset-event:") }?.detail.contains("Scheduled ") == true)
        XCTAssertEqual(card.links.first?.url.absoluteString, "https://example.test/reset")
        XCTAssertTrue(try f.card(G1DFixture.ids[2]).links.isEmpty, "An event must not borrow another provider's links")
        try f.hover(); f.tick(0.25)
        func buttons(_ view: NSView) -> [NSButton] { (view as? NSButton).map { [$0] } ?? view.subviews.flatMap(buttons) }
        XCTAssertTrue(buttons(f.host.card).contains { $0.title == "Original source" })
        _ = try await f.editor.commit(SettingsB21Edit.language(.chinese))
        XCTAssertEqual(try f.card().links.map(\.label), ["来源", "AIHot", "原始来源"])
        var projection = f.raw["projection"] as! [String: Any]
        var events = projection["resetEvents"] as! [[String: Any]]
        events[0]["source"] = ["kind":"publication", "publicationId":"0123456789abcdef01234567", "url":"file:///synthetic", "links":[["type":"original", "url":"http://example.test/unsafe"],["type":"original", "url":"https://synthetic:synthetic@example.test/private"],["type":"unknown", "url":"https://example.test/unapproved"]]]
        projection["resetEvents"] = events; f.raw["projection"] = projection
        try await f.publish()
        XCTAssertTrue(try f.card().links.isEmpty, "Only bounded admitted HTTPS source links may reach the card")
        events[0]["source"] = ["kind":"publication", "publicationId":"0123456789abcdef01234567", "url":"https://example.test/reset", "links":(0..<12).map { ["type":"original", "url":"https://example.test/source-\($0)"] }]
        projection["resetEvents"] = events; f.raw["projection"] = projection
        try await f.publish()
        let bounded = try f.card().links
        XCTAssertEqual(bounded.count, 8); XCTAssertEqual(Set(bounded.map(\.url)).count, 8)
    }
    func testG1_DOCK_3_8_12() async throws {
        let f = try await fixture();f.mutateFirst{a in var windows=a["windows"] as! [[String:Any]];var extra=windows[0];extra["id"]="scoped";extra["modelScope"]=["models":["synthetic"]];extra["remainingPercent"]=1;windows.append(extra);a["windows"]=windows};try await f.publish()
        XCTAssertEqual(f.host.dockView.presentedReadingsForChecks[G1DFixture.ids[0]]?.remainingPercent,41)
        XCTAssertTrue(try f.card().rows.contains{$0.id == "quota:scoped" && $0.kind == .extraQuota && $0.value == "1%"})
    }
    func testG1_DOCK_3_8_13() async throws {
        let f = try await fixture();f.mutateFirst{a in a.removeValue(forKey:"credits");a["observedAt"]=NSNull();var windows=a["windows"] as! [[String:Any]];for i in windows.indices{windows[i].removeValue(forKey:"remainingPercent")};a["windows"]=windows};try await f.publish()
        let card=try f.card();XCTAssertTrue(card.rows.filter{$0.kind == .quota}.allSatisfy{$0.value == "--"});XCTAssertFalse(card.rows.contains{$0.kind == .reserve})
        XCTAssertTrue(card.sourceAndAge.contains("unknown"))
    }
}
