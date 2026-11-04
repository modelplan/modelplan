// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanDock
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
@testable import ModelPlanAppIntegration

// Only the engine transport is synthetic. Settings, the production entry and
// the Dock's retained presentation and visibility controllers remain real.
private actor G1RowsClient: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore
    let rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "g1-synthetic", floor: .init(storeEpoch: "g1-synthetic", generation: 1), revision: 1)
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context)))
        await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context), invalidRowCount: rows.projection.invalidRowCount))
        return context
    }
    func stop() async {}
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("g1-rows")) }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

@MainActor private final class G1DisplayEnvironment {
    let display = DockDisplayArea(id: "g1-display", frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 900))
    var presence = DockPresence()
    func sample() -> DockEdgeEnvironment {
        .init(displays: [display], layouts: [], primaryDisplayID: display.id, pointer: CGPoint(x: 720, y: 450), presence: presence)
    }
}

@MainActor final class G1WidgetSettingsJourneys: XCTestCase {
    private func open(_ environment: G1DisplayEnvironment, profile: URL) async throws -> EngineDockMenuApplication {
        _ = NSApplication.shared
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(root["projection"] as? [String: Any])
        var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
        rows[0]["state"] = "fresh"; rows[0]["consent"] = "allowed"
        rows[0]["surfaces"] = ["dock", "menu"]; rows[0]["expiresAt"] = "2099-01-01T00:00:00Z"
        projection["rows"] = rows; projection.removeValue(forKey: "resetEvents"); root["projection"] = projection
        let fixture = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
        let configuration = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/never-launched"), applicationVersion: "g1", allowedEnvironment: [:], offline: true, readOnly: true)
        let app = EngineRowsEntry.make(configuration: configuration,
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"]),
            createsNativePanels: false, dockEnvironment: { environment.sample() },
            makeClient: { _, store in G1RowsClient(store: store, rows: fixture) }, activateSettings: {})
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        return app
    }

    func testG1_DOCK_3_1_1_01() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-position-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await open(G1DisplayEnvironment(), profile: profile)
        defer { app.composition.dock.close() }
        let preferences = try XCTUnwrap(app.settingsHost.application.editor.snapshot?.preferences)
        XCTAssertEqual(preferences.dockEdge, .right)
        XCTAssertEqual(preferences.dockAlongFraction, 0.5, accuracy: 0.0001)
        let placement = try XCTUnwrap(app.composition.dock.edgePresentation?.placement)
        XCTAssertEqual(placement.edge, .right)
        XCTAssertEqual(placement.alongFraction, 0.5, accuracy: 0.0001)
        await app.composition.stop()
    }

    func testG1_DOCK_3_1_1_04() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-fullscreen-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let environment = G1DisplayEnvironment()
        let app = try await open(environment, profile: profile)
        defer { app.composition.dock.close() }
        let preferences = try XCTUnwrap(app.settingsHost.application.editor.snapshot?.preferences)
        XCTAssertFalse(preferences.showOverFullscreen)
        environment.presence.allowedOverFullscreen = false
        app.composition.dock.refreshPresence()
        XCTAssertEqual(app.composition.dock.edgePresentation?.state, .suppressed(.fullscreen))
        environment.presence.allowedOverFullscreen = true
        app.composition.dock.refreshPresence()
        XCTAssertNotEqual(app.composition.dock.edgePresentation?.state, .suppressed(.fullscreen))
        await app.composition.stop()
    }

    func testG1_DOCK_3_1_1_08() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-choices-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let path = profile.appendingPathComponent("ModelPlan/settings.json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: path.path))
        let app = try await open(G1DisplayEnvironment(), profile: profile)
        defer { app.composition.dock.close() }
        XCTAssertFalse(FileManager.default.fileExists(atPath: path.path), "Reading defaults must not persist them")
        _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.showDock(false))
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
        let settings = try XCTUnwrap(document["settings"] as? [String: Any])
        XCTAssertEqual(Set(settings.keys), Set(["showDock"]), "Only the explicit choice should be stored")
        await app.composition.stop(); app.composition.dock.close()

        let reopened = try await open(G1DisplayEnvironment(), profile: profile)
        XCTAssertEqual(reopened.settingsHost.application.editor.snapshot?.preferences.showDock, false)
        await reopened.composition.stop(); reopened.composition.dock.close()

        var injected = document
        var unknownSettings = settings
        unknownSettings["g1UnknownSetting"] = "synthetic"
        injected["settings"] = unknownSettings
        try JSONSerialization.data(withJSONObject: injected).write(to: path, options: .atomic)
        let attempted = try await open(G1DisplayEnvironment(), profile: profile)
        defer { attempted.composition.dock.close() }
        _ = try await attempted.settingsHost.application.editor.commit(SettingsB21Edit.showDock(true))
        let after = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
        XCTAssertNil((after["settings"] as? [String: Any])?["g1UnknownSetting"])
        await attempted.composition.stop()
    }
}
