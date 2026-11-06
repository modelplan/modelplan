// SPDX-License-Identifier: MIT
#if MODELPLAN_DOCK_REAL_STALL_JOURNEY
import AppKit
import ModelPlanEngineClient
import ModelPlanSettings
@_spi(DockResourceChecks) import ModelPlanDock
import XCTest
@testable import ModelPlanAppIntegration

@MainActor private final class G5CapturedTimer: DockEdgeScheduling {
    var deadline: TimeInterval?
    private var action: (@MainActor () -> Void)?
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) {
        self.deadline = deadline; self.action = action
    }
    func cancel() { deadline = nil; action = nil }
    func advance(to now: TimeInterval) {
        guard let deadline, deadline <= now else { return }
        let pending = action
        cancel()
        pending?()
    }
}

@MainActor final class G5RealEngineStallTests: XCTestCase {
    private func quote(_ path: String) -> String { "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    private func script(_ name: String, in root: URL, _ text: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        return url
    }

    private func sandbox() throws -> (URL, URL, [String: String]) {
        let executable = try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_DOCK_TEST_CLI"])
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("g5-real-engine-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        let environment = ["HOME": root.path, "TMPDIR": root.path, "PATH": root.path + ":/usr/bin:/bin", "LANG": "C"]
        // Keep production scheduling enabled while blocking child network access.
        let helper = try script("app-cli", in: root, """
            #!/bin/sh
            exec /usr/bin/sandbox-exec -p '(version 1)(allow default)(deny network*)' \(quote(executable)) "$@"
            """)
        return (root, helper, environment)
    }

    private func encode(_ json: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: json) }
    private func decode(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
    private func command(_ arguments: [String], helper: URL, environment: [String: String], input: [String: Any]? = nil) async throws -> [String: Any] {
        let child = Process(), output = Pipe(), stdin = input.map { _ in Pipe() }
        child.executableURL = helper; child.arguments = arguments; child.environment = environment
        child.standardOutput = output; child.standardError = FileHandle.nullDevice
        child.standardInput = stdin ?? FileHandle.nullDevice
        try child.run()
        if let input, let stdin {
            try stdin.fileHandleForWriting.write(contentsOf: encode(input))
            try stdin.fileHandleForWriting.close()
        }
        let deadline = ContinuousClock.now + .seconds(8)
        while child.isRunning && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        if child.isRunning { child.terminate(); throw CocoaError(.fileReadUnknown) }
        guard child.terminationStatus == 0 else {
            XCTFail("Synthetic CLI failed: \(arguments.joined(separator: " "))")
            throw CocoaError(.fileReadUnknown)
        }
        return try decode(output.fileHandleForReading.readDataToEndOfFile())
    }

    private func wait(_ condition: () -> Bool) async throws -> Bool {
        let end = ContinuousClock.now + .seconds(8)
        while !condition() && ContinuousClock.now < end { try await Task.sleep(for: .milliseconds(20)) }
        return condition()
    }

    func testG5RealChildStallAdvancesCountdownExpiresAndRecoversAfterLifecycleRestart() async throws {
        let (root, helper, environment) = try sandbox()
        let cache = root.appendingPathComponent("Library/Caches/modelplan/observed")
        let accountURL = cache.appendingPathComponent("codex-account.json")
        let attempts = cache.appendingPathComponent("reader-attempts/codex.json")
        let response = root.appendingPathComponent("rpc.json")
        let paused = root.appendingPathComponent("pause-child"), receipt = root.appendingPathComponent("child-paused")
        _ = try script("codex", in: root, """
            #!/bin/sh
            [ "$1" = app-server ] || exit 2
            while IFS= read -r line; do
                case "$line" in
                *'"id":1,'*) echo '{"id":1,"result":{"userAgent":"synthetic"}}' ;;
                *'"method":"account/rateLimits/read"'*) printf '{"id":2,"result":%s}\n' "$(cat \(quote(response.path)))" ;;
                *'"method":"account/read"'*) echo '{"id":3,"result":{"account":{"type":"chatgpt","email":"synthetic@example.invalid"}}}' ;;
                esac
            done
            """)
        let paths = try JSONEncoder().encode([helper.path, paused.path, receipt.path])
        let relay = try script("stall-helper", in: root, """
            #!/usr/bin/python3
            import base64
            import json
            import pathlib
            import signal
            import subprocess
            import sys
            import time

            helper, flag, acknowledgement = json.loads(base64.b64decode("\(paths.base64EncodedString())"))
            child = subprocess.Popen([helper, *sys.argv[1:]])
            paused = False

            def resume_and_terminate(signum, frame):
                if child.poll() is None:
                    child.send_signal(signal.SIGCONT)
                    child.terminate()

            signal.signal(signal.SIGTERM, resume_and_terminate)
            signal.signal(signal.SIGINT, resume_and_terminate)
            while child.poll() is None:
                requested = pathlib.Path(flag).exists()
                if requested != paused:
                    child.send_signal(signal.SIGSTOP if requested else signal.SIGCONT)
                    paused = requested
                    if requested:
                        pathlib.Path(acknowledgement).touch()
                    else:
                        pathlib.Path(acknowledgement).unlink(missing_ok=True)
                time.sleep(0.01)
            sys.exit(child.returncode)
            """)
        _ = try await command(["consent", "init", "--json"], helper: helper, environment: environment)
        let before = try await command(["consent", "--json"], helper: helper, environment: environment)
        _ = try await command(["consent", "grant", "--json"], helper: helper, environment: environment, input: [
            "requestId": UUID().uuidString.lowercased(),
            "expectStoreEpoch": try XCTUnwrap(before["storeEpoch"] as? String),
            "expectGeneration": try XCTUnwrap(before["generation"] as? Int),
            "consentTextVersion": try XCTUnwrap(before["consentTextVersion"] as? Int),
            "allow": ["codex.runtime_usage"], "deny": [String](),
        ])
        let iso = ISO8601DateFormatter()
        func publish(remaining: Int) async throws {
            try encode(["rateLimits": ["planType": "plus", "secondary": ["usedPercent": 100 - remaining,
                "windowDurationMins": 10080, "resetsAt": Int(Date().timeIntervalSince1970) + 7_200]]])
                .write(to: response, options: .atomic)
            _ = try await command(["quota", "--refresh-account", "--json", "--offline"], helper: helper, environment: environment)
        }
        try await publish(remaining: 41)
        let account = try decode(Data(contentsOf: accountURL))
        let member = try XCTUnwrap(account["subscriptionRef"] as? String)
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        _ = try await settings.update { $0.autoHide = false }
        var wall = Date(), elapsed: TimeInterval = 100
        let timer = G5CapturedTimer()
        let display = DockDisplayArea(id: "synthetic", frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 72, width: 1440, height: 798))
        let app = EngineRowsEntry.make(configuration: .init(executableURL: relay, applicationVersion: "synthetic-stall",
            allowedEnvironment: environment, offline: true, readOnly: true), settingsStore: settings,
            createsNativePanels: false, bundleURL: root.appendingPathComponent("Synthetic.app"),
            dockEnvironment: {
                .init(displays: [display], layouts: [], primaryDisplayID: display.id, pointer: CGPoint(x: 700, y: 400))
            }, deadlineNow: { wall }, deadlineElapsed: { elapsed },
            deadlineScheduling: timer, activateSettings: {})
        let workspace = NotificationCenter()
        addTeardownBlock { @MainActor in
            try? FileManager.default.removeItem(at: paused)
            await app.stopLifecycle()
            await app.composition.stop()
        }
        await app.prepare()
        app.startLifecycle(workspace: workspace, local: NotificationCenter(), lockEvents: NotificationCenter(),
            displayIDs: { [1] }, onConsole: { true }, displaysAsleep: { _ in false })
        let dock = app.composition.dock
        let view = dock.dockView
        guard try await wait({ view.presentedReadingsForChecks[member]?.remainingPercent == 41 }) else {
            let state = app.composition.store.snapshot.rows?.projection.rows.first { $0.id == "codex" }
            return XCTFail("The initial runtime reading must render: \(String(describing: state?.reason.code))")
        }
        let original = try XCTUnwrap(app.composition.store.snapshot.delivery)
        let rows = try XCTUnwrap(app.composition.store.snapshot.rows)
        let initial = try XCTUnwrap(view.presentedReadingsForChecks[member]?.timeLeftFraction)
        guard case .scheduled(let expiry, _) = EngineDeadlineFacts.evaluate(rows: rows.projection.rows, now: wall) else {
            return XCTFail("The real source must supply an admitted presentation deadline")
        }
        XCTAssertGreaterThan(expiry.timeIntervalSince(wall), 61)
        try Data().write(to: paused)
        let stopped = try await wait { FileManager.default.fileExists(atPath: receipt.path) }
        guard stopped else { return XCTFail("The supervisor did not pause its own helper child") }
        func advance(_ seconds: TimeInterval) {
            elapsed += seconds
            wall.addTimeInterval(seconds)
            timer.advance(to: elapsed)
        }
        print("G5 stage: paused helper")
        advance(61)
        let later = try XCTUnwrap(view.presentedReadingsForChecks[member]?.timeLeftFraction)
        XCTAssertLessThan(later, initial, "Countdown must advance while the actual helper is stopped")
        XCTAssertEqual(view.presentedReadingsForChecks[member]?.remainingPercent, 41)
        XCTAssertEqual(app.composition.store.snapshot.rows?.sequence, rows.sequence)
        advance(expiry.timeIntervalSince(wall) + 1)
        XCTAssertEqual(view.presentedReadingsForChecks[member]?.dataState, .stale)
        XCTAssertNil(view.presentedReadingsForChecks[member]?.remainingPercent)
        XCTAssertEqual(app.composition.store.snapshot.rows?.sequence, rows.sequence)
        XCTAssertEqual(app.composition.store.snapshot.delivery, original)

        print("G5 stage: presentation expired")
        let due = iso.string(from: Date().addingTimeInterval(-600))
        var expired = account
        expired["observedAt"] = due
        try encode(expired).write(to: accountURL, options: .atomic)
        try FileManager.default.createDirectory(at: attempts.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encode(["schemaVersion": 1, "nextAttemptAt": due]).write(to: attempts, options: .atomic)
        try await publish(remaining: 23)
        let refreshed = try decode(Data(contentsOf: accountURL))
        let refreshedWindows = try XCTUnwrap(refreshed["windows"] as? [[String: Any]])
        let used = refreshedWindows.compactMap { $0["usedPercent"] as? Double }
        XCTAssertTrue(used.contains(77), "The fixture must stage 23% before restarting: \(used)")
        workspace.post(name: NSWorkspace.willSleepNotification, object: nil)
        try FileManager.default.removeItem(at: paused)
        let retired = try await wait { app.composition.store.snapshot.connection == .stopped(.requested) }
        guard retired else { return XCTFail("The lifecycle must retire the old helper before resuming") }
        XCTAssertNil(app.composition.store.snapshot.rows)
        wall = Date()
        workspace.post(name: NSWorkspace.didWakeNotification, object: nil)
        let recovered = try await wait {
            guard let next = app.composition.store.snapshot.delivery, next.sessionID != original.sessionID else { return false }
            return view.presentedReadingsForChecks[member]?.remainingPercent == 23
        }
        if !recovered {
            let snapshot = app.composition.store.snapshot
            let codex = snapshot.rows?.projection.rows.first { $0.id == "codex" }
            let values = codex?.accounts.flatMap { $0.windows.compactMap(\.remainingPercent) } ?? []
            let failures = snapshot.failures.map { String(describing: $0.feature) }
            XCTFail("Restart did not recover: row=\(String(describing: codex?.reason.code)), values=\(values), failures=\(failures)")
        }
        let restarted = try XCTUnwrap(app.composition.store.snapshot.delivery)
        XCTAssertNotEqual(restarted.sessionID, original.sessionID)
        XCTAssertEqual(view.presentedReadingsForChecks[member]?.dataState, .fresh)
        XCTAssertEqual(app.composition.store.snapshot.delivery, restarted)
    }
}
#endif
