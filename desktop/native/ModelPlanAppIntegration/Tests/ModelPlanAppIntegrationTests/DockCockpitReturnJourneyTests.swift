// SPDX-License-Identifier: MIT
#if MODELPLAN_DOCK_NATIVE_JOURNEY
import AppKit
import XCTest
import ModelPlanCockpitWeb
import ModelPlanDock
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
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
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
        seed.waitUntilExit()
        XCTAssertEqual(seed.terminationStatus, 0, "Seed only the temporary consent store")
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
            offline: true, readOnly: true), settingsStore: store, createsNativePanels: native, cockpitEntryEnabled: true,
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
        app.allowDockPresentation()
        let delivery = try await app.composition.client.start()
        XCTAssertEqual(app.composition.store.snapshot.connection, .ready(delivery))
        let rowsDeadline = ContinuousClock.now + .seconds(3)
        while app.composition.store.snapshot.rows == nil, ContinuousClock.now < rowsDeadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        _ = try XCTUnwrap(app.composition.store.snapshot.rows, "Require an accepted app-server rows reply before exercising the Dock")
        // The fake page uses the real delivery and borrowed client without a WebKit window.
        await cockpit.consume(.context(delivery))

        let editor = app.settingsHost.application.editor
        let dock = app.composition.dock
        for size in SettingsSize.allCases {
            _ = try await editor.commit(SettingsB20Edit.size(size))
            let placement = try XCTUnwrap(dock.edgePresentation?.placement)
            let wake = CGPoint(x: placement.wakeFrame.maxX - 19, y: placement.wakeFrame.midY)
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
                pointer = point
                dock.refreshPresence()
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
                pointer = outside
                dock.refreshPresence()
            }
        }
    }
}
#endif
