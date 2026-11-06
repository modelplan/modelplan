// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanEngineClient
import ModelPlanSettings
#if MODELPLAN_DOCK_NATIVE_JOURNEY
import ModelPlanShell
#endif
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
            for source in [topology.a, topology.b, topology.c] where source.id != screen.id {
                for (index, target) in points.enumerated() {
                    let (edge, point) = target
                    controller.setPreference(.init(displayID: source.id, edge: .right))
                    _ = try press()
                    let count = commits.count
                    controller.updateBackgroundMove(global: point)
                    controller.endBackgroundMove(global: point)
                    controller.endBackgroundMove(global: point)
                    let label = "D-07 mode \(mode), \(source.id) → \(screen.id), \(edge), target \(index % 3)"
                    XCTAssertEqual(commits.count, count + 1, label)
                    let committed = try XCTUnwrap(commits.last)
                    XCTAssertEqual(committed.displayID, screen.id, label)
                    XCTAssertEqual(committed.edge, edge, label)
                    let length = edge == .bottom ? r.width : r.height
                    // The 160-point rail is centred on its anchor and stops 24 points from each corner.
                    let expected = [104 / length, 0.5, 1 - 104 / length][index % 3]
                    XCTAssertEqual(committed.alongFraction, Double(expected), accuracy: 0.0001, label)
                }
            }
        }
    }
    func testD11NozzleDragThresholdSeparatesReorderFromRefresh() throws {
        let controller = DockInteractionController(clock: { 0 }, scheduler: DragSchedule()) {
            .init(catalogue: ["a", "b"], preferences: .init(),
                targets: [.init(id: "a", along: 0), .init(id: "b", along: 10)])
        }
        var refreshes: [String] = []
        var orders: [DockOrderRequest] = []
        controller.onActivate = { refreshes.append($0) }
        controller.onOrderRequest = { orders.append($0) }
        controller.start()
        defer { controller.stop() }

        for distance in [4.0, 5.0] {
            XCTAssertTrue(controller.beginNozzle(id: "a", along: 0))
            controller.moveNozzle(along: distance)
            XCTAssertNil(controller.presentation?.reorder)
            controller.endNozzle(insideMain: true, overSameSource: true)
            XCTAssertTrue(refreshes.isEmpty, "a short drag must not become a ring click")
            XCTAssertTrue(orders.isEmpty)
        }

        XCTAssertTrue(controller.beginNozzle(id: "a", along: 0))
        controller.moveNozzle(along: 6)
        XCTAssertEqual(controller.presentation?.reorder?.order, ["b", "a"])
        controller.cancelNozzle()
        XCTAssertNil(controller.presentation?.reorder)
        XCTAssertTrue(orders.isEmpty, "Escape must leave the order unchanged")

        XCTAssertTrue(controller.beginNozzle(id: "a", along: 0))
        controller.moveNozzle(along: 6)
        controller.endNozzle(insideMain: false, overSameSource: false)
        XCTAssertTrue(orders.isEmpty, "release outside the widget must leave the order unchanged")
        XCTAssertTrue(refreshes.isEmpty)

        XCTAssertTrue(controller.beginNozzle(id: "a", along: 0))
        controller.endNozzle(insideMain: true, overSameSource: true)
        XCTAssertEqual(refreshes, ["a"], "a stationary ring click still refreshes the member")
    }

    func testD09DisappearingDragDestinationCannotJumpOrSaveFallback() throws {
        let topology = DragTopology()
        var clock = 0.0
        let controller = DockEdgeController(preference: .init(displayID: topology.a.id), clock: { clock },
            scheduler: DragSchedule(), read: {
                var sample = topology.read()
                sample.presence.autoHide = false
                sample.layouts = sample.displays.flatMap { display in
                    DockEdgeGeometry.allowedEdges.map { edge in
                        DockEdgeLayout(displayID: display.id, edge: edge, expandedSize: CGSize(width: 80, height: 160),
                            sliverLength: 110, sliverThickness: 4, hoverRects: [])
                    }
                }
                return sample
            }, position: PulseDockPositioning.resolve)
        var commits: [DockEdgePreference] = []
        controller.onCommittedPlacement = { commits.append($0) }
        controller.start()
        defer { controller.stop() }
        let initial = try XCTUnwrap(controller.presentation?.paintedFrame)
        controller.dragRegions = .init(body: CGPath(rect: CGRect(origin: .zero, size: initial.size), transform: nil),
            excludedControls: [])
        clock = 1
        let down = CGPoint(x: initial.midX, y: initial.midY)
        XCTAssertTrue(controller.beginBackgroundMove(local: CGPoint(x: initial.width / 2, y: initial.height / 2), global: down))
        controller.updateBackgroundMove(global: CGPoint(x: down.x, y: down.y + 24))
        let held = try XCTUnwrap(controller.presentation)
        XCTAssertTrue(held.moving)
        let target = CGPoint(x: topology.b.frame.midX, y: topology.b.frame.midY)
        controller.prepareDragDisplay = { display in
            if display.id == topology.b.id { topology.active = [topology.a, topology.c] }
        }

        controller.updateBackgroundMove(global: target)
        XCTAssertEqual(controller.presentation, held, "the last verified carry stays visible during a topology race")
        XCTAssertTrue(controller.isBackgroundPressed)
        XCTAssertTrue(commits.isEmpty)
        topology.active = [topology.a, topology.b, topology.c]
        controller.endBackgroundMove(global: target)
        XCTAssertTrue(commits.isEmpty, "release cannot save a fallback when its destination disappears")
        XCTAssertEqual(controller.preference.displayID, topology.a.id)
        XCTAssertEqual(controller.presentation?.paintedFrame, initial)
    }

    func testD09PreparationCannotCarryOrSaveAfterCockpitBlocks() throws {
        defer { UserDefaults.standard.register(defaults: ["ModelPlanDockDragMode": 1]) }
        for mode in [1, 2] {
            UserDefaults.standard.register(defaults: ["ModelPlanDockDragMode": mode])
            for releasing in [false, true] {
                let topology = DragTopology()
                var clock = 0.0, cockpitClosed = true
                let original = DockEdgePreference(displayID: topology.a.id)
                let controller = DockEdgeController(preference: original, clock: { clock },
                    scheduler: DragSchedule(), read: {
                        var sample = topology.read()
                        sample.presence.autoHide = false
                        sample.presence.cockpitClosed = cockpitClosed
                        sample.layouts = sample.displays.flatMap { display in
                            DockEdgeGeometry.allowedEdges.map { edge in
                                DockEdgeLayout(displayID: display.id, edge: edge, expandedSize: CGSize(width: 80, height: 160),
                                    sliverLength: 110, sliverThickness: 4, hoverRects: [])
                            }
                        }
                        return sample
                    }, position: PulseDockPositioning.resolve)
                var presents: [DockEdgePresentation] = [], commits: [DockEdgePreference] = []
                controller.onPresent = { presents.append($0) }
                controller.onCommittedPlacement = { commits.append($0) }
                controller.start()
                defer { controller.stop() }
                let frame = try XCTUnwrap(controller.presentation?.paintedFrame)
                controller.dragRegions = .init(body: CGPath(rect: CGRect(origin: .zero, size: frame.size), transform: nil),
                    excludedControls: [])
                clock = 1
                let down = CGPoint(x: frame.midX, y: frame.midY)
                XCTAssertTrue(controller.beginBackgroundMove(local: CGPoint(x: frame.width / 2, y: frame.height / 2), global: down))
                controller.updateBackgroundMove(global: CGPoint(x: down.x, y: down.y + 24))
                XCTAssertTrue(controller.presentation?.moving == true)
                presents.removeAll()

                // A new sample can observe suppression during destination preparation,
                // before the next normal visibility event is delivered.
                controller.prepareDragDisplay = { _ in cockpitClosed = false }
                let target = CGPoint(x: topology.b.frame.midX, y: topology.b.frame.midY)
                if releasing { controller.endBackgroundMove(global: target) }
                else { controller.updateBackgroundMove(global: target) }

                XCTAssertEqual(controller.presentation?.state, .suppressed(.cockpit))
                XCTAssertFalse(controller.isBackgroundPressed)
                XCTAssertTrue(presents.allSatisfy { $0.paintedFrame == nil }, "Suppression must not flash a carried or resting frame")
                XCTAssertTrue(commits.isEmpty, "A newly blocked release must not save")
                XCTAssertEqual(controller.preference, original)
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

@MainActor final class DockPulseDragPersistenceTests: XCTestCase {
    func testD19NormalEntryMigratesLegacyFloatingWithoutCoordinates() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("legacy-floating-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: profile) }
        let topology = DragTopology()
        let cases: [(savedDisplay: String?, savedAlong: Double?, expectedDisplay: String, expectedAlong: Double)] = [
            ("B", 0.27, "B", 0.27),
            ("disconnected", 0.27, "A", 0.27),
            (nil, nil, "A", 0.5)
        ]
        for (index, sample) in cases.enumerated() {
            let root = profile.appendingPathComponent(String(index))
            let legacy = root.appendingPathComponent("ModelPlan/Native/settings-v1.json")
            try FileManager.default.createDirectory(at: legacy.deletingLastPathComponent(), withIntermediateDirectories: true)
            var placement: [String: Any] = ["dockEdge": "floating"]
            placement["dockDisplayID"] = sample.savedDisplay
            placement["dockAlongFraction"] = sample.savedAlong
            let bytes = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "preferences": placement])
            try bytes.write(to: legacy)
            let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
            let status = await store.foundationStatus()
            XCTAssertEqual(status?.selection?.settings, .communitySettings)
            XCTAssertEqual(status?.issues, [.init(source: .communitySettings, failure: .invalidEdge)])
            let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
                applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: store,
                createsNativePanels: false, dockEnvironment: topology.read, activateSettings: {})
            addTeardownBlock { @MainActor in await app.composition.stop() }
            await app.prepare()
            app.allowDockPresentation()
            let dock = app.composition.dock
            let displayed = try XCTUnwrap(dock.edgePresentation?.placement)
            XCTAssertEqual(dock.edgePresentation?.state, .expanded)
            XCTAssertEqual(displayed.edge, .right)
            XCTAssertEqual(displayed.displayID, sample.expectedDisplay)
            XCTAssertEqual(displayed.alongFraction, sample.expectedAlong, accuracy: 0.001)
            let settings = await store.snapshot()
            XCTAssertEqual(settings.preferences.dockDisplayID, sample.savedDisplay, "Transient fallback must not replace the saved display")
            XCTAssertEqual(settings.preferences.dockAlongFraction, sample.expectedAlong)
            XCTAssertEqual(settings.preferences.dockEdge, .right)
            XCTAssertEqual(try Data(contentsOf: legacy), bytes)
            await app.composition.stop()
        }
    }

    func testD19FirstExplicitDropAfterLegacyMigrationSurvivesReconstructedEntry() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("legacy-dock-drop-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let topology = DragTopology()
        topology.active.removeAll { $0.id == topology.c.id }
        let legacy = root.appendingPathComponent("ModelPlan/Native/settings-v1.json")
        let target = root.appendingPathComponent("ModelPlan/settings.json")
        try FileManager.default.createDirectory(at: legacy.deletingLastPathComponent(), withIntermediateDirectories: true)
        let bytes = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "preferences": [
            "dockEdge": "floating", "dockDisplayID": topology.c.id, "dockAlongFraction": 0.27,
        ]])
        try bytes.write(to: legacy)

        func launch() async throws -> (EngineDockMenuApplication, SettingsStore) {
            let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
            let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
                applicationVersion: "d19-migrated-drop", allowedEnvironment: [:]), settingsStore: store,
                createsNativePanels: false, dockEnvironment: topology.read, activateSettings: {})
            addTeardownBlock { @MainActor in await app.composition.stop() }
            await app.prepare()
            app.allowDockPresentation()
            return (app, store)
        }

        let (app, store) = try await launch()
        let host = app.composition.dock
        let migrated = await store.snapshot()
        let migratedBytes = try Data(contentsOf: target)
        XCTAssertEqual(migrated.preferences.dockDisplayID, topology.c.id)
        XCTAssertEqual(migrated.preferences.dockEdge, .right)
        XCTAssertEqual(migrated.preferences.dockAlongFraction, 0.27)
        XCTAssertEqual(host.edgePresentation?.placement?.displayID, topology.a.id)

        topology.active.append(topology.c)
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        host.refreshPresence()
        let original = try XCTUnwrap(host.edgePresentation?.placement)
        XCTAssertEqual(original.displayID, topology.c.id)
        XCTAssertEqual(original.edge, .right)
        XCTAssertEqual(original.alongFraction, 0.27, accuracy: 0.001)
        XCTAssertEqual(try Data(contentsOf: target), migratedBytes)

        let view = host.dockView
        let drag = try XCTUnwrap(view.backgroundDragDelegate)
        let local = try XCTUnwrap(stride(from: 4.0, to: view.bounds.height, by: 4).lazy.flatMap { y in
            stride(from: 4.0, to: view.bounds.width, by: 4).map { CGPoint(x: $0, y: y) }
        }.first { drag.backgroundCanDrag(local: $0) })
        let down = CGPoint(x: original.frame.minX + local.x, y: original.frame.maxY - local.y)
        topology.pointer = down
        let arrival = ContinuousClock.now + .seconds(1)
        while !drag.beginBackgroundMove(local: local, global: down) {
            guard ContinuousClock.now < arrival else { return XCTFail("The restored widget must accept an ordinary face press") }
            try await Task.sleep(for: .milliseconds(10))
        }
        let destination = topology.b.usableFrame
        let end = CGPoint(x: destination.minX + 2, y: destination.midY)
        topology.pointer = end
        drag.updateBackgroundMove(global: end)
        XCTAssertEqual(host.edgePresentation?.placement?.displayID, topology.b.id)
        XCTAssertEqual(try Data(contentsOf: target), migratedBytes)
        drag.endBackgroundMove(global: end)
        drag.endBackgroundMove(global: end)
        let editor = app.settingsHost.application.editor
        try await waitForSettings(editor) {
            editor.snapshot?.revision == migrated.revision + 1 && !editor.isSaving
        }
        let landed = try XCTUnwrap(host.edgePresentation?.placement)
        let saved = await store.snapshot()
        let savedBytes = try Data(contentsOf: target)
        XCTAssertEqual(landed.displayID, topology.b.id)
        XCTAssertEqual(landed.edge, .left)
        XCTAssertEqual(saved.revision, migrated.revision + 1)
        XCTAssertEqual(saved.preferences.dockAlongFraction, landed.alongFraction, accuracy: 0.0001)
        XCTAssertNotEqual(savedBytes, migratedBytes)
        XCTAssertEqual(try Data(contentsOf: legacy), bytes)
        await app.composition.stop()

        let (reopened, reopenedStore) = try await launch()
        XCTAssertEqual(reopened.composition.dock.edgePresentation?.placement, landed)
        let retained = await reopenedStore.snapshot()
        XCTAssertEqual(retained.revision, 0, "Reconstruction starts a new in-memory revision")
        XCTAssertEqual(retained.preferences.dockAlongFraction, landed.alongFraction, accuracy: 0.0001)
        XCTAssertEqual(retained.preferences.dockDisplayID, topology.b.id)
        XCTAssertEqual(retained.preferences.dockEdge, .left)
        XCTAssertEqual(try Data(contentsOf: target), savedBytes)
        XCTAssertEqual(try Data(contentsOf: legacy), bytes)
    }

    func testD19NormalDragKeepsCornerClearanceAndAvoidsSystemDock() async throws {
        try await exerciseD19(nativePanels: false)
    }

    #if MODELPLAN_DOCK_NATIVE_JOURNEY
    func testD19NativePanelDragKeepsCornerClearanceAndAvoidsSystemDock() async throws {
        _ = NSApplication.shared
        try await exerciseD19(nativePanels: true)
    }
    #endif

    private func exerciseD19(nativePanels: Bool) async throws {
        let topology = DragTopology()
        let frame = CGRect(x: 0, y: 0, width: 1600, height: 900)
        let reservations: [(String, CGRect)] = [
            ("bottom", CGRect(x: 0, y: 72, width: 1600, height: 804)),
            ("left", CGRect(x: 72, y: 0, width: 1528, height: 876)),
            ("right", CGRect(x: 0, y: 0, width: 1528, height: 876)),
        ]
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("dock-reservations-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: profile) }
        defer { UserDefaults.standard.register(defaults: ["ModelPlanDockDragMode": 1]) }

        for mode in [1, 2] {
            UserDefaults.standard.register(defaults: ["ModelPlanDockDragMode": mode])
            for (reservation, available) in reservations {
                let display = DockDisplayArea(id: "A", frame: frame, visibleFrame: available)
                topology.active = [display]
                topology.pointer = CGPoint(x: available.midX, y: available.midY)
                let root = profile.appendingPathComponent("\(mode)-" + reservation)
                #if MODELPLAN_DOCK_NATIVE_JOURNEY
                if nativePanels { EngineRowsEntry.nativeJourneyProfile = root }
                defer { if nativePanels { EngineRowsEntry.nativeJourneyProfile = nil } }
                #endif
                let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
                let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
                    applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: store,
                    createsNativePanels: nativePanels, dockEnvironment: topology.read, activateSettings: {})
                addTeardownBlock { @MainActor in await app.composition.stop() }
                await app.prepare()
                app.allowDockPresentation()

                let host = app.composition.dock
                let editor = app.settingsHost.application.editor
                let panel: NSPanel?
                #if MODELPLAN_DOCK_NATIVE_JOURNEY
                panel = nativePanels ? try XCTUnwrap(host.nativePanel) : nil
                #else
                panel = nil
                #endif
                func send(_ type: NSEvent.EventType, at point: CGPoint, to panel: NSPanel) throws {
                    panel.sendEvent(try XCTUnwrap(NSEvent.mouseEvent(with: type,
                        location: panel.convertPoint(fromScreen: point), modifierFlags: [],
                        timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: panel.windowNumber,
                        context: nil, eventNumber: 1, clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1)))
                }
                let targets: [(DockEdge, CGPoint, Bool?)] = [
                    (.left, .init(x: available.minX + 2, y: available.minY + 14), false),
                    (.left, .init(x: available.minX + 2, y: available.maxY - 14), true),
                    (.right, .init(x: available.maxX - 2, y: available.minY + 14), false),
                    (.right, .init(x: available.maxX - 2, y: available.maxY - 14), true),
                    (.bottom, .init(x: available.minX + 14, y: available.minY + 2), false),
                    (.bottom, .init(x: available.maxX - 14, y: available.minY + 2), true),
                    (.bottom, .init(x: available.midX, y: available.midY), nil),
                ]
                for (edge, point, upperEnd) in targets {
                    let label = "Mode \(mode), system Dock \(reservation), \(edge), \(point)"
                    let view = host.dockView
                    let drag = try XCTUnwrap(view.backgroundDragDelegate, label)
                    let local = try XCTUnwrap(stride(from: 4.0, to: view.bounds.height, by: 4).lazy.flatMap { y in
                        stride(from: 4.0, to: view.bounds.width, by: 4).map { CGPoint(x: $0, y: y) }
                    }.first { drag.backgroundCanDrag(local: $0) }, label)
                    let start = try XCTUnwrap(host.edgePresentation?.paintedFrame, label)
                    let down = panel.map { $0.convertPoint(toScreen: view.convert(local, to: nil)) }
                        ?? CGPoint(x: start.minX + local.x, y: start.maxY - local.y)
                    topology.pointer = down
                    let revision = try XCTUnwrap(editor.snapshot?.revision)
                    if let panel {
                        XCTAssertTrue(panel.isVisible, label)
                        // A new press must arrive after the normal reveal guard.
                        try await Task.sleep(for: .milliseconds(320))
                        try send(.leftMouseDown, at: down, to: panel)
                        topology.pointer = point
                        try send(.leftMouseDragged, at: point, to: panel)
                        XCTAssertTrue(panel.isVisible, label)
                        XCTAssertEqual(editor.snapshot?.revision, revision, label)
                        try send(.leftMouseUp, at: point, to: panel)
                    } else {
                        let arrival = ContinuousClock.now + .seconds(1)
                        while !drag.beginBackgroundMove(local: local, global: down) {
                            guard ContinuousClock.now < arrival else { return XCTFail("Could not press the widget: " + label) }
                            try await Task.sleep(for: .milliseconds(10))
                        }
                        topology.pointer = point
                        drag.updateBackgroundMove(global: point)
                        XCTAssertEqual(editor.snapshot?.revision, revision, label)
                        drag.endBackgroundMove(global: point)
                    }
                    try await waitForSettings(editor) {
                        editor.snapshot?.revision == revision + 1 && !editor.isSaving
                    }
                    let observed = try XCTUnwrap(host.edgePresentation?.placement, label)
                    let saved = await store.snapshot()
                    XCTAssertEqual(observed.edge, edge, label)
                    XCTAssertEqual(observed.displayID, display.id, label)
                    XCTAssertEqual(saved.preferences.dockDisplayID, display.id, label)
                    XCTAssertEqual(saved.preferences.dockAlongFraction, observed.alongFraction, accuracy: 0.0001, label)
                    let painted = try XCTUnwrap(host.edgePresentation?.paintedFrame, label)
                    XCTAssertEqual(painted, observed.frame, label)
                    XCTAssertTrue(available.contains(painted), label)
                    if let panel {
                        XCTAssertTrue(panel.isVisible, label)
                        XCTAssertTrue(available.contains(panel.frame), label)
                        XCTAssertEqual(panel.frame.minX, painted.minX, accuracy: 1, label)
                        XCTAssertEqual(panel.frame.maxX, painted.maxX, accuracy: 1, label)
                        XCTAssertEqual(panel.frame.minY, painted.minY, accuracy: 1, label)
                        XCTAssertEqual(panel.frame.maxY, painted.maxY, accuracy: 1, label)
                    }
                    switch edge {
                    case .left: XCTAssertEqual(painted.minX, available.minX, accuracy: 0.001, label)
                    case .right: XCTAssertEqual(painted.maxX, available.maxX, accuracy: 0.001, label)
                    case .bottom: XCTAssertEqual(painted.minY, available.minY, accuracy: 0.001, label)
                    case .top: XCTFail(label)
                    }
                    if let upperEnd {
                        let occupied = painted.union(observed.sliverFrame)
                        let clearance = edge == .bottom
                            ? (upperEnd ? available.maxX - occupied.maxX : occupied.minX - available.minX)
                            : (upperEnd ? available.maxY - occupied.maxY : occupied.minY - available.minY)
                        XCTAssertEqual(clearance, 24, accuracy: 0.001, label)
                    }
                }
                await app.composition.stop()
            }
        }
    }

    #if MODELPLAN_DOCK_REAL_CONTEXT_JOURNEY
    func testD09RealServerPublicationAndTopologyCannotMoveTheHeldWidget() async throws {
        let helper = URL(fileURLWithPath: try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_DOCK_TEST_CLI"]))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: helper.path))
        let modeKey = "ModelPlanDockDragMode"
        let originalMode = UserDefaults.standard.integer(forKey: modeKey)
        defer { UserDefaults.standard.register(defaults: [modeKey: originalMode]) }

        for mode in [1, 2] {
            UserDefaults.standard.register(defaults: [modeKey: mode])
            XCTAssertEqual(UserDefaults.standard.integer(forKey: modeKey), mode)
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("dock-d09-" + UUID().uuidString)
            let config = root.appendingPathComponent(".config/modelplan")
            try FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)
            addTeardownBlock { try? FileManager.default.removeItem(at: root) }
            let environment = ["HOME": root.path, "TMPDIR": root.path, "PATH": "/usr/bin:/bin", "LANG": "C"]
            let seed = Process()
            seed.executableURL = helper
            seed.arguments = ["consent", "init", "--json"]
            seed.environment = environment
            seed.standardInput = FileHandle.nullDevice
            seed.standardOutput = FileHandle.nullDevice
            seed.standardError = FileHandle.nullDevice
            try seed.run()
            let seedDeadline = ContinuousClock.now + .seconds(5)
            while seed.isRunning && ContinuousClock.now < seedDeadline {
                try await Task.sleep(for: .milliseconds(20))
            }
            if seed.isRunning {
                seed.terminate()
                return XCTFail("Temporary consent initialization timed out")
            }
            XCTAssertEqual(seed.terminationStatus, 0)

            let plan = "synthetic-d09", iso = ISO8601DateFormatter()
            func writeReading(_ percent: Int) throws {
                let now = Date()
                let fixture: [String: Any] = ["schemaVersion": 1, "plans": [["planId": plan]], "windows": [[
                    "planId": plan, "kind": "five_hour", "remainingPercent": percent, "resetMode": "rolling",
                    "observedAt": iso.string(from: now.addingTimeInterval(-10)),
                    "resetAt": iso.string(from: now.addingTimeInterval(7_200)),
                ]]]
                let bytes = try JSONSerialization.data(withJSONObject: fixture)
                try bytes.write(to: config.appendingPathComponent("local.json"), options: .atomic)
            }
            try writeReading(40)

            let topology = DragTopology()
            let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
            _ = try await store.update {
                $0.dockDisplayID = "A"
                $0.dockEdge = .right
                $0.autoHide = false
                $0.followActiveDisplay = true
            }
            let storedURL = root.appendingPathComponent("ModelPlan/settings.json")
            let app = EngineRowsEntry.make(configuration: .init(executableURL: helper, applicationVersion: "synthetic-d09",
                allowedEnvironment: environment, offline: true, readOnly: true), settingsStore: store,
                createsNativePanels: false, bundleURL: root.appendingPathComponent("Synthetic.app"),
                dockEnvironment: topology.read, activateSettings: {})
            addTeardownBlock { @MainActor in await app.composition.stop() }
            await app.prepare()
            app.allowDockPresentation()
            let delivery = try await app.composition.client.start()
            _ = try await app.composition.client.subscribeRows(timeout: .seconds(4))
            let host = app.composition.dock, view = host.dockView
            func serverReading() -> Double? {
                app.composition.store.snapshot.rows?.projection.rows.first { $0.id == "declared:" + plan }?
                    .accounts.first?.windows.first?.remainingPercent
            }
            XCTAssertEqual(serverReading(), 40)
            let before = await store.snapshot()
            let bytes = try Data(contentsOf: storedURL)
            let initial = try XCTUnwrap(host.edgePresentation?.placement)
            let drag = try XCTUnwrap(view.backgroundDragDelegate)
            let local = try XCTUnwrap(stride(from: 4.0, to: view.bounds.height, by: 4).lazy.flatMap { y in
                stride(from: 4.0, to: view.bounds.width, by: 4).map { CGPoint(x: $0, y: y) }
            }.first { drag.backgroundCanDrag(local: $0) })
            let down = CGPoint(x: initial.frame.minX + local.x, y: initial.frame.maxY - local.y)
            topology.pointer = down
            let arrival = ContinuousClock.now + .seconds(1)
            var captured = drag.beginBackgroundMove(local: local, global: down)
            while !captured && ContinuousClock.now < arrival {
                try await Task.sleep(for: .milliseconds(20))
                captured = drag.beginBackgroundMove(local: local, global: down)
            }
            guard captured else { return XCTFail("Mode \(mode) did not capture the actual host's background") }

            let destination = topology.b.usableFrame
            let held = CGPoint(x: destination.maxX - 15, y: destination.midY - 60)
            topology.pointer = held
            drag.updateBackgroundMove(global: held)
            let carried = try XCTUnwrap(host.edgePresentation?.paintedFrame)
            XCTAssertEqual(host.edgePresentation?.placement?.displayID, topology.b.id)
            XCTAssertTrue(drag.isBackgroundMoving)

            // The topology/follow sample sees C, with no new captured drag event.
            // Meanwhile a real app-server publication replaces the declared reading.
            topology.active = [topology.b, topology.c]
            topology.pointer = CGPoint(x: topology.c.frame.midX, y: topology.c.frame.midY)
            NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
            host.refreshPresence()
            try writeReading(70)
            let published = ContinuousClock.now + .seconds(6)
            while serverReading() != 70 && ContinuousClock.now < published {
                XCTAssertEqual(host.edgePresentation?.paintedFrame, carried, "Mode \(mode) jumped while held")
                XCTAssertTrue(drag.isBackgroundMoving, "Mode \(mode) lost the held transaction")
                try await Task.sleep(for: .milliseconds(20))
            }
            XCTAssertEqual(serverReading(), 70)
            XCTAssertEqual(app.composition.store.snapshot.delivery, delivery)
            XCTAssertEqual(host.edgePresentation?.paintedFrame, carried)
            XCTAssertTrue(drag.isBackgroundMoving)
            let whileHeld = await store.snapshot()
            XCTAssertEqual(whileHeld.revision, before.revision)
            XCTAssertEqual(try Data(contentsOf: storedURL), bytes)

            let next = CGPoint(x: held.x, y: held.y + 80)
            topology.pointer = next
            drag.updateBackgroundMove(global: next)
            let resumed = try XCTUnwrap(host.edgePresentation?.paintedFrame)
            XCTAssertTrue(destination.insetBy(dx: -1, dy: -1).contains(resumed))
            XCTAssertEqual(resumed.midY - carried.midY, 80, accuracy: 1, "Mode \(mode) must follow the next captured event")
            drag.endBackgroundMove(global: next)
            let editor = app.settingsHost.application.editor
            try await waitForSettings(editor) { editor.snapshot?.preferences.dockDisplayID == topology.b.id && !editor.isSaving }
            let after = await store.snapshot()
            XCTAssertEqual(after.revision, before.revision + 1)
            XCTAssertEqual(after.preferences.dockEdge, .right)
            await app.composition.stop()
        }
    }
    #endif

    func testD06NormalDropsWriteOnceAndRelaunchAtEachDestination() async throws {
        let topology = DragTopology()
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("dock-drag-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: profile) }
        func launch() async throws -> EngineDockMenuApplication {
            let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
            let app = EngineRowsEntry.make(configuration: .init(executableURL: profile.appendingPathComponent("not-launched"),
                applicationVersion: "drag-persistence", allowedEnvironment: [:]), settingsStore: store,
                createsNativePanels: false, dockEnvironment: topology.read, activateSettings: {})
            addTeardownBlock { @MainActor in await app.composition.stop() }
            await app.prepare()
            app.allowDockPresentation()
            return app
        }

        let a = topology.a.usableFrame, b = topology.b.usableFrame, c = topology.c.usableFrame
        let targets: [(DockDisplayArea, DockEdge, CGPoint)] = [
            (topology.b, .left, CGPoint(x: b.minX + 2, y: b.midY)),
            (topology.c, .bottom, CGPoint(x: c.midX, y: c.minY + 2)),
            (topology.a, .bottom, CGPoint(x: a.midX, y: a.minY + 2)),
        ]
        var app = try await launch()
        for (destination, edge, point) in targets {
            let host = app.composition.dock, view = host.dockView
            let editor = app.settingsHost.application.editor
            let before = try XCTUnwrap(editor.snapshot)
            let presented = try XCTUnwrap(host.edgePresentation?.paintedFrame)
            let drag = try XCTUnwrap(view.backgroundDragDelegate)
            let local = try XCTUnwrap(stride(from: 4.0, to: view.bounds.height, by: 4).lazy.flatMap { y in
                stride(from: 4.0, to: view.bounds.width, by: 4).map { CGPoint(x: $0, y: y) }
            }.first { drag.backgroundCanDrag(local: $0) })
            let down = CGPoint(x: presented.minX + local.x, y: presented.maxY - local.y)
            topology.pointer = down
            let arrival = ContinuousClock.now + .seconds(1)
            var captured = drag.beginBackgroundMove(local: local, global: down)
            while !captured && ContinuousClock.now < arrival {
                try await Task.sleep(for: .milliseconds(20))
                captured = drag.beginBackgroundMove(local: local, global: down)
            }
            XCTAssertTrue(captured)
            guard captured else { return }
            topology.pointer = point
            drag.updateBackgroundMove(global: point)
            XCTAssertEqual(editor.snapshot?.revision, before.revision)
            drag.endBackgroundMove(global: point)
            drag.endBackgroundMove(global: point)
            try await waitForSettings(editor) {
                editor.snapshot?.preferences.dockDisplayID == destination.id && !editor.isSaving
            }
            let saved = await app.foundationStore.snapshot()
            XCTAssertEqual(saved.revision, before.revision + 1)
            let landed = try XCTUnwrap(host.edgePresentation?.placement)
            XCTAssertEqual(landed.edge, edge)
            XCTAssertEqual(landed.displayID, destination.id)
            XCTAssertEqual(saved.preferences.dockAlongFraction, landed.alongFraction, accuracy: 0.0001)
            if edge == .bottom { XCTAssertEqual(landed.frame.minY, destination.usableFrame.minY, accuracy: 0.001) }
            await app.composition.stop()
            app = try await launch()
            let restored = try XCTUnwrap(app.composition.dock.edgePresentation?.placement)
            XCTAssertEqual(restored.displayID, destination.id)
            XCTAssertEqual(restored.edge, edge)
            XCTAssertEqual(restored.alongFraction, saved.preferences.dockAlongFraction, accuracy: 0.0001)
            XCTAssertEqual(restored.frame, landed.frame)

            if destination.id == topology.c.id {
                let restoredHost = app.composition.dock
                let beforeHotPlug = await app.foundationStore.snapshot()
                topology.active = [topology.a, topology.b]
                NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
                restoredHost.refreshPresence()
                XCTAssertEqual(restoredHost.edgePresentation?.placement?.displayID, topology.a.id, "D-10 fallback")
                let unplugged = await app.foundationStore.snapshot()
                XCTAssertEqual(unplugged.revision, beforeHotPlug.revision)
                XCTAssertEqual(unplugged.preferences.dockDisplayID, topology.c.id)

                topology.active = [topology.a, topology.b, topology.c]
                NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
                restoredHost.refreshPresence()
                XCTAssertEqual(restoredHost.edgePresentation?.placement?.displayID, topology.c.id, "D-10 return")
                XCTAssertEqual(restoredHost.edgePresentation?.placement?.frame, restored.frame)
                let reconnected = await app.foundationStore.snapshot()
                XCTAssertEqual(reconnected.revision, beforeHotPlug.revision)
                XCTAssertEqual(reconnected.preferences.dockDisplayID, beforeHotPlug.preferences.dockDisplayID)
                XCTAssertEqual(reconnected.preferences.dockEdge, beforeHotPlug.preferences.dockEdge)
                XCTAssertEqual(reconnected.preferences.dockAlongFraction, beforeHotPlug.preferences.dockAlongFraction)
            }
        }
    }
}

