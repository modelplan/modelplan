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
    private func makeRowsBarrier(in root: URL, releaseRowsWhen marker: URL? = nil) async throws -> (URL, URL, URL) {
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
        let paths = try JSONEncoder().encode([helper.path, receipt.path, marker?.path])
        let script = """
        #!/usr/bin/python3
        import base64
        import json
        import pathlib
        import signal
        import subprocess
        import sys
        import threading
        import time

        helper, receipt, marker = json.loads(base64.b64decode("\(paths.base64EncodedString())"))
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
                        if marker is None:
                            continue
                        while not pathlib.Path(marker).exists():
                            if server.poll() is not None:
                                return
                            time.sleep(0.01)
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

    func testD01DetachedFreshFirstShowWithRealRowsWithheld() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dock-d01-detached-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let (executable, receipt, home) = try await makeRowsBarrier(in: root)
        let profile = root.appendingPathComponent("profile")
        XCTAssertFalse(FileManager.default.fileExists(atPath: profile.path))
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        let topology = Topology()
        let app = EngineRowsEntry.make(configuration: configuration(executable, root: home),
            settingsStore: settings, createsNativePanels: false, bundleURL: profile.appendingPathComponent("Synthetic.app"),
            dockEnvironment: { topology.read() }, activateSettings: {})
        addTeardownBlock { @MainActor in
            await app.stopLifecycle()
            app.composition.dock.close()
        }
        let store = app.composition.store
        let replies = Replies()
        let token = store.attach(replies)
        defer { store.detach(token) }
        await app.prepare()
        app.startLifecycle(workspace: NotificationCenter(), local: NotificationCenter(), lockEvents: NotificationCenter(),
            displayIDs: { [1] }, onConsole: { true }, displaysAsleep: { _ in false })
        let host = app.composition.dock
        let shown = try await wait(2) { host.edgePresentation?.state == .expanded }
        XCTAssertTrue(shown, "Fresh presentation must not wait on the real server's rows reply")
        XCTAssertEqual(replies.count, 0)
        let placement = try XCTUnwrap(host.edgePresentation?.placement)
        XCTAssertEqual(placement.displayID, topology.main.id)
        XCTAssertEqual(placement.edge, .right)
        XCTAssertEqual(placement.alongFraction, 0.5, accuracy: 0.001)
        XCTAssertNotNil(host.edgePresentation?.paintedFrame)
        XCTAssertNotNil(host.dockView.emptyStationRectForChecks)

        let subscribed = try await wait(5) { FileManager.default.fileExists(atPath: receipt.path) }
        XCTAssertTrue(subscribed, "The launched app must send rows/subscribe to the withholding barrier")
        try await checkEngine(app)
        XCTAssertEqual(replies.count, 0)
        XCTAssertNil(store.snapshot.rows)
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

    private func promptD14(_ instruction: String) {
        FileHandle.standardOutput.write(Data(("D-14: " + instruction + "\n").utf8))
    }

    private func preserveTestAppAppearance() {
        let app = NSApplication.shared
        let mainMenu = app.mainMenu, appearance = app.appearance
        let policy = app.activationPolicy()
        addTeardownBlock { @MainActor in
            app.mainMenu = mainMenu
            app.appearance = appearance
            app.setActivationPolicy(policy)
        }
    }

    private func watchPhysicalMenu(matching matches: @escaping (NSMenu) -> Bool, action: String,
                                   until completed: () -> Bool) async throws {
        var tracked = false
        let observer = NotificationCenter.default.addObserver(forName: NSMenu.didBeginTrackingNotification,
            object: nil, queue: .main) { note in
                MainActor.assumeIsolated {
                    if let menu = note.object as? NSMenu, matches(menu) { tracked = true }
                }
            }
        defer { NotificationCenter.default.removeObserver(observer) }
        promptD14(action)
        let applied = try await wait(45) { tracked && completed() }
        _ = try XCTUnwrap(applied ? true : nil, "The physical menu action must complete: \(action)")
    }

    func testD12DetachedRealServerScrubsRowsAndRestoresResizedPlacementAfterWake() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dock-d12-detached-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let allowRows = root.appendingPathComponent("allow-rows")
        let (relay, receipt, home) = try await makeRowsBarrier(in: root, releaseRowsWhen: allowRows)
        let config = home.appendingPathComponent(".config/modelplan")
        try FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)
        let time = Date(), iso = ISO8601DateFormatter()
        func writeReading(_ remaining: Int, offset: TimeInterval) throws {
            let plan = "d12-offline-reading"
            let data: [String: Any] = ["schemaVersion": 1, "plans": [["planId": plan]], "windows": [[
                "planId": plan, "kind": "five_hour", "remainingPercent": remaining, "resetMode": "rolling",
                "observedAt": iso.string(from: time.addingTimeInterval(offset)),
                "resetAt": iso.string(from: time.addingTimeInterval(7_200)),
            ]]]
            try JSONSerialization.data(withJSONObject: data)
                .write(to: config.appendingPathComponent("local.json"), options: .atomic)
        }
        try writeReading(40, offset: -20)
        try Data().write(to: allowRows)

        let profile = root.appendingPathComponent("profile")
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        _ = try await settings.update {
            $0.dockEdge = .bottom
            $0.dockDisplayID = "A"
            $0.dockAlongFraction = 0.62
            $0.autoHide = false
        }
        var display = DockDisplayArea(id: "A", frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: CGRect(x: 0, y: 70, width: 1512, height: 875), backingScale: 2)
        var fullscreen = false
        let app = EngineRowsEntry.make(configuration: configuration(relay, root: home), settingsStore: settings,
            createsNativePanels: false, bundleURL: profile.appendingPathComponent("Synthetic.app"), dockEnvironment: {
                var presence = DockPresence()
                presence.allowedOverFullscreen = !fullscreen
                return .init(displays: [display], layouts: [], primaryDisplayID: display.id,
                             pointer: CGPoint(x: display.usableFrame.midX, y: display.usableFrame.midY), presence: presence)
            }, activateSettings: {})
        let workspace = NotificationCenter()
        let store = app.composition.store
        let replies = Replies()
        let token = store.attach(replies)
        defer { store.detach(token) }
        addTeardownBlock { @MainActor in
            await app.stopLifecycle()
            app.composition.dock.close()
        }
        await app.prepare()
        app.startLifecycle(workspace: workspace, local: NotificationCenter(), lockEvents: NotificationCenter(),
            displayIDs: { [1] }, onConsole: { true }, displaysAsleep: { _ in false })
        let dock = app.composition.dock
        func rendered() -> [Double] {
            dock.dockView.presentedReadingsForChecks.values.compactMap(\.remainingPercent).sorted()
        }
        let readInitial = try await wait(6) { rendered() == [40] }
        XCTAssertTrue(readInitial)
        XCTAssertGreaterThan(replies.count, 0)
        let originalDelivery = try XCTUnwrap(store.snapshot.delivery)
        let original = try XCTUnwrap(dock.edgePresentation?.placement)
        XCTAssertEqual(dock.edgePresentation?.paintedFrame, original.frame)
        XCTAssertEqual(dock.dockView.layer?.contentsScale, 2)
        let saved = await settings.snapshot()
        let url = profile.appendingPathComponent("ModelPlan/settings.json")
        let originalSettings = try Data(contentsOf: url)

        fullscreen = true
        dock.refreshPresence()
        XCTAssertNil(dock.edgePresentation?.paintedFrame)
        fullscreen = false
        dock.refreshPresence()
        XCTAssertEqual(dock.edgePresentation?.paintedFrame, original.frame)
        XCTAssertEqual(rendered(), [40])

        display = DockDisplayArea(id: "A", frame: CGRect(x: 0, y: 0, width: 1280, height: 800),
            visibleFrame: CGRect(x: 0, y: 70, width: 1280, height: 693))
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let resized = try XCTUnwrap(dock.edgePresentation?.placement)
        XCTAssertEqual(resized.edge, .bottom)
        XCTAssertEqual(resized.alongFraction, 0.62, accuracy: 0.0001)
        XCTAssertNotEqual(resized.frame.minX, original.frame.minX)
        XCTAssertEqual(resized.frame.minY, display.usableFrame.minY, accuracy: 0.01)
        XCTAssertTrue(display.usableFrame.contains(resized.frame))
        XCTAssertEqual(dock.dockView.layer?.contentsScale, 1)
        XCTAssertEqual(rendered(), [40])

        try FileManager.default.removeItem(at: allowRows)
        workspace.post(name: NSWorkspace.willSleepNotification, object: nil)
        XCTAssertNil(dock.edgePresentation?.paintedFrame)
        XCTAssertTrue(rendered().isEmpty)
        let stopped = try await wait(5) { store.snapshot.connection == .stopped(.requested) }
        guard stopped else { return XCTFail("The previous server must retire before staging the next reading") }
        XCTAssertNil(store.snapshot.rows)
        let beforeWake = replies.count
        try FileManager.default.removeItem(at: receipt)
        try writeReading(70, offset: -5)
        workspace.post(name: NSWorkspace.didWakeNotification, object: nil)
        let woke = try await wait(2) { dock.edgePresentation?.paintedFrame != nil }
        XCTAssertTrue(woke)
        XCTAssertEqual(dock.edgePresentation?.paintedFrame, resized.frame)
        XCTAssertNotNil(dock.dockView.emptyStationRectForChecks)
        let requestHeld = try await wait(5) { FileManager.default.fileExists(atPath: receipt.path) }
        XCTAssertTrue(requestHeld)
        try await checkEngine(app)
        XCTAssertTrue(rendered().isEmpty)
        XCTAssertNil(store.snapshot.rows)
        XCTAssertEqual(replies.count, beforeWake)

        try Data().write(to: allowRows)
        let readFresh = try await wait(6) { rendered() == [70] }
        XCTAssertTrue(readFresh)
        XCTAssertGreaterThan(replies.count, beforeWake)
        XCTAssertNotEqual(try XCTUnwrap(store.snapshot.delivery).sessionID, originalDelivery.sessionID)
        XCTAssertEqual(dock.edgePresentation?.paintedFrame, resized.frame)
        XCTAssertEqual(dock.edgePresentation?.placement?.edge, .bottom)
        let after = await settings.snapshot()
        XCTAssertEqual(after.revision, saved.revision)
        XCTAssertEqual(after.preferences.dockAlongFraction, 0.62)
        XCTAssertEqual(try Data(contentsOf: url), originalSettings)
    }

    func testD14DetachedRealServerRestoresAndQueuesShowWithoutRowsReplies() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dock-d14-detached-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let (relay, receipt, home) = try await makeRowsBarrier(in: root)
        let profile = root.appendingPathComponent("profile")
        let topology = Topology()
        let workspace = NotificationCenter()
        let replies = Replies()

        func launch(initial: Bool = false) async throws -> EngineDockMenuApplication {
            let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
            if initial {
                _ = try await settings.update {
                    $0.motion = .on
                    $0.dockAlongFraction = 0.62
                }
            }
            let app = EngineRowsEntry.make(configuration: configuration(relay, root: home),
                settingsStore: settings, createsNativePanels: false, bundleURL: profile.appendingPathComponent("Synthetic.app"),
                dockEnvironment: {
                    var sample = topology.read()
                    let available = topology.main.visibleFrame
                    sample.pointer = CGPoint(x: available.midX, y: available.midY)
                    return sample
                }, activateSettings: {})
            let token = app.composition.store.attach(replies)
            addTeardownBlock { @MainActor in
                app.composition.store.detach(token)
                await app.stopLifecycle()
                app.composition.dock.close()
            }
            await app.prepare()
            app.startLifecycle(workspace: workspace, local: NotificationCenter(), lockEvents: NotificationCenter(),
                displayIDs: { [1] }, onConsole: { true }, displaysAsleep: { _ in false })
            return app
        }

        func select(_ title: String, in menu: NSMenu) throws {
            let index = try XCTUnwrap(menu.items.firstIndex { $0.title == title && $0.isEnabled })
            menu.performActionForItem(at: index)
        }
        func show(_ app: EngineDockMenuApplication) throws {
            try select("Show Quota Widget", in: XCTUnwrap(app.liveStatusMenu))
        }
        func highlight(_ app: EngineDockMenuApplication) -> CALayer? {
            app.composition.dock.dockView.layer?.sublayers?.first { $0.name == "dock.locate-highlight" }
        }
        func checkShown(_ app: EngineDockMenuApplication, at savedFrame: CGRect) async throws {
            let host = app.composition.dock
            let shown = try await wait(2) {
                host.edgePresentation?.state == .expanded && highlight(app) != nil
            }
            XCTAssertTrue(shown)
            XCTAssertEqual(host.edgePresentation?.paintedFrame, savedFrame)
            XCTAssertTrue(try XCTUnwrap(highlight(app)).animationKeys()?.isEmpty ?? true)
            XCTAssertNotNil(host.dockView.emptyStationRectForChecks)
            XCTAssertEqual(replies.count, 0)
            XCTAssertNil(app.composition.store.snapshot.rows)
        }

        let first = try await launch(initial: true)
        let firstHost = first.composition.dock
        let original = try XCTUnwrap(firstHost.edgePresentation?.paintedFrame)
        let subscribed = try await wait(5) { FileManager.default.fileExists(atPath: receipt.path) }
        XCTAssertTrue(subscribed)
        try await checkEngine(first)
        XCTAssertEqual(replies.count, 0)
        try select("Hide Quota Widget", in: firstHost.menu())
        try await waitForSettings(first.settingsHost.application.editor) {
            first.settingsHost.application.editor.snapshot?.preferences.showDock == false
        }
        XCTAssertNil(firstHost.edgePresentation?.paintedFrame)
        await first.stopLifecycle()
        firstHost.close()
        try FileManager.default.removeItem(at: receipt)

        let app = try await launch()
        let host = app.composition.dock, editor = app.settingsHost.application.editor
        let subscribedAgain = try await wait(5) { FileManager.default.fileExists(atPath: receipt.path) }
        XCTAssertTrue(subscribedAgain, "The reopened profile must use a new real server subscription")
        try await checkEngine(app)
        XCTAssertEqual(editor.snapshot?.preferences.showDock, false)
        XCTAssertNil(host.edgePresentation?.paintedFrame)

        try show(app)
        try await checkShown(app, at: original)
        XCTAssertEqual(editor.snapshot?.preferences.showDock, true)
        let highlightBefore = try XCTUnwrap(highlight(app))
        let revisionBefore = editor.snapshot?.revision
        try show(app)
        let newHighlight = try await wait(2) { highlight(app).map { $0 !== highlightBefore } ?? false }
        XCTAssertTrue(newHighlight)
        try await checkShown(app, at: original)
        XCTAssertEqual(editor.snapshot?.revision, revisionBefore, "Show on an expanded widget must only highlight")

        _ = try await editor.commit(SettingsB21Edit.autoHide(true))
        let collapsed = try await wait(4) { host.edgePresentation?.state == .sliver }
        XCTAssertTrue(collapsed)
        let stripRevision = editor.snapshot?.revision
        try show(app)
        try await checkShown(app, at: original)
        XCTAssertEqual(editor.snapshot?.revision, stripRevision)
        XCTAssertEqual(editor.snapshot?.preferences.autoHide, true)
        let collapsedAgain = try await wait(4) { host.edgePresentation?.state == .sliver }
        XCTAssertTrue(collapsedAgain)

        func checkSettings(_ shown: Bool) async throws {
            _ = try await editor.commit(SettingsB21Edit.showDock(shown))
            let settings = await editor.store.snapshot()
            XCTAssertEqual(settings.preferences.showDock, shown)
            let rows = try SettingsCatalogue.rows(preferences: settings.preferences, context: editor.context, paneID: "dock")
            XCTAssertEqual(rows.first { $0.key == .showDock }?.value, .toggle(shown))
            XCTAssertEqual(host.edgePresentation?.paintedFrame != nil, shown)
            XCTAssertEqual(app.liveStatusMenu?.items.first { $0.title == "Show Quota Widget" }?.isEnabled, true)
        }
        try await checkSettings(false)
        try await checkSettings(true)

        func blockedShow(reconnects: Bool, block: () -> Void, unblock: () -> Void) async throws {
            try await checkSettings(false)
            block()
            if reconnects { try FileManager.default.removeItem(at: receipt) }
            try show(app)
            try await waitForSettings(editor) { editor.snapshot?.preferences.showDock == true && !editor.isSaving }
            XCTAssertNil(host.edgePresentation?.paintedFrame)
            XCTAssertNil(highlight(app))
            unblock()
            try await checkShown(app, at: original)
            if reconnects {
                let resubscribed = try await wait(5) { FileManager.default.fileExists(atPath: receipt.path) }
                XCTAssertTrue(resubscribed, "The resumed app must resubscribe to the real server")
                try await checkEngine(app)
                XCTAssertEqual(replies.count, 0)
            }
        }
        try await blockedShow(reconnects: true,
                              block: { workspace.post(name: NSWorkspace.willSleepNotification, object: nil) },
                              unblock: { workspace.post(name: NSWorkspace.didWakeNotification, object: nil) })
        try await blockedShow(reconnects: true,
                              block: { workspace.post(name: NSWorkspace.sessionDidResignActiveNotification, object: nil) },
                              unblock: { workspace.post(name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil) })
        try await blockedShow(reconnects: false,
                              block: { host.setCockpitPresentationBlocked(true) },
                              unblock: { host.setCockpitPresentationBlocked(false) })
        try await checkEngine(app)
        XCTAssertEqual(replies.count, 0)
    }

    func testD14PhysicalHideRelaunchAndShowWhileRowsAreWithheld() async throws {
        preserveTestAppAppearance()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dock-d14-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let (relay, _, home) = try await makeRowsBarrier(in: root)
        let profile = root.appendingPathComponent("profile")
        let first = try await make(profile, nil, executable: relay, helperHome: home) {
            $0.motion = .on
            $0.autoHide = false
            $0.showDock = true
            $0.dockEdge = .right
        }
        addTeardownBlock { @MainActor in
            await first.stopNativeDockJourney()
            EngineRowsEntry.nativeJourneyProfile = nil
        }
        launch(first)
        let visible = try await wait(8) { first.nativeJourneyStatusVisible && first.composition.dock.nativePanel?.isVisible == true }
        let original = try XCTUnwrap(visible ? first.composition.dock.nativePanel?.frame : nil)
        let firstEditor = first.settingsHost.application.editor
        try await watchPhysicalMenu(matching: first.composition.dock.ownsDockMenu, action: "Right-click the visible widget and select Hide Quota Widget.") {
            firstEditor.snapshot?.preferences.showDock == false && !firstEditor.isSaving &&
                first.composition.dock.nativePanel?.isVisible != true
        }
        let hidden = await firstEditor.store.snapshot()
        XCTAssertFalse(hidden.preferences.showDock)
        XCTAssertNil(first.composition.store.snapshot.rows)
        await first.stopNativeDockJourney()

        let second = try await make(profile, nil, executable: relay, helperHome: home)
        addTeardownBlock { @MainActor in
            await second.stopNativeDockJourney()
            EngineRowsEntry.nativeJourneyProfile = nil
        }
        launch(second)
        let editor = second.settingsHost.application.editor
        let ready = try await wait(8) {
            second.nativeJourneyStatusVisible && editor.snapshot?.preferences.showDock == false
        }
        XCTAssertTrue(ready)
        XCTAssertFalse(second.composition.dock.nativePanel?.isVisible == true)
        XCTAssertEqual(editor.snapshot?.revision, hidden.revision)
        promptD14("Capture the still-hidden widget after reopening the same profile.")

        let host = second.composition.dock
        func highlight() -> CALayer? {
            host.dockView.layer?.sublayers?.first { $0.name == "dock.locate-highlight" }
        }
        second.setActivityPaused(true)
        let paused = try await wait(4) { second.lifecyclePaused && host.nativePanel?.isVisible != true }
        XCTAssertTrue(paused)
        let pausedMenu = try XCTUnwrap(second.liveStatusMenu)
        XCTAssertTrue(pausedMenu.items.contains { $0.title == "Show Quota Widget" && $0.isEnabled })
        try await watchPhysicalMenu(matching: { $0 === pausedMenu }, action: "In the status menu, select Show Quota Widget while presentation is paused.") {
            editor.snapshot?.preferences.showDock == true && !editor.isSaving
        }
        XCTAssertEqual(editor.snapshot?.revision, hidden.revision + 1)
        XCTAssertFalse(host.nativePanel?.isVisible == true)
        XCTAssertNil(highlight())
        second.setActivityPaused(false)
        let revealed = try await wait(8) { host.nativePanel?.isVisible == true && highlight() != nil }
        XCTAssertTrue(revealed)
        XCTAssertEqual(host.nativePanel?.frame, original)
        XCTAssertNotNil(host.dockView.emptyStationRectForChecks)
        XCTAssertNil(second.composition.store.snapshot.rows)
        let firstMark = try XCTUnwrap(highlight())
        XCTAssertTrue(firstMark.animationKeys()?.isEmpty ?? true)
        promptD14("Capture the empty widget restored to its original position with a static highlight.")

        let showAgain = try XCTUnwrap(second.liveStatusMenu)
        let shownRevision = editor.snapshot?.revision
        try await watchPhysicalMenu(matching: { $0 === showAgain }, action: "Select Show Quota Widget again while the widget is already visible.") {
            highlight().map { $0 !== firstMark } == true
        }
        XCTAssertEqual(host.nativePanel?.frame, original)
        XCTAssertEqual(editor.snapshot?.revision, shownRevision)
        XCTAssertTrue(try XCTUnwrap(highlight()).animationKeys()?.isEmpty ?? true)

        _ = try await editor.commit(SettingsB21Edit.autoHide(true))
        promptD14("Move the pointer away from the widget until it collapses to the strip.")
        let collapsed = try await wait(12) { host.edgePresentation?.state == .sliver }
        XCTAssertTrue(collapsed)
        let stripMenu = try XCTUnwrap(second.liveStatusMenu)
        let stripRevision = editor.snapshot?.revision
        try await watchPhysicalMenu(matching: { $0 === stripMenu }, action: "With the strip collapsed, select Show Quota Widget in the status menu.") {
            host.edgePresentation?.state == .expanded && highlight() != nil
        }
        XCTAssertTrue(try XCTUnwrap(highlight()).animationKeys()?.isEmpty ?? true)
        promptD14("Keep the pointer away and capture the strip collapsing again by its normal rule.")
        let recollapsed = try await wait(12) { host.edgePresentation?.state == .sliver }
        XCTAssertTrue(recollapsed)
        XCTAssertEqual(editor.snapshot?.revision, stripRevision)
        XCTAssertTrue(editor.snapshot?.preferences.autoHide == true)
        XCTAssertNil(second.composition.store.snapshot.rows)
    }

    func testD14PhysicalSettingsToggleAndStatusMenuStayInSync() async throws {
        preserveTestAppAppearance()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dock-d14-settings-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let (_, _, home) = try await makeRowsBarrier(in: root)
        let app = try await make(root.appendingPathComponent("profile"), nil, executable: try reviewedHelper(),
                                 helperHome: home) {
            $0.autoHide = false
            $0.onboarding.next()
        }
        addTeardownBlock { @MainActor in
            await app.stopNativeDockJourney()
            EngineRowsEntry.nativeJourneyProfile = nil
        }
        launch(app)
        let ready = try await wait(12) {
            app.nativeJourneyStatusVisible && !app.lifecyclePaused && app.composition.dock.nativePanel?.isVisible == true
        }
        guard ready else { return XCTFail("Settings needs the real native launch and a current engine delivery") }
        let windowsBefore = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
        let menu = try XCTUnwrap(app.liveStatusMenu)
        func settingsWindow() -> NSWindow? {
            NSApplication.shared.windows.first { !windowsBefore.contains(ObjectIdentifier($0)) && $0.isVisible && $0.title == "Settings" }
        }
        try await watchPhysicalMenu(matching: { $0 === menu }, action: "Open Settings from the native status menu and select the Quota Widget pane.") {
            settingsWindow() != nil
        }
        let editor = app.settingsHost.application.editor
        let frame = try XCTUnwrap(app.composition.dock.nativePanel?.frame)
        for shown in [false, true] {
            promptD14("In Settings, turn Show Quota Widget \(shown ? "on" : "off"). Capture the result.")
            let applied = try await wait(45) {
                editor.snapshot?.preferences.showDock == shown && !editor.isSaving &&
                    (app.composition.dock.nativePanel?.isVisible == true) == shown
            }
            XCTAssertTrue(applied)
            let stored = await editor.store.snapshot()
            XCTAssertEqual(stored.preferences.showDock, shown)
            XCTAssertTrue(app.liveStatusMenu?.items.contains { $0.title == "Show Quota Widget" && $0.isEnabled } == true)
            if shown { XCTAssertEqual(app.composition.dock.nativePanel?.frame, frame) }
        }
    }
    func testD15PhysicalRestingPanelRendersEveryDisplayEdgeAndSize() async throws {
        preserveTestAppAppearance()
        let topology = DockDisplayTopology.system()
        guard topology.displays.count >= 2, topology.displays.indices.allSatisfy({ index in
            topology.displays[..<index].allSatisfy { !$0.frame.intersects(topology.displays[index].frame) }
        }) else { return XCTFail("D-15 needs at least two actual non-mirrored displays") }

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dock-d15-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let (_, _, home) = try await makeRowsBarrier(in: root)
        let now = Date()
        let iso = ISO8601DateFormatter()
        let quotas = [76, 58, 41, 25]
        let ids = quotas.indices.map { "synthetic-d15-\($0)" }
        let plans = ids.map { ["planId": $0] }
        let windows: [[String: Any]] = zip(ids, quotas).map { id, remaining in
            ["planId": id, "kind": "five_hour", "remainingPercent": remaining, "resetMode": "rolling",
             "observedAt": iso.string(from: now.addingTimeInterval(-10)),
             "resetAt": iso.string(from: now.addingTimeInterval(7_200))]
        }
        let settingsDirectory = home.appendingPathComponent(".config/modelplan")
        try FileManager.default.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "plans": plans, "windows": windows])
        try data.write(to: settingsDirectory.appendingPathComponent("local.json"), options: .atomic)
        let app = try await make(root.appendingPathComponent("profile"), nil, executable: try reviewedHelper(),
                                 helperHome: home) {
            $0.autoHide = false
            $0.followActiveDisplay = false
            $0.onboarding.next()
        }
        addTeardownBlock { @MainActor in
            await app.stopNativeDockJourney()
            EngineRowsEntry.nativeJourneyProfile = nil
        }
        launch(app)
        let host = app.composition.dock
        let ready = try await wait(12) {
            app.nativeJourneyStatusVisible && !app.lifecyclePaused && host.nativePanel?.isVisible == true &&
                Set(host.dockView.presentedReadingsForChecks.values.compactMap(\.remainingPercent)) == Set(quotas.map(Double.init))
        }
        guard ready else { return XCTFail("The real helper must deliver the four synthetic readings") }
        let panel = try XCTUnwrap(host.nativePanel)
        let editor = app.settingsHost.application.editor
        let edges: [(SettingsDockEdge, DockEdge)] = [(.left, .left), (.right, .right), (.bottom, .bottom)]
        let requestedAppearance = ProcessInfo.processInfo.environment["MODELPLAN_DOCK_D15_THEME"] ?? "night"
        let theme = try XCTUnwrap(SettingsTheme(rawValue: requestedAppearance))
        _ = try await editor.commit(SettingsB20Edit.theme(theme))

        for (index, screen) in topology.displays.enumerated() {
            _ = try await editor.commit(SettingsB21Edit.dockDisplay(screen.id))
            for (preference, edge) in edges {
                _ = try await editor.commit(SettingsB21Edit.dockEdge(preference))
                for size in [SettingsSize.small, .medium, .large] {
                    _ = try await editor.commit(SettingsB20Edit.size(size))
                    let label = "display \(index + 1), \(edge), \(size), \(theme)"
                    let visible = try await wait(4) {
                        panel.isVisible && panel.occlusionState.contains(.visible) &&
                            host.edgePresentation?.placement?.displayID == screen.id &&
                            host.edgePresentation?.placement?.edge == edge
                    }
                    XCTAssertTrue(visible, label)
                    let place = try XCTUnwrap(host.edgePresentation?.placement)
                    let view = try XCTUnwrap(panel.contentView?.subviews.compactMap { $0 as? DockInstrumentView }.first)
                    XCTAssertEqual(view.appearanceDisplaySize, screen.usableFrame.size, label)
                    XCTAssertEqual(view.presentationBackingScale, screen.backingScale, label)
                    XCTAssertEqual(panel.frame.width, place.frame.width, accuracy: 1, label)
                    XCTAssertEqual(panel.frame.height, place.frame.height, accuracy: 1, label)
                    XCTAssertTrue(screen.usableFrame.insetBy(dx: -1, dy: -1).contains(panel.frame), label)
                    switch edge {
                    case .left: XCTAssertEqual(panel.frame.minX, screen.usableFrame.minX, accuracy: 1, label)
                    case .right: XCTAssertEqual(panel.frame.maxX, screen.usableFrame.maxX, accuracy: 1, label)
                    case .bottom: XCTAssertEqual(panel.frame.minY, screen.usableFrame.minY, accuracy: 1, label)
                    case .top: XCTFail("Top is not an allowed resting edge")
                    }
                    let skin = try XCTUnwrap(view.presentedSkinForChecks)
                    let nozzles = skin.stations.filter { $0.subscriptionID != nil }
                    XCTAssertFalse(nozzles.isEmpty, label)
                    for nozzle in nozzles { XCTAssertEqual(nozzle.diameter, size.nozzleDiameter, accuracy: 0.001, label) }
                    XCTAssertEqual(nozzles.count + view.interactionOverflowIDs.count, quotas.count, label)
                    let raster = try XCTUnwrap(view.renderedPixelSize)
                    XCTAssertEqual(raster.width, ceil(view.bounds.width * CGFloat(screen.backingScale)), label)
                    XCTAssertEqual(raster.height, ceil(view.bounds.height * CGFloat(screen.backingScale)), label)
                    FileHandle.standardOutput.write(Data(("D-15: Capture " + label +
                        " at 100%. Native raster \(Int(raster.width))×\(Int(raster.height)).\n").utf8))
                    try await Task.sleep(for: .seconds(5))
                }
            }
        }
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
