// SPDX-License-Identifier: MIT
#if MODELPLAN_DOCK_REAL_ACTIVITY_JOURNEY
import AppKit
import CryptoKit
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanEngineClient
import ModelPlanOfficialDock
import ModelPlanPrimitives
import ModelPlanSettings
import XCTest
@_spi(DockResourceChecks) @testable import ModelPlanAppIntegration

@MainActor final class V15RealServerActivityTests: XCTestCase {
    private func quote(_ path: String) -> String { "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    private func script(_ name: String, in root: URL, _ text: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        return url
    }

    private func sandbox() throws -> (URL, URL, [String: String]) {
        let executable = try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_DOCK_TEST_CLI"])
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("v15-real-activity-" + UUID().uuidString)
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

    private func eventually(_ condition: () -> Bool) async throws -> Bool {
        let deadline = ContinuousClock.now + .seconds(8)
        while !condition() && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
        return condition()
    }

    func testV15RealServerLogTransitionsReachOnlyTheBoundDockMember() async throws {
        let (root, helper, environment) = try sandbox()
        let cache = root.appendingPathComponent("Library/Caches/modelplan/observed")
        let response = root.appendingPathComponent("rpc.json")
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
        let now = Date(), iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        _ = try await command(["consent", "init", "--json"], helper: helper, environment: environment)
        let before = try await command(["consent", "--json"], helper: helper, environment: environment)
        _ = try await command(["consent", "grant", "--json"], helper: helper, environment: environment, input: [
            "requestId": UUID().uuidString.lowercased(),
            "expectStoreEpoch": try XCTUnwrap(before["storeEpoch"] as? String),
            "expectGeneration": try XCTUnwrap(before["generation"] as? Int),
            "consentTextVersion": try XCTUnwrap(before["consentTextVersion"] as? Int),
            "allow": ["codex.runtime_usage", "codex.local_history"], "deny": [String](),
        ])
        let granted = try await command(["consent", "--json"], helper: helper, environment: environment)
        let epoch = try XCTUnwrap(granted["storeEpoch"] as? String)
        try encode(["rateLimits": ["planType": "plus", "secondary": ["usedPercent": 25,
            "windowDurationMins": 10080, "resetsAt": Int(now.timeIntervalSince1970) + 86_400]]])
            .write(to: response, options: .atomic)
        _ = try await command(["quota", "--refresh-account", "--json", "--offline"], helper: helper, environment: environment)
        let account = try decode(Data(contentsOf: cache.appendingPathComponent("codex-account.json")))
        let ref = try XCTUnwrap(account["subscriptionRef"] as? String)
        let declared = root.appendingPathComponent(".config/modelplan/local.json")
        let peer = "v15-critical-without-session"
        try FileManager.default.createDirectory(at: declared.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encode(["schemaVersion": 1, "plans": [["planId": peer]], "windows": [[
            "planId": peer, "kind": "five_hour", "remainingPercent": 12, "resetMode": "rolling",
            "observedAt": iso.string(from: now), "resetAt": iso.string(from: now.addingTimeInterval(7_200)),
        ]]]).write(to: declared, options: .atomic)
        let log = root.appendingPathComponent(".codex/sessions/rollout-synthetic.jsonl")
        try FileManager.default.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true)
        func turn(_ type: String) throws {
            var record = try encode(["timestamp": iso.string(from: Date()), "type": "event_msg",
                                     "payload": ["type": type]])
            record.append(0x0a)
            try record.write(to: log, options: .atomic)
        }
        let key = SHA256.hash(data: Data(log.path.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
        func bindSession() throws {
            try encode(["schemaVersion": 1, "since": iso.string(from: now), "rows": [], "sessions": [[
                "source": "codex", "key": key, "ref": "cccccccccccccccc", "subscriptionRef": ref,
                "grantEpoch": ["storeEpoch": epoch, "revokedGeneration": 0],
                "firstAt": iso.string(from: now), "lastAt": iso.string(from: now), "days": [],
            ]]]).write(to: cache.appendingPathComponent("perf.json"), options: .atomic)
        }
        try turn("task_started")

        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        _ = try await settings.update { $0.autoHide = false; $0.motion = .system }
        let app = EngineRowsEntry.make(configuration: .init(executableURL: helper, applicationVersion: "v15-real-activity",
            allowedEnvironment: environment, offline: true, readOnly: true), settingsStore: settings,
            createsNativePanels: false, bundleURL: root.appendingPathComponent("Synthetic.app"),
            activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        let dock = app.composition.dock
        dock.installWorkingEffectsForChecks(pool: EffectResourcePool(), provider: try T2FlameFrameProvider.bundled(),
                                            systemReduceMotion: { false })
        var rotation: [String: Double] = [:]
        dock.workingEffectsDidConfigureForChecks = { [weak dock] in rotation = dock?.workingEffectRotationPeriodsForChecks ?? [:] }
        await app.prepare()
        app.updateSystemAccessibility(.init())
        app.allowDockPresentation()
        let delivery = try await app.composition.client.start()
        _ = try await app.composition.client.subscribeRows(timeout: .seconds(4))
        func activity() -> [String] {
            let row = app.composition.store.snapshot.rows?.projection.rows.first { $0.id == "codex" }
            return (row?.accounts ?? []).flatMap { ($0.activity ?? []).map(\.subscriptionRef) }
        }
        let admitted = try await eventually {
            dock.dockView.presentedReadingsForChecks[ref]?.remainingPercent == 75 &&
                dock.dockView.presentedReadingsForChecks.values.contains { $0.remainingPercent == 12 }
        }
        guard admitted else {
            let rowStates = (app.composition.store.snapshot.rows?.projection.rows ?? []).map {
                "\($0.id) \($0.state) \($0.reason.code) \($0.accounts.flatMap { $0.windows.compactMap(\.remainingPercent) })"
            }
            let drawn = dock.dockView.presentedReadingsForChecks.values.compactMap(\.remainingPercent).sorted()
            return XCTFail("Synthetic baseline did not render: rows \(rowStates), drawn \(drawn)")
        }
        try await Task.sleep(for: .milliseconds(2_200))
        XCTAssertTrue(activity().isEmpty)
        XCTAssertTrue(dock.activeWorkingEffectIDs.isEmpty)

        try bindSession()
        let active = try await eventually { activity() == [ref] && rotation == [ref: 1] }
        XCTAssertTrue(active, "A real rows update must animate only the bound account")
        XCTAssertEqual(dock.activeWorkingEffectIDs, [ref])
        XCTAssertEqual(app.composition.store.snapshot.delivery, delivery)

        _ = try await app.settingsHost.application.editor.commit(SettingsB20Edit.motion(.on))
        XCTAssertEqual(dock.activeWorkingEffectIDs, [ref])
        XCTAssertTrue(rotation.isEmpty)
        XCTAssertTrue(dock.animatingWorkingEffectIDs.isEmpty)
        try turn("task_complete")
        let idle = try await eventually { dock.activeWorkingEffectIDs.isEmpty }
        XCTAssertTrue(idle, "The terminal log record must withdraw the native effect")
        XCTAssertTrue(rotation.isEmpty)
        XCTAssertEqual(app.composition.store.snapshot.delivery, delivery)
        XCTAssertTrue(dock.dockView.presentedReadingsForChecks.values.contains { $0.remainingPercent == 12 })
    }
}
#endif
