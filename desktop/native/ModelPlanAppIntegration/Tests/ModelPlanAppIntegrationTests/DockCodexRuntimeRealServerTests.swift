// SPDX-License-Identifier: MIT
#if MODELPLAN_DOCK_REAL_RUNTIME_JOURNEY
import AppKit
import ModelPlanDock
import ModelPlanSettings
import ModelPlanWire
import XCTest
@testable import ModelPlanAppIntegration

@MainActor private final class RuntimeCardTimer: DockEdgeScheduling {
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) {}
    func cancel() {}
}

@MainActor final class DockCodexRuntimeRealServerTests: XCTestCase {
    func testSameRuntimeMemberUpdatesTheOpenCard() async throws {
        let executable = try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_DOCK_TEST_CLI"])
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("codex-card-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        let cache = root.appendingPathComponent("Library/Caches/modelplan/observed")
        let environment = ["HOME": root.path, "TMPDIR": root.path, "PATH": root.path + ":/usr/bin:/bin", "LANG": "C"]
        func quote(_ path: String) -> String { "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        func script(_ name: String, _ text: String) throws -> URL {
            let url = root.appendingPathComponent(name)
            try text.write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
            return url
        }
        // Keep normal automatic refresh enabled while preventing network access by the helper and its children.
        let helper = try script("app-cli", """
            #!/bin/sh
            exec /usr/bin/sandbox-exec -p '(version 1)(allow default)(deny network*)' \(quote(executable)) "$@"
            """)
        let payload = root.appendingPathComponent("rpc-response.json")
        let hold = root.appendingPathComponent("hold-runtime-reply")
        let requested = root.appendingPathComponent("runtime-requested")
        _ = try script("codex", """
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
        func encode(_ json: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: json) }
        func decode(_ data: Data) throws -> [String: Any] {
            try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        }
        func command(_ arguments: [String], input: [String: Any]? = nil) async throws -> [String: Any] {
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

        let now = Date(), iso = ISO8601DateFormatter(), scope = "codex.runtime_usage"
        func response(used: Int) throws {
            try encode(["rateLimits": ["planType": "plus", "secondary": ["usedPercent": used,
                "windowDurationMins": 10080, "resetsAt": Int(now.timeIntervalSince1970) + 86_400]]]).write(to: payload, options: .atomic)
        }
        _ = try await command(["consent", "init", "--json"])
        let before = try await command(["consent", "--json"])
        _ = try await command(["consent", "grant", "--json"], input: [
            "requestId": UUID().uuidString.lowercased(), "expectStoreEpoch": try XCTUnwrap(before["storeEpoch"] as? String),
            "expectGeneration": try XCTUnwrap(before["generation"] as? Int),
            "consentTextVersion": try XCTUnwrap(before["consentTextVersion"] as? Int), "allow": [scope], "deny": [String]()
        ])
        try response(used: 80)
        _ = try await command(["quota", "--refresh-account", "--json", "--offline"])
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
        try encode(seed).write(to: readingURL, options: .atomic)
        let reservation = cache.appendingPathComponent("reader-attempts/codex.json")
        try encode(["schemaVersion": 1, "nextAttemptAt": old]).write(to: reservation, options: .atomic)
        try response(used: 30)

        try Data().write(to: hold)
        defer { try? FileManager.default.removeItem(at: hold) }

        let display = DockDisplayArea(id: "synthetic", frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 880))
        var pointer = CGPoint(x: 700, y: 450), elapsed = 0.0
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let app = EngineRowsEntry.make(configuration: .init(executableURL: helper, applicationVersion: "synthetic-runtime-card",
            allowedEnvironment: environment), settingsStore: settings, createsNativePanels: false,
            bundleURL: root.appendingPathComponent("Synthetic.app"),
            dockEnvironment: { .init(displays: [display], layouts: [], primaryDisplayID: display.id, pointer: pointer) },
            deadlineNow: { Date() }, deadlineElapsed: { elapsed }, deadlineScheduling: RuntimeCardTimer(), activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.prepare()
        app.allowDockPresentation()
        let delivery = try await app.composition.client.start()
        func account() -> RowsAccount? {
            let row = app.composition.store.snapshot.rows?.projection.rows.first { $0.id == "codex" }
            return row?.accounts.first {
                $0.subscriptionRef == ref && $0.route == .runtimeRpc
            }
        }
        func wait(until predicate: () -> Bool) async throws {
            let deadline = ContinuousClock.now + .seconds(10)
            while !predicate() && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
        }
        try await wait { account()?.valueState == .retained }
        XCTAssertEqual(account()?.observedAt?.rawValue, old)
        XCTAssertEqual(account()?.valueState, .retained)

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
        let window = try XCTUnwrap(account()?.windows.first)
        XCTAssertEqual(window.remainingPercent, 20)
        XCTAssertEqual(window.observedAt?.rawValue, old)
        XCTAssertEqual(window.source, .runtime)
        let weekly = "row.quota:" + window.id
        let retainedDetail = text(weekly + ".detail", in: card)
        XCTAssertTrue(retainedDetail?.contains("Tool runtime · 3h ago") == true,
                      "Retained window provenance: " + (retainedDetail ?? "missing"))
        try await wait { FileManager.default.fileExists(atPath: requested.path) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: requested.path), "The normal session started the runtime RPC")
        try FileManager.default.removeItem(at: hold)
        try await wait { account()?.valueState == .current && account()?.windows.first?.remainingPercent == 70 }
        XCTAssertEqual(app.composition.store.snapshot.delivery, delivery)
        let recovered = try XCTUnwrap(account()?.windows.first)
        XCTAssertEqual(recovered.id, window.id)
        XCTAssertEqual(recovered.remainingPercent, 70)
        XCTAssertEqual(recovered.source, .runtime)
        XCTAssertNotEqual(recovered.observedAt?.rawValue, old)
        XCTAssertEqual(account()?.valueState, .current)
        XCTAssertTrue(dock.detachedCardForChecks === card, "The still-hovered card must update without closing")
        // If continuity fails, a fresh hover still distinguishes projection from the close.
        let currentCard: DockCardView
        if let displayed = dock.detachedCardForChecks { currentCard = displayed }
        else { currentCard = try openCard() }
        XCTAssertEqual(text(weekly + ".value", in: currentCard), "70%")
        XCTAssertTrue(text(weekly + ".detail", in: currentCard)?.contains("Tool runtime · just now") == true)

    }
}
#endif
