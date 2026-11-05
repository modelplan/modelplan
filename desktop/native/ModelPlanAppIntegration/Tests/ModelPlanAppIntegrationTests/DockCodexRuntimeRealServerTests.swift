// SPDX-License-Identifier: MIT
#if MODELPLAN_DOCK_REAL_RUNTIME_JOURNEY
import AppKit
import ModelPlanDock
import ModelPlanEngineClient
import ModelPlanSettings
import ModelPlanWire
import XCTest
@testable import ModelPlanAppIntegration

@MainActor private final class RuntimeCardTimer: DockEdgeScheduling {
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) {}
    func cancel() {}
}

@MainActor final class DockCodexRuntimeRealServerTests: XCTestCase {
    private func quote(_ path: String) -> String { "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    private func script(_ name: String, in root: URL, _ text: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        return url
    }

    private func sandbox() throws -> (URL, URL, [String: String]) {
        let executable = try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_DOCK_TEST_CLI"])
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("codex-card-" + UUID().uuidString)
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

    func testSameRuntimeMemberUpdatesTheOpenCard() async throws {
        let (root, helper, environment) = try sandbox()
        let cache = root.appendingPathComponent("Library/Caches/modelplan/observed")
        let payload = root.appendingPathComponent("rpc-response.json")
        let hold = root.appendingPathComponent("hold-runtime-reply")
        let requested = root.appendingPathComponent("runtime-requested")
        _ = try script("codex", in: root, """
            #!/bin/sh
            [ "$1" = app-server ] || exit 2
            while IFS= read -r line; do
                case "$line" in
                *'"id":1,'*) echo '{"id":1,"result":{"userAgent":"synthetic"}}' ;;
                *'"method":"account/rateLimits/read"'*)
                    if [ -e \(quote(hold.path)) ]; then
                        : > \(quote(requested.path))
                        while [ -e \(quote(hold.path)) ]; do sleep 0.02; done
                    fi
                    printf '{"id":2,"result":%s}\\n' "$(cat \(quote(payload.path)))" ;;
                *'"method":"account/read"'*) echo '{"id":3,"result":{"account":{"type":"chatgpt","email":"synthetic@example.invalid"}}}' ;;
                esac
            done
            """)
        let now = Date(), iso = ISO8601DateFormatter(), scope = "codex.runtime_usage"
        func response(used: Int) throws {
            try encode(["rateLimits": ["planType": "plus", "secondary": ["usedPercent": used,
                "windowDurationMins": 10080, "resetsAt": Int(now.timeIntervalSince1970) + 86_400]]]).write(to: payload, options: .atomic)
        }
        _ = try await command(["consent", "init", "--json"], helper: helper, environment: environment)
        let before = try await command(["consent", "--json"], helper: helper, environment: environment)
        _ = try await command(["consent", "grant", "--json"], helper: helper, environment: environment, input: [
            "requestId": UUID().uuidString.lowercased(), "expectStoreEpoch": try XCTUnwrap(before["storeEpoch"] as? String),
            "expectGeneration": try XCTUnwrap(before["generation"] as? Int),
            "consentTextVersion": try XCTUnwrap(before["consentTextVersion"] as? Int), "allow": [scope], "deny": [String]()
        ])
        try response(used: 80)
        _ = try await command(["quota", "--refresh-account", "--json", "--offline"], helper: helper, environment: environment)
        // Age only the disposable fixture, keeping the producer-generated binding and admission stamp.
        let readingURL = cache.appendingPathComponent("codex-account.json")
        var seed = try decode(Data(contentsOf: readingURL))
        let ref = try XCTUnwrap(seed["subscriptionRef"] as? String)
        let old = iso.string(from: now.addingTimeInterval(-3 * 3600 - 30))
        seed["observedAt"] = old
        var windows = try XCTUnwrap(seed["windows"] as? [[String: Any]])
        XCTAssertEqual(windows.count, 1)
        windows[0]["observedAt"] = old
        seed["windows"] = windows
        let retainedBytes = try encode(seed)
        try retainedBytes.write(to: readingURL, options: .atomic)
        let reservation = cache.appendingPathComponent("reader-attempts/codex.json")
        try encode(["schemaVersion": 1, "nextAttemptAt": old]).write(to: reservation, options: .atomic)
        try response(used: 30)

        try Data().write(to: hold)
        defer { try? FileManager.default.removeItem(at: hold) }

        let display = DockDisplayArea(id: "synthetic", frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 880))
        var pointer = CGPoint(x: 700, y: 450), elapsed = 0.0
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        func makeApplication(offline: Bool = false) async -> EngineDockMenuApplication {
            let app = EngineRowsEntry.make(configuration: .init(executableURL: helper, applicationVersion: "synthetic-runtime-card",
                allowedEnvironment: environment, offline: offline), settingsStore: settings, createsNativePanels: false,
                bundleURL: root.appendingPathComponent("Synthetic.app"),
                dockEnvironment: { .init(displays: [display], layouts: [], primaryDisplayID: display.id, pointer: pointer) },
                deadlineNow: { Date() }, deadlineElapsed: { elapsed }, deadlineScheduling: RuntimeCardTimer(), activateSettings: {})
            addTeardownBlock { @MainActor in await app.composition.stop() }
            await app.prepare()
            app.allowDockPresentation()
            return app
        }
        func account(in app: EngineDockMenuApplication) -> RowsAccount? {
            let row = app.composition.store.snapshot.rows?.projection.rows.first { $0.id == "codex" }
            return row?.accounts.first { $0.subscriptionRef == ref && $0.route == .runtimeRpc }
        }
        func blockedRefresh(in app: EngineDockMenuApplication, reason: WireRefreshDisabledReason) async throws {
            let store = app.composition.store
            var replies: [(WireRequestID, [WireRefreshScheduled])] = []
            let observer = store.observeRefreshReplies { replies.append(($0, $1)) }
            defer { store.removeRefreshReplyObserver(observer) }
            let result = try await app.composition.client.refresh(.init(scopes: [scope]), timeout: .seconds(4))
            let reply = try XCTUnwrap(replies.first { $0.0 == result.requestID }?.1.first)
            XCTAssertEqual(reply.disabledReason, reason)
            XCTAssertFalse(FileManager.default.fileExists(atPath: requested.path),
                           "Neither startup nor an explicit blocked request may call the runtime")
        }

        let offline = await makeApplication(offline: true)
        _ = try await offline.composition.client.start()
        _ = try await offline.composition.client.subscribeRows(timeout: .seconds(4))
        XCTAssertEqual(account(in: offline)?.valueState, .retained)
        XCTAssertEqual(account(in: offline)?.observedAt?.rawValue, old)
        try await blockedRefresh(in: offline, reason: .offline)
        XCTAssertEqual(try Data(contentsOf: readingURL), retainedBytes, "Offline may not replace the retained cache")
        await offline.composition.stop()

        let app = await makeApplication()
        let delivery = try await app.composition.client.start()
        func wait(until predicate: () -> Bool) async throws {
            let deadline = ContinuousClock.now + .seconds(10)
            while !predicate() && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
        }
        try await wait { account(in: app)?.valueState == .retained }
        XCTAssertEqual(account(in: app)?.observedAt?.rawValue, old)
        XCTAssertEqual(account(in: app)?.valueState, .retained)

        let dock = app.composition.dock, view = dock.dockView
        func openCard() throws -> DockCardView {
            let placement = try XCTUnwrap(dock.edgePresentation?.placement)
            let anchor = try XCTUnwrap(view.interactionAnchor(ref))
            pointer = CGPoint(x: placement.frame.minX + anchor.midX - view.bounds.minX,
                y: placement.frame.maxY - anchor.midY + view.bounds.minY)
            let events = try XCTUnwrap(view.nozzleEventDelegate)
            events.hoverNozzle(nil)
            events.hoverNozzle(ref)
            elapsed += 0.251; dock.interactionControllerForChecks?.refresh()
            return try XCTUnwrap(dock.detachedCardForChecks)
        }
        let card = try openCard()
        func text(_ name: String, in root: NSView) -> String? {
            if let field = root as? NSTextField, field.accessibilityIdentifier() == "dock.card.text." + name { return field.stringValue }
            return root.subviews.lazy.compactMap { text(name, in: $0) }.first
        }
        let window = try XCTUnwrap(account(in: app)?.windows.first)
        XCTAssertEqual(window.remainingPercent, 20)
        XCTAssertEqual(window.observedAt?.rawValue, old)
        XCTAssertEqual(window.source, .runtime)
        let weekly = "row.quota:" + window.id
        XCTAssertEqual(text(weekly + ".value", in: card), "--", "Retained metadata must not admit an expired number")
        let retainedDetail = text(weekly + ".detail", in: card)
        XCTAssertTrue(retainedDetail?.contains("Tool runtime · 3h ago") == true,
                      "Retained window provenance: " + (retainedDetail ?? "missing"))
        try await wait { FileManager.default.fileExists(atPath: requested.path) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: requested.path), "The normal session started the runtime RPC")
        try FileManager.default.removeItem(at: hold)
        try await wait { account(in: app)?.valueState == .current && account(in: app)?.windows.first?.remainingPercent == 70 }
        XCTAssertEqual(app.composition.store.snapshot.delivery, delivery)
        let recovered = try XCTUnwrap(account(in: app)?.windows.first)
        XCTAssertEqual(recovered.id, window.id)
        XCTAssertEqual(recovered.remainingPercent, 70)
        XCTAssertEqual(recovered.source, .runtime)
        XCTAssertNotEqual(recovered.observedAt?.rawValue, old)
        XCTAssertEqual(account(in: app)?.valueState, .current)
        XCTAssertTrue(dock.detachedCardForChecks === card, "The still-hovered card must update without closing")
        // If continuity fails, a fresh hover still distinguishes projection from the close.
        let currentCard: DockCardView
        if let displayed = dock.detachedCardForChecks { currentCard = displayed }
        else { currentCard = try openCard() }
        XCTAssertEqual(text(weekly + ".value", in: currentCard), "70%")
        XCTAssertTrue(text(weekly + ".detail", in: currentCard)?.contains("Tool runtime · just now") == true)

