// SPDX-License-Identifier: MIT
#if MODELPLAN_DOCK_NATIVE_JOURNEY && MODELPLAN_DOCK_REAL_SPACES_JOURNEY
import AppKit
import ModelPlanDock
import ModelPlanSettings
import XCTest
@testable import ModelPlanAppIntegration

/// Operator-driven. Run only during an admitted GUI session with the required topology.
@MainActor final class DockRealSpacesJourneyTests: XCTestCase {
    @MainActor private final class SpaceEvents {
        var count = 0
    }

    private func makeProfile(displayID: String, edge: SettingsDockEdge) async throws
        -> (EngineDockMenuApplication, SettingsStore, URL) {
        let executable = try reviewedExecutable()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dock-device-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        let environment = isolatedEnvironment(root)
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

        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        _ = try await store.update {
            $0.autoHide = false
            $0.followActiveDisplay = false
            $0.dockDisplayID = displayID
            $0.dockEdge = edge
            $0.dockAlongFraction = 0.62
        }
        return (makeApplication(root: root, executable: executable, store: store), store,
                root.appendingPathComponent("ModelPlan/settings.json"))
    }

    private func reviewedExecutable() throws -> URL {
        let executable = URL(fileURLWithPath: try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_DOCK_TEST_CLI"]))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: executable.path))
        return executable
    }

    private func isolatedEnvironment(_ root: URL) -> [String: String] {
        ["HOME": root.path, "TMPDIR": root.path, "PATH": "/usr/bin:/bin", "LANG": "C"]
    }

    private func makeApplication(root: URL, executable: URL, store: SettingsStore) -> EngineDockMenuApplication {
        EngineRowsEntry.nativeJourneyProfile = root
        let app = EngineRowsEntry.make(configuration: .init(executableURL: executable, applicationVersion: "synthetic-dock-device",
            allowedEnvironment: isolatedEnvironment(root), offline: true, readOnly: true), settingsStore: store,
            createsNativePanels: true, bundleURL: root.appendingPathComponent("Synthetic.app"), activateSettings: {})
        addTeardownBlock { @MainActor in
            await app.stopNativeDockJourney()
            EngineRowsEntry.nativeJourneyProfile = nil
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

    @MainActor private final class LifecycleEvents {
        var screens = 0
        var sleeps = 0
        var wakes = 0
    }

    func testD02PhysicalRightEdgeSurvivesDockMoveAndDisplayPowerCycle() async throws {
        _ = NSApplication.shared
        let topology = DockDisplayTopology.system()
        let main = try XCTUnwrap(topology.main)
        let neighbour = try XCTUnwrap(topology.displays.first {
            abs($0.frame.minX - main.frame.maxX) <= 1 &&
                min($0.frame.maxY, main.frame.maxY) > max($0.frame.minY, main.frame.minY)
        }, "D-02 needs an actual non-mirrored display adjoining the primary on the right")
        guard main.usableFrame.minY - main.frame.minY >= 8 else {
            return XCTFail("Start with the macOS Dock at the bottom and auto-hide off")
        }
        let (first, store, storedURL) = try await makeProfile(displayID: main.id, edge: .right)
        let saved = await store.snapshot()
        let bytes = try Data(contentsOf: storedURL)
        func assertRight(_ app: EngineDockMenuApplication, label: String) throws {
            let current = try XCTUnwrap(DockDisplayTopology.system().display(main.id))
            let host = app.composition.dock
            let panel = try XCTUnwrap(host.nativePanel)
            let placement = try XCTUnwrap(host.edgePresentation?.placement)
            XCTAssertTrue(panel.isVisible && panel.occlusionState.contains(.visible), label)
            XCTAssertEqual(placement.displayID, main.id, label)
            XCTAssertEqual(placement.edge, .right, label)
            XCTAssertEqual(placement.alongFraction, 0.62, accuracy: 0.01, label)
            XCTAssertEqual(panel.frame.maxX, current.usableFrame.maxX, accuracy: 1, label)
            XCTAssertTrue(current.usableFrame.insetBy(dx: -1, dy: -1).contains(panel.frame), label)
            XCTAssertEqual(try Data(contentsOf: storedURL), bytes, label)
            announce("D-02", "Capture \(label) now.")
        }
        func launch(_ app: EngineDockMenuApplication) async throws {
            await app.prepare()
            XCTAssertNil(app.loginServiceAdapter)
            XCTAssertNil(app.notificationAuthorizationService)
            app.startLifecycle()
            let visible = try await wait(.seconds(10)) {
                app.composition.dock.nativePanel?.isVisible == true && !app.lifecyclePaused
            }
            XCTAssertTrue(visible)
        }
        try await launch(first)
        try assertRight(first, label: "first launch with the right neighbour and bottom system Dock")
        try await Task.sleep(for: .seconds(4))
        await first.stopNativeDockJourney()

        let root = storedURL.deletingLastPathComponent().deletingLastPathComponent()
        let reopened = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let app = makeApplication(root: root, executable: try reviewedExecutable(), store: reopened)
        try await launch(app)
        try assertRight(app, label: "reopened profile")
        let host = app.composition.dock
        let previousPlacement = host.onPlacementObserved
        var nonRightPlacements: [DockEdge] = []
        host.onPlacementObserved = { placement, recovering in
            previousPlacement?(placement, recovering)
            if let placement, placement.edge != .right { nonRightPlacements.append(placement.edge) }
        }
        defer { host.onPlacementObserved = previousPlacement }
        let transitions: [(String, (DockDisplayTopology, DockDisplayArea) -> Bool)] = [
            ("Move the macOS Dock to the left", { _, screen in screen.usableFrame.minX - screen.frame.minX >= 8 }),
            ("Move the macOS Dock back to the bottom", { _, screen in screen.usableFrame.minY - screen.frame.minY >= 8 }),
            ("Power off or disconnect the right display", { topology, _ in topology.display(neighbour.id) == nil }),
            ("Power the right display back on or reconnect it", { topology, _ in topology.display(neighbour.id) != nil }),
        ]
        for (instruction, changed) in transitions {
            announce("D-02", instruction)
            let settled = try await wait(.seconds(60)) {
                let current = DockDisplayTopology.system()
                guard let screen = current.display(main.id), changed(current, screen),
                      let frame = app.composition.dock.nativePanel?.frame else { return false }
                return app.composition.dock.nativePanel?.isVisible == true &&
                    app.composition.dock.edgePresentation?.placement?.edge == .right &&
                    abs(frame.maxX - screen.usableFrame.maxX) <= 1 &&
                    screen.usableFrame.insetBy(dx: -1, dy: -1).contains(frame)
            }
            guard settled else { return XCTFail("No settled physical right placement after: \(instruction)") }
            try assertRight(app, label: instruction)
            try await Task.sleep(for: .seconds(4))
        }
        XCTAssertTrue(nonRightPlacements.isEmpty, "Transient placements changed the saved edge: \(nonRightPlacements)")
        let after = await reopened.snapshot()
        XCTAssertEqual(after.revision, saved.revision)
        XCTAssertEqual(after.preferences.dockDisplayID, main.id)
        XCTAssertEqual(after.preferences.dockEdge, .right)
    }

    func testD03PhysicalBottomStaysStableWhenSystemDockAutoHides() async throws {
        _ = NSApplication.shared
        let initial = try XCTUnwrap(DockDisplayTopology.system().main)
        let reserved = initial.usableFrame.minY - initial.frame.minY
        guard reserved >= 8 else { return XCTFail("Start with the macOS Dock at the bottom and auto-hide off") }
        let (app, store, storedURL) = try await makeProfile(displayID: initial.id, edge: .bottom)
        await app.prepare()
        app.startLifecycle()
        let host = app.composition.dock
        let shown = try await wait(.seconds(10)) { host.nativePanel?.isVisible == true && !app.lifecyclePaused }
        let panel = try XCTUnwrap(shown ? host.nativePanel : nil)
        XCTAssertEqual(host.edgePresentation?.placement?.edge, .bottom)
        XCTAssertEqual(panel.frame.minY, initial.usableFrame.minY, accuracy: 1)
        XCTAssertTrue(initial.usableFrame.insetBy(dx: -1, dy: -1).contains(panel.frame))
        let before = await store.snapshot()
        let bytes = try Data(contentsOf: storedURL)
        announce("D-03", "Capture the widget above the visible macOS Dock. Then enable macOS Dock auto-hide.")
        let adjusted = try await wait(.seconds(60)) {
            guard let display = DockDisplayTopology.system().display(initial.id) else { return false }
            return display.usableFrame.minY - display.frame.minY < reserved - 5 && panel.isVisible &&
                host.edgePresentation?.placement?.edge == .bottom &&
                abs(panel.frame.minY - display.usableFrame.minY) <= 1
        }
        guard adjusted else { return XCTFail("The native bottom widget did not follow the new available floor") }
        let autoHidden = try XCTUnwrap(DockDisplayTopology.system().display(initial.id))
        let settledFrame = panel.frame
        var moved = false
        let observer = NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification,
            object: panel, queue: .main) { _ in
                MainActor.assumeIsolated { if panel.frame != settledFrame { moved = true } }
            }
        defer { NotificationCenter.default.removeObserver(observer) }
        let triggerX = settledFrame.midX < autoHidden.frame.midX
            ? min(autoHidden.frame.maxX - 6, settledFrame.maxX + 24)
            : max(autoHidden.frame.minX + 6, settledFrame.minX - 24)
        let wake = CGRect(x: triggerX - 12, y: autoHidden.frame.minY, width: 24, height: 4)
        let away = autoHidden.frame.insetBy(dx: autoHidden.frame.width * 0.15, dy: autoHidden.frame.height * 0.15)
        func remainStable(_ duration: Duration, label: String) async throws {
            let end = ContinuousClock.now + duration
            while ContinuousClock.now < end {
                XCTAssertEqual(panel.frame, settledFrame, label)
                XCTAssertEqual(DockDisplayTopology.system().display(initial.id)?.usableFrame, autoHidden.usableFrame, label)
                try await Task.sleep(for: .milliseconds(30))
            }
        }
        announce("D-03", "Move the pointer to the physical bottom near \(Int(triggerX)) x, away from the widget, to reveal the macOS Dock. Hold for capture.")
        guard try await wait(.seconds(35), until: { wake.contains(NSEvent.mouseLocation) }) else {
            return XCTFail("No physical system-Dock wake movement arrived")
        }
        try await remainStable(.seconds(3), label: "system Dock revealed")
        announce("D-03", "Move the pointer toward the display centre, let the system Dock hide and capture both positions.")
        guard try await wait(.seconds(25), until: { away.contains(NSEvent.mouseLocation) }) else {
            return XCTFail("No physical pointer withdrawal arrived")
        }
        try await remainStable(.seconds(3), label: "system Dock auto-hidden")
        XCTAssertFalse(moved, "The widget must not move during the transient macOS Dock animation")
        XCTAssertEqual(host.edgePresentation?.placement?.edge, .bottom)
        let after = await store.snapshot()
        XCTAssertEqual(after.revision, before.revision)
        XCTAssertEqual(try Data(contentsOf: storedURL), bytes)
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
