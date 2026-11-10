// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCockpitWeb
import ModelPlanWire
@testable import ModelPlanAppIntegration

#if MODELPLAN_TEST_ONLY_SPI
@MainActor private final class RealDetailsPage: CockpitPageSurface {
    private let bridge: CockpitBridgeState
    var onReady: (() -> Void)?
    var onIntent: ((CockpitIntent) -> Void)?
    var onClosed: (() -> Void)?
    private(set) var received = false
    private(set) var details: WireCockpitDetails?
    private(set) var cleared = false
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

    func display(_ data: WireCockpitData, ticket: CockpitQueryTicket) {
        received = true
        details = data.details
    }

    func clearPrivateViews(adopting context: CockpitEngineContext?) async {
        details = nil
        cleared = true
        _ = try? bridge.clear(adopting: context)
    }

    func discard() { bridge.dispose(); onClosed?() }
}

extension CommunityCockpitEntryTests {
    @MainActor func testNormalEntryReceivesCockpitDetailsFromRealAppServer() async throws {
        guard let path = ProcessInfo.processInfo.environment["MODELPLAN_U11_TEST_CLI"],
              FileManager.default.isExecutableFile(atPath: path) else {
            throw XCTSkip("The real synthetic-test CLI is not available")
        }
        let helper = URL(fileURLWithPath: path)
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("cockpit-details-" + UUID().uuidString)
        let cache = home.appendingPathComponent("Library/Caches/modelplan/observed")
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: home.appendingPathComponent(".codex"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
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
        let epoch = try XCTUnwrap(before["storeEpoch"] as? String)
        _ = try await command(["consent", "grant", "--json"], input: [
            "requestId": UUID().uuidString.lowercased(), "expectStoreEpoch": epoch,
            "expectGeneration": try XCTUnwrap(before["generation"] as? Int),
            "consentTextVersion": try XCTUnwrap(before["consentTextVersion"] as? Int),
            "allow": ["codex.local_history"], "deny": [String]()
        ])
        let now = Date(), iso = ISO8601DateFormatter()
        func at(_ offset: Double) -> String { iso.string(from: now.addingTimeInterval(offset)) }
        func record(_ ref: String, source: String, running: Bool, last: Double) -> [String: Any] {
            ["ref": ref, "source": source, "model": "unverified-synthetic-alias", "effort": running ? "high" : "unverified",
             "startedAt": at(-10), "lastAt": at(last), "running": running,
             "grantEpoch": ["storeEpoch": epoch, "revokedGeneration": 0]]
        }
        // D63: recorded sessions for the 7-day view (cockpitSessionsV1); an unadmitted source stays out.
        func recorded(_ ref: String, source: String, last: Double) -> [String: Any] {
            ["ref": ref, "key": "synthetic-" + ref, "source": source, "firstAt": at(last - 600), "lastAt": at(last),
             "days": [["day": "2026-11-01", "model": "unverified-synthetic-alias", "effortStatus": "reported", "effort": "high", "observedRequests": 1, "observedOutputTokens": 10]],
             "grantEpoch": ["storeEpoch": epoch, "revokedGeneration": 0]]
        }
        let ledger: [String: Any] = ["schemaVersion": 1, "since": at(-9 * 86400), "rows": [], "live": [
            record("1111111111111111", source: "codex", running: true, last: -1),
            record("2222222222222222", source: "codex", running: false, last: -3),
            record("3333333333333333", source: "claude-code", running: true, last: -1)
        ], "sessions": [
            recorded("4444444444444444", source: "codex", last: -2 * 86400),
            recorded("5555555555555555", source: "codex", last: -8 * 86400),
            recorded("6666666666666666", source: "claude-code", last: -3600)
        ]]
        try JSONSerialization.data(withJSONObject: ledger).write(to: cache.appendingPathComponent("perf.json"))

        var page: RealDetailsPage?
        let previousFactory = CommunityCockpitApplicationFactory.verificationPageFactory
        CommunityCockpitApplicationFactory.verificationPageFactory = { context in
            let surface = RealDetailsPage(context)
            page = surface
            return surface
        }
        defer { CommunityCockpitApplicationFactory.verificationPageFactory = previousFactory }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: home)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: helper, applicationVersion: "synthetic-details-test",
            allowedEnvironment: environment, offline: true, readOnly: true), settingsStore: settings,
            createsNativePanels: false, cockpitEntryEnabled: true)
        await app.prepare()
        await app.composition.start()
        app.showConsole()
        let deadline = ContinuousClock.now + .seconds(30)
        do {
            while page?.received != true && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
            let surface = try XCTUnwrap(page, "The normal cockpit action must construct a page")
            XCTAssertTrue(surface.received, "The real cockpit response must reach the page")
            let details = try XCTUnwrap(surface.details, "The production initialize must negotiate cockpitDetailsV1")
            XCTAssertEqual(details.sessionCoverage, "local-last-seen")
            XCTAssertEqual(details.sessions.map(\.sessionRef), ["1111111111111111", "2222222222222222"])
            XCTAssertEqual(details.sessions.map(\.state), ["running", "idle"])
            XCTAssertEqual(details.sessions.map(\.model), ["unknown", "unknown"])
            XCTAssertTrue(details.sessions.allSatisfy { $0.rate == nil })
            XCTAssertEqual(details.recentSessions?.map(\.sessionRef), ["4444444444444444"],
                           "The negotiated 7-day list carries only admitted sessions seen within seven days")
            XCTAssertEqual(details.recentSessions?.first?.effort, "high")
            await app.composition.stop()
            XCTAssertTrue(surface.cleared, "The normal engine stop must clear the page")
            XCTAssertNil(surface.details)
        } catch {
            await app.composition.stop()
            throw error
        }
    }
}
#endif
