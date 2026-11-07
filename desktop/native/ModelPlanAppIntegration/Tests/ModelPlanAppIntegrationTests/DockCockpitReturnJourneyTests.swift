// SPDX-License-Identifier: MIT
#if MODELPLAN_DOCK_NATIVE_JOURNEY
import AppKit
import XCTest
import ModelPlanCockpitWeb
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanSettings
import ModelPlanWire
@testable import ModelPlanAppIntegration

@MainActor private final class ReturnPage: CockpitPageSurface {
    let queryTicket: CockpitQueryTicket? = nil
    var onReady: (() -> Void)?
    var onIntent: ((CockpitIntent) -> Void)?
    var onClosed: (() -> Void)?
    private(set) var visible = false

    func open() { visible = true }
    func display(_ data: WireCockpitData, ticket: CockpitQueryTicket) {}
    func clearPrivateViews(adopting: CockpitEngineContext?) async {}
    func discard() { visible = false; onClosed?() }
}

@MainActor final class DockCockpitReturnJourneyTests: XCTestCase {
    func testD22NormalCockpitCloseRestoresTheCorrectSurface() async throws {
        try await exercise(native: false)
    }

    func testD22NativeDockReturnsFromCockpit() async throws {
        try await exercise(native: true)
    }

    private func exercise(native: Bool) async throws {
        let binary = try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_DOCK_TEST_CLI"])
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: binary))
        let display: DockDisplayArea
        if native {
            _ = NSApplication.shared
            let screen = try XCTUnwrap(NSScreen.main)
            display = .init(id: "test-display", frame: screen.frame, visibleFrame: screen.visibleFrame)
        } else {
            display = .init(id: "test-display", frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                            visibleFrame: CGRect(x: 0, y: 72, width: 1440, height: 804))
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dock-return-" + UUID().uuidString)
        let config = root.appendingPathComponent(".config/modelplan")
        try FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        let environment = ["HOME": root.path, "TMPDIR": root.path, "PATH": "/usr/bin:/bin", "LANG": "C"]
        let seed = Process()
        seed.executableURL = URL(fileURLWithPath: binary)
        seed.arguments = ["consent", "init", "--json"]
        seed.environment = environment
        seed.standardInput = FileHandle.nullDevice
        seed.standardOutput = FileHandle.nullDevice
        seed.standardError = FileHandle.nullDevice
        try seed.run()
        let seedDeadline = ContinuousClock.now + .seconds(5)
        while seed.isRunning && ContinuousClock.now < seedDeadline { try await Task.sleep(for: .milliseconds(10)) }
        if seed.isRunning { seed.terminate(); return XCTFail("Temporary consent initialization timed out") }
        XCTAssertEqual(seed.terminationStatus, 0, "Seed only the temporary consent store")
        let plan = "synthetic-d22"
        let iso = ISO8601DateFormatter()
        let now = Date()
        let fixture: [String: Any] = ["schemaVersion": 1, "plans": [["planId": plan]], "windows": [[
            "planId": plan, "kind": "five_hour", "remainingPercent": 57, "resetMode": "rolling",
            "observedAt": iso.string(from: now.addingTimeInterval(-15)),
            "resetAt": iso.string(from: now.addingTimeInterval(7_200))
        ]]]
        try JSONSerialization.data(withJSONObject: fixture).write(to: config.appendingPathComponent("local.json"), options: .atomic)
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        _ = try await store.update { $0.autoHide = true; $0.theme = .night; $0.motion = .on }
        let page = ReturnPage()
        let cockpit = EngineCockpitCoordinator { _ in page }
        let owner = CockpitConsoleOwner(bundle: root, settingsStore: store)
        owner.coordinator = cockpit
        let outside = CGPoint(x: display.visibleFrame.midX, y: display.visibleFrame.midY)
        var pointer = outside
        if native { EngineRowsEntry.nativeJourneyProfile = root }
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: binary),
            applicationVersion: "dock-cockpit-return", allowedEnvironment: environment,
            offline: true, readOnly: true), settingsStore: store, createsNativePanels: native,
            bundleURL: root.appendingPathComponent("Synthetic.app"), cockpitEntryEnabled: true,
            dockEnvironment: { .init(displays: [display], layouts: [], primaryDisplayID: display.id, pointer: pointer) },
            makeConsole: { composition in
                SharedEngineCockpitConsole(owner: owner, composition: composition, isForeground: { false }, activate: {})
            }, activateSettings: {})
        addTeardownBlock { @MainActor in
            await cockpit.shutdown()
            await app.stopNativeDockJourney()
            if native { EngineRowsEntry.nativeJourneyProfile = nil }
        }
        cockpit.bind(client: app.composition.client)
        await app.prepare()
        XCTAssertNil(app.loginServiceAdapter)
        XCTAssertNil(app.notificationAuthorizationService)
        app.allowDockPresentation()
        let delivery = try await app.composition.client.start()
        XCTAssertEqual(app.composition.store.snapshot.connection, .ready(delivery))
        let dock = app.composition.dock
        let rowsDeadline = ContinuousClock.now + .seconds(4)
        func observedQuota() -> Bool {
            dock.dockView.presentedReadingsForChecks.values.contains { $0.remainingPercent == 57 }
        }
        while !observedQuota() && ContinuousClock.now < rowsDeadline { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(observedQuota(), "Require the real app-server's declared quota in the rendered widget")
        // The fake page uses the real delivery and borrowed client without a WebKit window.
        await cockpit.consume(.context(delivery))

        let editor = app.settingsHost.application.editor
        func move(to point: CGPoint) {
            pointer = point
            dock.refreshPresence()
        }
        func waitForSurface(_ expected: DockSurfaceState) async throws {
            let end = ContinuousClock.now + .seconds(2)
            while dock.edgePresentation?.state != expected && ContinuousClock.now < end {
                try await Task.sleep(for: .milliseconds(10))
            }
            XCTAssertEqual(dock.edgePresentation?.state, expected)
        }
        for size in SettingsSize.allCases {
            _ = try await editor.commit(SettingsB20Edit.size(size))
            let placement = try XCTUnwrap(dock.edgePresentation?.placement)
            XCTAssertEqual(placement.edge, .right)
            let wake = CGPoint(x: placement.wakeFrame.maxX - 19, y: placement.wakeFrame.midY)
            let beyondDepth = CGPoint(x: wake.x - 2, y: wake.y)
            let beyondEnd = CGPoint(x: wake.x, y: placement.wakeFrame.minY - 19)
            move(to: outside)
            try await waitForSurface(.sliver)
            for point in [beyondDepth, beyondEnd] {
                move(to: point)
                // Give each outside point more than the default 150 ms reveal dwell.
                try await Task.sleep(for: .milliseconds(225))
                XCTAssertEqual(dock.edgePresentation?.state, .sliver, "\(size) at \(point)")
            }
            move(to: wake)
            try await waitForSurface(.expanded)
            try await Task.sleep(for: .milliseconds(550))
            XCTAssertEqual(dock.edgePresentation?.state, .expanded, "The wake band stays inside after reveal")
            // A main-thread stall on a hosted Mac can outlast the 500 ms grace before the test looks.
            // Such a try proves nothing about the hide, so it goes again; only an in-time look counts.
            var inTime = false
            for _ in 0..<5 where !inTime {
                let left = ContinuousClock.now
                move(to: outside)
                try await Task.sleep(for: .milliseconds(200))
                let state = dock.edgePresentation?.state
                if left.duration(to: .now) < .milliseconds(450) {
                    inTime = true
                    XCTAssertEqual(state, .expanded, "The first absence is shorter than the hide grace")
                }
                move(to: wake)
                if inTime {
                    try await Task.sleep(for: .milliseconds(150))
                    XCTAssertEqual(dock.edgePresentation?.state, .expanded, "Returning to the wake band cancels the hide")
                } else { try await waitForSurface(.expanded) }
            }
            XCTAssertTrue(inTime, "No in-time look at the hide grace in five tries")
            move(to: outside)
            // A fixed 550 ms left a 500 ms grace 50 ms of slack on a loaded hosted Mac.
            try await waitForSurface(.sliver)
            let panelOnly = try XCTUnwrap(placement.globalHoverRects.map {
                CGPoint(x: $0.midX, y: $0.midY)
            }.first { display.usableFrame.contains($0) && !placement.wakeFrame.contains($0) })
            for (point, expected) in [(outside, DockSurfaceState.sliver), (wake, .expanded), (panelOnly, .expanded)] {
                app.showConsole()
                XCTAssertNil(dock.edgePresentation?.paintedFrame, "Opening must withdraw the Dock synchronously")
                if native { XCTAssertFalse(dock.nativePanel?.isVisible == true) }
                let end = ContinuousClock.now + .seconds(2)
                while !page.visible && ContinuousClock.now < end { try await Task.sleep(for: .milliseconds(5)) }
                XCTAssertTrue(page.visible)
                move(to: point)
                XCTAssertNil(dock.edgePresentation?.paintedFrame, "Pointer movement cannot reveal over an open cockpit")
                cockpit.requestClose()
                XCTAssertFalse(page.visible)
                let restored = try XCTUnwrap(dock.edgePresentation)
                XCTAssertEqual(restored.state, expected, "\(size) at \(point)")
                let frame = expected == .expanded ? placement.frame : placement.sliverFrame
                XCTAssertEqual(restored.paintedFrame, frame)
                if native {
                    let panel = try XCTUnwrap(dock.nativePanel)
                    XCTAssertTrue(panel.isVisible)
                    XCTAssertEqual(panel.frame.minX, frame.minX, accuracy: 1)
                    XCTAssertEqual(panel.frame.minY, frame.minY, accuracy: 1)
                    XCTAssertEqual(panel.frame.width, frame.width, accuracy: 1)
                    XCTAssertEqual(panel.frame.height, frame.height, accuracy: 1)
                }
                move(to: outside)
            }
        }
    }
}
#endif
