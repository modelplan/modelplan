// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanOfficialDock
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

@MainActor private final class G1DisplayEnvironment {
    let display = DockDisplayArea(id: "g1-display", frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 24, width: 1440, height: 850))
    let second = DockDisplayArea(id: "g1-second", frame: CGRect(x: 1800, y: 0, width: 1200, height: 700), visibleFrame: CGRect(x: 1800, y: 0, width: 1200, height: 700))
    var pointer = CGPoint(x: 720, y: 450)
    var presence = DockPresence()
    func sample() -> DockEdgeEnvironment {
        .init(displays: [display, second], layouts: [], primaryDisplayID: display.id, pointer: pointer, presence: presence)
    }
}

@MainActor private final class G1Clock: DockEdgeScheduling {
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

@MainActor final class G1WidgetSettingsJourneys: XCTestCase {
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
    private func open(_ environment: G1DisplayEnvironment, profile: URL, empty: Bool = false, secondMember: Bool = false, clock: G1Clock? = nil, panels: Bool = false, resetStatus: String? = nil) async throws -> EngineDockMenuApplication {
        _ = NSApplication.shared
        let fixture = try fixture(empty: empty, secondMember: secondMember, resetStatus: resetStatus)
        let configuration = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/never-launched"), applicationVersion: "g1", allowedEnvironment: [:], offline: true, readOnly: true)
        let app = EngineRowsEntry.make(configuration: configuration,
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"]),
            createsNativePanels: panels, dockEnvironment: { environment.sample() },
            deadlineNow: { Date(timeIntervalSince1970: 1_800_000_000 + (clock?.elapsed ?? 0)) },
            deadlineElapsed: clock.map { clock in { clock.elapsed } }, deadlineScheduling: clock,
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

    func testG1_DOCK_3_1_1_10() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-follow-display-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let environment = G1DisplayEnvironment()
        let app = try await open(environment, profile: profile)
        defer { app.composition.dock.close() }
        let editor = app.settingsHost.application.editor
        _ = try await editor.commit(SettingsB21Edit.dockPosition(0.35))
        _ = try await editor.commit(SettingsB21Edit.activeDisplay(true))
        let dock = app.composition.dock
        dock.refreshPresence()
        let before = try XCTUnwrap(dock.edgePresentation?.placement)
        XCTAssertEqual(before.displayID, environment.display.id)
        XCTAssertEqual(before.alongFraction, 0.35, accuracy: 0.0001)
        environment.pointer = CGPoint(x: 2400, y: 350)
        dock.refreshPresence()
        let after = try XCTUnwrap(dock.edgePresentation?.placement)
        XCTAssertEqual(after.displayID, environment.second.id)
        XCTAssertEqual(after.alongFraction, before.alongFraction, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(editor.snapshot).preferences.dockAlongFraction, 0.35, accuracy: 0.0001)
        await app.composition.stop()
    }

    func testG1_DOCK_3_1_01() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-edges-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        for (setting, expected) in [(SettingsDockEdge.left, DockEdge.left), (.right, .right), (.bottom, .bottom)] {
            let app = try await open(G1DisplayEnvironment(), profile: profile)
            _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.dockEdge(setting))
            XCTAssertEqual(app.composition.dock.edgePresentation?.placement?.edge, expected)
            await app.composition.stop(); app.composition.dock.close()
            let restored = try await open(G1DisplayEnvironment(), profile: profile)
            XCTAssertEqual(restored.composition.dock.edgePresentation?.placement?.edge, expected)
            await restored.composition.stop(); restored.composition.dock.close()
        }

