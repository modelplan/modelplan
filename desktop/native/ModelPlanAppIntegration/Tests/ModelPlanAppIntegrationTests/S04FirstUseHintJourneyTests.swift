// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanInstruments
import ModelPlanWire
@testable import ModelPlanSettings
@testable import ModelPlanAppIntegration

private actor S04SyntheticClient: EngineClient {
    let store: EngineStore
    let rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "s04-synthetic", floor: .init(storeEpoch: "s04-synthetic", generation: 1), revision: 1)
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { context.sessionID == "s04-synthetic" }
    func supportsCapability(_ capability: String) async -> Bool { capability == "memberRefreshV1" }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context), invalidRowCount: 0))
        return context
    }
    func stop() async {}
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("s04")) }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

@MainActor final class S04FirstUseHintJourneyTests: XCTestCase {
    private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
    private func liveHintLayers() -> [HelpUILayerView] {
        NSApplication.shared.windows.filter { $0.isVisible && !$0.isMiniaturized }
            .flatMap { $0.contentView.map(descendants) ?? [] }
            .compactMap { $0 as? HelpUILayerView }
            .filter { $0.window?.isVisible == true && !$0.isHiddenOrHasHiddenAncestor && $0.input?.firstUse != nil }
    }
    #if MODELPLAN_DOCK_NATIVE_JOURNEY
    /// Real panels in an admitted GUI session. The native-journey profile isolates the reset
    /// notification ledger and the status item (no system delivery, no autosaved position).
    func testNormalEntryShowsWidgetThenRingHintOnRealSurfaces() async throws {
        _ = NSApplication.shared
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("s04-hints-" + UUID().uuidString)
        EngineRowsEntry.nativeJourneyProfile = profile
        defer { EngineRowsEntry.nativeJourneyProfile = nil; try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(root["projection"] as? [String: Any])
        var records = try XCTUnwrap(projection["rows"] as? [[String: Any]])
        records[0]["surfaces"] = ["dock", "menu"]; records[0]["expiresAt"] = "2027-01-01T00:00:00Z"
        projection["rows"] = records; root["projection"] = projection
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        _ = try await store.update { preferences in preferences.onboarding.next(in: .task65) }
        let config = EngineClientConfiguration(executableURL: profile.appendingPathComponent("synthetic"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true)
        let app = EngineRowsEntry.make(configuration: config, settingsStore: store, createsNativePanels: true,
            makeClient: { _, engineStore in S04SyntheticClient(store: engineStore, rows: rows) }, activateSettings: {})
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        defer { app.composition.dock.close() }
        for _ in 0..<200 where liveHintLayers().isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        // #529 supplies the real visible-widget anchor, so the first hint must now appear.
        let first = try XCTUnwrap(liveHintLayers().first, "The first hint must appear on the real visible widget")
        let firstCard = try XCTUnwrap(first.input?.firstUse)
        XCTAssertEqual(liveHintLayers().count, 1)
        XCTAssertEqual(firstCard.anchorID, "dock.findWidget")
        first.onAction?(.dismissHint(offerID: firstCard.offerID, reason: .explicitButton))
        for _ in 0..<200 where !liveHintLayers().contains(where: { $0.input?.firstUse?.anchorID == "dock.ringRefresh" }) {
            try await Task.sleep(for: .milliseconds(10))
        }
        let second = try XCTUnwrap(liveHintLayers().first { $0.input?.firstUse?.anchorID == "dock.ringRefresh" })
        XCTAssertEqual(liveHintLayers().count, 1)
        let secondCard = try XCTUnwrap(second.input?.firstUse)
        second.onAction?(.dismissHint(offerID: secondCard.offerID, reason: .explicitButton))
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(liveHintLayers().isEmpty, "There must not be a third automatic hint")
        await app.composition.stop()
    }

    /// G3-10 / S-07 on real panels: keyboard focus on the painted grip shows the move
    /// explanation next to the widget, and leaving the grip clears it.
    func testG310FocusedGripShowsItsExplanationAndLeavingClearsIt() async throws {
        _ = NSApplication.shared
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g310-explanation-" + UUID().uuidString)
        EngineRowsEntry.nativeJourneyProfile = profile
        defer { EngineRowsEntry.nativeJourneyProfile = nil; try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(root["projection"] as? [String: Any])
        var records = try XCTUnwrap(projection["rows"] as? [[String: Any]])
        records[0]["surfaces"] = ["dock", "menu"]; records[0]["expiresAt"] = "2027-01-01T00:00:00Z"
        projection["rows"] = records; root["projection"] = projection
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        let config = EngineClientConfiguration(executableURL: profile.appendingPathComponent("synthetic"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true)
        let app = EngineRowsEntry.make(configuration: config, settingsStore: store, createsNativePanels: true,
            makeClient: { _, engineStore in S04SyntheticClient(store: engineStore, rows: rows) }, activateSettings: {})
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        defer { app.composition.dock.close() }
        let dock = app.composition.dock, view = dock.dockView
        for _ in 0..<300 where dock.currentDockHelpSurface == nil { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertNotNil(dock.currentDockHelpSurface, "the real widget must publish its help surface")
        let tab = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: 0, context: nil, characters: "\t",
            charactersIgnoringModifiers: "\t", isARepeat: false, keyCode: 48))
        view.keyDown(with: tab)
        XCTAssertEqual(view.focusedGripIndex, 0)
        for _ in 0..<200 where app.shownDockExplanationForChecks == nil { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(app.shownDockExplanationForChecks, HelpCatalog(.english).explanation(.dockMove).accessibleDescription)
        _ = view.resignFirstResponder()
        for _ in 0..<200 where app.shownDockExplanationForChecks != nil { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertNil(app.shownDockExplanationForChecks, "leaving the grip clears its explanation")
        await app.composition.stop()
    }
    #endif
}
