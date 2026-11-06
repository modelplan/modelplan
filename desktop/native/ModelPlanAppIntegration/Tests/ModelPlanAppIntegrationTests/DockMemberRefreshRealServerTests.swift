// SPDX-License-Identifier: MIT
#if MODELPLAN_DOCK_REAL_RUNTIME_JOURNEY
import AppKit
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings
import ModelPlanWire
@_spi(DockResourceChecks) import ModelPlanDock
import XCTest
@testable import ModelPlanAppIntegration

@MainActor private final class MemberRefreshReceipts: EngineStoreEventSink {
    private(set) var replies: [String: WireMemberRefreshResult] = [:]
    func acceptedEvent(_ event: EngineClientEvent) {
        guard case .response(.string(let id), .memberRefresh(let reply)) = event else { return }
        replies[id] = reply.envelope.data
    }
    func apply(_ snapshot: EngineStoreSnapshot) {}
    func clearPrivateViews(_ invalidation: EngineInvalidation) { replies.removeAll() }
}

@MainActor final class DockMemberRefreshRealServerTests: XCTestCase {
    private struct RuntimeProfile {
        let root: URL
        let helper: URL
        let environment: [String: String]
        let epoch: String
        let generation: Int
        var cache: URL { root.appendingPathComponent("Library/Caches/modelplan/observed") }
    }

    private func quote(_ path: String) -> String { "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    private func script(_ name: String, at root: URL, _ body: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try ("#!/bin/sh\n" + body + "\n").write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        return url
    }

