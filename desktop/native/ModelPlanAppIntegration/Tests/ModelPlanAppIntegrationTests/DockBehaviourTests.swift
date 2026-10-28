// SPDX-License-Identifier: MIT
import AppKit
import CryptoKit
import ImageIO
import XCTest
import ModelPlanCore
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanSettings
@testable import ModelPlanAppIntegration

/// Drives the host's real panels and handlers. No event tap, TCC, live reader or official artwork.
@MainActor private final class BehaviourScheduler: DockEdgeScheduling {
    var deadline: TimeInterval?
    var action: (@MainActor () -> Void)?
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) {
        self.deadline = deadline; self.action = action
    }
    func cancel() { deadline = nil; action = nil }
    func fire() { let next = action; cancel(); next?() }
}

@MainActor private final class BehaviourInputs {
    var elapsed: TimeInterval = 0
    var pointer = CGPoint(x: 400, y: 300)
    var presence = DockPresence()
    var displays = [DockDisplayArea(id: "main", frame: CGRect(x: 0, y: 0, width: 1200, height: 900),
                                   visibleFrame: CGRect(x: 0, y: 24, width: 1200, height: 850))]
    var suppliedPreferences: SettingsPreferences?
    var suppliedRows: [DockInstrumentReading] = []
}

@MainActor private final class BehaviourFixture {
    let inputs = BehaviourInputs(), scheduler = BehaviourScheduler()
    let host: StaticDockPreviewHost
    let coordinator: SettingsApplicationCoordinator
    let url: URL
    static let now = Date(timeIntervalSince1970: 1_800_000_000)
    // Neutral test registration: the owner's requested M span, asymmetric padding to catch anchor drift.
    // This is a supplier input, not an assertion about official appearance pixels (checklist item 7).
    static let hullSpan: CGFloat = 147.3962
    init(url: URL, capabilities: CommunityReaderCapabilities = .init(), neutralAppearance: Bool = true, customAppearance: StaticDockPreviewHost.Appearance? = nil) throws {
        self.url = url
        _ = NSApplication.shared
        let inputs = inputs, scheduler = scheduler
        let appearance: StaticDockPreviewHost.Appearance?
        if let customAppearance {
            appearance = { view, rows, preferences in
                inputs.suppliedPreferences = preferences; inputs.suppliedRows = rows
                return try customAppearance(view, rows, preferences)
            }
        } else if neutralAppearance {
            appearance = { view, rows, preferences in
                inputs.suppliedPreferences = preferences; inputs.suppliedRows = rows
                try view.applyCommunity(rows, locale: preferences.language.rawValue)
                let factor = preferences.size.nozzleDiameter / 44
                let vertical = preferences.dockEdge != .bottom
                let size = CGSize(width: (vertical ? 90 : 190) * factor, height: (vertical ? 190 : 90) * factor)
                view.setFrameSize(size)
                let hull = CGRect(x: 11 * factor, y: 17 * factor,
                                  width: (vertical ? 60 : BehaviourFixture.hullSpan) * factor,
                                  height: (vertical ? BehaviourFixture.hullSpan : 60) * factor)
                var geometry = StaticDockGeometry(hoverRects: [hull],
                    dragRegions: .init(body: CGPath(rect: hull, transform: nil), excludedControls: []))
                try geometry.registerSliver(hullBounds: hull, expandedSize: size, edge: preferences.dockEdge, scale: factor)
                return geometry
            }
        } else { appearance = nil }
        host = StaticDockPreviewHost(appearance: appearance, currentDate: { BehaviourFixture.now }, createsNativePanels: true,
            nativeEnvironment: { .init(displays: inputs.displays, layouts: [], primaryDisplayID: "main",
                                       pointer: inputs.pointer, presence: inputs.presence) },
            elapsedClock: { inputs.elapsed }, edgeScheduling: scheduler, readerCapabilities: capabilities)
        let host = host
        let coordinator = SettingsApplicationCoordinator(store: try SettingsStore(url: url)) { host.apply($0) }
        self.coordinator = coordinator
        host.catalogueChanged = { [weak coordinator] subscriptions in
            var context = SettingsPageContext(); context.subscriptions = subscriptions
            coordinator?.update(context: context)
        }
    }
    func start() async { await coordinator.reload(); host.setPresentationAllowed(true) }
    func tick(_ seconds: TimeInterval) {
        inputs.elapsed += seconds
        // Exercise the deadline callback installed by the real edge controller, not a second state machine.
        if let deadline = scheduler.deadline, deadline <= inputs.elapsed { scheduler.fire() }
        else { host.refreshPresence() }
    }
    func reveal() throws {
        let placement = try XCTUnwrap(host.edgePresentation?.placement)
        inputs.pointer = CGPoint(x: placement.wakeFrame.midX, y: placement.wakeFrame.midY)
        host.refreshPresence(); tick(0.301)
        XCTAssertEqual(host.edgePresentation?.state, .expanded)
        tick(0.301) // Pass the actual arrival guard before a press/drag.
    }
    func leave() {
        inputs.pointer = CGPoint(x: 500, y: 500)
        host.refreshPresence(); tick(0.501)
    }
    func panel() throws -> NSPanel { try XCTUnwrap(host.nativePanel) }
    func event(_ type: NSEvent.EventType, global: CGPoint) throws -> NSEvent {
        let panel = try panel()
        return try XCTUnwrap(NSEvent.mouseEvent(with: type, location: panel.convertPoint(fromScreen: global),
            modifierFlags: [], timestamp: inputs.elapsed, windowNumber: panel.windowNumber, context: nil,
            eventNumber: 1, clickCount: type == .leftMouseDown ? 1 : 0, pressure: type == .leftMouseDown ? 1 : 0))
    }
    func rows() -> [NSAccessibilityElement] {
        host.dockView.accessibilityChildren()?.compactMap { $0 as? NSAccessibilityElement } ?? []
    }
    func menuText() throws -> String { try XCTUnwrap(panel().contentView?.menu).items.map(\.title).joined(separator: " | ") }
}

