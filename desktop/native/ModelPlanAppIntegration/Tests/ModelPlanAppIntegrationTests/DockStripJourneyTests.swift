// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
@_spi(DockResourceChecks) import ModelPlanDock
@testable import ModelPlanAppIntegration

@MainActor private final class DockStripClock {
    var wall = Date(timeIntervalSince1970: 1_800_000_000)
    var elapsed = 10.0
}
@MainActor private final class DockStripTimer: DockEdgeScheduling {
    var deadline: Double?, action: (@MainActor () -> Void)?
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) { self.deadline = deadline; self.action = action }
    func cancel() { deadline = nil; action = nil }
    func fireIfDue(_ now: Double) { if let deadline, now >= deadline { let saved = action; cancel(); saved?() } }
}
private actor DockStripEngine: EngineClient {
    let store: EngineStore
    let context = EngineDeliveryContext(sessionID: "dock-strip", floor: .init(storeEpoch: "dock-strip", generation: 1), revision: 1)
    var rows: WireRowsSnapshot
    var requests: [String] = []
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    nonisolated func isCurrent(_ value: EngineDeliveryContext) -> Bool { value.sessionID == "dock-strip" && value.revision == 1 }
    func supportsCapability(_ value: String) async -> Bool { value == "memberRefreshV1" }
    func start() async throws -> EngineDeliveryContext { requests.append("start"); await store.consume(.connection(.ready(context))); await store.consume(.context(context)); return context }
    func stop() async { requests.append("stop") }
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func deliver(_ value: WireRowsSnapshot) async throws { rows = value; await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: value), delivery: context), invalidRowCount: 0)) }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { requests.append("rows"); try await deliver(rows); return .init(requestID: .string("rows")) }
    func consent(timeout: Duration?) throws -> EngineRequestCompletion { requests.append("consent"); throw EngineClientError.unsupportedCapability }
    func grant(_ value: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ value: WireRefreshRequestParams, timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ value: WireHistoryQueryParams, timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ value: WirePluginInstallParams, timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}
@MainActor private final class DockStripFixture {
    static let ids = ["aaaaaaaaaaaaaaaa", "bbbbbbbbbbbbbbbb", "cccccccccccccccc"]
    let clock = DockStripClock(), timer = DockStripTimer()
    let root: URL, store: SettingsStore
    var app: EngineDockMenuApplication!
    var engine: DockStripEngine!
    var raw: [String: Any]
    var pointer = CGPoint(x: 700, y: 400), cardFrame: CGRect?, presence = DockPresence()
    var displays = [DockDisplayArea(id: "primary", frame: .init(x: 0,y: 0,width: 1440,height: 900), visibleFrame: .init(x: 0,y: 80,width: 1440,height: 820))]
    var host: StaticDockPreviewHost { app.composition.dock }
    static func stamp(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }
    init(profile: URL? = nil, wall: Date? = nil) throws {
        root = profile ?? FileManager.default.temporaryDirectory.appendingPathComponent("dock-strip-" + UUID().uuidString)
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
                    w["remainingPercent"] = number == 0 ? [51,50,25][index] : [70,60,50][index]
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
    func open(autoHide: Bool = false, cockpitEnabled: Bool = false, notifications: Bool = false) async throws {
        _ = try await store.update { p in p.autoHide = autoHide; p.showDock = true; p.language = .english; p.motion = .on; if notifications { p.notifications.optedIn = true }; for _ in 0..<16 { p.onboarding.next() } }
        let rows = try decode()
        app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true), settingsStore: store, createsNativePanels: false, cockpitEntryEnabled: cockpitEnabled,
            dockEnvironment: { [weak self] in guard let self else { return .init(displays: [], layouts: []) }; return .init(displays: self.displays, layouts: [], primaryDisplayID: "primary", pointer: self.pointer, presence: self.presence, cardFrame: self.cardFrame) },
            deadlineNow: { [clock] in clock.wall }, deadlineElapsed: { [clock] in clock.elapsed }, deadlineScheduling: timer,
            makeClient: { [weak self] _, store in let engine = DockStripEngine(store: store, rows: rows); self?.engine = engine; return engine }, activateSettings: {})
        await app.prepare(); app.allowDockPresentation(); await app.composition.start(); tick(0.5)
    }
    func decode() throws -> WireRowsSnapshot { try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: raw)) }
    func publish() async throws { raw["sequence"] = ((raw["sequence"] as? Int) ?? 1) + 1; try await engine.deliver(decode()) }
    func mutateFirstRowAccount(at index: Int, _ edit: (inout [String: Any]) -> Void) {
        var p = raw["projection"] as! [String: Any], rows = p["rows"] as! [[String: Any]], accounts = rows[0]["accounts"] as! [[String: Any]]
        edit(&accounts[index]); rows[0]["accounts"] = accounts; p["rows"] = rows; raw["projection"] = p
    }
    func tick(_ seconds: Double) { clock.elapsed += seconds; clock.wall.addTimeInterval(seconds); timer.fireIfDue(clock.elapsed); host.refreshPresence(); host.interactionControllerForChecks?.refresh() }
    func close() async { if let app { await app.composition.stop() }; try? FileManager.default.removeItem(at: root) }
}

