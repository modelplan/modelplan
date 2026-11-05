// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
import ModelPlanDock
@testable import ModelPlanAppIntegration

/// Production entry and production Dock, with no engine child, native panel or input.
@MainActor final class G1DockPlacementJourneys: XCTestCase {
    func testG1_DOCK_3_6_01_normalEntrySliverTracksHullAndSize() async throws {
        _ = NSApplication.shared
        for (size, expectedThickness) in [(SettingsSize.small, 4.0 * 36 / 44), (.medium, 4.0), (.large, 4.0 * 52 / 44)] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("g1-placement-" + UUID().uuidString, isDirectory: true)
            defer { try? FileManager.default.removeItem(at: root) }
            let settings = try SettingsStore(url: root.appendingPathComponent("settings.json"))
            _ = try await settings.update { $0.showDock = true; $0.autoHide = true; $0.size = size; $0.dockEdge = .right }
            let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"), applicationVersion: "g1-synthetic", allowedEnvironment: [:], offline: true, readOnly: true), settingsStore: settings, createsNativePanels: false)
            await app.prepare(); app.allowDockPresentation()
            defer { app.composition.dock.close() }
            let dock = app.composition.dock
            XCTAssertNil(dock.nativePanel)
            XCTAssertNil(dock.lastAppearanceError)
            let placement = try XCTUnwrap(dock.edgePresentation?.placement, "the normal entry must publish a real placement")
            let thickness = placement.edge == .bottom ? placement.sliverFrame.height : placement.sliverFrame.width
            let length = placement.edge == .bottom ? placement.sliverFrame.width : placement.sliverFrame.height
            let anchor = placement.edge == .bottom ? placement.frame.minX + placement.layout.alongAnchor : placement.frame.minY + placement.layout.alongAnchor
            let sliverCentre = placement.edge == .bottom ? placement.sliverFrame.midX : placement.sliverFrame.midY
            XCTAssertEqual(Double(thickness), expectedThickness, accuracy: 0.05, "S/M/L painted thickness")
            let hull = try XCTUnwrap(dock.dockView.registeredHullBounds)
            let hullSpan = placement.edge == .bottom ? hull.width : hull.height
            XCTAssertEqual(length, hullSpan, accuracy: 0.05, "the painted sliver spans the actual registered Dock hull")
            XCTAssertEqual(sliverCentre, anchor, accuracy: 0.05, "the sliver stays registered at the Dock position")
            let sliver = try dock.prepareSliver(size: placement.sliverFrame.size)
            XCTAssertEqual(sliver.frame.size, placement.sliverFrame.size)
            let width = max(1, Int(ceil(sliver.bounds.width * 2))), height = max(1, Int(ceil(sliver.bounds.height * 2)))
            let image = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                bytesPerRow: 0, bitsPerPixel: 0))
            let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: image))
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = context
            context.cgContext.scaleBy(x: 2, y: 2)
            sliver.draw(sliver.bounds)
            NSGraphicsContext.restoreGraphicsState()
            let metal = try XCTUnwrap(image.colorAt(x: width / 2, y: height / 2)?.usingColorSpace(.deviceRGB))
            XCTAssertGreaterThan(metal.alphaComponent, 0.5)
            XCTAssertLessThan(abs(metal.redComponent - metal.greenComponent), 0.08, "the body is neutral, not a quota alert")
            XCTAssertLessThan(abs(metal.greenComponent - metal.blueComponent), 0.08, "the body remains neutral metal")
        }
    }
}

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
    let context = EngineDeliveryContext(sessionID: "s-00000000-0000-4000-8000-000000000001", floor: .init(storeEpoch: "g1-d", generation: 1), revision: 1)
    var rows: WireRowsSnapshot
    var requests: [String] = []
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    nonisolated func isCurrent(_ value: EngineDeliveryContext) -> Bool { value.sessionID == "s-00000000-0000-4000-8000-000000000001" && value.revision == 1 }
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
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion {
        requests.append("cockpit")
        let captures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures").standardizedFileURL
        let data = try WireDecoder.decode(WireCockpitData.self, from: Data(contentsOf: captures.appendingPathComponent("WireCockpitData.json")))
        let id = WireRequestID.string("g1-cockpit")
        await store.consume(.response(requestID: id, .cockpit(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: data), delivery: context))))
        return .init(requestID: id)
    }
    func publication(timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ value: WirePluginInstallParams, timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}