        let deny = try WireConsentGrantParams(requestId: UUID().uuidString.lowercased(),
            expectStoreEpoch: delivery.floor.storeEpoch, expectGeneration: delivery.floor.generation,
            consentTextVersion: XCTUnwrap(before["consentTextVersion"] as? Int), allow: [], deny: [scope])
        _ = try await app.composition.client.grant(deny, userAction: .init(id: UUID()), timeout: .seconds(4))
        XCTAssertNil(dock.detachedCardForChecks, "Consent withdrawal must close the card before the grant returns")
        XCTAssertNil(text(weekly + ".value", in: currentCard))
        _ = try await app.composition.client.subscribeRows(timeout: .seconds(4))
        XCTAssertNil(account(in: app), "A revoked subscription must not reappear on the next real rows reply")
        XCTAssertNil(try dock.cardContent(for: ref))
        await app.composition.stop()

        try FileManager.default.removeItem(at: requested)
        try Data().write(to: hold)
        let denied = await makeApplication()
        _ = try await denied.composition.client.start()
        _ = try await denied.composition.client.subscribeRows(timeout: .seconds(4))
        XCTAssertNil(account(in: denied), "A new launch must honor the persisted denial")
        try await blockedRefresh(in: denied, reason: .readOnly)
        XCTAssertNil(try denied.composition.dock.cardContent(for: ref))
    }
    func testR06LocalHistoryChangeReachesTheSameSubscribedMember() async throws {
        let (root, helper, environment) = try sandbox()
        // Establish tool presence without a usable runtime executable.
        _ = try script("codex", in: root, "#!/bin/sh\nexit 64\n")
        let scope = "codex.local_history"
        _ = try await command(["consent", "init", "--json"], helper: helper, environment: environment)
        let before = try await command(["consent", "--json"], helper: helper, environment: environment)
        _ = try await command(["consent", "grant", "--json"], helper: helper, environment: environment, input: [
            "requestId": UUID().uuidString.lowercased(), "expectStoreEpoch": try XCTUnwrap(before["storeEpoch"] as? String),
            "expectGeneration": try XCTUnwrap(before["generation"] as? Int),
            "consentTextVersion": try XCTUnwrap(before["consentTextVersion"] as? Int), "allow": [scope], "deny": [String]()
        ])
        let now = Date(), iso = ISO8601DateFormatter()
        let day = iso.string(from: now).prefix(10).replacingOccurrences(of: "-", with: "/")
        let log = root.appendingPathComponent(".codex/sessions/" + day + "/rollout-synthetic.jsonl")
        try FileManager.default.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true)
        func line(used: Int, at time: Date) throws -> Data {
            var bytes = try encode(["timestamp": iso.string(from: time), "type": "event_msg", "payload": [
                "type": "token_count", "rate_limits": ["limit_id": "codex", "plan_type": "plus", "primary": [
                    "used_percent": used, "window_minutes": 10080, "resets_at": Int(now.timeIntervalSince1970) + 86_400
                ]]
            ]])
            bytes.append(10)
            return bytes
        }
        let old = now.addingTimeInterval(-3 * 3600 - 30)
        try line(used: 80, at: old).write(to: log)
        let report = try await command(["quota", "--json", "--offline"], helper: helper, environment: environment)
        let reportAccounts = try XCTUnwrap(report["accounts"] as? [[String: Any]])
        let directLocal = try XCTUnwrap(reportAccounts.first { $0["source"] as? String == "codex" },
                                       "The same explicit local grant must expose the fixture to CLI quota")
        let directWindow = try XCTUnwrap((directLocal["windows"] as? [[String: Any]])?.first)
        XCTAssertEqual(directWindow["remainingPercent"] as? Double, 20)

        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let app = EngineRowsEntry.make(configuration: .init(executableURL: helper, applicationVersion: "synthetic-local-card",
            allowedEnvironment: environment), settingsStore: settings, createsNativePanels: false,
            bundleURL: root.appendingPathComponent("Synthetic.app"),
            dockEnvironment: normalEntryTestEnvironment, activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.prepare()
        app.allowDockPresentation()
        let delivery = try await app.composition.client.start()
        _ = try await app.composition.client.subscribeRows(timeout: .seconds(4))
        func localAccount() -> RowsAccount? {
            app.composition.store.snapshot.rows?.projection.rows.first { $0.id == "codex" }?.accounts.first { $0.route == .localLog }
        }
        let row = app.composition.store.snapshot.rows?.projection.rows.first { $0.id == "codex" }
        let diagnostic = row.map { "\($0.state) / \($0.reason.code), routes: \($0.accounts.map(\.route))" } ?? "absent"
        let first = try XCTUnwrap(localAccount(), diagnostic)
        let firstWindow = try XCTUnwrap(first.windows.first)
        XCTAssertEqual(first.valueState, .retained)
        XCTAssertEqual(firstWindow.remainingPercent, 20)
        XCTAssertEqual(firstWindow.source, .localHistory)
        XCTAssertEqual(firstWindow.observedAt?.rawValue, iso.string(from: old))

        let fresh = Date()
        let handle = try FileHandle(forWritingTo: log)
        try handle.seekToEnd()
        try handle.write(contentsOf: line(used: 30, at: fresh))
        try handle.close()
        let end = ContinuousClock.now + .seconds(6)
        while localAccount()?.windows.first?.remainingPercent != 70 && ContinuousClock.now < end {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(localAccount()?.windows.first?.remainingPercent, 70,
                       "The existing subscription must receive the new local observation without a request")
        if localAccount()?.windows.first?.remainingPercent != 70 {
            // Positive control for a valid fixture. This cannot satisfy automatic delivery.
            _ = try await app.composition.client.subscribeRows(timeout: .seconds(4))
        }
        let current = try XCTUnwrap(localAccount())
        let currentWindow = try XCTUnwrap(current.windows.first)
        XCTAssertEqual(app.composition.store.snapshot.delivery, delivery)
        XCTAssertEqual(current.subscriptionRef, first.subscriptionRef)
        XCTAssertEqual(currentWindow.id, firstWindow.id)
        XCTAssertEqual(current.valueState, .current)
        XCTAssertEqual(currentWindow.remainingPercent, 70)
        XCTAssertEqual(currentWindow.source, .localHistory)
        XCTAssertEqual(currentWindow.observedAt?.rawValue, iso.string(from: fresh))
        let card = try XCTUnwrap(app.composition.dock.cardContent(for: "codex#local_log"))
        XCTAssertTrue(card.rows.contains { $0.id == "quota:" + currentWindow.id && $0.value == "70%" })
        XCTAssertTrue(card.sourceAndAge.contains("Local history"))
    }

}
#endif