@MainActor final class DockStripJourneyTests: XCTestCase {
    func testNormalEntryPaintsOnlyAffectedQuotaPitches() async throws {
        let fixture = try DockStripFixture()
        addTeardownBlock { @MainActor in await fixture.close() }
        let frame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        fixture.displays = [.init(id: "primary", frame: frame, visibleFrame: frame)]
        _ = try await fixture.store.update { $0.dockEdge = .bottom; $0.redBelow = 17 }
        try await fixture.open(autoHide: true)
        XCTAssertEqual(fixture.app.composition.latestSettings?.effective.redBelow, 25)
        let stored = await fixture.store.snapshot()
        XCTAssertEqual(stored.preferences.redBelow, 17)
        XCTAssertEqual(fixture.host.edgePresentation?.state, .sliver)
        let placement = try XCTUnwrap(fixture.host.edgePresentation?.placement)
        XCTAssertEqual(placement.edge, .bottom)
        let size = placement.sliverFrame.size
        let view = try fixture.host.prepareSliver(size: size)
        XCTAssertGreaterThan(view.bounds.width, view.bounds.height)
        func capture() throws -> NSBitmapImageRep {
            let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            return bitmap
        }
        func color(in bitmap: NSBitmapImageRep, at fraction: Double) throws -> NSColor {
            let x = min(bitmap.pixelsWide - 1, Int(fraction * Double(bitmap.pixelsWide)))
            return try XCTUnwrap(bitmap.colorAt(x: x, y: bitmap.pixelsHigh / 2)?.usingColorSpace(.sRGB))
        }
        let withAlerts = try capture()
        let segments = view.quotaSegmentColorRolesForChecks
        XCTAssertTrue(SettingsPreferences().sliverAlert)
        XCTAssertEqual(view.quotaSegmentColorRolesForChecks.map(\.remainingPercent), [51, 50, 25])
        XCTAssertEqual(view.quotaSegmentColorRolesForChecks.map(\.quotaRole), [nil, .warning, .critical])
        XCTAssertEqual(view.quotaSegmentColorRolesForChecks.map(\.opacity), [0, 0.18, 0.18])
        XCTAssertEqual(segments.map(\.subscriptionID), DockStripFixture.ids.map(Optional.some))
        XCTAssertTrue(view.layer?.animationKeys()?.isEmpty ?? true)
        XCTAssertTrue(view.accessibilityPerformPress())
        XCTAssertEqual(fixture.host.edgePresentation?.state, .expanded)
        _ = try fixture.host.prepareSliver(size: size)
        let deadline = ContinuousClock.now + .seconds(2)
        while fixture.host.edgePresentation?.state != .sliver, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(fixture.host.edgePresentation?.state, .sliver)
        XCTAssertEqual(try capture().tiffRepresentation, withAlerts.tiffRepresentation, "Reveal leaves persistent quota alerts painted")
        fixture.mutateFirstRowAccount(at: 1) { account in
            var windows = account["windows"] as! [[String: Any]]
            windows[0]["remainingPercent"] = 51
            account["windows"] = windows
        }
        try await fixture.publish()
        _ = try fixture.host.prepareSliver(size: size)
        XCTAssertEqual(view.quotaSegmentColorRolesForChecks.map(\.remainingPercent), [51, 51, 25])
        XCTAssertEqual(view.quotaSegmentColorRolesForChecks.map(\.quotaRole), [nil, nil, .critical])
        _ = try await fixture.app.settingsHost.application.editor.commit(SettingsB20Edit.sliverAlert(false))
        _ = try fixture.host.prepareSliver(size: size)
        XCTAssertTrue(view.quotaSegmentColorRolesForChecks.isEmpty)
        let neutral = try capture()
        XCTAssertNotEqual(neutral.tiffRepresentation, withAlerts.tiffRepresentation)
        XCTAssertEqual(segments.count, 3)
        guard segments.count == 3 else { return }
        for (index, segment) in segments.enumerated() {
            let fraction = (segment.from + segment.through) / 2
            let base = try color(in: neutral, at: fraction)
            let painted = try color(in: withAlerts, at: fraction)
            let channels = [base.redComponent, base.greenComponent, base.blueComponent]
            XCTAssertLessThan(try XCTUnwrap(channels.max()) - XCTUnwrap(channels.min()), 0.08)
            switch index {
            case 0: XCTAssertEqual(painted, base, "The healthy pitch keeps the neutral body")
            case 1:
                XCTAssertGreaterThan(painted.redComponent, base.redComponent + 0.05)
                XCTAssertGreaterThan(painted.greenComponent, base.greenComponent + 0.05)
            default:
                XCTAssertGreaterThan(painted.redComponent, base.redComponent + 0.05)
                XCTAssertGreaterThan(painted.redComponent, painted.greenComponent + 0.10)
            }
        }
    }

