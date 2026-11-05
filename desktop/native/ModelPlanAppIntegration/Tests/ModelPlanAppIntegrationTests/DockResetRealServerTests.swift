// SPDX-License-Identifier: MIT
#if MODELPLAN_DOCK_REAL_STRIP_JOURNEY
import AppKit
import CryptoKit
import Foundation
import XCTest
import ModelPlanDock
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class DockResetRealServerTests: XCTestCase {
    func testD21PublicResetAndCurrentMemberReachTheNormalDock() async throws {
        let executable = URL(fileURLWithPath: try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_DOCK_TEST_CLI"]))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("d21-real-reset-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".codex"), withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        let env = ["HOME": root.path, "TMPDIR": root.path, "PATH": "/usr/bin:/bin", "LANG": "C"]
        func json(_ value: Any) throws -> Data {
            try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .withoutEscapingSlashes])
        }
        func command(_ arguments: [String], input: [String: Any]? = nil) async throws -> [String: Any] {
            let process = Process(), output = Pipe()
            process.executableURL = executable; process.arguments = arguments; process.environment = env
            process.standardOutput = output; process.standardError = FileHandle.nullDevice
            let stdin = input.map { _ in Pipe() }
            process.standardInput = stdin ?? FileHandle.nullDevice
            try process.run()
            if let input, let stdin {
                try stdin.fileHandleForWriting.write(contentsOf: json(input))
                try stdin.fileHandleForWriting.close()
            }
            let deadline = ContinuousClock.now + .seconds(5)
            while process.isRunning, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
            if process.isRunning { process.terminate(); throw CocoaError(.fileReadUnknown) }
            XCTAssertEqual(process.terminationStatus, 0, arguments.joined(separator: " "))
            return try XCTUnwrap(JSONSerialization.jsonObject(with: output.fileHandleForReading.readDataToEndOfFile()) as? [String: Any])
        }
        _ = try await command(["consent", "init", "--json"])
        let beforeGrant = try await command(["consent", "--json"])
        let scope = "codex.runtime_usage"
        let epoch = try XCTUnwrap(beforeGrant["storeEpoch"] as? String)
        _ = try await command(["consent", "grant", "--json"], input: [
            "requestId": UUID().uuidString.lowercased(), "expectStoreEpoch": epoch,
            "expectGeneration": try XCTUnwrap(beforeGrant["generation"] as? Int),
            "consentTextVersion": try XCTUnwrap(beforeGrant["consentTextVersion"] as? Int),
            "allow": [scope], "deny": [String]()
        ])
        let consent = try await command(["consent", "--json"])
        let generation = try XCTUnwrap(consent["generation"] as? Int)
        let cache = root.appendingPathComponent("Library/Caches/modelplan")
        func write(_ bytes: Data, to relative: String) throws {
            let url = cache.appendingPathComponent(relative)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try bytes.write(to: url, options: .atomic)
        }
        func hash(_ bytes: Data) -> String { SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() }
        let now = Date(), iso = ISO8601DateFormatter()
        func at(_ offset: Double) -> String { iso.string(from: now.addingTimeInterval(offset)) }
        let reset = at(7_200), observed = at(-120), published = at(-60)
        let window: [String: Any] = ["kind": "five_hour", "usedPercent": 50, "windowMinutes": 300,
            "resetsAt": reset, "observedAt": observed, "resetMode": "rolling"]
        try write(json(["schemaVersion": 1, "status": "ok", "observedAt": observed, "plan": "plus",
                        "subscriptionRef": "aaaaaaaaaaaaaaaa", "windows": [window],
                        "admission": ["storeEpoch": epoch, "generation": generation, "scope": scope]]),
                  to: "observed/codex-account.json")
        let eventID = "synthetic-d21-announcement"
        let url = "https://status.openai.com/incidents/synthetic-d21"
        let announced: [String: Any] = ["id": eventID, "provider": "openai", "eventType": "direct_reset_announced",
            "status": "upstream-announced", "publishedAt": published, "url": url,
            "schedule": ["precision": "deadline", "from": reset, "through": reset, "label": "before the deadline"]]
        let confirmed: [String: Any] = ["id": "synthetic-d21-confirmation", "provider": "openai",
            "eventType": "direct_reset_reported_complete", "status": "upstream-confirmed", "publishedAt": at(-30),
            "confirms": eventID, "url": url]
        // Match the synthetic verified-cache format from cli/cmd/modelplan/app_server_reset_binary_test.go.
        func publish(_ events: [[String: Any]]) throws {
            let dummy = String(repeating: "a", count: 64)
            let data: [String: Any] = ["units": ["ability": "websiteAbility", "cost": "usdPerReferenceTask", "time": "taskTimeCrossModel"],
                "models": [], "lineups": [], "resets": events, "windows": []]
            let dependencies = Dictionary(uniqueKeysWithValues: ["models", "registry", "rules", "calendar"].map { ($0, dummy) })
            let bytes = try json(["schemaVersion": 1, "kind": "client", "dependencies": dependencies, "data": data])
            let component = hash(bytes)
            var refs = Dictionary(uniqueKeysWithValues: ["methods", "registry", "models", "plans", "rules", "news", "calendar"].map {
                ($0, ["schemaVersion": 1, "hash": dummy, "bytes": 2] as [String: Any])
            })
            refs["client"] = ["schemaVersion": 1, "hash": component, "bytes": bytes.count]
            let methods = #"{"index":"unified-v03-estimator-0.1.0-internal","recommendation":"balanced-coding-absolute-v4"}"#
            let components = String(decoding: try json(refs), as: UTF8.self)
            let core = #"{"schemaVersion":1,"comparisonVersion":"synthetic","methods":"# + methods + #","components":"# + components + "}"
            let publicationID = String(hash(Data(core.utf8)).prefix(24))
            let manifest = Data((core.dropLast() + #","publicationId":""# + publicationID + #"","publishedAt":""# + published + #""}"#).utf8)
            try write(bytes, to: "objects/" + component + ".json")
            try write(manifest, to: "releases/" + publicationID + "/manifest.json")
            try write(json(["publicationId": publicationID, "manifestHash": hash(manifest),
                            "component": "client", "componentHash": component]), to: "state.json")
        }
        try publish([announced])

        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        _ = try await store.update { $0.autoHide = true; $0.motion = .on }
        let app = EngineRowsEntry.make(configuration: .init(executableURL: executable, applicationVersion: "synthetic-d21",
            allowedEnvironment: env, offline: true, readOnly: true), settingsStore: store, createsNativePanels: false,
            bundleURL: root.appendingPathComponent("Synthetic.app"), dockEnvironment: normalEntryTestEnvironment,
            isolatedResetNotificationLedger: root.appendingPathComponent("test-notifications.json"), activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.prepare(); app.allowDockPresentation()
        let delivery = try await app.composition.client.start()
        func waitForEvent(_ status: String) async throws {
            func matches() -> Bool {
                guard case .available(let events) = app.composition.rowEvents else { return false }
                return events.contains { $0.id == eventID && $0.status == status }
            }
            let end = ContinuousClock.now + .seconds(4)
            while !matches(), ContinuousClock.now < end { try await Task.sleep(for: .milliseconds(10)) }
            XCTAssertTrue(matches(), "The real server must publish the " + status + " event")
        }
        try await waitForEvent("announced")
        try publish([announced, confirmed])
        _ = try await app.composition.client.subscribeRows(timeout: .seconds(4))
        try await waitForEvent("confirmed")
        XCTAssertEqual(app.composition.store.snapshot.delivery, delivery)

        let row = try XCTUnwrap(app.composition.store.snapshot.rows?.projection.rows.first { $0.id == "codex" })
        XCTAssertEqual(row.accounts.first?.windows.first?.remainingPercent, 50)
        XCTAssertEqual(row.accounts.first?.windows.first?.current, true)
        XCTAssertEqual(row.state, .fresh, "A current cached runtime reading must be admitted to the Dock. Producer reason: " + String(describing: row.reason.code))
        guard row.state == .fresh else { return }
        let dock = app.composition.dock
        let strip = try dock.prepareSliver(size: XCTUnwrap(dock.edgePresentation?.placement?.sliverFrame.size))
        XCTAssertFalse(strip.noticeMarks.isEmpty)
        XCTAssertEqual(strip.quotaSegmentColorRolesForChecks.first?.remainingPercent, 50)
    }
}
#endif
