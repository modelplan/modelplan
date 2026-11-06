// SPDX-License-Identifier: MIT
#if MODELPLAN_DOCK_NATIVE_JOURNEY && MODELPLAN_DOCK_REAL_SPACES_JOURNEY
import AppKit
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanShell
import ModelPlanSettings
import XCTest
@testable import ModelPlanAppIntegration

/// Operator-driven. Run only during an admitted native session with the required display arrangement.
@MainActor final class DockRealSpacesJourneyTests: XCTestCase {
    @MainActor private final class SpaceEvents {
        var count = 0
    }

    private func makeProfile(displayID: String, edge: SettingsDockEdge, declaredQuotas: [Int] = [],
                             autoHide: Bool = false, along: Double = 0.62,
                             cockpitEntryEnabled: Bool? = nil) async throws
        -> (EngineDockMenuApplication, SettingsStore, URL) {
        let executable = try reviewedExecutable()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dock-device-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        let environment = deviceEnvironment(root)
        let seed = Process()
        seed.executableURL = executable
        seed.arguments = ["consent", "init", "--json"]
        seed.environment = environment
        seed.standardInput = FileHandle.nullDevice
        seed.standardOutput = FileHandle.nullDevice
        seed.standardError = FileHandle.nullDevice
        try seed.run()
        let seedDeadline = ContinuousClock.now + .seconds(5)
        while seed.isRunning && ContinuousClock.now < seedDeadline { try await Task.sleep(for: .milliseconds(20)) }
        if seed.isRunning {
            seed.terminate()
            throw CocoaError(.fileReadUnknown, userInfo: [NSLocalizedDescriptionKey: "Temporary consent initialization timed out"])
        }
        guard seed.terminationStatus == 0 else {
            throw CocoaError(.fileReadUnknown, userInfo: [NSLocalizedDescriptionKey: "Temporary consent initialization failed"])
        }

        if !declaredQuotas.isEmpty {
            let directory = root.appendingPathComponent(".config/modelplan")
            let now = Date(), iso = ISO8601DateFormatter()
            let ids = declaredQuotas.indices.map { "synthetic-d05-\($0)" }
            let plans = ids.map { ["planId": $0] }
            let windows: [[String: Any]] = zip(ids, declaredQuotas).map { id, remaining in
                ["planId": id, "kind": "five_hour", "remainingPercent": remaining, "resetMode": "rolling",
                 "observedAt": iso.string(from: now.addingTimeInterval(-15)),
                 "resetAt": iso.string(from: now.addingTimeInterval(7_200))]
            }
            try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "plans": plans, "windows": windows])
                .write(to: directory.appendingPathComponent("local.json"), options: .atomic)
        }
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        _ = try await store.update {
            $0.autoHide = autoHide
            $0.followActiveDisplay = false
            $0.dockDisplayID = displayID
            $0.dockEdge = edge
            $0.dockAlongFraction = along
        }
        return (makeDeviceApplication(root: root, executable: executable, store: store,
                                      cockpitEntryEnabled: cockpitEntryEnabled), store,
                root.appendingPathComponent("ModelPlan/settings.json"))
    }

    private func reviewedExecutable() throws -> URL {
        let executable = URL(fileURLWithPath: try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_DOCK_TEST_CLI"]))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: executable.path))
        return executable
    }

    private func deviceEnvironment(_ root: URL) -> [String: String] {
        ["HOME": root.path, "TMPDIR": root.path, "PATH": "/usr/bin:/bin", "LANG": "C"]
    }

    private func makeDeviceApplication(root: URL, executable: URL, store: SettingsStore,
                                       registerTeardown: Bool = true,
                                       cockpitEntryEnabled: Bool? = nil) -> EngineDockMenuApplication {
        EngineRowsEntry.nativeJourneyProfile = root
        let app = EngineRowsEntry.make(configuration: .init(executableURL: executable, applicationVersion: "synthetic-dock-device",
            allowedEnvironment: deviceEnvironment(root), offline: true, readOnly: true), settingsStore: store,
            createsNativePanels: true, bundleURL: root.appendingPathComponent("Synthetic.app"),
            cockpitEntryEnabled: cockpitEntryEnabled, activateSettings: {})
        if registerTeardown {
            addTeardownBlock { @MainActor in
                await app.stopNativeDockJourney()
                EngineRowsEntry.nativeJourneyProfile = nil
            }
        }

        return app
    }

    private func wait(_ duration: Duration, until condition: () -> Bool) async throws -> Bool {
        let end = ContinuousClock.now + duration
        while !condition() && ContinuousClock.now < end { try await Task.sleep(for: .milliseconds(20)) }
        return condition()
    }

    private func announce(_ scenario: String, _ instruction: String) {
        FileHandle.standardOutput.write(Data((scenario + ": " + instruction + "\n").utf8))
    }

    @MainActor private final class PointerEvents {
        var down = 0, drag = 0, up = 0
    }

    func testD04PhysicalThreeDisplayStrongSnap() async throws { try await exerciseThreeDisplayCarry(mode: 1) }
    func testD04PhysicalThreeDisplayAlwaysAttached() async throws { try await exerciseThreeDisplayCarry(mode: 2) }

    private func exerciseThreeDisplayCarry(mode: Int) async throws {
        _ = NSApplication.shared
        let topology = DockDisplayTopology.system()
        let a = try XCTUnwrap(topology.main)
        let others = topology.displays.filter { $0.id != a.id && !$0.frame.intersects(a.frame) }.sorted {
            $0.frame.midX == $1.frame.midX ? $0.frame.midY < $1.frame.midY : $0.frame.midX < $1.frame.midX
        }
        let b = try XCTUnwrap(others.first, "D-04 needs three real non-mirrored displays")
        let c = try XCTUnwrap(others.dropFirst().first { !$0.frame.intersects(b.frame) },
                              "D-04 needs a distinct third display")
        let modeKey = "ModelPlanDockDragMode"
        let originalMode = UserDefaults.standard.integer(forKey: modeKey)
        UserDefaults.standard.register(defaults: [modeKey: mode])
        defer { UserDefaults.standard.register(defaults: [modeKey: originalMode]) }
        guard UserDefaults.standard.integer(forKey: modeKey) == mode else {
            return XCTFail("An explicit setting overrides the isolated test mode")
        }

        let (app, store, storedURL) = try await makeProfile(displayID: a.id, edge: .right, declaredQuotas: [72, 53, 38])
        await app.prepare()
        XCTAssertNil(app.loginServiceAdapter)
        XCTAssertNil(app.notificationAuthorizationService)
        app.allowDockPresentation()
        await app.composition.start()
        let dock = app.composition.dock
        let panel = try XCTUnwrap(dock.nativePanel as? PulseDockPanel)
        let ready = try await wait(.seconds(5)) {
            let values = Set(dock.dockView.presentedReadingsForChecks.values.compactMap(\.remainingPercent))
            return panel.isVisible && panel.occlusionState.contains(.visible) &&
                dock.edgePresentation?.placement?.displayID == a.id && values == [72, 53, 38]
        }
        guard ready else { return XCTFail("The real widget must begin on A/right with all synthetic readings") }
        let savedBefore = await store.snapshot()
        let bytes = try Data(contentsOf: storedURL)
        let events = PointerEvents()
        let previousInput = panel.receivedInput
        panel.receivedInput = { type, _ in
            switch type {
            case .leftMouseDown: events.down += 1
            case .leftMouseDragged: events.drag += 1
            case .leftMouseUp: events.up += 1
            default: break
            }
        }
        defer { panel.receivedInput = previousInput }
        let previousPlacement = dock.onPlacementObserved
        var observedFrames = 0, invalidFrames = 0
        dock.onPlacementObserved = { placement, recovering in
            previousPlacement?(placement, recovering)
            guard dock.edgePresentation?.moving == true, events.up == 0 else { return }
            observedFrames += 1
            guard let placement,
                  let display = topology.display(placement.displayID), panel.isVisible,
                  panel.level == .statusBar,
                  display.usableFrame.insetBy(dx: -1, dy: -1).contains(panel.frame) else {
                invalidFrames += 1
                return
            }
        }
        defer { dock.onPlacementObserved = previousPlacement }

        func holdAtCentre(_ display: DockDisplayArea, role: String) async throws -> Bool {
            let centre = display.usableFrame.insetBy(dx: display.usableFrame.width * 0.35,
                                                    dy: display.usableFrame.height * 0.35)
            announce("D-04 mode \(mode)", "Hold the drag near \(role)'s centre")
            return try await wait(.seconds(40)) {
                events.down > 0 && events.drag > 0 && events.up == 0 &&
                    centre.contains(NSEvent.mouseLocation) &&
                    dock.edgePresentation?.moving == true &&
                    dock.edgePresentation?.placement?.displayID == display.id &&
                    panel.isVisible && panel.occlusionState.contains(.visible)
            }
        }

        announce("D-04 mode \(mode)", "A is the primary display; B and C are the remaining displays ordered left to right")
        announce("D-04 mode \(mode)", "Press the widget body on A/right and keep holding until the release prompt")
        for (display, role) in [(b, "B"), (c, "C")] {
            guard try await holdAtCentre(display, role: role) else {
                return XCTFail("The held native widget did not reach \(role)'s centre")
            }
            let carried = try XCTUnwrap(dock.edgePresentation)
            if mode == 1 {
                XCTAssertNotEqual(carried.paintedFrame, carried.placement?.frame, "Strong snap floats at display centre")
                XCTAssertTrue(panel.frame.contains(NSEvent.mouseLocation))
            } else {
                XCTAssertEqual(carried.paintedFrame, carried.placement?.frame, "Always-attached mode stays on a rail")
            }
            XCTAssertTrue(display.usableFrame.insetBy(dx: -1, dy: -1).contains(panel.frame))
            XCTAssertEqual(try Data(contentsOf: storedURL), bytes)
        }
        announce("D-04 mode \(mode)", "While still holding, move near C's bottom usable edge")
        let bottom = try await wait(.seconds(40)) {
            events.up == 0 && dock.edgePresentation?.moving == true &&
                dock.edgePresentation?.placement?.displayID == c.id &&
                dock.edgePresentation?.placement?.edge == .bottom &&
                abs(panel.frame.minY - c.usableFrame.minY) <= 1 && panel.isVisible
        }
        guard bottom else { return XCTFail("The held native widget did not attach to C/bottom") }
        XCTAssertGreaterThan(observedFrames, 0)
        XCTAssertEqual(invalidFrames, 0, "Every observed placement must keep a visible, frontmost, contained panel")
        XCTAssertEqual(try Data(contentsOf: storedURL), bytes)

        announce("D-04 mode \(mode)", "Release on C/bottom and capture the settled widget")
        let released = try await wait(.seconds(30)) {
            events.up > 0 && dock.edgePresentation?.moving == false &&
                app.settingsHost.application.editor.snapshot?.preferences.dockDisplayID == c.id
        }
        guard released else { return XCTFail("The real release did not save C") }
        let saved = await store.snapshot()
        XCTAssertEqual(saved.revision, savedBefore.revision + 1)
        XCTAssertEqual(saved.preferences.dockEdge, .bottom)
        XCTAssertEqual(panel.level, .floating)
        XCTAssertEqual(panel.frame.minY, c.visibleFrame.minY, accuracy: 1)
        try await Task.sleep(for: .seconds(5))
    }

    func testD05PhysicalMixedScaleStrongSnap() async throws { try await exerciseMixedScale(mode: 1) }
    func testD05PhysicalMixedScaleAlwaysAttached() async throws { try await exerciseMixedScale(mode: 2) }

    private func exerciseMixedScale(mode: Int) async throws {
        _ = NSApplication.shared
        let topology = DockDisplayTopology.system()
        let source = try XCTUnwrap(topology.displays.first { $0.backingScale == 2 }, "D-05 needs a real 2x display")
        let destination = try XCTUnwrap(topology.displays.first {
            $0.backingScale == 1 && !$0.frame.intersects(source.frame)
        }, "D-05 needs a separate, non-mirrored 1x display")
        let modeKey = "ModelPlanDockDragMode"
        let originalMode = UserDefaults.standard.integer(forKey: modeKey)
        UserDefaults.standard.register(defaults: [modeKey: mode])
        defer { UserDefaults.standard.register(defaults: [modeKey: originalMode]) }
        guard UserDefaults.standard.integer(forKey: modeKey) == mode else {
            return XCTFail("An explicit setting overrides the isolated test mode")
        }

        let (app, store, storedURL) = try await makeProfile(displayID: source.id, edge: .right, declaredQuotas: [72, 53, 38])
        await app.prepare()
        XCTAssertNil(app.loginServiceAdapter)
        XCTAssertNil(app.notificationAuthorizationService)
        app.allowDockPresentation()
        await app.composition.start()
        let dock = app.composition.dock
        let panel = try XCTUnwrap(dock.nativePanel as? PulseDockPanel)
        func instrument(in root: NSView) -> DockInstrumentView? {
            if let view = root as? DockInstrumentView { return view }
            return root.subviews.lazy.compactMap { instrument(in: $0) }.first
        }
        func currentInstrument() -> DockInstrumentView? {
            panel.contentView.flatMap { instrument(in: $0) }
        }
        func assertPixels(scale: Int, line: UInt = #line) throws {
            let view = try XCTUnwrap(currentInstrument(), line: line)
            let raster = try XCTUnwrap(view.renderedPixelSize, line: line)
            XCTAssertEqual(panel.backingScaleFactor, CGFloat(scale), line: line)
            XCTAssertEqual(raster.width, ceil(view.bounds.width * CGFloat(scale)), line: line)
            XCTAssertEqual(raster.height, ceil(view.bounds.height * CGFloat(scale)), line: line)
        }
        let ready = try await wait(.seconds(5)) {
            guard let view = currentInstrument() else { return false }
            let values = Set(view.presentedReadingsForChecks.values.compactMap(\.remainingPercent))
            return panel.isVisible && panel.occlusionState.contains(.visible) &&
                dock.edgePresentation?.placement?.displayID == source.id && values == [72, 53, 38]
        }
        guard ready else { return XCTFail("The real App must paint all three readings on the 2x display") }
        try assertPixels(scale: 2)
        let original = await store.snapshot()
        let originalBytes = try Data(contentsOf: storedURL)

        let events = PointerEvents()
        let previousInput = panel.receivedInput
        panel.receivedInput = { type, _ in
            switch type {
            case .leftMouseDown: events.down += 1
            case .leftMouseDragged: events.drag += 1
            case .leftMouseUp: events.up += 1
            default: break
            }
        }
        defer { panel.receivedInput = previousInput }
        announce("D-05 mode \(mode)", "Capture the 2x baseline, then drag the widget body to the 1x display and keep holding")
        let carried = try await wait(.seconds(45)) {
            events.down > 0 && events.drag > 0 && dock.edgePresentation?.moving == true &&
                dock.edgePresentation?.placement?.displayID == destination.id &&
                panel.backingScaleFactor == 1 && panel.isVisible && panel.occlusionState.contains(.visible)
        }
        guard carried else { return XCTFail("The native panel never carried to the 1x display while pressed") }
        try assertPixels(scale: 1)
        XCTAssertEqual(panel.level, .statusBar)
        XCTAssertTrue(destination.usableFrame.insetBy(dx: -1, dy: -1).contains(panel.frame))
        XCTAssertEqual(try Data(contentsOf: storedURL), originalBytes)

        announce("D-05 mode \(mode)", "Capture the held 1x widget, then release near the 1x display's bottom usable edge")
        let released = try await wait(.seconds(45)) {
            events.up > 0 && dock.edgePresentation?.moving == false &&
                dock.edgePresentation?.placement?.displayID == destination.id &&
                app.settingsHost.application.editor.snapshot?.preferences.dockDisplayID == destination.id
        }
        guard released else { return XCTFail("The native release did not save the actual 1x destination") }
        try assertPixels(scale: 1)
        let saved = await store.snapshot()
        XCTAssertEqual(saved.revision, original.revision + 1)
        XCTAssertEqual(saved.preferences.dockEdge, .bottom)
        XCTAssertEqual(panel.level, .floating)
        XCTAssertEqual(panel.frame.minY, destination.visibleFrame.minY, accuracy: 1)
        XCTAssertTrue(panel.isVisible && panel.occlusionState.contains(.visible))
        let savedBytes = try Data(contentsOf: storedURL)
        announce("D-05 mode \(mode)", "Capture the settled 1x crop at 100 percent within five seconds")
        try await Task.sleep(for: .seconds(5))
        XCTAssertEqual(try Data(contentsOf: storedURL), savedBytes)
    }

    @MainActor private final class LifecycleEvents {
        var screens = 0
        var sleeps = 0
        var wakes = 0
    }

    func testD06PhysicalStrongSnapDropsSaveOnceAndRestore() async throws { try await exercisePhysicalDrops(mode: 1) }
    func testD06PhysicalAlwaysAttachedDropsSaveOnceAndRestore() async throws { try await exercisePhysicalDrops(mode: 2) }

    private func exercisePhysicalDrops(mode: Int) async throws {
        _ = NSApplication.shared
        let modeKey = "ModelPlanDockDragMode"
        let originalMode = UserDefaults.standard.integer(forKey: modeKey)
        UserDefaults.standard.register(defaults: [modeKey: mode])
        defer { UserDefaults.standard.register(defaults: [modeKey: originalMode]) }
        guard UserDefaults.standard.integer(forKey: modeKey) == mode else {
            return XCTFail("An explicit setting overrides the isolated test mode")
        }
        let topology = DockDisplayTopology.system()
        let a = try XCTUnwrap(topology.main)
        guard a.visibleFrame.minY > a.frame.minY else {
            return XCTFail("D-06 requires the macOS Dock at A/bottom")
        }
        let b = try XCTUnwrap(topology.displays.first { candidate in
            abs(candidate.frame.minX - a.frame.maxX) <= 1 &&
                min(a.frame.maxY, candidate.frame.maxY) - max(a.frame.minY, candidate.frame.minY) > 0 &&
                abs(candidate.usableFrame.minX - candidate.frame.minX) <= 1
        }, "D-06 requires B on A's right with an unreserved shared edge")
        let c = try XCTUnwrap(topology.displays.first {
            $0.id != a.id && $0.id != b.id && !$0.frame.intersects(a.frame) && !$0.frame.intersects(b.frame)
        }, "D-06 requires a third, non-mirrored display")
        let quotas = [72, 53, 38]
        var (app, store, storedURL) = try await makeProfile(displayID: a.id, edge: .right, declaredQuotas: quotas)
        let root = storedURL.deletingLastPathComponent().deletingLastPathComponent()
        let executable = try reviewedExecutable()

        func start(_ application: EngineDockMenuApplication) async throws -> PulseDockPanel {
            await application.prepare()
            application.allowDockPresentation()
            await application.composition.start()
            let host = application.composition.dock
            let panel = try XCTUnwrap(host.nativePanel as? PulseDockPanel)
            let ready = try await wait(.seconds(10)) {
                let values = host.dockView.presentedReadingsForChecks.values.compactMap(\.remainingPercent).sorted(by: >)
                return panel.isVisible && values == quotas.map(Double.init)
            }
            return try XCTUnwrap(ready ? panel : nil, "The real widget and synthetic readings must be visible")
        }

        func drop(_ application: EngineDockMenuApplication, panel: PulseDockPanel, destination: DockDisplayArea,
                  edge: DockEdge, role: String, originalBytes: Data) async throws -> DockEdgePlacement {
            let host = application.composition.dock
            let events = PointerEvents()
            let previous = panel.receivedInput
            panel.receivedInput = { type, event in
                previous?(type, event)
                switch type {
                case .leftMouseDown: events.down += 1
                case .leftMouseDragged: events.drag += 1
                case .leftMouseUp: events.up += 1
                default: break
                }
            }
            defer { panel.receivedInput = previous }
            announce("D-06", "Drag the widget body to \(role), near the edge midpoint. Keep holding until prompted.")
            let held = try await wait(.seconds(45)) {
                guard events.down > 0, events.drag > 0, events.up == 0,
                      host.edgePresentation?.moving == true, panel.isVisible,
                      let candidate = host.edgePresentation?.placement,
                      candidate.displayID == destination.id, candidate.edge == edge else { return false }
                let cursor = NSEvent.mouseLocation
                let usable = destination.usableFrame
                guard destination.frame.contains(cursor) else { return false }
                if edge == .left {
                    let sharedMiddle = (max(a.frame.minY, b.frame.minY) + min(a.frame.maxY, b.frame.maxY)) / 2
                    return abs(cursor.x - usable.minX) <= 24 && abs(cursor.y - sharedMiddle) <= 80 &&
                        abs(panel.frame.minX - usable.minX) <= 1
                }
                return abs(cursor.y - usable.minY) <= 24 && abs(cursor.x - usable.midX) <= 80 &&
                    abs(panel.frame.minY - usable.minY) <= 1
            }
            _ = try XCTUnwrap(held ? panel : nil, "No held native placement reached \(role)")
            XCTAssertEqual(try Data(contentsOf: storedURL), originalBytes, role)
            announce("D-06", "Release on \(role) and capture the settled widget.")
            let editor = application.settingsHost.application.editor
            let released = try await wait(.seconds(20)) {
                events.up == 1 && host.edgePresentation?.moving == false && panel.isVisible &&
                    editor.snapshot?.preferences.dockDisplayID == destination.id && !editor.isSaving
            }
            return try XCTUnwrap(released ? host.edgePresentation?.placement : nil, "No completed release at \(role)")
        }

        var panel = try await start(app)
        XCTAssertEqual(app.composition.dock.edgePresentation?.placement?.displayID, a.id)
        XCTAssertEqual(app.composition.dock.edgePresentation?.placement?.edge, .right)
        let targets: [(DockDisplayArea, DockEdge, SettingsDockEdge, String)] = [
            (b, .left, .left, "B's left inner edge"),
            (c, .bottom, .bottom, "C's bottom edge"),
            (a, .bottom, .bottom, "A's bottom edge above the macOS Dock"),
        ]
        for (destination, edge, savedEdge, role) in targets {
            let before = await store.snapshot()
            let originalBytes = try Data(contentsOf: storedURL)
            let landed = try await drop(app, panel: panel, destination: destination, edge: edge,
                                        role: role, originalBytes: originalBytes)
            XCTAssertEqual(landed.displayID, destination.id, role)
            XCTAssertEqual(landed.edge, edge, role)
            XCTAssertTrue(destination.usableFrame.insetBy(dx: -1, dy: -1).contains(panel.frame), role)
            if edge == .bottom { XCTAssertEqual(panel.frame.minY, destination.visibleFrame.minY, accuracy: 1, role) }
            let saved = await store.snapshot()
            XCTAssertEqual(saved.revision, before.revision + 1, role)
            XCTAssertEqual(saved.preferences.dockDisplayID, destination.id, role)
            XCTAssertEqual(saved.preferences.dockEdge, savedEdge, role)
            XCTAssertEqual(saved.preferences.dockAlongFraction, landed.alongFraction, accuracy: 0.0001, role)
            let savedBytes = try Data(contentsOf: storedURL)
            let settledFrame = panel.frame
            try await Task.sleep(for: .seconds(4))

            await app.stopNativeDockJourney()
            store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
            app = makeDeviceApplication(root: root, executable: executable, store: store)
            panel = try await start(app)
            let restored = try XCTUnwrap(app.composition.dock.edgePresentation?.placement)
            XCTAssertEqual(restored.displayID, landed.displayID, role)
            XCTAssertEqual(restored.edge, landed.edge, role)
            XCTAssertEqual(restored.alongFraction, landed.alongFraction, accuracy: 0.0001, role)
            XCTAssertEqual(panel.frame.minX, settledFrame.minX, accuracy: 1, role)
            XCTAssertEqual(panel.frame.minY, settledFrame.minY, accuracy: 1, role)
            XCTAssertEqual(panel.frame.width, settledFrame.width, accuracy: 1, role)
            XCTAssertEqual(panel.frame.height, settledFrame.height, accuracy: 1, role)
            XCTAssertEqual(try Data(contentsOf: storedURL), savedBytes, role)
            announce("D-06", "The relaunched widget is visible on \(role). Capture its restored placement.")
            try await Task.sleep(for: .seconds(5))
        }
    }

    func testD07PhysicalEdgeMatrixStrongSnap() async throws { try await exercisePhysicalEdgeMatrix(mode: 1) }
    func testD07PhysicalEdgeMatrixAlwaysAttached() async throws { try await exercisePhysicalEdgeMatrix(mode: 2) }

    private enum EdgeTargetFailure: Error {
        case wrongStartPlacement, pointerDidNotReachTarget
    }

    private enum EdgeStation: String, CaseIterable {
        case low, midpoint, high

        func contains(_ point: CGFloat, from min: CGFloat, to max: CGFloat) -> Bool {
            switch self {
            case .low: return (min + 4...min + 20).contains(point)
            case .midpoint: return abs(point - (min + max) / 2) <= 16
            case .high: return (max - 20...max - 4).contains(point)
            }
        }
    }

    private func exercisePhysicalEdgeMatrix(mode: Int) async throws {
        _ = NSApplication.shared
        let modeKey = "ModelPlanDockDragMode"
        let originalMode = UserDefaults.standard.integer(forKey: modeKey)
        UserDefaults.standard.register(defaults: [modeKey: mode])
        defer { UserDefaults.standard.register(defaults: [modeKey: originalMode]) }
        guard UserDefaults.standard.integer(forKey: modeKey) == mode else {
            return XCTFail("An explicit setting overrides the isolated test mode")
        }
        let displays = DockDisplayTopology.system().displays.sorted {
            $0.frame.minX == $1.frame.minX ? $0.frame.minY < $1.frame.minY : $0.frame.minX < $1.frame.minX
        }
        guard displays.count >= 3, displays.indices.allSatisfy({ index in
            displays[..<index].allSatisfy { !$0.frame.intersects(displays[index].frame) }
        }) else { return XCTFail("D-07 needs at least three non-mirrored displays") }
        for (index, display) in displays.enumerated() {
            announce("D-07 display \(index + 1)", "\(display.name ?? "Display") at \(display.frame)")
        }
        let route = ProcessInfo.processInfo.environment["MODELPLAN_DOCK_D07_ROUTE"] ?? ""
        let indices = route.split(separator: ":", omittingEmptySubsequences: false).compactMap { Int($0) }
        guard indices.count == 2, indices[0] != indices[1],
              indices.allSatisfy({ (1...displays.count).contains($0) }) else {
            return XCTFail("Set MODELPLAN_DOCK_D07_ROUTE to source:destination using the numbered displays")
        }
        let source = displays[indices[0] - 1], destination = displays[indices[1] - 1]
        let label = "D-07 mode \(mode) route \(route)"
        let (_, _, storedURL) = try await makeProfile(displayID: source.id, edge: .right, declaredQuotas: [72, 53, 38])
        let root = storedURL.deletingLastPathComponent().deletingLastPathComponent()
        let executable = try reviewedExecutable()
        let edges: [(DockEdge, SettingsDockEdge)] = [(.left, .left), (.right, .right), (.bottom, .bottom)]
        var results: [(String, Bool)] = []

        func withNativePanel<T>(store: SettingsStore,
                                _ action: (EngineDockMenuApplication, PulseDockPanel) async throws -> T) async throws -> T {
            let app = makeDeviceApplication(root: root, executable: executable, store: store, registerTeardown: false)
            do {
                await app.prepare()
                app.allowDockPresentation()
                await app.composition.start()
                let host = app.composition.dock
                let panel = try XCTUnwrap(host.nativePanel as? PulseDockPanel)
                let ready = try await wait(.seconds(10)) {
                    panel.isVisible && Set(host.dockView.presentedReadingsForChecks.values.compactMap(\.remainingPercent))
                        == [72, 53, 38]
                }
                _ = try XCTUnwrap(ready ? panel : nil, "The native widget and three readings must appear")
                let value = try await action(app, panel)
                await app.stopNativeDockJourney()
                return value
            } catch {
                await app.stopNativeDockJourney()
                throw error
            }
        }

        func verifyTarget(edge: DockEdge, setting: SettingsDockEdge, station: EdgeStation) async throws -> Bool {
            let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
            let before = try await store.update {
                $0.dockDisplayID = source.id
                $0.dockEdge = .right
                $0.dockAlongFraction = 0.5
            }
            let originalBytes = try Data(contentsOf: storedURL)
            let usable = destination.usableFrame
            let horizontal = edge == .bottom
            let lo = horizontal ? usable.minX : usable.minY
            let hi = horizontal ? usable.maxX : usable.maxY
            let axis: (CGPoint) -> CGFloat = { horizontal ? $0.x : $0.y }
            func inTarget(_ point: CGPoint) -> Bool {
                guard destination.frame.contains(point), station.contains(axis(point), from: lo, to: hi) else { return false }
                switch edge {
                case .left: return (usable.minX...usable.minX + 4).contains(point.x)
                case .right: return (usable.maxX - 4...usable.maxX).contains(point.x)
                case .bottom: return (usable.minY...usable.minY + 4).contains(point.y)
                case .top: return false
                }
            }
            let dropped = try await withNativePanel(store: store) { app, panel in
                let host = app.composition.dock
                let start = try XCTUnwrap(host.edgePresentation?.placement)
                guard start.displayID == source.id, start.edge == .right else {
                    throw EdgeTargetFailure.wrongStartPlacement
                }
                let previous = panel.receivedInput
                var pressOnSource = false
                var releasedAt: CGPoint?
                panel.receivedInput = { type, event in
                    previous?(type, event)
                    if type == .leftMouseDown { pressOnSource = source.frame.contains(NSEvent.mouseLocation) }
                    if type == .leftMouseUp { releasedAt = NSEvent.mouseLocation }
                }
                defer { panel.receivedInput = previous }
                announce(label, "\(edge) \(station.rawValue): drag from source, aim within 4 pt of the destination rail, and hold")
                let held = try await wait(.seconds(35)) {
                    pressOnSource && releasedAt == nil && host.edgePresentation?.moving == true &&
                        host.edgePresentation?.placement?.displayID == destination.id &&
                        panel.isVisible && inTarget(NSEvent.mouseLocation)
                }
                let unchanged = try Data(contentsOf: storedURL) == originalBytes
                guard held else { throw EdgeTargetFailure.pointerDidNotReachTarget }
                announce(label, "Release now")
                let editor = app.settingsHost.application.editor
                let settled = try await wait(.seconds(8)) {
                    releasedAt != nil && host.edgePresentation?.moving == false && panel.isVisible &&
                        editor.snapshot?.preferences.dockDisplayID == destination.id && !editor.isSaving
                }
                let release = try XCTUnwrap(settled ? releasedAt : nil, "The target release did not settle")
                let landing = try XCTUnwrap(host.edgePresentation?.placement)
                let saved = await store.snapshot()
                let layout = landing.layout
                let length = horizontal ? layout.expandedSize.width : layout.expandedSize.height
                let lowAnchor = lo + 24 + max(layout.alongAnchor, layout.sliverLength / 2)
                let highAnchor = hi - 24 - max(length - layout.alongAnchor, layout.sliverLength / 2)
                let expected = (max(lowAnchor, min(highAnchor, axis(release))) - lo) / (hi - lo)
                let frame = panel.frame
                let frameStart = horizontal ? frame.minX : frame.minY
                let frameEnd = horizontal ? frame.maxX : frame.maxY
                let crossDistance: CGFloat = edge == .left ? frame.minX - usable.minX :
                    edge == .right ? usable.maxX - frame.maxX : frame.minY - usable.minY
                let savedCorrectly = unchanged && inTarget(release) && landing.displayID == destination.id &&
                    landing.edge == edge && saved.revision == before.revision + 1 &&
                    saved.preferences.dockDisplayID == destination.id && saved.preferences.dockEdge == setting &&
                    abs(saved.preferences.dockAlongFraction - expected) <= 0.002
                let panelCorrectlyPlaced = usable.insetBy(dx: -1, dy: -1).contains(frame) &&
                    abs(crossDistance) <= 1 && frameStart >= lo + 23 && frameEnd <= hi - 23
                if !savedCorrectly || !panelCorrectlyPlaced {
                    announce(label, "Release \(release), edge \(landing.edge), frame \(frame), fraction \(saved.preferences.dockAlongFraction) (expected \(expected)), revision \(before.revision) → \(saved.revision)")
                }
                return (savedCorrectly && panelCorrectlyPlaced, frame, saved.preferences.dockAlongFraction)
            }
            let bytesAfter = try Data(contentsOf: storedURL)
            let reopened = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
            let restored = try await withNativePanel(store: reopened) { app, panel in
                let placement = try XCTUnwrap(app.composition.dock.edgePresentation?.placement)
                let frame = panel.frame
                let matches = placement.displayID == destination.id && placement.edge == edge &&
                    abs(placement.alongFraction - dropped.2) <= 0.002 &&
                    abs(frame.minX - dropped.1.minX) <= 1 && abs(frame.minY - dropped.1.minY) <= 1 &&
                    abs(frame.width - dropped.1.width) <= 1 && abs(frame.height - dropped.1.height) <= 1
                return matches
            }
            let restoredBytes = try Data(contentsOf: storedURL)
            return dropped.0 && restored && restoredBytes == bytesAfter
        }

        for (edge, setting) in edges {
            for station in EdgeStation.allCases {
                let target = "\(edge) \(station.rawValue)"
                do {
                    results.append((target, try await verifyTarget(edge: edge, setting: setting, station: station)))
                } catch {
                    announce(label, "\(target) error: \(error)")
                    results.append((target, false))
                }
            }
        }
        for (target, passed) in results {
            announce(label, "\(passed ? "PASS" : "FAIL") \(target)")
            XCTAssertTrue(passed, "\(label): \(target)")
        }
    }

    func testD08PhysicalInnerStripWakesWithoutCrossingDisplays() async throws {
        _ = NSApplication.shared
        let topology = DockDisplayTopology.system()
        var candidate: (display: DockDisplayArea, edge: SettingsDockEdge, along: Double)?
        displays: for display in topology.displays {
            for adjacent in topology.displays where adjacent.id != display.id {
                let edge: SettingsDockEdge
                if abs(display.frame.maxX - adjacent.frame.minX) < 0.5 &&
                    abs(display.usableFrame.maxX - display.frame.maxX) < 0.5 {
                    edge = .right
                } else if abs(display.frame.minX - adjacent.frame.maxX) < 0.5 &&
                    abs(display.usableFrame.minX - display.frame.minX) < 0.5 {
                    edge = .left
                } else { continue }
                let lower = max(display.usableFrame.minY, adjacent.frame.minY)
                let upper = min(display.usableFrame.maxY, adjacent.frame.maxY)
                guard upper - lower >= 350 else { continue }
                let along = Double(((lower + upper) / 2 - display.usableFrame.minY) / display.usableFrame.height)
                candidate = (display, edge, along)
                break displays
            }
        }
        let target = try XCTUnwrap(candidate, "D-08 needs two side-by-side displays with a usable shared edge")
        let (app, store, storedURL) = try await makeProfile(displayID: target.display.id, edge: target.edge,
            declaredQuotas: [72, 53, 38], autoHide: true, along: target.along)
        await app.prepare()
        XCTAssertNil(app.loginServiceAdapter)
        XCTAssertNil(app.notificationAuthorizationService)
        app.allowDockPresentation()
        await app.composition.start()
        let dock = app.composition.dock
        func state(_ expected: DockSurfaceState) -> Bool {
            guard let panel = dock.nativePanel else { return false }
            return dock.edgePresentation?.state == expected && panel.isVisible && panel.occlusionState.contains(.visible)
        }

        announce("D-08", "Place the pointer near the centre of the display showing the collapsed widget")
        let ready = try await wait(.seconds(30)) {
            guard case .ready = app.composition.store.snapshot.connection else { return false }
            return target.display.frame.contains(NSEvent.mouseLocation) && state(.sliver)
        }
        guard ready else { return XCTFail("The real App must show the inner strip with the pointer on its own display") }
        let placement = try XCTUnwrap(dock.edgePresentation?.placement)
        let panel = try XCTUnwrap(dock.nativePanel)
        XCTAssertTrue(panel.contentView is DockSliverView)
        XCTAssertEqual(placement.displayID, target.display.id)
        XCTAssertEqual(placement.edge, target.edge == .left ? .left : .right)
        XCTAssertEqual(panel.frame.minX, placement.sliverFrame.minX, accuracy: 1)
        XCTAssertEqual(panel.frame.maxX, placement.sliverFrame.maxX, accuracy: 1)
        let wake = placement.wakeFrame.insetBy(dx: 2, dy: 6)
        XCTAssertFalse(wake.isEmpty)
        XCTAssertTrue(target.display.frame.contains(wake))
        XCTAssertFalse(wake.contains(NSEvent.mouseLocation))
        let before = await store.snapshot()
        let bytes = try Data(contentsOf: storedURL)

        var leftSource = false
        announce("D-08", "Move toward the inner strip and hold just inside the same display, without crossing the seam")
        let expanded = try await wait(.seconds(30)) {
            let point = NSEvent.mouseLocation
            leftSource = leftSource || !target.display.frame.contains(point)
            return state(.expanded) && wake.contains(point)
        }
        guard expanded else { return XCTFail("The native inner strip did not reveal with the pointer on its own display") }
        XCTAssertFalse(leftSource, "Pointer samples must stay on the originating display")
        XCTAssertEqual(dock.edgePresentation?.placement?.displayID, target.display.id)
        try await Task.sleep(for: .milliseconds(550))
        XCTAssertTrue(state(.expanded), "The inner wake band counts as inside the open widget")
        XCTAssertTrue(wake.contains(NSEvent.mouseLocation))

        announce("D-08", "Move back toward the centre of the same display and capture the restored strip")
        let collapsed = try await wait(.seconds(30)) {
            target.display.frame.contains(NSEvent.mouseLocation) &&
                !placement.wakeFrame.contains(NSEvent.mouseLocation) && state(.sliver)
        }
        XCTAssertTrue(collapsed)
        XCTAssertEqual(dock.edgePresentation?.placement, placement)
        let after = await store.snapshot()
        XCTAssertEqual(after.revision, before.revision)
        XCTAssertEqual(try Data(contentsOf: storedURL), bytes)
        try await Task.sleep(for: .seconds(5))
    }

    func testD10PhysicalHotPlugRestoresSavedDisplayWithoutWriting() async throws {
        _ = NSApplication.shared
        let topology = DockDisplayTopology.system()
        let main = try XCTUnwrap(topology.main)
        let savedDisplay = try XCTUnwrap(topology.displays.first {
            $0.id != main.id && !$0.frame.intersects(main.frame)
        }, "D-10 requires a real removable non-mirrored display")
        let (app, store, storedURL) = try await makeProfile(displayID: savedDisplay.id, edge: .right,
                                                          declaredQuotas: [72, 53, 38])
        await app.prepare()
        XCTAssertNil(app.loginServiceAdapter)
        XCTAssertNil(app.notificationAuthorizationService)
        app.allowDockPresentation()
        await app.composition.start()
        let dock = app.composition.dock
        func visibleOn(_ id: String) -> Bool {
            guard let panel = dock.nativePanel else { return false }
            return dock.edgePresentation?.placement?.displayID == id &&
                panel.isVisible && panel.occlusionState.contains(.visible)
        }
        let ready = try await wait(.seconds(5)) {
            guard case .ready = app.composition.store.snapshot.connection else { return false }
            let values = Set(dock.dockView.presentedReadingsForChecks.values.compactMap(\.remainingPercent))
            return visibleOn(savedDisplay.id) && values == [72, 53, 38]
        }
        guard ready else { return XCTFail("The real App must paint the synthetic readings visibly on its saved display") }
        let original = try XCTUnwrap(dock.edgePresentation?.placement)
        let initial = await store.snapshot()
        let originalBytes = try Data(contentsOf: storedURL)
        XCTAssertEqual(original.edge, .right)
        XCTAssertEqual(original.alongFraction, initial.preferences.dockAlongFraction, accuracy: 0.01)
        XCTAssertEqual(initial.preferences.dockDisplayID, savedDisplay.id)

        let events = LifecycleEvents()
        let notifications = NotificationCenter.default
        let observer = notifications.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                  object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { events.screens += 1 }
        }
        defer { notifications.removeObserver(observer) }

        let beforeRemoval = events.screens
        announce("D-10", "Capture the saved placement, then physically disconnect the secondary display showing the widget")
        let removed = try await wait(.seconds(45)) {
            events.screens > beforeRemoval && DockDisplayTopology.system().display(savedDisplay.id) == nil &&
                visibleOn(main.id)
        }
        guard removed else { return XCTFail("The missing-display transition did not show the Dock on the primary display") }
        let fallback = try XCTUnwrap(dock.edgePresentation?.placement)
        let fallbackPanel = try XCTUnwrap(dock.nativePanel)
        let currentMain = try XCTUnwrap(DockDisplayTopology.system().display(main.id))
        XCTAssertEqual(fallback.edge, original.edge)
        XCTAssertEqual(fallback.alongFraction, original.alongFraction, accuracy: 0.01)
        XCTAssertEqual(fallbackPanel.frame.maxX, currentMain.visibleFrame.maxX, accuracy: 1)
        let afterRemoval = await store.snapshot()
        XCTAssertEqual(afterRemoval.revision, initial.revision)
        XCTAssertEqual(afterRemoval.preferences.dockDisplayID, savedDisplay.id)
        XCTAssertEqual(try Data(contentsOf: storedURL), originalBytes)

        let beforeReturn = events.screens
        announce("D-10", "Capture the primary fallback, then reconnect the same display to its original port")
        let reattached = try await wait(.seconds(60)) {
            events.screens > beforeReturn && DockDisplayTopology.system().display(savedDisplay.id) != nil &&
                visibleOn(savedDisplay.id)
        }
        guard reattached else { return XCTFail("The Dock did not return to its original display") }
        let restored = try XCTUnwrap(dock.edgePresentation?.placement)
        let restoredPanel = try XCTUnwrap(dock.nativePanel)
        let currentSaved = try XCTUnwrap(DockDisplayTopology.system().display(savedDisplay.id))
        XCTAssertEqual(restored.edge, original.edge)
        XCTAssertEqual(restored.alongFraction, original.alongFraction, accuracy: 0.01)
        XCTAssertEqual(restoredPanel.frame.maxX, currentSaved.visibleFrame.maxX, accuracy: 1)
        let afterReturn = await store.snapshot()
        XCTAssertEqual(afterReturn.revision, initial.revision)
        XCTAssertEqual(try Data(contentsOf: storedURL), originalBytes)
        announce("D-10", "Capture the restored placement within five seconds")
        try await Task.sleep(for: .seconds(5))
        XCTAssertEqual(try Data(contentsOf: storedURL), originalBytes)
    }

    func testD11PhysicalPressAndCancelWithoutSaving() async throws {
        let application = NSApplication.shared
        let foregroundBundle = try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_DOCK_D11_FOREGROUND_BUNDLE"],
            "Supply the admitted synthetic editor's bundle identifier")
        func editorRemainsFrontmost() -> Bool {
            !application.isActive && NSWorkspace.shared.frontmostApplication?.bundleIdentifier == foregroundBundle
        }
        let display = try XCTUnwrap(DockDisplayTopology.system().main)
        let (app, store, storedURL) = try await makeProfile(displayID: display.id, edge: .bottom,
                                                            declaredQuotas: [72, 53, 38])
        await app.prepare()
        app.allowDockPresentation()
        await app.composition.start()
        let dock = app.composition.dock
        let panel = try XCTUnwrap(dock.nativePanel as? PulseDockPanel)
        let ready = try await wait(.seconds(12)) {
            panel.isVisible && dock.interactionControllerRunning &&
                dock.edgePresentation?.placement?.edge == .bottom &&
                Set(dock.dockView.presentedReadingsForChecks.values.compactMap(\.remainingPercent)) == [72, 53, 38]
        }
        guard ready else { return XCTFail("D-11 needs a visible native bottom panel with three synthetic readings") }
        let view = try XCTUnwrap(panel.contentView?.subviews.compactMap { $0 as? DockInstrumentView }.first)
        let controller = try XCTUnwrap(dock.interactionControllerForChecks)
        let order = view.interactionTargets(edge: .bottom).map(\.id)
        let first = try XCTUnwrap(order.first)
        let last = try XCTUnwrap(order.last)
        XCTAssertNotEqual(first, last)
        let startStation = try XCTUnwrap(view.interactionAnchor(first))
        let endStation = try XCTUnwrap(view.interactionAnchor(last))
        let face = try XCTUnwrap(stride(from: 4.0, to: view.bounds.height, by: 4).lazy.flatMap { y in
            stride(from: 4.0, to: view.bounds.width, by: 4).map { CGPoint(x: $0, y: y) }
        }.first { view.backgroundDragDelegate?.backgroundCanDrag(local: $0) == true })
        func screenPoint(_ local: CGPoint) -> CGPoint {
            panel.convertPoint(toScreen: view.convert(local, to: nil))
        }
        let facePoint = screenPoint(face)
        let firstPoint = screenPoint(CGPoint(x: startStation.midX, y: startStation.midY))
        let lastPoint = screenPoint(CGPoint(x: endStation.midX, y: endStation.midY))
        let frame = panel.frame
        var originalKeyWindow: NSWindow?
        let before = await store.snapshot()
        let bytes = try Data(contentsOf: storedURL)
        let sweep = view.refreshSweepCountForChecks
        let events = PointerEvents()
        let previous = panel.receivedInput
        var pressPoint: CGPoint?
        var releasePoint: CGPoint?
        panel.receivedInput = { type, timestamp in
            previous?(type, timestamp)
            switch type {
            case .leftMouseDown: events.down += 1; pressPoint = NSEvent.mouseLocation
            case .leftMouseDragged: events.drag += 1
            case .leftMouseUp: events.up += 1; releasePoint = NSEvent.mouseLocation
            default: break
            }
        }
        defer { panel.receivedInput = previous }

        func assertRestored(_ step: String) async throws {
            XCTAssertTrue(editorRemainsFrontmost(), "The synthetic editor must remain frontmost: " + step)
            XCTAssertTrue(panel.isVisible, step)
            XCTAssertFalse(panel.isKeyWindow, step)
            XCTAssertTrue(application.keyWindow === originalKeyWindow, "Temporary keyboard focus must be released: " + step)
            XCTAssertEqual(panel.frame, frame, step)
            XCTAssertFalse(dock.edgePresentation?.moving == true, step)
            XCTAssertFalse(controller.hasCapture, step)
            XCTAssertNil(controller.presentation?.reorder, step)
            XCTAssertEqual(view.interactionTargets(edge: .bottom).map(\.id), order, step)
            XCTAssertEqual(view.refreshSweepCountForChecks, sweep, step)
            XCTAssertFalse(app.settingsHost.application.editor.isSaving, step)
            let saved = await store.snapshot()
            XCTAssertEqual(saved.revision, before.revision, step)
            XCTAssertEqual(try Data(contentsOf: storedURL), bytes, step)
        }
        func near(_ point: CGPoint?, _ target: CGPoint) -> Bool {
            guard let point else { return false }
            return hypot(point.x - target.x, point.y - target.y) <= 8
        }

        announce("D-11", "Activate the admitted synthetic editor and leave it frontmost throughout this test.")
        guard try await wait(.seconds(30), until: editorRemainsFrontmost) else {
            return XCTFail("The admitted synthetic editor is not frontmost")
        }
        originalKeyWindow = application.keyWindow

        announce("D-11", "Click the widget body near \(facePoint) without moving, then release.")
        guard try await wait(.seconds(30), until: { events.up == 1 }) else {
            return XCTFail("No physical face click arrived")
        }
        XCTAssertTrue(near(pressPoint, facePoint) && near(releasePoint, facePoint))
        XCTAssertEqual(events.drag, 0)
        try await assertRestored("face click")

        announce("D-11", "Press the same body point and hold still. Wait for the next prompt.")
        guard try await wait(.seconds(30), until: { events.down == 2 && events.up == 1 }) else {
            return XCTFail("No physical hold arrived")
        }
        XCTAssertTrue(near(pressPoint, facePoint))
        let hold = ContinuousClock.now + .seconds(1)
        while ContinuousClock.now < hold {
            XCTAssertEqual(panel.frame, frame, "Face must stay put before the first drag event")
            if events.up != 1 || events.drag != 0 { return XCTFail("Keep the face press still for the full second") }
            try await Task.sleep(for: .milliseconds(20))
        }
        announce("D-11", "Drag along the bottom rail and keep holding.")
        guard try await wait(.seconds(25), until: {
            events.drag > 0 && events.up == 1 && dock.edgePresentation?.moving == true && panel.frame != frame
        }) else { return XCTFail("The held native panel did not move") }
        XCTAssertTrue(editorRemainsFrontmost(), "Body carry must not activate ModelPlan")
        announce("D-11", "Press physical Escape without letting go of the mouse or switching apps.")
        guard try await wait(.seconds(20), until: {
            editorRemainsFrontmost() && events.up == 1 && dock.edgePresentation?.moving == false && panel.frame == frame
        }) else { return XCTFail("The native panel did not restore before physical mouse-up") }
        announce("D-11", "Release the mouse now.")
        guard try await wait(.seconds(15), until: { events.up == 2 }) else {
            return XCTFail("The post-Escape mouse-up did not arrive")
        }
        try await assertRestored("face Escape")

        for escape in [true, false] {
            let upBefore = events.up
            let step = escape ? "nozzle Escape" : "nozzle outside release"
            announce("D-11", "Drag the nozzle near \(firstPoint) towards \(lastPoint); keep holding for \(step).")
            guard try await wait(.seconds(35), until: {
                events.up == upBefore && near(pressPoint, firstPoint) && controller.hasCapture &&
                    controller.presentation?.reorder != nil
            }) else { return XCTFail("No physical reorder preview for \(step)") }
            XCTAssertEqual(panel.frame, frame, step)
            if escape {
                XCTAssertTrue(editorRemainsFrontmost(), "Nozzle reorder must not activate ModelPlan")
                announce("D-11", "Press physical Escape while still holding, with the editor frontmost.")
                guard try await wait(.seconds(20), until: {
                    editorRemainsFrontmost() && events.up == upBefore && !controller.hasCapture && controller.presentation?.reorder == nil
                }) else { return XCTFail("Nozzle capture remained after physical Escape") }
                announce("D-11", "Release the mouse now.")
            } else {
                announce("D-11", "Move well above the widget and card, then release outside.")
            }
            guard try await wait(.seconds(20), until: { events.up == upBefore + 1 }) else {
                return XCTFail("No physical mouse-up for \(step)")
            }
            if !escape {
                let outside = try XCTUnwrap(releasePoint)
                XCTAssertFalse(frame.insetBy(dx: -12, dy: -12).contains(outside))
            }
            try await assertRestored(step)
        }
    }

    func testD11PhysicalIgnitionAndNozzleThreshold() async throws {
        _ = NSApplication.shared
        let display = try XCTUnwrap(DockDisplayTopology.system().displays.first { $0.backingScale == 1 },
                                    "D-11 physical pixel distances require a 1x display")
        let (app, store, storedURL) = try await makeProfile(displayID: display.id, edge: .bottom,
            declaredQuotas: [72, 53, 38], cockpitEntryEnabled: true)
        await app.prepare()
        app.allowDockPresentation()
        await app.composition.start()
        let dock = app.composition.dock
        let panel = try XCTUnwrap(dock.nativePanel as? PulseDockPanel)
        let ready = try await wait(.seconds(12)) {
            panel.isVisible && dock.interactionControllerRunning &&
                dock.edgePresentation?.placement?.displayID == display.id &&
                dock.edgePresentation?.placement?.edge == .bottom &&
                Set(dock.dockView.presentedReadingsForChecks.values.compactMap(\.remainingPercent)) == [72, 53, 38]
        }
        guard ready else { return XCTFail("D-11 needs the native widget on the 1x bottom rail") }
        let children = try XCTUnwrap(panel.contentView?.subviews)
        let view = try XCTUnwrap(children.compactMap { $0 as? DockInstrumentView }.first)
        let ignition = try XCTUnwrap(children.compactMap { $0 as? NSButton }.first {
            $0.isTransparent && $0.isEnabled && !$0.isHiddenOrHasHiddenAncestor && !$0.bounds.isEmpty
        })
        let ignitionFrame = panel.convertToScreen(ignition.convert(ignition.bounds, to: nil))
        let controller = try XCTUnwrap(dock.interactionControllerForChecks)
        let order = view.interactionTargets(edge: .bottom).map(\.id)
        let nozzle = try XCTUnwrap(view.interactionAnchor(try XCTUnwrap(order.first)))
        let nozzleFrame = panel.convertToScreen(view.convert(nozzle, to: nil))
        let frame = panel.frame
        let before = await store.snapshot()
        let bytes = try Data(contentsOf: storedURL)
        let sweeps = view.refreshSweepCountForChecks
        let originalOpen = dock.showConsole
        var cockpitRequests = 0
        dock.showConsole = { cockpitRequests += 1 }
        defer { dock.showConsole = originalOpen }

        let events = PointerEvents()
        let previousInput = panel.receivedInput
        let previousPlacement = dock.onPlacementObserved
        var start: CGPoint?
        var displacement: CGFloat = 0
        var peak: CGFloat = 0
        var movedPanel = false
        dock.onPlacementObserved = { placement, recovering in
            previousPlacement?(placement, recovering)
            movedPanel = movedPanel || dock.edgePresentation?.moving == true
        }
        panel.receivedInput = { type, timestamp in
            previousInput?(type, timestamp)
            switch type {
            case .leftMouseDown:
                events.down += 1
                start = NSEvent.mouseLocation
                displacement = 0
                peak = 0
            case .leftMouseDragged:
                events.drag += 1
                if let start {
                    displacement = NSEvent.mouseLocation.x - start.x
                    peak = max(peak, abs(displacement))
                }
            case .leftMouseUp:
                events.up += 1
            default:
                break
            }
        }
        defer {
            panel.receivedInput = previousInput
            dock.onPlacementObserved = previousPlacement
        }

        func assertUnchanged(_ step: String) async throws {
            XCTAssertTrue(panel.isVisible, step)
            XCTAssertEqual(panel.frame, frame, step)
            XCTAssertFalse(movedPanel, step)
            XCTAssertEqual(cockpitRequests, 0, step)
            XCTAssertEqual(view.interactionTargets(edge: .bottom).map(\.id), order, step)
            XCTAssertEqual(view.refreshSweepCountForChecks, sweeps, step)
            XCTAssertFalse(controller.hasCapture, step)
            XCTAssertNil(controller.presentation?.reorder, step)
            XCTAssertFalse(app.settingsHost.application.editor.isSaving, step)
            let saved = await store.snapshot()
            XCTAssertEqual(saved.revision, before.revision, step)
            XCTAssertEqual(try Data(contentsOf: storedURL), bytes, step)
        }

        announce("D-11", "Press the ignition inside \(ignitionFrame), drag outside the button and release.")
        // AppKit button tracking may consume its own drag/up events instead of dispatching them to NSPanel.
        guard try await wait(.seconds(35), until: {
            events.down == 1 && NSEvent.pressedMouseButtons & 1 == 0 && !ignitionFrame.contains(NSEvent.mouseLocation)
        }) else { return XCTFail("No completed physical ignition gesture") }
        XCTAssertTrue(start.map(ignitionFrame.contains) == true)
        try await assertUnchanged("ignition drag")

        for target in [4.0, 5.0, 6.0] {
            let downBefore = events.down, upBefore = events.up, dragBefore = events.drag
            announce("D-11", "Press near the centre of \(nozzleFrame); move right by \(Int(target)) pixels and hold.")
            let reached = try await wait(.seconds(35)) {
                events.down == downBefore + 1 && events.up == upBefore && events.drag > dragBefore &&
                    start.map(nozzleFrame.contains) == true && controller.hasCapture && abs(displacement - target) < 0.25
            }
            guard reached else { return XCTFail("No physical \(target) px checkpoint. Last sampled delta: \(displacement)") }
            XCTAssertLessThan(peak, target + 0.25, "The physical gesture must not overshoot its threshold")
            if target > 5 { XCTAssertNotNil(controller.presentation?.reorder) }
            else { XCTAssertNil(controller.presentation?.reorder) }
            XCTAssertEqual(panel.frame, frame)
            announce("D-11", "Release without moving from the checkpoint.")
            guard try await wait(.seconds(15), until: { events.up == upBefore + 1 }) else {
                return XCTFail("Physical threshold release did not arrive")
            }
            XCTAssertLessThan(peak, target + 0.25, "Release must stay at the sampled threshold")
            try await assertUnchanged("\(Int(target)) px threshold")
        }
    }

    func testD18PhysicalVoiceOverReordersFace() async throws { try await exerciseVoiceOverReorder(overflow: false) }
    func testD18PhysicalVoiceOverReordersOverflow() async throws { try await exerciseVoiceOverReorder(overflow: true) }

    private func exerciseVoiceOverReorder(overflow: Bool) async throws {
        let application = NSApplication.shared
        let systemOnly = ProcessInfo.processInfo.environment["MODELPLAN_DOCK_D18_MOTION"] == "system"
        guard NSWorkspace.shared.accessibilityDisplayShouldReduceMotion == systemOnly else {
            return XCTFail(systemOnly ? "Enable macOS Reduce Motion for the system-only run" :
                            "Turn macOS Reduce Motion off for the app-only run")
        }
        let main = try XCTUnwrap(DockDisplayTopology.system().main)
        let quotas = overflow ? Array(40..<70) : [72, 53, 38]
        let (app, store, storedURL) = try await makeProfile(displayID: main.id, edge: .bottom, declaredQuotas: quotas)
        _ = try await store.update { $0.motion = systemOnly ? .system : .on }
        await app.prepare()
        app.allowDockPresentation()
        await app.composition.start()
        let host = app.composition.dock
        let panel = try XCTUnwrap(host.nativePanel)
        let ready = try await wait(.seconds(15)) {
            panel.isVisible && host.edgePresentation?.placement?.edge == .bottom &&
                host.interactionControllerRunning && host.interactionEnvironment().catalogue.count == quotas.count
        }
        guard ready else { return XCTFail("The native panel did not present the synthetic subscriptions") }
        XCTAssertTrue(host.interactionEnvironment().reducedMotion)
        let view = try XCTUnwrap(panel.contentView?.subviews.compactMap { $0 as? DockInstrumentView }.first)
        let initial = host.interactionEnvironment()
        let ordered = try initial.preferences.orderedIDs(in: initial.catalogue)
        let before = await store.snapshot()
        let oldBytes = try Data(contentsOf: storedURL)
        let beforeFrame = panel.frame
        let children = (view.accessibilityChildren() ?? []).compactMap { $0 as? NSAccessibilityElement }
        XCTAssertFalse(children.isEmpty)
        for child in children { XCTAssertFalse(try XCTUnwrap(child.accessibilityLabel()).isEmpty) }

        func findTray(in view: NSView?) -> DockOverflowTrayView? {
            guard let view, !view.isHiddenOrHasHiddenAncestor else { return nil }
            if let tray = view as? DockOverflowTrayView { return tray }
            return view.subviews.lazy.compactMap { findTray(in: $0) }.first
        }
        func visibleTray() -> DockOverflowTrayView? {
            application.windows.lazy.filter(\.isVisible).compactMap { findTray(in: $0.contentView) }.first
        }
        func findRow(_ id: String, in view: NSView) -> NSView? {
            if view.accessibilityIdentifier() == "dock.overflow." + id { return view }
            return view.subviews.lazy.compactMap { findRow(id, in: $0) }.first
        }

        let id: String
        let offset: Int
        if overflow {
            XCTAssertFalse(view.interactionOverflowIDs.isEmpty)
            let trigger = try XCTUnwrap(children.first { $0.accessibilityIdentifier() == "dock.overflow" })
            announce("D-18", "Use VoiceOver to find \(trigger.accessibilityLabel() ?? "More subscriptions") and open it.")
            guard try await wait(.seconds(45), until: { visibleTray() != nil }) else {
                return XCTFail("VoiceOver did not open the native overflow tray")
            }
            id = try XCTUnwrap(ordered.last { view.interactionOverflowIDs.contains($0) })
            offset = -1
            let tray = try XCTUnwrap(visibleTray())
            let row = try XCTUnwrap(findRow(id, in: tray))
            let label = try XCTUnwrap(row.accessibilityLabel())
            XCTAssertFalse(label.isEmpty)
            XCTAssertFalse(try XCTUnwrap(row.accessibilityHelp()).isEmpty)
            announce("D-18", "Focus the overflow row \(label) with VoiceOver and record its speech.")
            guard try await wait(.seconds(45), until: {
                tray.keyboardTargetID == id || row.window?.firstResponder === row
            }) else { return XCTFail("The physical overflow focus did not reach the keyboard route") }
        } else {
            id = try XCTUnwrap(view.interactionTargets(edge: .bottom).first?.id)
            offset = 1
            let node = try XCTUnwrap(children.first { $0.accessibilityIdentifier() == "dock.subscription." + id })
            let label = try XCTUnwrap(node.accessibilityLabel())
            announce("D-18", "Use VoiceOver to focus \(label), value \(node.accessibilityValue() as? String ?? ""). Record the announcement.")
            guard try await wait(.seconds(45), until: { view.keyboardTargetID == id && node.isAccessibilityFocused() }) else {
                return XCTFail("VoiceOver focus did not reach the native face nozzle")
            }
        }
        let oldIndex = try XCTUnwrap(ordered.firstIndex(of: id))
        let newIndex = oldIndex + offset
        guard ordered.indices.contains(newIndex) else { return XCTFail("Choose a nozzle with an adjacent subscription") }
        var expected = ordered
        expected.swapAt(oldIndex, newIndex)
        let direction = offset > 0 ? "Right" : "Left"
        announce("D-18", "Press physical Option-\(direction) once. Capture the widget and VoiceOver speech.")
        let editor = app.settingsHost.application.editor
        let committed = try await wait(.seconds(25)) {
            editor.snapshot?.preferences.subscriptions.order == expected && !editor.isSaving
        }
        guard committed else { return XCTFail("Physical Option-\(direction) did not persist the order") }
        let after = await store.snapshot()
        XCTAssertEqual(after.revision, before.revision + 1)
        XCTAssertEqual(after.preferences.subscriptions.order, expected)
        XCTAssertNotEqual(try Data(contentsOf: storedURL), oldBytes)
        XCTAssertTrue((view.accessibilityValue() as? String)?.hasSuffix("position \(newIndex + 1) of \(ordered.count)") == true)
        XCTAssertTrue(host.interactionEnvironment().reducedMotion)
        XCTAssertEqual(panel.frame, beforeFrame)
        XCTAssertNil(host.interactionControllerForChecks?.presentation?.reorder, "A keyboard commit must not retain a drag pose")
        try await Task.sleep(for: .seconds(5))
    }

    func testD19PhysicalSystemDockReservationsAndLegacyPlacement() async throws {
        _ = NSApplication.shared
        let side = try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_DOCK_D19_SYSTEM_EDGE"]
            .flatMap(SettingsDockEdge.init(rawValue:)), "Choose bottom, left or right in MODELPLAN_DOCK_D19_SYSTEM_EDGE")
        let display = try XCTUnwrap(DockDisplayTopology.system().main)
        let area = display.usableFrame
        let reserve: CGFloat
        switch side {
        case .bottom: reserve = area.minY - display.frame.minY
        case .left: reserve = area.minX - display.frame.minX
        case .right: reserve = display.frame.maxX - area.maxX
        }
        guard reserve >= 8 else { return XCTFail("The physical macOS Dock must visibly reserve the \(side) edge") }

        let (app, store, storedURL) = try await makeProfile(displayID: display.id, edge: .right,
                                                            declaredQuotas: [72, 53, 38])
        await app.prepare()
        app.allowDockPresentation()
        await app.composition.start()
        let host = app.composition.dock
        let panel = try XCTUnwrap(host.nativePanel as? PulseDockPanel)
        let ready = try await wait(.seconds(12)) {
            panel.isVisible && host.edgePresentation?.placement?.displayID == display.id &&
                Set(host.dockView.presentedReadingsForChecks.values.compactMap(\.remainingPercent)) == [72, 53, 38]
        }
        guard ready else { return XCTFail("The native panel and readings must be visible") }

        let events = PointerEvents()
        let previous = panel.receivedInput
        var releasePoint: CGPoint?
        panel.receivedInput = { type, timestamp in
            previous?(type, timestamp)
            switch type {
            case .leftMouseDown: events.down += 1
            case .leftMouseDragged: events.drag += 1
            case .leftMouseUp: events.up += 1; releasePoint = NSEvent.mouseLocation
            default: break
            }
        }
        defer { panel.receivedInput = previous }

        func distance(_ point: CGPoint, from edge: DockEdge) -> CGFloat {
            switch edge {
            case .left: return abs(point.x - area.minX)
            case .right: return abs(point.x - area.maxX)
            case .bottom: return abs(point.y - area.minY)
            case .top: return .infinity
            }
        }
        let rails: [(DockEdge, SettingsDockEdge)] = [(.left, .left), (.right, .right), (.bottom, .bottom)]
        func verifyDrop(_ label: String, target: (CGPoint) -> Bool,
                        expected: (CGPoint) -> (DockEdge, SettingsDockEdge)) async throws {
            let previousUp = events.up, previousDrag = events.drag
            let before = await store.snapshot()
            let bytes = try Data(contentsOf: storedURL)
            announce("D-19 \(side)", "Drag the body to \(label), then hold.")
            let held = try await wait(.seconds(35)) {
                events.up == previousUp && events.drag > previousDrag && host.edgePresentation?.moving == true &&
                    target(NSEvent.mouseLocation)
            }
            _ = try XCTUnwrap(held ? panel : nil, "No held gesture at \(label)")
            XCTAssertEqual(try Data(contentsOf: storedURL), bytes, label)
            announce("D-19 \(side)", "Release now and capture \(label).")
            let editor = app.settingsHost.application.editor
            let settled = try await wait(.seconds(15)) {
                events.up == previousUp + 1 && host.edgePresentation?.moving == false && !editor.isSaving &&
                    editor.snapshot?.revision == before.revision + 1
            }
            let point = try XCTUnwrap(settled ? releasePoint : nil, "No single settled release at \(label)")
            XCTAssertTrue(target(point), label)
            let (edge, setting) = expected(point)
            let landed = try XCTUnwrap(host.edgePresentation?.placement)
            let saved = await store.snapshot()
            XCTAssertEqual(landed.displayID, display.id, label)
            XCTAssertEqual(landed.edge, edge, label)
            XCTAssertEqual(saved.revision, before.revision + 1, label)
            XCTAssertEqual(saved.preferences.dockEdge, setting, label)
            XCTAssertEqual(saved.preferences.dockAlongFraction, landed.alongFraction, accuracy: 0.0001, label)
            XCTAssertTrue(panel.isVisible)
            XCTAssertTrue(area.insetBy(dx: -1, dy: -1).contains(panel.frame), label)
            switch edge {
            case .left: XCTAssertEqual(panel.frame.minX, area.minX, accuracy: 1, label)
            case .right: XCTAssertEqual(panel.frame.maxX, area.maxX, accuracy: 1, label)
            case .bottom: XCTAssertEqual(panel.frame.minY, area.minY, accuracy: 1, label)
            case .top: XCTFail("Top is not an allowed resting edge")
            }
            let start = edge == .bottom ? panel.frame.minX - area.minX : panel.frame.minY - area.minY
            let end = edge == .bottom ? area.maxX - panel.frame.maxX : area.maxY - panel.frame.maxY
            XCTAssertGreaterThanOrEqual(min(start, end), 23, label)
            try await Task.sleep(for: .seconds(3))
        }

        for (edge, setting) in rails {
            let lo = edge == .bottom ? area.minX : area.minY
            let hi = edge == .bottom ? area.maxX : area.maxY
            for station in [EdgeStation.low, .high] {
                try await verifyDrop("\(edge) \(station.rawValue) usable corner", target: { point in
                    area.contains(point) && distance(point, from: edge) <= 3 &&
                        station.contains(edge == .bottom ? point.x : point.y, from: lo, to: hi)
                }, expected: { _ in (edge, setting) })
            }
        }
        let centre = area.insetBy(dx: area.width * 0.30, dy: area.height * 0.30)
        try await verifyDrop("the middle of the display (slightly towards the right)", target: { point in
            guard centre.contains(point), point.x > area.midX else { return false }
            let distances = rails.map { distance(point, from: $0.0) }.sorted()
            return distances[0] + 12 < distances[1]
        }, expected: { point in
            rails.min(by: { distance(point, from: $0.0) < distance(point, from: $1.0) }) ?? (.right, .right)
        })
        await app.stopNativeDockJourney()

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dock-d19-floating-" + UUID().uuidString)
        let legacy = root.appendingPathComponent("ModelPlan/Native/settings-v1.json")
        try FileManager.default.createDirectory(at: legacy.deletingLastPathComponent(), withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        let legacyBytes = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 1, "preferences": ["dockEdge": "floating", "dockDisplayID": display.id, "dockAlongFraction": 0.27],
        ])
        try legacyBytes.write(to: legacy)
        let restoredStore = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let restored = makeDeviceApplication(root: root, executable: try reviewedExecutable(), store: restoredStore)
        await restored.prepare()
        restored.allowDockPresentation()
        let restoredHost = restored.composition.dock
        let restoredPanel = try XCTUnwrap(restoredHost.nativePanel)
        let restoredVisible = try await wait(.seconds(6)) { restoredPanel.isVisible }
        let placement = try XCTUnwrap(restoredVisible ? restoredHost.edgePresentation?.placement : nil)
        XCTAssertEqual(placement.displayID, display.id)
        XCTAssertEqual(placement.edge, .right)
        XCTAssertEqual(placement.alongFraction, 0.27, accuracy: 0.001)
        XCTAssertTrue(area.insetBy(dx: -1, dy: -1).contains(restoredPanel.frame))
        XCTAssertEqual(try Data(contentsOf: legacy), legacyBytes)
        announce("D-19 \(side)", "Capture the coordinate-less legacy fixture restored on the saved display’s right edge.")
        try await Task.sleep(for: .seconds(5))
    }

    func testD12NativeFullscreenResolutionAndWakeKeepSavedPlace() async throws {
        _ = NSApplication.shared
        let main = try XCTUnwrap(DockDisplayTopology.system().main)
        let (app, store, storedURL) = try await makeProfile(displayID: main.id, edge: .bottom)
        await app.prepare()
        XCTAssertNil(app.loginServiceAdapter)
        XCTAssertNil(app.notificationAuthorizationService)
        app.startLifecycle()
        let dock = app.composition.dock
        func visible() -> Bool {
            dock.nativePanel.map { $0.isVisible && $0.occlusionState.contains(.visible) } ?? false
        }
        let ready = try await wait(.seconds(5)) { !app.lifecyclePaused && visible() }
        guard ready else { return XCTFail("The native Dock must be visible on a regular desktop before the test starts") }
        let before = try XCTUnwrap(dock.edgePresentation?.placement)
        let initialFrame = try XCTUnwrap(dock.nativePanel?.frame)
        let initialSettings = await store.snapshot()
        let storedBytes = try Data(contentsOf: storedURL)
        XCTAssertFalse(initialSettings.preferences.showOverFullscreen)
        XCTAssertEqual(before.displayID, main.id)
        XCTAssertEqual(before.edge, .bottom)
        XCTAssertEqual(before.alongFraction, 0.62, accuracy: 0.01)

        let events = LifecycleEvents(), spaces = SpaceEvents()
        let workspace = NSWorkspace.shared.notificationCenter
        let local = NotificationCenter.default
        let spaceObserver = workspace.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { spaces.count += 1 }
        }
        let resolutionObserver = local.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { events.screens += 1 }
        }
        let sleepObserver = workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { events.sleeps += 1 }
        }
        let wakeObserver = workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { events.wakes += 1 }
        }
        defer {
            workspace.removeObserver(spaceObserver)
            local.removeObserver(resolutionObserver)
            workspace.removeObserver(sleepObserver)
            workspace.removeObserver(wakeObserver)
        }

        announce("D-12", "Enter full screen with the approved synthetic receiver on the primary display")
        let entered = try await wait(.seconds(30)) { spaces.count > 0 && !visible() }
        guard entered else { return XCTFail("The Dock stayed visible or no public Space change was observed") }
        let inFullscreen = spaces.count
        announce("D-12", "Exit full screen back to the original desktop")
        let returned = try await wait(.seconds(30)) { spaces.count > inFullscreen && visible() }
        guard returned else { return XCTFail("The Dock did not return after the fullscreen Space") }
        XCTAssertEqual(dock.nativePanel?.frame, initialFrame)

        let screenEvents = events.screens
        announce("D-12", "Change the primary display resolution so its logical size changes")
        let resized = try await wait(.seconds(45)) {
            guard let current = DockDisplayTopology.system().display(main.id) else { return false }
            return events.screens > screenEvents && current.frame.size != main.frame.size && visible()
        }
        guard resized else { return XCTFail("No logical resolution change was observed for the same display") }
        let changedDisplay = try XCTUnwrap(DockDisplayTopology.system().display(main.id))
        let afterResize = try XCTUnwrap(dock.edgePresentation?.placement)
        let resizedFrame = try XCTUnwrap(dock.nativePanel?.frame)
        XCTAssertEqual(afterResize.displayID, main.id)
        XCTAssertEqual(afterResize.edge, before.edge)
        XCTAssertEqual(afterResize.alongFraction, before.alongFraction, accuracy: 0.01)
        XCTAssertEqual(resizedFrame.minY, changedDisplay.visibleFrame.minY, accuracy: 1)
        XCTAssertEqual(try Data(contentsOf: storedURL), storedBytes)

        let sleeps = events.sleeps, wakes = events.wakes
        announce("D-12", "Sleep and wake the Mac, then return to the same unlocked desktop")
        let woke = try await wait(.seconds(120)) {
            events.sleeps > sleeps && events.wakes > wakes && !app.lifecyclePaused && visible()
        }
        guard woke else { return XCTFail("No completed native sleep/wake and restored Dock were observed") }
        XCTAssertEqual(dock.edgePresentation?.placement, afterResize)
        XCTAssertEqual(dock.nativePanel?.frame, resizedFrame)
        let final = await store.snapshot()
        XCTAssertEqual(final.revision, initialSettings.revision)
        XCTAssertEqual(try Data(contentsOf: storedURL), storedBytes)
    }

    func testD17NativePanelStaysAcrossSpacesAndFollowsWithoutSaving() async throws {
        _ = NSApplication.shared
        let topology = DockDisplayTopology.system()
        let main = try XCTUnwrap(topology.main)
        let neighbour = try XCTUnwrap(topology.displays.first {
            $0.id != main.id && !$0.frame.intersects(main.frame)
        }, "D-17 requires two real, non-mirrored displays")
        let (app, store, storedURL) = try await makeProfile(displayID: main.id, edge: .right)

        await app.prepare()
        XCTAssertNil(app.loginServiceAdapter)
        XCTAssertNil(app.notificationAuthorizationService)
        app.allowDockPresentation()
        let delivery = try await app.composition.client.start()
        XCTAssertEqual(app.composition.store.snapshot.connection, .ready(delivery))
        let dock = app.composition.dock
        let panel = try XCTUnwrap(dock.nativePanel)
        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
        let original = try XCTUnwrap(dock.edgePresentation?.placement)
        XCTAssertEqual(original.displayID, main.id)
        XCTAssertEqual(original.edge, .right)
        let originalFrame = panel.frame
        let fixedBytes = try Data(contentsOf: storedURL)
        let fixed = await store.snapshot()
        func visible() -> Bool { panel.isVisible && panel.occlusionState.contains(.visible) }
        let initiallyVisible = try await wait(.seconds(2), until: visible)
        guard initiallyVisible else { return XCTFail("The real Dock panel did not become visible") }
        announce("D-17", "Place the pointer on the primary display")
        let startsOnPrimary = try await wait(.seconds(30)) { main.frame.contains(NSEvent.mouseLocation) }
        guard startsOnPrimary else { return XCTFail("No pointer input on the primary display") }

        let events = SpaceEvents()
        let notifications = NSWorkspace.shared.notificationCenter
        let token = notifications.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { events.count += 1 }
        }
        defer { notifications.removeObserver(token) }

        for step in ["Switch to the second regular desktop Space on the primary display",
                     "Switch back to the original regular desktop Space on the primary display"] {
            let before = events.count
            announce("D-17", step)
            let changed = try await wait(.seconds(30)) { events.count > before }
            guard changed else { return XCTFail("The expected public Space change was not observed") }
            try await Task.sleep(for: .milliseconds(300))
            let shown = try await wait(.seconds(3), until: visible)
            XCTAssertTrue(shown)
            XCTAssertEqual(panel.frame, originalFrame)
            XCTAssertEqual(dock.edgePresentation?.placement, original)
            XCTAssertEqual(try Data(contentsOf: storedURL), fixedBytes)
        }

        announce("D-17", "Move the pointer to the second display with Follow off")
        let onNeighbour = try await wait(.seconds(30)) { neighbour.frame.contains(NSEvent.mouseLocation) }
        guard onNeighbour else { return XCTFail("No pointer input on the second display") }
        dock.refreshPresence()
        XCTAssertEqual(panel.frame, originalFrame)
        XCTAssertEqual(dock.edgePresentation?.placement, original)
        let afterFixed = await store.snapshot()
        XCTAssertEqual(afterFixed.revision, fixed.revision)
        XCTAssertEqual(try Data(contentsOf: storedURL), fixedBytes)

        announce("D-17", "Keep the pointer on the second display while Follow is enabled")
        let editor = app.settingsHost.application.editor
        _ = try await editor.commit(SettingsB21Edit.activeDisplay(true))
        let follow = await store.snapshot()
        let followBytes = try Data(contentsOf: storedURL)
        let moved = try await wait(.seconds(5)) {
            dock.edgePresentation?.placement?.displayID == neighbour.id && visible()
        }
        guard moved else { return XCTFail("The native Dock did not follow the second display") }
        let followed = try XCTUnwrap(dock.edgePresentation?.placement)
        XCTAssertEqual(followed.edge, original.edge)
        XCTAssertEqual(followed.alongFraction, original.alongFraction, accuracy: 0.01)
        XCTAssertEqual(panel.frame.maxX, neighbour.visibleFrame.maxX, accuracy: 1)
        XCTAssertEqual(follow.preferences.dockDisplayID, main.id)
        XCTAssertEqual(follow.preferences.dockAlongFraction, fixed.preferences.dockAlongFraction)

        announce("D-17", "Move the pointer back to the primary display with Follow on")
        let returned = try await wait(.seconds(30)) {
            main.frame.contains(NSEvent.mouseLocation) &&
                dock.edgePresentation?.placement?.displayID == main.id && visible()
        }
        guard returned else { return XCTFail("The native Dock did not return to the primary display") }
        XCTAssertEqual(panel.frame, originalFrame)
        let afterFollow = await store.snapshot()
        XCTAssertEqual(afterFollow.revision, follow.revision)
        XCTAssertEqual(try Data(contentsOf: storedURL), followBytes)
    }
}
#endif