@MainActor private final class G1DFixture {
    static let ids = ["aaaaaaaaaaaaaaaa", "bbbbbbbbbbbbbbbb", "cccccccccccccccc"]
    let clock = G1DClock(), timer = G1DTimer(), placementTimer = G1DTimer()
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
    func open(autoHide: Bool = false, cockpitEnabled: Bool = false, notifications: Bool = false) async throws {
        _ = try await store.update { p in p.autoHide = autoHide; p.showDock = true; p.language = .english; p.motion = .system; if notifications { p.notifications.optedIn = true }; for _ in 0..<16 { p.onboarding.next() } }
        let rows = try decode()
        app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true), settingsStore: store, createsNativePanels: false, cockpitEntryEnabled: cockpitEnabled,
            dockEnvironment: { [weak self] in guard let self else { return .init(displays: [], layouts: []) }; return .init(displays: self.displays, layouts: [], primaryDisplayID: "primary", pointer: self.pointer, presence: self.presence, cardFrame: self.cardFrame) },
            deadlineNow: { [clock] in clock.wall }, deadlineElapsed: { [clock] in clock.elapsed }, deadlineScheduling: timer, placementScheduling: placementTimer,
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
    func advanceClock(by seconds: Double) { clock.elapsed += seconds; clock.wall.addTimeInterval(seconds); timer.fireIfDue(clock.elapsed); placementTimer.fireIfDue(clock.elapsed); host.refreshPresence(); host.interactionControllerForChecks?.refresh() }
    func movePointer(to point: CGPoint) { pointer = point; host.refreshPresence() }
    func tick(_ seconds: Double) { advanceClock(by: seconds) }
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

@MainActor extension G1DockPlacementJourneys {
    private func placementFixture(autoHide: Bool = false, cockpit: Bool = false) async throws -> G1DFixture {
        let value = try G1DFixture()
        addTeardownBlock { @MainActor in await value.close() }
        try await value.open(autoHide: autoHide, cockpitEnabled: cockpit)
        return value
    }
    private func placementEventually(_ condition: @escaping @MainActor () async -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(10)
        while !(await condition()) {
            guard ContinuousClock.now < deadline else { XCTFail("Timed out waiting for production placement state"); return }
            await Task.yield()
        }
    }
    /// Each rectangle is read from the installed production host in global coordinates.
    private func checkInside(_ point: CGPoint, _ fixture: G1DFixture, _ expected: Bool, _ label: String) {
        fixture.pointer = point; fixture.tick(0)
        XCTAssertEqual(fixture.host.interactionEnvironment().insideShared, expected, label)
    }

