// SPDX-License-Identifier: MIT
import AppKit
import ImageIO
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
@_spi(DockResourceChecks) @testable import ModelPlanAppIntegration

@MainActor private final class WP15NoWindowSurface: SettingsWindowSurface {
    func prepare() async {}
    func show(paneID: String?) {}
    func hide() {}
}

/// WP-15 GUI leg: the real Dock view paints the ring states and the host presents the hovered card (V1-FINAL §1, §2;
/// DOCK-3.2-50, DOCK-3.8-50…53) and G3-136's empty ring (owner 11-18). Reference: Pulse (qunqin24/Pulse v1.12.4)
/// `UsageRingView` and its hover card. Images go to $RUNNER_TEMP/dock-instrument-checks/dock-visual/wp15 for the
/// owner's confirm page.
@MainActor final class WP15WidgetRingCardGUITests: XCTestCase {
    private let base = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970))

    private func launch(_ members: [WP15Rows.Member], language: SettingsLanguage = .chinese) async throws -> (EngineDockMenuApplication, DockInstrumentView) {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("wp15-gui-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: profile) }
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        _ = try await store.update { p in
            p.showDock = true; p.autoHide = false; p.dockEdge = .right; p.size = .medium; p.showPercentages = true; p.language = language
            for _ in 0..<16 { p.onboarding.next() }
        }
        let snapshot = try WP15Rows.snapshot(members, base: base)
        let wall = base
        let screen = DockDisplayArea(id: "primary", frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 80, width: 1440, height: 795), backingScale: 2)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: store, createsNativePanels: false, bundleURL: profile.appendingPathComponent("Synthetic.app"),
            dockEnvironment: { .init(displays: [screen], layouts: [], primaryDisplayID: "primary", pointer: CGPoint(x: 600, y: 450)) },
            deadlineNow: { wall },
            makeClient: { _, target in WP15Engine(store: target, rows: snapshot) }, makeSettingsSurface: { _ in WP15NoWindowSurface() },
            isolatedResetNotificationLedger: profile.appendingPathComponent("reset-notifications.json"), activateSettings: {})
        app.makeFirstRunSurface = { _ in WP15NoWindowSurface() }
        app.makeFirstRunSurfaceWithConsent = { _, _ in WP15NoWindowSurface() }
        addTeardownBlock { @MainActor in await app.stopLifecycle(); app.composition.dock.close() }
        await app.prepare()
        app.startLifecycle(workspace: NotificationCenter(), local: NotificationCenter(), lockEvents: NotificationCenter(), displayIDs: { [1] }, onConsole: { true }, displaysAsleep: { _ in false })
        let view = app.composition.dock.dockView
        for _ in 0..<1000 {
            if !app.lifecyclePaused, view.presentedReadingsForChecks.count == members.count, view.presentedImageForChecks != nil { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        return (app, view)
    }
    private func write(_ image: CGImage, _ name: String) throws {
        let root = ProcessInfo.processInfo.environment["RUNNER_TEMP"].map { URL(fileURLWithPath: $0, isDirectory: true) } ?? FileManager.default.temporaryDirectory
        let out = root.appendingPathComponent("dock-instrument-checks/dock-visual/wp15", isDirectory: true)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        if let writer = CGImageDestinationCreateWithURL(out.appendingPathComponent(name) as CFURL, "public.png" as CFString, 1, nil) {
            CGImageDestinationAddImage(writer, image, nil); CGImageDestinationFinalize(writer)
        }
    }
    private func write(card view: DockCardView, _ name: String) throws {
        view.appearance = NSAppearance(named: .darkAqua)
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        if let image = rep.cgImage { try write(image, name) }
    }

    /// DOCK-3.2-50 / -51 on the painted Dock: a kept reading keeps its number (dim after an hour), an unreadable one keeps
    /// its ring with "--", a reset window is "--", and the tight one is red.
    func testPaintedRingsForTightKeptResetAndUnreadable() async throws {
        let members: [WP15Rows.Member] = [.tight, .keptRecent, .keptOld, .keptReset, .unread]
        let (_, view) = try await launch(members)
        let readings = view.presentedReadingsForChecks
        XCTAssertEqual(readings[WP15Rows.Member.tight.ref]?.status, .critical)
        XCTAssertEqual(readings[WP15Rows.Member.keptRecent.ref]?.readout, "63%")
        XCTAssertEqual(readings[WP15Rows.Member.keptRecent.ref]?.readoutDimmed, false)
        XCTAssertEqual(readings[WP15Rows.Member.keptOld.ref]?.readout, "63%")
        XCTAssertEqual(readings[WP15Rows.Member.keptOld.ref]?.readoutDimmed, true)
        XCTAssertEqual(readings[WP15Rows.Member.keptReset.ref]?.readout, "--")
        XCTAssertEqual(readings[WP15Rows.Member.unread.ref]?.readout, "--", "an unreadable subscription keeps its ring")
        XCTAssertEqual(readings[WP15Rows.Member.unread.ref]?.status, .unknown)
        try write(try XCTUnwrap(view.presentedImageForChecks), "after-widget-ring-states-M.png")
    }

    /// DOCK-3.8-50…53: hovering a ring presents the v1 final card; the unreadable card carries "重新读取".
    func testHoverPresentsTheV1FinalCardForTightKeptAndUnreadable() async throws {
        let (app, _) = try await launch([.tight, .keptOld, .unread])
        let host = app.composition.dock
        var style = StaticDockPreviewHost.prototypeCardStyle; style.showsActions = false
        for (member, file) in [(WP15Rows.Member.tight, "after-card-tight-zh.png"), (.keptOld, "after-card-kept-3h-zh.png"), (.unread, "after-card-unread-zh.png")] {
            try presentSyntheticHostCard(host, id: member.ref)
            let content = try XCTUnwrap(host.cardContent(for: member.ref, at: base))
            let view = DockCardView(frame: .zero)
            try view.apply(content, style: style)
            let texts = view.subviews.flatMap { [$0] + $0.subviews }.compactMap { ($0 as? NSTextField)?.stringValue }
            switch member {
            case .tight:
                XCTAssertTrue(texts.contains("2 分钟前更新")); XCTAssertTrue(texts.contains("约40m用完"))
                XCTAssertTrue(texts.contains("Tight 5小时 9% · 约40m用完 · 2h00 后重置"), "the footer sentence is painted")
            case .keptOld:
                XCTAssertTrue(texts.contains("3 小时前更新")); XCTAssertTrue(texts.contains("63%"))
            default:
                XCTAssertTrue(texts.contains("未登录")); XCTAssertTrue(texts.contains("打开 Unread 并登录"))
                let buttons = view.subviews.compactMap { $0 as? NSButton }.map(\.title)
                XCTAssertEqual(buttons, ["重新读取"])
            }
            XCTAssertFalse(texts.contains { $0.contains("-- · -- t/s") })
            try write(card: view, file)
            view.dispose()
        }
    }

    /// G3-136 (owner 11-18): with nothing to read the widget stays on screen as an empty ring on the regular nozzle
    /// backdrop with the menu-bar rocket in its centre; no "?" anywhere; the reason is one line.
    func testEmptyWidgetIsAnEmptyRingWithTheRocketMarkAndNoQuestionMark() async throws {
        let (app, view) = try await launch([], language: .english)
        let host = app.composition.dock
        var skin: DockInstrumentSkin?
        for _ in 0..<500 {
            skin = view.presentedSkinForChecks
            if skin?.stations.contains(where: { $0.emptyRing == true }) == true, view.presentedImageForChecks != nil { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let painted = try XCTUnwrap(skin)
        let empty = try XCTUnwrap(painted.stations.first { $0.emptyRing == true }, "the widget is never hidden for this")
        XCTAssertFalse(painted.stations.contains { $0.placeholderLabel == "?" }, "no question mark")
        XCTAssertFalse(empty.layers.isEmpty, "the regular nozzle backdrop")
        XCTAssertNotNil(view.emptyStationRectForChecks)
        XCTAssertNotNil(T2ProductionAppearance.emptyMark, "the status item's rocket template is the mark")
        let image = try XCTUnwrap(view.presentedImageForChecks)
        // The rocket is painted in the glyph box: some pixels there are the light mark ink, unlike a bare face.
        let pixels = CGFloat(image.width) / painted.bounds.width
        let c = try XCTUnwrap(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
        c.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try XCTUnwrap(c.data).assumingMemoryBound(to: UInt8.self)
        var light = 0
        let box = empty.glyphRect
        for dy in stride(from: box.minY, to: box.maxY, by: 0.5) {
            for dx in stride(from: box.minX, to: box.maxX, by: 0.5) {
                let x = Int(((dx - painted.bounds.minX) * pixels).rounded(.down)), y = Int(((dy - painted.bounds.minY) * pixels).rounded(.down))
                guard x >= 0, y >= 0, x < image.width, y < image.height else { continue }
                let i = (y * image.width + x) * 4
                if Int(bytes[i]) > 110 && Int(bytes[i + 1]) > 110 && Int(bytes[i + 2]) > 110 { light += 1 }
            }
        }
        XCTAssertGreaterThan(light, 4, "the rocket mark is painted in the centre")
        let card = try XCTUnwrap(host.emptyCardContent())
        XCTAssertEqual(card.rows.map(\.value), ["No subscriptions yet"])
        XCTAssertFalse(card.rows.contains { $0.value.contains("?") })
        try write(image, "after-widget-empty-M.png")
        // Hover (the view's own mouseMoved/mouseExited path): the pointer on the empty ring shows the reason card; leaving hides it.
        let rect = try XCTUnwrap(view.emptyStationRectForChecks)
        XCTAssertFalse(host.emptyCardShownForChecks)
        view.hoverEmptyStationForChecks(atLocal: CGPoint(x: rect.midX, y: rect.midY))
        XCTAssertTrue(host.emptyCardShownForChecks, "hovering the empty widget explains why there is no data")
        let shown = host.card.subviews.flatMap { [$0] + $0.subviews }.compactMap { ($0 as? NSTextField)?.stringValue }
        XCTAssertTrue(shown.contains("No subscriptions yet"), "the hovered card shows the cause line: \(shown)")
        XCTAssertFalse(shown.contains { $0.contains("?") })
        try write(card: host.card, "after-card-empty-en.png")
        view.hoverEmptyStationForChecks(atLocal: nil)
        XCTAssertFalse(host.emptyCardShownForChecks, "leaving the empty widget hides the reason card")
        // Click: the real pointer dispatcher shows the same reason card while Settings opens.
        var opened = 0; host.showSettings = { opened += 1 }
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertTrue(view.performPointerPress(atLocal: CGPoint(x: rect.midX, y: rect.midY)))
        XCTAssertEqual(opened, 1)
        XCTAssertTrue(host.emptyCardShownForChecks, "clicking the empty widget also explains why there is no data")
    }
}