#if MODELPLAN_DOCK_NATIVE_JOURNEY
@MainActor final class DockPulseDragNativeTests: XCTestCase {
    func testD11EscapeDiscardsNativeNozzleReorderBeforeRelease() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dock-escape-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        _ = try await settings.update { $0.autoHide = false; $0.dockEdge = .bottom }
        let wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-02T00:00:00Z"))
        let snapshot = try HostPairedProjectionTests.rows(weekly: 75, secondWeekly: 55)
        EngineRowsEntry.nativeJourneyProfile = root
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: true,
            dockEnvironment: normalEntryTestEnvironment, deadlineNow: { wall },
            makeClient: { _, store in EntrySyntheticClient(store: store, rows: snapshot) }, activateSettings: {})
        addTeardownBlock { @MainActor in
            await app.stopNativeDockJourney()
            EngineRowsEntry.nativeJourneyProfile = nil
        }
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        let dock = app.composition.dock
        let panel = try XCTUnwrap(dock.nativePanel as? PulseDockPanel)
        let view = try XCTUnwrap(panel.contentView?.subviews.compactMap { $0 as? DockInstrumentView }.first)
        let controller = try XCTUnwrap(dock.interactionControllerForChecks)
        let first = try XCTUnwrap(view.interactionAnchor("aaaaaaaaaaaaaaaa"))
        let second = try XCTUnwrap(view.interactionAnchor("bbbbbbbbbbbbbbbb"))
        let before = await settings.snapshot()
        let frame = panel.frame
        let down = panel.convertPoint(toScreen: view.convert(CGPoint(x: first.midX, y: first.midY), to: nil))
        let destination = panel.convertPoint(toScreen: view.convert(CGPoint(x: second.midX, y: second.midY), to: nil))
        var pointer = down
        panel.pointerLocation = { pointer }
        func mouse(_ type: NSEvent.EventType, at point: CGPoint) throws {
            pointer = point
            let event = try XCTUnwrap(NSEvent.mouseEvent(with: type, location: panel.convertPoint(fromScreen: point),
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: panel.windowNumber,
                context: nil, eventNumber: 1, clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1))
            panel.sendEvent(event)
        }
        // Establish capture after the ordinary arrival guard, without bypassing pointer routing.
        let deadline = ContinuousClock.now + .seconds(2)
        while !controller.hasCapture && ContinuousClock.now < deadline {
            try mouse(.leftMouseDown, at: down)
            if !controller.hasCapture {
                try mouse(.leftMouseUp, at: down)
                try await Task.sleep(for: .milliseconds(25))
            }
        }
        XCTAssertTrue(controller.hasCapture)
        try mouse(.leftMouseDragged, at: destination)
        XCTAssertNotNil(controller.presentation?.reorder)
        XCTAssertEqual(panel.frame, frame)

        let escape = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: panel.windowNumber, context: nil,
            characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53))
        panel.sendEvent(escape)
        XCTAssertFalse(controller.hasCapture)
        XCTAssertNil(controller.presentation?.reorder)
        try mouse(.leftMouseUp, at: destination)
        XCTAssertEqual(panel.frame, frame)
        XCTAssertFalse(app.settingsHost.application.editor.isSaving)
        let after = await settings.snapshot()
        XCTAssertEqual(after.revision, before.revision)
    }

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
