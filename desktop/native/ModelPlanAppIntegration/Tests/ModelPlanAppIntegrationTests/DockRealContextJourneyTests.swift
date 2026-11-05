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

@MainActor private final class D13RefreshReplies: EngineStoreEventSink {
    private(set) var outcomes: [WireMemberRefreshResult] = []
    func acceptedEvent(_ event: EngineClientEvent) {
        if case .response(_, .memberRefresh(let reply)) = event { outcomes.append(reply.envelope.data) }
    }
    func apply(_ snapshot: EngineStoreSnapshot) {}
    func clearPrivateViews(_ invalidation: EngineInvalidation) {}
}

@MainActor final class DockRealContextJourneyTests: XCTestCase {
    func testD13BilingualCardAndMenuUseTheRealServerDelivery() async throws {
        let helper = URL(fileURLWithPath: try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_DOCK_TEST_CLI"]))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("d13-real-context-" + UUID().uuidString)
        let config = root.appendingPathComponent(".config/modelplan")
        try FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        let environment = ["HOME": root.path, "TMPDIR": root.path, "PATH": "/usr/bin:/bin", "LANG": "C"]
        let initConsent = Process()
        initConsent.executableURL = helper; initConsent.arguments = ["consent", "init", "--json"]
        initConsent.environment = environment
        initConsent.standardInput = FileHandle.nullDevice
        initConsent.standardOutput = FileHandle.nullDevice
        initConsent.standardError = FileHandle.nullDevice
        try initConsent.run()
        let seedDeadline = ContinuousClock.now + .seconds(5)
        while initConsent.isRunning && ContinuousClock.now < seedDeadline { try await Task.sleep(for: .milliseconds(10)) }
        if initConsent.isRunning { initConsent.terminate(); return XCTFail("Synthetic consent initialization timed out") }
        XCTAssertEqual(initConsent.terminationStatus, 0)

        let now = Date(), iso = ISO8601DateFormatter(), plan = "synthetic-d13"
        let fixture: [String: Any] = ["schemaVersion": 1, "plans": [["planId": plan]], "windows": [[
            "planId": plan, "kind": "five_hour", "remainingPercent": 57, "resetMode": "rolling",
            "observedAt": iso.string(from: now.addingTimeInterval(-20)),
            "resetAt": iso.string(from: now.addingTimeInterval(7_200))
        ]]]
        try JSONSerialization.data(withJSONObject: fixture).write(to: config.appendingPathComponent("local.json"), options: .atomic)

        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        _ = try await settings.update { $0.autoHide = false; $0.motion = .on }
        let settingsSurface = TestSettingsSurface()
        var builds = 0
        var pointer = CGPoint(x: 1430, y: 475), cardFrame: CGRect?
        var elapsed = 0.0
        let app = EngineRowsEntry.make(configuration: .init(executableURL: helper, applicationVersion: "synthetic-d13",
            allowedEnvironment: environment, offline: true, readOnly: true), settingsStore: settings, createsNativePanels: false,
            bundleURL: root.appendingPathComponent("Synthetic.app"), dockEnvironment: {
                var facts = normalEntryTestEnvironment()
                facts.pointer = pointer
                facts.cardFrame = cardFrame
                return facts
            }, deadlineElapsed: { elapsed }, makeSettingsSurface: { _ in builds += 1; return settingsSurface },
            activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.prepare()
        app.allowDockPresentation()
        let delivery = try await app.composition.client.start()
        _ = try await app.composition.client.subscribeRows(timeout: .seconds(4))
        let wire = try XCTUnwrap(app.composition.store.snapshot.rows?.projection.rows.first { $0.id == "declared:" + plan })
        XCTAssertEqual(wire.accounts.first?.windows.first?.remainingPercent, 57)
        let dock = app.composition.dock, view = dock.dockView
        let member = try XCTUnwrap(app.composition.presentedContent.snapshot.inputs.first?.id)
        XCTAssertEqual(view.presentedReadingsForChecks[member]?.readout, "57%")
        let nozzle = try XCTUnwrap(view.nozzleEventDelegate)
        let controller = try XCTUnwrap(dock.interactionControllerForChecks)
        let frame = try XCTUnwrap(dock.edgePresentation?.placement?.frame)
        let anchor = try XCTUnwrap(view.interactionAnchor(member))
        let ring = CGPoint(x: frame.minX + anchor.midX - view.bounds.minX, y: frame.maxY - anchor.midY + view.bounds.minY)
        func openCard() {
            pointer = ring
            nozzle.hoverNozzle(nil)
            nozzle.hoverNozzle(member)
            elapsed += 0.251
            controller.refresh()
            XCTAssertFalse(dock.card.isHidden)
        }
        func button(_ id: String, in view: NSView) -> NSButton? {
            if let control = view as? NSButton, control.accessibilityIdentifier() == id { return control }
            return view.subviews.lazy.compactMap { button(id, in: $0) }.first
        }
        let editor = app.settingsHost.application.editor
        for (language, settingsTitle, closeTitle) in [(SettingsLanguage.english, "Settings", "Close"), (.chinese, "设置", "关闭")] {
            _ = try await editor.commit(SettingsB21Edit.language(language))
            openCard()
            let target = CGRect(x: frame.minX - 312, y: frame.midY - 100, width: 300, height: 200)
            cardFrame = target
            pointer = CGPoint(x: frame.minX - 6, y: frame.midY)
            nozzle.hoverNozzle(nil)
            elapsed += 0.3
            controller.refresh()
            XCTAssertTrue(dock.interactionEnvironment().insideShared == true)
            XCTAssertFalse(dock.card.isHidden, "The card remains visible across the transfer corridor")
            pointer = CGPoint(x: target.midX, y: target.midY)
            controller.refresh()
            XCTAssertFalse(dock.card.isHidden)
            pointer = CGPoint(x: 100, y: 100)
            controller.refresh()
            elapsed += 0.249
            controller.refresh()
            XCTAssertFalse(dock.card.isHidden)
            elapsed += 0.002
            controller.refresh()
            XCTAssertTrue(dock.card.isHidden, "Leaving both surfaces closes the card after the grace")
            cardFrame = nil

            openCard()
            let menu = dock.menu()
            let actions = menu.items.filter { $0.title == settingsTitle || $0.title == closeTitle }
            XCTAssertEqual(actions.map(\.title), [settingsTitle, closeTitle])
            let settingsButton = try XCTUnwrap(button("dock.card.enter", in: dock.card))
            XCTAssertEqual(settingsButton.title, settingsTitle)
            let closeButton = try XCTUnwrap(button("dock.card.close", in: dock.card))
            XCTAssertEqual(closeButton.accessibilityLabel(), closeTitle)
            let footer = try XCTUnwrap(settingsButton.superview as? NSStackView)
            XCTAssertEqual(footer.arrangedSubviews.map { $0.accessibilityIdentifier() },
                           ["dock.card.enter", "dock.card.close"])

            let cardSettings = expectation(description: "Card opens the shared Settings host")
            settingsSurface.onShow = { cardSettings.fulfill() }
            settingsButton.performClick(nil)
            await fulfillment(of: [cardSettings], timeout: 2)
            XCTAssertTrue(dock.card.isHidden)

            openCard()
            let menuSettings = expectation(description: "Menu opens the same Settings host")
            settingsSurface.onShow = { menuSettings.fulfill() }
            let settingsIndex = try XCTUnwrap(menu.items.firstIndex { $0.title == settingsTitle })
            menu.performActionForItem(at: settingsIndex)
            await fulfillment(of: [menuSettings], timeout: 2)
            XCTAssertTrue(dock.card.isHidden)

            openCard()
            try XCTUnwrap(button("dock.card.close", in: dock.card)).performClick(nil)
            XCTAssertTrue(dock.card.isHidden)
            openCard()
            let closeIndex = try XCTUnwrap(menu.items.firstIndex { $0.title == closeTitle })
            menu.performActionForItem(at: closeIndex)
            XCTAssertTrue(dock.card.isHidden)
        }
        XCTAssertEqual(builds, 1)
        XCTAssertEqual(settingsSurface.shown.count, 4)
        XCTAssertEqual(app.composition.store.snapshot.delivery, delivery)

        let sweeps = view.refreshSweepCountForChecks
        let before = app.composition.presentedContent.snapshot.presentationRows[member]?.originalObservedAt
        pointer = ring
        XCTAssertTrue(nozzle.beginNozzle(id: member, local: CGPoint(x: anchor.midX, y: anchor.midY)))
        nozzle.endNozzle(global: ring, currentID: member)
        XCTAssertEqual(view.refreshSweepCountForChecks, sweeps + 1)
        XCTAssertFalse(view.refreshSweepAnimatingForChecks)
        XCTAssertTrue(dock.card.isHidden, "Clicking a nozzle must not pin a card")
        XCTAssertEqual(app.composition.presentedContent.snapshot.presentationRows[member]?.originalObservedAt, before)
    }

    private func quote(_ path: String) -> String { "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    private func script(_ name: String, in root: URL, _ text: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        return url
    }

    private func sandbox() throws -> (URL, URL, [String: String]) {
        let executable = try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_DOCK_TEST_CLI"])
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("d13-member-refresh-" + UUID().uuidString)
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

    func testD13RingClickStartsOnlyItsRealServerMemberRefresh() async throws {
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
        let controlPlan = "d13-independent-control"
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
        _ = try await settings.update { $0.autoHide = false; $0.motion = .on }
        let app = EngineRowsEntry.make(configuration: .init(executableURL: helper, applicationVersion: "d13-real-member",
            allowedEnvironment: environment), settingsStore: settings, createsNativePanels: false,
            bundleURL: root.appendingPathComponent("Synthetic.app"), dockEnvironment: normalEntryTestEnvironment, activateSettings: {})
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

        let reply = D13RefreshReplies()
        let observer = app.composition.store.attach(reply)
        defer { app.composition.store.detach(observer) }
        let dock = app.composition.dock, view = dock.dockView
        let nozzle = try XCTUnwrap(view.nozzleEventDelegate)
        let anchor = try XCTUnwrap(view.interactionAnchor(ref))
        let target = CGPoint(x: anchor.midX, y: anchor.midY)
        func click() {
            XCTAssertTrue(nozzle.beginNozzle(id: ref, local: target))
            nozzle.endNozzle(global: .zero, currentID: ref)
        }
        let sweeps = view.refreshSweepCountForChecks
        click()
        XCTAssertTrue(dock.card.isHidden)
        XCTAssertEqual(view.refreshSweepCountForChecks, sweeps + 1)
        let end = ContinuousClock.now + .seconds(6)
        while member()?.account.windows.first?.remainingPercent != 70 && ContinuousClock.now < end {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(reply.outcomes.map(\.outcome), [.started])
        let refreshed = try XCTUnwrap(member())
        XCTAssertEqual(refreshed.account.windows.first?.remainingPercent, 70)
        XCTAssertNotEqual(refreshed.account.windows.first?.observedAt?.rawValue, old)
        XCTAssertEqual(view.presentedReadingsForChecks[ref]?.readout, "70%")
        XCTAssertEqual(controlReading(), 51)
        XCTAssertEqual(try String(contentsOf: calls, encoding: .utf8), "read\n")

        XCTAssertEqual(adapter.admission(for: refreshed, delivery: current, now: Date()), .deferred)
        click()
        XCTAssertTrue(dock.card.isHidden)
        XCTAssertEqual(view.refreshSweepCountForChecks, sweeps + 2)
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(reply.outcomes.count, 1)
        XCTAssertEqual(try String(contentsOf: calls, encoding: .utf8), "read\n")
    }

}
#endif
