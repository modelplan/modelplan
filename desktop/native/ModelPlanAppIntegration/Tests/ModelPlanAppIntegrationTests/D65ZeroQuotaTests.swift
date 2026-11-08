// SPDX-License-Identifier: MIT
import AppKit
import ImageIO
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
@testable import ModelPlanAppIntegration

private actor D65Engine: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore, rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "d65", floor: .init(storeEpoch: "d65", generation: 1), revision: 1)
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        return context
    }
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func stop() async {}
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion {
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context), invalidRowCount: 0))
        return .init(requestID: .string("d65-rows"))
    }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

@MainActor private final class D65NoWindowSurface: SettingsWindowSurface {
    func prepare() async {}
    func show(paneID: String?) {}
    func hide() {}
}

/// D65 (owner 11-08, option B): a window at 0 % draws its ring track in dark red, tints the nozzle face
/// light red and dims the vendor mark; the card adds "5-hour quota used up · resets in 3h 18m"
/// (5 小时额度已用完 · 3 小时 18 分后恢复). Reference: handoffs/shared/zero-quota-options-1108.md and
/// evidence/zero-quota-options @ 7de7acaa (the option B overlay this ports: track #9c3427 .95,
/// face #df604c .20, mark #0b0f13 .45).
@MainActor final class D65ZeroQuotaTests: XCTestCase {
    private let base = Date()

    /// Two OpenAI rows with the same vendor mark: 5-hour at 0 % and at 1 %, weekly 76 % for both.
    private func rows() throws -> WireRowsSnapshot {
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(json["projection"] as? [String: Any])
        let template = try XCTUnwrap((projection["rows"] as? [[String: Any]])?.first)
        let account = try XCTUnwrap((template["accounts"] as? [[String: Any]])?.first)
        let window = try XCTUnwrap((account["windows"] as? [[String: Any]])?.first)
        let stamp = { (d: Date) in ISO8601DateFormatter().string(from: d) }
        projection["rows"] = [("empty", 0.0), ("one", 1.0)].enumerated().map { order, item -> [String: Any] in
            var row = template
            row["id"] = item.0; row["order"] = order + 1; row["vendorKey"] = "openai"
            row["name"] = ["en": "Codex " + item.0, "zh": "Codex " + item.0]
            row["state"] = "fresh"; row["consent"] = "allowed"; row["surfaces"] = ["dock", "menu", "settings"]; row["expiresAt"] = "2099-01-01T00:00:00Z"
            var a = account
            a["subscriptionRef"] = String(format: "%016x", order + 1); a["valueState"] = "current"; a["freshUntil"] = "2099-01-01T00:00:00Z"
            a["route"] = "runtime_rpc"; a["observedAt"] = stamp(base.addingTimeInterval(-60))
            a["windows"] = [0, 1].map { n -> [String: Any] in
                var w = window
                w["id"] = n == 0 ? "short" : "week"; w["role"] = n == 0 ? "session" : "weekly"
                w["durationSeconds"] = n == 0 ? 18000 : 604800; w["limitKey"] = n == 0 ? "five_hour" : "weekly"; w["poolKey"] = "main"
                w["remainingPercent"] = n == 0 ? item.1 : 76.0; w["current"] = true; w["observedAt"] = stamp(base.addingTimeInterval(-60))
                w["resetsAt"] = stamp(base.addingTimeInterval(n == 0 ? 198 * 60 : 5 * 86400)); w["validUntil"] = w["resetsAt"]
                w.removeValue(forKey: "modelScope")
                return w
            }
            row["accounts"] = [a]
            return row
        }
        projection["resetEvents"] = []
        json["projection"] = projection
        return try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
    }

