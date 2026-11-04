// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
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
    let display = DockDisplayArea(id: "g1-display", frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 900))
    let second = DockDisplayArea(id: "g1-second", frame: CGRect(x: 1800, y: 0, width: 1200, height: 700), visibleFrame: CGRect(x: 1800, y: 0, width: 1200, height: 700))
    var pointer = CGPoint(x: 720, y: 450)
    var presence = DockPresence()
    func sample() -> DockEdgeEnvironment {
        .init(displays: [display, second], layouts: [], primaryDisplayID: display.id, pointer: pointer, presence: presence)
    }
}

@MainActor final class G1WidgetSettingsJourneys: XCTestCase {
    private func fixture(empty: Bool = false, missingReading: Bool = false, secondMember: Bool = false,
                         five: Double = 41, week: Double = 72, secondFive: Double = 16, secondWeek: Double = 89) throws -> WireRowsSnapshot {
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
        accounts[0]["windows"] = windows
        if secondMember {
            var second = accounts[0]
            second["subscriptionRef"] = "fedcba9876543210"; second["accountLocator"] = "fedcba9876543210"
            var secondWindows = windows
            secondWindows[0]["remainingPercent"] = secondFive; secondWindows[1]["remainingPercent"] = secondWeek
            second["windows"] = secondWindows; accounts.append(second)
        }
        rows[0]["accounts"] = accounts
        projection["rows"] = empty ? [] : rows; projection.removeValue(forKey: "resetEvents"); root["projection"] = projection
        return try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
    }
    private func open(_ environment: G1DisplayEnvironment, profile: URL, empty: Bool = false, secondMember: Bool = false) async throws -> EngineDockMenuApplication {
        _ = NSApplication.shared
        let fixture = try fixture(empty: empty, secondMember: secondMember)
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
}
