// SPDX-License-Identifier: MIT
#if MODELPLAN_DOCK_NATIVE_JOURNEY
import AppKit
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings
@testable import ModelPlanAppIntegration

/// Run on an admitted GUI session with a reviewed real CLI and isolated home.
@MainActor final class DockNativePlacementJourneyTests: XCTestCase {
    private final class Topology {
        var main = DockDisplayArea(id: "A", frame: CGRect(x: 0, y: 0, width: 1470, height: 956),
            visibleFrame: CGRect(x: 0, y: 70, width: 1470, height: 860))
        var adjoining = false
        func read() -> DockEdgeEnvironment {
            let neighbour = DockDisplayArea(id: "B", frame: CGRect(x: 1470, y: -300, width: 2560, height: 1440),
                visibleFrame: CGRect(x: 1470, y: -300, width: 2560, height: 1415))
            return .init(displays: adjoining ? [main, neighbour] : [main], layouts: [], primaryDisplayID: "A")
        }
    }
    private final class Replies: EngineStoreEventSink {
        var count = 0
        func acceptedEvent(_ event: EngineClientEvent) {
            switch event {
            case .rowsChanged, .response(_, .rows): count += 1
            default: break
            }
        }
        func apply(_ snapshot: EngineStoreSnapshot) {}
        func clearPrivateViews(_ invalidation: EngineInvalidation) {}
    }
    private func make(_ root: URL, _ topology: Topology?, executable: URL? = nil, helperHome: URL? = nil,
                      edit: ((inout SettingsPreferences) -> Void)? = nil) async throws -> EngineDockMenuApplication {
        let executable = try executable ?? reviewedHelper()
        _ = NSApplication.shared
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        if let edit { _ = try await store.update { edit(&$0) } }
        EngineRowsEntry.nativeJourneyProfile = root
        return EngineRowsEntry.make(configuration: configuration(executable, root: helperHome ?? root),
            settingsStore: store, createsNativePanels: true, bundleURL: root.appendingPathComponent("Synthetic.app"),
            dockEnvironment: topology.map { sample in { sample.read() } }, activateSettings: {})
    }

