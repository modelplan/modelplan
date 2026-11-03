// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
import ModelPlanEngineStore
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanAppIntegration

private actor CardDismissalClient: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool {
        context.sessionID == "synthetic-entry" && context.floor.storeEpoch == "synthetic-entry" &&
            context.floor.generation == 1 && context.revision == 1
    }
    let store: EngineStore
    let rows: WireRowsSnapshot
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
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("synthetic-refresh")) }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

@MainActor final class DockCardDismissalJourneyTests: XCTestCase {
    func testNormalEntryStartsAfterPresentationAndOfficialCardCloses() async throws {
        _ = NSApplication.shared
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("card-dismissal-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(root["projection"] as? [String: Any])
        var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
        rows[0]["surfaces"] = ["dock", "menu"]; rows[0]["expiresAt"] = "2027-01-01T00:00:00Z"
        projection["rows"] = rows; root["projection"] = projection
        let fixture = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
        let config = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true)
        let app = EngineRowsEntry.make(configuration: config,
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en-US"]),
            createsNativePanels: false, cockpitEntryEnabled: true, makeClient: { _, store in CardDismissalClient(store: store, rows: fixture) }, activateSettings: {})
        await app.prepare()
        let dock = app.composition.dock
        XCTAssertTrue(dock.interactionBindingInstalled)
        XCTAssertFalse(dock.interactionControllerRunning, "The interaction controller must not start before presentation is allowed")
        // Exercise the real official controller with its parent surface expanded.
        _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.autoHide(false))
        app.allowDockPresentation()
        XCTAssertTrue(dock.interactionControllerRunning)
        await app.composition.start()
        defer { dock.close() }
        XCTAssertTrue(dock.interactionEnvironment().active, "The official appearance must activate the real interaction projection")
        XCTAssertNotNil(dock.dockView.registeredHullPath)
        XCTAssertTrue(dock.interactionEnvironment().parentExpanded)
        func button(_ view: NSView, id: String) -> NSButton? {
            if let value = view as? NSButton, value.accessibilityIdentifier() == id { return value }
            for child in view.subviews { if let found = button(child, id: id) { return found } }
            return nil
        }
        // A drag release must not become a click or pin a card.
        let memberID = "0123456789abcdef"
        let nozzle = try XCTUnwrap(dock.dockView.nozzleEventDelegate)
        let target = try XCTUnwrap(dock.interactionEnvironment().targets.first { $0.id == memberID })
        let start = CGPoint(x: target.along, y: target.along)
        XCTAssertTrue(nozzle.beginNozzle(id: memberID, local: start))
        nozzle.moveNozzle(local: CGPoint(x: target.along + 10, y: target.along + 10))
        nozzle.endNozzle(global: .zero, currentID: memberID)
        XCTAssertTrue(dock.card.isHidden, "Dragging must not open a card")
        XCTAssertFalse(dock.cardPinsDock, "Dragging must not pin a card")
        // A press and release without movement opens and pins the same member.
        XCTAssertTrue(nozzle.beginNozzle(id: memberID, local: start))
        nozzle.endNozzle(global: .zero, currentID: memberID)
        XCTAssertFalse(dock.card.isHidden)
        XCTAssertTrue(dock.cardPinsDock, "Clicking the nozzle opens and pins the card")
        try XCTUnwrap(button(dock.card, id: "dock.card.close")).performClick(nil)
        XCTAssertTrue(dock.card.isHidden, "The ✕ button must close the official Dock card")
        XCTAssertFalse(dock.cardPinsDock)
        var navigations = 0
        dock.showSettings = { navigations += 1 }; dock.showConsole = { navigations += 1 }
        // Member identity rule: the same verified member ID reopens the card.
        dock.dockView.onAction?(.subscription("0123456789abcdef"))
        try XCTUnwrap(button(dock.card, id: "dock.card.enter")).performClick(nil)
        XCTAssertTrue(dock.card.isHidden, "Enter must close the Dock card before navigation")
        XCTAssertEqual(navigations, 1)
        await app.composition.stop()
    }
}
