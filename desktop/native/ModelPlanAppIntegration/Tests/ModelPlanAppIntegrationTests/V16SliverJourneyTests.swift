// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanDock
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings
import ModelPlanWire
@testable import ModelPlanAppIntegration

private actor V16SyntheticClient: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore, rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "reserve-synthetic", floor: .init(storeEpoch: "reserve-synthetic", generation: 1), revision: 1)
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch,
            consentGeneration: 1, data: rows), delivery: context), invalidRowCount: rows.projection.invalidRowCount))
        return context
    }
    func stop() async {}
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("synthetic-rows")) }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

@MainActor private final class V16Timer: DockEdgeScheduling {
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) {}
    func cancel() {}
}

@MainActor final class V16SliverJourneyTests: XCTestCase {
    func testV16NormalEntrySliverTracksSizeAndEdge() async throws {
        _ = NSApplication.shared
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("v16-sliver-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(root["projection"] as? [String: Any])
        var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
        var row = rows[0], accounts = try XCTUnwrap(row["accounts"] as? [[String: Any]])
        var account = accounts[0], windows = try XCTUnwrap(account["windows"] as? [[String: Any]])
        row["id"] = "codex"; row["state"] = "fresh"; row["consent"] = "allowed"; row["surfaces"] = ["dock"]
        row["expiresAt"] = "2028-12-01T00:00:00Z"
        row["reason"] = ["code": "ok", "text": ["en": "Reading available", "zh": "读数可用"]]
        row["nextStep"] = ["action": "open_settings_consent", "text": ["en": "Check read access in Settings", "zh": "在设置检查读取权限"], "availableAt": NSNull(), "disabledReason": NSNull()]
        account["subscriptionRef"] = "aaaaaaaaaaaaaaaa"; account["valueState"] = "current"
        account["observedAt"] = "2026-12-01T00:00:00Z"; account["freshUntil"] = "2028-12-01T00:00:00Z"
        account["lastFailure"] = NSNull(); account["credits"] = ["balance": 123.45, "unit": "unknown"]
        windows[0].removeValue(forKey: "modelScope"); windows[0]["current"] = true
        windows[0]["observedAt"] = "2026-12-01T00:00:00Z"; windows[0]["validUntil"] = "2028-12-01T00:00:00Z"
        windows[0]["resetsAt"] = "2028-12-01T00:00:00Z"; windows[0]["remainingPercent"] = 42.0
        account["windows"] = [windows[0]]; row["accounts"] = [account]; rows[0] = row
        projection["rows"] = rows; projection.removeValue(forKey: "resetEvents"); root["projection"] = projection
        let snapshot = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
        XCTAssertEqual(snapshot.projection.invalidRowCount, 0)
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        try await settings.update { $0.autoHide = true; $0.dockDisplayID = "synthetic"; $0.followActiveDisplay = false }
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-01-01T00:00:00Z"))
        let display = DockDisplayArea(id: "synthetic", frame: .init(x: 0, y: 0, width: 1440, height: 900), visibleFrame: .init(x: 0, y: 80, width: 1440, height: 820))
        var pointer = CGPoint(x: 700, y: 450), elapsed = 0.0
        let timer = V16Timer()
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true),
            settingsStore: settings, createsNativePanels: false,
            dockEnvironment: { .init(displays: [display], layouts: [], primaryDisplayID: "synthetic", pointer: pointer) },
            deadlineNow: { now }, deadlineElapsed: { elapsed }, deadlineScheduling: timer,
            makeClient: { _, store in V16SyntheticClient(store: store, rows: snapshot) }, activateSettings: {})
        defer { app.composition.dock.close() }
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        let dock = app.composition.dock
        for (size, expected) in [(SettingsSize.small, 4.0 * 36.0 / 44.0), (.medium, 4.0), (.large, 4.0 * 52.0 / 44.0)] {
            for edge in [SettingsDockEdge.left, .right, .bottom] {
                _ = try await app.settingsHost.application.editor.commit(SettingsB20Edit.size(size))
                _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.dockEdge(edge))
                elapsed += 2; dock.refreshPresence()
                elapsed += 1; dock.refreshPresence()
                let presentation = try XCTUnwrap(dock.edgePresentation)
                XCTAssertEqual(presentation.state, .sliver, "Auto-hide must collapse at the normal entry")
                let placement = try XCTUnwrap(presentation.placement)
                let expectedEdge: DockEdge = edge == .left ? .left : edge == .right ? .right : .bottom
                XCTAssertEqual(placement.edge, expectedEdge, "The presented sliver must use the requested edge")
                // Do not interpret a side placement's dimensions as a bottom placement.
                guard placement.edge == expectedEdge else { continue }
                let thickness = edge == .bottom ? placement.sliverFrame.height : placement.sliverFrame.width
                XCTAssertEqual(thickness, expected, accuracy: 0.001, "Incorrect sliver thickness for \(size) on \(edge)")
                let hull = try XCTUnwrap(dock.dockView.registeredHullBounds)
                let length = edge == .bottom ? placement.sliverFrame.width : placement.sliverFrame.height
                XCTAssertEqual(length, edge == .bottom ? hull.width : hull.height, accuracy: 0.001, "Sliver must span the registered widget hull")
            }
        }
        await app.composition.stop()
    }
}
