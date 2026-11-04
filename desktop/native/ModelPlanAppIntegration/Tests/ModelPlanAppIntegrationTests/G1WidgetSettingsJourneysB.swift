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
private actor G1BRowsClient: EngineClient {
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

@MainActor private final class G1BDisplayEnvironment {
    let display = DockDisplayArea(id: "g1-display", frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 24, width: 1440, height: 850))
    let second = DockDisplayArea(id: "g1-second", frame: CGRect(x: 1800, y: 0, width: 1200, height: 700), visibleFrame: CGRect(x: 1800, y: 0, width: 1200, height: 700))
    var pointer = CGPoint(x: 720, y: 450)
    var presence = DockPresence()
    func sample() -> DockEdgeEnvironment {
        .init(displays: [display, second], layouts: [], primaryDisplayID: display.id, pointer: pointer, presence: presence)
    }
}

@MainActor private final class G1BClock: DockEdgeScheduling {
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

@MainActor final class G1WidgetSettingsJourneysB: XCTestCase {
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
    private func open(_ environment: G1BDisplayEnvironment, profile: URL, empty: Bool = false, secondMember: Bool = false, clock: G1BClock? = nil, panels: Bool = false, resetStatus: String? = nil) async throws -> EngineDockMenuApplication {
        _ = NSApplication.shared
        let fixture = try fixture(empty: empty, secondMember: secondMember, resetStatus: resetStatus)
        let configuration = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/never-launched"), applicationVersion: "g1", allowedEnvironment: [:], offline: true, readOnly: true)
        let app = EngineRowsEntry.make(configuration: configuration,
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"]),
            createsNativePanels: panels, dockEnvironment: { environment.sample() },
            deadlineNow: { Date(timeIntervalSince1970: 1_800_000_000 + (clock?.elapsed ?? 0)) },
            deadlineElapsed: clock.map { clock in { clock.elapsed } }, deadlineScheduling: clock,
            makeClient: { _, store in G1BRowsClient(store: store, rows: fixture) }, activateSettings: {})
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        return app
    }

