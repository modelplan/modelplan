// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
import ModelPlanEngineStore
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanAppIntegration

private actor RowsEntryClient: EngineClient {
    let store: EngineStore
    let rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "synthetic-entry", floor: .init(storeEpoch: "synthetic-entry", generation: 1), revision: 1)
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context)))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context), invalidRowCount: 0))
        return context
    }
    func stop() async {}
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("synthetic-rows")) }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("synthetic-refresh")) }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}
@MainActor final class EngineRowsEntryTests: XCTestCase {
    func testNormalEntryFactoryFeedsActualDockAndMenuThenWithdrawsBeforeClearAck() async throws {
        _ = NSApplication.shared
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("u6-entry-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(object["projection"] as? [String: Any])
        var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
        rows[0]["surfaces"] = ["dock", "menu"]
        rows[0]["name"] = ["en": "Engine-only row", "zh": "引擎行"]
        rows[0]["reason"] = ["code": "ok", "text": ["en": "Engine-only reason", "zh": "引擎原因"]]
        projection["rows"] = rows; object["projection"] = projection
        let fixture = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true),
            settingsStore: try SettingsStore(url: profile.appendingPathComponent("settings.json")), createsNativePanels: false,
            makeClient: { _, store in RowsEntryClient(store: store, rows: fixture) })
        await app.prepare(); await app.composition.start()
        XCTAssertEqual(app.composition.provider.dockContent.dockRows.map(\.id), ["codex"])
        XCTAssertTrue(app.composition.dock.menu().items.contains { $0.title.contains("Engine-only reason") })
        XCTAssertTrue(app.composition.menuPresentation.detail.contains("Engine-only reason"))
        XCTAssertNil(app.composition.dock.nativePanel)
        var clearObservedBeforeReturn = false
        app.composition.menuDidChange = {
            if app.composition.provider.dockContent.status == .cleared {
                clearObservedBeforeReturn = true
                XCTAssertFalse(app.composition.dock.menu().items.contains { $0.title.contains("Engine-only reason") })
                XCTAssertFalse(app.composition.menuPresentation.detail.contains("Engine-only reason"))
            }
        }
        await app.composition.store.consume(.clearPrivateViews(.init(revision: 2, reason: .connectionLost, previous: nil, nextFloor: nil)))
        XCTAssertFalse(app.composition.dock.menu().items.contains { $0.title.contains("Engine-only reason") })
        XCTAssertFalse(app.composition.menuPresentation.detail.contains("Engine-only reason"))
        XCTAssertTrue(clearObservedBeforeReturn)
        XCTAssertTrue(app.composition.provider.dockContent.dockRows.isEmpty)
        await app.composition.stop()
    }
    func testFreshGeneratedWindowReachesDockInputAndMenuReading() async throws {
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(root["projection"] as? [String: Any])
        var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
        rows[0]["surfaces"] = ["dock", "menu"]; rows[0]["state"] = "fresh"
        rows[0]["expiresAt"] = "2027-01-01T00:00:00Z"
        var accounts = try XCTUnwrap(rows[0]["accounts"] as? [[String: Any]])
        accounts[0]["valueState"] = "current"; accounts[0]["freshUntil"] = "2027-01-01T00:00:00Z"
        var windows = try XCTUnwrap(accounts[0]["windows"] as? [[String: Any]])
        windows[0]["current"] = true; windows[0]["remainingPercent"] = 73
        windows[0]["validUntil"] = "2027-01-01T00:00:00Z"; windows[0]["resetsAt"] = "2027-01-01T00:00:00Z"
        accounts[0]["windows"] = windows; rows[0]["accounts"] = accounts
        projection["rows"] = rows; root["projection"] = projection
        let fixture = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
        let store = EngineStore(), source = EngineDockMenuProvider(store: store)
        let adapter = EngineDockContentProvider(source: source)
        let fake = RowsEntryClient(store: store, rows: fixture); _ = try await fake.start()
        let content = adapter.makeContent(.init(snapshot: nil, diagnostics: .init(), now: Date()))
        XCTAssertEqual(content.snapshot.inputs.first?.windows.first?.remainingPercent, 73)
        XCTAssertEqual(content.snapshot.inputs.first?.dataState, .fresh)
        XCTAssertTrue((content.menuStatusLines ?? []).joined().contains("73%"))
    }

}
