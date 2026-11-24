// SPDX-License-Identifier: MIT
import Darwin
import Foundation
import XCTest
import WebKit
import ModelPlanCockpitWeb
@testable import ModelPlanAppIntegration

#if MODELPLAN_TEST_ONLY_SPI
/// G3-42 / CKP-SHELL-20 (owner D50): a click on the cockpit must show it with data within a few hundred
/// milliseconds. These run the normal entry (`EngineRowsEntry.make` with `cockpitEntryEnabled: true`), the
/// production factory and console, the real CLI app-server on synthetic data and the real WKWebView page.
extension CommunityCockpitEntryTests {
    static func syntheticHome(_ root: URL, helper: URL) async throws -> [String: String] {
        let home = root.appendingPathComponent("home")
        try FileManager.default.createDirectory(at: home.appendingPathComponent("Library/Caches/modelplan/observed"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: home.appendingPathComponent(".codex"), withIntermediateDirectories: true)
        let environment = ["HOME": home.path, "TMPDIR": home.path, "PATH": "/usr/bin:/bin", "LANG": "C"]
        func command(_ arguments: [String], input: [String: Any]? = nil) async throws -> [String: Any] {
            let process = Process(), output = Pipe()
            process.executableURL = helper
            process.arguments = arguments
            process.environment = environment
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            let stdin = input.map { _ in Pipe() }
            process.standardInput = stdin ?? FileHandle.nullDevice
            try process.run()
            if let input, let stdin {
                try stdin.fileHandleForWriting.write(contentsOf: JSONSerialization.data(withJSONObject: input))
                try stdin.fileHandleForWriting.close()
            }
            let deadline = ContinuousClock.now + .seconds(5)
            while process.isRunning && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
            if process.isRunning { process.terminate(); throw CocoaError(.fileReadUnknown) }
            XCTAssertEqual(process.terminationStatus, 0, arguments.joined(separator: " "))
            return try XCTUnwrap(JSONSerialization.jsonObject(with: output.fileHandleForReading.readDataToEndOfFile()) as? [String: Any])
        }
        _ = try await command(["consent", "init", "--json"])
        let before = try await command(["consent", "--json"])
        _ = try await command(["consent", "grant", "--json"], input: [
            "requestId": UUID().uuidString.lowercased(), "expectStoreEpoch": try XCTUnwrap(before["storeEpoch"] as? String),
            "expectGeneration": try XCTUnwrap(before["generation"] as? Int),
            "consentTextVersion": try XCTUnwrap(before["consentTextVersion"] as? Int),
            "allow": ["codex.local_history"], "deny": [String]()
        ])
        return environment
    }
    /// One fresh Codex reading in the synthetic home, so the real CLI emits a Codex row on the "dock" surface and the
    /// cockpit has one subscription column. Without it the synthetic home has no reading, the producer drops "dock"
    /// (G3-38, D76) and the real page shows the CKP-ENG-57 empty engine, which draws no table and so no plugin column.
    /// The record has the shape `testG313RealCLIRecoversRetainedWeeklyCard` uses.
    static func seedCodexSubscription(_ root: URL) throws {
        let day = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: Date())
        let sessions = root.appendingPathComponent(String(format: "home/.codex/sessions/%04d/%02d/%02d", day.year!, day.month!, day.day!), isDirectory: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        let value: [String: Any] = ["timestamp": ISO8601DateFormatter().string(from: Date().addingTimeInterval(-60)), "type": "event_msg",
            "payload": ["type": "token_count", "rate_limits": ["limit_id": "codex", "plan_type": "plus",
                "primary": ["used_percent": 30, "window_minutes": 10080,
                            "resets_at": Int(Date().addingTimeInterval(86400).timeIntervalSince1970)]]]]
        var data = try JSONSerialization.data(withJSONObject: value)
        data.append(0x0a)
        try data.write(to: sessions.appendingPathComponent("rollout-synthetic-plugins.jsonl"))
    }
    /// CKP-ENG-57: the real page draws its engine table (and so any plugin column) only with a subscription column.
    static let engineDrawnScript = "document.getElementById('cockpit')?.dataset.engineEmpty==='false'"

    /// Resident memory of the WebKit helper processes, in KiB, by process. RSS counts shared pages, so
    /// differences between two samples are the useful number, not the totals.
    static func webKitMemory() -> [Int32: Int] {
        let process = Process(), output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,rss=,comm="]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return [:] }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        var result: [Int32: Int] = [:]
        for line in String(decoding: data, as: UTF8.self).split(separator: "\n") where line.contains("com.apple.WebKit.") {
            let fields = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            if fields.count == 3, let pid = Int32(fields[0]), let rss = Int(fields[1]) { result[pid] = rss }
        }
        return result
    }

    /// Physical footprint (what Activity Monitor calls Memory) of one process, in KiB.
    static func footprintKiB(_ pid: Int32) -> Int {
        var usage = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &usage) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V4, $0) }
        }
        return result == 0 ? Int(usage.ri_phys_footprint / 1024) : -1
    }
    /// WebKit helper processes by pid, with their footprint in KiB.
    static func webKitFootprints() -> [Int32: Int] {
        Dictionary(uniqueKeysWithValues: webKitMemory().keys.map { ($0, footprintKiB($0)) })
    }
    private static func ms(_ start: ContinuousClock.Instant, _ end: ContinuousClock.Instant = .now) -> Int {
        let (seconds, attoseconds) = (end - start).components
        return Int(seconds) * 1000 + Int(attoseconds / 1_000_000_000_000_000)
    }

    private final class OpenProbe {
        var pages: [CockpitWindowController] = []
        var rendered: [ObjectIdentifier: ContinuousClock.Instant] = [:]
        var trace: [(step: String, at: ContinuousClock.Instant)] = []
        var failures: [String] = []
        var timing: [(line: String, at: ContinuousClock.Instant)] = []
        func traced(_ step: String, after: ContinuousClock.Instant) -> ContinuousClock.Instant? {
            trace.first { $0.step == step && $0.at > after }?.at
        }
    }

    /// Launch the actual entry with an admitted CLI and official bundle, then open
    /// a new WebView on each click. Capture click-to-data and check the shell stages.
    @MainActor private func measureOnDemand(root: URL, official: URL, cli: URL, cycles: Int, checkShellBudget: Bool) async throws {
        _ = NSApplication.shared
        let app = try Self.ownerTestShapedApp(at: root.appendingPathComponent("package"), helper: cli, ownerTest: true, official: official)
        let helper = app.appendingPathComponent("Contents/Helpers/modelplan")
        let environment = try await Self.syntheticHome(root, helper: helper)
        try Self.seedCodexSubscription(root)
        let settings = try await completedOnboarding(try EngineRowsEntry.makeSettingsStore(
            applicationSupport: root.appendingPathComponent("support"), preferredLanguages: ["en"]))
        let probe = OpenProbe()
        let saved = (CommunityCockpitApplicationFactory.verificationPage, CommunityCockpitApplicationFactory.verificationCockpitTrace,
                     CommunityCockpitApplicationFactory.verificationConsoleNotice, CockpitFailureLog.verificationLine, CockpitTimingLog.verificationLine)
        CommunityCockpitApplicationFactory.verificationCockpitTrace = { probe.trace.append(($0, .now)) }
        CommunityCockpitApplicationFactory.verificationConsoleNotice = { _ in probe.failures.append("notice") }
        CockpitFailureLog.verificationLine = { probe.failures.append($0) }
        CockpitTimingLog.verificationLine = { probe.timing.append(($0, .now)) }
        CommunityCockpitApplicationFactory.verificationPage = { [weak probe] page in
            probe?.pages.append(page)
            let id = ObjectIdentifier(page)
            page.onRendered = { [weak probe] in
                guard let probe, probe.rendered[id] == nil else { return }
                probe.rendered[id] = .now
            }
        }
        defer {
            CommunityCockpitApplicationFactory.verificationPage = saved.0
            CommunityCockpitApplicationFactory.verificationCockpitTrace = saved.1
            CommunityCockpitApplicationFactory.verificationConsoleNotice = saved.2
            CockpitFailureLog.verificationLine = saved.3
            CockpitTimingLog.verificationLine = saved.4
            print("G3-42-TIMINGLOG " + probe.timing.map(\.line).joined(separator: " | "))
        }
        let entry = EngineRowsEntry.make(configuration: .init(executableURL: helper, applicationVersion: "synthetic-g3-42",
            allowedEnvironment: environment, offline: true, readOnly: true), settingsStore: settings,
            createsNativePanels: false, bundleURL: app, cockpitEntryEnabled: true)
        do {
            await entry.prepare()
            await entry.composition.start()
            for _ in 0..<1500 where entry.composition.store.snapshot.delivery == nil {
                try await Task.sleep(for: .milliseconds(10))
            }
            XCTAssertNotNil(entry.composition.store.snapshot.delivery, "the engine session is up")
            try await Task.sleep(for: .milliseconds(300))
            XCTAssertTrue(probe.pages.isEmpty, "launch prepares the bundle without building an idle page")
            for cycle in 1...cycles {
                let pagesBefore = probe.pages.count
                let click = ContinuousClock.now
                entry.showConsole()
                let deadline = click + .seconds(15)
                var dataAt: ContinuousClock.Instant?
                while ContinuousClock.now < deadline && dataAt == nil {
                    if probe.pages.count > pagesBefore, let page = probe.pages.last,
                       probe.rendered[ObjectIdentifier(page)] != nil,
                       let web = page.verificationWebView,
                       (try? await web.evaluateJavaScript(Self.engineDrawnScript)) as? Bool == true {
                        dataAt = .now
                    } else { try await Task.sleep(for: .milliseconds(10)) }
                }
                let shown = try XCTUnwrap(dataAt, "cycle \(cycle): no admitted data after the click; \(probe.failures)")
                let page = try XCTUnwrap(probe.pages.last)
                XCTAssertEqual(probe.pages.count, pagesBefore + 1, "one page per click")
                XCTAssertNotNil(probe.traced("open.cold", after: click))
                let fresh = try XCTUnwrap(probe.traced("query.reply", after: click))
                XCTAssertLessThanOrEqual(fresh, shown, "the real CLI reply precedes data on screen")
                print("G3-42-STAGES on-demand cycle=\(cycle) firstDataMs=\(Self.ms(click, shown)) freshReplyMs=\(Self.ms(click, fresh))")

                for _ in 0..<100 where !probe.timing.contains(where: { $0.at > click && $0.line.hasPrefix("open stage=animation-complete") }) {
                    try await Task.sleep(for: .milliseconds(10))
                }
                page.requestClose()
                for _ in 0..<500 where page.verificationWebView != nil || page.window != nil {
                    try await Task.sleep(for: .milliseconds(10))
                }
                XCTAssertNil(page.verificationWebView, "close disposes the WebView")
                XCTAssertNil(page.window, "close disposes the window")
                if checkShellBudget {
                    let lines = probe.timing.filter { $0.at > click }.map(\.line)
                    print("G3-123 cycle=\(cycle) " + lines.joined(separator: " | "))
                    func milliseconds(_ prefix: String) throws -> Int {
                        let line = try XCTUnwrap(lines.first { $0.hasPrefix(prefix) }, "cycle \(cycle): missing \(prefix)")
                        return try XCTUnwrap(Int(line.split(separator: "=").last ?? ""))
                    }
                    HostedRunnerTiming.enforce("G3-123 cycle \(cycle) open stage=window-visible ms", measured: Double(try milliseconds("open stage=window-visible")), atMost: 400)
                    HostedRunnerTiming.enforce("G3-123 cycle \(cycle) open stage=animation-complete ms", measured: Double(try milliseconds("open stage=animation-complete")), atMost: 800)
                    XCTAssertGreaterThanOrEqual(try milliseconds("open stage=page-rendered"), 0)
                    HostedRunnerTiming.enforce("G3-123 cycle \(cycle) close stage=gone ms", measured: Double(try milliseconds("close stage=gone")), atMost: 800)
                }
                try await Task.sleep(for: .milliseconds(300))
                XCTAssertEqual(probe.pages.count, pagesBefore + 1, "idle after close builds no replacement page")
            }
        } catch {
            probe.pages.last?.requestClose()
            await entry.composition.stop()
            throw error
        }
        await entry.composition.stop()
    }

    @MainActor private func checkOnDemandCycles(_ cycles: Int, checkShellBudget: Bool = false) async throws {
        let official = Self.repoRoot().appendingPathComponent("desktop/cockpit/.tmp/official")
        let environment = ProcessInfo.processInfo.environment
        guard let path = environment["MODELPLAN_U11_TEST_CLI"],
              FileManager.default.isExecutableFile(atPath: path),
              FileManager.default.fileExists(atPath: official.appendingPathComponent("bundle-manifest.json").path) else {
            if environment["MODELPLAN_U11_TEST_REQUIRED"] == "1" {
                XCTFail("U11 must supply the canonical official cockpit and real synthetic-test CLI")
                return
            }
            throw XCTSkip("The real page needs the canonical official cockpit and the synthetic-test CLI")
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("cockpit-on-demand-" + UUID().uuidString).resolvingSymlinksInPath()
        defer { try? FileManager.default.removeItem(at: root) }
        try await measureOnDemand(root: root, official: official, cli: URL(fileURLWithPath: path),
                                  cycles: cycles, checkShellBudget: checkShellBudget)
    }

    @MainActor func testG3_42ClickToFirstDataStagesAtTheNormalEntry() async throws {
        try await checkOnDemandCycles(3)
    }

    @MainActor func testG3_123OpenCloseBudgetTenNormalEntryCycles() async throws {
        try await checkOnDemandCycles(10, checkShellBudget: true)
    }
}
#endif
