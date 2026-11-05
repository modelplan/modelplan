// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings
import ModelPlanWire
@_spi(DockResourceChecks) import ModelPlanDock
@testable import ModelPlanAppIntegration

/// This client supplies only the synthetic wire snapshot; the app, host and card
/// are constructed through the same entry and rendering path as the product.
private actor G1CardRowsClient: EngineClient {
    let store: EngineStore
    let rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "g1-card", floor: .init(storeEpoch: "g1-card", generation: 1), revision: 1)

    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { context.sessionID == "g1-card" && context.revision == 1 }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context)))
        await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context), invalidRowCount: rows.projection.invalidRowCount))
        return context
    }
    func stop() async {}
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("g1-rows")) }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

@MainActor final class G1DockCardJourneys: XCTestCase {
    private let memberID = "aaaaaaaaaaaaaaaa"

    private func snapshot(credits: [String: Any]? = nil, includeScoped: Bool = false,
                          missingPercentage: Bool = false) throws -> WireRowsSnapshot {
        let captures = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: captures)) as? [String: Any])
        var projection = try XCTUnwrap(root["projection"] as? [String: Any])
        var row = try XCTUnwrap((projection["rows"] as? [[String: Any]])?.first)
        var account = try XCTUnwrap((row["accounts"] as? [[String: Any]])?.first)
        let source = try XCTUnwrap((account["windows"] as? [[String: Any]])?.first)
        let now = Date(), format = ISO8601DateFormatter()
        let observed = format.string(from: now.addingTimeInterval(-30))
        let reset = format.string(from: now.addingTimeInterval(2 * 3600 + 13 * 60 + 30))
        let deadline = format.string(from: now.addingTimeInterval(86400))
        func window(_ id: String, role: String, duration: Int, percent: Any) -> [String: Any] {
            var value = source
            value["id"] = id; value["role"] = role; value["durationSeconds"] = duration
            value["label"] = ["en": id, "zh": id]
            value["limitKey"] = "main"; value["poolKey"] = "main"; value.removeValue(forKey: "modelScope")
            value["remainingPercent"] = percent; value["current"] = true
            value["observedAt"] = observed; value["resetsAt"] = reset; value["validUntil"] = reset
            return value
        }
        let percent: Any = missingPercentage ? NSNull() : 41
        var windows = [window("five", role: "session", duration: 18000, percent: percent),
                       window("week", role: "weekly", duration: 604800, percent: missingPercentage ? NSNull() : 70)]
        if includeScoped {
            var extra = window("scoped", role: "weekly", duration: 604800, percent: 1)
            extra["modelScope"] = ["models": ["synthetic-model"]]
            windows.append(extra)
        }
        row["id"] = "codex"; row["name"] = ["en": "Synthetic Tool", "zh": "Synthetic Tool"]
        row["vendorKey"] = "codex"; row["consent"] = "allowed"; row["surfaces"] = ["dock", "menu"]
        row["state"] = "fresh"; row["expiresAt"] = deadline; row["stateAfterExpiry"] = NSNull()
        row["reason"] = ["code": "ok", "text": ["en": "Reading available", "zh": "读数可用"]]
        account["subscriptionRef"] = memberID; account["valueState"] = "current"
        account["observedAt"] = observed; account["freshUntil"] = deadline
        account["plan"] = ["id": "synthetic-plan", "name": ["en": "Synthetic Plan", "zh": "Synthetic Plan"]]
        account["windows"] = windows; account["credits"] = credits ?? NSNull()
        account["resetCards"] = NSNull(); row["accounts"] = [account]
        projection["rows"] = [row]; projection.removeValue(forKey: "resetEvents")
        root["projection"] = projection
        return try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
    }

    private func nodes(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(nodes) }
    private func text(_ root: NSView, _ identifier: String) -> String? {
        nodes(root).compactMap { $0 as? NSTextField }.first { $0.accessibilityIdentifier() == identifier }?.stringValue
    }

    private func withRenderedCard(credits: [String: Any]? = nil, includeScoped: Bool = false,
                                  missingPercentage: Bool = false,
                                  check: (StaticDockPreviewHost, EngineDockMenuApplication) async throws -> Void) async throws {
        _ = NSApplication.shared
        let rows = try snapshot(credits: credits, includeScoped: includeScoped, missingPercentage: missingPercentage)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("g1-card-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        try await store.update { $0.language = .english; $0.showDock = true; $0.autoHide = false }
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/never-launched"),
            applicationVersion: "g1-synthetic", allowedEnvironment: [:], offline: true, readOnly: true),
            settingsStore: store, createsNativePanels: false,
            makeClient: { _, store in G1CardRowsClient(store: store, rows: rows) }, activateSettings: {})
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        let host = app.composition.dock
        do {
            // Exercise the production controller's hover dwell and host callback.
            try presentSyntheticHostCard(host, id: memberID)
            XCTAssertFalse(host.card.isHidden, "normal entry must present an actual card for the admitted member")
            try await check(host, app)
            await app.composition.stop(); host.close()
        } catch {
            await app.composition.stop(); host.close()
            throw error
        }
    }

    func testDOCK_3_8_05RenderedHeaderShowsMemberPlanAgeAndGlyph() async throws {
        try await withRenderedCard { host, _ in
            let title = try XCTUnwrap(text(host.card, "dock.card.text.name"))
            XCTAssertTrue(title.contains("Synthetic Tool"))
            XCTAssertTrue(title.contains("Synthetic Plan"))
            XCTAssertNotNil(text(host.card, "dock.card.text.source"))
            XCTAssertTrue(nodes(host.card).contains { $0 is NSImageView }, "the actual header must render the member glyph")
        }
    }

    func testDOCK_3_8_06RenderedFiveHourAndWeeklyRowsHaveBarsAndValues() async throws {
        try await withRenderedCard { host, _ in
            XCTAssertEqual(text(host.card, "dock.card.text.row.quota:five.value"), "41%")
            XCTAssertEqual(text(host.card, "dock.card.text.row.quota:week.value"), "70%")
            let ids = Set(nodes(host.card).compactMap { $0.accessibilityIdentifier() })
            XCTAssertTrue(ids.contains("dock.card.quota.quota:five"))
            XCTAssertTrue(ids.contains("dock.card.quota.quota:week"))
        }
    }

    func testDOCK_3_8_07RenderedResetUsesRelativeGlossaryCopy() async throws {
        try await withRenderedCard { host, app in
            let detail = try XCTUnwrap(text(host.card, "dock.card.text.row.quota:five.detail"))
            XCTAssertEqual(detail, "Resets in 2h 14m")
            _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.language(.chinese))
            XCTAssertEqual(text(host.card, "dock.card.text.row.quota:five.detail"), "2小时14分后重置")
        }
    }

    func testDOCK_3_8_08RenderedReserveUsesReportedCreditsAndUnknownUnit() async throws {
        try await withRenderedCard(credits: ["balance": 19614, "unit": "credits"]) { host, _ in
            XCTAssertEqual(text(host.card, "dock.card.text.row.credits.value"), "19,614")
        }
        try await withRenderedCard(credits: ["balance": 0.42, "unit": "credits"]) { host, _ in
            XCTAssertEqual(text(host.card, "dock.card.text.row.credits.value"), "<1")
        }
        try await withRenderedCard(credits: ["balance": 19614, "unit": "synthetic-unknown"]) { host, _ in
            XCTAssertEqual(text(host.card, "dock.card.text.row.credits.label"), "Reserve")
        }
    }

    func testDOCK_3_8_12ScopedWindowIsCardOnlyAndNotAGeneralRing() async throws {
        try await withRenderedCard(includeScoped: true) { host, _ in
            XCTAssertEqual(text(host.card, "dock.card.text.row.quota:scoped.value"), "1%")
            let reading = try XCTUnwrap(host.dockView.presentedReadingsForChecks[memberID])
            XCTAssertEqual(reading.outer?.windowID, "five")
            XCTAssertEqual(reading.inner?.windowID, "week")
            XCTAssertNotEqual(reading.remainingPercent, 1)
        }
    }

    func testDOCK_3_8_13MissingFactsAreNotInventedInRenderedCard() async throws {
        try await withRenderedCard(missingPercentage: true) { host, _ in
            XCTAssertEqual(text(host.card, "dock.card.text.row.quota:five.value"), "--")
            XCTAssertNil(text(host.card, "dock.card.text.row.credits.value"))
        }
    }
}
