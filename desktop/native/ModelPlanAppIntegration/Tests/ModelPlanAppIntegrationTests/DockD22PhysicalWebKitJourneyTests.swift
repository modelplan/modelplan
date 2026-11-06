// SPDX-License-Identifier: MIT
#if MODELPLAN_DOCK_NATIVE_JOURNEY && MODELPLAN_DOCK_REAL_STRIP_JOURNEY
import AppKit
import WebKit
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanSettings
@testable import ModelPlanAppIntegration

/// Requires an admitted, source-matched cockpit-enabled candidate and a real display.
@MainActor final class DockD22PhysicalWebKitJourneyTests: XCTestCase {
    func testD22VerifiedWebKitReturnUsesTheRealPointerOnEachSize() async throws {
        let application = NSApplication.shared
        let path = try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_DOCK_D22_APP"],
            "Set MODELPLAN_DOCK_D22_APP to the admitted cockpit-enabled candidate")
        let bundleURL = URL(fileURLWithPath: path, isDirectory: true)
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        guard bundle.object(forInfoDictionaryKey: "ModelPlanCockpitEntryEnabled") as? Bool == true,
              CommunityConsentBundleIdentity.matches(bundle: bundleURL) else {
            return XCTFail("The candidate must enable cockpit entry and admit its bundled helper")
        }
        let helper = bundleURL.appendingPathComponent("Contents/Helpers/modelplan")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dock-d22-webkit-" + UUID().uuidString)
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
        guard try await wait(.seconds(5), until: { !seed.isRunning }) else {
            seed.terminate()
            return XCTFail("Temporary consent initialization timed out")
        }
        XCTAssertEqual(seed.terminationStatus, 0)

        let plan = "synthetic-d22-webkit", iso = ISO8601DateFormatter(), now = Date()
        let fixture: [String: Any] = ["schemaVersion": 1, "plans": [["planId": plan]], "windows": [[
            "planId": plan, "kind": "five_hour", "remainingPercent": 57, "resetMode": "rolling",
            "observedAt": iso.string(from: now.addingTimeInterval(-10)),
            "resetAt": iso.string(from: now.addingTimeInterval(7_200)),
        ]]]
        try JSONSerialization.data(withJSONObject: fixture).write(to: config.appendingPathComponent("local.json"), options: .atomic)
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        _ = try await store.update { $0.autoHide = true; $0.dockEdge = .bottom; $0.motion = .on }
        EngineRowsEntry.nativeJourneyProfile = root
        let app = EngineRowsEntry.make(configuration: .init(executableURL: helper, applicationVersion: "synthetic-d22-webkit",
            allowedEnvironment: environment, offline: true, readOnly: true), settingsStore: store,
            createsNativePanels: true, bundleURL: bundleURL, activateSettings: {})
        addTeardownBlock { @MainActor in
            await app.stopNativeDockJourney()
            EngineRowsEntry.nativeJourneyProfile = nil
        }
        await app.prepare()
        XCTAssertNil(app.loginServiceAdapter)
        XCTAssertNil(app.notificationAuthorizationService)
        app.allowDockPresentation()
        _ = try await app.composition.client.start()
        _ = try await app.composition.client.subscribeRows(timeout: .seconds(4))

        let dock = app.composition.dock, editor = app.settingsHost.application.editor
        let panel = try XCTUnwrap(dock.nativePanel)
        XCTAssertTrue(dock.dockView.presentedReadingsForChecks.values.contains { $0.remainingPercent == 57 })
        let storedURL = root.appendingPathComponent("ModelPlan/settings.json")
        for size in [SettingsSize.small, .medium, .large] {
            _ = try await editor.commit(SettingsB20Edit.size(size))
            announce("For \(size), move the pointer away from the widget to establish a collapsed strip.")
            let collapsed = try await wait(.seconds(20)) { panel.isVisible && dock.edgePresentation?.state == .sliver }
            guard collapsed else { return XCTFail("The actual native strip did not settle at \(size)") }
            let placement = try XCTUnwrap(dock.edgePresentation?.placement)
            XCTAssertEqual(placement.edge, .bottom)
            let originalStrip = panel.frame
            let revision = editor.snapshot?.revision
            let bytes = try Data(contentsOf: storedURL)

            for inside in [false, true] {
                app.showConsole()
                XCTAssertNil(dock.edgePresentation?.paintedFrame, "The normal cockpit action withdraws the Dock synchronously")
                let open = try await wait(.seconds(20)) { self.visibleCockpit(in: application) != nil && !panel.isVisible }
                let cockpit = try XCTUnwrap(open ? visibleCockpit(in: application) : nil, "The verified WebKit window must load")
                let safePoint = CGPoint(x: placement.wakeFrame.midX, y: placement.wakeFrame.midY)
                announce(inside
                    ? "Move into the former strip wake area near \(safePoint) and hold. The test will close the actual cockpit window."
                    : "Move away from the former strip and widget area. The test will close the actual cockpit window.")
                func pointerMatches() -> Bool {
                    let pointer = NSEvent.mouseLocation
                    return inside ? placement.wakeFrame.contains(pointer) :
                        !placement.wakeFrame.contains(pointer) && !placement.frame.contains(pointer)
                }
                let pointed = try await wait(.seconds(30), until: pointerMatches)
                guard pointed else { return XCTFail("The physical pointer did not reach the expected close location") }
                XCTAssertFalse(panel.isVisible)
                var exposedExpanded = false
                let movement = NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification,
                    object: panel, queue: .main) { _ in
                        MainActor.assumeIsolated {
                            if panel.isVisible && !(panel.contentView is DockSliverView) { exposedExpanded = true }
                        }
                    }
                defer { NotificationCenter.default.removeObserver(movement) }
                // A borderless cockpit has no AppKit close button. Close its real
                // NSWindow here and let the installed window delegate retire the page.
                cockpit.close()
                let expected: DockSurfaceState = inside ? .expanded : .sliver
                let returned = try await wait(.seconds(8)) {
                    if !inside && panel.isVisible && !(panel.contentView is DockSliverView) { exposedExpanded = true }
                    return !cockpit.isVisible && panel.isVisible && dock.edgePresentation?.state == expected
                }
                XCTAssertTrue(returned, "\(size), pointer \(inside ? "in" : "out"): expected \(expected)")
                if inside {
                    XCTAssertFalse(panel.contentView is DockSliverView)
                } else {
                    XCTAssertFalse(exposedExpanded, "The away return must not flash the expanded widget")
                    XCTAssertEqual(panel.frame, originalStrip)
                    XCTAssertTrue(panel.contentView is DockSliverView)
                }
                XCTAssertEqual(editor.snapshot?.revision, revision)
                XCTAssertEqual(try Data(contentsOf: storedURL), bytes)
                announce("Capture \(size) returning to \(expected) now.")
                try await Task.sleep(for: .seconds(3))
            }
        }
    }

    private func visibleCockpit(in app: NSApplication) -> NSWindow? {
        func containsPage(_ view: NSView?) -> Bool {
            guard let view else { return false }
            if let web = view as? WKWebView { return web.url?.scheme == "modelplan-cockpit" }
            return view.subviews.contains { containsPage($0) }
        }
        return app.windows.first { $0.isVisible && containsPage($0.contentView) }
    }

    private func wait(_ duration: Duration, until condition: () -> Bool) async throws -> Bool {
        let deadline = ContinuousClock.now + duration
        while !condition() && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        return condition()
    }

    private func announce(_ message: String) {
        FileHandle.standardOutput.write(Data(("D-22: " + message + "\n").utf8))
    }
}
#endif
