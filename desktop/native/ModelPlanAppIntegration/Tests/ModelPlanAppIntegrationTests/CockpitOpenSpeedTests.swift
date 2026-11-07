// SPDX-License-Identifier: MIT
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

    private static func ms(_ start: ContinuousClock.Instant, _ end: ContinuousClock.Instant = .now) -> Int {
        let (seconds, attoseconds) = (end - start).components
        return Int(seconds) * 1000 + Int(attoseconds / 1_000_000_000_000_000)
    }

    /// Splits click to first data on the page into stages, for three opens of one launch. The first open is
    /// the first WebKit use of this test process. Stages, all from the click:
    /// - `navStartMs`: the page's `performance.timeOrigin`, so the web view, its WebKit processes and the
    ///   navigation start; `firstFileMs`: the first file the bundle scheme served.
    /// - `pageLoadMs`: the page's load event (HTML, module scripts, styles).
    /// - `bridgeReadyMs`: the page's `ready` reply after the native `load` message.
    /// - `firstDataMs`: the page's `rendered` reply for the first data it displayed.
    /// - `queryMs`: one more cockpit query on the same client, timed alone after the page is shown.
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
            var made: [(page: CockpitWindowController, at: ContinuousClock.Instant)] = []
            var firstFile: [ObjectIdentifier: ContinuousClock.Instant] = [:]
            var rendered: [ObjectIdentifier: [ContinuousClock.Instant]] = [:]
        }
        let probe = Probe()
        let previous = CommunityCockpitApplicationFactory.verificationPage
        CommunityCockpitApplicationFactory.verificationPage = { page in
            let id = ObjectIdentifier(page)
            probe.made.append((page, .now))
            page.verificationResource = { _ in if probe.firstFile[id] == nil { probe.firstFile[id] = .now } }
            page.onRendered = { probe.rendered[id, default: []].append(.now) }
        }
        defer { CommunityCockpitApplicationFactory.verificationPage = previous }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root.appendingPathComponent("support"), preferredLanguages: ["en"])
        let memoryAtLaunch = Self.webKitMemory()
        let entry = EngineRowsEntry.make(configuration: .init(executableURL: helper, applicationVersion: "synthetic-g3-42",
            allowedEnvironment: environment, offline: true, readOnly: true), settingsStore: settings,
            createsNativePanels: false, bundleURL: app, cockpitEntryEnabled: true)
        let launch = ContinuousClock.now
        await entry.prepare()
        await entry.composition.start()
        do {
            for _ in 0..<1000 where entry.composition.store.snapshot.delivery == nil { try await Task.sleep(for: .milliseconds(10)) }
            XCTAssertNotNil(entry.composition.store.snapshot.delivery, "the engine session is up before the first click")
            // A user clicks some seconds after launch; the app may use that time.
            try await Task.sleep(for: .seconds(6))
            print("G3-42-LAUNCH engineReadyToSettledMs=\(Self.ms(launch)) pagesBeforeClick=\(probe.made.count)")
            for run in 1...3 {
                let pagesBefore = probe.made.count
                let memoryBefore = Self.webKitMemory()
                let click = ContinuousClock.now
                let clickEpochMs = Date().timeIntervalSince1970 * 1000
                entry.showConsole()
                let deadline = ContinuousClock.now + .seconds(30)
                func shown() -> CockpitWindowController? { probe.made.last?.page }
                while ContinuousClock.now < deadline {
                    if let page = shown(), probe.rendered[ObjectIdentifier(page)]?.contains(where: { $0 > click }) == true { break }
                    try await Task.sleep(for: .milliseconds(2))
                }
                let page = try XCTUnwrap(shown(), "the click shows a page")
                let id = ObjectIdentifier(page)
                let firstData = try XCTUnwrap(probe.rendered[id]?.first(where: { $0 > click }), "the shown page renders data")
                let web = try XCTUnwrap(page.verificationWebView)
                let timing = try? await web.evaluateJavaScript("""
                    (()=>{const n=performance.getEntriesByType('navigation')[0];
                    return JSON.stringify({origin:performance.timeOrigin,load:n?n.loadEventEnd:-1})})()
                    """) as? String
                let values = (timing.flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) } as? [String: Double]) ?? [:]
                let navStart = values["origin"].map { Int($0 - clickEpochMs) } ?? -1
                let pageLoad = values["load"].flatMap { load in values["origin"].map { Int($0 + load - clickEpochMs) } } ?? -1
                let firstFile = probe.firstFile[id].map { $0 > click ? Self.ms(click, $0) : 0 } ?? -1
                let queryStart = ContinuousClock.now
                _ = try await entry.composition.client.cockpit(timeout: .seconds(10))
                let query = Self.ms(queryStart)
                let memoryOpen = Self.webKitMemory()
                let pageMadeByClick = probe.made.count > pagesBefore
                print("G3-42-STAGES run=\(run) pageMadeByClick=\(pageMadeByClick) navStartMs=\(navStart) firstFileMs=\(firstFile) "
                    + "pageLoadMs=\(pageLoad) firstDataMs=\(Self.ms(click, firstData)) queryMs=\(query) "
                    + "renders=\(probe.rendered[id]?.count ?? 0) webKitProcesses=\(memoryOpen.count) "
                    + "webKitRssKiB=\(memoryOpen.values.reduce(0, +)) beforeClickRssKiB=\(memoryBefore.values.reduce(0, +)) "
                    + "atLaunchRssKiB=\(memoryAtLaunch.values.reduce(0, +))")
                XCTAssertLessThan(Self.ms(click, firstData), 800, "run \(run): a click shows the cockpit with data without a WebKit cold start")
                page.requestClose()
                for _ in 0..<300 where page.verificationWebView != nil { try await Task.sleep(for: .milliseconds(10)) }
                XCTAssertNil(page.verificationWebView, "the user close discards the shown page")
                try await Task.sleep(for: .seconds(4))
            }
        } catch {
            await entry.composition.stop()
            throw error
        }
        await entry.composition.stop()
    }
}
#endif