    private func command(_ arguments: [String], helper: URL, environment: [String: String],
                         input: [String: Any]? = nil) async throws -> [String: Any] {
        let process = Process(), output = Pipe()
        process.executableURL = helper
        process.arguments = arguments
        process.environment = environment
        process.standardError = FileHandle.nullDevice
        process.standardOutput = output
        let stdin = input.map { _ in Pipe() }
        process.standardInput = stdin ?? FileHandle.nullDevice
        try process.run()
        if let stdin, let input {
            try stdin.fileHandleForWriting.write(contentsOf: JSONSerialization.data(withJSONObject: input))
            try stdin.fileHandleForWriting.close()
        }
        let deadline = ContinuousClock.now + .seconds(5)
        while process.isRunning && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        if process.isRunning { process.terminate(); throw CocoaError(.fileReadUnknown) }
        XCTAssertEqual(process.terminationStatus, 0)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: output.fileHandleForReading.readDataToEndOfFile()) as? [String: Any])
    }

    private func runtimeProfile() async throws -> RuntimeProfile {
        let executable = try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_DOCK_TEST_CLI"])
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("member-refresh-" + UUID().uuidString)
        let cache = root.appendingPathComponent("Library/Caches/modelplan/observed")
        for directory in [cache, root.appendingPathComponent(".codex")] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        let environment = ["HOME": root.path, "TMPDIR": root.path, "PATH": root.path + ":/usr/bin:/bin", "LANG": "C"]
        // Run the genuine scheduler with no network or provider credentials.
        let helper = try script("app-cli", at: root, "exec /usr/bin/sandbox-exec -p '(version 1)(allow default)(deny network*)' " + quote(executable) + " \"$@\"")
        func consent(_ arguments: [String], input: [String: Any]? = nil) async throws -> [String: Any] {
            try await command(["consent"] + arguments + ["--json"], helper: helper, environment: environment, input: input)
        }

        _ = try await consent(["init"])
        let before = try await consent([])
        let epoch = try XCTUnwrap(before["storeEpoch"] as? String)
        let scope = "codex.runtime_usage"
        _ = try await consent(["grant"], input: [
            "requestId": UUID().uuidString.lowercased(), "expectStoreEpoch": epoch,
            "expectGeneration": try XCTUnwrap(before["generation"] as? Int),
            "consentTextVersion": try XCTUnwrap(before["consentTextVersion"] as? Int),
            "allow": [scope], "deny": [String]()
        ])
        let after = try await consent([])
        return RuntimeProfile(root: root, helper: helper, environment: environment, epoch: epoch,
                              generation: try XCTUnwrap(after["generation"] as? Int))
    }

    func testR04RealServerDefersOnlyTheGrantedMemberAndRefusesTheOther() async throws {
        let profile = try await runtimeProfile()
        let root = profile.root
        let declared = root.appendingPathComponent(".config/modelplan")
        try FileManager.default.createDirectory(at: declared, withIntermediateDirectories: true)
        let attempted = root.appendingPathComponent("unexpected-runtime-attempt")
        _ = try script("codex", at: root, "[ \"$1\" != app-server ] || : > " + quote(attempted.path) + "\nexit 64")

        let formatter = ISO8601DateFormatter(), observed = Date().addingTimeInterval(-20)
        let observedText = formatter.string(from: observed)
        let floor = formatter.string(from: observed.addingTimeInterval(300))
        let reset = formatter.string(from: observed.addingTimeInterval(7200))
        let runtimeRef = "aaaaaaaaaaaaaaaa", plan = "synthetic-manual"
        let runtimeBytes = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 1, "status": "ok", "observedAt": observedText, "plan": "plus", "subscriptionRef": runtimeRef,
            "admission": ["storeEpoch": profile.epoch, "generation": profile.generation, "scope": "codex.runtime_usage"],
            "windows": [["kind": "five_hour", "windowMinutes": 300, "usedPercent": 30,
                         "observedAt": observedText, "resetsAt": reset, "resetMode": "rolling"]]
        ])
        let runtimeCache = profile.cache.appendingPathComponent("codex-account.json")
        try runtimeBytes.write(to: runtimeCache)
        let manualBytes = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "plans": [["planId": plan]],
            "windows": [["planId": plan, "kind": "five_hour", "remainingPercent": 37,
                         "observedAt": observedText, "resetAt": reset, "resetMode": "rolling"]]])
        let manualFile = declared.appendingPathComponent("local.json")
        try manualBytes.write(to: manualFile)

        let frame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let screen = DockDisplayArea(id: "synthetic", frame: frame, visibleFrame: frame)
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        _ = try await settings.update { $0.motion = .on }
        let app = EngineRowsEntry.make(configuration: .init(executableURL: profile.helper, applicationVersion: "synthetic-member-refresh",
            allowedEnvironment: profile.environment), settingsStore: settings, createsNativePanels: false,
            bundleURL: root.appendingPathComponent("Synthetic.app"),
            dockEnvironment: { .init(displays: [screen], layouts: [], primaryDisplayID: screen.id, pointer: .init(x: 700, y: 450)) },
            activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.prepare()
        app.allowDockPresentation()
        let client = app.composition.client
        let delivery = try await client.start()
        _ = try await client.subscribeRows(timeout: .seconds(5))
        let deadline = ContinuousClock.now + .seconds(3)
        while app.memberRefreshAdapter == nil && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        let adapter = try XCTUnwrap(app.memberRefreshAdapter as? AppServerMemberRefreshAdapter)
        let catalogue = app.composition.accountMembers.members
        let runtime = try XCTUnwrap(catalogue.first { $0.id == runtimeRef })
        let manual = try XCTUnwrap(catalogue.first { $0.rowID == "declared:" + plan })
        XCTAssertEqual(runtime.account.refreshNotBefore?.rawValue, floor)
        XCTAssertNil(manual.account.refreshNotBefore)
        XCTAssertEqual(adapter.admission(for: runtime, delivery: delivery, now: Date()), .deferred)
        let eligibleAt = try XCTUnwrap(formatter.date(from: floor))
        XCTAssertEqual(adapter.admission(for: runtime, delivery: delivery, now: eligibleAt), .ready)
        XCTAssertEqual(adapter.admission(for: manual, delivery: delivery, now: Date()), .unavailable)

        let dock = app.composition.dock, view = dock.dockView
        let events = try XCTUnwrap(view.nozzleEventDelegate)
        let startSweeps = view.refreshSweepCountForChecks
        let sink = MemberRefreshReceipts()
        let token = app.composition.store.attach(sink)
        defer { app.composition.store.detach(token) }
        for member in [runtime, manual] {
            let anchor = try XCTUnwrap(view.interactionAnchor(member.id))
            XCTAssertTrue(events.beginNozzle(id: member.id, local: .init(x: anchor.midX, y: anchor.midY)))
            events.endNozzle(global: .zero, currentID: member.id)
        }
        XCTAssertEqual(view.refreshSweepCountForChecks, startSweeps + 2)
        XCTAssertFalse(view.refreshSweepAnimatingForChecks)
        XCTAssertTrue(app.liveStatusMenu?.items.contains { $0.title.contains("Refresh unavailable") } == true)

        // The UI suppressed both RPCs. The two explicit requests below independently
        // verify the producer receipts on the same session and exact member identities.
        func receipt(_ member: EngineAccountMember) async throws -> WireMemberRefreshResult {
            let target = try WireRefreshMember(rowId: member.rowID, route: member.account.route,
                subscriptionRef: member.account.subscriptionRef, accountLocator: member.account.accountLocator)
            let completion = try await client.refresh(.init(member: target), timeout: .seconds(4))
            guard case .string(let id) = completion.requestID else { throw CocoaError(.coderInvalidValue) }
            return try XCTUnwrap(sink.replies[id])
        }
        let deferred = try await receipt(runtime)
        let refused = try await receipt(manual)
        XCTAssertEqual(sink.replies.count, 2, "Only the two explicit receipt probes may reach the server")
        XCTAssertEqual(deferred.outcome, .deferred)
        XCTAssertEqual(deferred.reason, .floor)
        XCTAssertEqual(deferred.notBefore?.rawValue, floor)
        XCTAssertEqual(refused.outcome, .deferred)
        XCTAssertEqual(refused.reason, .notGranted)
        XCTAssertNil(refused.notBefore)
        XCTAssertEqual(view.presentedReadingsForChecks[runtime.id]?.readout, "70%")
        XCTAssertEqual(view.presentedReadingsForChecks[manual.id]?.readout, "37%")
        XCTAssertFalse(FileManager.default.fileExists(atPath: attempted.path))
        XCTAssertEqual(try Data(contentsOf: runtimeCache), runtimeBytes)
        XCTAssertEqual(try Data(contentsOf: manualFile), manualBytes)
    }

    func testR02RealServerWakeRespectsBudgetAndResumesOneDueRead() async throws {
        let profile = try await runtimeProfile()
        let root = profile.root
        let payload = root.appendingPathComponent("runtime-payload.json")
        let hold = root.appendingPathComponent("hold-runtime")
        let calls = root.appendingPathComponent("runtime-calls")
        let reading = profile.cache.appendingPathComponent("codex-account.json")
        let reservation = profile.cache.appendingPathComponent("reader-attempts/codex.json")
        _ = try script("codex", at: root, """
            [ "$1" = app-server ] || exit 2
            while IFS= read -r line; do
                case "$line" in
                *'"id":1,'*) echo '{"id":1,"result":{"userAgent":"synthetic"}}' ;;
                *'"method":"account/rateLimits/read"'*)
                    echo read >> \(quote(calls.path))
                    while [ -e \(quote(hold.path)) ]; do sleep 0.02; done
                    printf '{"id":2,"result":%s}\\n' "$(cat \(quote(payload.path)))" ;;
                *'"method":"account/read"'*) echo '{"id":3,"result":{"account":{"type":"chatgpt","email":"synthetic@example.invalid"}}}' ;;
                esac
            done
            """)
        func reply(used: Int) throws {
            let reset = Int(Date().timeIntervalSince1970) + 86_400
            try JSONSerialization.data(withJSONObject: ["rateLimits": ["planType": "plus", "secondary": [
                "usedPercent": used, "windowDurationMins": 10_080, "resetsAt": reset
            ]]]).write(to: payload, options: .atomic)
        }
        func json(_ url: URL) throws -> [String: Any] {
            try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        }
        func runtimeReads() -> Int {
            (try? String(contentsOf: calls, encoding: .utf8).split(separator: "\n").count) ?? 0
        }
        try reply(used: 80)
        _ = try await command(["quota", "--refresh-account", "--json", "--offline"],
                              helper: profile.helper, environment: profile.environment)
        XCTAssertEqual(runtimeReads(), 1, "The real CLI fixture must establish one verified binding")
        let seed = try json(reading)
        let ref = try XCTUnwrap(seed["subscriptionRef"] as? String)
        let initialObservation = try XCTUnwrap(seed["observedAt"] as? String)
        let persistedBudget = try Data(contentsOf: reservation)
        try FileManager.default.removeItem(at: calls)

        let frame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let screen = DockDisplayArea(id: "synthetic", frame: frame, visibleFrame: frame)
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        _ = try await settings.update { preferences in
            for _ in OnboardingDefinition.task65.steps { preferences.onboarding.next() }
        }
        let app = EngineRowsEntry.make(configuration: .init(executableURL: profile.helper, applicationVersion: "synthetic-runtime-wake",
            allowedEnvironment: profile.environment), settingsStore: settings, createsNativePanels: false,
            bundleURL: root.appendingPathComponent("Synthetic.app"),
            dockEnvironment: { .init(displays: [screen], layouts: [], primaryDisplayID: screen.id, pointer: .init(x: 700, y: 450)) },
            activateSettings: {})
        addTeardownBlock { @MainActor in
            try? FileManager.default.removeItem(at: hold)
            await app.stopLifecycle()
            await app.composition.stop()
        }
        await app.prepare()
        let workspace = NotificationCenter()
        app.startLifecycle(workspace: workspace, local: NotificationCenter(), lockEvents: NotificationCenter(),
                           displayIDs: { [1] }, onConsole: { true }, displaysAsleep: { _ in false })
        let store = app.composition.store
        func wait(_ message: String, for predicate: () -> Bool) async throws {
            let deadline = ContinuousClock.now + .seconds(10)
            while !predicate() && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
            if !predicate() {
                XCTFail(message)
                throw CocoaError(.fileReadUnknown)
            }
        }
        func observation() -> RowsAccount? {
            store.snapshot.rows?.projection.rows.first { $0.id == "codex" }?.accounts.first { $0.subscriptionRef == ref }
        }
        func sleep() async throws {
            workspace.post(name: NSWorkspace.willSleepNotification, object: nil)
            XCTAssertTrue(app.lifecyclePaused)
            try await wait("Sleep must stop the real client and withdraw the old rows") {
                store.snapshot.connection == .stopped(.requested) && store.snapshot.rows == nil
            }
        }
        try await wait("Initial real client must render the seeded member") {
            !app.lifecyclePaused && observation()?.windows.first?.remainingPercent == 20
        }
        let first = try XCTUnwrap(store.snapshot.delivery)
        XCTAssertEqual(runtimeReads(), 0)
        try await sleep()
        XCTAssertFalse(app.composition.client.isCurrent(first))
        workspace.post(name: NSWorkspace.didWakeNotification, object: nil)
        try await wait("Wake within the floor must establish a new session") {
            !app.lifecyclePaused && store.snapshot.delivery?.sessionID != first.sessionID && observation() != nil
        }
        let earlyWake = try XCTUnwrap(store.snapshot.delivery)
        XCTAssertEqual(runtimeReads(), 0)
        XCTAssertEqual(try Data(contentsOf: reservation), persistedBudget)
        XCTAssertEqual(observation()?.observedAt?.rawValue, initialObservation)

        try await sleep()
        // Model the passage of the floor while the engine is stopped. Both files
        // belong to this disposable profile; the producer still owns every read.
        let elapsed = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-360))
        var aged = seed
        aged["observedAt"] = elapsed
        var windows = try XCTUnwrap(aged["windows"] as? [[String: Any]])
        for index in windows.indices { windows[index]["observedAt"] = elapsed }
        aged["windows"] = windows
        try JSONSerialization.data(withJSONObject: aged).write(to: reading, options: .atomic)
        try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "nextAttemptAt": elapsed])
            .write(to: reservation, options: .atomic)
        try reply(used: 30)
        try Data().write(to: hold)
        workspace.post(name: NSWorkspace.didWakeNotification, object: nil)
        try await wait("A due source must start automatically on the new wake session") {
            store.snapshot.delivery?.sessionID != earlyWake.sessionID && observation() != nil && runtimeReads() == 1
        }
        let dueWake = try XCTUnwrap(store.snapshot.delivery)
        XCTAssertFalse(app.composition.client.isCurrent(earlyWake))
        XCTAssertNotEqual(dueWake.sessionID, first.sessionID)

        let member = try XCTUnwrap(app.composition.accountMembers.members.first { $0.id == ref })
        let sink = MemberRefreshReceipts()
        let token = store.attach(sink)
        defer { store.detach(token) }
        let target = try WireRefreshMember(rowId: member.rowID, route: member.account.route,
            subscriptionRef: member.account.subscriptionRef, accountLocator: member.account.accountLocator)
        let competing = try await app.composition.client.refresh(.init(member: target), timeout: .seconds(5))
        guard case .string(let id) = competing.requestID else { throw CocoaError(.coderInvalidValue) }
        let receipt = try XCTUnwrap(sink.replies[id])
        XCTAssertEqual(receipt.outcome, .deferred, "A competing refresh must not start during the automatic attempt")
        XCTAssertEqual(runtimeReads(), 1)
        try FileManager.default.removeItem(at: hold)
        try await wait("The same wake session must receive its new reading") {
            !app.lifecyclePaused && observation()?.windows.first?.remainingPercent == 70 &&
                app.composition.dock.dockView.presentedReadingsForChecks[ref]?.readout == "70%"
        }
        XCTAssertEqual(store.snapshot.delivery, dueWake)
        XCTAssertNotEqual(observation()?.observedAt?.rawValue, elapsed)
        XCTAssertEqual(runtimeReads(), 1)
    }

}
#endif
