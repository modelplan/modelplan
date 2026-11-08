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
    init(profile: URL? = nil, wall: Date? = nil, shortRemaining: [Int] = [41, 26, 0]) throws {
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
                    w["remainingPercent"] = number == 0 ? shortRemaining[index] : [70,60,50][index]
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
        let fixture = try DockStripFixture(shortRemaining: [51, 50, 0])
        addTeardownBlock { @MainActor in await fixture.close() }
        try await fixture.open(autoHide: true)
        XCTAssertEqual(fixture.host.edgePresentation?.state, .sliver)
        let size = try XCTUnwrap(fixture.host.edgePresentation?.placement).sliverFrame.size
        let view = try fixture.host.prepareSliver(size: size)
        func pixels() throws -> Data {
            let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            return try XCTUnwrap(bitmap.tiffRepresentation)
        }
        let withAlerts = try pixels()
        XCTAssertTrue(SettingsPreferences().sliverAlert)
        XCTAssertEqual(view.quotaSegmentColorRolesForChecks.map(\.remainingPercent), [51, 50, 0])
        XCTAssertEqual(view.quotaSegmentColorRolesForChecks.map(\.quotaRole), [nil, .warning, .critical])
        XCTAssertEqual(view.quotaSegmentColorRolesForChecks.map(\.opacity), [0, 0.4, 0.4]) // G3-51: prototype opacity .4
        XCTAssertTrue(view.accessibilityPerformPress())
        XCTAssertEqual(fixture.host.edgePresentation?.state, .expanded)
        _ = try fixture.host.prepareSliver(size: size)
        XCTAssertEqual(try pixels(), withAlerts, "Reveal leaves persistent quota alerts painted")
        fixture.mutateFirstRowAccount(at: 1) { account in
            var windows = account["windows"] as! [[String: Any]]
            windows[0]["remainingPercent"] = 52
            account["windows"] = windows
        }
        try await fixture.publish()
        _ = try fixture.host.prepareSliver(size: size)
        XCTAssertEqual(view.quotaSegmentColorRolesForChecks.map(\.remainingPercent), [51, 52, 0])
        XCTAssertEqual(view.quotaSegmentColorRolesForChecks.map(\.quotaRole), [nil, nil, .critical])
        _ = try await fixture.app.settingsHost.application.editor.commit(SettingsB20Edit.sliverAlert(false))
        _ = try fixture.host.prepareSliver(size: size)
        XCTAssertTrue(view.quotaSegmentColorRolesForChecks.isEmpty)
        XCTAssertNotEqual(try pixels(), withAlerts, "Disabling quota alerts must remove actual painted segments")
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

    /// G3-51 (owner, build 12): an empty Codex quota barely showed on the collapsed strip. The prototype
    /// paints each alarming member's pitch as a glow (clients/official-visuals/dock-aftview-integration/
    /// face.css:125-130, .sl-segment): a gradient along the strip over the whole pitch, clear at both
    /// ends and full ink from 40 % to 60 %, at opacity .4; the strip clips it. Checked pixel by pixel
    /// against the same strip with alerts off. Writes the strip with and without alerts (and an 8x
    /// enlargement side by side) to dock-visual/g3-51.
    func testG351AlertPitchGlowsLikeThePrototype() async throws {
        let fixture = try DockStripFixture(shortRemaining: [51, 50, 0])
        addTeardownBlock { @MainActor in await fixture.close() }
        try await fixture.open(autoHide: true)
        XCTAssertEqual(fixture.host.edgePresentation?.state, .sliver)
        let size = try XCTUnwrap(fixture.host.edgePresentation?.placement).sliverFrame.size
        func capture(_ view: DockSliverView) throws -> NSBitmapImageRep {
            let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            return bitmap
        }
        let view = try fixture.host.prepareSliver(size: size, backingScale: 2)
        let segments = view.quotaSegmentColorRolesForChecks
        let critical = try XCTUnwrap(segments.first { $0.quotaRole == .critical })
        let warning = try XCTUnwrap(segments.first { $0.quotaRole == .warning })
        XCTAssertEqual(critical.opacity, 0.4); XCTAssertEqual(warning.opacity, 0.4)
        XCTAssertEqual(critical.rgbaHex, "#EF4444FF", "--st-low"); XCTAssertEqual(warning.rgbaHex, "#EAC17BFF", "--st-mid")
        XCTAssertLessThanOrEqual(critical.span.lowerBound, critical.from); XCTAssertGreaterThanOrEqual(critical.span.upperBound, critical.through)
        let alerted = try capture(view)
        _ = try await fixture.app.settingsHost.application.editor.commit(SettingsB20Edit.sliverAlert(false))
        let neutralView = try fixture.host.prepareSliver(size: size, backingScale: 2)
        XCTAssertTrue(neutralView.quotaSegmentColorRolesForChecks.allSatisfy { $0.quotaRole == nil })
        let neutral = try capture(neutralView)
        XCTAssertEqual(alerted.pixelsWide, neutral.pixelsWide); XCTAssertEqual(alerted.pixelsHigh, neutral.pixelsHigh)

        let vertical = size.height > size.width
        let length = Double(vertical ? alerted.pixelsHigh : alerted.pixelsWide)
        func colour(_ bitmap: NSBitmapImageRep, along: Int) throws -> [Double] {
            let cross = (vertical ? bitmap.pixelsWide : bitmap.pixelsHigh) / 2
            let c = try XCTUnwrap((vertical ? bitmap.colorAt(x: cross, y: along) : bitmap.colorAt(x: along, y: cross))?.usingColorSpace(.sRGB))
            return [c.redComponent, c.greenComponent, c.blueComponent].map(Double.init)
        }
        for (segment, ink) in [(critical, [239.0, 68, 68]), (warning, [234.0, 193, 123])] {
            let span = segment.span, width = span.upperBound - span.lowerBound
            var peak = 0.0
            for step in 1..<40 {
                let t = Double(step) / 40, position = span.lowerBound + t * width
                // Whole pixels well inside the strip's share of the pitch only.
                guard position > segment.from + 1 / length, position < segment.through - 1 / length else { continue }
                let along = Int(position * length)
                let centre = (Double(along) + 0.5) / length, k = (centre - span.lowerBound) / width
                let weight = k < 0.4 ? k / 0.4 : (k <= 0.6 ? 1 : (1 - k) / 0.4)
                let base = try colour(neutral, along: along), got = try colour(alerted, along: along)
                for channel in 0..<3 {
                    let expected = base[channel] * (1 - 0.4 * weight) + ink[channel] / 255 * 0.4 * weight
                    XCTAssertEqual(got[channel], expected, accuracy: 4.0 / 255, "\(segment.quotaRole.map { "\($0)" } ?? "") t=\(t) channel \(channel)")
                }
                peak = max(peak, abs(got[0] - base[0]))
            }
            XCTAssertGreaterThan(peak, 0, "the pitch is painted")
        }

        let root = ProcessInfo.processInfo.environment["RUNNER_TEMP"].map { URL(fileURLWithPath: $0, isDirectory: true) } ?? FileManager.default.temporaryDirectory
        let out = root.appendingPathComponent("dock-instrument-checks/dock-visual/g3-51", isDirectory: true)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        try XCTUnwrap(alerted.representation(using: .png, properties: [:])).write(to: out.appendingPathComponent("after-strip-alerts.png"))
        try XCTUnwrap(neutral.representation(using: .png, properties: [:])).write(to: out.appendingPathComponent("strip-alerts-off.png"))
        if let a = alerted.cgImage, let n = neutral.cgImage {
            let zoom = 8, gap = 40, w = (a.width * zoom) * 2 + gap * 3, h = a.height * zoom + gap * 2
            if w * h <= 40_000_000, let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                c.setFillColor(CGColor(srgbRed: 0.93, green: 0.94, blue: 0.95, alpha: 1)); c.fill(CGRect(x: 0, y: 0, width: w, height: h))
                c.interpolationQuality = .none
                c.draw(a, in: CGRect(x: gap, y: gap, width: a.width * zoom, height: a.height * zoom))
                c.draw(n, in: CGRect(x: gap * 2 + a.width * zoom, y: gap, width: n.width * zoom, height: n.height * zoom))
                if let image = c.makeImage(), let rep = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
                    try rep.write(to: out.appendingPathComponent("after-strip-alerts-vs-off-8x.png"))
                }
            }
        }
    }
}