    func testG1PlacementPointerObservationUsesInstalledController() async throws {
        let f = try await placementFixture()
        let target = CGPoint(x: 321, y: 432)
        f.movePointer(to: target)
        XCTAssertEqual(f.host.placementObservationForChecks?.pointer, target)
        XCTAssertNil(f.host.nativePanel)
    }
    func testG1PlacementClockObservationUsesIndependentScheduler() async throws {
        let f = try await placementFixture(autoHide: true)
        let before = try XCTUnwrap(f.host.placementObservationForChecks?.elapsed)
        f.timer.arm(at: before + 50) {}
        f.host.refreshPresence()
        XCTAssertEqual(f.timer.deadline, before + 50, "placement sampling must not cancel a data deadline")
        XCTAssertNotNil(f.placementTimer.deadline, "the installed placement controller arms its own scheduler")
        f.advanceClock(by: 0.25)
        XCTAssertEqual(try XCTUnwrap(f.host.placementObservationForChecks?.elapsed), before + 0.25, accuracy: 0.0001)
        XCTAssertEqual(f.host.samplingIntervalForChecks, 0.15, accuracy: 0.0001)
    }
    func testG1PlacementDisplayObservationTracksActualSample() async throws {
        let f = try await placementFixture()
        let extra = DockDisplayArea(id: "synthetic-second", frame: .init(x: -800, y: 0, width: 800, height: 900), visibleFrame: .init(x: -800, y: 0, width: 800, height: 900))
        f.displays.append(extra); f.advanceClock(by: 0)
        let observation = try XCTUnwrap(f.host.placementObservationForChecks)
        XCTAssertEqual(observation.displays, f.displays.sorted { $0.id < $1.id })
        XCTAssertEqual(observation.primaryDisplayID, "primary")
        let frames = try XCTUnwrap(f.host.placementFramesForChecks), placement = try XCTUnwrap(f.host.edgePresentation?.placement)
        XCTAssertEqual(frames.dock, placement.frame); XCTAssertEqual(frames.sliver, placement.sliverFrame); XCTAssertEqual(frames.wake, placement.wakeFrame)
    }

