// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings
import ModelPlanWire
@testable import ModelPlanAppIntegration

/// Delivers one rows frame and then stays silent: no further engine frames.
private actor TickSilentClient: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore, rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "tick-synthetic", floor: .init(storeEpoch: "tick-synthetic", generation: 1), revision: 1)
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch,
            consentGeneration: 1, data: rows), delivery: context), invalidRowCount: rows.projection.invalidRowCount))
        return context
    }
    func stop() async {}
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("tick-rows")) }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

/// The production deadline scheduler, replaced by a manual clock: fires only what is due.
@MainActor private final class TickTimer: DockEdgeScheduling {
    private var armed: (deadline: TimeInterval, action: @MainActor () -> Void)?
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) { armed = (deadline, action) }
    func cancel() { armed = nil }
    func fireIfDue(_ elapsed: TimeInterval) {
        guard let armed, armed.deadline <= elapsed else { return }
        self.armed = nil; armed.action()
    }
}

/// From #496 (60-second presentation refresh): countdowns and the expired state advance on the
/// widget while the engine sends no new frame and nothing else (hover, menu, input) happens.
@MainActor final class DockPresentationTickTests: XCTestCase {
    func testCountdownAdvancesEveryMinuteAndExpiryLandsWithoutNewData() async throws {
        _ = NSApplication.shared
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("tick-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        var wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-01-01T00:00:00Z")), elapsed = 0.0
        let iso = ISO8601DateFormatter()
        func stamp(_ offset: TimeInterval) -> String { iso.string(from: wall.addingTimeInterval(offset)) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(root["projection"] as? [String: Any])
        var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
        var row = rows[0], accounts = try XCTUnwrap(row["accounts"] as? [[String: Any]])
        var account = accounts[0], windows = try XCTUnwrap(account["windows"] as? [[String: Any]])
        // The reading is valid for 150 s; its 5-hour window resets in 3 hours.
        row["id"] = "codex"; row["state"] = "fresh"; row["consent"] = "allowed"; row["surfaces"] = ["dock"]
        row["expiresAt"] = stamp(150); row["refreshNotBefore"] = stamp(0)
        row["reason"] = ["code": "ok", "text": ["en": "Reading available", "zh": "读数可用"]]
        account["subscriptionRef"] = "aaaaaaaaaaaaaaaa"; account["valueState"] = "current"
        account["observedAt"] = stamp(-60); account["freshUntil"] = stamp(150); account["lastFailure"] = NSNull()
        account.removeValue(forKey: "resetCards")
        windows[0].removeValue(forKey: "modelScope"); windows[0]["current"] = true
        windows[0]["durationSeconds"] = 18_000; windows[0]["resetsAt"] = stamp(3 * 3600)
        windows[0]["observedAt"] = stamp(-60); windows[0]["validUntil"] = stamp(150); windows[0]["remainingPercent"] = 42.0
        account["windows"] = [windows[0]]; row["accounts"] = [account]; rows[0] = row
        projection["rows"] = rows; projection.removeValue(forKey: "resetEvents"); root["projection"] = projection
        let snapshot = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        let display = DockDisplayArea(id: "synthetic", frame: .init(x: 0, y: 0, width: 1440, height: 900), visibleFrame: .init(x: 0, y: 80, width: 1440, height: 820))
        let timer = TickTimer()
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true),
            settingsStore: settings, createsNativePanels: false,
            dockEnvironment: { .init(displays: [display], layouts: [], primaryDisplayID: "synthetic", pointer: CGPoint(x: 700, y: 450)) },
            deadlineNow: { wall }, deadlineElapsed: { elapsed }, deadlineScheduling: timer,
            makeClient: { _, store in TickSilentClient(store: store, rows: snapshot) }, activateSettings: {})
        defer { app.composition.dock.close() }
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        let id = "aaaaaaaaaaaaaaaa", view = app.composition.dock.dockView
        let sequence = app.composition.store.snapshot.rows?.sequence
        func reading() throws -> DockInstrumentReading { try XCTUnwrap(view.presentedReadingsForChecks[id]) }
        func advance(_ seconds: TimeInterval) {
            wall.addTimeInterval(seconds); elapsed += seconds
            timer.fireIfDue(elapsed) // No hover, menu, refreshPresence or engine frame.
        }
        let initial = try XCTUnwrap(try reading().timeLeftFraction)
        XCTAssertEqual(try reading().dataState, .fresh)

        advance(61)
        let minuteLater = try XCTUnwrap(try reading().timeLeftFraction)
        XCTAssertLessThan(minuteLater, initial, "The rendered countdown must advance within a minute without new data")
        XCTAssertEqual(try reading().dataState, .fresh)
        advance(61)
        XCTAssertLessThan(try XCTUnwrap(try reading().timeLeftFraction), minuteLater, "and keep advancing every minute")

        advance(40) // past validUntil (150 s)
        XCTAssertNotEqual(try reading().dataState, .fresh, "The expired state lands without a new engine frame")
        XCTAssertNil(try reading().remainingPercent, "An expired reading is never shown as a current percentage")
        XCTAssertEqual(app.composition.store.snapshot.rows?.sequence, sequence, "no engine frame was involved")
        await app.composition.stop()
    }
}
