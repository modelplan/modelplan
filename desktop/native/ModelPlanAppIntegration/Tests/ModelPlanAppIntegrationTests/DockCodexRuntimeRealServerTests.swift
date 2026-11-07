// SPDX-License-Identifier: MIT
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
        // The U11 workflow builds the real CLI from this commit and requires these journeys;
        // the native legs have no Go toolchain and skip them (allowed skips in the partition).
        let environmentValues = ProcessInfo.processInfo.environment
        guard let executable = [environmentValues["MODELPLAN_DOCK_TEST_CLI"], environmentValues["MODELPLAN_U11_TEST_CLI"]]
                .compactMap({ $0 }).first(where: { !$0.isEmpty }) else {
            if environmentValues["MODELPLAN_U11_TEST_REQUIRED"] == "1" {
                XCTFail("U11 must provide the real synthetic-test CLI"); throw CancellationError()
            }
            throw XCTSkip("Build the real synthetic-test CLI for the Codex runtime card journeys")
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("codex-card-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            do { try FileManager.default.removeItem(at: root) }
            catch { XCTFail("DIAG teardown removal: \(error)") }
        }
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

    private func text(_ name: String, in root: NSView) -> String? {
        if let field = root as? NSTextField, field.accessibilityIdentifier() == "dock.card.text." + name { return field.stringValue }
        return root.subviews.lazy.compactMap { self.text(name, in: $0) }.first
    }

    func testSameRuntimeMemberUpdatesTheOpenCard() async throws {
        func mark(_ s: String) { FileHandle.standardError.write(Data(("BREAD " + s + "\n").utf8)) }
        mark("L81")
        let (root, helper, environment) = try sandbox()
        mark("L82")
        let cache = root.appendingPathComponent("Library/Caches/modelplan/observed")
        mark("L83")
        let payload = root.appendingPathComponent("rpc-response.json")
        mark("L84")
        let hold = root.appendingPathComponent("hold-runtime-reply")
        mark("L85")
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
        mark("L102")
        let now = Date(), iso = ISO8601DateFormatter(), scope = "codex.runtime_usage"
        mark("L103")
        func response(used: Int) throws {
            try encode(["rateLimits": ["planType": "plus", "secondary": ["usedPercent": used,
                "windowDurationMins": 10080, "resetsAt": Int(now.timeIntervalSince1970) + 86_400]]]).write(to: payload, options: .atomic)
        }
        mark("L107")
        _ = try await command(["consent", "init", "--json"], helper: helper, environment: environment)
        mark("L108")
        let before = try await command(["consent", "--json"], helper: helper, environment: environment)
        mark("L109")
        _ = try await command(["consent", "grant", "--json"], helper: helper, environment: environment, input: [
            "requestId": UUID().uuidString.lowercased(), "expectStoreEpoch": try XCTUnwrap(before["storeEpoch"] as? String),
            "expectGeneration": try XCTUnwrap(before["generation"] as? Int),
            "consentTextVersion": try XCTUnwrap(before["consentTextVersion"] as? Int), "allow": [scope], "deny": [String]()
        ])
        mark("L114")
        try response(used: 80)
        mark("L115")
        _ = try await command(["quota", "--refresh-account", "--json", "--offline"], helper: helper, environment: environment)
        // Age only the disposable fixture, keeping the producer-generated binding and admission stamp.
        mark("L117")
        let readingURL = cache.appendingPathComponent("codex-account.json")
        mark("L118")
        var seed = try decode(Data(contentsOf: readingURL))
        mark("L119")
        let ref = try XCTUnwrap(seed["subscriptionRef"] as? String)
        mark("L120")
        let old = iso.string(from: now.addingTimeInterval(-3 * 3600 - 30))
        seed["observedAt"] = old
        mark("L122")
        var windows = try XCTUnwrap(seed["windows"] as? [[String: Any]])
        mark("L123")
        XCTAssertEqual(windows.count, 1)
        windows[0]["observedAt"] = old
        seed["windows"] = windows
        mark("L126")
        let retainedBytes = try encode(seed)
        mark("L127")
        try retainedBytes.write(to: readingURL, options: .atomic)
        mark("L128")
        let reservation = cache.appendingPathComponent("reader-attempts/codex.json")
        mark("L129")
        try encode(["schemaVersion": 1, "nextAttemptAt": old]).write(to: reservation, options: .atomic)
        mark("L130")
        try response(used: 30)

        mark("L132")
        try Data().write(to: hold)
        defer { try? FileManager.default.removeItem(at: hold) }

        mark("L135")
        let display = DockDisplayArea(id: "synthetic", frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 880))
        mark("L137")
        var pointer = CGPoint(x: 700, y: 450), elapsed = 0.0
        mark("L138")
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        mark("L139")
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
        mark("L150")
        func account(in app: EngineDockMenuApplication) -> RowsAccount? {
            let row = app.composition.store.snapshot.rows?.projection.rows.first { $0.id == "codex" }
            return row?.accounts.first { $0.subscriptionRef == ref && $0.route == .runtimeRpc }
        }
        mark("L154")
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

        mark("L166")
        let offline = await makeApplication(offline: true)
        mark("L167")
        _ = try await offline.composition.client.start()
        mark("L168")
        _ = try await offline.composition.client.subscribeRows(timeout: .seconds(4))
        mark("L169")
        XCTAssertEqual(account(in: offline)?.valueState, .retained)
        mark("L170")
        XCTAssertEqual(account(in: offline)?.observedAt?.rawValue, old)
        mark("L171")
        try await blockedRefresh(in: offline, reason: .offline)
        mark("L172")
        XCTAssertEqual(try Data(contentsOf: readingURL), retainedBytes, "Offline may not replace the retained cache")
        mark("L173")
        await offline.composition.stop()

        mark("L175")
        let app = await makeApplication()
        mark("L176")
        let delivery = try await app.composition.client.start()
        mark("L177")
        func wait(until predicate: () -> Bool) async throws {
            let deadline = ContinuousClock.now + .seconds(10)
            while !predicate() && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
        }
        mark("L181")
        try await wait { account(in: app)?.valueState == .retained }
        mark("L182")
        XCTAssertEqual(account(in: app)?.observedAt?.rawValue, old)
        mark("L183")
        XCTAssertEqual(account(in: app)?.valueState, .retained)

        mark("L185")
        let dock = app.composition.dock, view = dock.dockView
        mark("L186")
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
        mark("L197")
        let card = try openCard()
        mark("L198")
        let window = try XCTUnwrap(account(in: app)?.windows.first)
        mark("L199")
        XCTAssertEqual(window.remainingPercent, 20)
        mark("L200")
        XCTAssertEqual(window.observedAt?.rawValue, old)
        mark("L201")
        XCTAssertEqual(window.source, .runtime)
        mark("L202")
        let weekly = "row.quota:" + window.id
        mark("L203")
        XCTAssertEqual(text(weekly + ".value", in: card), "--", "Retained metadata must not admit an expired number")
        // One source: the header carries it, and the row does not repeat it.
        mark("L205")
        let retainedSource = text("source", in: card)
        mark("L206")
        XCTAssertTrue(retainedSource?.contains("Tool runtime · 3h ago") == true,
                      "Retained window provenance: " + (retainedSource ?? "missing"))
        mark("L208")
        XCTAssertTrue(FileManager.default.fileExists(atPath: hold.path), "DIAG hold before requested wait")
        mark("L209")
        try await wait { FileManager.default.fileExists(atPath: requested.path) }
        mark("L210")
        XCTAssertTrue(FileManager.default.fileExists(atPath: hold.path), "DIAG hold after requested wait: " + ((try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []).joined(separator: ","))
        mark("L211")
        XCTAssertTrue(FileManager.default.fileExists(atPath: requested.path), "The normal session started the runtime RPC")
        do { try FileManager.default.removeItem(at: hold) }
        catch { XCTFail("DIAG first release failed; exists=\(FileManager.default.fileExists(atPath: hold.path)) dir=\(((try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []).joined(separator: ",")) error=\(error)"); throw error }
        mark("L214")
        try await wait { account(in: app)?.valueState == .current && account(in: app)?.windows.first?.remainingPercent == 70 }
        mark("L215")
        XCTAssertEqual(app.composition.store.snapshot.delivery, delivery)
        mark("L216")
        let recovered = try XCTUnwrap(account(in: app)?.windows.first)
        mark("L217")
        XCTAssertEqual(recovered.id, window.id)
        mark("L218")
        XCTAssertEqual(recovered.remainingPercent, 70)
        mark("L219")
        XCTAssertEqual(recovered.source, .runtime)
        mark("L220")
        XCTAssertNotEqual(recovered.observedAt?.rawValue, old)
        mark("L221")
        XCTAssertEqual(account(in: app)?.valueState, .current)
        mark("L222")
        XCTAssertTrue(dock.detachedCardForChecks === card, "The still-hovered card must update without closing")
        // If continuity fails, a fresh hover still distinguishes projection from the close.
        mark("L224")
        let currentCard: DockCardView
        if let displayed = dock.detachedCardForChecks { currentCard = displayed }
        else { currentCard = try openCard() }
        mark("L227")
        XCTAssertEqual(text(weekly + ".value", in: currentCard), "70%")
        mark("L228")
        XCTAssertTrue(text("source", in: currentCard)?.contains("Tool runtime · just now") == true)

        mark("L230")
        let deny = try WireConsentGrantParams(requestId: UUID().uuidString.lowercased(),
            expectStoreEpoch: delivery.floor.storeEpoch, expectGeneration: delivery.floor.generation,
            consentTextVersion: XCTUnwrap(before["consentTextVersion"] as? Int), allow: [], deny: [scope])
        mark("L233")
        _ = try await app.composition.client.grant(deny, userAction: .init(id: UUID()), timeout: .seconds(4))
        mark("L234")
        XCTAssertNil(dock.detachedCardForChecks, "Consent withdrawal must close the card before the grant returns")
        mark("L235")
        XCTAssertNil(text(weekly + ".value", in: currentCard))
        mark("L236")
        _ = try await app.composition.client.subscribeRows(timeout: .seconds(4))
        mark("L237")
        XCTAssertNil(account(in: app), "A revoked subscription must not reappear on the next real rows reply")
        mark("L238")
        XCTAssertNil(try dock.cardContent(for: ref))
        mark("L239")
        await app.composition.stop()

        mark("L241")
        try FileManager.default.removeItem(at: requested)
        mark("L242")
        XCTAssertFalse(FileManager.default.fileExists(atPath: hold.path), "DIAG hold before second write")
        mark("L243")
        try Data().write(to: hold)
        print("DIAG reached denied launch")
        mark("L245")
        let denied = await makeApplication()
        mark("L246")
        _ = try await denied.composition.client.start()
        mark("L247")
        _ = try await denied.composition.client.subscribeRows(timeout: .seconds(4))
        mark("L248")
        XCTAssertNil(account(in: denied), "A new launch must honor the persisted denial")
        mark("L249")
        try await blockedRefresh(in: denied, reason: .readOnly)
        mark("L250")
        XCTAssertNil(try denied.composition.dock.cardContent(for: ref))
    }
    func testR01ExplicitLocalGrantShowsFourThenThreePercentWithSourceTime() async throws {
        try await exerciseLocalHistory(initialRemaining: 4, updatedRemaining: 3, initialAge: 150, initialState: .current)
    }

    func testR06LocalHistoryChangeReachesTheSameSubscribedMember() async throws {
        try await exerciseLocalHistory(initialRemaining: 20, updatedRemaining: 70, initialAge: 3 * 3600 + 30, initialState: .retained)
    }

    private func exerciseLocalHistory(initialRemaining: Int, updatedRemaining: Int, initialAge: TimeInterval,
                                      initialState: RowsValueState) async throws {
        let (root, helper, environment) = try sandbox()
        // Establish tool presence without a usable runtime executable.
        _ = try script("codex", in: root, "#!/bin/sh\nexit 64\n")
        let scope = "codex.local_history"
        let runtimeScope = "codex.runtime_usage"
        _ = try await command(["consent", "init", "--json"], helper: helper, environment: environment)
        let before = try await command(["consent", "--json"], helper: helper, environment: environment)
        _ = try await command(["consent", "grant", "--json"], helper: helper, environment: environment, input: [
            "requestId": UUID().uuidString.lowercased(), "expectStoreEpoch": try XCTUnwrap(before["storeEpoch"] as? String),
            "expectGeneration": try XCTUnwrap(before["generation"] as? Int),
            "consentTextVersion": try XCTUnwrap(before["consentTextVersion"] as? Int), "allow": [scope], "deny": [runtimeScope]
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
        let old = now.addingTimeInterval(-initialAge)
        try line(used: 100 - initialRemaining, at: old).write(to: log)
        let report = try await command(["quota", "--json", "--offline"], helper: helper, environment: environment)
        let reportAccounts = try XCTUnwrap(report["accounts"] as? [[String: Any]])
        let directLocal = try XCTUnwrap(reportAccounts.first { $0["source"] as? String == "codex" },
                                       "The same explicit local grant must expose the fixture to CLI quota")
        let directWindow = try XCTUnwrap((directLocal["windows"] as? [[String: Any]])?.first)
        XCTAssertEqual(directWindow["remainingPercent"] as? Double, Double(initialRemaining))

        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        var pointer = CGPoint(x: 700, y: 450), elapsed = 0.0
        let app = EngineRowsEntry.make(configuration: .init(executableURL: helper, applicationVersion: "synthetic-local-card",
            allowedEnvironment: environment, readOnly: true), settingsStore: settings, createsNativePanels: false,
            bundleURL: root.appendingPathComponent("Synthetic.app"), dockEnvironment: {
                var topology = normalEntryTestEnvironment()
                topology.pointer = pointer
                return topology
            }, deadlineElapsed: { elapsed }, deadlineScheduling: RuntimeCardTimer(), activateSettings: {})
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
        XCTAssertEqual(first.valueState, initialState)
        XCTAssertEqual(firstWindow.remainingPercent, Double(initialRemaining))
        XCTAssertEqual(firstWindow.source, .localHistory)
        XCTAssertEqual(firstWindow.observedAt?.rawValue, iso.string(from: old))

        let dock = app.composition.dock, view = dock.dockView
        let member = "codex#local_log"
        func openLocalCard() throws -> DockCardView {
            let placement = try XCTUnwrap(dock.edgePresentation?.placement)
            let anchor = try XCTUnwrap(view.interactionAnchor(member))
            pointer = CGPoint(x: placement.frame.minX + anchor.midX - view.bounds.minX,
                              y: placement.frame.maxY - anchor.midY + view.bounds.minY)
            try XCTUnwrap(view.nozzleEventDelegate).hoverNozzle(member)
            elapsed += 0.251
            try XCTUnwrap(dock.interactionControllerForChecks).refresh()
            return try XCTUnwrap(dock.detachedCardForChecks)
        }
        if initialState == .current {
            let initialCard = try openLocalCard()
            XCTAssertEqual(text("row.quota:" + firstWindow.id + ".value", in: initialCard), "\(initialRemaining)%")
            XCTAssertTrue(text("source", in: initialCard)?.contains("Local history · 2m ago") == true)
        }

        func appendReading(used: Int, at observed: Date) throws {
            let handle = try FileHandle(forWritingTo: log)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: line(used: used, at: observed))
        }
        let fresh = Date()
        try appendReading(used: 100 - updatedRemaining, at: fresh)
        func waitForFreshReading(timeout: Duration) async throws -> Bool {
            let end = ContinuousClock.now + timeout
            while localAccount()?.windows.first?.remainingPercent != Double(updatedRemaining) && ContinuousClock.now < end {
                try await Task.sleep(for: .milliseconds(20))
            }
            return localAccount()?.windows.first?.remainingPercent == Double(updatedRemaining)
        }
        let deliveredOnAppend = try await waitForFreshReading(timeout: .seconds(6))
        XCTAssertTrue(deliveredOnAppend, "The existing subscription must receive the new local observation without a request")
        guard deliveredOnAppend else { return }
        let current = try XCTUnwrap(localAccount())
        let currentWindow = try XCTUnwrap(current.windows.first)
        XCTAssertEqual(app.composition.store.snapshot.delivery, delivery)
        XCTAssertEqual(current.subscriptionRef, first.subscriptionRef)
        XCTAssertEqual(currentWindow.id, firstWindow.id)
        XCTAssertEqual(current.valueState, .current)
        XCTAssertEqual(currentWindow.remainingPercent, Double(updatedRemaining))
        XCTAssertEqual(currentWindow.source, .localHistory)
        XCTAssertEqual(currentWindow.observedAt?.rawValue, iso.string(from: fresh))
        XCTAssertNil(current.subscriptionRef, "Local history must not be linked to a runtime account")
        let card = try openLocalCard()
        XCTAssertEqual(text("row.quota:" + currentWindow.id + ".value", in: card), "\(updatedRemaining)%")
        XCTAssertTrue(text("source", in: card)?.contains("Local history · just now") == true)

        // Commit the denial from the same synthetic profile while the read-only
        // App stays subscribed. The consent event must withdraw the actual card.
        _ = try await command(["consent", "grant", "--json"], helper: helper, environment: environment, input: [
            "requestId": UUID().uuidString.lowercased(), "expectStoreEpoch": delivery.floor.storeEpoch,
            "expectGeneration": delivery.floor.generation, "consentTextVersion": try XCTUnwrap(before["consentTextVersion"] as? Int),
            "allow": [String](), "deny": [scope]
        ])
        let withdrawal = ContinuousClock.now + .seconds(4)
        while dock.detachedCardForChecks != nil && ContinuousClock.now < withdrawal {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertNil(dock.detachedCardForChecks)
        XCTAssertNil(text("row.quota:" + currentWindow.id + ".value", in: card))
        try appendReading(used: 10, at: Date())
        try await Task.sleep(for: .milliseconds(1_250))
        XCTAssertNil(localAccount())
        XCTAssertNil(try dock.cardContent(for: member))

    }

}
