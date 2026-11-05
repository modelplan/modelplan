// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor private final class DragTopology {
    let a = DockDisplayArea(id: "A", frame: CGRect(x: 0, y: 0, width: 1400, height: 900),
        visibleFrame: CGRect(x: 0, y: 70, width: 1400, height: 800), backingScale: 2)
    let b = DockDisplayArea(id: "B", frame: CGRect(x: 1400, y: -100, width: 1600, height: 1000),
        visibleFrame: CGRect(x: 1400, y: -100, width: 1600, height: 975))
    let c = DockDisplayArea(id: "C", frame: CGRect(x: -1200, y: -800, width: 1200, height: 800),
        visibleFrame: CGRect(x: -1200, y: -800, width: 1200, height: 775))
    var pointer = CGPoint(x: 700, y: 400)
    var active: [DockDisplayArea] = []
    init() { active = [a, b, c] }
    func read() -> DockEdgeEnvironment {
        .init(displays: active, layouts: [], primaryDisplayID: "A", pointer: pointer)
    }
}

@MainActor private final class DragSchedule: DockEdgeScheduling {
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) {}
    func cancel() {}
}

@MainActor final class DockPulseDragLogicTests: XCTestCase {
    private func exercise(_ mode: Int) throws {
        UserDefaults.standard.register(defaults: ["ModelPlanDockDragMode": mode])
        defer { UserDefaults.standard.register(defaults: ["ModelPlanDockDragMode": 1]) }
        let topology = DragTopology()
        let layout: (DockDisplayArea, DockEdge) -> DockEdgeLayout = { screen, edge in
            .init(displayID: screen.id, edge: edge, expandedSize: edge == .bottom ?
                CGSize(width: 160, height: 80) : CGSize(width: 80, height: 160),
                sliverLength: 110, sliverThickness: 4, hoverRects: [])
        }
        var clock = 0.0
        var expandedLayout = false
        let controller = DockEdgeController(preference: .init(displayID: "A"), clock: { clock },
            scheduler: DragSchedule(), read: {
                var sample = topology.read()
                sample.presence.autoHide = false
                sample.layouts = sample.displays.flatMap { display in
                    DockEdgeGeometry.allowedEdges.map { edge in
                        let base = layout(display, edge)
                        if expandedLayout {
                            let size = CGSize(width: base.expandedSize.width, height: base.expandedSize.height + 12)
                            return DockEdgeLayout(displayID: display.id, edge: edge, expandedSize: size,
                                sliverLength: base.sliverLength, sliverThickness: base.sliverThickness, hoverRects: [])
                        }
                        return base
                    }
                }
                return sample
            }, position: PulseDockPositioning.resolve)
        var commits: [DockEdgePreference] = []
        controller.onCommittedPlacement = { commits.append($0) }
        controller.start()
        defer { controller.stop() }
        func press() throws -> CGRect {
            clock += 1
            let frame = try XCTUnwrap(controller.presentation?.paintedFrame)
            controller.dragRegions = .init(body: CGPath(rect: CGRect(origin: .zero, size: frame.size), transform: nil),
                excludedControls: [])
            let down = CGPoint(x: frame.midX, y: frame.midY)
            XCTAssertTrue(controller.beginBackgroundMove(local: CGPoint(x: frame.width / 2, y: frame.height / 2), global: down))
            return frame
        }
        let before = try press()
        // A topology sample while the mouse is held may not replace the painted surface.
        topology.active = [topology.a, topology.b]
        controller.refresh()
        XCTAssertTrue(controller.isBackgroundPressed, "D-09")
        XCTAssertEqual(controller.presentation?.paintedFrame, before)
        topology.active.append(topology.c)
        // Sliding along the right rail into the bottom snap range applies no pull-off.
        let corner = CGPoint(x: before.midX, y: topology.a.usableFrame.minY + 10)
        controller.updateBackgroundMove(global: corner)
        XCTAssertEqual(controller.presentation?.placement?.edge, mode == 1 ? .right : .bottom,
                       "D-04: strong snap holds the right rail until pull-off; always-attached selects the nearest edge")
        let held = CGPoint(x: before.midX - 70, y: before.midY)
        controller.updateBackgroundMove(global: held)
        XCTAssertEqual(controller.presentation?.paintedFrame?.maxX, topology.a.usableFrame.maxX)
        let pulled = CGPoint(x: before.midX - 140, y: before.midY)
        controller.updateBackgroundMove(global: pulled)
        if mode == 1 {
            XCTAssertTrue(controller.presentation?.paintedFrame?.contains(pulled) == true)
            XCTAssertLessThan(try XCTUnwrap(controller.presentation?.paintedFrame?.maxX), topology.a.usableFrame.maxX)
        } else {
            XCTAssertEqual(controller.presentation?.paintedFrame?.maxX, topology.a.usableFrame.maxX)
        }
        let middle = CGPoint(x: topology.b.frame.midX, y: 300)
        controller.updateBackgroundMove(global: middle)
        let carried = try XCTUnwrap(controller.presentation?.paintedFrame)
        XCTAssertTrue(topology.b.usableFrame.contains(carried), "D-04")
        if mode == 1 { XCTAssertTrue(carried.contains(middle)) }
        else { XCTAssertEqual(carried.minY, topology.b.usableFrame.minY, accuracy: 0.01) }
        XCTAssertTrue(commits.isEmpty)

        // While carrying on B, deliver a changed layout and remove the old
        // display. A refresh may neither cancel the press nor move the panel.
        expandedLayout = true
        topology.active = [topology.b, topology.c]
        topology.pointer = CGPoint(x: topology.c.frame.midX, y: topology.c.frame.midY)
        clock += 1
        controller.refresh()
        XCTAssertTrue(controller.isBackgroundPressed, "D-09")
        XCTAssertEqual(controller.presentation?.paintedFrame, carried, "D-09")
        XCTAssertTrue(commits.isEmpty)
        controller.updateBackgroundMove(global: CGPoint(x: middle.x + 120, y: middle.y))
        let stillCarried = try XCTUnwrap(controller.presentation?.paintedFrame)
        XCTAssertTrue(topology.b.usableFrame.contains(stillCarried))
        XCTAssertNotEqual(stillCarried, carried, "the next pointer event must keep moving the same widget")
        expandedLayout = false
        topology.active = [topology.a, topology.b, topology.c]
        controller.cancelBackgroundMove()
        XCTAssertEqual(controller.presentation?.paintedFrame, before, "D-11")
        for screen in [topology.b, topology.c, topology.a] {
            let r = screen.usableFrame
            let vertical = [r.minY + 30, r.midY, r.maxY - 30]
            let horizontal = [r.minX + 30, r.midX, r.maxX - 30]
            let points = vertical.map { (DockEdge.left, CGPoint(x: r.minX + 1, y: $0)) } +
                vertical.map { (DockEdge.right, CGPoint(x: r.maxX - 1, y: $0)) } +
                horizontal.map { (DockEdge.bottom, CGPoint(x: $0, y: r.minY + 1)) }
            for (edge, point) in points {
                _ = try press()
                let count = commits.count
                controller.updateBackgroundMove(global: point)
                controller.endBackgroundMove(global: point)
                controller.endBackgroundMove(global: point)
                XCTAssertEqual(commits.count, count + 1, "D-06")
                XCTAssertEqual(commits.last?.displayID, screen.id, "D-07")
                XCTAssertEqual(commits.last?.edge, edge, "D-07")
            }
        }
    }
    func testD08D10InnerStripWakeAndHotPlugPreserveIntentInBothModes() throws {
        defer { UserDefaults.standard.register(defaults: ["ModelPlanDockDragMode": 1]) }
        for mode in [1, 2] {
            UserDefaults.standard.register(defaults: ["ModelPlanDockDragMode": mode])
            let topology = DragTopology()
            topology.pointer = CGPoint(x: topology.b.frame.midX, y: 450)
            var clock = 0.0
            var commits = 0
            let controller = DockEdgeController(preference: .init(displayID: "B", edge: .left, alongFraction: 0.6),
                clock: { clock }, scheduler: DragSchedule(), read: {
                    var sample = topology.read()
                    sample.layouts = sample.displays.map {
                        DockEdgeLayout(displayID: $0.id, edge: .left, expandedSize: CGSize(width: 80, height: 160),
                                       sliverLength: 110, sliverThickness: 4, hoverRects: [])
                    }
                    return sample
                }, position: PulseDockPositioning.resolve)
            controller.onCommittedPlacement = { _ in commits += 1 }
            controller.start()
            XCTAssertEqual(controller.presentation?.state, .sliver)
            let strip = try XCTUnwrap(controller.presentation?.paintedFrame)
            topology.pointer = CGPoint(x: strip.midX, y: strip.midY)
            controller.refresh()
            clock += 1
            controller.refresh()
            XCTAssertEqual(controller.presentation?.state, .expanded)
            topology.active = [topology.a, topology.c]
            controller.refresh()
            XCTAssertEqual(controller.presentation?.placement?.displayID, "A")
            topology.active.append(topology.b)
            controller.refresh()
            XCTAssertEqual(controller.presentation?.placement?.displayID, "B")
            XCTAssertEqual(controller.preference, .init(displayID: "B", edge: .left, alongFraction: 0.6))
            XCTAssertEqual(commits, 0)
            controller.stop()
        }
    }
    func testD04D06D07D09D11Mode1() throws { try exercise(1) }
    func testD04D06D07D09D11Mode2() throws { try exercise(2) }
}

