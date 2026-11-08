// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCockpitWeb
import ModelPlanWire
@testable import ModelPlanAppIntegration

#if MODELPLAN_TEST_ONLY_SPI
/// A synthetic page on the real bridge state: it reports what the app asks it to show and sends the
/// intents a person's clicks would send. No WebKit window.
@MainActor private final class ScopeDayPage: CockpitPageSurface {
    private let bridge: CockpitBridgeState
    var onReady: (() -> Void)?
    var onIntent: ((CockpitIntent) -> Void)?
    var onClosed: (() -> Void)?
    private(set) var data: WireCockpitData?
    private(set) var scopes: [String] = []
    var queryTicket: CockpitQueryTicket? { bridge.queryTicket }

    init(_ context: CockpitEngineContext) { bridge = .init(context: context) }

    func open() {
        do {
            let raw = try bridge.load(.init(theme: .night, locale: .en, profile: .full, redBelow: 25),
                shell: .init(closed: false, attached: true, forcedClosed: false, tier: .tall))
            var value = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
            value["appearance"] = nil
            value["shell"] = nil
            value["redBelow"] = nil
            value["type"] = "ready"
            value["sequence"] = "1"
            value["appearanceVersion"] = 2
            value["capabilities"] = ["appearanceUpdates", "shellState", "shellActions"]
            let message = String(decoding: try JSONSerialization.data(withJSONObject: value), as: UTF8.self)
            _ = try bridge.accept(message, source: .init(mainFrame: true, origin: "modelplan-cockpit://bundle"))
            onReady?()
        } catch { XCTFail("Synthetic page failed to become ready: \(error)") }
    }
    func updateScope(_ key: String) { scopes.append(key) }
    func display(_ data: WireCockpitData, ticket: CockpitQueryTicket) { self.data = data }
    func clearPrivateViews(adopting context: CockpitEngineContext?) async { data = nil; _ = try? bridge.clear(adopting: context) }
    private(set) var closed = false
    func discard() { closed = true; bridge.dispose(); onClosed?() }

    /// The engine key of the first displayed subscription, as the page names it: its verified reference,
    /// otherwise its row and route.
    var firstMemberKey: String? {
        guard let data, let row = data.projection.rows.first, let account = row.accounts.first else { return nil }
        let verified = Set(data.subscriptions.map(\.subscriptionRef))
        if let ref = account.subscriptionRef, verified.contains(ref) { return ref }
        return row.id + "#" + account.route.rawValue
    }
}

extension CommunityCockpitEntryTests {
    /// CKP-ENTRY-04 (C-35): through the normal entry and the real app-server, a scope chosen in the cockpit is
    /// still selected when it is opened again later that day, and the first open on the next day starts at All.
    /// The day comes from the app's own clock, which the test controls.
    @MainActor func testNormalEntryKeepsTheScopeForTheDayAndStartsTheNextDayAtAll() async throws {
        guard let path = ProcessInfo.processInfo.environment["MODELPLAN_U11_TEST_CLI"],
              FileManager.default.isExecutableFile(atPath: path) else {
            throw XCTSkip("The real synthetic-test CLI is not available")
        }
        let helper = URL(fileURLWithPath: path)
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("cockpit-scope-day-" + UUID().uuidString)
        let config = home.appendingPathComponent(".config/modelplan")
        try FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let environment = ["HOME": home.path, "TMPDIR": home.path, "PATH": "/usr/bin:/bin", "LANG": "C"]
        let seed = Process()
        seed.executableURL = helper
        seed.arguments = ["consent", "init", "--json"]
        seed.environment = environment
        seed.standardInput = FileHandle.nullDevice
        seed.standardOutput = FileHandle.nullDevice
        seed.standardError = FileHandle.nullDevice
        try seed.run()
        let seedDeadline = ContinuousClock.now + .seconds(5)
        while seed.isRunning && ContinuousClock.now < seedDeadline { try await Task.sleep(for: .milliseconds(10)) }
        if seed.isRunning { seed.terminate(); return XCTFail("Temporary consent initialization timed out") }
        XCTAssertEqual(seed.terminationStatus, 0)
        // The real producer reads local.json as declared quota, with no provider credentials or calls.
        let iso = ISO8601DateFormatter(), real = Date()
        let fixture: [String: Any] = ["schemaVersion": 1, "plans": [["planId": "synthetic-scope-day"]], "windows": [[
            "planId": "synthetic-scope-day", "kind": "five_hour", "remainingPercent": 61, "resetMode": "rolling",
            "observedAt": iso.string(from: real.addingTimeInterval(-15)), "resetAt": iso.string(from: real.addingTimeInterval(7_200))
        ]]]
        try JSONSerialization.data(withJSONObject: fixture).write(to: config.appendingPathComponent("local.json"), options: .atomic)

        var pages: [ScopeDayPage] = []
        let previousFactory = CommunityCockpitApplicationFactory.verificationPageFactory
        CommunityCockpitApplicationFactory.verificationPageFactory = { context in
            let page = ScopeDayPage(context)
            pages.append(page)
            return page
        }
        defer { CommunityCockpitApplicationFactory.verificationPageFactory = previousFactory }
        // The app's clock: noon on a fixed local day, moved only by the test.
        let noon = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 6, hour: 12)))
        var wall = noon
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: home, preferredLanguages: ["en"])
        let app = EngineRowsEntry.make(configuration: .init(executableURL: helper, applicationVersion: "synthetic-scope-day",
            allowedEnvironment: environment, offline: true, readOnly: true), settingsStore: settings,
            createsNativePanels: false, cockpitEntryEnabled: true, deadlineNow: { wall })
        await app.prepare()
        await app.composition.start()

        func openAndWaitForData() async throws -> ScopeDayPage {
            let before = pages.count
            app.showConsole()
            let deadline = ContinuousClock.now + .seconds(30)
            while (pages.count == before || pages.last?.data == nil) && ContinuousClock.now < deadline {
                try await Task.sleep(for: .milliseconds(10))
            }
            XCTAssertEqual(pages.count, before + 1, "Each open after a close builds a new page")
            let page = try XCTUnwrap(pages.last)
            XCTAssertNotNil(page.data, "The real cockpit response must reach the page")
            return page
        }
        func close(_ page: ScopeDayPage) {
            // The page's close key: the app routes it to the coordinator's normal close.
            page.onIntent?(.close)
            XCTAssertTrue(page.closed, "The close key closes the page")
        }

        do {
            let first = try await openAndWaitForData()
            XCTAssertEqual(first.scopes.first, "all", "A fresh app opens at All")
            let key = try XCTUnwrap(first.firstMemberKey, "The real response must list the synthetic subscription")
            first.onIntent?(.scopeSelect(key))
            XCTAssertEqual(first.scopes.last, key, "The selected engine key scopes the open page")
            close(first)

            wall = noon.addingTimeInterval(6 * 3600)
            let later = try await openAndWaitForData()
            XCTAssertEqual(later.scopes.first, key, "Opened again later the same day, the scope is remembered")
            XCTAssertEqual(later.scopes.last, key, "The fresh response keeps the remembered scope")
            close(later)

            wall = noon.addingTimeInterval(24 * 3600)
            let nextDay = try await openAndWaitForData()
            XCTAssertEqual(nextDay.scopes.first, "all", "The first open on the next day starts at All")
            XCTAssertEqual(nextDay.scopes.last, "all")
            close(nextDay)
            await app.composition.stop()
        } catch {
            await app.composition.stop()
            throw error
        }
    }
}
#endif
