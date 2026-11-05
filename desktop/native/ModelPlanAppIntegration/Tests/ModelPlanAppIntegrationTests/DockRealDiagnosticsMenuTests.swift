// SPDX-License-Identifier: MIT
#if MODELPLAN_DOCK_REAL_CONTEXT_JOURNEY
import AppKit
import ModelPlanDock
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
        try await exerciseReaderMenu(physical: false)
    }

    #if MODELPLAN_DOCK_NATIVE_JOURNEY
    func testD24PhysicalLocalizedStatusMenuAndSettingsShortcut() async throws {
        try await exerciseReaderMenu(physical: true)
    }
    #endif

    private func exerciseReaderMenu(physical: Bool) async throws {
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
        #if MODELPLAN_DOCK_NATIVE_JOURNEY
        if physical {
            _ = try await settings.update { $0.onboarding.next() }
            EngineRowsEntry.isolatesD24NativeServices = true
        }
        #endif
        let readDisplay: (@MainActor () -> DockEdgeEnvironment)?
        let makeSurface: (@MainActor (SettingsEditor) -> any SettingsWindowSurface)?
        if physical {
            readDisplay = nil
            makeSurface = nil
        } else {
            readDisplay = normalEntryTestEnvironment
            makeSurface = { _ in surface }
        }
        let app = EngineRowsEntry.make(configuration: .init(executableURL: helper, applicationVersion: "synthetic-d24",
            allowedEnvironment: environment, offline: true, readOnly: true), settingsStore: settings,
            createsNativePanels: physical, bundleURL: root.appendingPathComponent("Synthetic.app"), cockpitEntryEnabled: true,
            dockEnvironment: readDisplay, makeSettingsSurface: makeSurface, activateSettings: {
                if physical { NSApplication.shared.activate() }
            })
        func row() -> RowsRow? {
            app.composition.store.snapshot.rows?.projection.rows.first { $0.id == "codex" }
        }
        func items() throws -> [NSMenuItem] {
            try XCTUnwrap(app.liveStatusMenu).items.filter { !$0.isSeparatorItem }
        }
        if physical {
            #if MODELPLAN_DOCK_NATIVE_JOURNEY
            let application = NSApplication.shared
            let oldMenu = application.mainMenu, oldAppearance = application.appearance
            let oldPolicy = application.activationPolicy()
            addTeardownBlock { @MainActor in
                await app.stopD24NativeJourney()
                application.mainMenu = oldMenu
                application.appearance = oldAppearance
                application.setActivationPolicy(oldPolicy)
                EngineRowsEntry.isolatesD24NativeServices = false
            }
            app.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification, object: application))
            guard try await wait(.seconds(12), until: {
                app.isD24StatusItemVisible && !app.lifecyclePaused && row()?.state == .fresh
            }) else { return XCTFail("The normal application launch did not publish a healthy native status menu") }
            XCTAssertNil(app.loginServiceAdapter)
            XCTAssertNil(app.notificationAuthorizationService)
            #endif
        } else {
            addTeardownBlock { @MainActor in await app.composition.stop() }
            await app.prepare()
            app.allowDockPresentation()
            _ = try await app.composition.client.start()
            _ = try await app.composition.client.subscribeRows(timeout: .seconds(4))
        }
        let delivery = try XCTUnwrap(app.composition.store.snapshot.delivery)
        XCTAssertEqual(row()?.state, .fresh)
        XCTAssertEqual(row()?.accounts.first?.windows.first?.remainingPercent, 75)
        let editor = app.settingsHost.application.editor
        let english = try items().map(\.title)
        XCTAssertEqual(english, ["Refresh", "Show Quota Widget", "Open Cockpit", "Website", "Methodology", "Privacy", "Help…", "Settings…", "About", "Quit"])
        #if MODELPLAN_DOCK_NATIVE_JOURNEY
        if physical {
            try await capturePhysicalMenu(app, prompt: "Healthy English menu. Open, capture, then dismiss.")
            try await capturePhysicalShortcut(app, title: "Settings")
        }
        #endif
        _ = try await editor.commit(SettingsB21Edit.language(.chinese))
        let chinese = try items().map(\.title)
        XCTAssertEqual(chinese, ["刷新", "显示额度挂件", "打开驾驶舱", "网站", "方法论", "隐私", "说明…", "设置…", "关于", "退出"])

        #if MODELPLAN_DOCK_NATIVE_JOURNEY
        if physical {
            try await capturePhysicalMenu(app, prompt: "Healthy Chinese menu. Open, capture, then dismiss.")
            try await capturePhysicalShortcut(app, title: "设置")
        }
        #endif

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
        let zhProblem = failedRow.name.zh + "：读取失败 · 查看…"
        XCTAssertEqual(try items().filter { $0.title == zhProblem }.count, 1)
        XCTAssertEqual(try items().filter { $0.title != zhProblem }.map(\.title), chinese)
        #if MODELPLAN_DOCK_NATIVE_JOURNEY
        if physical { try await capturePhysicalMenu(app, prompt: "Failed Chinese menu. Open, capture, then dismiss.") }
        #endif
        _ = try await editor.commit(SettingsB21Edit.language(.english))
        let enProblem = failedRow.name.en + ": Couldn't read · Details…"
        XCTAssertEqual(try items().filter { $0.title == enProblem }.count, 1)
        XCTAssertEqual(try items().filter { $0.title != enProblem }.map(\.title), english)
        if physical {
            #if MODELPLAN_DOCK_NATIVE_JOURNEY
            try await capturePhysicalMenu(app, prompt: "Failed English menu. Capture it, then select the reader problem.")
            let window = try await waitForPhysicalSettings(title: "Settings")
            XCTAssertTrue(containsText("Reader status", in: window.contentView))
            announce("Capture the Settings Diagnostics pane, then close Settings.")
            guard try await wait(.seconds(45), until: { !window.isVisible }) else {
                return XCTFail("Settings Diagnostics remained open")
            }
            #endif
        } else {
            let menu = try XCTUnwrap(app.liveStatusMenu)
            let index = try XCTUnwrap(menu.items.firstIndex { $0.title == enProblem })
            let shown = expectation(description: "The problem opens Settings Diagnostics")
            surface.onShow = { shown.fulfill() }
            menu.performActionForItem(at: index)
            await fulfillment(of: [shown], timeout: 2)
            XCTAssertEqual(surface.shown, ["diagnostics"])

        }

        try makeDue(failure, seconds: 3_600)
        try FileManager.default.removeItem(at: failed)
        _ = try await command(["quota", "--refresh-account", "--json", "--offline"], helper: helper, environment: environment)
        let recovery = ContinuousClock.now + .seconds(5)
        while row()?.state != .fresh && ContinuousClock.now < recovery {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(app.composition.store.snapshot.delivery, delivery)
        XCTAssertEqual(row()?.state, .fresh)
        XCTAssertEqual(try items().map(\.title), english)
        #if MODELPLAN_DOCK_NATIVE_JOURNEY
        if physical { try await capturePhysicalMenu(app, prompt: "Recovered English menu. Open, capture, then dismiss.") }
        #endif
        _ = try await editor.commit(SettingsB21Edit.language(.chinese))
        XCTAssertEqual(try items().map(\.title), chinese)
        #if MODELPLAN_DOCK_NATIVE_JOURNEY
        if physical {
            try await capturePhysicalMenu(app, prompt: "Recovered Chinese menu. Open, capture, then dismiss.")
            try await capturePausedShortcut(app)
            try await capturePhysicalShortcut(app, title: "设置")
        }
        #endif
    }

    #if MODELPLAN_DOCK_NATIVE_JOURNEY
    private func announce(_ prompt: String) {
        FileHandle.standardOutput.write(Data(("D-24: " + prompt + "\n").utf8))
    }

    private func wait(_ duration: Duration, until predicate: () -> Bool) async throws -> Bool {
        let deadline = ContinuousClock.now + duration
        while !predicate() && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
        return predicate()
    }

    private func capturePhysicalMenu(_ app: EngineDockMenuApplication, prompt: String) async throws {
        let menu = try XCTUnwrap(app.liveStatusMenu)
        var began = false, ended = false
        let start = NotificationCenter.default.addObserver(forName: NSMenu.didBeginTrackingNotification,
            object: menu, queue: .main) { _ in MainActor.assumeIsolated { began = true } }
        let stop = NotificationCenter.default.addObserver(forName: NSMenu.didEndTrackingNotification,
            object: menu, queue: .main) { _ in MainActor.assumeIsolated { if began { ended = true } } }
        defer { NotificationCenter.default.removeObserver(start); NotificationCenter.default.removeObserver(stop) }
        announce(prompt)
        let tracked = try await wait(.seconds(45)) { began && ended && !app.isD24StatusMenuTracking }
        _ = try XCTUnwrap(tracked ? menu : nil, "No complete physical status-menu tracking cycle")
    }

    private func waitForPhysicalSettings(title: String) async throws -> NSWindow {
        var window: NSWindow?
        let opened = try await wait(.seconds(30)) {
            window = NSApplication.shared.windows.first { $0.isVisible && $0.isKeyWindow && $0.title == title }
            return window != nil
        }
        return try XCTUnwrap(opened ? window : nil, "No key native Settings window opened")
    }

    private func capturePhysicalShortcut(_ app: EngineDockMenuApplication, title: String) async throws {
        XCTAssertFalse(app.isD24StatusMenuTracking)
        XCTAssertFalse(NSApplication.shared.windows.contains { $0.isVisible && $0.title == title })
        NSApplication.shared.activate()
        guard try await wait(.seconds(5), until: { NSApplication.shared.isActive }) else {
            return XCTFail("The synthetic app must be active before the physical shortcut")
        }
        announce("With the status menu closed, press physical Command-comma.")
        let window = try await waitForPhysicalSettings(title: title)
        XCTAssertFalse(app.isD24StatusMenuTracking)
        announce("Capture the Settings window, then close it.")
        guard try await wait(.seconds(45), until: { !window.isVisible }) else { return XCTFail("Close Settings to continue") }
    }

    private func capturePausedShortcut(_ app: EngineDockMenuApplication) async throws {
        app.setActivityPaused(true)
        defer { app.setActivityPaused(false) }
        NSApplication.shared.activate()
        guard try await wait(.seconds(5), until: {
            app.lifecyclePaused && NSApplication.shared.isActive && !app.isD24StatusMenuTracking
        }) else { return XCTFail("The foreground app did not enter the paused state") }

        var receivedCommandComma = false
        let monitor = try XCTUnwrap(NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "," {
                MainActor.assumeIsolated { receivedCommandComma = true }
            }
            return event
        })
        defer { NSEvent.removeMonitor(monitor) }
        announce("The app is paused and its status menu is closed. Press physical Command-comma and capture that Settings stays closed.")
        guard try await wait(.seconds(30), until: { receivedCommandComma }) else {
            return XCTFail("No physical Command-comma was delivered while paused")
        }
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertTrue(app.lifecyclePaused)
        XCTAssertFalse(NSApplication.shared.windows.contains { $0.isVisible && ($0.title == "Settings" || $0.title == "设置") })

        app.setActivityPaused(false)
        guard try await wait(.seconds(12), until: { !app.lifecyclePaused }) else {
            return XCTFail("The real app-server did not restore the active shortcut")
        }
    }

    private func containsText(_ expected: String, in view: NSView?) -> Bool {
        guard let view, !view.isHiddenOrHasHiddenAncestor else { return false }
        if (view as? NSTextField)?.stringValue == expected { return true }
        return view.subviews.contains { containsText(expected, in: $0) }
    }
    #endif
}
#endif