    func testG1_DOCK_3_1_04() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-screen-visible-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        _ = NSApplication.shared
        guard !NSScreen.screens.isEmpty else { throw XCTSkip("No native display available") }
        let configuration = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/never-launched"), applicationVersion: "g1", allowedEnvironment: [:], offline: true, readOnly: true)
        let rows = try fixture()
        let app = EngineRowsEntry.make(configuration: configuration,
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"]),
            createsNativePanels: false, makeClient: { _, store in G1BRowsClient(store: store, rows: rows) }, activateSettings: {})
        defer { app.composition.dock.close() }
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        for edge in [SettingsDockEdge.left, .right, .bottom] {
            _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.dockEdge(edge))
            let placement = try XCTUnwrap(app.composition.dock.edgePresentation?.placement)
            let screen = try XCTUnwrap(NSScreen.screens.enumerated().first { index, screen in
                let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
                return (number?.stringValue ?? "session.\(index)") == placement.displayID
            }?.element)
            XCTAssertTrue(screen.visibleFrame.contains(placement.frame), "The painted Dock must remain in NSScreen.visibleFrame")
            XCTAssertTrue(screen.visibleFrame.contains(placement.sliverFrame))
            XCTAssertTrue(screen.visibleFrame.contains(placement.wakeFrame))
        }
        await app.composition.stop()
    }

    func testG1_DOCK_3_1_08() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-dock-sizes-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await open(G1BDisplayEnvironment(), profile: profile)
        defer { app.composition.dock.close() }
        let editor = app.settingsHost.application.editor, view = app.composition.dock.dockView
        XCTAssertEqual(editor.snapshot?.preferences.size, .medium)
        XCTAssertEqual(try XCTUnwrap(view.requestedNozzleDiameter), 44, accuracy: 0.0001)
        for (size, diameter) in [(SettingsSize.small, CGFloat(36)), (.medium, 44), (.large, 52)] {
            _ = try await editor.commit(SettingsB20Edit.size(size))
            XCTAssertEqual(try XCTUnwrap(view.requestedNozzleDiameter), diameter, accuracy: 0.0001)
            let station = try XCTUnwrap(view.presentedSkinForChecks?.stations.first { $0.subscriptionID == "0123456789abcdef" })
            XCTAssertEqual(station.diameter, diameter, accuracy: 0.0001)
        }
        XCTAssertEqual(SettingsSize.allCases.count, 3)
        await app.composition.stop()
    }

    func testG1_DOCK_3_1_1_05() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-follow-default-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let environment = G1BDisplayEnvironment()
        let app = try await open(environment, profile: profile)
        defer { app.composition.dock.close() }
        XCTAssertEqual(app.settingsHost.application.editor.snapshot?.preferences.followActiveDisplay, false)
        XCTAssertEqual(app.composition.dock.edgePresentation?.placement?.displayID, environment.display.id)
        environment.pointer = CGPoint(x: environment.second.frame.midX, y: environment.second.frame.midY)
        app.composition.dock.refreshPresence()
        XCTAssertEqual(app.composition.dock.edgePresentation?.placement?.displayID, environment.display.id)
        await app.composition.stop()
    }

    func testG1_DOCK_3_1_1_12() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-first-widget-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let environment = G1BDisplayEnvironment(), clock = G1BClock()
        let app = try await open(environment, profile: profile, clock: clock)
        defer { app.composition.dock.close() }
        let preferences = try XCTUnwrap(app.settingsHost.application.editor.snapshot?.preferences)
        XCTAssertTrue(preferences.showDock)
        XCTAssertFalse(preferences.autoHide)
        environment.pointer = CGPoint(x: 720, y: 450)
        app.composition.dock.refreshPresence(); clock.advance(5)
        let presentation = try XCTUnwrap(app.composition.dock.edgePresentation)
        XCTAssertEqual(presentation.state, .expanded)
        XCTAssertEqual(presentation.placement?.displayID, environment.display.id)
        XCTAssertEqual(presentation.placement?.edge, .right)
        await app.composition.stop()
    }

    func testG1_DOCK_3_1_12() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-readout-box-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await open(G1BDisplayEnvironment(), profile: profile)
        defer { app.composition.dock.close() }
        let editor = app.settingsHost.application.editor, view = app.composition.dock.dockView
        let client = try XCTUnwrap(app.composition.client as? G1BRowsClient)
        for edge in [SettingsDockEdge.left, .right, .bottom] {
            _ = try await editor.commit(SettingsB21Edit.dockEdge(edge))
            for (size, diameter) in [(SettingsSize.small, CGFloat(36)), (.medium, 44), (.large, 52)] {
                _ = try await editor.commit(SettingsB20Edit.size(size))
                let station = try XCTUnwrap(view.presentedSkinForChecks?.stations.first { $0.subscriptionID == "0123456789abcdef" })
                XCTAssertEqual(station.readout.width, 56 * diameter / 52, accuracy: 0.0001)
                XCTAssertEqual(station.readout.height, 16 * diameter / 52, accuracy: 0.0001)
                XCTAssertGreaterThan(station.eventRect.width, 0, "The event slot remains reserved without an event")
                XCTAssertNil(view.presentedNoticesForChecks["0123456789abcdef"])
                try await client.replaceRows(fixture(resetStatus: "announced"))
                XCTAssertNotNil(view.presentedNoticesForChecks["0123456789abcdef"])
                let withEvent = try XCTUnwrap(view.presentedSkinForChecks?.stations.first { $0.subscriptionID == "0123456789abcdef" })
                XCTAssertEqual(withEvent.readout, station.readout)
                XCTAssertEqual(withEvent.eventRect, station.eventRect)
                try await client.replaceRows(fixture())
            }
        }
        await app.composition.stop()
    }

    func testG1_DOCK_3_1_1_02() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-autohide-default-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let environment = G1BDisplayEnvironment(), clock = G1BClock()
        let app = try await open(environment, profile: profile, clock: clock)
        defer { app.composition.dock.close() }
        XCTAssertEqual(app.settingsHost.application.editor.snapshot?.preferences.autoHide, false)
        environment.pointer = CGPoint(x: 720, y: 450)
        app.composition.dock.refreshPresence()
        clock.advance(5)
        XCTAssertEqual(app.composition.dock.edgePresentation?.state, .expanded)
        await app.composition.stop()
    }

    // TODO(G1): enable only after the normal-entry native-panel path accepts an
    // isolated notification-ledger location; never read a user's live ledger.
    #if G1_ISOLATED_NATIVE_PANEL_ENTRY
    func testG1_DOCK_3_1_03() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-no-floating-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let environment = G1BDisplayEnvironment(), clock = G1BClock()
        let app = try await open(environment, profile: profile, clock: clock, panels: true)
        let dock = app.composition.dock, panel = try XCTUnwrap(dock.nativePanel), view = dock.dockView
        clock.advance(1)
        let candidates = stride(from: CGFloat(1), to: view.bounds.width, by: 4).flatMap { x in
            stride(from: CGFloat(1), to: view.bounds.height, by: 4).map { CGPoint(x: x, y: $0) }
        }
        let start = try XCTUnwrap(candidates.first { view.backgroundDragDelegate?.backgroundCanDrag(local: $0) == true })
        let origin = panel.convertPoint(toScreen: view.convert(start, to: nil))
        let destination = CGPoint(x: 720, y: 450)
        func event(_ type: NSEvent.EventType, at point: CGPoint) throws -> NSEvent {
            try XCTUnwrap(NSEvent.mouseEvent(with: type, location: panel.convertPoint(fromScreen: point), modifierFlags: [], timestamp: clock.elapsed, windowNumber: panel.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: type == .leftMouseDown ? 1 : 0))
        }
        environment.pointer = origin; environment.presence.mouseButtonDown = true
        view.mouseDown(with: try event(.leftMouseDown, at: origin))
        environment.pointer = destination
        view.mouseDragged(with: try event(.leftMouseDragged, at: destination))
        environment.presence.mouseButtonDown = false
        view.mouseUp(with: try event(.leftMouseUp, at: destination))
        for _ in 0..<100 { if !app.settingsHost.application.editor.isSaving { await Task.yield() } }
        let placed = try XCTUnwrap(dock.edgePresentation?.placement)
        XCTAssertTrue([DockEdge.left, .right, .bottom].contains(placed.edge))
        let usable = environment.display.usableFrame
        switch placed.edge {
        case .left: XCTAssertEqual(placed.frame.minX, usable.minX, accuracy: 0.0001)
        case .right: XCTAssertEqual(placed.frame.maxX, usable.maxX, accuracy: 0.0001)
        case .bottom: XCTAssertEqual(placed.frame.minY, usable.minY, accuracy: 0.0001)
        case .top: XCTFail("A floating or top-edge Dock is not allowed")
        }
        await app.composition.stop(); dock.close()
        let reopened = try await open(environment, profile: profile)
        defer { reopened.composition.dock.close() }
        let restored = try XCTUnwrap(reopened.composition.dock.edgePresentation?.placement)
        XCTAssertEqual(restored.edge, placed.edge)
        XCTAssertTrue([DockEdge.left, .right, .bottom].contains(restored.edge))
        await reopened.composition.stop()
    }

    func testG1_DOCK_3_1_1_06() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-edge-snap-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let environment = G1BDisplayEnvironment(), clock = G1BClock()
        let app = try await open(environment, profile: profile, clock: clock, panels: true)
        defer { app.composition.dock.close() }
        let editor = app.settingsHost.application.editor
        let prefs = try XCTUnwrap(editor.snapshot?.preferences)
        let rows = try SettingsCatalogue.rows(preferences: prefs, context: editor.context, paneID: nil)
        XCTAssertFalse(rows.contains { $0.key.rawValue.lowercased().contains("snap") }, "There must be no snap-disable setting")
        let dock = app.composition.dock, panel = try XCTUnwrap(dock.nativePanel), view = dock.dockView
        clock.advance(1)
        for (destination, expected) in [(CGPoint(x: 1, y: 450), DockEdge.left),
                                        (CGPoint(x: 1439, y: 450), .right),
                                        (CGPoint(x: 720, y: 25), .bottom)] {
            let candidates = stride(from: CGFloat(1), to: view.bounds.width, by: 4).flatMap { x in
                stride(from: CGFloat(1), to: view.bounds.height, by: 4).map { CGPoint(x: x, y: $0) }
            }
            let local = try XCTUnwrap(candidates.first { view.backgroundDragDelegate?.backgroundCanDrag(local: $0) == true })
            let start = panel.convertPoint(toScreen: view.convert(local, to: nil))
            func event(_ type: NSEvent.EventType, _ point: CGPoint) throws -> NSEvent {
                try XCTUnwrap(NSEvent.mouseEvent(with: type, location: panel.convertPoint(fromScreen: point), modifierFlags: [], timestamp: clock.elapsed, windowNumber: panel.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: type == .leftMouseDown ? 1 : 0))
            }
            environment.pointer = start; environment.presence.mouseButtonDown = true
            view.mouseDown(with: try event(.leftMouseDown, start))
            environment.pointer = destination; view.mouseDragged(with: try event(.leftMouseDragged, destination))
            environment.presence.mouseButtonDown = false; view.mouseUp(with: try event(.leftMouseUp, destination))
            for _ in 0..<100 { await Task.yield() }
            XCTAssertEqual(dock.edgePresentation?.placement?.edge, expected)
            clock.advance(1)
        }
        await app.composition.stop()
    }
    #endif

    // TODO(G1): enable after M2's quotaSegmentColorRolesForChecks seam lands.
    #if G1_SLIVER_COLOUR_SEAM
    func testG1_DOCK_3_1_1_03() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-sliver-alert-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let environment = G1BDisplayEnvironment(), clock = G1BClock()
        let app = try await open(environment, profile: profile, clock: clock)
        defer { app.composition.dock.close() }
        let dock = app.composition.dock
        XCTAssertEqual(app.settingsHost.application.editor.snapshot?.preferences.sliverAlert, true)
        _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.autoHide(true))
        environment.pointer = CGPoint(x: 720, y: 450)
        dock.refreshPresence(); clock.advance(1)
        XCTAssertEqual(dock.edgePresentation?.state, .sliver)
        let client = try XCTUnwrap(app.composition.client as? G1BRowsClient)
        for (percent, role) in [(41.0, "normal"), (40.0, "warning"), (25.0, "critical")] {
            try await client.replaceRows(fixture(five: percent, week: 72))
            let skin = try XCTUnwrap(dock.dockView.presentedSkinForChecks)
            let ink = try XCTUnwrap(skin.palette[role])
            let expected = String(format: "#%02X%02X%02X%02X", Int((ink.r * 255).rounded()), Int((ink.g * 255).rounded()), Int((ink.b * 255).rounded()), Int((ink.a * 255).rounded()))
            let placement = try XCTUnwrap(dock.edgePresentation?.placement)
            let sliver = try dock.prepareSliver(size: placement.sliverFrame.size)
            let actual = sliver.quotaSegmentColorRolesForChecks.map(\.rgbaHex)
            XCTAssertTrue(actual.contains(expected), "Expected the single member's \(role) quota colour in the actual sliver")
        }
        await app.composition.stop()
    }
    #endif
}