    func testOfficialResetAnnouncementCannotRefillThePersonalRing() async throws {
        let fixture = try DockStripFixture()
        addTeardownBlock { @MainActor in await fixture.close() }
        try await fixture.open()
        let member = DockStripFixture.ids[0]
        func reading() throws -> DockInstrumentReading {
            try XCTUnwrap(fixture.host.dockView.presentedReadingsForChecks[member])
        }

        let before = try reading()
        XCTAssertEqual(before.outer?.fraction, 0.41)
        XCTAssertEqual(before.readout, "41%")
        XCTAssertNil(fixture.host.dockView.presentedNoticesForChecks[member])

        let start = DockStripFixture.stamp(fixture.clock.wall.addingTimeInterval(-1))
        let end = DockStripFixture.stamp(fixture.clock.wall.addingTimeInterval(3600))
        var projection = try XCTUnwrap(fixture.raw["projection"] as? [String: Any])
        projection["resetEvents"] = [[
            "version": 1, "id": "synthetic-public-reset", "provider": "openai", "rowId": "codex",
            "status": "announced", "planIds": ["pro"], "publishedAt": start, "expiresAt": end,
            "schedule": ["precision": "window", "from": start, "through": end],
            "source": ["kind": "publication", "publicationId": "synthetic"]
        ]]
        fixture.raw["projection"] = projection
        try await fixture.publish()
        let announcement = try reading()
        XCTAssertEqual(fixture.host.dockView.presentedNoticesForChecks[member]?.key.kind, .resetAnnounced)
        XCTAssertEqual(announcement.outer?.fraction, before.outer?.fraction)
        XCTAssertEqual(announcement.readout, before.readout)

        fixture.tick(2)
        fixture.mutateFirstRowAccount(at: 0) { account in
            var windows = account["windows"] as! [[String: Any]]
            windows[0]["remainingPercent"] = 82
            windows[0]["observedAt"] = DockStripFixture.stamp(fixture.clock.wall)
            account["windows"] = windows
        }
        try await fixture.publish()
        let updated = try reading()
        XCTAssertEqual(updated.outer?.fraction, 0.82)
        XCTAssertEqual(updated.readout, "70%", "the still-tighter weekly window remains the selected readout")
        XCTAssertEqual(fixture.host.dockView.presentedNoticesForChecks[member]?.key.kind, .resetAnnounced)
    }

    func testRevealAcknowledgesOneShotDotsWithoutClearingQuotaSegmentsOrFaceNotice() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var signal = DockSubscriptionSignal(id: "member")
        signal.dataState = .fresh; signal.alert = .warning
        signal.reset = DockResetSignal(id: "event", status: .announced, scheduledThrough: now.addingTimeInterval(60))
        var state = DockAttentionState()
        let stations = [signal.id: "station"]
        let before = try state.project([signal], stationBySubscription: stations, at: now)
        XCTAssertEqual(before.dots.count, 1)
        XCTAssertNotNil(before.menuNotice)
        try state.acknowledge(.dockRevealed, signals: [signal], at: now)
        let revealed = try state.project([signal], stationBySubscription: stations, at: now)
        XCTAssertTrue(revealed.dots.isEmpty)
        XCTAssertNil(revealed.menuNotice, "MENU-06 clears the menu-bar dot when the widget opens")
        XCTAssertNotNil(DockNoticeProjection.selected(for: signal, at: now))
        XCTAssertEqual(revealed.segments, before.segments)
        var unacknowledged = DockAttentionState()
        let expired = try unacknowledged.project([signal], stationBySubscription: stations, at: now.addingTimeInterval(60))
        XCTAssertTrue(expired.dots.isEmpty)
        XCTAssertNil(expired.menuNotice)
        var cockpit = DockAttentionState()
        try cockpit.acknowledge(.cockpitOpening, signals: [signal], at: now)
        let cockpitOpened = try cockpit.project([signal], stationBySubscription: stations, at: now)
        XCTAssertNil(cockpitOpened.menuNotice)
        XCTAssertEqual(cockpitOpened.dots, before.dots)
        XCTAssertEqual(cockpitOpened.segments, before.segments)
    }
}
