// SPDX-License-Identifier: MIT
#if MODELPLAN_DOCK_REAL_CONTEXT_JOURNEY
import AppKit
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanEngineClient
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor private final class CarryComparisonTopology {
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

@MainActor final class DockRenderedCarryComparisonTests: XCTestCase {
    func testD04DetachedRealServerCarriesRenderedWidgetAcrossDisplays() async throws {
        try await exercise(releaseOnMixedScale: false)
    }

    func testD05DetachedRealServerRerasterizesAndSavesOnTheDestination() async throws {
        try await exercise(releaseOnMixedScale: true)
    }

    private func exercise(releaseOnMixedScale: Bool) async throws {
        let path = try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_D04_CAPTURE_DIR"])
        let output = URL(fileURLWithPath: path, isDirectory: true)
        let helper = URL(fileURLWithPath: try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_DOCK_TEST_CLI"]))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: helper.path))
        let modeKey = "ModelPlanDockDragMode"
        let originalMode = UserDefaults.standard.integer(forKey: modeKey)
        defer { UserDefaults.standard.register(defaults: [modeKey: originalMode]) }

        for mode in [1, 2] {
            UserDefaults.standard.register(defaults: [modeKey: mode])
            XCTAssertEqual(UserDefaults.standard.integer(forKey: modeKey), mode)
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("dock-d04-" + UUID().uuidString)
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

            let plan = "synthetic-d04", iso = ISO8601DateFormatter()
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

            let topology = CarryComparisonTopology()
            let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
            _ = try await store.update {
                $0.dockDisplayID = "A"
                $0.dockEdge = .right
                $0.autoHide = false
            }
            let storedURL = root.appendingPathComponent("ModelPlan/settings.json")
            let app = EngineRowsEntry.make(configuration: .init(executableURL: helper, applicationVersion: "synthetic-d04",
                allowedEnvironment: environment, offline: true, readOnly: true), settingsStore: store,
                createsNativePanels: false, bundleURL: root.appendingPathComponent("Synthetic.app"),
                dockEnvironment: topology.read, activateSettings: {})
            addTeardownBlock { @MainActor in await app.composition.stop() }
            await app.prepare()
            app.allowDockPresentation()
            _ = try await app.composition.client.start()
            _ = try await app.composition.client.subscribeRows(timeout: .seconds(4))
            let host = app.composition.dock, view = host.dockView
            func serverReading() -> Double? {
                app.composition.store.snapshot.rows?.projection.rows.first { $0.id == "declared:" + plan }?
                    .accounts.first?.windows.first?.remainingPercent
            }
            XCTAssertEqual(serverReading(), 40)
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

            if releaseOnMixedScale {
                func capture(_ name: String, at display: DockDisplayArea, moving: Bool) throws {
                    let current = try XCTUnwrap(host.edgePresentation)
                    let frame = try XCTUnwrap(current.paintedFrame)
                    let raster = try XCTUnwrap(host.detachedRenderedCarryViewForChecks?.presentedImageForChecks)
                    XCTAssertEqual(current.state, .expanded)
                    XCTAssertEqual(current.moving, moving)
                    XCTAssertEqual(current.placement?.displayID, display.id)
                    XCTAssertEqual(current.placement?.edge, .right)
                    XCTAssertTrue(display.usableFrame.insetBy(dx: -0.01, dy: -0.01).contains(frame))
                    XCTAssertEqual(CGFloat(raster.width), frame.width * CGFloat(display.backingScale), accuracy: 1)
                    XCTAssertEqual(CGFloat(raster.height), frame.height * CGFloat(display.backingScale), accuracy: 1)
                    XCTAssertEqual(serverReading(), 40)
                    let prefix = "mode-\(mode)-" + name
                    try XCTUnwrap(NSBitmapImageRep(cgImage: raster).representation(using: .png, properties: [:]))
                        .write(to: output.appendingPathComponent(prefix + ".png"))
                    let report: [String: Any] = [
                        "display": display.id, "edge": "right", "frame": NSStringFromRect(frame),
                        "scale": display.backingScale, "pixels": [raster.width, raster.height],
                    ]
                    try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                        .write(to: output.appendingPathComponent(prefix + ".json"))
                }
                let before = await store.snapshot()
                try capture("a-2x-pressed", at: topology.a, moving: false)
                let destination = topology.b.usableFrame
                let target = CGPoint(x: destination.maxX - 12, y: destination.midY)
                topology.pointer = target
                drag.updateBackgroundMove(global: target)
                try capture("b-1x-held", at: topology.b, moving: true)
                XCTAssertEqual(try Data(contentsOf: storedURL), bytes)

                drag.endBackgroundMove(global: target)
                let editor = app.settingsHost.application.editor
                try await waitForSettings(editor) {
                    editor.snapshot?.preferences.dockDisplayID == topology.b.id && !editor.isSaving
                }
                let after = await store.snapshot()
                XCTAssertEqual(after.revision, before.revision + 1)
                XCTAssertEqual(after.preferences.dockEdge, .right)
                XCTAssertEqual(host.edgePresentation?.placement?.alongFraction,
                               after.preferences.dockAlongFraction)
                try capture("b-1x-released", at: topology.b, moving: false)
                await app.composition.stop()
                continue
            }

            let itinerary: [(String, DockDisplayArea, CGPoint)] = [
                ("a-rest", topology.a, down),
                ("b-centre", topology.b, CGPoint(x: topology.b.usableFrame.midX, y: topology.b.usableFrame.midY)),
                ("c-centre", topology.c, CGPoint(x: topology.c.usableFrame.midX, y: topology.c.usableFrame.midY)),
                ("c-bottom", topology.c, CGPoint(x: topology.c.usableFrame.midX, y: topology.c.usableFrame.minY + 12)),
            ]
            for (index, sample) in itinerary.enumerated() {
                let (name, target, point) = sample
                if index > 0 {
                    topology.pointer = point
                    drag.updateBackgroundMove(global: point)
                }
                let presented = host.edgePresentation
                let raster = host.detachedRenderedCarryViewForChecks?.presentedImageForChecks
                let namePrefix = "mode-\(mode)-" + name
                var observation: [String: Any] = [
                    "step": name, "target": target.id, "pointer": NSStringFromPoint(point),
                    "state": presented.map { String(describing: $0.state) } ?? "absent",
                    "moving": presented?.moving ?? false, "remainingPercent": serverReading() ?? -1,
                ]
                observation["display"] = presented?.placement?.displayID
                observation["edge"] = presented?.placement.map { String(describing: $0.edge) }
                if let frame = presented?.paintedFrame { observation["paintedFrame"] = NSStringFromRect(frame) }
                if let raster, presented?.paintedFrame != nil {
                    let png = try XCTUnwrap(NSBitmapImageRep(cgImage: raster).representation(using: .png, properties: [:]))
                    try png.write(to: output.appendingPathComponent(namePrefix + ".png"))
                    observation["pixels"] = [raster.width, raster.height]
                }
                try JSONSerialization.data(withJSONObject: observation, options: [.prettyPrinted, .sortedKeys])
                    .write(to: output.appendingPathComponent(namePrefix + ".json"))
                XCTAssertEqual(presented?.state, .expanded, namePrefix)
                XCTAssertEqual(presented?.placement?.displayID, target.id, namePrefix)
                XCTAssertTrue(presented?.paintedFrame.map { target.usableFrame.insetBy(dx: -0.01, dy: -0.01).contains($0) } ?? false, namePrefix)
                XCTAssertNotNil(raster, namePrefix)
                XCTAssertEqual(try Data(contentsOf: storedURL), bytes, "Holding the gesture must not save")
                if index > 0 { XCTAssertEqual(presented?.moving, true, namePrefix) }
                if name == "c-bottom" { XCTAssertEqual(presented?.placement?.edge, .bottom, namePrefix) }
            }
            drag.cancelBackgroundMove()
            XCTAssertEqual(host.edgePresentation?.paintedFrame, initial.frame)
            XCTAssertEqual(try Data(contentsOf: storedURL), bytes)
            await app.composition.stop()
        }
    }
}
#endif
