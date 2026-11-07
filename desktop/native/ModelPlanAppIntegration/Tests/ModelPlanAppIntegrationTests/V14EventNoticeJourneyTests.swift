// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings
import ModelPlanWire
@testable import ModelPlanAppIntegration

private actor V14RowsClient: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore, rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "v14-synthetic", floor: .init(storeEpoch: "v14-synthetic", generation: 1), revision: 1)
    var revision: UInt64 = 1
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context)))
        await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context), invalidRowCount: rows.projection.invalidRowCount))
        return context
    }
    func replaceRows(_ rows: WireRowsSnapshot) async throws {
        revision += 1
        let next = EngineDeliveryContext(sessionID: context.sessionID, floor: context.floor, revision: revision)
        await store.consume(.connection(.ready(next)))
        await store.consume(.context(next))
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

@MainActor final class V14EventNoticeJourneyTests: XCTestCase {
    func testV14NormalEntryAnnouncedEventHasFivePointHollowDot() async throws {
        _ = NSApplication.shared
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/proposals/fixtures/app-journey-plan-scoped.json").standardizedFileURL
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: fixture)) as? [String: Any])
        let result = try XCTUnwrap(document["result"] as? [String: Any])
        var data = try XCTUnwrap(result["data"] as? [String: Any])
        var projection = try XCTUnwrap(data["projection"] as? [String: Any])
        var events = try XCTUnwrap(projection["resetEvents"] as? [[String: Any]])
        XCTAssertFalse(events.isEmpty)
        guard !events.isEmpty else { return }
        let now = Date(), formatter = ISO8601DateFormatter()
        events[0]["publishedAt"] = formatter.string(from: now.addingTimeInterval(-60))
        events[0]["expiresAt"] = formatter.string(from: now.addingTimeInterval(3600))
        events[0]["schedule"] = ["precision": "window", "from": formatter.string(from: now), "through": formatter.string(from: now.addingTimeInterval(3600))]
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let captureRoot = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        let captureProjection = try XCTUnwrap(captureRoot["projection"] as? [String: Any])
        let captureRows = try XCTUnwrap(captureProjection["rows"] as? [[String: Any]])
        let captureRow = try XCTUnwrap(captureRows.first)
        let captureAccounts = try XCTUnwrap(captureRow["accounts"] as? [[String: Any]])
        let captureAccount = try XCTUnwrap(captureAccounts.first)
        let captureWindows = try XCTUnwrap(captureAccount["windows"] as? [[String: Any]])
        var lowWindow = try XCTUnwrap(captureWindows.first)
        lowWindow.removeValue(forKey: "modelScope")
        lowWindow["limitKey"] = "main"; lowWindow["poolKey"] = "main"; lowWindow["current"] = true
        lowWindow["remainingPercent"] = 10
        lowWindow["observedAt"] = formatter.string(from: now.addingTimeInterval(-60))
        lowWindow["validUntil"] = formatter.string(from: now.addingTimeInterval(3600))
        lowWindow["resetsAt"] = formatter.string(from: now.addingTimeInterval(3600))
        var fixtureRows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
        guard !fixtureRows.isEmpty else { return XCTFail("V-14: synthetic row missing") }
        var accounts = try XCTUnwrap(fixtureRows[0]["accounts"] as? [[String: Any]])
        guard accounts.count >= 2 else { return XCTFail("V-14: synthetic control member missing") }
        accounts[1]["valueState"] = "current"; accounts[1]["observedAt"] = formatter.string(from: now.addingTimeInterval(-60))
        accounts[1]["freshUntil"] = formatter.string(from: now.addingTimeInterval(3600)); accounts[1]["windows"] = [lowWindow]
        fixtureRows[0]["state"] = "fresh"; fixtureRows[0]["expiresAt"] = formatter.string(from: now.addingTimeInterval(3600))
        fixtureRows[0]["accounts"] = accounts; projection["rows"] = fixtureRows
        projection["resetEvents"] = events; data["projection"] = projection
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: data))
        projection["resetEvents"] = []; data["projection"] = projection
        let withoutEvents = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: data))
        XCTAssertEqual(rows.projection.invalidRowCount, 0)
        XCTAssertEqual(withoutEvents.projection.invalidRowCount, 0)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("v14-event-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let settings = try SettingsStore(url: directory.appendingPathComponent("settings.json"))
        let display = DockDisplayArea(id: "synthetic", frame: .init(x: 0, y: 0, width: 1440, height: 900), visibleFrame: .init(x: 0, y: 80, width: 1440, height: 820))
        let entry = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true), settingsStore: settings, createsNativePanels: false, dockEnvironment: { .init(displays: [display], layouts: [], primaryDisplayID: "synthetic", pointer: CGPoint(x: 700, y: 450)) }, deadlineNow: { now }, makeClient: { _, store in V14RowsClient(store: store, rows: withoutEvents) }, activateSettings: {})
        entry.composition.currentDate = { now }
        defer { entry.composition.dock.close() }
        await entry.prepare(); entry.allowDockPresentation(); await entry.composition.start()
        let view = entry.composition.dock.dockView
        _ = try XCTUnwrap(view.presentedSkinForChecks, "V-14: no-event control must inspect an active rendered skin")
        XCTAssertNil(view.presentedNoticesForChecks["0123456789abcdef"], "V-14: no event must not create a notice")
        let lowReading = try XCTUnwrap(view.presentedReadingsForChecks["fedcba9876543210"])
        XCTAssertEqual(lowReading.status, .critical, "V-14: the control must really be low quota")
        XCTAssertNil(view.presentedNoticesForChecks["fedcba9876543210"], "V-14: low quota alone is not an event")
        let client = try XCTUnwrap(entry.composition.client as? V14RowsClient)
        try await client.replaceRows(rows)
        let notice = try XCTUnwrap(view.presentedNoticesForChecks["0123456789abcdef"])
        XCTAssertNil(view.presentedNoticesForChecks["fedcba9876543210"], "V-14: another member's event must not create a notice on the low-quota control")
        XCTAssertEqual(notice.key.kind, .resetAnnounced)
        XCTAssertEqual(notice.tone, .blue)
        XCTAssertEqual(notice.shape, .hollow)
        let skin = try XCTUnwrap(view.presentedSkinForChecks)
        let station = try XCTUnwrap(skin.stations.first { $0.subscriptionID == "0123456789abcdef" })
        let diameter = try XCTUnwrap(station.eventHollowDiameter)
        XCTAssertEqual(diameter, 5 * station.diameter / 52, accuracy: 0.000001, "V-14: announced dot outer diameter at the reference scale")

        let announcedID = try XCTUnwrap(events[0]["id"] as? String)
        var confirmed = events[0]
        confirmed["status"] = "confirmed"
        confirmed["confirms"] = announcedID
        let confirmedAt = now.addingTimeInterval(-1)
        confirmed["publishedAt"] = formatter.string(from: confirmedAt)
        confirmed["expiresAt"] = formatter.string(from: confirmedAt.addingTimeInterval(24 * 3600))
        confirmed.removeValue(forKey: "schedule")
        projection["resetEvents"] = [confirmed]; data["projection"] = projection
        let confirmedRows = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: data))
        try await client.replaceRows(confirmedRows)
        let confirmedNotice = try XCTUnwrap(view.presentedNoticesForChecks["0123456789abcdef"])
        XCTAssertEqual(confirmedNotice.key.kind, .resetConfirmed)
        XCTAssertEqual(confirmedNotice.tone, .blue)
        XCTAssertEqual(confirmedNotice.shape, .solid)
        XCTAssertNil(view.presentedNoticesForChecks["fedcba9876543210"], "V-14: another member's confirmation must not create a notice on the low-quota control")
        let confirmedSkin = try XCTUnwrap(view.presentedSkinForChecks)
        let confirmedStation = try XCTUnwrap(confirmedSkin.stations.first { $0.subscriptionID == "0123456789abcdef" })
        XCTAssertEqual(try XCTUnwrap(confirmedStation.eventSolidDiameter), 5 * confirmedStation.diameter / 52, accuracy: 0.000001, "V-14: confirmed dot outer diameter at the reference scale")
        await entry.composition.stop()
    }
}