@MainActor final class DockBehaviourTests: XCTestCase {
    private func temporaryURL() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("dock-behaviour-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder.appendingPathComponent("settings.json")
    }
    private func report(_ item: Int, _ values: String) {
        print("dock-item \(item) \((testRun?.failureCount ?? 0) == 0 ? "PASS" : "FAIL") \(values)")
    }
    private func feed(accounts: Bool = true, secondAccount: Bool = false, valid: TimeInterval = 600,
                      extras: [String: Any] = [:]) throws -> JoinedSnapshot {
        func instant(_ offset: TimeInterval) -> String {
            ISO8601DateFormatter().string(from: BehaviourFixture.now.addingTimeInterval(offset))
        }
        let windows: [[String: Any]] = [
            ["kind": "five_hour", "remainingPercent": 37, "observedAt": instant(-5), "resetsAt": instant(600)],
            ["kind": "week", "remainingPercent": 72, "observedAt": instant(-5), "resetsAt": instant(3600)],
        ]
        var object: [String: Any] = ["schemaVersion": 1, "contractVersion": 1, "kind": "modelplan.personal-snapshot",
            "generatedAt": instant(-10), "validUntil": instant(valid),
            "accounts": accounts ? [["source": "codex", "subscription": ["subscriptionRef": "synthetic-local", "status": "verified"],
                                      "observedAt": instant(-5), "windows": windows]] : [],
            "subscriptions": accounts ? [["subscriptionRef": "synthetic-local", "sources": ["codex"]]] : []]
        if secondAccount {
            var rows = object["accounts"] as! [[String: Any]]
            var second = rows[0]
            second["subscription"] = ["subscriptionRef": "synthetic-second", "status": "verified"]
            rows.append(second); object["accounts"] = rows
            object["subscriptions"] = [["subscriptionRef": "synthetic-local", "sources": ["codex"]],
                                       ["subscriptionRef": "synthetic-second", "sources": ["codex"]]]
        }
        object.merge(extras) { _, new in new }
        let personal = try FeedDecoder.personal(JSONSerialization.data(withJSONObject: object))
        var ledger = ExpiryLedger()
        return .make(personal: personal, presentation: PersonalProjection.evaluate(personal, now: BehaviourFixture.now,
                                                                                   ledger: &ledger), publication: nil)
    }
    private func render(_ fixture: BehaviourFixture, _ snapshot: JoinedSnapshot?) {
        var diagnostics = StoreDiagnostics(); diagnostics.personal = nil
        fixture.host.render(snapshot: snapshot, diagnostics: diagnostics)
    }