    func testG1_DOCK_3_6_03_insideSlackForEachPaintedSurface() async throws {
        #if G1_PLACEMENT_SEAMS
        let f = try await placementFixture()
        // The observation returns real registered global bounds, not policy-generated sample points.
        let regions = f.host.placementInsideRegionsForChecks
        for name in ["hull", "nozzle", "label", "ignition", "cap"] {
            let rect = try XCTUnwrap(regions[name], "missing actual \(name) region")
            checkInside(.init(x: rect.midX, y: rect.midY), f, true, "\(name) itself")
        }
        let hull = try XCTUnwrap(regions["hull"])
        checkInside(.init(x: hull.minX - 11.9, y: hull.midY), f, true, "11.9 px slack")
        checkInside(.init(x: hull.minX - 12.1, y: hull.midY), f, false, "outside 12 px slack")
        try f.hover(); f.tick(0.25)
        let card = try XCTUnwrap(f.host.placementInsideRegionsForChecks["card"])
        checkInside(.init(x: card.midX, y: card.midY), f, true, "card itself")
        // Force real overflow via the production member catalogue, then open its real tray.
        var projection = f.raw["projection"] as! [String: Any], rows = projection["rows"] as! [[String: Any]]
        var accounts = rows[0]["accounts"] as! [[String: Any]]
        let prototype = accounts[0]
        for index in 1...24 { var account = prototype; account["subscriptionRef"] = String(format: "%016x", index); accounts.append(account) }
        rows[0]["accounts"] = accounts; projection["rows"] = rows; f.raw["projection"] = projection
        try await f.publish(); f.host.dockView.onAction?(.overflow); f.tick(0)
        let overflow = try XCTUnwrap(f.host.placementInsideRegionsForChecks["overflow"])
        checkInside(.init(x: overflow.midX, y: overflow.midY), f, true, "overflow tray itself")
        #else
        throw XCTSkip("DOCK-3.6-03 seam-needed: EngineRowsEntry.swift:dockEnvironment; StaticDockPreviewHost.swift:placementInsideRegionsForChecks")
        #endif
    }
    func testG1_DOCK_3_6_04_cardCorridorAndHide() async throws {
        let f = try await placementFixture(autoHide: true); try f.revealFromWake(); f.tick(0.301)
        try f.hover(); f.tick(0.25); XCTAssertFalse(f.host.card.isHidden)
        let place = try XCTUnwrap(f.host.edgePresentation?.placement)
        let rect = CGRect(x: place.frame.minX - 312, y: place.frame.midY - 90, width: 300, height: 180)
        f.cardFrame = rect
        for x in [rect.midX, (rect.maxX + place.frame.minX) / 2, place.frame.minX - 1] {
            checkInside(.init(x: x, y: rect.midY), f, true, "full-depth card corridor")
        }
        f.pointer = .init(x: 600, y: 400); f.tick(0); f.tick(0.501)
        XCTAssertEqual(f.host.edgePresentation?.state, .sliver)
        XCTAssertTrue(f.host.card.isHidden, "the actual hide decision closes the card")
    }
    func testG1_DOCK_3_6_05_dwellSettingsSamplingAndSharedSeam() async throws {
        for milliseconds in [100, 150, 300] {
            let f = try await placementFixture(autoHide: true)
            _ = try await f.editor.commit(SettingsB21Edit.reveal(milliseconds))
            let p = try XCTUnwrap(f.host.edgePresentation?.placement)
            f.movePointer(to: .init(x: p.wakeFrame.midX, y: p.wakeFrame.midY))
            f.advanceClock(by: Double(milliseconds) / 1000 - 0.001)
            XCTAssertEqual(f.host.edgePresentation?.state, .sliver)
            f.advanceClock(by: 0.002); XCTAssertEqual(f.host.edgePresentation?.state, .expanded)
            XCTAssertEqual(f.host.samplingIntervalForChecks, 0.150, accuracy: 0.001)
        }
        let shared = try await placementFixture(autoHide: true)
        shared.displays.append(.init(id: "neighbour", frame: .init(x: 1440, y: 0, width: 1000, height: 900), visibleFrame: .init(x: 1440, y: 0, width: 1000, height: 900)))
        shared.movePointer(to: .init(x: 1440, y: 450)); shared.advanceClock(by: 0.301)
        XCTAssertNotEqual(shared.host.edgePresentation?.state, .expanded, "a shared display seam cannot reveal")
    }
    func testG1_DOCK_3_6_06_continuousAbsenceAndReentry() async throws {
        let f = try await placementFixture(autoHide: true); try f.revealFromWake(); f.tick(0.301)
        let placement = try XCTUnwrap(f.host.edgePresentation?.placement)
        f.pointer = .init(x: 600, y: 400); f.tick(0); f.tick(0.499)
        XCTAssertEqual(f.host.edgePresentation?.state, .expanded)
        f.pointer = .init(x: placement.frame.midX, y: placement.frame.midY); f.tick(0)
        f.pointer = .init(x: 600, y: 400); f.tick(0); f.tick(0.499)
        XCTAssertEqual(f.host.edgePresentation?.state, .expanded, "re-entry starts a new absolute deadline")
        f.tick(0.002); XCTAssertEqual(f.host.edgePresentation?.state, .sliver)
    }
    func testG1_DOCK_3_6_07_cockpitCloseRestoresWithoutFlash() async throws {
        #if G1_PLACEMENT_SEAMS
        let f = try await placementFixture(autoHide: true, cockpit: true)
        f.app.showConsole(); try await placementEventually { f.app.cockpitLifecycleForChecks == .open }
        let cockpit = try XCTUnwrap(f.app.cockpitCoordinatorForChecks)
        f.pointer = .init(x: 600, y: 400)
        cockpit.close(); try await placementEventually { f.app.cockpitLifecycleForChecks == .closed }
        XCTAssertEqual(f.host.edgePresentation?.state, .sliver)
        XCTAssertFalse(f.host.placementTransitionsForChecks.suffix(2).contains { $0 == .expanded }, "close must not flash an expanded Dock")
        let place = try XCTUnwrap(f.host.edgePresentation?.placement)
        f.pointer = .init(x: place.wakeFrame.midX, y: place.wakeFrame.midY); f.tick(0); f.tick(0.151)
        XCTAssertEqual(f.host.edgePresentation?.state, .expanded)
        #else
        throw XCTSkip("DOCK-3.6-07 seam-needed: EngineDockMenuApplication.swift:cockpitCoordinatorForChecks,cockpitLifecycleForChecks; StaticDockPreviewHost.swift:placementTransitionsForChecks; EngineRowsEntry.swift:dockEnvironment,deadlineElapsed,deadlineScheduling")
        #endif
    }
    func testG1_DOCK_3_6_08_acknowledgementDoesNotEraseQuotaSegments() async throws {
        #if G1_PLACEMENT_SEAMS
        let f = try await placementFixture(autoHide: true, cockpit: true); try await f.event()
        _ = try f.host.prepareSliver(size: .init(width: 4, height: 180))
        XCTAssertNotNil(f.app.noticeIndicator.notice); XCTAssertFalse(f.host.sliverNoticeMarksForChecks.isEmpty)
        f.host.acknowledgeCockpitOpening(); XCTAssertNil(f.app.noticeIndicator.notice)
        _ = try f.host.prepareSliver(size: .init(width: 4, height: 180)); XCTAssertFalse(f.host.sliverNoticeMarksForChecks.isEmpty)
        f.host.acknowledgeDockReveal()
        _ = try f.host.prepareSliver(size: .init(width: 4, height: 180)); XCTAssertTrue(f.host.sliverNoticeMarksForChecks.isEmpty)
        let options = XCTExpectedFailure.Options(); options.isStrict = true
        XCTExpectFailure("DOCK-3.6-08 product-missing on main: quota segments are not delivered to the sliver", options: options) {
            XCTAssertTrue(f.host.sliverQuotaColorsForChecks.contains { $0.remainingPercent == 0 })
        }
        #else
        throw XCTSkip("DOCK-3.6-08 seam-needed: EngineRowsEntry.swift:dockEnvironment; StaticDockPreviewHost.swift:sliverNoticeMarksForChecks,sliverQuotaColorsForChecks")
        #endif
    }
    func testG1_DOCK_3_6_09_arrivalGuard() async throws {
        let f = try await placementFixture(autoHide: true); try f.revealFromWake()
        let action = DockInstrumentAction.subscription(G1DFixture.ids[0])
        f.tick(0.299); XCTAssertEqual(f.host.dockView.permitsAction?(action, .pointer), false)
        f.tick(0.002); XCTAssertEqual(f.host.dockView.permitsAction?(action, .pointer), true)
    }
    func testG1_DOCK_3_6_10_protectionRecoveryAndNoPinnedCard() async throws {
        #if G1_PLACEMENT_SEAMS
        let f = try await placementFixture(autoHide: true); try f.revealFromWake(); f.tick(0.301)
        let outside = CGPoint(x: 600, y: 400)
        for lock in [DockRecordedLocks.drag, .menu, .keyboard] {
            f.pointer = outside; f.presence.recordedLocks = lock; f.tick(0); f.tick(1.999)
            XCTAssertEqual(f.host.edgePresentation?.state, .expanded)
            f.tick(0.002); XCTAssertEqual(f.host.edgePresentation?.state, .sliver)
            XCTAssertTrue(f.host.forcedHideEventsForChecks.contains(lock), "stale lock recovery must be recorded")
            f.presence.recordedLocks = []; try f.revealFromWake(); f.tick(0.301)
        }
        for protected in ["mouse", "menu", "ignition"] {
            f.pointer = outside
            switch protected { case "mouse": f.presence.mouseButtonDown = true; case "menu": f.host.menuWillOpen(f.host.menu()); default: f.presence.ignitionHeld = true }
            f.tick(0); f.tick(2.1); XCTAssertEqual(f.host.edgePresentation?.state, .expanded, protected)
            f.presence.mouseButtonDown = false; f.presence.ignitionHeld = false
            f.host.menuDidClose(f.host.menu()); f.tick(0); f.tick(0.501)
            XCTAssertEqual(f.host.edgePresentation?.state, .sliver); try f.revealFromWake(); f.tick(0.301)
        }
        try f.hover(); f.tick(0.25); XCTAssertFalse(f.host.card.isHidden)
        XCTAssertFalse(f.host.cardPinsDock, "cards are never pinned")
        #else
        throw XCTSkip("DOCK-3.6-10 seam-needed: EngineRowsEntry.swift:dockEnvironment,deadlineElapsed,deadlineScheduling; StaticDockPreviewHost.swift:forcedHideEventsForChecks")
        #endif
    }
    func testG1_DOCK_3_6_11_quotaSegmentsPersistImproveAndSwitchOff() async throws {
        #if G1_PLACEMENT_SEAMS
        let f = try await placementFixture(autoHide: true)
        _ = try f.host.prepareSliver(size: .init(width: 4, height: 180))
        let options = XCTExpectedFailure.Options(); options.isStrict = true
        XCTExpectFailure("DOCK-3.6-11 product-missing on main: sliver has no quota-segment input", options: options) {
            let segments = f.host.sliverQuotaColorsForChecks
            XCTAssertTrue(segments.contains { $0.remainingPercent == 0 && $0.quotaRole == .critical })
            XCTAssertTrue(segments.contains { $0.remainingPercent == 26 && $0.quotaRole == .warning })
            XCTAssertTrue(segments.filter { $0.quotaRole != nil }.allSatisfy { $0.through > $0.from && $0.through - $0.from <= f.host.sliverPitchFractionForChecks })
        }
        try await f.event(); f.host.acknowledgeDockReveal(); _ = try f.host.prepareSliver(size: .init(width: 4, height: 180))
        XCTAssertTrue(f.host.sliverNoticeMarksForChecks.isEmpty)
        let before = f.host.sliverQuotaColorsForChecks; f.tick(0.5); _ = try f.host.prepareSliver(size: .init(width: 4, height: 180))
        XCTAssertEqual(f.host.sliverQuotaColorsForChecks, before, "segments remain static while quota is unchanged")
        var projection = f.raw["projection"] as! [String: Any], rows = projection["rows"] as! [[String: Any]], accounts = rows[0]["accounts"] as! [[String: Any]]
        var windows = accounts[1]["windows"] as! [[String: Any]]; windows[0]["remainingPercent"] = 90; accounts[1]["windows"] = windows
        rows[0]["accounts"] = accounts; projection["rows"] = rows; f.raw["projection"] = projection
        try await f.publish(); _ = try f.host.prepareSliver(size: .init(width: 4, height: 180))
        XCTAssertFalse(f.host.sliverQuotaColorsForChecks.contains { $0.remainingPercent == 26 }, "improved quota retires its segment")
        _ = try await f.editor.commit(SettingsB20Edit.sliverAlert(false)); _ = try f.host.prepareSliver(size: .init(width: 4, height: 180))
        XCTAssertTrue(f.host.sliverQuotaColorsForChecks.allSatisfy { $0.quotaRole == nil })
        #else
        throw XCTSkip("DOCK-3.6-11 seam-needed: EngineRowsEntry.swift:dockEnvironment; StaticDockPreviewHost.swift:sliverQuotaColorsForChecks,sliverNoticeMarksForChecks,sliverPitchFractionForChecks")
        #endif
    }
    func testG1_DOCK_3_6_12_pointerReorderCancelAndRefresh() async throws {
        #if G1_PLACEMENT_SEAMS
        let f = try await placementFixture(); let controller = try XCTUnwrap(f.host.interactionControllerForChecks)
        f.app.updateSystemAccessibility(.init())
        let targets = f.host.interactionEnvironment().targets; XCTAssertGreaterThanOrEqual(targets.count, 2)
        let first = targets[0], second = targets[1]
        XCTAssertTrue(controller.beginNozzle(id: first.id, along: first.along))
        controller.moveNozzle(along: first.along + 5); XCTAssertNil(controller.presentation?.reorder)
        controller.moveNozzle(along: second.along); let preview = try XCTUnwrap(controller.presentation?.reorder)
        XCTAssertEqual(preview.neighbourYieldSeconds, 0.150, accuracy: 0.001)
        controller.endNozzle(insideMain: true, overSameSource: false)
        try await placementEventually { !f.editor.isSaving && f.editor.snapshot?.preferences.subscriptions.order.first == second.id }
        let committed = try XCTUnwrap(f.editor.snapshot?.preferences.subscriptions.order)
        XCTAssertTrue(controller.beginNozzle(id: first.id, along: first.along)); controller.moveNozzle(along: second.along); controller.cancelNozzle()
        XCTAssertEqual(f.editor.snapshot?.preferences.subscriptions.order, committed, "Escape cancels")
        XCTAssertTrue(controller.beginNozzle(id: first.id, along: first.along)); controller.moveNozzle(along: second.along); controller.endNozzle(insideMain: false, overSameSource: false)
        XCTAssertEqual(f.editor.snapshot?.preferences.subscriptions.order, committed, "outside release cancels")
        _ = try await f.editor.commit(SettingsB20Edit.motion(.on))
        XCTAssertTrue(controller.beginNozzle(id: first.id, along: first.along)); controller.moveNozzle(along: second.along)
        XCTAssertEqual(controller.presentation?.reorder?.neighbourYieldSeconds, 0); controller.cancelNozzle()
        XCTAssertTrue(controller.beginNozzle(id: first.id, along: first.along)); controller.endNozzle(insideMain: true, overSameSource: true)
        try await placementEventually { await f.engine.trace().contains("member-refresh") }
        XCTAssertTrue(f.host.card.isHidden, "ring click must not pin a card")
        #else
        throw XCTSkip("DOCK-3.6-12 seam-needed: EngineRowsEntry.swift:dockEnvironment,deadlineElapsed,deadlineScheduling; StaticDockPreviewHost.swift:interactionControllerForChecks")
        #endif
    }
    func testG1_DOCK_3_6_13_keyboardReorderAndAccessibilityAnnouncement() async throws {
        #if G1_PLACEMENT_SEAMS
        for edge in [SettingsDockEdge.bottom, .left, .right] {
            let f = try await placementFixture()
            _ = try await f.editor.commit(SettingsB21Edit.dockEdge(edge))
            let first = G1DFixture.ids[0], delegate = try XCTUnwrap(f.host.dockView.nozzleEventDelegate)
            let key: UInt16 = edge == .bottom ? 124 : 125
            XCTAssertTrue(delegate.optionArrow(id: first, keyCode: key))
            try await placementEventually { !f.editor.isSaving && f.editor.snapshot?.preferences.subscriptions.order.first == G1DFixture.ids[1] }
            let options = XCTExpectedFailure.Options(); options.isStrict = true
            XCTExpectFailure("DOCK-3.6-13 product-missing on main: keyboard reorder has no accessibility announcement consumer", options: options) {
                XCTAssertTrue(f.host.orderAnnouncementsForChecks.contains { $0.subscriptionID == first && $0.position == 1 })
            }
            let reverse: UInt16 = edge == .bottom ? 123 : 126
            XCTAssertTrue(delegate.optionArrow(id: first, keyCode: reverse))
            try await placementEventually { !f.editor.isSaving && f.editor.snapshot?.preferences.subscriptions.order.first == first }
            let reverseOptions = XCTExpectedFailure.Options(); reverseOptions.isStrict = true
            XCTExpectFailure("DOCK-3.6-13 product-missing on main: reverse reorder has no accessibility announcement", options: reverseOptions) {
                XCTAssertTrue(f.host.orderAnnouncementsForChecks.contains { $0.subscriptionID == first && $0.position == 0 })
            }
        }
        #else
        throw XCTSkip("DOCK-3.6-13 seam-needed: EngineRowsEntry.swift:dockEnvironment; StaticDockPreviewHost.swift:orderAnnouncementsForChecks")
        #endif
    }
    func testG1_DOCK_3_6_15_topologyRecoveryAndReservedEdge() async throws {
        #if G1_PLACEMENT_SEAMS
        let f = try await placementFixture()
        f.displays.append(.init(id: "neighbour", frame: .init(x: 1440, y: 0, width: 1200, height: 900), visibleFrame: .init(x: 1440, y: 0, width: 1200, height: 900)))
        f.tick(0)
        let shared = try XCTUnwrap(f.host.edgePresentation?.placement)
        XCTAssertFalse(shared.displayID == "primary" && shared.edge == .right, "the shared edge is ineligible")
        XCTAssertEqual(f.editor.snapshot?.preferences.dockEdge, .right, "temporary recovery is not persisted")
        f.displays = [.init(id: "primary", frame: .init(x: 0, y: 0, width: 1440, height: 900), visibleFrame: .init(x: 0, y: 0, width: 1400, height: 900))]
        f.tick(0)
        XCTAssertNotEqual(f.host.edgePresentation?.placement?.edge, .right, "the system Dock edge is excluded when alternatives exist")
        XCTAssertNotNil(f.host.edgeRecoveryHintForChecks)
        let handler = try XCTUnwrap(f.host.dockView.backgroundDragDelegate)
        let local = try XCTUnwrap(f.host.backgroundDragPointForChecks)
        let start = try XCTUnwrap(f.host.edgePresentation?.placement)
        let global = CGPoint(x: start.frame.minX + local.x, y: start.frame.maxY - local.y)
        f.pointer = global; f.presence.mouseButtonDown = true
        XCTAssertTrue(handler.beginBackgroundMove(local: local, global: global))
        f.pointer = .init(x: 1439, y: 450); handler.updateBackgroundMove(global: f.pointer)
        XCTAssertNotEqual(f.host.edgePresentation?.snapPreview?.edge, .right, "drop previews avoid the reserved edge")
        f.presence.mouseButtonDown = false; handler.endBackgroundMove(global: f.pointer)
        try await placementEventually { !f.editor.isSaving }
        XCTAssertNotEqual(f.host.edgePresentation?.placement?.edge, .right, "drop snaps to an eligible outer edge")
        #else
        throw XCTSkip("DOCK-3.6-15 seam-needed: EngineRowsEntry.swift:dockEnvironment; StaticDockPreviewHost.swift:edgeRecoveryHintForChecks,backgroundDragPointForChecks")
        #endif
    }
    func testG1_DOCK_3_6_17_cockpitOpeningOpenAndCloseInBothModes() async throws {
        #if G1_PLACEMENT_SEAMS
        for attachment in ["attached", "detached"] {
            let f = try await placementFixture(cockpit: true)
            f.app.showConsole()
            XCTAssertEqual(f.host.edgePresentation?.state, .suppressed(.cockpit), "opening must hide Dock")
            try await placementEventually { f.app.cockpitLifecycleForChecks == .open }
            let cockpit = try XCTUnwrap(f.app.cockpitCoordinatorForChecks)
            if attachment == "detached" {
                let detach = try XCTUnwrap(f.app.cockpitDetachAccessibilityElementForChecks)
                XCTAssertTrue(detach.accessibilityPerformPress(), "drive the real detach control")
                try await placementEventually { f.app.cockpitAttachmentForChecks == .detached }
            } else { XCTAssertEqual(f.app.cockpitAttachmentForChecks, .attached) }
            XCTAssertEqual(f.host.edgePresentation?.state, .suppressed(.cockpit), attachment)
            cockpit.close(); try await placementEventually { f.app.cockpitLifecycleForChecks == .closed }
            XCTAssertNotEqual(f.host.edgePresentation?.state, .suppressed(.cockpit), "Dock returns on close")
        }
        #else
        throw XCTSkip("DOCK-3.6-17 seam-needed: EngineDockMenuApplication.swift:cockpitCoordinatorForChecks,cockpitLifecycleForChecks,cockpitAttachmentForChecks,cockpitDetachAccessibilityElementForChecks")
        #endif
    }
}
