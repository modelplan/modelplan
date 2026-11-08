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

private actor G350Engine: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore, rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "g350", floor: .init(storeEpoch: "g350", generation: 1), revision: 1)
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        return context
    }
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func stop() async {}
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion {
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context), invalidRowCount: 0))
        return .init(requestID: .string("g350-rows"))
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

@MainActor private final class G350NoWindowSurface: SettingsWindowSurface {
    func prepare() async {}
    func show(paneID: String?) {}
    func hide() {}
}

@MainActor private final class G350Clock { var elapsed = 10.0, wall = Date() }

/// G3-50 (owner, build 12): the card's vendor mark is the wrong size, the card sits closer to the
/// widget than in the prototype and the arrow tip is cut off.
/// - Mark: the owner ruled (11-08) that the prototype's mark is itself wrong, so the mark is not
///   copied: every vendor mark is cropped to its visible glyph and drawn as tall as the title line.
/// - Gap and arrow: as the prototype (opus-r7 card.js place() and refreshCardPlacement): 12 x D/52
///   from the ring as painted, and the arrow tip 2 pt before it, also while hover magnification
///   has grown the ring and moved it towards the card.
@MainActor final class G3CardMarkAndGapTests: XCTestCase {
    /// Every vendor mark the widget can show (T2DockSkin logos), plus the opt-in Z.ai mark.
    static let marks: [(resource: String, zai: Bool)] = [
        "logo-openai", "logo-claude", "logo-cursor", "logo-copilot", "logo-kimi", "logo-deepseek", "logo-opencode",
        "logo-gemini", "logo-grok", "logo-x", "logo-qwen", "logo-minimax", "logo-xiaomi", "logo-kiro", "logo-amp",
        "logo-antigravity", "logo-droid", "logo-zhipu",
    ].map { ($0, false) } + [("logo-zai-white", true)]

