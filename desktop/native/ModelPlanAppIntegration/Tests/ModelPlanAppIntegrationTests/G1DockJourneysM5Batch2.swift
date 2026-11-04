// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanOfficialDock
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
@_spi(DockResourceChecks) @testable import ModelPlanAppIntegration

// Only the engine transport is synthetic. Settings, the production entry and
// the Dock's retained presentation and visibility controllers remain real.
private actor G1CRowsClient: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore
    let rows: WireRowsSnapshot
    var revision: UInt64 = 1
    let context = EngineDeliveryContext(sessionID: "g1-synthetic", floor: .init(storeEpoch: "g1-synthetic", generation: 1), revision: 1)
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context)))
        await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context), invalidRowCount: rows.projection.invalidRowCount))
        return context
    }
    func stop() async {}
    func replaceRows(_ replacement: WireRowsSnapshot) async throws {
        revision += 1
        let next = EngineDeliveryContext(sessionID: context.sessionID, floor: context.floor, revision: revision)
        await store.consume(.connection(.ready(next)))
        await store.consume(.context(next))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: next.sessionID, storeEpoch: next.floor.storeEpoch, consentGeneration: 1, data: replacement), delivery: next), invalidRowCount: replacement.projection.invalidRowCount))
    }
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

@MainActor private final class G1CDisplayEnvironment {
    let display = DockDisplayArea(id: "g1-display", frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 24, width: 1440, height: 850))
    let second = DockDisplayArea(id: "g1-second", frame: CGRect(x: 1800, y: 0, width: 1200, height: 700), visibleFrame: CGRect(x: 1800, y: 0, width: 1200, height: 700))
    var pointer = CGPoint(x: 720, y: 450)
    var presence = DockPresence()
    func sample() -> DockEdgeEnvironment {
        .init(displays: [display, second], layouts: [], primaryDisplayID: display.id, pointer: pointer, presence: presence)
    }
}

@MainActor private final class G1CClock: DockEdgeScheduling {
    var elapsed: TimeInterval = 0
    var deadline: TimeInterval?
    var action: (@MainActor () -> Void)?
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) { self.deadline = deadline; self.action = action }
    func cancel() { deadline = nil; action = nil }
    func advance(_ seconds: TimeInterval) {
        elapsed += seconds
        if let deadline, deadline <= elapsed { let next = action; cancel(); next?() }
    }
}

