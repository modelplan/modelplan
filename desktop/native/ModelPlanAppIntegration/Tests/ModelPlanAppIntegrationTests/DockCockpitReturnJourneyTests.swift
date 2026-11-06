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

    func testD22NormalCockpitCloseRestoresLeftAndBottomSurfaces() async throws {
        try await exercise(native: false, edges: [.left, .bottom])
    }

    func testD22NativeDockReturnsFromCockpit() async throws {
        try await exercise(native: true)
    }

    #if MODELPLAN_DOCK_REAL_STRIP_JOURNEY
    func testD22PhysicalPointerMeasuresWakeAndLeaveOnEachSize() async throws {
        try await exercise(native: true, physicalPointer: true)
    }
    #endif

    private func exercise(native: Bool, physicalPointer: Bool = false,
                          edges: [SettingsDockEdge] = [.right]) async throws {
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
        let readDisplay: (@MainActor () -> DockEdgeEnvironment)?
        if physicalPointer { readDisplay = nil }
        else { readDisplay = { .init(displays: [display], layouts: [], primaryDisplayID: display.id, pointer: pointer) } }
        if native { EngineRowsEntry.nativeJourneyProfile = root }
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: binary),
            applicationVersion: "dock-cockpit-return", allowedEnvironment: environment,
            offline: true, readOnly: true), settingsStore: store, createsNativePanels: native,
            bundleURL: root.appendingPathComponent("Synthetic.app"), cockpitEntryEnabled: true,
            dockEnvironment: readDisplay,
            makeConsole: { composition in
                SharedEngineCockpitConsole(owner: owner, composition: composition, isForeground: { false }, activate: {})
            }, activateSettings: {})
        addTeardownBlock { @MainActor in
            await cockpit.shutdown()
            await app.stopNativeDockJourney()
            if native { EngineRowsEntry.nativeJourneyProfile = nil }
        }
        #if DEBUG
        let visibilityClock = native ? nil : DockVisibilityTestClock()
        if let visibilityClock {
            EngineRowsEntry.installDockVisibilityTimingForChecks(on: app, clock: { visibilityClock.now },
                                                               scheduler: visibilityClock)
        }
        let usesControlledVisibility = visibilityClock != nil
        #else
        let usesControlledVisibility = false
        #endif
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
        #if MODELPLAN_DOCK_REAL_STRIP_JOURNEY
        if physicalPointer {
            try await observePhysicalWakeAndLeave(app, store: store, root: root)
            return
        }
        #endif
        // The fake page uses the real delivery and borrowed client without a WebKit window.
        await cockpit.consume(.context(delivery))

        let editor = app.settingsHost.application.editor
        func move(to point: CGPoint) {
            pointer = point
            dock.refreshPresence()
        }
        func advanceVisibility(milliseconds: Int) async throws {
            #if DEBUG
            if let visibilityClock {
                visibilityClock.advance(by: Double(milliseconds) / 1000)
                return
            }
            #endif
            try await Task.sleep(for: .milliseconds(milliseconds))
        }
        func waitForSurface(_ expected: DockSurfaceState) async throws {
            if usesControlledVisibility {
                if dock.edgePresentation?.state != expected {
                    try await advanceVisibility(milliseconds: 550)
                }
                XCTAssertEqual(dock.edgePresentation?.state, expected)
                return
            }
            let end = ContinuousClock.now + .seconds(2)
            while dock.edgePresentation?.state != expected && ContinuousClock.now < end {
                try await Task.sleep(for: .milliseconds(10))
            }
            XCTAssertEqual(dock.edgePresentation?.state, expected)
        }
        let settingsURL = root.appendingPathComponent("ModelPlan/settings.json")
        for preference in edges {
            move(to: outside)
            _ = try await editor.commit(SettingsB21Edit.dockEdge(preference))
            let edge: DockEdge = switch preference {
            case .left: .left
            case .right: .right
            case .bottom: .bottom
            }
            for size in SettingsSize.allCases {
                _ = try await editor.commit(SettingsB20Edit.size(size))
                let placement = try XCTUnwrap(dock.edgePresentation?.placement)
                XCTAssertEqual(placement.edge, edge)
                let wakeRect = placement.wakeFrame
                let wake: CGPoint, beyondDepth: CGPoint, beyondEnd: CGPoint
                switch edge {
                case .left:
                    XCTAssertEqual(wakeRect.width, 20, accuracy: 0.001)
                    wake = CGPoint(x: wakeRect.minX + 19, y: wakeRect.midY)
                    beyondDepth = CGPoint(x: wake.x + 2, y: wake.y)
                    beyondEnd = CGPoint(x: wake.x, y: wakeRect.minY - 19)
                case .right:
                    XCTAssertEqual(wakeRect.width, 20, accuracy: 0.001)
                    wake = CGPoint(x: wakeRect.maxX - 19, y: wakeRect.midY)
                    beyondDepth = CGPoint(x: wake.x - 2, y: wake.y)
                    beyondEnd = CGPoint(x: wake.x, y: wakeRect.minY - 19)
                case .bottom:
                    XCTAssertEqual(wakeRect.height, 20, accuracy: 0.001)
                    wake = CGPoint(x: wakeRect.midX, y: wakeRect.minY + 19)
                    beyondDepth = CGPoint(x: wake.x, y: wake.y + 2)
                    beyondEnd = CGPoint(x: wakeRect.minX - 19, y: wake.y)
                case .top:
                    return XCTFail("Top is not a supported resting edge")
                }
                let revision = await store.snapshot().revision
                let bytes = try Data(contentsOf: settingsURL)
                move(to: outside)
                try await waitForSurface(.sliver)
                for point in [beyondDepth, beyondEnd] {
                    move(to: point)
                    try await advanceVisibility(milliseconds: 225)
                    XCTAssertEqual(dock.edgePresentation?.state, .sliver, "\(size) at \(point)")
                }
                move(to: wake)
                if usesControlledVisibility {
                    try await advanceVisibility(milliseconds: 149)
                    XCTAssertEqual(dock.edgePresentation?.state, .sliver, "Reveal waits for 150 ms")
                    try await advanceVisibility(milliseconds: 2)
                    XCTAssertEqual(dock.edgePresentation?.state, .expanded, "Reveal after the dwell deadline")
                } else {
                    try await waitForSurface(.expanded)
                }
                try await advanceVisibility(milliseconds: 550)
                XCTAssertEqual(dock.edgePresentation?.state, .expanded, "The wake band stays inside after reveal")
                move(to: outside)
                try await advanceVisibility(milliseconds: 400)
                XCTAssertEqual(dock.edgePresentation?.state, .expanded, "The first absence is shorter than the hide grace")
                move(to: wake)
                try await advanceVisibility(milliseconds: 150)
                XCTAssertEqual(dock.edgePresentation?.state, .expanded, "Returning to the wake band cancels the hide")
                move(to: outside)
                if usesControlledVisibility {
                    try await advanceVisibility(milliseconds: 499)
                    XCTAssertEqual(dock.edgePresentation?.state, .expanded, "Collapse waits for 500 ms")
                    try await advanceVisibility(milliseconds: 2)
                } else {
                    try await advanceVisibility(milliseconds: 550)
                }
                XCTAssertEqual(dock.edgePresentation?.state, .sliver, "Continuous absence hides after the grace period")
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
                    XCTAssertEqual(app.composition.store.snapshot.delivery, delivery)
                    XCTAssertTrue(observedQuota())
                    move(to: outside)
                }
                let after = await store.snapshot()
                XCTAssertEqual(after.revision, revision)
                XCTAssertEqual(try Data(contentsOf: settingsURL), bytes)
            }
        }
    }

    #if MODELPLAN_DOCK_REAL_STRIP_JOURNEY
    private func observePhysicalWakeAndLeave(_ app: EngineDockMenuApplication, store: SettingsStore, root: URL) async throws {
        let dock = app.composition.dock
        let panel = try XCTUnwrap(dock.nativePanel)
        let editor = app.settingsHost.application.editor
        let stored = root.appendingPathComponent("ModelPlan/settings.json")
        func announce(_ instruction: String) {
            FileHandle.standardOutput.write(Data(("D-22: " + instruction + "\n").utf8))
        }
        func wait(_ duration: Duration, until predicate: () -> Bool) async throws -> Bool {
            let deadline = ContinuousClock.now + duration
            while !predicate() && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(8)) }
            return predicate()
        }
        func target(_ point: CGPoint) -> CGRect {
            CGRect(x: point.x - 0.6, y: point.y - 3, width: 1.2, height: 6)
        }
        func staysCollapsed(at point: CGPoint, label: String) async throws {
            announce("Hold the pointer at \(point) for \(label).")
            let region = target(point)
            let reached = try await wait(.seconds(30)) { region.contains(NSEvent.mouseLocation) }
            _ = try XCTUnwrap(reached ? panel : nil, "The physical pointer did not reach \(label)")
            let end = ContinuousClock.now + .milliseconds(550)
            while ContinuousClock.now < end {
                XCTAssertTrue(region.contains(NSEvent.mouseLocation), label)
                XCTAssertTrue(panel.isVisible, label)
                XCTAssertEqual(dock.edgePresentation?.state, .sliver, label)
                try await Task.sleep(for: .milliseconds(15))
            }
        }

        for size in [SettingsSize.small, .medium, .large] {
            _ = try await editor.commit(SettingsB20Edit.size(size))
            announce("Move clear of the widget to settle the \(size) strip. Use the displayed screen coordinates for the precision steps.")
            let collapsed = try await wait(.seconds(18)) { panel.isVisible && dock.edgePresentation?.state == .sliver }
            let placement = try XCTUnwrap(collapsed ? dock.edgePresentation?.placement : nil)
            XCTAssertEqual(placement.edge, .right)
            let screen = try XCTUnwrap(DockDisplayTopology.system().display(placement.displayID))
            let rail = screen.usableFrame.maxX, middle = placement.sliverFrame.midY
            let beyond = placement.sliverFrame.maxY + 19 < screen.usableFrame.maxY
                ? placement.sliverFrame.maxY + 19 : placement.sliverFrame.minY - 19
            XCTAssertTrue(screen.usableFrame.contains(CGPoint(x: rail - 19, y: beyond)))
            let before = await store.snapshot()
            let bytes = try Data(contentsOf: stored)
            try await staysCollapsed(at: CGPoint(x: rail - 21, y: middle), label: "\(size) at 21 pt depth")
            try await staysCollapsed(at: CGPoint(x: rail - 19, y: beyond), label: "\(size) past the strip end")
            let wakePoint = CGPoint(x: rail - 19, y: middle)
            announce("Move to \(wakePoint) at 19 pt depth and capture the expanded widget.")
            let expanded = try await wait(.seconds(30)) {
                target(wakePoint).contains(NSEvent.mouseLocation) && dock.edgePresentation?.state == .expanded && panel.isVisible
            }
            XCTAssertTrue(expanded)
            let openFrame = panel.frame
            func isInside() -> Bool {
                let pointer = NSEvent.mouseLocation
                return placement.wakeFrame.contains(pointer) || placement.globalHoverRects.contains { $0.contains(pointer) }
            }

            announce("Leave the entire widget and wake zone, then return to the same wake point after about 400 ms.")
            let left = try await wait(.seconds(25)) { !isInside() }
            guard left else { return XCTFail("No physical pointer leave was observed") }
            let shortStart = ContinuousClock.now
            let cameBack = try await wait(.milliseconds(470)) { isInside() }
            let absence = shortStart.duration(to: ContinuousClock.now)
            XCTAssertTrue(cameBack, "Return before the 500 ms grace")
            XCTAssertGreaterThanOrEqual(absence, .milliseconds(350))
            XCTAssertLessThanOrEqual(absence, .milliseconds(450))
            XCTAssertTrue(placement.wakeFrame.contains(NSEvent.mouseLocation))
            XCTAssertEqual(dock.edgePresentation?.state, .expanded)
            try await Task.sleep(for: .milliseconds(200))
            XCTAssertEqual(panel.frame, openFrame, "A return to the wake band cancels the pending hide")

            announce("Now leave both areas continuously. Capture the panel collapsing after the grace.")
            let leftAgain = try await wait(.seconds(25)) { !isInside() }
            guard leftAgain else { return XCTFail("No second physical leave was observed") }
            let longStart = ContinuousClock.now
            let hidden = try await wait(.seconds(2)) { dock.edgePresentation?.state == .sliver }
            let untilHidden = longStart.duration(to: ContinuousClock.now)
            XCTAssertTrue(hidden)
            XCTAssertFalse(isInside())
            XCTAssertGreaterThanOrEqual(untilHidden, .milliseconds(480))
            XCTAssertLessThanOrEqual(untilHidden, .milliseconds(750))
            let after = await store.snapshot()
            XCTAssertEqual(after.revision, before.revision)
            XCTAssertEqual(try Data(contentsOf: stored), bytes)
            announce("Capture \(size): measured leave \(untilHidden), short return \(absence).")
            try await Task.sleep(for: .seconds(3))
        }
    }
    #endif
}
#endif