    func testRasterDefaultHostDragShowsPreviewAndRestoresAtBothScales() async throws {
        for scale in [1, 2] {
            let url = try temporaryURL(), folder = url.deletingLastPathComponent()
            let context = try XCTUnwrap(CGContext(data: nil, width: 192, height: 320,
                bitsPerComponent: 8, bytesPerRow: 768, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.setFillColor(NSColor.gray.cgColor)
            context.addPath(CGPath(roundedRect: CGRect(x: 16, y: 16, width: 160, height: 288),
                                   cornerWidth: 16, cornerHeight: 16, transform: nil)); context.fillPath()
            let rasterURL = folder.appendingPathComponent("synthetic-material.png")
            let writer = try XCTUnwrap(CGImageDestinationCreateWithURL(rasterURL as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(writer, try XCTUnwrap(context.makeImage()), nil)
            XCTAssertTrue(CGImageDestinationFinalize(writer))
            let data = try Data(contentsOf: rasterURL)
            let resources = try DockArtworkStore(root: folder, manifest: .init(files: ["material": .init(
                path: rasterURL.lastPathComponent, sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), bytes: data.count)]))
            let json: [String: Any] = ["schemaVersion": 1, "bounds": [[0, 0], [96, 160]], "bodyPolygon": [],
                "fixedLayers": [["resource": "material", "rect": [[0, 0], [96, 160]]]], "palette": [:],
                "text": ["size": 10, "weight": 400], "aliasText": ["size": 10, "weight": 400],
                "stations": [["subscriptionID": "synthetic", "centre": [48, 64], "diameter": 44,
                    "readout": [[28, 90], [40, 16]], "aliasRect": [[24, 118], [48, 12]],
                    "eventRect": [[72, 96], [8, 8]], "glyphRect": [[26, 42], [44, 44]],
                    "layers": [], "glyphs": [:],
                    "outer": ["radius": 20, "width": 2, "minimumVisibleFraction": 0, "opacity": 1],
                    "inner": ["radius": 16, "width": 1, "minimumVisibleFraction": 0, "opacity": 1],
                    "clock": ["radius": 24, "dotRadius": 0.5, "backWidth": 1, "positions": 10],
                    "notchWidth": 1, "caseInnerRadius": 10]]]
            let skin = try JSONDecoder().decode(DockInstrumentSkin.self, from: JSONSerialization.data(withJSONObject: json))
            let renderer = DockInstrumentRenderer(resources: resources)
            let appearance: StaticDockPreviewHost.Appearance = { view, _, _ in
                view.presentationBackingScale = scale
                try view.applyOfficial(skin: skin, rows: [], renderer: renderer, scale: scale, locale: "en")
                return .init(hoverRects: [CGRect(x: 8, y: 8, width: 80, height: 144)], sliverLength: 144,
                             consoleButton: CGRect(x: 16, y: 20, width: 12, height: 12), sliverAlongAnchor: 80)
            }
            let f = try BehaviourFixture(url: url, customAppearance: appearance)
            defer { f.host.close() }
            await f.start()
            let preferences = try XCTUnwrap(f.coordinator.latest).snapshot.preferences
            XCTAssertEqual(preferences.size, .medium); XCTAssertEqual(preferences.size.nozzleDiameter, 44)
            XCTAssertEqual(preferences.dockEdge, .right); XCTAssertTrue(preferences.autoHide)
            XCTAssertEqual(preferences.revealMilliseconds, 150)
            XCTAssertEqual(f.host.edgePresentation?.state, .sliver)
            let initial = try XCTUnwrap(f.host.edgePresentation?.placement)
            f.inputs.pointer = CGPoint(x: initial.wakeFrame.midX, y: initial.wakeFrame.midY)
            f.host.refreshPresence(); f.tick(0.149)
            XCTAssertEqual(f.host.edgePresentation?.state, .sliver)
            f.tick(0.002); XCTAssertEqual(f.host.edgePresentation?.state, .expanded)
            let panel = try f.panel(), originalFrame = panel.frame
            let view = try XCTUnwrap(panel.contentView?.subviews.compactMap { $0 as? DockInstrumentView }.first)
            XCTAssertNil(view.registeredHullPath)
            XCTAssertEqual(view.renderedPixelSize, CGSize(width: 96 * scale, height: 160 * scale))
            var commits: [(String, SettingsDockEdge, Double)] = []
            f.host.commitDisplayPlacement = { commits.append(($0, $1, $2)) }
            func gesture(_ local: CGPoint, to end: CGPoint, release: Bool = true) throws {
                let start = panel.convertPoint(toScreen: view.convert(local, to: nil))
                f.inputs.pointer = start; f.inputs.presence.mouseButtonDown = true
                view.mouseDown(with: try f.event(.leftMouseDown, global: start))
                f.inputs.pointer = end
                view.mouseDragged(with: try f.event(.leftMouseDragged, global: end))
                if release {
                    f.inputs.presence.mouseButtonDown = false
                    view.mouseUp(with: try f.event(.leftMouseUp, global: end))
                }
            }
            let end = CGPoint(x: 1, y: 450)
            try gesture(CGPoint(x: 20, y: 80), to: end)
            XCTAssertTrue(commits.isEmpty, "arrival guard must reject a drag immediately after reveal")
            f.tick(0.301)
            for local in [CGPoint(x: 1, y: 1), CGPoint(x: 20, y: 24), CGPoint(x: 48, y: 64),
                          CGPoint(x: 48, y: 98), CGPoint(x: 76, y: 100), CGPoint(x: 48, y: 124)] {
                XCTAssertFalse(view.backgroundDragDelegate?.backgroundCanDrag(local: local) ?? true)
                try gesture(local, to: end)
                XCTAssertTrue(commits.isEmpty, "padding and every control must not start a host move")
                XCTAssertFalse(f.host.edgePresentation?.moving ?? true)
            }
            try gesture(CGPoint(x: 20, y: 80), to: end, release: false)
            XCTAssertEqual(f.host.edgePresentation?.moving, true)
            let destination = try XCTUnwrap(f.host.edgePresentation?.snapPreview)
            XCTAssertEqual(destination.edge, .left); XCTAssertEqual(panel.frame, originalFrame)
            let preview = try XCTUnwrap(f.host.nativeMovePreviewPanel, "raster drags need visible destination feedback")
            XCTAssertTrue(preview.isVisible); XCTAssertTrue(preview.ignoresMouseEvents)
            XCTAssertEqual(preview.frame, destination.frame)
            XCTAssertNil(preview.contentView?.hitTest(CGPoint(x: 20, y: 80)))
            XCTAssertGreaterThan(preview.alphaValue, 0)
            let surface = try XCTUnwrap(preview.contentView as? DockSnapOutlineView)
            XCTAssertNil(surface.path)
            let material = try XCTUnwrap(surface.rasterImage)
            XCTAssertEqual(material.width, 96 * scale); XCTAssertEqual(material.height, 160 * scale)
            let pixels = try XCTUnwrap(surface.bitmapImageRepForCachingDisplay(in: surface.bounds))
            surface.cacheDisplay(in: surface.bounds, to: pixels)
            let painted = try XCTUnwrap(pixels.colorAt(x: pixels.pixelsWide / 2, y: pixels.pixelsHigh / 2))
            XCTAssertGreaterThan(painted.alphaComponent, 0); XCTAssertLessThan(painted.alphaComponent, 1)
            f.inputs.presence.mouseButtonDown = false
            view.mouseUp(with: try f.event(.leftMouseUp, global: end))
            view.mouseUp(with: try f.event(.leftMouseUp, global: end))
            XCTAssertEqual(commits.count, 1, "a completed native gesture commits once")
            XCTAssertFalse(preview.isVisible); XCTAssertNil(surface.rasterImage)
            let commit = try XCTUnwrap(commits.first)
            try await f.coordinator.editor.commit(.dockPlacement(displayID: commit.0, edge: commit.1, alongFraction: commit.2))
            let placement = try XCTUnwrap(f.host.edgePresentation?.placement)
            try f.reveal(); let savedFrame = panel.frame
            XCTAssertNotEqual(savedFrame, originalFrame)
            f.host.close(); XCTAssertFalse(panel.isVisible); XCTAssertFalse(preview.isVisible)
            let restored = try BehaviourFixture(url: url, customAppearance: appearance)
            defer { restored.host.close() }
            await restored.start(); try restored.reveal()
            XCTAssertEqual(restored.host.edgePresentation?.placement, placement)
            let restoredPanel = try restored.panel()
            XCTAssertEqual(restoredPanel.frame, savedFrame)
            restored.host.close(); XCTAssertFalse(restoredPanel.isVisible)
            print("raster-host scale=\(scale) default-M44-right reveal=150ms preview=visible non-intercepting drop=1 restored=true closed=true")
        }
    }

    func testItem1FirstLaunchIsInsideMainVisibleFrame() async throws {
        let f = try BehaviourFixture(url: temporaryURL()); defer { f.host.close() }
        await f.start()
        let panel = try f.panel(), placement = try XCTUnwrap(f.host.edgePresentation?.placement)
        XCTAssertTrue(panel.isVisible); XCTAssertEqual(placement.displayID, "main")
        XCTAssertTrue(f.inputs.displays[0].visibleFrame.contains(panel.frame))
        try f.reveal()
        XCTAssertTrue(f.inputs.displays[0].visibleFrame.contains(panel.frame))
        report(1, "display=\(placement.displayID) frame=\(panel.frame) visible=\(f.inputs.displays[0].visibleFrame)")
    }

    func testItem2SliverRegistrationAndTenDwellRevealLeaveCycles() async throws {
        let f = try BehaviourFixture(url: temporaryURL()); defer { f.host.close() }
        await f.start()
        let panel = try f.panel(), placement = try XCTUnwrap(f.host.edgePresentation?.placement)
        XCTAssertEqual(f.host.edgePresentation?.state, .sliver)
        XCTAssertEqual(placement.sliverFrame.height, BehaviourFixture.hullSpan, accuracy: 0.0001)
        XCTAssertEqual(placement.sliverFrame.width, 4)
        XCTAssertEqual(placement.sliverFrame.midY, placement.frame.maxY - 17 - BehaviourFixture.hullSpan / 2, accuracy: 0.0001)
        // AppKit rounds an owned window's surface to backing pixels; logical placement remains exact.
        XCTAssertEqual(panel.frame.height, BehaviourFixture.hullSpan, accuracy: 1)
        XCTAssertTrue(panel.contentView is DockSliverView)
        var reveals = 0, collapses = 0
        for _ in 0..<10 {
            f.inputs.pointer = CGPoint(x: placement.wakeFrame.midX, y: placement.wakeFrame.midY)
            f.host.refreshPresence(); f.tick(0.149)
            XCTAssertEqual(f.host.edgePresentation?.state, .sliver, "dwell must not reveal early")
            f.tick(0.002)
            if f.host.edgePresentation?.state == .expanded { reveals += 1 }
            XCTAssertTrue(f.host.dockView.window === panel)
            XCTAssertEqual(panel.frame.minX, placement.frame.minX, accuracy: 1)
            XCTAssertEqual(panel.frame.minY, placement.frame.minY, accuracy: 1)
            XCTAssertEqual(panel.frame.width, placement.frame.width, accuracy: 1)
            XCTAssertEqual(panel.frame.height, placement.frame.height, accuracy: 1)
            f.leave()
            if f.host.edgePresentation?.state == .sliver { collapses += 1 }
            XCTAssertTrue(panel.contentView is DockSliverView)
        }
        XCTAssertEqual(reveals, 10); XCTAssertEqual(collapses, 10)
        report(2, "neutral-M-span=\(placement.sliverFrame.height) thickness=4 reveals=\(reveals)/10 collapses=\(collapses)/10")
    }

    func testItem3ThirtyPointerOnlyMovesCannotRepositionTheWindow() async throws {
        let f = try BehaviourFixture(url: temporaryURL()); defer { f.host.close() }
        await f.start(); try await f.coordinator.editor.commit(.autoHide(false))
        let panel = try f.panel(), frame = panel.frame
        let logicalFrame = f.host.edgePresentation?.placement?.frame
        var commits = 0; f.host.commitDisplayPlacement = { _, _, _ in commits += 1 }
        for index in 0..<30 {
            let p = CGPoint(x: CGFloat(index * 41 % 1200), y: CGFloat(index * 73 % 850) + 24)
            f.inputs.pointer = p
            f.host.dockView.mouseMoved(with: try f.event(.mouseMoved, global: p))
            f.tick(0.16)
            XCTAssertEqual(panel.frame, frame, "pointer sample \(index) without mouse-down")
            XCTAssertEqual(f.host.edgePresentation?.placement?.frame, logicalFrame)
        }
        XCTAssertEqual(commits, 0)
        report(3, "moves=30 frame-delta=0 placement-commits=\(commits)")
    }

    func testItem4NativeDragCommitsAndRecreatesFromStoredPreferences() async throws {
        let url = try temporaryURL(), f = try BehaviourFixture(url: url)
        defer { f.host.close() }
        await f.start(); try f.reveal()
        let panel = try f.panel(), before = panel.frame
        var commits: [(String, SettingsDockEdge, Double)] = []
        // The app's callback saves asynchronously; capture its receipt, then use the same Settings editor transaction.
        f.host.commitDisplayPlacement = { commits.append(($0, $1, $2)) }
        let local = CGPoint(x: 25, y: 30)
        let start = panel.convertPoint(toScreen: f.host.dockView.convert(local, to: nil))
        // Bottom space is reserved for the system Dock in this layout; drop on the exposed left edge.
        let end = CGPoint(x: 1, y: 450)
        f.inputs.pointer = start; f.inputs.presence.mouseButtonDown = true
        f.host.dockView.mouseDown(with: try f.event(.leftMouseDown, global: start))
        f.inputs.pointer = end
        f.host.dockView.mouseDragged(with: try f.event(.leftMouseDragged, global: end))
        XCTAssertEqual(f.host.edgePresentation?.moving, true)
        XCTAssertEqual(f.host.edgePresentation?.snapPreview?.edge, .left)
        f.inputs.presence.mouseButtonDown = false
        f.host.dockView.mouseUp(with: try f.event(.leftMouseUp, global: end))
        XCTAssertEqual(commits.count, 1)
        let commit = try XCTUnwrap(commits.first)
        try await f.coordinator.editor.commit(.dockPlacement(displayID: commit.0, edge: commit.1, alongFraction: commit.2))
        let placement = try XCTUnwrap(f.host.edgePresentation?.placement)
        XCTAssertEqual(placement.edge, .left); XCTAssertNotEqual(placement.frame, before)
        try f.reveal(); let savedFrame = panel.frame
        f.host.close()
        let restored = try BehaviourFixture(url: url); defer { restored.host.close() }
        await restored.start(); try restored.reveal()
        XCTAssertEqual(restored.host.edgePresentation?.placement, placement)
        XCTAssertEqual(try restored.panel().frame, savedFrame)
        report(4, "commits=\(commits.count) edge=\(placement.edge) fraction=\(commit.2) restored-frame=\(savedFrame)")
    }

    func testItem5TwoDisplaySelectionSurvivesRecreationAndPointerCrossing() async throws {
        let url = try temporaryURL(), f = try BehaviourFixture(url: url)
        defer { f.host.close() }
        let second = DockDisplayArea(id: "second", frame: CGRect(x: -1400, y: -200, width: 1400, height: 1000),
                                     visibleFrame: CGRect(x: -1400, y: -176, width: 1400, height: 950))
        f.inputs.displays.append(second); await f.start()
        try await f.coordinator.editor.commit(.dockDisplay("second"))
        try await f.coordinator.editor.commit(.dockEdge(.left))
        try f.reveal()
        let placement = try XCTUnwrap(f.host.edgePresentation?.placement), frame = try f.panel().frame
        XCTAssertEqual(placement.displayID, "second"); XCTAssertTrue(second.visibleFrame.contains(frame))
        f.inputs.pointer = CGPoint(x: 700, y: 500); f.tick(1)
        XCTAssertEqual(f.host.edgePresentation?.placement, placement)
        f.host.close()
        let restored = try BehaviourFixture(url: url); defer { restored.host.close() }
        restored.inputs.displays.append(second); await restored.start(); try restored.reveal()
        XCTAssertEqual(restored.host.edgePresentation?.placement, placement)
        XCTAssertEqual(try restored.panel().frame, frame)
        report(5, "displays=2 chosen=second restored-frame=\(frame) pointer-crossing-delta=0")
    }

    func testItem6SyntheticFeedValuesAndReasonsReachActualRowsAndMenus() async throws {
        let f = try BehaviourFixture(url: temporaryURL(), neutralAppearance: false); defer { f.host.close() }
        await f.start(); try await f.coordinator.editor.commit(.autoHide(false))
        try await f.coordinator.editor.commit(.language(.english))
        render(f, try feed())
        XCTAssertEqual(f.rows().count, 1)
        XCTAssertEqual(f.rows().first?.accessibilityValue() as? String, "37%")
        XCTAssertEqual(f.rows().first?.accessibilityIdentifier(), "dock.subscription.synthetic-local")
        render(f, try feed(valid: -1))
        XCTAssertEqual(f.rows().count, 1)
        XCTAssertFalse((f.rows().first?.accessibilityValue() as? String ?? "").contains("37"))
        XCTAssertTrue(try f.menuText().contains("stale"))
        let absent = try feed(accounts: false, extras: ["connections": [["id": "codex", "installed": ["status": "no", "reason": "not-found"]]]])
        render(f, absent)
        XCTAssertEqual(f.rows().count, 0); XCTAssertTrue(try f.menuText().contains("Tool not detected."))
        let denied = try feed(accounts: false, extras: ["connections": [["id": "codex", "quotaAccess": ["blocked": "reader-consent-or-privacy"]]]])
        render(f, denied)
        XCTAssertEqual(f.rows().count, 0)
        XCTAssertTrue(try f.menuText().contains("Usage access is blocked by consent or privacy settings."))
        let gap = try BehaviourFixture(url: temporaryURL(), capabilities: .init(unconnectedProviders: ["claude"]), neutralAppearance: false)
        defer { gap.host.close() }
        await gap.start(); try await gap.coordinator.editor.commit(.autoHide(false))
        try await gap.coordinator.editor.commit(.language(.english))
        render(gap, nil)
        XCTAssertEqual(gap.rows().count, 0)
        XCTAssertTrue(try gap.menuText().contains("Reader connection is not complete yet."))
        let labels = try gap.panel().contentView?.subviews.flatMap(\.subviews).compactMap { $0 as? NSTextField } ?? []
        XCTAssertTrue(labels.contains { $0.stringValue == "Reader connection is not complete yet." })
        report(6, "synthetic-local=37% stale=reason-only not-detected=0-rows no-consent=0-rows not-connected=0-rows demo-rows=0")
    }

    func testItem8DockSettingsCommitThroughTheSettingsModel() async throws {
        let f = try BehaviourFixture(url: temporaryURL()); defer { f.host.close() }
        await f.start(); render(f, try feed(secondAccount: true))
        let editor = f.coordinator.editor
        try await editor.commit(.showDock(false))
        XCTAssertFalse(try f.panel().isVisible); XCTAssertEqual(f.host.edgePresentation?.state, .suppressed(.userHidden))
        try await editor.commit(.showDock(true)); try await editor.commit(.autoHide(false))
        XCTAssertTrue(try f.panel().isVisible); XCTAssertEqual(f.host.edgePresentation?.state, .expanded)
        let medium = try f.panel().frame.size
        try await editor.commit(.size(.large))
        XCTAssertGreaterThan(try f.panel().frame.height, medium.height)
        XCTAssertEqual(f.host.dockView.requestedNozzleDiameter, 52)
        try await editor.commit(.size(.medium))
        try await editor.commit(.dockEdge(.left)); try await editor.commit(.dockPosition(0.3))
        XCTAssertEqual(f.host.edgePresentation?.placement?.edge, .left)
        XCTAssertEqual(try XCTUnwrap(f.host.edgePresentation?.placement?.alongFraction), 0.3, accuracy: 0.0001)
        try await editor.commit(.fullscreen(true))
        XCTAssertTrue(try f.panel().collectionBehavior.contains(.fullScreenAuxiliary))
        try await editor.commit(.fullscreen(false))
        XCTAssertFalse(try f.panel().collectionBehavior.contains(.fullScreenAuxiliary))
        try await editor.commit(.percentageMode(.used))
        XCTAssertEqual(f.rows().first?.accessibilityValue() as? String, "63%")
        try await editor.commit(.percentagePin("synthetic-local", .week))
        XCTAssertEqual(f.rows().first?.accessibilityValue() as? String, "28%")
        try await editor.commit(.redBelow(10))
        XCTAssertEqual(f.inputs.suppliedRows.first?.status, .normal)
        // Supplier-owned choices must reach the appearance transaction; visual effects remain item 7.
        try await editor.commit(.magnification(.strong)); try await editor.commit(.sliverAlert(false))
        XCTAssertEqual(f.inputs.suppliedPreferences?.magnification, .strong)
        XCTAssertEqual(f.inputs.suppliedPreferences?.sliverAlert, false)
        try await editor.commit(.showPercentages(false))
        XCTAssertEqual(f.inputs.suppliedPreferences?.showPercentages, false)
        try await editor.commit(.reveal(300)); try await editor.commit(.autoHide(true))
        f.leave()
        let placement = try XCTUnwrap(f.host.edgePresentation?.placement)
        f.inputs.pointer = CGPoint(x: placement.wakeFrame.midX, y: placement.wakeFrame.midY)
        f.host.refreshPresence(); f.tick(0.299)
        XCTAssertEqual(f.host.edgePresentation?.state, .sliver)
        f.tick(0.002); XCTAssertEqual(f.host.edgePresentation?.state, .expanded)
        // Display selection and following use real Settings edits against a second virtual screen.
        f.inputs.displays.append(.init(id: "other", frame: CGRect(x: -1200, y: 0, width: 1200, height: 900),
                                      visibleFrame: CGRect(x: -1200, y: 24, width: 1200, height: 850)))
        try await editor.commit(.dockDisplay("other"))
        XCTAssertEqual(f.host.edgePresentation?.placement?.displayID, "other")
        try await editor.commit(.activeDisplay(true))
        f.inputs.pointer = CGPoint(x: 400, y: 400); f.host.refreshPresence()
        XCTAssertEqual(f.host.edgePresentation?.placement?.displayID, "main")
        // The catalogue explicitly makes capture hiding unavailable; there is no editable setting to apply.
        XCTAssertThrowsError(try SettingsB21Edit(key: .captureHiding, value: "true"))
        let covered: Set<SettingKey> = [.showDock, .autoHide, .reveal, .magnification, .size, .showPercentages,
            .percentageMode, .percentagePin, .redBelow, .sliverAlert, .dockDisplay, .dockEdge, .dockPosition,
            .fullscreen, .captureHiding, .activeDisplay, .order]
        XCTAssertEqual(Set(Settings65Homes.dock.flatMap(\.keys)), covered)
        try await editor.commit(.moveSubscription("synthetic-second", to: 0,
                                                 expectedOrder: ["synthetic-local", "synthetic-second"]))
        XCTAssertEqual(f.rows().map { $0.accessibilityIdentifier() },
                       ["dock.subscription.synthetic-second", "dock.subscription.synthetic-local"])
        // Existing Community behaviour: the host forwards this choice, but its native row still draws a percentage.
        // Strict expected failure is restricted to this assertion; do not repair behaviour in this test PR.
        let community = try BehaviourFixture(url: temporaryURL(), neutralAppearance: false)
        defer { community.host.close() }
        await community.start(); render(community, try feed())
        try await community.coordinator.editor.commit(.autoHide(false))
        try await community.coordinator.editor.commit(.showPercentages(false))
        let value = try XCTUnwrap(community.rows().first?.accessibilityValue() as? String)
        XCTExpectFailure("dock-item 8: Community row ignores Show percentages=false; beta07 bug") {
            XCTAssertFalse(value.contains("%"), "hidden percentages still expose the native readout: \(value)")
        }
        report(8, "Dock-keys=\(covered.count) reveal=300ms size=L/52 display/follow/edge/position=applied capture=unavailable supplier-options=forwarded expected-failures=1(show-percentages)")
    }
}