    private func launch(language: SettingsLanguage = .english) async throws -> (EngineDockMenuApplication, DockInstrumentView) {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("d65-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: profile) }
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        _ = try await store.update { p in
            p.showDock = true; p.autoHide = false; p.dockEdge = .right; p.size = .medium; p.showPercentages = true; p.language = language
            for _ in 0..<16 { p.onboarding.next() }
        }
        let snapshot = try rows()
        let screen = DockDisplayArea(id: "primary", frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 80, width: 1440, height: 795), backingScale: 2)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: store, createsNativePanels: false, bundleURL: profile.appendingPathComponent("Synthetic.app"),
            dockEnvironment: { .init(displays: [screen], layouts: [], primaryDisplayID: "primary", pointer: CGPoint(x: 600, y: 450)) },
            makeClient: { _, target in D65Engine(store: target, rows: snapshot) }, makeSettingsSurface: { _ in D65NoWindowSurface() },
            isolatedResetNotificationLedger: profile.appendingPathComponent("reset-notifications.json"), activateSettings: {})
        app.makeFirstRunSurface = { _ in D65NoWindowSurface() }
        app.makeFirstRunSurfaceWithConsent = { _, _ in D65NoWindowSurface() }
        addTeardownBlock { @MainActor in await app.stopLifecycle(); app.composition.dock.close() }
        await app.prepare()
        app.startLifecycle(workspace: NotificationCenter(), local: NotificationCenter(), lockEvents: NotificationCenter(), displayIDs: { [1] }, onConsole: { true }, displaysAsleep: { _ in false })
        let view = app.composition.dock.dockView
        for _ in 0..<1000 {
            if !app.lifecyclePaused, view.presentedReadingsForChecks.count == 2, view.presentedImageForChecks != nil { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        return (app, view)
    }

    /// The nozzle as painted: the empty station against the 1 % station, same vendor, same weekly ring.
    func testD65EmptyWindowDrawsRedTrackRedFaceAndDimmedMark() async throws {
        let (app, view) = try await launch()
        let skin = try XCTUnwrap(view.presentedSkinForChecks), image = try XCTUnwrap(view.presentedImageForChecks)
        let ids = Dictionary(uniqueKeysWithValues: view.presentedReadingsForChecks.map { ($0.value.name, $0.key) })
        let empty = try XCTUnwrap(skin.stations.first { $0.subscriptionID == ids["Codex empty"] })
        let one = try XCTUnwrap(skin.stations.first { $0.subscriptionID == ids["Codex one"] })
        XCTAssertEqual(view.presentedReadingsForChecks[try XCTUnwrap(ids["Codex empty"])]?.outer?.fraction, 0)
        let pixels = CGFloat(image.width) / skin.bounds.width
        let c = try XCTUnwrap(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
        c.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try XCTUnwrap(c.data).assumingMemoryBound(to: UInt8.self)
        func rgb(_ p: CGPoint) -> [Double] {
            let x = Int(((p.x - skin.bounds.minX) * pixels).rounded(.down)), y = Int(((p.y - skin.bounds.minY) * pixels).rounded(.down))
            let i = (y * image.width + x) * 4
            return [Double(bytes[i]), Double(bytes[i + 1]), Double(bytes[i + 2])]
        }
        func mean(_ rect: CGRect) -> [Double] {
            var sum = [0.0, 0.0, 0.0], n = 0.0
            for dy in stride(from: rect.minY, to: rect.maxY, by: 0.5) { for dx in stride(from: rect.minX, to: rect.maxX, by: 0.5) {
                let v = rgb(CGPoint(x: dx, y: dy)); for k in 0..<3 { sum[k] += v[k] }; n += 1 } }
            return sum.map { $0 / max(1, n) }
        }
        // Track: the outer ring at 6 o'clock (no arc there at 0 % or 1 %).
        let track = { (s: DockStationRecipe) in rgb(CGPoint(x: s.centre.x, y: s.centre.y + s.outer.radius)) }
        let redTrack = track(empty), plainTrack = track(one)
        XCTAssertGreaterThan(redTrack[0] - redTrack[1], 60, "the empty ring's track is dark red: \(redTrack)")
        XCTAssertLessThan(abs(plainTrack[0] - plainTrack[1]), 25, "a 1 % ring keeps its neutral track: \(plainTrack)")
        XCTAssertEqual(redTrack[0], 156 * 0.95 + plainTrack[0] * 0.05, accuracy: 18, "track ink #9c3427")
        // Face: between the mark and the case, on the left (no notch there).
        let faceRect = { (s: DockStationRecipe) in CGRect(x: s.centre.x - s.caseInnerRadius * 0.8, y: s.centre.y - 1, width: 2, height: 2) }
        let redFace = mean(faceRect(empty)), plainFace = mean(faceRect(one))
        XCTAssertGreaterThan((redFace[0] - redFace[1]) - (plainFace[0] - plainFace[1]), 8, "the face is tinted red: \(redFace) vs \(plainFace)")
        // Mark: the glyph box is darker than the same mark at 1 %.
        let markLight = { (v: [Double]) in v.reduce(0, +) / 3 }
        let dim = markLight(mean(empty.glyphRect)), lit = markLight(mean(one.glyphRect))
        XCTAssertLessThan(dim, lit * 0.8, "the vendor mark is dimmed: \(dim) vs \(lit)")

        let root = ProcessInfo.processInfo.environment["RUNNER_TEMP"].map { URL(fileURLWithPath: $0, isDirectory: true) } ?? FileManager.default.temporaryDirectory
        let out = root.appendingPathComponent("dock-instrument-checks/dock-visual/d65", isDirectory: true)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        if let writer = CGImageDestinationCreateWithURL(out.appendingPathComponent("after-widget-empty-vs-1pct-M.png") as CFURL, "public.png" as CFString, 1, nil) {
            CGImageDestinationAddImage(writer, image, nil); CGImageDestinationFinalize(writer)
        }
        _ = app
    }

    /// The card's plain line, from the normal entry, for the empty window only, and its Chinese pair.
    func testD65CardSaysTheWindowIsUsedUpAndWhenItResets() async throws {
        let (app, view) = try await launch()
        let ids = Dictionary(uniqueKeysWithValues: view.presentedReadingsForChecks.map { ($0.value.name, $0.key) })
        let card = try XCTUnwrap(app.composition.dock.cardContent(for: try XCTUnwrap(ids["Codex empty"]), at: base))
        let events = card.rows.filter { $0.kind == .event }
        XCTAssertEqual(events.map(\.value), ["5-hour quota used up · resets in 3h 18m"])
        XCTAssertEqual(events.first?.tone, .critical)
        let other = try XCTUnwrap(app.composition.dock.cardContent(for: try XCTUnwrap(ids["Codex one"]), at: base))
        XCTAssertTrue(other.rows.allSatisfy { $0.kind != .event }, "a 1 % window says nothing")
        XCTAssertEqual(EngineRowsText.quotaUsedUp(period: .fiveHour, label: "5h", resetMinutes: 198).chinese, "5 小时额度已用完 · 3 小时 18 分后恢复")
        XCTAssertEqual(EngineRowsText.quotaUsedUp(period: .week, label: "week", resetMinutes: 2 * 1440 + 300).english, "Weekly quota used up · resets in 2d 5h")
        XCTAssertEqual(EngineRowsText.quotaUsedUp(period: .fiveHour, label: "5h", resetMinutes: nil).chinese, "5 小时额度已用完")

        // Laid out under the readout window, the plate's full width, 6 pt below it (prototype .cd-events p).
        let view2 = DockCardView(frame: .zero)
        var style = StaticDockPreviewHost.prototypeCardStyle; style.showsActions = false
        try view2.apply(card, style: style)
        let line = try XCTUnwrap(view2.subviews.first { $0.accessibilityLabel() == "5-hour quota used up · resets in 3h 18m" })
        let readings = view2.subviews.filter { $0 !== line && $0.accessibilityRole() == .group && $0.accessibilityLabel()?.contains("·") == true }
        let bottom = try XCTUnwrap(readings.map(\.frame.maxY).max())
        XCTAssertGreaterThanOrEqual(line.frame.minY, bottom + 6, "below the readout")
        XCTAssertEqual(line.frame.width, style.width - 2 * style.padding, accuracy: 0.01)
        let root = ProcessInfo.processInfo.environment["RUNNER_TEMP"].map { URL(fileURLWithPath: $0, isDirectory: true) } ?? FileManager.default.temporaryDirectory
        let out = root.appendingPathComponent("dock-instrument-checks/dock-visual/d65", isDirectory: true)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        view2.appearance = NSAppearance(named: .darkAqua)
        if let rep = view2.bitmapImageRepForCachingDisplay(in: view2.bounds) {
            view2.cacheDisplay(in: view2.bounds, to: rep)
            try rep.representation(using: .png, properties: [:])?.write(to: out.appendingPathComponent("after-card-empty-en.png"))
        }
        view2.dispose()
    }
}
