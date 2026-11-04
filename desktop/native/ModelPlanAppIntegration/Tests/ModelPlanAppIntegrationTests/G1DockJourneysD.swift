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
    init(profile: URL? = nil) throws {
        root = profile ?? FileManager.default.temporaryDirectory.appendingPathComponent("g1-d-" + UUID().uuidString)
        store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../..").standardizedFileURL
        raw = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: repo.appendingPathComponent("schema/app-cli/captures/WireRowsSnapshot.json"))) as? [String: Any])
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
    func open(autoHide: Bool = false, cockpitEnabled: Bool = false) async throws {
        _ = try await store.update { p in p.autoHide = autoHide; p.showDock = true; p.language = .english; p.motion = .on; for _ in 0..<16 { p.onboarding.next() } }
        let rows = try decode()
        app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true), settingsStore: store, createsNativePanels: false, cockpitEntryEnabled: cockpitEnabled,
            dockEnvironment: { [weak self] in guard let self else { return .init(displays: [], layouts: []) }; return .init(displays: self.displays, layouts: [], primaryDisplayID: "primary", pointer: self.pointer, presence: self.presence, cardFrame: self.cardFrame) },
            deadlineNow: { [clock] in clock.wall }, deadlineElapsed: { [clock] in clock.elapsed }, deadlineScheduling: timer,
            makeClient: { [weak self] _, store in let engine = G1DEngine(store: store, rows: rows); self?.engine = engine; return engine }, activateSettings: {})
        app.composition.setResetNotificationDelivery { [weak self] in self?.notificationRequests.append($0) }
        await app.prepare(); app.allowDockPresentation(); await app.composition.start(); tick(0.5)
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
    func hover(_ id: String = ids[0]) throws {
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
    func card(_ id: String = ids[0]) throws -> DockCardContent { try XCTUnwrap(host.cardContent(for: id, at: clock.wall)) }
    func close() async { if let app { await app.composition.stop() }; try? FileManager.default.removeItem(at: root) }
}

