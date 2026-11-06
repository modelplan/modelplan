// SPDX-License-Identifier: MIT
#if MODELPLAN_DOCK_REAL_CONTEXT_JOURNEY
import AppKit
import ModelPlanSettings
import ModelPlanWire
import XCTest
@testable import ModelPlanAppIntegration

@MainActor final class DockRealDiagnosticsMenuTests: XCTestCase {
    private func quote(_ path: String) -> String { "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    private func script(_ name: String, in root: URL, _ text: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        return url
    }

    private func sandbox() throws -> (URL, URL, [String: String]) {
        let executable = try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_DOCK_TEST_CLI"])
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("d24-reader-menu-" + UUID().uuidString)
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

    func testD24RealReaderFailureAddsOnlyOneLocalizedDiagnosticsAction() async throws {
        let (root, helper, environment) = try sandbox()
        let failed = root.appendingPathComponent("simulate-reader-failure")
        let cache = root.appendingPathComponent("Library/Caches/modelplan/observed")
        let snapshot = cache.appendingPathComponent("codex-account.json")
        let attempts = cache.appendingPathComponent("reader-attempts/codex.json")
        let reset = Int(Date().timeIntervalSince1970) + 86_400
        _ = try script("codex", in: root, """
            #!/bin/sh
            [ "$1" = app-server ] || exit 2
            while IFS= read -r line; do
                case "$line" in
                *'"id":1,'*) echo '{"id":1,"result":{"userAgent":"synthetic"}}' ;;
                *'"method":"account/rateLimits/read"'*)
                    if [ -e \(quote(failed.path)) ]; then
                        echo '{"id":2,"error":{"code":-32000,"message":"synthetic failure"}}'
                    else
                        echo '{"id":2,"result":{"rateLimits":{"planType":"plus","secondary":{"usedPercent":25,"windowDurationMins":10080,"resetsAt":\(reset)}}}}'
                    fi ;;
                *'"method":"account/read"'*) echo '{"id":3,"result":{"account":{"type":"chatgpt","email":"synthetic@example.invalid"}}}' ;;
                esac
            done
            """)
        let scope = "codex.runtime_usage"
        _ = try await command(["consent", "init", "--json"], helper: helper, environment: environment)
        let before = try await command(["consent", "--json"], helper: helper, environment: environment)
        _ = try await command(["consent", "grant", "--json"], helper: helper, environment: environment, input: [
            "requestId": UUID().uuidString.lowercased(), "expectStoreEpoch": try XCTUnwrap(before["storeEpoch"] as? String),
            "expectGeneration": try XCTUnwrap(before["generation"] as? Int),
            "consentTextVersion": try XCTUnwrap(before["consentTextVersion"] as? Int), "allow": [scope], "deny": [String]()
        ])
        _ = try await command(["quota", "--refresh-account", "--json", "--offline"], helper: helper, environment: environment)
        let healthy = try decode(Data(contentsOf: snapshot))
        XCTAssertEqual(healthy["status"] as? String, "ok")

        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let surface = TestSettingsSurface()
        let app = EngineRowsEntry.make(configuration: .init(executableURL: helper, applicationVersion: "synthetic-d24",
            allowedEnvironment: environment, offline: true, readOnly: true), settingsStore: settings,
            createsNativePanels: false, bundleURL: root.appendingPathComponent("Synthetic.app"), cockpitEntryEnabled: true,
            dockEnvironment: normalEntryTestEnvironment, makeSettingsSurface: { _ in surface }, activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.prepare()
        app.allowDockPresentation()
        let delivery = try await app.composition.client.start()
        _ = try await app.composition.client.subscribeRows(timeout: .seconds(4))
        func row() -> RowsRow? {
            app.composition.store.snapshot.rows?.projection.rows.first { $0.id == "codex" }
        }
        func items() throws -> [NSMenuItem] {
            try XCTUnwrap(app.liveStatusMenu).items.filter { !$0.isSeparatorItem }
        }
        func capture(_ phase: String, _ locale: String) throws {
            guard let path = ProcessInfo.processInfo.environment["MODELPLAN_D24_CAPTURE_DIR"] else { return }
            let visible = try items()
            let report: [String: Any] = [
                "phase": phase, "locale": locale,
                "state": row().map { String(describing: $0.state) } ?? "absent",
                "accounts": row()?.accounts.count ?? 0,
                "items": visible.map { ["title": $0.title, "enabled": $0.isEnabled] },
                "selectedPanes": surface.shown,
            ]
            let output = URL(fileURLWithPath: path).appendingPathComponent(phase + "-" + locale + ".json")
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: output)
        }
        XCTAssertEqual(row()?.state, .fresh)
        XCTAssertEqual(row()?.accounts.first?.windows.first?.remainingPercent, 75)
        let editor = app.settingsHost.application.editor
        try capture("healthy", "en")
        let english = try items().map(\.title)
        XCTAssertEqual(english, ["Refresh", "Show Quota Widget", "Open Cockpit", "Website", "Methodology", "Privacy", "Help…", "Settings…", "About", "Quit"])
        _ = try await editor.commit(SettingsB21Edit.language(.chinese))
        try capture("healthy", "zh")
        let chinese = try items().map(\.title)
        XCTAssertEqual(chinese, ["刷新", "显示额度挂件", "打开驾驶舱", "网站", "方法论", "隐私", "说明…", "设置…", "关于", "退出"])

        // Backdate the synthetic fixture and reservation to exercise a second
        // real reader call without changing the production refresh interval.
        func makeDue(_ original: [String: Any], seconds: TimeInterval) throws {
            let due = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-seconds))
            var fixture = original
            fixture["observedAt"] = due
            try encode(fixture).write(to: snapshot, options: .atomic)
            try encode(["schemaVersion": 1, "nextAttemptAt": due]).write(to: attempts, options: .atomic)
        }
        try makeDue(healthy, seconds: 360)
        try Data().write(to: failed)
        _ = try await command(["quota", "--refresh-account", "--json", "--offline"], helper: helper, environment: environment)
        let failure = try decode(Data(contentsOf: snapshot))
        XCTAssertEqual(failure["status"] as? String, "error", "A real failed reader result must replace the cached success")
        let end = ContinuousClock.now + .seconds(5)
        while row()?.state != .failed && ContinuousClock.now < end {
            try await Task.sleep(for: .milliseconds(20))
        }
        let failedRow = try XCTUnwrap(row())
        XCTAssertEqual(failedRow.state, .failed, "Producer result: " + String(describing: failedRow.reason.code))
        XCTAssertTrue(failedRow.accounts.isEmpty, "The real failed provider need not retain an account")
        XCTAssertEqual(app.composition.store.snapshot.delivery, delivery)
        try capture("failed", "zh")
        let zhProblem = failedRow.name.zh + "：读取失败 · 查看…"
        XCTAssertEqual(try items().filter { $0.title == zhProblem }.count, 1)
        XCTAssertEqual(try items().filter { $0.title != zhProblem }.map(\.title), chinese)
        _ = try await editor.commit(SettingsB21Edit.language(.english))
        let enProblem = failedRow.name.en + ": Couldn't read · Details…"
        XCTAssertEqual(try items().filter { $0.title == enProblem }.count, 1)
        XCTAssertEqual(try items().filter { $0.title != enProblem }.map(\.title), english)
        let menu = try XCTUnwrap(app.liveStatusMenu)
        if let index = menu.items.firstIndex(where: { $0.title == enProblem }) {
            let shown = expectation(description: "The problem opens Settings Diagnostics")
            surface.onShow = { shown.fulfill() }
            menu.performActionForItem(at: index)
            await fulfillment(of: [shown], timeout: 2)
        }
        try capture("failed", "en")
        XCTAssertEqual(surface.shown, ["diagnostics"])

        try makeDue(failure, seconds: 3_600)
        try FileManager.default.removeItem(at: failed)
        _ = try await command(["quota", "--refresh-account", "--json", "--offline"], helper: helper, environment: environment)
        let recovery = ContinuousClock.now + .seconds(5)
        while row()?.state != .fresh && ContinuousClock.now < recovery {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(app.composition.store.snapshot.delivery, delivery)
        XCTAssertEqual(row()?.state, .fresh)
        try capture("recovered", "en")
        XCTAssertEqual(try items().map(\.title), english)
        _ = try await editor.commit(SettingsB21Edit.language(.chinese))
        try capture("recovered", "zh")
        XCTAssertEqual(try items().map(\.title), chinese)
    }
}
#endif