        // Legacy top placement near the left corner must migrate to the closest allowed edge.
        let legacyProfile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-top-migration-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: legacyProfile) }
        let directory = legacyProfile.appendingPathComponent("ModelPlan/Native", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let legacy: [String: Any] = ["schemaVersion": 1, "preferences": ["dockEdge": "top", "dockAlongFraction": 0.1]]
        try JSONSerialization.data(withJSONObject: legacy).write(to: directory.appendingPathComponent("settings-v1.json"))
        let migrated = try await open(G1DisplayEnvironment(), profile: legacyProfile)
        XCTAssertEqual(migrated.composition.dock.edgePresentation?.placement?.edge, .left)
        await migrated.composition.stop(); migrated.composition.dock.close()
        let reopened = try await open(G1DisplayEnvironment(), profile: legacyProfile)
        defer { reopened.composition.dock.close() }
        XCTAssertEqual(reopened.composition.dock.edgePresentation?.placement?.edge, .left)
        await reopened.composition.stop()
    }

    func testG1_DOCK_3_1_09() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-medium-size-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let initial = try await open(G1DisplayEnvironment(), profile: profile)
        _ = try await initial.settingsHost.application.editor.commit(SettingsB20Edit.size(.medium))
        XCTAssertEqual(initial.composition.dock.currentMenuBarPreferences?.size, .medium)
        XCTAssertEqual(try XCTUnwrap(initial.composition.dock.dockView.requestedNozzleDiameter), 44, accuracy: 0.0001)
        await initial.composition.stop(); initial.composition.dock.close()
        let reopened = try await open(G1DisplayEnvironment(), profile: profile)
        defer { reopened.composition.dock.close() }
        XCTAssertEqual(reopened.settingsHost.application.editor.snapshot?.preferences.size, .medium)
        XCTAssertEqual(try XCTUnwrap(reopened.composition.dock.dockView.requestedNozzleDiameter), 44, accuracy: 0.0001)
        await reopened.composition.stop()
    }

    func testG1_DOCK_3_1_19() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-empty-slot-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await open(G1DisplayEnvironment(), profile: profile, empty: true)
        defer { app.composition.dock.close() }
        let dock = app.composition.dock
        func assertEmptySlot() throws {
            let skin = try XCTUnwrap(dock.dockView.presentedSkinForChecks, "The actual Dock skin must be available")
            XCTAssertEqual(skin.stations.count, 1)
            XCTAssertNil(skin.stations.first?.subscriptionID)
            XCTAssertEqual(skin.stations.first?.placeholderLabel, "?")
        }
        try assertEmptySlot()
        let client = try XCTUnwrap(app.composition.client as? G1RowsClient)
        try await client.replaceRows(fixture())
        let populated = try XCTUnwrap(dock.dockView.presentedSkinForChecks)
        XCTAssertEqual(populated.stations.compactMap(\.subscriptionID), ["0123456789abcdef"])
        try await client.replaceRows(fixture(empty: true))
        try assertEmptySlot()
        await app.composition.stop()
    }

    func testG1_DOCK_3_3_01() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-percentage-default-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await open(G1DisplayEnvironment(), profile: profile)
        defer { app.composition.dock.close() }
        let view = app.composition.dock.dockView
        XCTAssertEqual(app.settingsHost.application.editor.snapshot?.preferences.showPercentages, true)
        let station = try XCTUnwrap(view.presentedSkinForChecks?.stations.first { $0.subscriptionID == "0123456789abcdef" })
        XCTAssertEqual(station.showsReadout, true)
        XCTAssertEqual(view.presentedReadingsForChecks["0123456789abcdef"]?.readout, "41%")
        let client = try XCTUnwrap(app.composition.client as? G1RowsClient)
        try await client.replaceRows(fixture(missingReading: true))
        XCTAssertEqual(view.presentedReadingsForChecks["0123456789abcdef"]?.readout, "--")
        await app.composition.stop()
    }

    func testG1_DOCK_3_3_06() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-remaining-used-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await open(G1DisplayEnvironment(), profile: profile)
        let editor = app.settingsHost.application.editor
        XCTAssertEqual(editor.snapshot?.preferences.percentageMode, .remaining)
        XCTAssertEqual(app.composition.dock.dockView.presentedReadingsForChecks["0123456789abcdef"]?.readout, "41%")
        _ = try await editor.commit(SettingsB20Edit.percentageMode(.used))
        XCTAssertEqual(app.composition.dock.dockView.presentedReadingsForChecks["0123456789abcdef"]?.readout, "59%")
        await app.composition.stop(); app.composition.dock.close()
        let reopened = try await open(G1DisplayEnvironment(), profile: profile)
        defer { reopened.composition.dock.close() }
        XCTAssertEqual(reopened.settingsHost.application.editor.snapshot?.preferences.percentageMode, .used)
        XCTAssertEqual(reopened.composition.dock.dockView.presentedReadingsForChecks["0123456789abcdef"]?.readout, "59%")
        await reopened.composition.stop()
    }

    func testG1_DOCK_3_3_02() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-readout-position-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await open(G1DisplayEnvironment(), profile: profile)
        defer { app.composition.dock.close() }
        let editor = app.settingsHost.application.editor
        for edge in [SettingsDockEdge.left, .right, .bottom] {
            _ = try await editor.commit(SettingsB21Edit.dockEdge(edge))
            let skin = try XCTUnwrap(app.composition.dock.dockView.presentedSkinForChecks)
            let station = try XCTUnwrap(skin.stations.first { $0.subscriptionID == "0123456789abcdef" })
            XCTAssertEqual(station.showsReadout, true)
            if edge == .bottom {
                XCTAssertGreaterThan(station.readout.midX, station.centre.x, "Bottom readout must be to the right")
            } else {
                XCTAssertGreaterThan(station.readout.midY, station.centre.y, "Side readout must be below the nozzle")
            }
        }
        await app.composition.stop()
    }

    func testG1_DOCK_3_3_05() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-window-pin-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await open(G1DisplayEnvironment(), profile: profile, secondMember: true)
        let editor = app.settingsHost.application.editor
        let view = app.composition.dock.dockView
        let first = "0123456789abcdef", second = "fedcba9876543210"
        XCTAssertEqual(editor.snapshot?.preferences.subscriptionSettings[first]?.percentagePin ?? .auto, .auto)
        XCTAssertEqual(view.presentedReadingsForChecks[first]?.remainingPercent, 41)
        XCTAssertEqual(view.presentedReadingsForChecks[second]?.remainingPercent, 16)
        for (pin, expected) in [(PercentagePin.fiveHour, 41.0), (.week, 72.0), (.auto, 41.0)] {
            _ = try await editor.commit(SettingsB20Edit.percentagePin(first, pin))
            XCTAssertEqual(view.presentedReadingsForChecks[first]?.remainingPercent, expected)
            XCTAssertEqual(view.presentedReadingsForChecks[second]?.remainingPercent, 16)
        }
        _ = try await editor.commit(SettingsB20Edit.percentagePin(first, .week))
        let client = try XCTUnwrap(app.composition.client as? G1RowsClient)
        try await client.replaceRows(fixture(secondMember: true, five: 90, week: 31, secondFive: 61, secondWeek: 12))
        XCTAssertEqual(view.presentedReadingsForChecks[first]?.remainingPercent, 31)
        XCTAssertEqual(view.presentedReadingsForChecks[second]?.remainingPercent, 12)
        await app.composition.stop(); app.composition.dock.close()
        let reopened = try await open(G1DisplayEnvironment(), profile: profile, secondMember: true)
        defer { reopened.composition.dock.close() }
        XCTAssertEqual(reopened.settingsHost.application.editor.snapshot?.preferences.subscriptionSettings[first]?.percentagePin, .week)
        XCTAssertEqual(reopened.settingsHost.application.editor.snapshot?.preferences.subscriptionSettings[second]?.percentagePin ?? .auto, .auto)
        XCTAssertEqual(reopened.composition.dock.dockView.presentedReadingsForChecks[first]?.remainingPercent, 72)
        XCTAssertEqual(reopened.composition.dock.dockView.presentedReadingsForChecks[second]?.remainingPercent, 16)
        await reopened.composition.stop()
    }

    func testG1_DOCK_3_1_1_07() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-threshold-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        var app = try await open(G1DisplayEnvironment(), profile: profile)
        XCTAssertEqual(app.settingsHost.application.editor.snapshot?.preferences.redBelow, 25)
        let editor = app.settingsHost.application.editor
        let preferences = try XCTUnwrap(editor.snapshot?.preferences)
        let rows = try SettingsCatalogue.rows(preferences: preferences, context: editor.context, paneID: nil)
        let thresholdRow = try XCTUnwrap(rows.first { $0.key == .redBelow })
        guard case let .choice(selected, options) = thresholdRow.value else { return XCTFail("Threshold choices must be presented") }
        XCTAssertEqual(selected, "25")
        XCTAssertEqual(options, ["10", "16", "20", "25"])
        for threshold in [10, 16, 20, 25] {
            let editor = app.settingsHost.application.editor
            _ = try await editor.commit(SettingsB20Edit.redBelow(threshold))
            let client = try XCTUnwrap(app.composition.client as? G1RowsClient)
            for value in [threshold - 1, threshold, threshold + 1] {
                try await client.replaceRows(fixture(five: Double(value)))
                let reading = try XCTUnwrap(app.composition.dock.dockView.presentedReadingsForChecks["0123456789abcdef"])
                if value <= threshold { XCTAssertEqual(reading.status, .critical) }
                else { XCTAssertNotEqual(reading.status, .critical) }
            }
            await app.composition.stop(); app.composition.dock.close()
            app = try await open(G1DisplayEnvironment(), profile: profile)
            XCTAssertEqual(app.settingsHost.application.editor.snapshot?.preferences.redBelow, threshold)
        }
        await app.composition.stop(); app.composition.dock.close()
    }

    func testG1_DOCK_3_1_02() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-system-dock-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let environment = G1DisplayEnvironment()
        let app = try await open(environment, profile: profile)
        defer { app.composition.dock.close() }
        let screen = environment.display.frame
        let systemDock = CGRect(x: screen.minX, y: screen.minY, width: screen.width, height: 24)
        let corners = [CGRect(x: screen.minX, y: screen.minY, width: 24, height: 24),
                       CGRect(x: screen.maxX - 24, y: screen.minY, width: 24, height: 24),
                       CGRect(x: screen.minX, y: screen.maxY - 24, width: 24, height: 24),
                       CGRect(x: screen.maxX - 24, y: screen.maxY - 24, width: 24, height: 24)]
        for edge in [SettingsDockEdge.left, .right, .bottom] {
            _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.dockEdge(edge))
            let placement = try XCTUnwrap(app.composition.dock.edgePresentation?.placement)
            XCTAssertEqual(placement.displayID, environment.display.id)
            let regions = placement.globalHoverRects + [placement.wakeFrame]
            XCTAssertFalse(regions.isEmpty)
            for region in regions {
                XCTAssertFalse(region.intersects(systemDock), "Dock region intersects the synthetic system Dock")
                for corner in corners { XCTAssertFalse(region.intersects(corner), "Dock region enters a 24-pixel hot corner") }
            }
        }
        await app.composition.stop()
    }

    func testG1_DOCK_3_6_02() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-wake-zone-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let environment = G1DisplayEnvironment(), clock = G1Clock()
        let app = try await open(environment, profile: profile, clock: clock)
        defer { app.composition.dock.close() }
        let dock = app.composition.dock, editor = app.settingsHost.application.editor
        _ = try await editor.commit(SettingsB21Edit.autoHide(true))
        for size in [SettingsSize.small, .medium, .large] {
            _ = try await editor.commit(SettingsB20Edit.size(size))
            for edge in [SettingsDockEdge.left, .right, .bottom] {
                _ = try await editor.commit(SettingsB21Edit.dockEdge(edge))
                environment.pointer = CGPoint(x: 720, y: 450); dock.refreshPresence(); clock.advance(1)
                let placement = try XCTUnwrap(dock.edgePresentation?.placement)
                let wake = placement.wakeFrame, sliver = placement.sliverFrame
                if edge == .bottom {
                    XCTAssertEqual(wake.height, 20, accuracy: 0.0001)
                    XCTAssertEqual(wake.minX, sliver.minX, accuracy: 0.0001)
                    XCTAssertEqual(wake.maxX, sliver.maxX, accuracy: 0.0001)
                    environment.pointer = CGPoint(x: wake.midX, y: wake.maxY + 0.5)
                } else {
                    XCTAssertEqual(wake.width, 20, accuracy: 0.0001)
                    XCTAssertEqual(wake.minY, sliver.minY, accuracy: 0.0001)
                    XCTAssertEqual(wake.maxY, sliver.maxY, accuracy: 0.0001)
                    environment.pointer = CGPoint(x: edge == .left ? wake.maxX + 0.5 : wake.minX - 0.5, y: wake.midY)
                }
                dock.refreshPresence(); clock.advance(1)
                XCTAssertEqual(dock.edgePresentation?.state, .sliver)
                environment.pointer = CGPoint(x: wake.midX, y: wake.midY)
                dock.refreshPresence(); clock.advance(0.151)
                XCTAssertEqual(dock.edgePresentation?.state, .expanded)
                environment.pointer = CGPoint(x: 720, y: 450); dock.refreshPresence(); clock.advance(1)
                environment.pointer = edge == .bottom ? CGPoint(x: wake.maxX + 0.5, y: wake.midY) : CGPoint(x: wake.midX, y: wake.maxY + 0.5)
                dock.refreshPresence(); clock.advance(1)
                XCTAssertEqual(dock.edgePresentation?.state, .sliver)
            }
        }
        await app.composition.stop()
    }

    func testG1_DOCK_3_2_02() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-dual-rings-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await open(G1DisplayEnvironment(), profile: profile)
        defer { app.composition.dock.close() }
        let view = app.composition.dock.dockView
        let station = try XCTUnwrap(view.presentedSkinForChecks?.stations.first { $0.subscriptionID == "0123456789abcdef" })
        XCTAssertGreaterThan(station.outer.width, station.inner.width)
        XCTAssertNil(station.outer.unknownDash)
        XCTAssertNil(station.inner.unknownDash)
        let client = try XCTUnwrap(app.composition.client as? G1RowsClient)
        for (five, week, outerStatus, innerStatus) in [(25.0, 72.0, DockQuotaStatus.critical, DockQuotaStatus.normal),
                                                       (41.0, 25.0, .normal, .critical)] {
            try await client.replaceRows(fixture(five: five, week: week))
            let reading = try XCTUnwrap(view.presentedReadingsForChecks["0123456789abcdef"])
            let outer = try XCTUnwrap(reading.outer), inner = try XCTUnwrap(reading.inner)
            XCTAssertEqual(outer.windowID, "g1-five"); XCTAssertEqual(inner.windowID, "g1-week")
            XCTAssertEqual(try XCTUnwrap(outer.fraction), five / 100, accuracy: 0.0001)
            XCTAssertEqual(try XCTUnwrap(inner.fraction), week / 100, accuracy: 0.0001)
            XCTAssertEqual(outer.status, outerStatus); XCTAssertEqual(inner.status, innerStatus)
        }
        await app.composition.stop()
    }

    func testG1_DOCK_3_3_10() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-hidden-percent-event-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await open(G1DisplayEnvironment(), profile: profile, resetStatus: "announced")
        defer { app.composition.dock.close() }
        let editor = app.settingsHost.application.editor, view = app.composition.dock.dockView
        _ = try await editor.commit(SettingsB20Edit.showPercentages(false))
        for edge in [SettingsDockEdge.left, .right, .bottom] {
            _ = try await editor.commit(SettingsB21Edit.dockEdge(edge))
            let station = try XCTUnwrap(view.presentedSkinForChecks?.stations.first { $0.subscriptionID == "0123456789abcdef" })
            let notice = try XCTUnwrap(view.presentedNoticesForChecks["0123456789abcdef"])
            XCTAssertEqual(station.showsReadout, false)
            XCTAssertEqual(notice.tone, .blue)
            XCTAssertGreaterThan(station.eventRect.midX, station.centre.x)
            XCTAssertLessThan(station.eventRect.midY, station.centre.y)
        }
        await app.composition.stop()
    }

    func testG1_DOCK_3_4_03() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-announced-dot-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await open(G1DisplayEnvironment(), profile: profile, resetStatus: "announced")
        defer { app.composition.dock.close() }
        let notice = try XCTUnwrap(app.composition.dock.dockView.presentedNoticesForChecks["0123456789abcdef"])
        XCTAssertEqual(notice.key.kind, .resetAnnounced)
        XCTAssertEqual(notice.tone, .blue); XCTAssertEqual(notice.shape, .hollow)
        await app.composition.stop()
    }

    func testG1_DOCK_3_4_04() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-confirmed-dot-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await open(G1DisplayEnvironment(), profile: profile, resetStatus: "confirmed")
        defer { app.composition.dock.close() }
        let notice = try XCTUnwrap(app.composition.dock.dockView.presentedNoticesForChecks["0123456789abcdef"])
        XCTAssertEqual(notice.key.kind, .resetConfirmed)
        XCTAssertEqual(notice.tone, .blue); XCTAssertEqual(notice.shape, .solid)
        await app.composition.stop()
    }

    func testG1_DOCK_3_4_06() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-no-quota-dot-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await open(G1DisplayEnvironment(), profile: profile)
        defer { app.composition.dock.close() }
        let client = try XCTUnwrap(app.composition.client as? G1RowsClient), view = app.composition.dock.dockView
        try await client.replaceRows(fixture(five: 0))
        XCTAssertEqual(view.presentedReadingsForChecks["0123456789abcdef"]?.status, .critical)
        XCTAssertNil(view.presentedNoticesForChecks["0123456789abcdef"], "Low quota alone must not create an event dot")
        try await client.replaceRows(fixture(five: 0, resetStatus: "announced"))
        XCTAssertEqual(view.presentedNoticesForChecks["0123456789abcdef"]?.tone, .blue)
        await app.composition.stop()
    }

    func testG1_DOCK_3_4_10() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-event-size-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await open(G1DisplayEnvironment(), profile: profile, resetStatus: "announced")
        defer { app.composition.dock.close() }
        let view = app.composition.dock.dockView
        let notice = try XCTUnwrap(view.presentedNoticesForChecks["0123456789abcdef"])
        let station = try XCTUnwrap(view.presentedSkinForChecks?.stations.first { $0.subscriptionID == "0123456789abcdef" })
        XCTAssertEqual(notice.tone, .blue)
        XCTAssertEqual(station.showsReadout, true)
        XCTAssertGreaterThan(station.eventRect.midX, station.readout.midX)
        XCTAssertEqual(try XCTUnwrap(station.eventHollowDiameter), 5, accuracy: 0.0001)
        await app.composition.stop()
    }

    func testG1_DOCK_3_7_06() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-reset-truth-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await open(G1DisplayEnvironment(), profile: profile)
        defer { app.composition.dock.close() }
        let client = try XCTUnwrap(app.composition.client as? G1RowsClient), view = app.composition.dock.dockView
        func remaining() throws -> Double { try XCTUnwrap(view.presentedReadingsForChecks["0123456789abcdef"]?.outer?.fraction) }
        XCTAssertEqual(try remaining(), 0.41, accuracy: 0.0001)
        try await client.replaceRows(fixture(five: 41, resetStatus: "announced"))
        XCTAssertEqual(try remaining(), 0.41, accuracy: 0.0001)
        XCTAssertEqual(view.presentedNoticesForChecks["0123456789abcdef"]?.key.kind, .resetAnnounced)
        try await client.replaceRows(fixture(five: 41, resetStatus: "confirmed"))
        XCTAssertEqual(try remaining(), 0.41, accuracy: 0.0001)
        XCTAssertEqual(view.presentedNoticesForChecks["0123456789abcdef"]?.key.kind, .resetConfirmed)
        try await client.replaceRows(fixture(five: 88, resetStatus: "confirmed", newReading: true))
        XCTAssertEqual(try remaining(), 0.88, accuracy: 0.0001)
        XCTAssertNil(view.presentedNoticesForChecks["0123456789abcdef"])
        await app.composition.stop()
    }

    func testG1_DOCK_3_4_01() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-event-spacing-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await open(G1DisplayEnvironment(), profile: profile, secondMember: true, resetStatus: "announced")
        defer { app.composition.dock.close() }
        let view = app.composition.dock.dockView
        let stations = try XCTUnwrap(view.presentedSkinForChecks?.stations)
        let first = try XCTUnwrap(stations.first { $0.subscriptionID == "0123456789abcdef" })
        let second = try XCTUnwrap(stations.first { $0.subscriptionID == "fedcba9876543210" })
        XCTAssertNotNil(view.presentedNoticesForChecks["0123456789abcdef"])
        XCTAssertNil(view.presentedNoticesForChecks["fedcba9876543210"])
        XCTAssertEqual(view.presentedNoticesForChecks.count, 1)
        XCTAssertGreaterThan(first.eventRect.midX, first.readout.midX)
        XCTAssertEqual(first.eventRect.width, second.eventRect.width, accuracy: 0.0001)
        await app.composition.stop()
    }

    func testG1_DOCK_3_3_12() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-t2-pitch-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await open(G1DisplayEnvironment(), profile: profile, secondMember: true)
        defer { app.composition.dock.close() }
        let view = app.composition.dock.dockView
        let size = try XCTUnwrap(view.appearanceDisplaySize), skin = try XCTUnwrap(view.presentedSkinForChecks)
        let prefs = try XCTUnwrap(app.settingsHost.application.editor.snapshot?.preferences)
        let subscriptions = [T2Subscription(id: "0123456789abcdef"), T2Subscription(id: "fedcba9876543210")]
        let coords = T2EdgeCoordinates(edge: .right, width: size.width, height: size.height, menuBarExclusion: view.appearanceMenuBarExclusion)
        let geometry = try T2Geometry.make(subscriptions: subscriptions, input: .init(coordinates: coords, diameter: prefs.size.nozzleDiameter, showsPercentages: prefs.showPercentages, along: prefs.dockAlongFraction))
        XCTAssertEqual(skin.stations.count, geometry.stations.count)
        for expected in geometry.stations {
            let id = try XCTUnwrap(expected.subscription?.id)
            let actual = try XCTUnwrap(skin.stations.first { $0.subscriptionID == id })
            XCTAssertEqual(actual.centre.x, expected.centre.x, accuracy: 0.0001)
            XCTAssertEqual(actual.centre.y, expected.centre.y, accuracy: 0.0001)
            XCTAssertNotEqual(expected.pitch, 82, accuracy: 0.0001)
        }
        let expectedBounds = geometry.outline.reduce(CGRect.null) { $0.union(CGRect(origin: $1, size: .zero)) }
            .union(geometry.ignitionBounds.insetBy(dx: -4 * prefs.size.nozzleDiameter / 52, dy: -4 * prefs.size.nozzleDiameter / 52)).integral
        XCTAssertEqual(skin.bounds, expectedBounds)
        await app.composition.stop()
    }

    func testG1_DOCK_3_6_18() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-accessible-help-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await open(G1DisplayEnvironment(), profile: profile)
        defer { app.composition.dock.close() }
        let dock = app.composition.dock, view = dock.dockView
        func inspect(_ node: NSView) {
            XCTAssertNil(node.toolTip, "Dock controls must not expose native hover tooltips")
            if node is NSControl && node.isAccessibilityElement() {
                XCTAssertFalse((node.accessibilityLabel() ?? "").isEmpty, "Accessible controls need a label")
            }
            node.subviews.forEach(inspect)
        }
        inspect(try XCTUnwrap(view.superview))
        let children = try XCTUnwrap(view.accessibilityChildren()?.compactMap { $0 as? NSAccessibilityElement })
        XCTAssertFalse(children.isEmpty)
        for element in children {
            XCTAssertFalse((element.accessibilityLabel() ?? "").isEmpty)
            element.setAccessibilityFocused(true)
            inspect(view)
            element.setAccessibilityFocused(false)
        }
        try XCTUnwrap(view.nozzleEventDelegate).hoverNozzle("0123456789abcdef")
        inspect(view); inspect(dock.card)
        await app.composition.stop()
    }
}
