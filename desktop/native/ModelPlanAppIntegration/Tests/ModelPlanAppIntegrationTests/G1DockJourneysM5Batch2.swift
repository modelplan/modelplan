// SPDX-License-Identifier: MIT
import AppKit
import CryptoKit
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanOfficialDock
import ModelPlanDockResources
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
@_spi(DockResourceChecks) @testable import ModelPlanAppIntegration

// Only the engine transport is synthetic. Settings, the production entry and
// the Dock's retained presentation and visibility controllers remain real.
// Pending read-only inspection/injection seams, named here for the owning lane:
// DOCK-3.1.1-09: EngineRowsEntry isolatedNativeNotificationLedgerForChecks.
// DOCK-3.1.1-11: StaticDockPreviewHost workingEffectFramesForChecks.
// DOCK-3.1-11: DockInstrumentView renderedFaceMaterialForChecks.
// DOCK-3.1-13: DockInstrumentView renderedReadoutBackingForChecks.
// DOCK-3.1-14: DockInstrumentView renderedAliasBackingForChecks.
// DOCK-3.1-15: DockInstrumentView renderedReadoutTransformsForChecks.
// DOCK-3.1-16: StaticDockPreviewHost resolvedT2GapAndOverflowForChecks.
// DOCK-3.1-17: StaticDockPreviewHost resolvedT2CurvatureForChecks.
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
    var display = DockDisplayArea(id: "g1-display", frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 24, width: 1440, height: 850))
    let second = DockDisplayArea(id: "g1-second", frame: CGRect(x: 1800, y: 0, width: 1200, height: 700), visibleFrame: CGRect(x: 1800, y: 0, width: 1200, height: 700))
    var pointer = CGPoint(x: 720, y: 450)
    var presence = DockPresence()
    var primaryConnected = true
    var includeSecondDisplay = true
    func sample() -> DockEdgeEnvironment {
        .init(displays: primaryConnected ? (includeSecondDisplay ? [display, second] : [display]) : [second], layouts: [], primaryDisplayID: primaryConnected ? display.id : second.id, pointer: pointer, presence: presence)
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
                         resetStatus: String? = nil, newReading: Bool = false, vendorKey: String = "synthetic", extraMembers: Int = 0) throws -> WireRowsSnapshot {
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(root["projection"] as? [String: Any])
        var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
        rows[0]["state"] = "fresh"; rows[0]["consent"] = "allowed"
        rows[0]["vendorKey"] = vendorKey
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
        for index in 0..<extraMembers {
            var member = accounts[0]
            let id = String(format: "%016llx", UInt64(index + 2))
            member["subscriptionRef"] = id; member["accountLocator"] = id
            var plan = try XCTUnwrap(member["plan"] as? [String: Any]); plan["id"] = "g1-extra-\(index)"; member["plan"] = plan
            accounts.append(member)
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
        if panels && resetStatus != nil { throw XCTSkip("Native-panel fixture must not dispatch system notifications") }
        let configuration = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/never-launched"), applicationVersion: "g1", allowedEnvironment: [:], offline: true, readOnly: true)
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        #if DEBUG
        let previousLedger = EngineRowsEntry.isolatedNativeNotificationLedgerForChecks
        let isolatedLedger = profile.appendingPathComponent("notification-ledger.json")
        if panels { EngineRowsEntry.isolatedNativeNotificationLedgerForChecks = isolatedLedger }
        #else
        if panels { throw XCTSkip("Native-panel tests require an isolated notification ledger") }
        #endif
        let app = EngineRowsEntry.make(configuration: configuration,
            settingsStore: settings,
            createsNativePanels: panels, dockEnvironment: { environment.sample() },
            deadlineNow: { Date(timeIntervalSince1970: 1_800_000_000 + (clock?.elapsed ?? 0)) },
            deadlineElapsed: clock.map { clock in { clock.elapsed } }, deadlineScheduling: clock,
            makeClient: { _, store in G1CRowsClient(store: store, rows: fixture) }, activateSettings: {})
        #if DEBUG
        EngineRowsEntry.isolatedNativeNotificationLedgerForChecks = previousLedger
        if panels { XCTAssertEqual(app.composition.nativeNotificationLedgerForChecks, isolatedLedger) }
        #endif
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        return app
    }

    func testG1_DOCK_3_1_07() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-t2-scaling-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await open(G1CDisplayEnvironment(), profile: profile)
        defer { app.composition.dock.close() }
        let dock = app.composition.dock, editor = app.settingsHost.application.editor
        for edge in [SettingsDockEdge.left, .right, .bottom] {
            _ = try await editor.commit(SettingsB21Edit.dockEdge(edge))
            var reference: [CGPoint]?
            for size in [SettingsSize.large, .medium, .small] {
                _ = try await editor.commit(SettingsB20Edit.size(size))
                let geometry = try XCTUnwrap(dock.resolvedT2CurvatureForChecks)
                let skin = try XCTUnwrap(dock.dockView.presentedSkinForChecks)
                let station = try XCTUnwrap(skin.stations.first { $0.subscriptionID == "0123456789abcdef" })
                let sourceStation = try XCTUnwrap(geometry.stations.first { $0.subscription?.id == "0123456789abcdef" })
                let scale = size.nozzleDiameter / 52
                XCTAssertEqual(station.diameter, size.nozzleDiameter, accuracy: 0.0001)
                XCTAssertEqual(station.readout.width, 56 * scale, accuracy: 0.0001)
                XCTAssertEqual(station.readout.height, 16 * scale, accuracy: 0.0001)
                XCTAssertEqual(station.clock.radius, 28.2 * scale, accuracy: 0.0001)
                XCTAssertEqual(try XCTUnwrap(dock.registeredConsoleButtonForChecks).width, 34 * scale, accuracy: 0.0001)
                XCTAssertEqual(geometry.gap, 14 * scale, accuracy: 0.0001)
                XCTAssertEqual(skin.bodyPolygon, geometry.outline)
                let normalized = geometry.outline.map { CGPoint(x: ($0.x - sourceStation.centre.x) / scale, y: ($0.y - sourceStation.centre.y) / scale) }
                if let reference {
                    XCTAssertEqual(normalized.count, reference.count)
                    for (actual, expected) in zip(normalized, reference) {
                        XCTAssertEqual(actual.x, expected.x, accuracy: 0.01)
                        XCTAssertEqual(actual.y, expected.y, accuracy: 0.01)
                    }
                } else { reference = normalized }
            }
        }
        await app.composition.stop()
    }

    func testG1_DOCK_3_1_1_09() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-position-commit-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let environment = G1CDisplayEnvironment(), clock = G1CClock()
        let app = try await open(environment, profile: profile, clock: clock, panels: true)
        defer { app.composition.dock.close() }
        let dock = app.composition.dock, editor = app.settingsHost.application.editor
        let before = try XCTUnwrap(editor.snapshot?.preferences)
        environment.primaryConnected = false; dock.refreshPresence(); clock.advance(1)
        XCTAssertEqual(editor.snapshot?.preferences.dockEdge, before.dockEdge)
        XCTAssertEqual(editor.snapshot?.preferences.dockAlongFraction, before.dockAlongFraction)
        environment.primaryConnected = true; dock.refreshPresence(); clock.advance(1)
        XCTAssertEqual(editor.snapshot?.preferences.dockEdge, before.dockEdge)
        XCTAssertEqual(editor.snapshot?.preferences.dockAlongFraction, before.dockAlongFraction)
        _ = try await editor.commit(SettingsB21Edit.activeDisplay(true))
        environment.pointer = CGPoint(x: environment.second.frame.midX, y: environment.second.frame.midY)
        dock.refreshPresence(); clock.advance(1)
        XCTAssertEqual(editor.snapshot?.preferences.dockEdge, before.dockEdge)
        XCTAssertEqual(editor.snapshot?.preferences.dockAlongFraction, before.dockAlongFraction)
        _ = try await editor.commit(SettingsB21Edit.activeDisplay(false))
        environment.pointer = CGPoint(x: 720, y: 450); dock.refreshPresence(); clock.advance(1)
        let panel = try XCTUnwrap(dock.nativePanel), view = dock.dockView
        let candidates = stride(from: CGFloat(1), to: view.bounds.width, by: 4).flatMap { x in
            stride(from: CGFloat(1), to: view.bounds.height, by: 4).map { CGPoint(x: x, y: $0) }
        }
        let local = try XCTUnwrap(candidates.first { view.backgroundDragDelegate?.backgroundCanDrag(local: $0) == true })
        let origin = panel.convertPoint(toScreen: view.convert(local, to: nil)), destination = CGPoint(x: 1, y: 450)
        func event(_ type: NSEvent.EventType, at point: CGPoint) throws -> NSEvent {
            try XCTUnwrap(NSEvent.mouseEvent(with: type, location: panel.convertPoint(fromScreen: point), modifierFlags: [], timestamp: clock.elapsed, windowNumber: panel.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: type == .leftMouseDown ? 1 : 0))
        }
        environment.pointer = origin; environment.presence.mouseButtonDown = true
        view.mouseDown(with: try event(.leftMouseDown, at: origin))
        environment.pointer = destination; view.mouseDragged(with: try event(.leftMouseDragged, at: destination))
        environment.presence.mouseButtonDown = false; view.mouseUp(with: try event(.leftMouseUp, at: destination))
        for _ in 0..<100 { await Task.yield() }
        XCTAssertEqual(dock.edgePresentation?.placement?.edge, .left)
        XCTAssertEqual(editor.snapshot?.preferences.dockEdge, .left)
        let savedAlong = try XCTUnwrap(editor.snapshot?.preferences.dockAlongFraction)
        await app.composition.stop(); dock.close()
        let reopened = try await open(environment, profile: profile)
        defer { reopened.composition.dock.close() }
        XCTAssertEqual(reopened.settingsHost.application.editor.snapshot?.preferences.dockEdge, .left)
        XCTAssertEqual(reopened.settingsHost.application.editor.snapshot?.preferences.dockAlongFraction, savedAlong)
        await reopened.composition.stop()
    }

    func testG1_DOCK_3_1_14() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-alias-backing-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await open(G1CDisplayEnvironment(), profile: profile, secondMember: true)
        defer { app.composition.dock.close() }
        let editor = app.settingsHost.application.editor, view = app.composition.dock.dockView
        for alias in ["ABCD1234", "账户一二"] {
            _ = try await editor.commit(SettingsB21Edit.alias(.init(subscriptionID: "0123456789abcdef", committed: alias)))
            XCTAssertEqual(view.presentedReadingsForChecks["0123456789abcdef"]?.alias, alias)
            let rendered = try XCTUnwrap(view.renderedAliasBackingForChecks["0123456789abcdef"])
            XCTAssertTrue(rendered.hasDedicatedBacking, "The alias must have its own opaque backing")
            XCTAssertGreaterThan(rendered.frame.width, 0)
            XCTAssertGreaterThan(rendered.frame.height, 0)
        }
        // TODO(G1): inspect effective visible glyphs at and beyond each length limit.
        await app.composition.stop()
    }

    func testG1_DOCK_3_1_13() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-readout-backing-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await open(G1CDisplayEnvironment(), profile: profile)
        defer { app.composition.dock.close() }
        let client = try XCTUnwrap(app.composition.client as? G1CRowsClient), view = app.composition.dock.dockView
        for remaining in [41.0, 25.0, 0.0] {
            try await client.replaceRows(fixture(five: remaining))
            XCTAssertEqual(view.presentedReadingsForChecks["0123456789abcdef"]?.readout, "\(Int(remaining))%")
            let actual = try XCTUnwrap(view.renderedReadoutBackingForChecks["0123456789abcdef"])
            XCTAssertFalse(actual.hasDedicatedBacking)
        }
        await app.composition.stop()
    }

    func testG1_DOCK_3_1_15() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-upright-readout-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await open(G1CDisplayEnvironment(), profile: profile, secondMember: true)
        defer { app.composition.dock.close() }
        let editor = app.settingsHost.application.editor, view = app.composition.dock.dockView
        for edge in [SettingsDockEdge.left, .right, .bottom] {
            _ = try await editor.commit(SettingsB21Edit.dockEdge(edge))
            for size in [SettingsSize.small, .medium, .large] {
                _ = try await editor.commit(SettingsB20Edit.size(size))
                for id in ["0123456789abcdef", "fedcba9876543210"] {
                    let transform = try XCTUnwrap(view.renderedReadoutTransformsForChecks[id])
                    XCTAssertEqual(transform.b, 0, accuracy: 0.000001)
                    XCTAssertEqual(transform.c, 0, accuracy: 0.000001)
                    XCTAssertGreaterThan(transform.a, 0)
                }
            }
        }
        await app.composition.stop()
    }

    func testG1_DOCK_3_1_16() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-gap-overflow-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let environment = G1CDisplayEnvironment()
        environment.includeSecondDisplay = false
        let app = try await open(environment, profile: profile)
        defer { app.composition.dock.close() }
        let dock = app.composition.dock, editor = app.settingsHost.application.editor
        let client = try XCTUnwrap(app.composition.client as? G1CRowsClient)
        try await client.replaceRows(fixture(extraMembers: 6))
        _ = try await editor.commit(SettingsB20Edit.size(.medium))
        _ = try await editor.commit(SettingsB21Edit.dockEdge(.bottom))
        var results: [(CGFloat, Int)] = []
        for width in [CGFloat(1400), 800, 700] {
            let frame = CGRect(x: 0, y: 0, width: width, height: 900)
            environment.display = DockDisplayArea(id: "g1-display", frame: frame, visibleFrame: frame)
            environment.pointer = CGPoint(x: width / 2, y: 450)
            dock.refreshPresence(); dock.refreshDockContent()
            let actual = try XCTUnwrap(dock.resolvedT2GapAndOverflowForChecks)
            XCTAssertEqual(actual.shownIDs.count + actual.overflowIDs.count, 7)
            XCTAssertGreaterThanOrEqual(actual.gap, 6 * 44 / 52 - 0.0001)
            XCTAssertLessThanOrEqual(actual.gap, 14 * 44 / 52 + 0.0001)
            let skin = try XCTUnwrap(dock.dockView.presentedSkinForChecks)
            for station in skin.stations { XCTAssertEqual(station.diameter, 44, accuracy: 0.0001) }
            results.append((actual.gap, actual.overflowIDs.count))
        }
        XCTAssertEqual(results[0].1, 0)
        XCTAssertEqual(results[0].0, 14 * 44 / 52, accuracy: 0.0001)
        XCTAssertEqual(results[1].1, 0)
        XCTAssertLessThan(results[1].0, results[0].0)
        XCTAssertGreaterThan(results[2].1, 0)
        await app.composition.stop()
    }

    func testG1_DOCK_3_1_17() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-curvature-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await open(G1CDisplayEnvironment(), profile: profile, secondMember: true)
        defer { app.composition.dock.close() }
        let dock = app.composition.dock, editor = app.settingsHost.application.editor
        for edge in [SettingsDockEdge.left, .right, .bottom] {
            _ = try await editor.commit(SettingsB21Edit.dockEdge(edge))
            for size in [SettingsSize.small, .medium, .large] {
                _ = try await editor.commit(SettingsB20Edit.size(size))
                let actual = try XCTUnwrap(dock.resolvedT2CurvatureForChecks)
                XCTAssertGreaterThan(actual.sliceAngle, 0)
                XCTAssertLessThanOrEqual(actual.sliceAngle, 16 * .pi / 180 + 0.000001)
                let sagitta = actual.radius * (1 - cos(actual.sliceAngle / 2))
                XCTAssertLessThanOrEqual(sagitta, 8 * size.nozzleDiameter / 52 + 0.000001)
            }
        }
        await app.composition.stop()
    }

    func testG1_DOCK_3_2_06() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-mark-provenance-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await open(G1CDisplayEnvironment(), profile: profile)
        defer { app.composition.dock.close() }
        let client = try XCTUnwrap(app.composition.client as? G1CRowsClient), view = app.composition.dock.dockView
        let manifest = try JSONDecoder().decode(DockResourceManifest.self, from: DockThirdPartyResources.manifestData(zaiMarkEnabled: view.zaiMarkEnabled))
        let root = try DockThirdPartyResources.rootURL()
        let sourceRecord = try XCTUnwrap(manifest.files["notice-vendors"])
        let sourceData = try Data(contentsOf: root.appendingPathComponent(sourceRecord.path))
        func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
        XCTAssertEqual(sourceData.count, sourceRecord.bytes)
        XCTAssertEqual(digest(sourceData), sourceRecord.sha256.lowercased())
        let notes = try XCTUnwrap(String(data: sourceData, encoding: .utf8))
        XCTAssertTrue(notes.localizedCaseInsensitiveContains("trademark"))
        var vendors = [("openai", "logo-openai"), ("cursor", "logo-cursor"), ("claude", "logo-claude"),
                       ("kimi", "logo-kimi"), ("copilot", "logo-copilot"), ("opencode", "logo-opencode")]
        if view.zaiMarkEnabled { vendors.append(("zhipu", "logo-zai-white")) }
        for (vendor, expected) in vendors {
            try await client.replaceRows(fixture(vendorKey: vendor))
            let reading = try XCTUnwrap(view.presentedReadingsForChecks["0123456789abcdef"])
            let station = try XCTUnwrap(view.presentedSkinForChecks?.stations.first { $0.subscriptionID == reading.subscriptionID })
            XCTAssertEqual(reading.vendorResourceKey, vendor)
            XCTAssertEqual(station.glyphs[vendor], expected)
            let record = try XCTUnwrap(manifest.files[expected])
            let asset = try Data(contentsOf: root.appendingPathComponent(record.path))
            XCTAssertEqual(asset.count, record.bytes)
            XCTAssertEqual(digest(asset), record.sha256.lowercased())
            XCTAssertTrue(notes.contains(URL(fileURLWithPath: record.path).lastPathComponent))
        }
        await app.composition.stop()
    }

    func testG1_DOCK_3_2_11() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-idle-alert-flame-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await open(G1CDisplayEnvironment(), profile: profile)
        defer { app.composition.dock.close() }
        let dock = app.composition.dock
        XCTAssertTrue(dock.activeWorkingEffectIDs.isEmpty)
        let client = try XCTUnwrap(app.composition.client as? G1CRowsClient)
        try await client.replaceRows(fixture(resetStatus: "announced"))
        XCTAssertNotNil(dock.dockView.presentedNoticesForChecks["0123456789abcdef"])
        XCTAssertTrue(dock.activeWorkingEffectIDs.isEmpty)
        // TODO(G1): exercise active output and return to idle through the admitted session-activity feed.
        await app.composition.stop()
    }

    func testG1_DOCK_3_2_07() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-white-marks-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await open(G1CDisplayEnvironment(), profile: profile)
        defer { app.composition.dock.close() }
        let client = try XCTUnwrap(app.composition.client as? G1CRowsClient), view = app.composition.dock.dockView
        let manifest = try JSONDecoder().decode(DockResourceManifest.self, from: DockThirdPartyResources.manifestData(zaiMarkEnabled: view.zaiMarkEnabled))
        for (vendor, resource) in [("openai", "logo-openai"), ("cursor", "logo-cursor")] {
            try await client.replaceRows(fixture(vendorKey: vendor))
            let reading = try XCTUnwrap(view.presentedReadingsForChecks["0123456789abcdef"])
            let station = try XCTUnwrap(view.presentedSkinForChecks?.stations.first { $0.subscriptionID == reading.subscriptionID })
            XCTAssertEqual(reading.vendorResourceKey, vendor)
            XCTAssertEqual(station.glyphs[vendor], resource)
            XCTAssertNotNil(manifest.files[resource])
        }
        for vendor in ["zhipu", "glm", "zai", "zcode"] {
            try await client.replaceRows(fixture(vendorKey: vendor))
            let station = try XCTUnwrap(view.presentedSkinForChecks?.stations.first { $0.subscriptionID == "0123456789abcdef" })
            XCTAssertEqual(station.glyphs[vendor], view.zaiMarkEnabled ? "logo-zai-white" : nil)
        }
        XCTAssertEqual(manifest.files["logo-zai-white"] != nil, view.zaiMarkEnabled)
        await app.composition.stop()
    }

    func testG1_DOCK_3_2_08() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-colour-marks-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await open(G1CDisplayEnvironment(), profile: profile)
        defer { app.composition.dock.close() }
        let client = try XCTUnwrap(app.composition.client as? G1CRowsClient), view = app.composition.dock.dockView
        let manifest = try JSONDecoder().decode(DockResourceManifest.self, from: DockThirdPartyResources.manifestData(zaiMarkEnabled: view.zaiMarkEnabled))
        for vendor in ["google", "alibaba", "qwen", "minimax"] {
            try await client.replaceRows(fixture(vendorKey: vendor))
            let reading = try XCTUnwrap(view.presentedReadingsForChecks["0123456789abcdef"])
            let station = try XCTUnwrap(view.presentedSkinForChecks?.stations.first { $0.subscriptionID == reading.subscriptionID })
            XCTAssertEqual(reading.vendorResourceKey, vendor)
            let resource = station.glyphs[vendor]
            XCTAssertNotNil(resource, "No selected mark for \(vendor)")
            if let resource { XCTAssertNotNil(manifest.files[resource], "The selected mark must be packaged") }
        }
        await app.composition.stop()
    }

    func testG1_DOCK_3_2_09() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-other-marks-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await open(G1CDisplayEnvironment(), profile: profile)
        defer { app.composition.dock.close() }
        let client = try XCTUnwrap(app.composition.client as? G1CRowsClient), view = app.composition.dock.dockView
        let manifest = try JSONDecoder().decode(DockResourceManifest.self, from: DockThirdPartyResources.manifestData(zaiMarkEnabled: view.zaiMarkEnabled))
        for (vendor, resource) in [("claude", "logo-claude"), ("kimi", "logo-kimi"), ("copilot", "logo-copilot"), ("opencode", "logo-opencode")] {
            try await client.replaceRows(fixture(vendorKey: vendor))
            let reading = try XCTUnwrap(view.presentedReadingsForChecks["0123456789abcdef"])
            let station = try XCTUnwrap(view.presentedSkinForChecks?.stations.first { $0.subscriptionID == reading.subscriptionID })
            XCTAssertEqual(reading.vendorResourceKey, vendor)
            XCTAssertEqual(station.glyphs[vendor], resource)
            XCTAssertNotNil(manifest.files[resource])
        }
        await app.composition.stop()
    }

    func testG1_DOCK_3_1_22() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g1-ignition-guard-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try await open(G1CDisplayEnvironment(), profile: profile, secondMember: true)
        defer { app.composition.dock.close() }
        let dock = app.composition.dock, editor = app.settingsHost.application.editor
        for edge in [SettingsDockEdge.left, .right, .bottom] {
            _ = try await editor.commit(SettingsB21Edit.dockEdge(edge))
            for (size, diameter) in [(SettingsSize.small, CGFloat(36)), (.medium, 44), (.large, 52)] {
                _ = try await editor.commit(SettingsB20Edit.size(size))
                let skin = try XCTUnwrap(dock.dockView.presentedSkinForChecks)
                let button = try XCTUnwrap(dock.registeredConsoleButtonForChecks)
                XCTAssertEqual(button.width, 34 * diameter / 52, accuracy: 0.0001)
                XCTAssertEqual(button.height, 34 * diameter / 52, accuracy: 0.0001)
                let resources = Set(skin.fixedLayers.map(\.resource))
                XCTAssertTrue(resources.contains("a5-recessed-guard-52x52@3x.png"))
                XCTAssertTrue(resources.contains("a5-cap-night-idle-44x44@3x.png"))
                XCTAssertGreaterThanOrEqual(skin.bodyPolygon.count, 3)
                let hull = CGMutablePath(); hull.addLines(between: skin.bodyPolygon); hull.closeSubpath()
                let centre = CGPoint(x: button.midX + skin.bounds.minX, y: button.midY + skin.bounds.minY)
                let radius = button.width / 2
                var inside = 0, total = 0
                for x in -40...40 {
                    for y in -40...40 {
                        let dx = CGFloat(x) / 40, dy = CGFloat(y) / 40
                        guard dx * dx + dy * dy <= 1 else { continue }
                        total += 1
                        if hull.contains(CGPoint(x: centre.x + dx * radius, y: centre.y + dy * radius)) { inside += 1 }
                    }
                }
                XCTAssertGreaterThan(total, 0)
                let outsideFraction = 1 - Double(inside) / Double(total)
                XCTAssertEqual(outsideFraction, 0.4, accuracy: 0.03)
            }
        }
        await app.composition.stop()
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
