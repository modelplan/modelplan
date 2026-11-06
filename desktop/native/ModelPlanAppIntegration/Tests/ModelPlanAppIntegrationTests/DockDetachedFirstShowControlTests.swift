// SPDX-License-Identifier: MIT
#if MODELPLAN_DOCK_NATIVE_JOURNEY
import AppKit
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class DockDetachedFirstShowControlTests: XCTestCase {
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
    private func checkEngine(_ app: EngineDockMenuApplication) async throws {
        let ready = try await wait(5) {
            if case .ready = app.composition.store.snapshot.connection { return true }
            return false
        }
        XCTAssertTrue(ready, "The real app-server must handshake")
    }
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

}
#endif
