// SPDX-License-Identifier: MIT
import Darwin
import Foundation
import XCTest
import WebKit
import ModelPlanCockpitWeb
@testable import ModelPlanAppIntegration

#if MODELPLAN_TEST_ONLY_SPI
/// WP-17 (CKP-SHELL-19/53/54, G3-123): the automated cockpit measurement that replaces the manual Computer Use runs
/// (8 attempts gave 4 valid samples). It reports only: it writes the app's own timing lines and the idle CPU samples to
/// the directory named by MODELPLAN_PERF_OUT, and `desktop/native/tools/perf/perf_report.py` (through
/// `summarize_timing.py`) turns them into the JSON summary and the markdown table. The test fails only when a
/// measurement cannot be taken (fewer than 10 valid samples of a section, fewer than 60 idle seconds), never on a
/// budget. Without MODELPLAN_PERF_OUT (every ordinary run) it is skipped, so it never costs GUI time.
///
/// Same entry as the normal-entry tests: `EngineRowsEntry.make` with `cockpitEntryEnabled: true`, the production page
/// factory and console, the real CLI app-server on a synthetic home with one seeded Codex subscription, and the real
/// WKWebView page of the owner-test shaped package. Opens go through `showConsole()` (the entry the other G3-123
/// tests use; a status item is not created, so the icon rack entrance is not part of these numbers). Detached cycles
/// press the page's own detach key through `verificationDetach` after the first attached open.
extension CommunityCockpitEntryTests {
    private final class PerfProbe {
        var made: [CockpitWindowController] = []
        var renders: [ContinuousClock.Instant] = []
        var trace: [(step: String, at: ContinuousClock.Instant)] = []
        var timing: [(line: String, at: ContinuousClock.Instant)] = []
        func traced(_ step: String, after: ContinuousClock.Instant) -> ContinuousClock.Instant? {
            trace.first { $0.step == step && $0.at > after }?.at
        }
        func timed(_ prefix: String, after: ContinuousClock.Instant) -> String? {
            timing.first { $0.line.hasPrefix(prefix) && $0.at > after }?.line
        }
    }

    private static func perfMs(_ start: ContinuousClock.Instant, _ end: ContinuousClock.Instant = .now) -> Int {
        let (seconds, attoseconds) = (end - start).components
        return Int(seconds) * 1000 + Int(attoseconds / 1_000_000_000_000_000)
    }

    /// The production page factory with prewarm, observed. Returns the restore closure.
    @MainActor private static func perfHooks(_ probe: PerfProbe) -> () -> Void {
        let saved = (CommunityCockpitApplicationFactory.verificationPage, CommunityCockpitApplicationFactory.verificationCockpitTrace,
                     CommunityCockpitApplicationFactory.verificationConsoleNotice, CockpitFailureLog.verificationLine,
                     CommunityCockpitApplicationFactory.verificationPrewarm, CockpitTimingLog.verificationLine)
        CommunityCockpitApplicationFactory.verificationPrewarm = true
        CommunityCockpitApplicationFactory.verificationCockpitTrace = { probe.trace.append((step: $0, at: ContinuousClock.now)) }
        CommunityCockpitApplicationFactory.verificationConsoleNotice = { _ in }
        CockpitFailureLog.verificationLine = { _ in }
        // The hook receives the bare line; ModelPlan.log carries it after "timing ", the form summarize_timing.py reads.
        CockpitTimingLog.verificationLine = { probe.timing.append((line: $0, at: ContinuousClock.now)) }
        CommunityCockpitApplicationFactory.verificationPage = { [weak probe] page in
            probe?.made.append(page)
            page.onRendered = { [weak probe] in probe?.renders.append(ContinuousClock.now) }
        }
        return {
            CommunityCockpitApplicationFactory.verificationPage = saved.0
            CommunityCockpitApplicationFactory.verificationCockpitTrace = saved.1
            CommunityCockpitApplicationFactory.verificationConsoleNotice = saved.2
            CockpitFailureLog.verificationLine = saved.3
            CommunityCockpitApplicationFactory.verificationPrewarm = saved.4
            CockpitTimingLog.verificationLine = saved.5
        }
    }

    /// A fresh synthetic home with one Codex reading, a completed onboarding and the production entry on it.
    @MainActor private static func perfEntry(root: URL, app: URL, helper: URL) async throws -> (make: () -> EngineDockMenuApplication, environment: [String: String]) {
        let environment = try await Self.syntheticHome(root, helper: helper)
        try Self.seedCodexSubscription(root)
        let settings = try await completedOnboarding(try EngineRowsEntry.makeSettingsStore(applicationSupport: root.appendingPathComponent("support"), preferredLanguages: ["en"]))
        return ({
            EngineRowsEntry.make(configuration: .init(executableURL: helper, applicationVersion: "synthetic-wp17",
                allowedEnvironment: environment, offline: true, readOnly: true), settingsStore: settings,
                createsNativePanels: false, bundleURL: app, cockpitEntryEnabled: true)
        }, environment)
    }

