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
    private static func syntheticHome(_ root: URL, helper: URL) async throws -> [String: String] {
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

    /// CKP-SHELL-20: after launch the app loads one hidden, empty page and fills the last reply; a click
    /// shows that page and the last reply at once, then the fresh reply replaces it without a layout change.
    /// After each close an empty page is loaded again. Three opens of one launch, and the memory it costs.
    /// The 800 ms bound is loose for a hosted runner and still far below a WebKit cold start (about 3.3 s there).
    @MainActor func testG3_42ClickToFirstDataStagesAtTheNormalEntry() async throws {
        let official = Self.repoRoot().appendingPathComponent("desktop/cockpit/.tmp/official")
        guard let path = ProcessInfo.processInfo.environment["MODELPLAN_U11_TEST_CLI"],
              FileManager.default.isExecutableFile(atPath: path),
              FileManager.default.fileExists(atPath: official.appendingPathComponent("bundle-manifest.json").path) else {
            throw XCTSkip("The real page needs the canonical official cockpit and the synthetic-test CLI")
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("g3-42-stages-" + UUID().uuidString).resolvingSymlinksInPath()
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try Self.ownerTestShapedApp(at: root.appendingPathComponent("package"), helper: URL(fileURLWithPath: path), ownerTest: true, official: official)
        let helper = app.appendingPathComponent("Contents/Helpers/modelplan")
        let environment = try await Self.syntheticHome(root, helper: helper)

        final class Probe {
            var made: [CockpitWindowController] = []
            var rendered: [ObjectIdentifier: [(at: ContinuousClock.Instant, frame: CGRect, rootHeight: CGFloat?)]] = [:]
            var layouts: [ObjectIdentifier: [String]] = [:]
            var trace: [(step: String, at: ContinuousClock.Instant)] = []
            func traced(_ step: String, after: ContinuousClock.Instant) -> ContinuousClock.Instant? {
                trace.first { $0.step == step && $0.at > after }?.at
            }
            func renders(_ page: CockpitWindowController, after: ContinuousClock.Instant) -> [(at: ContinuousClock.Instant, frame: CGRect, rootHeight: CGFloat?)] {
                (rendered[ObjectIdentifier(page)] ?? []).filter { $0.at > after }
            }
        }
        let probe = Probe()
        let previousPage = CommunityCockpitApplicationFactory.verificationPage
        let previousTrace = CommunityCockpitApplicationFactory.verificationCockpitTrace
        CommunityCockpitApplicationFactory.verificationCockpitTrace = { probe.trace.append((step: $0, at: ContinuousClock.now)) }
        CommunityCockpitApplicationFactory.verificationPage = { [weak probe] page in
            let id = ObjectIdentifier(page)
            probe?.made.append(page)
            page.onRendered = { [weak page, weak probe] in
                guard let page, let probe else { return }
                probe.rendered[id, default: []].append((at: ContinuousClock.now, frame: page.window?.frame ?? .zero, rootHeight: page.verificationRootHeight))
                // Read in order with the page's own messages, so each read sees the render it follows.
                Task { @MainActor in
                    let layout = try? await page.verificationWebView?.evaluateJavaScript("""
                        [...document.querySelectorAll('#cockpit > *')].map(e=>{const r=e.getBoundingClientRect();
                        return [r.x,r.y,r.width,r.height].map(Math.round).join(',')}).join(';')
                        """) as? String
                    probe.layouts[id, default: []].append(layout ?? "unreadable")
                }
            }
        }
        defer {
            CommunityCockpitApplicationFactory.verificationPage = previousPage
            CommunityCockpitApplicationFactory.verificationCockpitTrace = previousTrace
        }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root.appendingPathComponent("support"), preferredLanguages: ["en"])
        let memoryAtLaunch = Self.webKitFootprints()
        let entry = EngineRowsEntry.make(configuration: .init(executableURL: helper, applicationVersion: "synthetic-g3-42",
            allowedEnvironment: environment, offline: true, readOnly: true), settingsStore: settings,
            createsNativePanels: false, bundleURL: app, cockpitEntryEnabled: true)
        let launch = ContinuousClock.now
        await entry.prepare()
        await entry.composition.start()
        do {
            for _ in 0..<3000 where probe.traced("warm.reply", after: launch) == nil { try await Task.sleep(for: .milliseconds(10)) }
            let warmReady = try XCTUnwrap(probe.traced("warm.ready", after: launch), "the app loads a hidden page after launch")
            let warmReply = try XCTUnwrap(probe.traced("warm.reply", after: launch), "and fills the last reply without a click")
            let warm = try XCTUnwrap(probe.made.last)
            XCTAssertEqual(probe.made.filter { $0.verificationWebView != nil }.count, 1, "one hidden page")
            XCTAssertFalse(warm.window?.isVisible ?? true, "the hidden page is never ordered front")
            XCTAssertFalse(warm.window?.isKeyWindow ?? true, "and never takes focus")
            XCTAssertTrue(probe.renders(warm, after: launch).isEmpty, "nothing is rendered into a hidden page")
            let memoryWarm = Self.webKitFootprints()
            func kib(_ sample: [Int32: Int]) -> Int { sample.values.filter { $0 > 0 }.reduce(0, +) }
            print("G3-42-PREWARM launchToWarmReadyMs=\(Self.ms(launch, warmReady)) launchToLastReplyMs=\(Self.ms(launch, warmReply)) "
                + "webKitFootprintKiB atLaunch=\(kib(memoryAtLaunch)) warm=\(kib(memoryWarm)) "
                + "newProcesses=\(Set(memoryWarm.keys).subtracting(memoryAtLaunch.keys).count)")
            var closedAt = warmReady
            for run in 1...3 {
                if run > 1 {
                    for _ in 0..<3000 where probe.traced("warm.ready", after: closedAt) == nil { try await Task.sleep(for: .milliseconds(10)) }
                    let ready = try XCTUnwrap(probe.traced("warm.ready", after: closedAt), "run \(run): an empty page is loaded again after the close")
                    print("G3-42-REWARM run=\(run) closeToWarmReadyMs=\(Self.ms(closedAt, ready)) webKitFootprintKiB=\(kib(Self.webKitFootprints()))")
                    try await Task.sleep(for: .milliseconds(300))
                }
                let pagesBefore = probe.made.count
                let page = try XCTUnwrap(probe.made.last)
                let click = ContinuousClock.now
                entry.showConsole()
                for _ in 0..<3000 where probe.renders(page, after: click).count < 2 { try await Task.sleep(for: .milliseconds(2)) }
                let renders = probe.renders(page, after: click)
                XCTAssertEqual(probe.made.count, pagesBefore, "run \(run): the click shows the prewarmed page and builds none")
                XCTAssertNotNil(probe.traced("open.warm", after: click), "run \(run)")
                let first = try XCTUnwrap(renders.first, "run \(run): the shown page renders data").at
                let lastShown = try XCTUnwrap(probe.traced("display.last", after: click), "run \(run): the last reply is shown first")
                let fresh = try XCTUnwrap(probe.traced("query.reply", after: click), "run \(run): a fresh reply follows")
                XCTAssertLessThan(lastShown, fresh, "run \(run)")
                XCTAssertGreaterThanOrEqual(renders.count, 2, "run \(run): the fresh reply is rendered too")
                if renders.count >= 2 {
                    XCTAssertEqual(renders[0].frame, renders[1].frame, "run \(run): the window does not move or resize")
                    XCTAssertEqual(renders[0].rootHeight, renders[1].rootHeight, "run \(run)")
                }
                for _ in 0..<200 where (probe.layouts[ObjectIdentifier(page)]?.count ?? 0) < 2 { try await Task.sleep(for: .milliseconds(10)) }
                let layouts = probe.layouts[ObjectIdentifier(page)] ?? []
                if layouts.count >= 2 { XCTAssertEqual(layouts[0], layouts[1], "run \(run): fresh data causes no layout jump") }
                XCTAssertFalse(probe.trace.contains { $0.at > click && $0.step.hasPrefix("open.cold") }, "run \(run)")
                let queryStart = ContinuousClock.now
                _ = try await entry.composition.client.cockpit(timeout: .seconds(10))
                let query = Self.ms(queryStart)
                print("G3-42-STAGES run=\(run) shownMs=\(probe.traced("page.shown", after: click).map { Self.ms(click, $0) } ?? -1) "
                    + "lastReplyShownMs=\(Self.ms(click, lastShown)) firstDataMs=\(Self.ms(click, first)) "
                    + "freshReplyMs=\(Self.ms(click, fresh)) freshRenderedMs=\(renders.count > 1 ? Self.ms(click, renders[1].at) : -1) "
                    + "queryAloneMs=\(query) webKitFootprintKiB=\(kib(Self.webKitFootprints()))")
                XCTAssertLessThan(Self.ms(click, first), 800, "run \(run): a click shows the cockpit with data without a WebKit cold start")
                page.requestClose()
                for _ in 0..<300 where page.verificationWebView != nil { try await Task.sleep(for: .milliseconds(10)) }
                XCTAssertNil(page.verificationWebView, "run \(run): the user close discards the shown page")
                closedAt = .now
            }
            for _ in 0..<3000 where probe.traced("warm.ready", after: closedAt) == nil { try await Task.sleep(for: .milliseconds(10)) }
            print("G3-42-IDLE webKitFootprintKiB=\(kib(Self.webKitFootprints())) pages=\(probe.made.count)")
        } catch {
            await entry.composition.stop()
            throw error
        }
        await entry.composition.stop()
    }
}
#endif