@MainActor final class G1DockJourneysM5Batch2: XCTestCase {
    private func fixture(empty: Bool = false, missingReading: Bool = false, secondMember: Bool = false,
                         five: Double = 41, week: Double = 72, secondFive: Double = 16, secondWeek: Double = 89,
                         resetStatus: String? = nil, newReading: Bool = false) throws -> WireRowsSnapshot {
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(root["projection"] as? [String: Any])
        var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
        rows[0]["state"] = "fresh"; rows[0]["consent"] = "allowed"
        rows[0]["surfaces"] = ["dock", "menu"]; rows[0]["expiresAt"] = "2099-01-01T00:00:00Z"
        var accounts = try XCTUnwrap(rows[0]["accounts"] as? [[String: Any]])
        accounts[0]["valueState"] = "current"; accounts[0]["freshUntil"] = "2099-01-01T00:00:00Z"
        var windows = try XCTUnwrap(accounts[0]["windows"] as? [[String: Any]])
        windows[0].removeValue(forKey: "modelScope"); windows[0]["current"] = true
        windows[0]["id"] = "g1-five"; windows[0]["durationSeconds"] = 18000
        windows[0]["role"] = "session"; windows[0]["limitKey"] = "five_hour"; windows[0]["poolKey"] = "main"
        windows[0]["remainingPercent"] = missingReading ? nil : five
        windows[0]["validUntil"] = "2099-01-01T00:00:00Z"; windows[0]["resetsAt"] = "2099-01-01T00:00:00Z"
        var weekly = windows[0]
        weekly["id"] = "g1-week"; weekly["role"] = "weekly"; weekly["limitKey"] = "weekly"
        weekly["durationSeconds"] = 604800; weekly["remainingPercent"] = missingReading ? nil : week
        windows = [windows[0], weekly]
        if newReading {
            let observed = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: 1_800_000_000))
            accounts[0]["observedAt"] = observed
            for index in windows.indices { windows[index]["observedAt"] = observed }
        }
        accounts[0]["windows"] = windows
        if secondMember {
            var second = accounts[0]
            second["subscriptionRef"] = "fedcba9876543210"; second["accountLocator"] = "fedcba9876543210"
            var plan = try XCTUnwrap(second["plan"] as? [String: Any]); plan["id"] = "g1-other"; second["plan"] = plan
            var secondWindows = windows
            secondWindows[0]["remainingPercent"] = secondFive; secondWindows[1]["remainingPercent"] = secondWeek
            second["windows"] = secondWindows; accounts.append(second)
        }
        rows[0]["accounts"] = accounts
        projection["rows"] = empty ? [] : rows
        if let resetStatus {
            let path = capture.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("proposals/fixtures/app-journey-plan-scoped.json")
            let document = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
            let result = try XCTUnwrap(document["result"] as? [String: Any])
            let data = try XCTUnwrap(result["data"] as? [String: Any])
            let source = try XCTUnwrap(data["projection"] as? [String: Any])
            var event = try XCTUnwrap((source["resetEvents"] as? [[String: Any]])?.first)
            let now = Date(timeIntervalSince1970: 1_800_000_000), format = ISO8601DateFormatter()
            event["rowId"] = "codex"; event["planIds"] = ["codex"]
            event["publishedAt"] = format.string(from: now.addingTimeInterval(-60))
            event["expiresAt"] = format.string(from: now.addingTimeInterval(3600))
            event["schedule"] = ["precision": "window", "from": format.string(from: now), "through": format.string(from: now.addingTimeInterval(3600))]
            if resetStatus == "confirmed" {
                var confirmation = event
                confirmation["status"] = "confirmed"; confirmation["confirms"] = event["id"]
                confirmation["publishedAt"] = format.string(from: now.addingTimeInterval(-1))
                projection["resetEvents"] = [event, confirmation]
            } else { projection["resetEvents"] = [event] }
        } else { projection.removeValue(forKey: "resetEvents") }
        root["projection"] = projection
        return try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
    }
    private func open(_ environment: G1CDisplayEnvironment, profile: URL, empty: Bool = false, secondMember: Bool = false, clock: G1CClock? = nil, panels: Bool = false, resetStatus: String? = nil) async throws -> EngineDockMenuApplication {
        _ = NSApplication.shared
        let fixture = try fixture(empty: empty, secondMember: secondMember, resetStatus: resetStatus)
        let configuration = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/never-launched"), applicationVersion: "g1", allowedEnvironment: [:], offline: true, readOnly: true)
        let app = EngineRowsEntry.make(configuration: configuration,
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"]),
            createsNativePanels: panels, dockEnvironment: { environment.sample() },
            deadlineNow: { Date(timeIntervalSince1970: 1_800_000_000 + (clock?.elapsed ?? 0)) },
            deadlineElapsed: clock.map { clock in { clock.elapsed } }, deadlineScheduling: clock,
            makeClient: { _, store in G1CRowsClient(store: store, rows: fixture) }, activateSettings: {})
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        return app
    }

    func testG1_DOCK_3_1_23() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-ignition-position-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await open(G1CDisplayEnvironment(), profile: profile, secondMember: true)
        defer { app.composition.dock.close() }
        let dock = app.composition.dock, editor = app.settingsHost.application.editor
        for edge in [SettingsDockEdge.left, .right, .bottom] {
            _ = try await editor.commit(SettingsB21Edit.dockEdge(edge))
            for size in [SettingsSize.small, .medium, .large] {
                _ = try await editor.commit(SettingsB20Edit.size(size))
                let skin = try XCTUnwrap(dock.dockView.presentedSkinForChecks)
                let button = try XCTUnwrap(dock.registeredConsoleButtonForChecks)
                let stations = skin.stations.filter { $0.subscriptionID != nil }
                XCTAssertEqual(stations.count, 2)
                for station in stations {
                    let local = CGPoint(x: station.centre.x - skin.bounds.minX, y: station.centre.y - skin.bounds.minY)
                    if edge == .bottom { XCTAssertGreaterThan(button.midX, local.x) }
                    else { XCTAssertLessThan(button.midY, local.y) }
                }
            }
        }
        await app.composition.stop()
    }
}
