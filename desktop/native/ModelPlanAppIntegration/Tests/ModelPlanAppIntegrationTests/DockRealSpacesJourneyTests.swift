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

    func testD17NativePanelStaysAcrossSpacesAndFollowsWithoutSaving() async throws {
        _ = NSApplication.shared
        let topology = DockDisplayTopology.system()
        let main = try XCTUnwrap(topology.main)
        let neighbour = try XCTUnwrap(topology.displays.first {
            $0.id != main.id && !$0.frame.intersects(main.frame)
        }, "D-17 requires two real, non-mirrored displays")
        let executable = URL(fileURLWithPath: try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_DOCK_TEST_CLI"]))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: executable.path))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("d17-spaces-" + UUID().uuidString)
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
        if seed.isRunning { seed.terminate(); return XCTFail("Temporary consent initialization timed out") }
        XCTAssertEqual(seed.terminationStatus, 0)

        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        _ = try await store.update {
            $0.autoHide = false
            $0.followActiveDisplay = false
            $0.dockDisplayID = main.id
            $0.dockEdge = .right
            $0.dockAlongFraction = 0.62
        }
        EngineRowsEntry.nativeJourneyProfile = root
        let app = EngineRowsEntry.make(configuration: .init(executableURL: executable, applicationVersion: "synthetic-d17",
            allowedEnvironment: environment, offline: true, readOnly: true), settingsStore: store,
            createsNativePanels: true, bundleURL: root.appendingPathComponent("Synthetic.app"), activateSettings: {})
        addTeardownBlock { @MainActor in
            await app.stopNativeDockJourney()
            EngineRowsEntry.nativeJourneyProfile = nil
        }

        func wait(_ duration: Duration, until condition: () -> Bool) async throws -> Bool {
            let end = ContinuousClock.now + duration
            while !condition() && ContinuousClock.now < end { try await Task.sleep(for: .milliseconds(20)) }
            return condition()
        }
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
        let storedURL = root.appendingPathComponent("ModelPlan/settings.json")
        let fixedBytes = try Data(contentsOf: storedURL)
        let fixed = await store.snapshot()
        func visible() -> Bool { panel.isVisible && panel.occlusionState.contains(.visible) }
        func announce(_ instruction: String) {
            FileHandle.standardOutput.write(Data(("D-17: " + instruction + "\n").utf8))
        }
        let initiallyVisible = try await wait(.seconds(2), until: visible)
        guard initiallyVisible else { return XCTFail("The real Dock panel did not become visible") }
        announce("Place the pointer on the primary display")
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
            announce(step)
            let changed = try await wait(.seconds(30)) { events.count > before }
            guard changed else { return XCTFail("The expected public Space change was not observed") }
            try await Task.sleep(for: .milliseconds(300))
            let shown = try await wait(.seconds(3), until: visible)
            XCTAssertTrue(shown)
            XCTAssertEqual(panel.frame, originalFrame)
            XCTAssertEqual(dock.edgePresentation?.placement, original)
            XCTAssertEqual(try Data(contentsOf: storedURL), fixedBytes)
        }

        announce("Move the pointer to the second display with Follow off")
        let onNeighbour = try await wait(.seconds(30)) { neighbour.frame.contains(NSEvent.mouseLocation) }
        guard onNeighbour else { return XCTFail("No pointer input on the second display") }
        dock.refreshPresence()
        XCTAssertEqual(panel.frame, originalFrame)
        XCTAssertEqual(dock.edgePresentation?.placement, original)
        let afterFixed = await store.snapshot()
        XCTAssertEqual(afterFixed.revision, fixed.revision)
        XCTAssertEqual(try Data(contentsOf: storedURL), fixedBytes)

        announce("Keep the pointer on the second display while Follow is enabled")
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

        announce("Move the pointer back to the primary display with Follow on")
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
