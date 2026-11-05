// SPDX-License-Identifier: MIT
#if MODELPLAN_DOCK_NATIVE_JOURNEY && MODELPLAN_DOCK_REAL_SPACES_JOURNEY
import AppKit
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanShell
import ModelPlanSettings
import XCTest
@testable import ModelPlanAppIntegration

/// Operator-driven. Run only during an admitted two-display, two-Space session.
@MainActor final class DockRealSpacesJourneyTests: XCTestCase {
    @MainActor private final class SpaceEvents {
        var count = 0
    }

    private func makeProfile(displayID: String, edge: SettingsDockEdge, declaredQuotas: [Int] = [],
                             autoHide: Bool = false, along: Double = 0.62) async throws
        -> (EngineDockMenuApplication, SettingsStore, URL) {
        let executable = URL(fileURLWithPath: try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_DOCK_TEST_CLI"]))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: executable.path))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dock-device-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        let environment = ["HOME": root.path, "TMPDIR": root.path, "PATH": "/usr/bin:/bin", "LANG": "C"]
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
        EngineRowsEntry.nativeJourneyProfile = root
        let app = EngineRowsEntry.make(configuration: .init(executableURL: executable, applicationVersion: "synthetic-dock-device",
            allowedEnvironment: environment, offline: true, readOnly: true), settingsStore: store,
            createsNativePanels: true, bundleURL: root.appendingPathComponent("Synthetic.app"), activateSettings: {})
        addTeardownBlock { @MainActor in
            await app.stopNativeDockJourney()
            EngineRowsEntry.nativeJourneyProfile = nil
        }

        return (app, store, root.appendingPathComponent("ModelPlan/settings.json"))
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
