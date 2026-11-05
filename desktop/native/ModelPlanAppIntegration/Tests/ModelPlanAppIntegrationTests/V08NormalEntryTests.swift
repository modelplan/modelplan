// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings
import ModelPlanWire
@testable import ModelPlanAppIntegration

private actor V08JourneyClient: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore, rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "v08-synthetic", floor: .init(storeEpoch: "v08-synthetic", generation: 1), revision: 1)
    var revision: UInt64 = 1
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context), invalidRowCount: rows.projection.invalidRowCount))
        return context
    }
    func replaceRows(_ rows: WireRowsSnapshot) async throws {
        revision += 1
        let next = EngineDeliveryContext(sessionID: context.sessionID, floor: context.floor, revision: revision)
        await store.consume(.connection(.ready(next))); await store.consume(.context(next))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: next.sessionID, storeEpoch: next.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: next), invalidRowCount: rows.projection.invalidRowCount))
    }
    func stop() async {}
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("synthetic")) }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

@MainActor final class V08NormalEntryTests: XCTestCase {
    private func fixture(_ remaining: Double) throws -> WireRowsSnapshot {
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(root["projection"] as? [String: Any])
        var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
        var row = rows[0], accounts = try XCTUnwrap(row["accounts"] as? [[String: Any]])
        var account = accounts[0], windows = try XCTUnwrap(account["windows"] as? [[String: Any]])
        row["id"] = "codex"; row["state"] = "fresh"; row["consent"] = "allowed"; row["surfaces"] = ["dock"]
        row["expiresAt"] = "2028-12-01T00:00:00Z"
        account["subscriptionRef"] = "aaaaaaaaaaaaaaaa"; account["valueState"] = "current"
        account["observedAt"] = "2026-12-01T00:00:00Z"; account["freshUntil"] = "2028-12-01T00:00:00Z"
        account["lastFailure"] = NSNull()
        windows[0].removeValue(forKey: "modelScope"); windows[0]["current"] = true
        // Exercise the plan-wide session quota, not the capture's named synthetic pool.
        windows[0]["limitKey"] = "main"; windows[0]["poolKey"] = "main"
        windows[0]["observedAt"] = "2026-12-01T00:00:00Z"; windows[0]["validUntil"] = "2028-12-01T00:00:00Z"
        windows[0]["resetsAt"] = "2028-12-01T00:00:00Z"; windows[0]["remainingPercent"] = remaining
        account["windows"] = [windows[0]]; row["accounts"] = [account]; rows[0] = row
        projection["rows"] = rows; projection.removeValue(forKey: "resetEvents"); root["projection"] = projection
        let snapshot = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
        XCTAssertEqual(snapshot.projection.invalidRowCount, 0)
        return snapshot
    }

    func testV08NormalEntryProjectsQuotaBandsAndNightPalette() async throws {
        _ = NSApplication.shared
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("v08-normal-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-01-01T00:00:00Z"))
        let display = DockDisplayArea(id: "synthetic", frame: .init(x: 0, y: 0, width: 1440, height: 900), visibleFrame: .init(x: 0, y: 80, width: 1440, height: 820))
        let initial = try fixture(100)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true),
            settingsStore: settings, createsNativePanels: false,
            dockEnvironment: { .init(displays: [display], layouts: [], primaryDisplayID: "synthetic", pointer: CGPoint(x: 700, y: 450)) },
            deadlineNow: { now }, makeClient: { _, store in V08JourneyClient(store: store, rows: initial) }, activateSettings: {})
        defer { app.composition.dock.close() }
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        let client = try XCTUnwrap(app.composition.client as? V08JourneyClient)
        let view = app.composition.dock.dockView
        for threshold in [25, 10] {
            _ = try await app.settingsHost.application.editor.commit(SettingsB20Edit.redBelow(threshold))
            for remaining in [0.0, 25, 26, 40, 41, 100] {
                try await client.replaceRows(fixture(remaining))
                let reading = try XCTUnwrap(view.presentedReadingsForChecks["aaaaaaaaaaaaaaaa"])
                let expected: DockQuotaStatus = remaining <= Double(threshold) ? .critical : remaining < 41 ? .warning : .normal
                XCTAssertEqual(reading.status, expected, "remaining=\(remaining), threshold=\(threshold)")
                XCTAssertEqual(reading.outer?.status, expected)
                let skin = try XCTUnwrap(view.presentedSkinForChecks)
                let ink = try XCTUnwrap(skin.palette[expected.rawValue])
                let rgb: (Double, Double, Double) = expected == .normal ? (90, 217, 186) : expected == .warning ? (234, 193, 123) : (239, 68, 68)
                XCTAssertEqual(ink.r, rgb.0 / 255, accuracy: 0.000001)
                XCTAssertEqual(ink.g, rgb.1 / 255, accuracy: 0.000001)
                XCTAssertEqual(ink.b, rgb.2 / 255, accuracy: 0.000001)
            }
        }
        await app.composition.stop()
    }
}
