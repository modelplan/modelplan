// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
@testable import ModelPlanAppIntegration
import ModelPlanSettings

private actor ForecastCapabilityClient: EngineClient {
    let store: EngineStore
    let supported: Bool
    let context = EngineDeliveryContext(sessionID: "synthetic-forecast", floor: .init(storeEpoch: "synthetic-forecast", generation: 1), revision: 1)
    init(store: EngineStore, supported: Bool) { self.store = store; self.supported = supported }
    nonisolated func isCurrent(_ value: EngineDeliveryContext) -> Bool { value.sessionID == "synthetic-forecast" }
    func supportsCapability(_ capability: String) async -> Bool { supported && capability == "forecastProducerV1" }
    func start() async throws -> EngineDeliveryContext { await store.consume(.connection(.ready(context))); await store.consume(.context(context)); return context }
    func stop() async {}
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("rows")) }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?, prepared: @escaping @Sendable (WireRequestID) async -> Void) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

/// SET-9-18 / SET-9-29 through the normal entry: the packaged app's Settings (EngineRowsEntry,
/// v1 normal entry) never lists "Resets expiring" or "Data stopped arriving" (v1.1, owner
/// D36). The forecast-exhaustion kind is data-driven: hidden while the engine reports no
/// forecast producer (F1), shown and enabled once it does. Saved kinds are never changed.
@MainActor final class SET918NotificationKindsJourneyTests: XCTestCase {
    func testSET_9_18NormalEntryOffersOnlyTheV1NotificationKinds() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("set-9-18-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let config = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic",
                                               allowedEnvironment: [:], offline: true, readOnly: true)
        let app = EngineRowsEntry.make(configuration: config,
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en-US"]),
            createsNativePanels: false, dockEnvironment: normalEntryTestEnvironment, activateSettings: {})
        await app.prepare()
        let editor = app.settingsHost.application.editor
        XCTAssertTrue(editor.context.v1NormalEntry)
        let preferences = try XCTUnwrap(editor.snapshot).preferences
        let rows = try SettingsCatalogue.rows(preferences: preferences, context: editor.context)
        for key in [SettingKey.reset, .official] {
            XCTAssertNotNil(rows.first { $0.key == key }, "v1 notification kind missing: \(key)")
        }
        XCTAssertFalse(editor.context.capabilities.forecastProducerAvailable)
        XCTAssertFalse(rows.contains { $0.key == .forecast }, "SET-9-29: no forecast producer, so no forecast row")
        for query in ["May not last", "可能撑不到"] {
            let found = try SettingsCatalogue.rows(preferences: preferences, context: editor.context, query: query)
            XCTAssertFalse(found.contains { $0.key == .forecast }, "Search finds the hidden forecast kind: \(query)")
        }
        XCTAssertFalse(rows.contains { [.expiring, .stale].contains($0.key) }, "SET-9-18: v1.1 notification kinds must not appear in v1")
        for query in ["Resets expiring", "Data stopped", "重置即将到期", "数据停止更新"] {
            let found = try SettingsCatalogue.rows(preferences: preferences, context: editor.context, query: query)
            XCTAssertFalse(found.contains { [.expiring, .stale].contains($0.key) }, "Search finds a v1.1 kind: \(query)")
        }

        // The engine reports its forecast producer: the row appears, enabled, with the saved value.
        var context = editor.context
        context.observeForecastProducer(true)
        app.settingsHost.application.update(context: context)
        let withForecast = try SettingsCatalogue.rows(preferences: preferences, context: editor.context, paneID: "notifications")
        let forecast = try XCTUnwrap(withForecast.first { $0.key == .forecast }, "forecast kind missing once the producer exists")
        XCTAssertEqual(forecast.availability, .available, "SET-9-29: a shown forecast kind is usable")
        XCTAssertEqual(forecast.value, .toggle(preferences.notifications.kinds.contains(.forecast)))
        XCTAssertFalse(withForecast.contains { [.expiring, .stale].contains($0.key) })
        // The producer goes away again: hidden, and the saved kinds are untouched.
        context = editor.context
        context.observeForecastProducer(false)
        app.settingsHost.application.update(context: context)
        XCTAssertFalse(try SettingsCatalogue.rows(preferences: preferences, context: editor.context).contains { $0.key == .forecast })
        XCTAssertEqual(try XCTUnwrap(editor.snapshot).preferences.notifications.kinds, preferences.notifications.kinds)
        await app.composition.stop()
    }

    /// The real connection path: the engine's reported capability reaches Settings with no
    /// test-side context write, and an engine that does not report it keeps the row hidden.
    func testSET_9_29EngineCapabilityDrivesTheForecastRow() async throws {
        for supported in [true, false] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("set-9-29-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true),
                settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en-US"]),
                createsNativePanels: false, dockEnvironment: normalEntryTestEnvironment,
                makeClient: { _, store in ForecastCapabilityClient(store: store, supported: supported) }, activateSettings: {})
            defer { app.composition.dock.close() }
            await app.prepare(); await app.composition.start()
            let editor = app.settingsHost.application.editor
            for _ in 0..<100 where editor.context.capabilities.forecastProducerAvailable != supported { try await Task.sleep(for: .milliseconds(10)) }
            if !supported { try await Task.sleep(for: .milliseconds(100)) }
            XCTAssertEqual(editor.context.capabilities.forecastProducerAvailable, supported)
            let preferences = try XCTUnwrap(editor.snapshot).preferences
            let rows = try SettingsCatalogue.rows(preferences: preferences, context: editor.context, paneID: "notifications")
            XCTAssertEqual(rows.contains { $0.key == .forecast }, supported)
            await app.composition.stop()
        }
    }
}
