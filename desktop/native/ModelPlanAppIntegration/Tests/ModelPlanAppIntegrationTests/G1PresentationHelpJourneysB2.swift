// SPDX-License-Identifier: MIT
import Foundation
import AppKit
import XCTest
import ModelPlanDock
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings
import ModelPlanWire
@testable import ModelPlanAppIntegration

// The engine transport is synthetic; the entry, store and Settings composition are production.
private actor G1B2Engine: EngineClient {
    let store: EngineStore
    let rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "g1-b-synthetic", floor: .init(storeEpoch: "g1-b-synthetic", generation: 1), revision: 1)
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context), invalidRowCount: 0))
        return context
    }
    func stop() async {}
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("g1-b-rows")) }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }

}

@MainActor final class G1PresentationHelpJourneysB2: XCTestCase {
    private func entry(profile: URL, preferredLanguages: [String], fixture: WireRowsSnapshot? = nil) async throws -> EngineDockMenuApplication {
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let rows = try fixture ?? WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: preferredLanguages)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: profile.appendingPathComponent("not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true),
            settingsStore: store, createsNativePanels: false, bundleURL: profile.appendingPathComponent("Synthetic.app"),
            makeClient: { _, store in G1B2Engine(store: store, rows: rows) }, activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.prepare()
        await app.composition.start()
        return app
    }
    private func profile() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("g1-b-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }

    // This exercises the actual Settings window through the normal entry.
    // Run only on an admitted GUI CI runner.
    func testG1_LBL_2_2_02_SettingsControlsHaveAccessibleNames() async throws {
        for (index, locale) in ["en-US", "zh-CN"].enumerated() {
            let app = try await entry(profile: profile().appendingPathComponent(String(index)), preferredLanguages: [locale])
            await app.presentSettings()
            let window = try XCTUnwrap(app.settingsHost.currentSurfaceForChecks?.windowForChecks)
            defer { window.close() }
            XCTAssertTrue(window.isVisible)
            func flatten(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(flatten) }
            let views = flatten(try XCTUnwrap(window.contentView))
            let search = try XCTUnwrap(views.first { $0.accessibilityIdentifier() == "settings.search" })
            let firstRun = try XCTUnwrap(views.first { $0.accessibilityIdentifier() == "settings.firstRunPreview" } as? NSButton)
            XCTAssertFalse((search.accessibilityLabel() ?? "").isEmpty, "Search must have an accessible name")
            XCTAssertFalse((firstRun.accessibilityLabel() ?? firstRun.title).isEmpty, "First-run action must have an accessible name or visible label")
        }
    }

    private func quotaFixture() throws -> WireRowsSnapshot {
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(root["projection"] as? [String: Any])
        var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
        var row = try XCTUnwrap(rows.first)
        var accounts = try XCTUnwrap(row["accounts"] as? [[String: Any]])
        var account = try XCTUnwrap(accounts.first)
        let original = try XCTUnwrap((account["windows"] as? [[String: Any]])?.first)
        row["state"] = "fresh"; row["consent"] = "allowed"; row["surfaces"] = ["dock", "menu"]
        row["name"] = ["en": "Synthetic", "zh": "合成"]
        row["expiresAt"] = "2099-01-01T00:00:00Z"
        account["subscriptionRef"] = "0123456789abcdef"; account["valueState"] = "current"
        account["observedAt"] = "2026-01-01T00:00:00Z"; account["freshUntil"] = "2099-01-01T00:00:00Z"
        account["windows"] = [("five", "session", 40.0, 18000), ("weekly", "weekly", 25.0, 604800)].map { id, role, value, duration in
            var window = original
            window["id"] = id; window["role"] = role; window["remainingPercent"] = value
            window["durationSeconds"] = duration; window["current"] = true
            window["limitKey"] = "main"; window["poolKey"] = "main"
            window["resetsAt"] = "2099-01-01T00:00:00Z"; window["validUntil"] = "2099-01-01T00:00:00Z"
            window.removeValue(forKey: "modelScope")
            return window
        }
        accounts = [account]; row["accounts"] = accounts; rows = [row]
        projection["rows"] = rows; root["projection"] = projection
        return try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
    }

    // Reads the actual card's mounted text geometry; character budgets and cockpit remain separate.
    func testG1_LBL_2_2_06_MountedCardTextFragmentsStayInsideCard() async throws {
        let app = try await entry(profile: profile(), preferredLanguages: ["en"], fixture: quotaFixture())
        app.composition.dock.setPresentationAllowed(true)
        let id = try XCTUnwrap(app.composition.presentedContent.snapshot.inputs.first?.id)
        let host = app.composition.dock
        try XCTUnwrap(host.dockView.nozzleEventDelegate).hoverNozzle(id)
        for _ in 0..<1000 where host.detachedCardForChecks == nil { await Task.yield() }
        let card = try XCTUnwrap(host.detachedCardForChecks)
        card.layoutSubtreeIfNeeded()
        let fragments = card.renderedLineFragmentsForChecks
        XCTAssertFalse(fragments.isEmpty)
        XCTAssertTrue(fragments.values.contains { !$0.isEmpty })
        for rect in fragments.values.flatMap({ $0 }) {
            XCTAssertTrue(card.bounds.insetBy(dx: -1, dy: -1).contains(rect), "Text fragment lies outside the mounted card")
        }
    }

    // Settings action accessibility only; iconography and cockpit actions remain separate.
    func testG1_LBL_2_2_04_SettingsActionsHaveAccessibleNames() async throws {
        let app = try await entry(profile: profile(), preferredLanguages: ["en-US"])
        await app.presentSettings()
        let window = try XCTUnwrap(app.settingsHost.currentSurfaceForChecks?.windowForChecks)
        defer { window.close() }
        func flatten(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(flatten) }
        let actions = flatten(try XCTUnwrap(window.contentView)).compactMap { $0 as? NSButton }
            .filter { !$0.isHiddenOrHasHiddenAncestor && $0.action != nil }
        XCTAssertFalse(actions.isEmpty)
        for action in actions {
            XCTAssertFalse((action.accessibilityLabel() ?? action.title).isEmpty, "Settings actions must have an accessible name")
        }
    }
}
