// SPDX-License-Identifier: MIT
#if MODELPLAN_DOCK_REAL_CONTEXT_JOURNEY
import AppKit
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings
import ModelPlanWire
import XCTest
@testable import ModelPlanAppIntegration

@MainActor private final class D11RefreshReplies: EngineStoreEventSink {
    private(set) var outcomes: [WireMemberRefreshResult] = []
    func acceptedEvent(_ event: EngineClientEvent) {
        if case .response(_, .memberRefresh(let reply)) = event { outcomes.append(reply.envelope.data) }
    }
    func apply(_ snapshot: EngineStoreSnapshot) {}
    func clearPrivateViews(_ invalidation: EngineInvalidation) {}
}

@MainActor final class DockNozzleRealServerGestureTests: XCTestCase {
    private func quote(_ path: String) -> String { "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    private func script(_ name: String, in root: URL, _ text: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        return url
    }

    private func sandbox() throws -> (URL, URL, [String: String]) {
        let executable = try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_DOCK_TEST_CLI"])
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("d11-member-gestures-" + UUID().uuidString)
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

    func testD11NormalNozzleDragsDoNotRefreshButStationaryClickDoes() async throws {
        let (root, helper, environment) = try sandbox()
        let cache = root.appendingPathComponent("Library/Caches/modelplan/observed")
        let reading = cache.appendingPathComponent("codex-account.json")
        let attempts = cache.appendingPathComponent("reader-attempts/codex.json")
        let response = root.appendingPathComponent("rpc.json"), calls = root.appendingPathComponent("runtime-calls")
        _ = try script("codex", in: root, """
            #!/bin/sh
            [ "$1" = app-server ] || exit 2
            while IFS= read -r line; do
                case "$line" in
                *'"id":1,'*) echo '{"id":1,"result":{"userAgent":"synthetic"}}' ;;
                *'"method":"account/rateLimits/read"'*)
                    printf 'read\\n' >> \(quote(calls.path))
                    printf '{"id":2,"result":%s}\\n' "$(cat \(quote(response.path)))" ;;
                *'"method":"account/read"'*) echo '{"id":3,"result":{"account":{"type":"chatgpt","email":"synthetic@example.invalid"}}}' ;;
                esac
            done
            """)
        let now = Date(), scope = "codex.runtime_usage"
        let iso = ISO8601DateFormatter()
        let controlPlan = "d11-independent-control"
        func writeResponse(used: Int) throws {
            try encode(["rateLimits": ["planType": "plus", "secondary": ["usedPercent": used,
                "windowDurationMins": 10080, "resetsAt": Int(now.timeIntervalSince1970) + 86_400]]]).write(to: response, options: .atomic)
        }
        func cliGrant(allow: [String], deny: [String]) async throws {
            let state = try await command(["consent", "--json"], helper: helper, environment: environment)
            _ = try await command(["consent", "grant", "--json"], helper: helper, environment: environment, input: [
                "requestId": UUID().uuidString.lowercased(), "expectStoreEpoch": try XCTUnwrap(state["storeEpoch"] as? String),
                "expectGeneration": try XCTUnwrap(state["generation"] as? Int),
                "consentTextVersion": try XCTUnwrap(state["consentTextVersion"] as? Int), "allow": allow, "deny": deny
            ])
        }
        _ = try await command(["consent", "init", "--json"], helper: helper, environment: environment)
        try await cliGrant(allow: [scope], deny: [])
        try writeResponse(used: 80)
        _ = try await command(["quota", "--refresh-account", "--json", "--offline"], helper: helper, environment: environment)
        var seed = try decode(Data(contentsOf: reading))
        let ref = try XCTUnwrap(seed["subscriptionRef"] as? String)
        try await cliGrant(allow: [], deny: [scope])
        try FileManager.default.removeItem(at: calls)
        try writeResponse(used: 30)
        let control: [String: Any] = ["schemaVersion": 1, "plans": [["planId": controlPlan]], "windows": [[
            "planId": controlPlan, "kind": "five_hour", "remainingPercent": 51, "resetMode": "rolling",
            "observedAt": iso.string(from: now.addingTimeInterval(-20)),
            "resetAt": iso.string(from: now.addingTimeInterval(7_200))
        ]]]
        try encode(control).write(to: root.appendingPathComponent(".config/modelplan/local.json"), options: .atomic)

        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        _ = try await settings.update { $0.autoHide = false; $0.motion = .on; $0.dockEdge = .bottom }
        let app = EngineRowsEntry.make(configuration: .init(executableURL: helper, applicationVersion: "d11-real-member",
            allowedEnvironment: environment), settingsStore: settings, createsNativePanels: false,
            bundleURL: root.appendingPathComponent("Synthetic.app"), dockEnvironment: normalEntryTestEnvironment,
            activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.prepare()
        app.allowDockPresentation()
        func controlReading() -> Double? {
            app.composition.store.snapshot.rows?.projection.rows.first { $0.id == "declared:" + controlPlan }?
                .accounts.first?.windows.first?.remainingPercent
        }
        let client = app.composition.client
        _ = try await client.start()
        _ = try await client.subscribeRows(timeout: .seconds(4))
        XCTAssertNil(app.composition.accountMembers.members.first { $0.id == ref })
        XCTAssertEqual(controlReading(), 51)
        XCTAssertFalse(FileManager.default.fileExists(atPath: calls.path))

        // Startup has completed with the scope denied. Grant only this test
        // profile, then restore a due synthetic cache entry under the new fence.
        try await cliGrant(allow: [scope], deny: [])
        let granted = try await command(["consent", "--json"], helper: helper, environment: environment)
        let epoch = try XCTUnwrap(granted["storeEpoch"] as? String), generation = try XCTUnwrap(granted["generation"] as? Int)
        let old = iso.string(from: now.addingTimeInterval(-360))
        seed["observedAt"] = old
        var windows = try XCTUnwrap(seed["windows"] as? [[String: Any]])
        windows[0]["observedAt"] = old
        seed["windows"] = windows
        seed["admission"] = ["storeEpoch": epoch, "generation": generation, "scope": scope]
        try FileManager.default.createDirectory(at: attempts.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encode(["schemaVersion": 1, "nextAttemptAt": old]).write(to: attempts, options: .atomic)
        try encode(seed).write(to: reading, options: .atomic)

        func member() -> EngineAccountMember? { app.composition.accountMembers.members.first { $0.id == ref } }
        let readiness = ContinuousClock.now + .seconds(6)
        while (member() == nil || app.memberRefreshAdapter == nil) && ContinuousClock.now < readiness {
            try await Task.sleep(for: .milliseconds(20))
        }
        let current = try XCTUnwrap(app.composition.store.snapshot.delivery)
        let before = try XCTUnwrap(member())
        let adapter = try XCTUnwrap(app.memberRefreshAdapter)
        XCTAssertEqual(adapter.admission(for: before, delivery: current, now: Date()), .ready)
        XCTAssertEqual(before.account.windows.first?.remainingPercent, 20)
        XCTAssertFalse(FileManager.default.fileExists(atPath: calls.path), "The synthetic reader has not run on this App launch")

        let reply = D11RefreshReplies()
        let observer = app.composition.store.attach(reply)
        defer { app.composition.store.detach(observer) }
        let dock = app.composition.dock, view = dock.dockView
        let nozzle = try XCTUnwrap(view.nozzleEventDelegate)
        let anchor = try XCTUnwrap(view.interactionAnchor(ref))
        let target = CGPoint(x: anchor.midX, y: anchor.midY)
        let controller = try XCTUnwrap(dock.interactionControllerForChecks)
        let another = try XCTUnwrap(view.presentedReadingsForChecks.keys.first { $0 != ref })
        let otherAnchor = try XCTUnwrap(view.interactionAnchor(another))
        let direction = otherAnchor.midX >= target.x ? 1.0 : -1.0
        let frame = try XCTUnwrap(dock.edgePresentation?.paintedFrame)
        let settingsBefore = await settings.snapshot()
        let url = root.appendingPathComponent("ModelPlan/settings.json")
        let bytes = try Data(contentsOf: url)
        let sweeps = view.refreshSweepCountForChecks

        for distance in [4.0, 5.0, 6.0] {
            XCTAssertTrue(nozzle.beginNozzle(id: ref, local: target))
            nozzle.moveNozzle(local: CGPoint(x: target.x + direction * distance, y: target.y))
            XCTAssertEqual(controller.presentation?.reorder != nil, distance == 6, "Threshold: \(distance)")
            nozzle.endNozzle(global: .zero, currentID: distance < 6 ? ref : nil)
            XCTAssertFalse(controller.hasCapture)
            XCTAssertEqual(view.refreshSweepCountForChecks, sweeps, "A drag must not run the click sweep")
            XCTAssertEqual(dock.edgePresentation?.paintedFrame, frame)
        }

        XCTAssertTrue(nozzle.beginNozzle(id: ref, local: target))
        nozzle.moveNozzle(local: CGPoint(x: otherAnchor.midX, y: otherAnchor.midY))
        XCTAssertNotNil(controller.presentation?.reorder)
        nozzle.cancelNozzle()
        nozzle.endNozzle(global: .zero, currentID: nil)
        XCTAssertFalse(controller.hasCapture)
        XCTAssertNil(controller.presentation?.reorder)
        let unchanged = await settings.snapshot()
        XCTAssertEqual(unchanged.revision, settingsBefore.revision)
        XCTAssertEqual(try Data(contentsOf: url), bytes)
        XCTAssertEqual(dock.edgePresentation?.paintedFrame, frame)
        XCTAssertEqual(view.refreshSweepCountForChecks, sweeps)
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertTrue(reply.outcomes.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: calls.path))

        XCTAssertTrue(nozzle.beginNozzle(id: ref, local: target))
        nozzle.endNozzle(global: .zero, currentID: ref)
        XCTAssertEqual(view.refreshSweepCountForChecks, sweeps + 1)
        let deadline = ContinuousClock.now + .seconds(6)
        while member()?.account.windows.first?.remainingPercent != 70 && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(reply.outcomes.map(\.outcome), [.started])
        XCTAssertEqual(try String(contentsOf: calls, encoding: .utf8), "read\n")
        XCTAssertEqual(view.presentedReadingsForChecks[ref]?.readout, "70%")
        XCTAssertEqual(controlReading(), 51)
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }
}
#endif
