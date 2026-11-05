// SPDX-License-Identifier: MIT
#if MODELPLAN_DOCK_NATIVE_JOURNEY && MODELPLAN_DOCK_REAL_CONTEXT_JOURNEY
import AppKit
import WebKit
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class DockD16PhysicalJourneyTests: XCTestCase {
    private func wait(_ duration: Duration, until ready: () -> Bool) async throws -> Bool {
        let deadline = ContinuousClock.now + duration
        while !ready() && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        return ready()
    }

    private func announce(_ instruction: String) {
        FileHandle.standardOutput.write(Data(("D-16: " + instruction + "\n").utf8))
    }

    private func makeApp(helper: URL, bundle: URL?, autoHide: Bool) async throws -> EngineDockMenuApplication {
        _ = NSApplication.shared
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: helper.path))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dock-d16-" + UUID().uuidString)
        let configuration = root.appendingPathComponent(".config/modelplan")
        try FileManager.default.createDirectory(at: configuration, withIntermediateDirectories: true)
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
            throw CocoaError(.fileReadUnknown, userInfo: [NSLocalizedDescriptionKey: "Temporary consent setup timed out"])
        }
        XCTAssertEqual(seed.terminationStatus, 0)
        let now = Date(), iso = ISO8601DateFormatter(), plan = "synthetic-d16"
        let fixture: [String: Any] = ["schemaVersion": 1, "plans": [["planId": plan]], "windows": [[
            "planId": plan, "kind": "five_hour", "remainingPercent": 57, "resetMode": "rolling",
            "observedAt": iso.string(from: now.addingTimeInterval(-10)),
            "resetAt": iso.string(from: now.addingTimeInterval(7_200)),
        ]]]
        try JSONSerialization.data(withJSONObject: fixture).write(to: configuration.appendingPathComponent("local.json"), options: .atomic)
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        _ = try await store.update { $0.autoHide = autoHide; $0.motion = .on }
        EngineRowsEntry.nativeJourneyProfile = root
        let app = EngineRowsEntry.make(configuration: .init(executableURL: helper, applicationVersion: "synthetic-d16",
            allowedEnvironment: environment, offline: true, readOnly: true), settingsStore: store,
            createsNativePanels: true, bundleURL: bundle ?? root.appendingPathComponent("Synthetic.app"),
            activateSettings: {})
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
        return app
    }

    func testD16PhysicalContextMenuTracksRightAndControlClickOnFaceAndStrip() async throws {
        let executable = URL(fileURLWithPath: try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_DOCK_TEST_CLI"]))
        let app = try await makeApp(helper: executable, bundle: nil, autoHide: false)
        let host = app.composition.dock
        let panel = try XCTUnwrap(host.nativePanel)
        let editor = app.settingsHost.application.editor
        XCTAssertTrue(host.dockView.presentedReadingsForChecks.values.contains { $0.remainingPercent == 57 })

        for surface in [DockSurfaceState.expanded, .sliver] {
            _ = try await editor.commit(SettingsB21Edit.autoHide(surface == .sliver))
            for control in [false, true] {
                announce("Move the pointer away from the widget before testing \(surface).")
                let ready = try await wait(.seconds(20)) {
                    host.edgePresentation?.state == surface && panel.isVisible && !panel.frame.contains(NSEvent.mouseLocation)
                }
                guard ready else { return XCTFail("The expected native surface did not settle") }

                var pressedOnSurface = false, tracked: NSMenu?, began: ContinuousClock.Instant?
                var heldFor: Duration?, stayedShown = false
                let center = NotificationCenter.default
                let input = try XCTUnwrap(NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .leftMouseDown]) { event in
                    MainActor.assumeIsolated {
                        let matches = control
                            ? event.type == .leftMouseDown && event.modifierFlags.contains(.control)
                            : event.type == .rightMouseDown
                        if matches && event.window === panel { pressedOnSurface = host.edgePresentation?.state == surface }
                    }
                    return event
                })
                let begin = center.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) { note in
                    MainActor.assumeIsolated {
                        guard let menu = note.object as? NSMenu, host.ownsDockMenu(menu) else { return }
                        tracked = menu
                        began = ContinuousClock.now
                    }
                }
                let end = center.addObserver(forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main) { note in
                    MainActor.assumeIsolated {
                        guard let menu = note.object as? NSMenu, menu === tracked, let began else { return }
                        heldFor = began.duration(to: ContinuousClock.now)
                        stayedShown = panel.isVisible && host.edgePresentation?.paintedFrame != nil
                    }
                }
                defer { NSEvent.removeMonitor(input); center.removeObserver(begin); center.removeObserver(end) }

                announce("Move directly to the \(surface) and immediately \(control ? "Control-click" : "right-click"). Keep the menu open for two seconds, then dismiss it.")
                let closed = try await wait(.seconds(40)) { heldFor != nil }
                guard closed else { return XCTFail("The actual context menu did not finish tracking") }
                XCTAssertTrue(pressedOnSurface)
                XCTAssertNotNil(tracked)
                XCTAssertGreaterThanOrEqual(try XCTUnwrap(heldFor), .milliseconds(500))
                XCTAssertTrue(stayedShown)
                XCTAssertFalse(host.interactionEnvironment().menuActuallyOpen)
                if surface == .sliver {
                    announce("Move away and capture the widget returning to the strip.")
                    let recollapsed = try await wait(.seconds(15)) {
                        host.edgePresentation?.state == .sliver && !host.interactionEnvironment().menuActuallyOpen
                    }
                    XCTAssertTrue(recollapsed)
                }
            }
        }
    }

    func testD16PhysicalVerifiedWebKitCockpitWithdrawsAndRestoresDock() async throws {
        let path = try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_DOCK_D16_APP"],
                                 "Set this to the reviewed cockpit-enabled candidate .app")
        let bundleURL = URL(fileURLWithPath: path, isDirectory: true)
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        XCTAssertEqual(bundle.object(forInfoDictionaryKey: "ModelPlanCockpitEntryEnabled") as? Bool, true)
        guard CommunityConsentBundleIdentity.matches(bundle: bundleURL),
              bundle.object(forInfoDictionaryKey: "ModelPlanCockpitEntryEnabled") as? Bool == true else {
            return XCTFail("A verified cockpit-enabled App/helper bundle is required")
        }
        let app = try await makeApp(helper: bundleURL.appendingPathComponent("Contents/Helpers/modelplan"),
                                    bundle: bundleURL, autoHide: false)
        let host = app.composition.dock
        let panel = try XCTUnwrap(host.nativePanel)
        XCTAssertTrue(panel.isVisible)
        let before = panel.frame
        let revision = app.settingsHost.application.editor.snapshot?.revision

        func browser(in view: NSView?) -> WKWebView? {
            guard let view else { return nil }
            if let web = view as? WKWebView { return web }
            return view.subviews.lazy.compactMap { browser(in: $0) }.first
        }
        announce("Click the actual ignition control on the widget. Capture the Dock withdrawal and the cockpit page.")
        let withdrawn = try await wait(.seconds(35)) { !panel.isVisible && host.edgePresentation?.paintedFrame == nil }
        XCTAssertTrue(withdrawn)
        var cockpit: NSWindow?
        let open = try await wait(.seconds(20)) {
            cockpit = NSApplication.shared.windows.first { window in
                window.isVisible && browser(in: window.contentView)?.url?.scheme == "modelplan-cockpit"
            }
            return cockpit != nil
        }
        let window = try XCTUnwrap(open ? cockpit : nil, "A real verified WebKit cockpit must be visible")
        XCTAssertFalse(panel.isVisible)
        XCTAssertNil(host.edgePresentation?.paintedFrame)
        announce("Close the actual cockpit window. Capture the restored Dock.")
        let restored = try await wait(.seconds(35)) { !window.isVisible && panel.isVisible }
        XCTAssertTrue(restored)
        XCTAssertEqual(panel.frame, before)
        XCTAssertEqual(app.settingsHost.application.editor.snapshot?.revision, revision)
    }
}
#endif
