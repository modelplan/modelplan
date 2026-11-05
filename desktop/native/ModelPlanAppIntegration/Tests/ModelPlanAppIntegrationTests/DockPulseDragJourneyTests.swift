// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanDock
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
        let controller = DockEdgeController(preference: .init(displayID: "A"), clock: { clock },
            scheduler: DragSchedule(), read: {
                var sample = topology.read()
                sample.presence.autoHide = false
                sample.layouts = sample.displays.flatMap { display in
                    DockEdgeGeometry.allowedEdges.map { layout(display, $0) }
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
        let middle = CGPoint(x: topology.b.frame.midX, y: 300)
        controller.updateBackgroundMove(global: middle)
        let carried = try XCTUnwrap(controller.presentation?.paintedFrame)
        XCTAssertTrue(topology.b.usableFrame.contains(carried), "D-04")
        if mode == 1 { XCTAssertTrue(carried.contains(middle)) }
        else { XCTAssertEqual(carried.minY, topology.b.usableFrame.minY, accuracy: 0.01) }
        XCTAssertTrue(commits.isEmpty)
        controller.cancelBackgroundMove()
        XCTAssertEqual(controller.presentation?.paintedFrame, before, "D-11")
        for screen in [topology.b, topology.c, topology.a] {
            let r = screen.usableFrame
            for (edge, point) in [(DockEdge.left, CGPoint(x: r.minX + 1, y: r.midY)),
                                  (.right, CGPoint(x: r.maxX - 1, y: r.midY)),
                                  (.bottom, CGPoint(x: r.midX, y: r.minY + 1))] {
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
        _ = try await store.update { $0.dockDisplayID = "A"; $0.dockEdge = .right }
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
        let start = panel.frame
        func event(_ type: NSEvent.EventType, point: CGPoint) throws {
            topology.pointer = point
            let location = panel.convertPoint(fromScreen: point)
            panel.sendEvent(try XCTUnwrap(NSEvent.mouseEvent(with: type, location: location, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: panel.windowNumber,
                context: nil, eventNumber: 1, clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1)))
        }
        let view = host.dockView
        let local = try XCTUnwrap(stride(from: 4.0, to: view.bounds.height, by: 4).lazy.flatMap { y in
            stride(from: 4.0, to: view.bounds.width, by: 4).map { CGPoint(x: $0, y: y) }
        }.first { view.backgroundDragDelegate?.backgroundCanDrag(local: $0) == true })
        let down = panel.convertPoint(toScreen: view.convert(local, to: nil))
        try event(.leftMouseDown, point: down)
        XCTAssertEqual(panel.frame, start, "D-11")
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
            let carried = panel.frame
            NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
            host.refreshPresence()
            XCTAssertEqual(panel.frame, carried, "D-09")
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
        topology.active = [topology.a, topology.c]
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        XCTAssertTrue(panel.isVisible, "D-10 fallback")
        topology.active.append(topology.b)
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        XCTAssertEqual(panel.frame.minX, topology.b.visibleFrame.minX, accuracy: 1, "D-10 return")
        let after = await store.snapshot()
        XCTAssertEqual(after.revision, saved.revision)
    }
    func testD04ToD11NativeMode1() async throws { try await exercise(1) }
    func testD04ToD11NativeMode2() async throws { try await exercise(2) }
}
#endif
