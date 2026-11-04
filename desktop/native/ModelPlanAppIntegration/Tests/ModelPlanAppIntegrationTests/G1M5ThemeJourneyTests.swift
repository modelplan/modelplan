// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanEngineStore
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanAppIntegration

private actor ThemeG1SyntheticClient: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore
    let rows: WireRowsSnapshot
    private(set) var grantCalls = 0
    func grantCount() -> Int { grantCalls }
    let context = EngineDeliveryContext(sessionID: "synthetic-entry", floor: .init(storeEpoch: "synthetic-entry", generation: 1), revision: 1)
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context)))
        await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context), invalidRowCount: 0))
        return context
    }
    func stop() async {}
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("synthetic-rows")) }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { grantCalls += 1; throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("synthetic-refresh")) }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

@MainActor final class G1M5ThemeJourneyTests: XCTestCase {
    private func makeApp(profile: URL) async throws -> EngineDockMenuApplication {
        _ = NSApplication.shared
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(root["projection"] as? [String: Any])
        var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
        rows[0]["surfaces"] = ["dock", "menu"]; rows[0]["expiresAt"] = "2099-01-01T00:00:00Z"
        projection["rows"] = rows; root["projection"] = projection
        let fixture = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
        let configuration = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/never-launched"), applicationVersion: "g1", allowedEnvironment: [:], offline: true, readOnly: true)
        let app = EngineRowsEntry.make(configuration: configuration,
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en-US"]),
            createsNativePanels: false, makeClient: { _, store in ThemeG1SyntheticClient(store: store, rows: fixture) }, activateSettings: {})
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        return app
    }

    func testG1_THM_10_03() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-settings-appearance-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await makeApp(profile: profile)
        defer { app.composition.dock.close() }
        let existing = Set(NSApp.windows.map(ObjectIdentifier.init))
        await app.settingsHost.present(origin: .programmatic)
        let window = try XCTUnwrap(NSApp.windows.first { !existing.contains(ObjectIdentifier($0)) && $0.isVisible })
        defer { window.close() }
        XCTAssertNil(window.appearance, "Settings must inherit the macOS appearance")
        await app.composition.stop()
    }

    func testG1_THM_2_4_05() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-dock-theme-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await makeApp(profile: profile)
        defer { app.composition.dock.close() }
        let application = app.settingsHost.application, dock = app.composition.dock
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        var environment = application.editor.environment
        environment.darkAppearance = false; application.update(environment: environment)
        await application.reload(); dock.refreshDockContent()
        let light = try encoder.encode(XCTUnwrap(dock.dockView.presentedSkinForChecks))
        environment.darkAppearance = true; application.update(environment: environment)
        await application.reload(); dock.refreshDockContent()
        let dark = try encoder.encode(XCTUnwrap(dock.dockView.presentedSkinForChecks))
        XCTAssertEqual(light, dark, "The normal Dock must retain the same skin across system appearances")
        // Wallpaper-specific device rendering remains a separate verification.
        await app.composition.stop()
    }
}
