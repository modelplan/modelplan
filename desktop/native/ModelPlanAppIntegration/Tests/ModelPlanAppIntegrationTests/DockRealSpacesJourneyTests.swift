// SPDX-License-Identifier: MIT
#if MODELPLAN_DOCK_NATIVE_JOURNEY && MODELPLAN_DOCK_REAL_SPACES_JOURNEY
import AppKit
import ModelPlanDock
import ModelPlanSettings
import XCTest
@testable import ModelPlanAppIntegration

/// Operator-driven. Run only during an admitted two-display, two-Space session.
@MainActor final class DockRealSpacesJourneyTests: XCTestCase {
    @MainActor private final class SpaceEvents {
        var count = 0
    }

    private func makeProfile(displayID: String, edge: SettingsDockEdge) async throws
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

        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        _ = try await store.update {
            $0.autoHide = false
            $0.followActiveDisplay = false
            $0.dockDisplayID = displayID
            $0.dockEdge = edge
            $0.dockAlongFraction = 0.62
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

    @MainActor private final class LifecycleEvents {
        var screens = 0
        var sleeps = 0
        var wakes = 0
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