    private func reviewedHelper() throws -> URL {
        let path = try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_DOCK_TEST_CLI"])
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: path))
        return URL(fileURLWithPath: path)
    }

    private func configuration(_ executable: URL, root: URL) -> EngineClientConfiguration {
        .init(executableURL: executable, applicationVersion: "dock-native-journey",
              allowedEnvironment: ["HOME": root.path, "TMPDIR": root.path, "PATH": "/usr/bin:/bin"],
              offline: true, readOnly: true)
    }
    private func wait(_ seconds: Double, _ predicate: () -> Bool) async throws -> Bool {
        let end = ContinuousClock.now + .seconds(seconds)
        while !predicate(), ContinuousClock.now < end { try await Task.sleep(for: .milliseconds(5)) }
        return predicate()
    }
    private func launch(_ app: EngineDockMenuApplication) {
        app.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    }
    private func checkEngine(_ app: EngineDockMenuApplication) async throws {
        let ready = try await wait(5) {
            if case .ready = app.composition.store.snapshot.connection { return true }
            return false
        }
        XCTAssertTrue(ready, "The real app-server must handshake")
    }
    private func firstShow(disabled: Bool) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let topology = Topology()
        let app = try await make(root, topology)
        addTeardownBlock { @MainActor in
            await app.stopNativeDockJourney()
            EngineRowsEntry.nativeJourneyProfile = nil
            try FileManager.default.removeItem(at: root)
        }
        let replies = Replies()
        let token = app.composition.store.attach(replies)
        defer { app.composition.store.detach(token) }
        app.composition.dock.suppressJourneyOrderIn = disabled
        launch(app)
        let statusVisible = try await wait(2) { app.nativeJourneyStatusVisible }
        XCTAssertTrue(statusVisible)
        let visible = try await wait(2) { app.composition.dock.nativePanel?.isVisible == true }
        XCTAssertEqual(visible, !disabled, "The first-show predicate must reject the disabled order-in control")
        if visible {
            let panel = try XCTUnwrap(app.composition.dock.nativePanel)
            XCTAssertEqual(panel.frame.maxX, topology.main.visibleFrame.maxX, accuracy: 1)
            XCTAssertEqual(replies.count, 0)
            XCTAssertNotNil(app.composition.dock.dockView.emptyStationRectForChecks)
        }
        try await checkEngine(app)
    }
    func testD01VisibleStatusToRealPanelBeforeRowsReplies() async throws { try await firstShow(disabled: false) }
    func testD01OrderInControlRejectsFirstShow() async throws { try await firstShow(disabled: true) }

    #if MODELPLAN_DOCK_REAL_SPACES_JOURNEY
    private func makeRowsBarrier(in root: URL) async throws -> (URL, URL, URL) {
        let helper = try reviewedHelper()
        let home = root.appendingPathComponent("engine-home")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let seed = Process()
        seed.executableURL = helper
        seed.arguments = ["consent", "init", "--json"]
        seed.environment = configuration(helper, root: home).allowedEnvironment
        seed.standardInput = FileHandle.nullDevice
        seed.standardOutput = FileHandle.nullDevice
        seed.standardError = FileHandle.nullDevice
        try seed.run()
        guard try await wait(5, { !seed.isRunning }) else {
            seed.terminate()
            throw CocoaError(.fileReadUnknown, userInfo: [NSLocalizedDescriptionKey: "Temporary consent setup timed out"])
        }
        guard seed.terminationStatus == 0 else {
            throw CocoaError(.fileReadUnknown, userInfo: [NSLocalizedDescriptionKey: "Temporary consent setup failed"])
        }
        let executable = root.appendingPathComponent("withhold-rows")
        let receipt = root.appendingPathComponent("subscribe-withheld")
        let paths = try JSONEncoder().encode([helper.path, receipt.path])
        let script = """
        #!/usr/bin/python3
        import base64
        import json
        import pathlib
        import signal
        import subprocess
        import sys
        import threading

        helper, receipt = json.loads(base64.b64decode("\(paths.base64EncodedString())"))
        server = subprocess.Popen([helper, *sys.argv[1:]], stdin=subprocess.PIPE)

        def stop(signum, frame):
            if server.poll() is None:
                server.terminate()

        signal.signal(signal.SIGTERM, stop)
        signal.signal(signal.SIGINT, stop)

        def forward():
            try:
                for raw in sys.stdin.buffer:
                    if json.loads(raw).get("method") == "rows/subscribe":
                        pathlib.Path(receipt).touch()
                        continue
                    server.stdin.write(raw)
                    server.stdin.flush()
            except BrokenPipeError:
                pass
            finally:
                server.stdin.close()

        threading.Thread(target=forward, daemon=True).start()
        sys.exit(server.wait())
        """
        try script.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        return (executable, receipt, home)
    }

    func testD01RowBarrierKeepsRealServerConnectedWithoutRows() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dock-row-barrier-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let (executable, receipt, home) = try await makeRowsBarrier(in: root)
        let store = EngineStore()
        let client = ProcessEngineClient(configuration: configuration(executable, root: home), consumer: store)
        addTeardownBlock { await client.stop() }
        _ = try await client.start()
        let replies = Replies()
        let token = store.attach(replies)
        defer { store.detach(token) }
        let subscription = Task { try await client.subscribeRows(timeout: .seconds(2)) }
        defer { subscription.cancel() }
        let blocked = try await wait(1) { FileManager.default.fileExists(atPath: receipt.path) }
        XCTAssertTrue(blocked, "The actual production client must reach the barrier")
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(replies.count, 0)
        XCTAssertNil(store.snapshot.rows)
        guard case .ready = store.snapshot.connection else { return XCTFail("The reviewed app-server must still be connected") }
    }

    func testD01PhysicalFreshFirstShowWithRealRowsWithheld() async throws {
        try await physicalFirstShow(disabled: false)
    }

    func testD01PhysicalOrderInControlNeverShowsWithRowsWithheld() async throws {
        try await physicalFirstShow(disabled: true)
    }

    private func physicalFirstShow(disabled: Bool) async throws {
        let application = NSApplication.shared
        let previousMenu = application.mainMenu, previousAppearance = application.appearance
        let previousPolicy = application.activationPolicy()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dock-d01-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let (executable, receipt, home) = try await makeRowsBarrier(in: root)
        let profile = root.appendingPathComponent("profile")
        XCTAssertFalse(FileManager.default.fileExists(atPath: profile.path))
        let screen = try XCTUnwrap(DockDisplayTopology.system().main)
        let app = try await make(profile, nil, executable: executable, helperHome: home)
        addTeardownBlock { @MainActor in
            await app.stopNativeDockJourney()
            EngineRowsEntry.nativeJourneyProfile = nil
            application.mainMenu = previousMenu
            application.appearance = previousAppearance
            application.setActivationPolicy(previousPolicy)
        }
        let store = app.composition.store
        let replies = Replies()
        let token = store.attach(replies)
        defer { store.detach(token) }
        let host = app.composition.dock
        host.suppressJourneyOrderIn = disabled
        FileHandle.standardOutput.write(Data("D-01: Start recording before launch. Rows requests will be withheld from the real helper.\n".utf8))
        launch(app)
        let statusVisible = try await wait(2) { app.nativeJourneyStatusVisible }
        XCTAssertTrue(statusVisible, "Start the first-show clock at the actual visible status item")
        let ordered = try await wait(2) {
            host.nativePanel.map { $0.isVisible && $0.occlusionState.contains(.visible) } ?? false
        }
        XCTAssertEqual(ordered, !disabled)
        XCTAssertEqual(replies.count, 0)
        if !disabled {
            let placement = try XCTUnwrap(host.edgePresentation?.placement)
            let panel = try XCTUnwrap(host.nativePanel)
            XCTAssertEqual(placement.displayID, screen.id)
            XCTAssertEqual(placement.edge, .right)
            XCTAssertEqual(panel.frame.maxX, screen.usableFrame.maxX, accuracy: 1)
            XCTAssertEqual(panel.frame.minY + placement.layout.alongAnchor, screen.usableFrame.midY, accuracy: 1)
            XCTAssertNotNil(host.dockView.emptyStationRectForChecks)
            XCTAssertTrue(host.dockView.presentedReadingsForChecks.isEmpty)
        }
        try await checkEngine(app)
        let blocked = try await wait(5) { FileManager.default.fileExists(atPath: receipt.path) }
        XCTAssertTrue(blocked, "The app-server handshake must precede a real blocked subscription")
        try await Task.sleep(for: .seconds(2))
        XCTAssertEqual(replies.count, 0)
        XCTAssertNil(store.snapshot.rows)
        if disabled { XCTAssertFalse(host.nativePanel?.isVisible == true) }
        else { XCTAssertTrue(host.nativePanel?.isVisible == true) }
    }
    #endif

    func testD02AndD03NativePanelTracksReservationsAndKeepsEdge() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let topology = Topology()
        topology.adjoining = true
        let app = try await make(root, topology) { $0.dockEdge = .right }
        addTeardownBlock { @MainActor in
            await app.stopNativeDockJourney()
            EngineRowsEntry.nativeJourneyProfile = nil
            try FileManager.default.removeItem(at: root)
        }
        launch(app)
        try await checkEngine(app)
        let panel = try XCTUnwrap(app.composition.dock.nativePanel)
        let editor = app.settingsHost.application.editor
        for edge in [SettingsDockEdge.right, .bottom] {
            _ = try await editor.commit(SettingsB21Edit.dockEdge(edge))
            for floor in [70.0, 4.0, 70.0] {
                topology.main = .init(id: "A", frame: topology.main.frame,
                    visibleFrame: CGRect(x: 0, y: floor, width: 1470, height: 930 - floor))
                NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
                XCTAssertTrue(panel.isVisible)
                if edge == .right { XCTAssertEqual(panel.frame.maxX, topology.main.visibleFrame.maxX, accuracy: 1) }
                else { XCTAssertEqual(panel.frame.minY, floor, accuracy: 1) }
            }
        }
    }

    func testD14NativeHideRelaunchAndShow() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let topology = Topology()
        let first = try await make(root, topology)
        addTeardownBlock { @MainActor in
            await first.stopNativeDockJourney()
            EngineRowsEntry.nativeJourneyProfile = nil
            try FileManager.default.removeItem(at: root)
        }
        launch(first)
        try await checkEngine(first)
        let original = try XCTUnwrap(first.composition.dock.nativePanel?.frame)
        let hide = try XCTUnwrap(first.composition.dock.menu().items.first { $0.title == "Hide Quota Widget" })
        _ = try XCTUnwrap(hide.target as? NSObject).perform(try XCTUnwrap(hide.action), with: hide)
        try await waitForSettings(first.settingsHost.application.editor) {
            first.settingsHost.application.editor.snapshot?.preferences.showDock == false
        }
        await first.stopNativeDockJourney()
        let second = try await make(root, topology)
        addTeardownBlock { @MainActor in await second.stopNativeDockJourney() }
        launch(second)
        try await checkEngine(second)
        XCTAssertFalse(second.composition.dock.nativePanel?.isVisible == true)
        let show = try XCTUnwrap(second.liveStatusMenu?.items.first { $0.title == "Show Quota Widget" })
        _ = try XCTUnwrap(show.target as? NSObject).perform(try XCTUnwrap(show.action), with: show)
        let visible = try await wait(2) { second.composition.dock.nativePanel?.isVisible == true }
        XCTAssertTrue(visible)
        XCTAssertEqual(second.composition.dock.nativePanel?.frame, original)
        XCTAssertEqual(second.settingsHost.application.editor.snapshot?.preferences.showDock, true)
    }
}
#endif