    private func output(_ name: String) throws -> URL {
        let root = ProcessInfo.processInfo.environment["RUNNER_TEMP"].map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.temporaryDirectory
        let url = root.appendingPathComponent("dock-instrument-checks/dock-visual/\(name)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func png(_ image: CGImage, _ url: URL) {
        guard let writer = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(writer, image, nil); CGImageDestinationFinalize(writer)
    }
    private func content(_ name: String) -> DockCardContent {
        DockCardContent(subscriptionID: "g350", revision: 1, name: name, plan: "Pro", sourceAndAge: "Tool runtime · now",
                        rows: [.init(id: "quota:week", kind: .quota, label: "Weekly", value: "0%", detail: "3d5h", remainingFraction: 0, tone: .critical, emphasised: true)],
                        enterLabel: "Open", dismissLabel: "Close")
    }
    /// The visible (non-clear) extent of an image, in its pixels.
    private func visibleBounds(_ image: CGImage) throws -> CGRect {
        let w = image.width, h = image.height
        let c = try XCTUnwrap(CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
        c.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        let bytes = try XCTUnwrap(c.data).assumingMemoryBound(to: UInt8.self)
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h { for x in 0..<w where bytes[(y * w + x) * 4 + 3] > 0 {
            minX = min(minX, x); minY = min(minY, y); maxX = max(maxX, x); maxY = max(maxY, y)
        }}
        return maxX < minX ? .zero : CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    /// The title-height rule and its slot: the mark is centred in the prototype's 20 pt slot, so the
    /// name keeps its place, and is as tall as the title line (ascender to descender of 13 pt bold).
    func testG350MarkIsAsTallAsTheTitleLineAndCentredInItsSlot() throws {
        let side = StaticDockPreviewHost.cardMarkSize
        let font = NSFont.systemFont(ofSize: 13, weight: .bold)
        XCTAssertEqual(side, ((font.ascender - font.descender) * 2).rounded() / 2)
        XCTAssertGreaterThanOrEqual(side, 14); XCTAssertLessThanOrEqual(side, 17)
        XCTAssertEqual(StaticDockPreviewHost.prototypeCardStyle.brandSize, 20, "the prototype slot stays")
        XCTAssertEqual(StaticDockPreviewHost.prototypeCardStyle.brandMarkSize, side)
        let slot = CGRect(x: 11, y: 10, width: 20, height: 20)
        let square = DockCardView.brandMarkFrame(slot: slot, image: CGSize(width: 30, height: 30), mark: side)
        XCTAssertEqual(square.width, side, accuracy: 0.0001); XCTAssertEqual(square.height, side, accuracy: 0.0001)
        XCTAssertEqual(square.midX, slot.midX, accuracy: 0.0001); XCTAssertEqual(square.midY, slot.midY, accuracy: 0.0001)
        let wide = DockCardView.brandMarkFrame(slot: slot, image: CGSize(width: 40, height: 20), mark: side)
        XCTAssertEqual(wide.width, side, accuracy: 0.001); XCTAssertEqual(wide.height, side / 2, accuracy: 0.001)
        XCTAssertEqual(wide.midX, slot.midX, accuracy: 0.001); XCTAssertEqual(wide.midY, slot.midY, accuracy: 0.001)
        XCTAssertEqual(DockCardView.brandMarkFrame(slot: slot, image: CGSize(width: 30, height: 30), mark: nil), slot)
    }

    /// Every vendor mark gets the same visible size in the card: its glyph's longest side is the title
    /// line within 6 % (the ring's #397 tolerance), whatever clear space its file keeps. Before, the
    /// mark filled the 20 pt slot with its file's viewBox, so OpenAI drew at about half the size of Claude.
    /// Writes every mark in a real card header (2x) to dock-visual/g3-50-marks.
    func testG350EveryVendorMarkHasTheSameVisibleSizeInTheCard() throws {
        let side = StaticDockPreviewHost.cardMarkSize
        let out = try output("g3-50-marks")
        var report = [String]()
        for (resource, zai) in Self.marks {
            let mark = try XCTUnwrap(StaticDockPreviewHost.cardMark(resource, zaiMarkEnabled: zai), resource)
            XCTAssertEqual(max(mark.size.width, mark.size.height), side, accuracy: 0.001, resource)
            let cg = try XCTUnwrap(mark.cgImage(forProposedRect: nil, context: nil, hints: nil), resource)
            let visible = try visibleBounds(cg)
            let fill = max(visible.width, visible.height) / CGFloat(max(cg.width, cg.height))
            XCTAssertGreaterThanOrEqual(fill, 0.94, "\(resource): the glyph fills the mark (no file clear space)")
            let card = DockCardView(frame: .zero)
            card.appearance = NSAppearance(named: .darkAqua)
            var production = StaticDockPreviewHost.prototypeCardStyle; production.showsActions = false // the production card (D37)
            try card.apply(content(String(resource.dropFirst(5)).capitalized), style: production, brandImage: mark)
            let frame = try XCTUnwrap(card.brandMarkFrameForChecks, resource)
            XCTAssertEqual(max(frame.width, frame.height), side, accuracy: 0.01, resource)
            XCTAssertEqual(frame.midX, 11 + 10, accuracy: 0.01, "\(resource): centred in the slot")
            let name = try XCTUnwrap(card.nameFrameForChecks)
            XCTAssertEqual(name.minX, 11 + 20 + 8, accuracy: 0.01, "\(resource): the name keeps the prototype's place")
            let bitmap = try XCTUnwrap(card.bitmapImageRepForCachingDisplay(in: card.bounds))
            card.cacheDisplay(in: card.bounds, to: bitmap)
            if let image = bitmap.cgImage { png(image, out.appendingPathComponent("after-\(resource).png")) }
            // Before: main's cardBrandImage, the whole file (viewBox) drawn into the 20 pt slot.
            if let store = StaticDockPreviewHost.cardResourceStore(zaiMarkEnabled: zai), let file = try? store.image(resource, maximumPixelSize: 64) {
                var legacy = StaticDockPreviewHost.prototypeCardStyle; legacy.brandMarkSize = nil; legacy.showsActions = false
                let old = DockCardView(frame: .zero); old.appearance = NSAppearance(named: .darkAqua)
                try old.apply(content(String(resource.dropFirst(5)).capitalized), style: legacy, brandImage: NSImage(cgImage: file, size: NSSize(width: 20, height: 20)))
                if let rep = old.bitmapImageRepForCachingDisplay(in: old.bounds) {
                    old.cacheDisplay(in: old.bounds, to: rep)
                    if let image = rep.cgImage { png(image, out.appendingPathComponent("before-\(resource).png")) }
                }
                old.dispose()
            }
            report.append("\(resource) mark \(mark.size.width)x\(mark.size.height) glyph-fill \(String(format: "%.3f", fill)) frame \(frame)")
            card.dispose()
        }
        try report.joined(separator: "\n").write(to: out.appendingPathComponent("marks.txt"), atomically: true, encoding: .utf8)
    }

    private func rows(_ ids: [(String, String)]) throws -> WireRowsSnapshot {
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(json["projection"] as? [String: Any])
        let template = try XCTUnwrap((projection["rows"] as? [[String: Any]])?.first)
        let account = try XCTUnwrap((template["accounts"] as? [[String: Any]])?.first)
        let observed = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-60))
        projection["rows"] = ids.enumerated().map { order, item -> [String: Any] in
            var row = template
            row["id"] = item.0; row["order"] = order + 1; row["vendorKey"] = item.1
            row["name"] = ["en": item.0, "zh": item.0]
            row["state"] = "fresh"; row["consent"] = "allowed"; row["surfaces"] = ["dock", "menu", "settings"]
            row["expiresAt"] = "2099-01-01T00:00:00Z"
            var copy = account
            copy["subscriptionRef"] = String(format: "%016x", order + 1)
            copy["valueState"] = "current"; copy["freshUntil"] = "2099-01-01T00:00:00Z"
            if var windows = copy["windows"] as? [[String: Any]], !windows.isEmpty {
                windows[0]["remainingPercent"] = [0, 62, 76][order % 3]; windows[0]["role"] = "weekly"; windows[0]["durationSeconds"] = 604800
                windows[0]["limitKey"] = "weekly"; windows[0]["poolKey"] = "main"; windows[0]["current"] = true; windows[0]["observedAt"] = observed
                windows[0]["resetsAt"] = "2099-01-01T00:00:00Z"; windows[0]["validUntil"] = "2099-01-01T00:00:00Z"
                windows[0].removeValue(forKey: "modelScope")
                copy["windows"] = [windows[0]]; copy["route"] = "runtime_rpc"; copy["observedAt"] = observed
            }
            row["accounts"] = [copy]
            return row
        }
        json["projection"] = projection
        return try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
    }

    /// The card's gap and arrow against the ring as painted, at rest and while the hovered ring is
    /// magnified (subtle: x1.15 and 6 pt towards the card), on the right edge at S, M and L, through
    /// the normal entry with native panels. Writes a 2x composite of widget and card per case to
    /// dock-visual/g3-50-gap (assembled from the two panels' own pixels at their screen frames).
    func testG350CardKeepsThePrototypeGapAndArrowFromTheMagnifiedRing() async throws {
        let out = try output("g3-50-gap")
        var report = [String]()
        for size in SettingsSize.allCases {
            let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g350-" + UUID().uuidString)
            addTeardownBlock { try? FileManager.default.removeItem(at: profile) }
            let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
            _ = try await store.update { p in
                p.showDock = true; p.autoHide = false; p.dockEdge = .right; p.size = size; p.magnification = .subtle
                p.motion = .system; for _ in 0..<16 { p.onboarding.next() }
            }
            let snapshot = try rows([("codex", "openai"), ("claude-code", "claude"), ("zcode", "zhipu")])
            let clock = G350Clock()
            var pointer = CGPoint(x: 600, y: 450)
            let screen = DockDisplayArea(id: "primary", frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 80, width: 1440, height: 795), backingScale: 2)
            let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: store, createsNativePanels: true, bundleURL: profile.appendingPathComponent("Synthetic.app"),
                dockEnvironment: { .init(displays: [screen], layouts: [], primaryDisplayID: "primary", pointer: pointer) },
                deadlineNow: { [clock] in clock.wall }, deadlineElapsed: { [clock] in clock.elapsed },
                makeClient: { _, target in G350Engine(store: target, rows: snapshot) }, makeSettingsSurface: { _ in G350NoWindowSurface() },
                isolatedResetNotificationLedger: profile.appendingPathComponent("reset-notifications.json"), activateSettings: {})
            app.makeFirstRunSurface = { _ in G350NoWindowSurface() }
            app.makeFirstRunSurfaceWithConsent = { _, _ in G350NoWindowSurface() }
            await app.prepare()
            app.startLifecycle(workspace: NotificationCenter(), local: NotificationCenter(), lockEvents: NotificationCenter(), displayIDs: { [1] }, onConsole: { true }, displaysAsleep: { _ in false })
            app.allowDockPresentation()
            let dock = app.composition.dock, view = dock.dockView
            for _ in 0..<1000 {
                if !app.lifecyclePaused, (view.presentedSkinForChecks?.stations.filter { $0.subscriptionID != nil }.count ?? 0) == 3, view.window != nil { break }
                try await Task.sleep(for: .milliseconds(10))
            }
            let label = size.rawValue, unit = size.nozzleDiameter / 52
            let id = try XCTUnwrap(view.presentedSkinForChecks?.stations.compactMap(\.subscriptionID).dropFirst().first, label)
            let window = try XCTUnwrap(view.window, label)
            func screenRect(_ local: CGRect) -> CGRect { window.convertToScreen(view.convert(local, to: nil)) }
            let resting = screenRect(try XCTUnwrap(view.cardRingAnchor(id), label))
            let hit = screenRect(try XCTUnwrap(view.interactionAnchor(id), label))
            pointer = CGPoint(x: hit.midX, y: hit.midY)
            let events = try XCTUnwrap(view.nozzleEventDelegate, label)
            events.hoverNozzle(nil); events.hoverNozzle(id)
            clock.elapsed += 0.6; clock.wall.addTimeInterval(0.6); dock.interactionControllerForChecks?.refresh()
            for _ in 0..<200 where dock.cardPlateForChecks == nil { try await Task.sleep(for: .milliseconds(10)); dock.interactionControllerForChecks?.refresh() }
            let pose = try XCTUnwrap(view.nozzlePosesForChecks[id], "\(label): subtle magnification is on the hovered ring")
            XCTAssertEqual(pose.scale, 1.15, accuracy: 0.001, label)
            let ring = screenRect(try XCTUnwrap(view.cardRingAnchor(id), label))
            XCTAssertEqual(ring.width, resting.width * 1.15, accuracy: 0.01, "\(label): the anchor is the magnified ring")
            XCTAssertLessThan(ring.minX, resting.minX - 6 * unit, "\(label): the magnified ring reaches towards the card")
            let plate = try XCTUnwrap(dock.cardPlateForChecks, "\(label): a card is shown")
            let arrow = try XCTUnwrap(dock.cardArrowForChecks, "\(label): the arrow is shown")
            let tip = try XCTUnwrap(arrow.max { $0.x < $1.x })
            XCTAssertGreaterThanOrEqual(ring.minX - plate.maxX, 12 * unit - 0.01, "\(label): 12 x D/52 from the ring as painted (card.js place)")
            XCTAssertEqual(tip.x, ring.minX - 2, accuracy: 0.01, "\(label): the tip stops 2 pt before the painted ring")
            XCTAssertEqual(tip.y, ring.midY, accuracy: 0.5, label)
            report.append("\(label) magnified ring \(ring) plate \(plate) gap \(ring.minX - plate.maxX) tip \(tip)")
            if let image = composite(dock: dock) { png(image, out.appendingPathComponent("after-right-\(label)-hover.png")) }

            // The pointer moves on: the pose resets and the shown card follows the resting ring.
            events.hoverNozzle(nil)
            XCTAssertNil(view.nozzlePosesForChecks[id], label)
            if let rest = dock.cardPlateForChecks, let back = dock.cardArrowForChecks?.max(by: { $0.x < $1.x }) {
                XCTAssertGreaterThanOrEqual(resting.minX - rest.maxX, 12 * unit - 0.01, "\(label): back to the resting gap")
                XCTAssertEqual(back.x, resting.minX - 2, accuracy: 0.01, label)
                report.append("\(label) resting ring \(resting) plate \(rest) gap \(resting.minX - rest.maxX) tip \(back)")
            }
            await app.stopLifecycle(); dock.close()
        }
        try report.joined(separator: "\n").write(to: out.appendingPathComponent("gap.txt"), atomically: true, encoding: .utf8)
        print(report.joined(separator: "\n"))
    }

    /// The widget panel and the card panel drawn at their screen frames, 2x, on a dark ground.
    private func composite(dock: StaticDockPreviewHost) -> CGImage? {
        let view = dock.dockView
        guard let dockWindow = view.window, let chrome = dock.cardChromeForChecks, let cardWindow = chrome.window else { return nil }
        let parts: [(NSView, CGRect)] = [(view, dockWindow.convertToScreen(view.convert(view.bounds, to: nil))),
                                         (chrome, cardWindow.convertToScreen(chrome.convert(chrome.bounds, to: nil)))]
        let union = parts.map(\.1).reduce(CGRect.null) { $0.union($1) }.insetBy(dx: -16, dy: -16)
        let scale: CGFloat = 2
        guard let c = CGContext(data: nil, width: Int(union.width * scale), height: Int(union.height * scale), bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        c.setFillColor(CGColor(srgbRed: 0.11, green: 0.13, blue: 0.16, alpha: 1)); c.fill(CGRect(x: 0, y: 0, width: c.width, height: c.height))
        for (part, frame) in parts {
            guard let rep = part.bitmapImageRepForCachingDisplay(in: part.bounds) else { continue }
            part.cacheDisplay(in: part.bounds, to: rep)
            guard let image = rep.cgImage else { continue }
            c.draw(image, in: CGRect(x: (frame.minX - union.minX) * scale, y: (frame.minY - union.minY) * scale, width: frame.width * scale, height: frame.height * scale))
        }
        return c.makeImage()
    }
}