    private static func perfWrite(_ lines: [String], _ name: String, in directory: URL) throws {
        try (lines.joined(separator: "\n") + "\n").write(to: directory.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    /// Closes a shown page the way a user close does and waits until it is gone.
    @MainActor private static func perfClose(_ page: CockpitWindowController, _ probe: PerfProbe) async throws {
        guard page.verificationWebView != nil else { return }
        page.requestClose()
        for _ in 0..<500 where page.verificationWebView != nil { try await Task.sleep(for: .milliseconds(10)) }
    }

    @MainActor func testWP17CockpitMeasurement() async throws {
        guard let outPath = ProcessInfo.processInfo.environment["MODELPLAN_PERF_OUT"], !outPath.isEmpty else {
            throw XCTSkip("WP-17 measurement runs only from desktop.yml with perf=true (MODELPLAN_PERF_OUT names the output directory)")
        }
        let official = Self.repoRoot().appendingPathComponent("desktop/cockpit/.tmp/official")
        let cliPath = try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_U11_TEST_CLI"], "the measurement needs the synthetic-test CLI")
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: cliPath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: official.appendingPathComponent("bundle-manifest.json").path), "the canonical official cockpit is built")
        let out = URL(fileURLWithPath: outPath, isDirectory: true)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let required = 10
        let package = FileManager.default.temporaryDirectory.appendingPathComponent("wp17-" + UUID().uuidString).resolvingSymlinksInPath()
        defer { try? FileManager.default.removeItem(at: package) }
        let app = try Self.ownerTestShapedApp(at: package.appendingPathComponent("package"), helper: URL(fileURLWithPath: cliPath), ownerTest: true, official: official)
        let helper = app.appendingPathComponent("Contents/Helpers/modelplan")
        _ = NSApplication.shared

        // 1. Cold start, N=10: a new entry (a new engine process and a new page) per run; the cockpit is opened right after
        // the launch, and the run ends when the engine table (the data) is on the page. The WebKit process pool is warm
        // after the first run, so run 1 is the true cold WebKit start; all runs are counted.
        var cold: [String] = [], coldValid = 0
        for run in 1...required {
            let root = package.appendingPathComponent("cold-\(run)")
            let probe = PerfProbe(), restore = Self.perfHooks(probe)
            defer { restore() }
            let setup = try await Self.perfEntry(root: root, app: app, helper: helper)
            let launch = ContinuousClock.now
            let entry = setup.make()
            await entry.prepare()
            await entry.composition.start()
            entry.showConsole()
            var handshake = -1, firstRender = -1, data = -1
            for _ in 0..<6000 where data < 0 {
                if handshake < 0, entry.composition.store.snapshot.delivery != nil { handshake = Self.perfMs(launch) }
                if firstRender < 0, let first = probe.renders.first, first > launch { firstRender = Self.perfMs(launch, first) }
                if let web = probe.made.last?.verificationWebView,
                   (try? await web.evaluateJavaScript(Self.engineDrawnScript)) as? Bool == true { data = Self.perfMs(launch) }
                try await Task.sleep(for: .milliseconds(5))
            }
            if firstRender < 0, let first = probe.renders.first(where: { $0 > launch }) { firstRender = Self.perfMs(launch, first) }
            print("WP17-COLD run=\(run) handshakeMs=\(handshake) firstRenderedMs=\(firstRender) firstRenderedWithDataMs=\(data)")
            if data >= 0 {
                coldValid += 1
                cold += ["timing launch stage=main uptimeMs=0 sinceStartMs=0",
                         "timing launch stage=engine-handshake uptimeMs=0 sinceStartMs=\(max(handshake, 0))",
                         "timing launch stage=first-rendered uptimeMs=0 sinceStartMs=\(firstRender >= 0 ? firstRender : data)",
                         "timing launch stage=first-rendered-with-data uptimeMs=0 sinceStartMs=\(data)"]
            }
            if let page = probe.made.last { try await Self.perfClose(page, probe) }
            await entry.composition.stop()
            try? FileManager.default.removeItem(at: root)
            try await Task.sleep(for: .seconds(1))
        }
        try Self.perfWrite(cold, "cold-start.log", in: out)
        XCTAssertEqual(coldValid, required, "cold start: \(coldValid) of \(required) runs reached first rendered data")

        // 2. One warm session for the open and close cycles and the idle CPU.
        let root = package.appendingPathComponent("warm")
        let probe = PerfProbe(), restore = Self.perfHooks(probe)
        defer { restore() }
        let setup = try await Self.perfEntry(root: root, app: app, helper: helper)
        let sessionStart = ContinuousClock.now
        let entry = setup.make()
        await entry.prepare()
        await entry.composition.start()
        for _ in 0..<1500 where entry.composition.store.snapshot.delivery == nil { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertNotNil(entry.composition.store.snapshot.delivery, "the engine session is up")
        var closedAt = sessionStart
        // The hidden prewarmed page is ready, as it is a few seconds after a real launch.
        for _ in 0..<3000 where probe.traced("warm.ready", after: sessionStart) == nil { try await Task.sleep(for: .milliseconds(10)) }
        try await Task.sleep(for: .seconds(3))

        // After a close the engine loads the next hidden page; a cycle starts once it is ready and has painted, plus 1.5 s.
        func settle() async throws {
            for _ in 0..<3000 where probe.traced("warm.ready", after: closedAt) == nil { try await Task.sleep(for: .milliseconds(10)) }
            for _ in 0..<800 where probe.timed("prewarm warm-paint", after: closedAt) == nil { try await Task.sleep(for: .milliseconds(10)) }
            try await Task.sleep(for: .milliseconds(1500))
        }
        /// One open (through the console entry), a hold of 1.5 s, one user close. Returns the cycle's timing lines (after the
        /// click), or nil when the cycle did not complete or the cockpit was not in the wanted attachment.
        func cycle(detached: Bool) async throws -> [String]? {
            try await settle()
            let click = ContinuousClock.now
            entry.showConsole()
            for _ in 0..<1500 where probe.timed("open stage=animation-complete", after: click) == nil { try await Task.sleep(for: .milliseconds(10)) }
            guard let page = probe.made.last, page.verificationWebView != nil else { return nil }
            try await Task.sleep(for: .milliseconds(1500))
            let attachmentOK = page.isAttached != detached
            try await Self.perfClose(page, probe)
            for _ in 0..<500 where probe.timed("close stage=gone", after: click) == nil { try await Task.sleep(for: .milliseconds(10)) }
            closedAt = .now
            let bare = probe.timing.filter { $0.at > click }.map(\.line)
            // A cycle counts only with the stages the report needs.
            let complete = ["open stage=window-visible", "open stage=animation-complete", "close stage=gone"].allSatisfy { stage in bare.contains { $0.hasPrefix(stage) } }
            return attachmentOK && complete && page.verificationWebView == nil ? bare.map { "timing " + $0 } : nil
        }
        func section(_ name: String, detached: Bool) async throws {
            _ = try await cycle(detached: detached) // the first open and close warms the page and does not count
            var lines: [String] = [], valid = 0
            var attempts = 0
            while valid < required, attempts < required + 5 {
                attempts += 1
                if let one = try await cycle(detached: detached) { valid += 1; lines += one }
            }
            try Self.perfWrite(lines, "\(name).log", in: out)
            print("WP17-SECTION \(name) valid=\(valid) attempts=\(attempts)")
            XCTAssertEqual(valid, required, "\(name): \(valid) of \(required) complete open/close cycles")
        }
        try await section("attached", detached: false)

        // Idle CPU, cockpit open and untouched for 60 s: this App, its WebContent and the GPU process, per second.
        try await settle()
        let idleClick = ContinuousClock.now
        entry.showConsole()
        for _ in 0..<1500 where probe.timed("open stage=animation-complete", after: idleClick) == nil { try await Task.sleep(for: .milliseconds(10)) }
        let idlePage = try XCTUnwrap(probe.made.last, "the cockpit is open for the idle measurement")
        let web = try XCTUnwrap(idlePage.verificationWebView)
        try await Task.sleep(for: .seconds(3))
        let processes = BudgetProcesses.of(web)
        var labelled: [(pid: pid_t, label: String)] = [(pid: processes.app, label: "app")]
        if let webPID = processes.web { labelled.append((pid: webPID, label: "webcontent")) }
        for gpuPID in processes.gpu { labelled.append((pid: gpuPID, label: "gpu")) }
        var idle: [String] = []
        var previous = labelled.map { ProcessSample.read($0.pid)?.cpuNanoseconds ?? 0 }, previousAt = DispatchTime.now().uptimeNanoseconds
        for second in 1...60 {
            try await Task.sleep(for: .seconds(1))
            let now = labelled.map { ProcessSample.read($0.pid)?.cpuNanoseconds ?? 0 }, nowAt = DispatchTime.now().uptimeNanoseconds
            for (index, item) in labelled.enumerated() {
                let used = now[index] > previous[index] ? now[index] - previous[index] : 0
                idle.append("\(second) \(item.pid) \(String(format: "%.2f", 100 * Double(used) / Double(nowAt - previousAt))) \(item.label)")
            }
            previous = now; previousAt = nowAt
        }
        try Self.perfWrite(idle, "idle-cpu.txt", in: out)
        XCTAssertNotNil(processes.web, "the page's WebContent process is attributable")
        try await Self.perfClose(idlePage, probe)
        closedAt = .now

        // Detached: open attached, press the page's detach key, close; the next opens are detached.
        try await settle()
        let detachClick = ContinuousClock.now
        entry.showConsole()
        for _ in 0..<1500 where probe.timed("open stage=animation-complete", after: detachClick) == nil { try await Task.sleep(for: .milliseconds(10)) }
        let detachPage = try XCTUnwrap(probe.made.last, "the cockpit is open to be detached")
        try await Task.sleep(for: .milliseconds(1500))
        detachPage.verificationDetach()
        for _ in 0..<500 where detachPage.isAttached { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(detachPage.isAttached, "the cockpit is detached")
        try await Task.sleep(for: .seconds(2))
        try await Self.perfClose(detachPage, probe)
        closedAt = .now
        try await section("detached", detached: true)
        await entry.composition.stop()
    }
}
#endif
