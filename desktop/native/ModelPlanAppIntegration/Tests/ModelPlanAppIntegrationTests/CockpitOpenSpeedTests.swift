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

    private final class OpenProbe {
        typealias Render = (at: ContinuousClock.Instant, frame: CGRect, rootHeight: CGFloat?)
        var made: [CockpitWindowController] = []
        var rendered: [ObjectIdentifier: [Render]] = [:]
        var layouts: [ObjectIdentifier: [String]] = [:]
        var trace: [(step: String, at: ContinuousClock.Instant)] = []
        var log: [String] = []
        var timing: [(line: String, at: ContinuousClock.Instant)] = []
        func timed(_ prefix: String, after: ContinuousClock.Instant) -> String? {
            timing.first { $0.line.hasPrefix(prefix) && $0.at > after }?.line
        }
        func traced(_ step: String, after: ContinuousClock.Instant) -> ContinuousClock.Instant? {
            trace.first { $0.step == step && $0.at > after }?.at
        }
        func renders(_ page: CockpitWindowController, after: ContinuousClock.Instant) -> [Render] {
            (rendered[ObjectIdentifier(page)] ?? []).filter { $0.at > after }
        }
    }

    /// One launch of the normal entry on the real page and CLI, then three opens. With `prewarm` it asserts
    /// the CKP-SHELL-20 open; without, it only reports the open as it was before.
    @MainActor private func measureLaunch(prewarm: Bool, root: URL, official: URL, cli: URL) async throws {
        let label = prewarm ? "prewarm" : "baseline"
        let app = try Self.ownerTestShapedApp(at: root.appendingPathComponent("package"), helper: cli, ownerTest: true, official: official)
        let helper = app.appendingPathComponent("Contents/Helpers/modelplan")
        let environment = try await Self.syntheticHome(root, helper: helper)
        let probe = OpenProbe()
        let saved = (CommunityCockpitApplicationFactory.verificationPage, CommunityCockpitApplicationFactory.verificationCockpitTrace,
                     CommunityCockpitApplicationFactory.verificationConsoleNotice, CockpitFailureLog.verificationLine,
                     CommunityCockpitApplicationFactory.verificationPrewarm, CockpitTimingLog.verificationLine)
        CommunityCockpitApplicationFactory.verificationPrewarm = prewarm
        CommunityCockpitApplicationFactory.verificationCockpitTrace = { probe.trace.append((step: $0, at: ContinuousClock.now)) }
        // A failed open asks for a notice; record it instead of a modal alert.
        CommunityCockpitApplicationFactory.verificationConsoleNotice = { _ in probe.log.append("notice") }
        CockpitFailureLog.verificationLine = { probe.log.append($0) }
        CockpitTimingLog.verificationLine = { probe.timing.append((line: $0, at: ContinuousClock.now)) }
        CommunityCockpitApplicationFactory.verificationPage = { [weak probe] page in
            let id = ObjectIdentifier(page)
            probe?.made.append(page)
            // At launch a busy WebKit process can answer the hidden state late; the first hidden page must survive it.
            if prewarm, probe?.made.count == 1 { page.verificationHoldHiddenVisibilityReceipt = true }
            let built = ContinuousClock.now
            page.verificationWarmPainted = { [weak probe] painted in
                probe?.log.append("warmPaint painted=\(painted) sinceBuiltMs=\(Self.ms(built))")
            }
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
            CommunityCockpitApplicationFactory.verificationPage = saved.0
            CommunityCockpitApplicationFactory.verificationCockpitTrace = saved.1
            CommunityCockpitApplicationFactory.verificationConsoleNotice = saved.2
            CockpitFailureLog.verificationLine = saved.3
            CommunityCockpitApplicationFactory.verificationPrewarm = saved.4
            CockpitTimingLog.verificationLine = saved.5
        }
        func kib(_ sample: [Int32: Int]) -> Int { sample.values.filter { $0 > 0 }.reduce(0, +) }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root.appendingPathComponent("support"), preferredLanguages: ["en"])
        let memoryAtLaunch = Self.webKitFootprints()
        let entry = EngineRowsEntry.make(configuration: .init(executableURL: helper, applicationVersion: "synthetic-g3-42",
            allowedEnvironment: environment, offline: true, readOnly: true), settingsStore: settings,
            createsNativePanels: false, bundleURL: app, cockpitEntryEnabled: true)
        let launch = ContinuousClock.now
        await entry.prepare()
        await entry.composition.start()
        defer {
            print("G3-42-LOG \(label) " + probe.log.joined(separator: " | "))
            print("G3-42-TIMINGLOG \(label) " + probe.timing.map(\.line).joined(separator: " | "))
        }
        do {
            for _ in 0..<1500 where entry.composition.store.snapshot.delivery == nil { try await Task.sleep(for: .milliseconds(10)) }
            let session = try XCTUnwrap(entry.composition.store.snapshot.delivery != nil ? ContinuousClock.now : nil, "\(label): the engine session is up")
            var closedAt = launch
            if prewarm {
                // The hidden page is ready and the last reply is filled; a page that failed while hidden is replaced.
                func warmPage() -> CockpitWindowController? {
                    guard let page = probe.made.last, page.verificationWebView != nil, page.bridge.ready,
                          probe.traced("warm.reply", after: launch) != nil else { return nil }
                    return page
                }
                for _ in 0..<3000 where warmPage() == nil { try await Task.sleep(for: .milliseconds(10)) }
                let warm = try XCTUnwrap(warmPage(), "the app loads a hidden page after launch and fills the last reply without a click")
                // The first page of a process may still be painting once at alpha 0, ignoring the mouse.
                for _ in 0..<800 where warm.window?.isVisible == true { try await Task.sleep(for: .milliseconds(10)) }
                XCTAssertEqual(probe.made.filter { $0.verificationWebView != nil }.count, 1, "one hidden page")
                XCTAssertFalse(warm.window?.isVisible ?? true, "the hidden page is out of view once its warm paint ends")
                XCTAssertFalse(warm.window?.isKeyWindow ?? true, "and never takes focus")
                XCTAssertTrue(probe.renders(warm, after: launch).isEmpty, "nothing is rendered into a hidden page")
                // Past the 2 s visibility deadline: a late hidden-state receipt does not fail the hidden page.
                if let ready = probe.traced("warm.ready", after: launch), Self.ms(ready) < 2500 {
                    try await Task.sleep(for: .milliseconds(2500 - Self.ms(ready)))
                }
                XCTAssertFalse(probe.log.contains { $0.hasPrefix("page-failure") }, "the hidden page is not failed: \(probe.log)")
                XCTAssertTrue(probe.made.count == 1 && warm.verificationWebView != nil, "the first hidden page is kept, not rebuilt")
                XCTAssertNotNil(probe.timed("prewarm hidden-visibility-late", after: launch), "the late receipt is logged")
                XCTAssertNotNil(probe.timed("prewarm warm-paint painted=", after: launch), "the warm paint is logged")
                let memoryWarm = Self.webKitFootprints()
                print("G3-42-PREWARM sessionMs=\(Self.ms(launch, session)) launchToWarmReadyMs=\(probe.traced("warm.ready", after: launch).map { Self.ms(launch, $0) } ?? -1) "
                    + "launchToLastReplyMs=\(probe.traced("warm.reply", after: launch).map { Self.ms(launch, $0) } ?? -1) "
                    + "hiddenPagesBuilt=\(probe.made.count) webKitFootprintKiB atLaunch=\(kib(memoryAtLaunch)) warm=\(kib(memoryWarm)) "
                    + "newWebKitProcesses=\(Set(memoryWarm.keys).subtracting(memoryAtLaunch.keys).count)")
            } else {
                try await Task.sleep(for: .seconds(3))
            }
            for run in 1...3 {
                if prewarm, run > 1 {
                    for _ in 0..<3000 where probe.traced("warm.ready", after: closedAt) == nil { try await Task.sleep(for: .milliseconds(10)) }
                    let ready = try XCTUnwrap(probe.traced("warm.ready", after: closedAt), "run \(run): an empty page is loaded again after the close")
                    // A page rebuilt after a close is warm-painted too, out of view; the click comes after that.
                    for _ in 0..<800 where probe.timed("prewarm warm-paint", after: closedAt) == nil { try await Task.sleep(for: .milliseconds(10)) }
                    let painted = try XCTUnwrap(probe.timed("prewarm warm-paint", after: closedAt), "run \(run): the rebuilt page is warm-painted")
                    XCTAssertTrue(painted.hasPrefix("prewarm warm-paint painted=true"), "run \(run): \(painted)")
                    XCTAssertFalse(probe.made.last?.window?.isVisible ?? true, "run \(run): and out of view again")
                    print("G3-42-REWARM run=\(run) closeToWarmReadyMs=\(Self.ms(closedAt, ready)) \(painted) webKitFootprintKiB=\(kib(Self.webKitFootprints()))")
                    try await Task.sleep(for: .milliseconds(300))
                } else if run > 1 {
                    try await Task.sleep(for: .seconds(2))
                }
                let pagesBefore = probe.made.count
                let click = ContinuousClock.now
                entry.showConsole()
                func shown() -> CockpitWindowController? { prewarm ? probe.made.last : (probe.made.count > pagesBefore ? probe.made.last : nil) }
                for _ in 0..<5000 {
                    if let page = shown(), probe.renders(page, after: click).count >= 2 || page.verificationWebView == nil { break }
                    try await Task.sleep(for: .milliseconds(2))
                }
                let page = try XCTUnwrap(shown(), "\(label) run \(run): the click shows a page")
                let renders = probe.renders(page, after: click)
                let lastShown = probe.traced("display.last", after: click), fresh = probe.traced("query.reply", after: click)
                func at(_ value: ContinuousClock.Instant?) -> Int { value.map { Self.ms(click, $0) } ?? -1 }
                let queryStart = ContinuousClock.now
                let queried = (try? await entry.composition.client.cockpit(timeout: .seconds(10))) != nil
                let query = queried ? Self.ms(queryStart) : -1
                print("G3-42-STAGES \(label) run=\(run) pageBuiltByClick=\(probe.made.count > pagesBefore) "
                    + "pageReadyMs=\(at(probe.traced("page.ready", after: click))) shownMs=\(at(probe.traced("page.shown", after: click))) "
                    + "lastReplyShownMs=\(at(lastShown)) firstDataMs=\(at(renders.first?.at)) freshReplyMs=\(at(fresh)) "
                    + "freshRenderedMs=\(at(renders.count > 1 ? renders[1].at : nil)) queryAloneMs=\(query) "
                    + "pageAlive=\(page.verificationWebView != nil) webKitFootprintKiB=\(kib(Self.webKitFootprints()))")
                if prewarm {
                    XCTAssertEqual(probe.made.count, pagesBefore, "run \(run): the click shows the prewarmed page and builds none")
                    XCTAssertNotNil(probe.traced("open.warm", after: click), "run \(run)")
                    // The packaged build's own record of the same open, measured from the click in the console.
                    XCTAssertNotNil(probe.timed("open page=warm-ready", after: click), "run \(run): \(probe.timing.map(\.line))")
                    let rendered = try XCTUnwrap(probe.timed("open rendered n=1 clickMs=", after: click), "run \(run)")
                    XCTAssertLessThan(try XCTUnwrap(Int(rendered.split(separator: "=").last ?? "")), 800, "run \(run): \(rendered)")
                    let first = try XCTUnwrap(renders.first?.at, "run \(run): the shown page renders data")
                    XCTAssertLessThan(Self.ms(click, first), 800, "run \(run): a click shows the cockpit with data without a WebKit cold start")
                    let shownLast = try XCTUnwrap(lastShown, "run \(run): the last reply is shown first")
                    let freshReply = try XCTUnwrap(fresh, "run \(run): a fresh reply follows")
                    XCTAssertLessThan(shownLast, freshReply, "run \(run)")
                    // A fresh reply that arrives before the last one has rendered replaces it; either way the
                    // last render follows the fresh reply.
                    XCTAssertGreaterThanOrEqual(try XCTUnwrap(renders.last?.at), freshReply, "run \(run): the fresh reply is rendered")
                    if renders.count >= 2 {
                        XCTAssertEqual(renders[0].frame, renders[1].frame, "run \(run): the window does not move or resize")
                        XCTAssertEqual(renders[0].rootHeight, renders[1].rootHeight, "run \(run)")
                    }
                    for _ in 0..<200 where (probe.layouts[ObjectIdentifier(page)]?.count ?? 0) < 2 { try await Task.sleep(for: .milliseconds(10)) }
                    let layouts = probe.layouts[ObjectIdentifier(page)] ?? []
                    if layouts.count >= 2 { XCTAssertEqual(layouts[0], layouts[1], "run \(run): fresh data causes no layout jump") }
                }
                if page.verificationWebView != nil {
                    page.requestClose()
                    for _ in 0..<300 where page.verificationWebView != nil { try await Task.sleep(for: .milliseconds(10)) }
                }
                XCTAssertNil(page.verificationWebView, "\(label) run \(run): the user close discards the shown page")
                closedAt = .now
            }
            if prewarm {
                // As the packaged walkthrough does: open again soon after a close, while the next page may still load.
                try await Task.sleep(for: .milliseconds(1000))
                let pagesBefore = probe.made.count, click = ContinuousClock.now
                entry.showConsole()
                for _ in 0..<5000 {
                    if let page = probe.made.last, !probe.renders(page, after: click).isEmpty || page.verificationWebView == nil { break }
                    try await Task.sleep(for: .milliseconds(2))
                }
                let page = try XCTUnwrap(probe.made.last)
                print("G3-42-SOON pageBuiltByClick=\(probe.made.count > pagesBefore) "
                    + probe.timing.filter { $0.at > click }.map(\.line).joined(separator: " | "))
                XCTAssertFalse(probe.renders(page, after: click).isEmpty, "an open soon after a close still shows data")
                page.requestClose()
                for _ in 0..<300 where page.verificationWebView != nil { try await Task.sleep(for: .milliseconds(10)) }
                closedAt = .now
                for _ in 0..<3000 where probe.traced("warm.ready", after: closedAt) == nil { try await Task.sleep(for: .milliseconds(10)) }
                print("G3-42-IDLE webKitFootprintKiB=\(kib(Self.webKitFootprints())) pagesBuilt=\(probe.made.count)")
            }
        } catch {
            await entry.composition.stop()
            throw error
        }
        await entry.composition.stop()
    }

    /// CKP-SHELL-20 (owner D50): after launch the app loads one hidden, empty page and fills the last reply;
    /// a click shows that page and the last reply at once, then the fresh reply replaces it without a layout
    /// change, and after each close an empty page is loaded again. The prewarmed launch runs first, while this
    /// test process has not started WebKit, so its hidden page pays the cold start. The 800 ms bound is loose
    /// for a hosted runner and still far below a WebKit cold start (about 3.3 s there). The second launch,
    /// without prewarm, reports the open as it was before.
    @MainActor func testG3_42ClickToFirstDataStagesAtTheNormalEntry() async throws {
        let official = Self.repoRoot().appendingPathComponent("desktop/cockpit/.tmp/official")
        guard let path = ProcessInfo.processInfo.environment["MODELPLAN_U11_TEST_CLI"],
              FileManager.default.isExecutableFile(atPath: path),
              FileManager.default.fileExists(atPath: official.appendingPathComponent("bundle-manifest.json").path) else {
            throw XCTSkip("The real page needs the canonical official cockpit and the synthetic-test CLI")
        }
        for prewarm in [true, false] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("g3-42-stages-" + UUID().uuidString).resolvingSymlinksInPath()
            defer { try? FileManager.default.removeItem(at: root) }
            // The baseline still runs when the prewarmed launch fails, so both are reported.
            do { try await measureLaunch(prewarm: prewarm, root: root, official: official, cli: URL(fileURLWithPath: path)) }
            catch { XCTFail("\(prewarm ? "prewarm" : "baseline") launch stopped: \(error)") }
        }
    }
}
#endif