@MainActor final class G1DockJourneysD: XCTestCase {
    private func fixture(autoHide: Bool = false, cockpitEnabled: Bool = false) async throws -> G1DFixture { let f = try G1DFixture(); addTeardownBlock { @MainActor in await f.close() }; try await f.open(autoHide: autoHide, cockpitEnabled: cockpitEnabled); return f }
    private func complete(_ condition: @escaping @MainActor () async -> Bool) async throws { let deadline = ContinuousClock.now + .seconds(15); while !(await condition()) { guard ContinuousClock.now < deadline else { XCTFail("Async delivery did not complete"); return }; await Task.yield() } }
    private func seam(_ id: String, _ reason: String) async throws { let f = try await fixture(); XCTAssertNotNil(f.host.edgePresentation); throw XCTSkip("\(id): SEAM-NEEDED \(reason)") }
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
        f.host.acknowledgeDockReveal(); _ = try f.host.prepareSliver(size:.init(width:4,height:180)); XCTAssertTrue(f.host.sliverNoticeMarksForChecks.isEmpty)
        XCTExpectFailure("DOCK-3.6-08: quota segment projection is not connected to the current Sliver") { XCTAssertTrue(f.host.sliverQuotaColorsForChecks.contains{$0.remainingPercent != nil}) }
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
        XCTExpectFailure("DOCK-3.6-11: no quota-derived segments reach the Sliver view") { XCTAssertTrue(f.host.sliverQuotaColorsForChecks.contains{$0.remainingPercent == 0}) }
    }
    func testG1_DOCK_3_6_12() async throws {
        let f = try await fixture(); let c = try XCTUnwrap(f.host.interactionControllerForChecks), env=f.host.interactionEnvironment()
        let target=try XCTUnwrap(env.targets.first); XCTAssertTrue(c.beginNozzle(id:target.id,along:target.along))
        c.moveNozzle(along:target.along+5); XCTAssertNil(c.presentation?.reorder)
        c.moveNozzle(along:try XCTUnwrap(env.targets.last).along+6); XCTAssertNotNil(c.presentation?.reorder)
        c.endNozzle(insideMain:true,overSameSource:false)
        try await complete { !f.editor.isSaving && f.editor.snapshot?.preferences.subscriptions.order.first != target.id }
        XCTAssertEqual(f.editor.snapshot?.preferences.subscriptions.order.last,target.id)
    }
    func testG1_DOCK_3_6_13() async throws {
        let f = try await fixture(); let first=G1DFixture.ids[0]
        XCTAssertTrue(try XCTUnwrap(f.host.dockView.nozzleEventDelegate).optionArrow(id:first,keyCode:125))
        try await complete { !f.editor.isSaving && f.editor.snapshot?.preferences.subscriptions.order.first == G1DFixture.ids[1] }
        XCTExpectFailure("DOCK-3.6-13: normal host does not install the controller's accessibility announcement consumer") { XCTAssertTrue(f.host.orderAnnouncementInstalledForChecks) }
    }
    func testG1_DOCK_3_6_14() async throws {
        let f = try await fixture(); let handler=try XCTUnwrap(f.host.dockView.backgroundDragDelegate), p=try XCTUnwrap(f.host.edgePresentation?.placement)
        let bounds=f.host.dockView.bounds
        let points=(0..<Int(bounds.height)).flatMap{y in (0..<Int(bounds.width)).map{x in CGPoint(x:Double(x)+0.5,y:Double(y)+0.5)}}
        let local=try XCTUnwrap(points.first{handler.backgroundCanDrag(local:$0)})
        XCTAssertTrue(handler.beginBackgroundMove(local:local,global:.init(x:p.frame.minX+local.x,y:p.frame.maxY-local.y)))
        handler.updateBackgroundMove(global:.init(x:1,y:400)); XCTAssertNotNil(f.host.edgePresentation?.snapPreview)
        handler.endBackgroundMove(global:.init(x:1,y:400))
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
    func testG1_DOCK_3_7_04() async throws { try await seam("DOCK-3.7-04","restart-persistent notification dispatch needs the controlled OS-delivery observation fixture, not a substituted notifier") }
    func testG1_DOCK_3_7_05() async throws {
        for duration in [3600.0,48*3600,24*3600] as [Double] {
            let f = try await fixture(); try await f.event(status:duration == 24*3600 ? "confirmed":"announced",lifetime:duration)
            f.tick(duration-0.001); XCTAssertNotNil(f.app.composition.resetSignals.first?.reset)
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
    func testG1_DOCK_3_8_01() async throws { try await seam("DOCK-3.8-01","resolved per-nozzle magnification/lift metadata is absent; stored choice alone is not motion proof") }
    func testG1_DOCK_3_8_02() async throws { try await seam("DOCK-3.8-02","independent nozzle/readout transform roles are not observable") }
    func testG1_DOCK_3_8_03() async throws {
        let f = try await fixture(); try f.hover(); f.tick(0.249); XCTAssertTrue(f.host.card.isHidden)
        f.tick(0.002); XCTAssertFalse(f.host.card.isHidden)
        f.pointer = .init(x:500,y:400); try XCTUnwrap(f.host.dockView.nozzleEventDelegate).hoverNozzle(nil)
        f.tick(0); f.tick(0.249); XCTAssertFalse(f.host.card.isHidden);f.tick(0.002);XCTAssertTrue(f.host.card.isHidden)
    }
    func testG1_DOCK_3_8_04() async throws { try await seam("DOCK-3.8-04","metal plate/LCD appearance roles are not exposed; generic NSView geometry does not prove visual identity") }
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
        facts["earliestExpiresAt"]=G1DFixture.stamp(f.clock.wall.addingTimeInterval(86400));facts["items"]=[["id":String(repeating:"d",count:64),"expiresAt":G1DFixture.stamp(f.clock.wall.addingTimeInterval(86400))]]
        f.mutateFirst{$0["resetCards"]=facts};try await f.publish();let card=try f.card()
        XCTAssertTrue(card.rows.contains{$0.kind == .reserve && $0.value == "1,500"})
        XCTExpectFailure("DOCK-3.8-08: reported reset-card count and expiry are not projected") { XCTAssertTrue(card.rows.contains{$0.id.contains("reset-card") && !$0.detail.isEmpty}) }
    }
    func testG1_DOCK_3_8_09() async throws {
        let f = try await fixture();let card=try f.card()
        XCTExpectFailure("DOCK-3.8-09: no reported today/rate/session rows are projected to the current card") { XCTAssertGreaterThanOrEqual(card.rows.filter{$0.kind == .statistic}.count,3) }
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
        let f = try await fixture();try await f.event();let card=try f.card()
        XCTAssertTrue(card.rows.contains{$0.id.hasPrefix("reset-event:")})
        XCTExpectFailure("DOCK-3.8-11: the current card does not expose approved event source links") { XCTAssertFalse(card.links.isEmpty) }
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