#if MODELPLAN_DOCK_NATIVE_JOURNEY
@MainActor final class DockPulseDragNativeTests: XCTestCase {
    private func exercise(_ mode: Int) async throws {
        _ = NSApplication.shared
        UserDefaults.standard.register(defaults: ["ModelPlanDockDragMode": mode])
        defer { UserDefaults.standard.register(defaults: ["ModelPlanDockDragMode": 1]) }
        let topology = DragTopology()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        EngineRowsEntry.nativeJourneyProfile = root
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        _ = try await store.update { $0.dockDisplayID = "A"; $0.dockEdge = .right; $0.followActiveDisplay = true }
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "drag-journey", allowedEnvironment: [:]), settingsStore: store,
            createsNativePanels: true, dockEnvironment: topology.read, activateSettings: {})
        defer {
            app.composition.dock.close()
            EngineRowsEntry.nativeJourneyProfile = nil
            try? FileManager.default.removeItem(at: root)
        }
        await app.prepare()
        app.allowDockPresentation()
        let host = app.composition.dock
        let panel = try XCTUnwrap(host.nativePanel)
        XCTAssertTrue(panel.isVisible)
        // Wait for the existing arrival guard before delivering the first press.
        try await Task.sleep(for: .milliseconds(320))
        let start = panel.frame
        func event(_ type: NSEvent.EventType, point: CGPoint) throws {
            topology.pointer = point
            let location = panel.convertPoint(fromScreen: point)
            panel.sendEvent(try XCTUnwrap(NSEvent.mouseEvent(with: type, location: location, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: panel.windowNumber,
                context: nil, eventNumber: 1, clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1)))
        }
        func assertRaster(_ view: DockInstrumentView, scale: Int, line: UInt = #line) throws {
            let pixels = try XCTUnwrap(view.renderedPixelSize, line: line)
            XCTAssertEqual(pixels.width, ceil(view.bounds.width * CGFloat(scale)), line: line)
            XCTAssertEqual(pixels.height, ceil(view.bounds.height * CGFloat(scale)), line: line)
        }
        let view = host.dockView
        try assertRaster(view, scale: topology.a.backingScale)
        let local = try XCTUnwrap(stride(from: 4.0, to: view.bounds.height, by: 4).lazy.flatMap { y in
            stride(from: 4.0, to: view.bounds.width, by: 4).map { CGPoint(x: $0, y: y) }
        }.first { view.backgroundDragDelegate?.backgroundCanDrag(local: $0) == true })
        let down = panel.convertPoint(toScreen: view.convert(local, to: nil))
        try event(.leftMouseDown, point: down)
        try await Task.sleep(for: .seconds(1))
        XCTAssertEqual(panel.frame, start, "D-11: a held press does not move the panel before motion")
        try event(.leftMouseUp, point: down)
        XCTAssertEqual(panel.frame, start, "D-11 face click")
        try event(.leftMouseDown, point: down)
        let before = await store.snapshot()
        for (display, point) in [(topology.b, CGPoint(x: topology.b.frame.midX, y: 300)),
                                 (topology.c, CGPoint(x: topology.c.frame.midX, y: topology.c.visibleFrame.minY + 2))] {
            try event(.leftMouseDragged, point: point)
            XCTAssertTrue(panel.isVisible, "D-04")
            XCTAssertTrue(display.usableFrame.insetBy(dx: -1, dy: -1).contains(panel.frame), "D-04")
            let painted = try XCTUnwrap(panel.contentView?.subviews.compactMap { $0 as? DockInstrumentView }.first)
            XCTAssertEqual(painted.layer?.contentsScale, CGFloat(display.backingScale), "D-05")
            try assertRaster(painted, scale: display.backingScale)
            let carried = panel.frame
            host.refreshDockContent()
            NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
            host.refreshPresence()
            XCTAssertEqual(panel.frame, carried, "D-09: data, topology and active-display sampling leave the carry intact")
        }
        let during = await store.snapshot()
        XCTAssertEqual(during.revision, before.revision)
        let escape = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: panel.windowNumber, context: nil,
            characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53))
        panel.sendEvent(escape)
        XCTAssertEqual(panel.frame, start, "D-11 Escape")
        try event(.leftMouseDown, point: down)
        let release = CGPoint(x: topology.b.visibleFrame.minX + 2, y: topology.b.visibleFrame.midY)
        try event(.leftMouseDragged, point: release)
        try event(.leftMouseUp, point: release)
        let editor = app.settingsHost.application.editor
        try await waitForSettings(editor) { editor.snapshot?.preferences.dockDisplayID == "B" && !editor.isSaving }
        let saved = await store.snapshot()
        XCTAssertEqual(saved.preferences.dockEdge, .left, "D-06 inner edge")
        XCTAssertEqual(saved.revision, before.revision + 1)
        let landed = try XCTUnwrap(panel.contentView?.subviews.compactMap { $0 as? DockInstrumentView }.first)
        try assertRaster(landed, scale: topology.b.backingScale)
        topology.active = [topology.a, topology.c]
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        XCTAssertTrue(panel.isVisible, "D-10 fallback")
        topology.active.append(topology.b)
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        XCTAssertEqual(panel.frame.minX, topology.b.visibleFrame.minX, accuracy: 1, "D-10 return")
        let after = await store.snapshot()
        XCTAssertEqual(after.revision, saved.revision)

        topology.pointer = CGPoint(x: topology.b.frame.midX, y: topology.b.frame.midY)
        _ = try await editor.commit(SettingsB21Edit.autoHide(true))
        func waitForSurface(_ state: DockSurfaceState) async throws {
            let deadline = ContinuousClock.now + .seconds(2)
            while host.edgePresentation?.state != state && ContinuousClock.now < deadline {
                host.refreshPresence()
                try await Task.sleep(for: .milliseconds(10))
            }
            XCTAssertEqual(host.edgePresentation?.state, state)
            XCTAssertTrue(panel.isVisible)
        }
        try await waitForSurface(.sliver)
        topology.pointer = CGPoint(x: panel.frame.midX, y: panel.frame.midY)
        XCTAssertTrue(topology.b.frame.contains(topology.pointer))
        try await waitForSurface(.expanded) // D-08, wake from the B/left inner strip.
    }
    func testD04ToD11NativeMode1() async throws { try await exercise(1) }
    func testD04ToD11NativeMode2() async throws { try await exercise(2) }
}
#endif
