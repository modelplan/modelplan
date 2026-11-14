// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
@testable import ModelPlanAppIntegration

private actor CarryEngine: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore, rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "carry", floor: .init(storeEpoch: "carry", generation: 1), revision: 1)
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        return context
    }
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func stop() async {}
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion {
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context), invalidRowCount: 0))
        return .init(requestID: .string("carry-rows"))
    }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

@MainActor private final class CarryNoWindowSurface: SettingsWindowSurface {
    func prepare() async {}
    func show(paneID: String?) {}
    func hide() {}
}

@MainActor private final class CarryClock { var elapsed = 10.0, wall = Date() }

/// Build 14f owner reports, after D244 (#932) made a ring press-drag carry the whole widget:
/// - G3-113: while the widget was carried, its quota rings vanished and came back only after the drop.
/// - G3-114: a ring's open card stayed where it was while the widget moved away from it.
@MainActor final class DockCarryKeepsWidgetTests: XCTestCase {
    private let first = "aaaaaaaaaaaaaaaa", second = "bbbbbbbbbbbbbbbb"

    /// G3-113: the engine replaces admitted content by clearing it and reinstalling it in one turn. The clear
    /// retires the painted rings at once; the reinstall was deferred until the drop while the widget was held,
    /// so a delivery that landed mid-carry left the carried widget without its rings. The reinstall now repaints
    /// the held widget in place, the carry goes on, and the drop still saves the new position.
    func testG3113ContentReplacedDuringARingCarryKeepsTheRingsOnTheCarriedWidget() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dock-carry-rings-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let settings = try await expandedWidgetSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-02T00:00:00Z"))
        let snapshot = try HostPairedProjectionTests.rows(weekly: 75, secondWeekly: 12)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: false,
            dockEnvironment: normalEntryTestEnvironment, deadlineNow: { wall },
            makeClient: { _, store in EntrySyntheticClient(store: store, rows: snapshot) }, activateSettings: {})
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        addTeardownBlock { @MainActor in await app.composition.stop() }
        let dock = app.composition.dock, view = dock.dockView, editor = app.settingsHost.application.editor
        func ringNodes() -> Set<String> {
            Set((view.accessibilityChildren() ?? []).compactMap { ($0 as? NSAccessibilityElement)?.accessibilityIdentifier() }
                .filter { $0.hasPrefix("dock.subscription.") })
        }
        let rings = ringNodes()
        XCTAssertEqual(rings, ["dock.subscription." + first, "dock.subscription." + second], "both rings are shown before the carry")
        let official = view.presentedSkinForChecks != nil

        let start = try XCTUnwrap(dock.edgePresentation?.paintedFrame)
        let anchor = try XCTUnwrap(view.interactionAnchor(second))
        let local = CGPoint(x: anchor.midX, y: anchor.midY)
        let down = CGPoint(x: start.minX + local.x - view.bounds.minX, y: start.maxY - local.y + view.bounds.minY)
        let revision = try XCTUnwrap(editor.snapshot?.revision)
        let arrival = ContinuousClock.now + .seconds(1)
        while !view.performPointerDown(atLocal: local, global: down) {
            guard ContinuousClock.now < arrival else { return XCTFail("a press on a ring is taken") }
            try await Task.sleep(for: .milliseconds(10))
        }
        let pulled = CGPoint(x: down.x, y: down.y - 120)
        view.performPointerDrag(atLocal: CGPoint(x: local.x, y: local.y + 120), global: pulled)
        let carried = try XCTUnwrap(dock.edgePresentation?.paintedFrame)
        XCTAssertEqual(dock.edgePresentation?.moving, true, "D244: the ring press carries the whole widget")
        XCTAssertNotEqual(carried, start)

        // A delivery lands while the widget is held: the composition's clear, then its reinstall.
        dock.withdrawAdmittedContent(privacy: false)
        dock.refreshDockContent()
        XCTAssertEqual(ringNodes(), rings, "G3-113: the carried widget keeps its rings through a content replacement")
        if official {
            let skin = try XCTUnwrap(view.presentedSkinForChecks, "G3-113: the official face is painted again, not left retired")
            XCTAssertEqual(Set(skin.stations.compactMap(\.subscriptionID)), [first, second])
            XCTAssertNotNil(view.presentedImageForChecks)
        }
        XCTAssertEqual(dock.edgePresentation?.paintedFrame, carried, "the repaint never moves the held widget")
        XCTAssertEqual(dock.edgePresentation?.moving, true, "the carry goes on")

        // The carry still follows the pointer and the drop saves the new position.
        let further = CGPoint(x: down.x, y: down.y - 160)
        view.performPointerDrag(atLocal: CGPoint(x: local.x, y: local.y + 160), global: further)
        XCTAssertEqual(try XCTUnwrap(dock.edgePresentation?.paintedFrame).midY, carried.midY - 40, accuracy: 1)
        view.performPointerUp(atLocal: CGPoint(x: local.x, y: local.y + 160), global: further)
        try await waitForSettings(editor) { (editor.snapshot?.revision ?? 0) > revision && !editor.isSaving }
        XCTAssertLessThan(try XCTUnwrap(dock.edgePresentation?.paintedFrame).midY, start.midY - 100, "the drop saved the new position")
        let settled = ContinuousClock.now + .seconds(2)
        while ringNodes() != rings && ContinuousClock.now < settled { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(ringNodes(), rings, "the rings are there after the drop")
    }

    private func rows(_ ids: [(String, String)]) throws -> WireRowsSnapshot {
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(json["projection"] as? [String: Any])
        let template = try XCTUnwrap((projection["rows"] as? [[String: Any]])?.first)
        let account = try XCTUnwrap((template["accounts"] as? [[String: Any]])?.first)
        let observed = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-60))
        let weeklyReset = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3 * 86400 + 5 * 3600 + 600))
        projection["rows"] = ids.enumerated().map { order, item -> [String: Any] in
            var row = template
            row["id"] = item.0; row["order"] = order + 1; row["vendorKey"] = item.1
            row["name"] = ["en": item.0, "zh": item.0]
            row["state"] = "fresh"; row["consent"] = "allowed"; row["surfaces"] = ["dock", "menu", "settings"]
            row["expiresAt"] = "2099-01-01T00:00:00Z"
            var copy = account
            copy["subscriptionRef"] = String(format: "%016x", order + 1)
            copy["valueState"] = "current"; copy["freshUntil"] = "2099-01-01T00:00:00Z"
            if var windows = copy["windows"] as? [[String: Any]], !windows.isEmpty {
                windows[0]["remainingPercent"] = [12, 62, 76][order % 3]; windows[0]["role"] = "weekly"; windows[0]["durationSeconds"] = 604800
                windows[0]["limitKey"] = "weekly"; windows[0]["poolKey"] = "main"; windows[0]["current"] = true; windows[0]["observedAt"] = observed
                windows[0]["resetsAt"] = weeklyReset; windows[0]["validUntil"] = weeklyReset
                windows[0].removeValue(forKey: "modelScope")
                copy["windows"] = [windows[0]]; copy["route"] = "runtime_rpc"; copy["observedAt"] = observed
            }
            row["accounts"] = [copy]
            return row
        }
        json["projection"] = projection
        return try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
    }

    /// G3-114: with a ring's card open, a press-drag on that ring carries the whole widget (D244). The card
    /// follows its ring as painted (prototype card.js refreshCardPlacement), keeping the same gap and arrow,
    /// instead of staying behind where the widget was. Through the normal entry with native panels.
    func testG3114AnOpenCardFollowsItsRingWhileTheWidgetIsCarried() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("dock-carry-card-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: profile) }
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        _ = try await store.update { p in
            p.showDock = true; p.autoHide = false; p.dockEdge = .right; p.size = .medium; p.magnification = .none
            p.motion = .system; for _ in 0..<16 { p.onboarding.next() }
        }
        let snapshot = try rows([("codex", "openai"), ("claude-code", "claude"), ("zcode", "zhipu")])
        let clock = CarryClock()
        var pointer = CGPoint(x: 600, y: 450)
        let screen = DockDisplayArea(id: "primary", frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 80, width: 1440, height: 795), backingScale: 2)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: store, createsNativePanels: true, bundleURL: profile.appendingPathComponent("Synthetic.app"),
            dockEnvironment: { .init(displays: [screen], layouts: [], primaryDisplayID: "primary", pointer: pointer) },
            deadlineNow: { [clock] in clock.wall }, deadlineElapsed: { [clock] in clock.elapsed },
            makeClient: { _, target in CarryEngine(store: target, rows: snapshot) }, makeSettingsSurface: { _ in CarryNoWindowSurface() },
            isolatedResetNotificationLedger: profile.appendingPathComponent("reset-notifications.json"), activateSettings: {})
        app.makeFirstRunSurface = { _ in CarryNoWindowSurface() }
        app.makeFirstRunSurfaceWithConsent = { _, _ in CarryNoWindowSurface() }
        await app.prepare()
        app.startLifecycle(workspace: NotificationCenter(), local: NotificationCenter(), lockEvents: NotificationCenter(), displayIDs: { [1] }, onConsole: { true }, displaysAsleep: { _ in false })
        app.allowDockPresentation()
        let dock = app.composition.dock, view = dock.dockView
        for _ in 0..<1000 {
            if !app.lifecyclePaused, (view.presentedSkinForChecks?.stations.filter { $0.subscriptionID != nil }.count ?? 0) == 3, view.window != nil { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let id = try XCTUnwrap(view.presentedSkinForChecks?.stations.compactMap(\.subscriptionID).first)
        let window = try XCTUnwrap(view.window)
        func screenRect(_ local: CGRect) -> CGRect { window.convertToScreen(view.convert(local, to: nil)) }
        let anchor = try XCTUnwrap(view.interactionAnchor(id))
        let hit = screenRect(anchor)
        pointer = CGPoint(x: hit.midX, y: hit.midY)
        let events = try XCTUnwrap(view.nozzleEventDelegate)
        events.hoverNozzle(nil); events.hoverNozzle(id)
        clock.elapsed += 0.6; clock.wall.addTimeInterval(0.6); dock.interactionControllerForChecks?.refresh()
        for _ in 0..<200 where dock.cardPlateForChecks == nil { try await Task.sleep(for: .milliseconds(10)); dock.interactionControllerForChecks?.refresh() }
        let plate = try XCTUnwrap(dock.cardPlateForChecks, "the ring's card is open")
        let ring = screenRect(try XCTUnwrap(view.cardRingAnchor(id)))

        // Press the ring and pull it 150 pt along the edge: the whole widget is carried (D244).
        let local = CGPoint(x: anchor.midX, y: anchor.midY)
        let start = try XCTUnwrap(dock.edgePresentation?.paintedFrame)
        let arrival = ContinuousClock.now + .seconds(1)
        while !view.performPointerDown(atLocal: local, global: pointer) {
            guard ContinuousClock.now < arrival else { return XCTFail("a press on a ring is taken") }
            try await Task.sleep(for: .milliseconds(10))
        }
        let pulled = CGPoint(x: pointer.x, y: pointer.y - 150)
        pointer = pulled
        view.performPointerDrag(atLocal: local, global: pulled)
        XCTAssertEqual(dock.edgePresentation?.moving, true, "D244: the ring press carries the widget")
        let carried = try XCTUnwrap(dock.edgePresentation?.paintedFrame)
        XCTAssertLessThan(carried.midY, start.midY - 100, "the widget follows the pointer")
        let movedRing = screenRect(try XCTUnwrap(view.cardRingAnchor(id)))
        XCTAssertEqual(movedRing.midY - ring.midY, carried.midY - start.midY, accuracy: 1, "the ring moved with the widget")
        if let moved = dock.cardPlateForChecks {
            XCTAssertEqual(moved.midY - movedRing.midY, plate.midY - ring.midY, accuracy: 1, "G3-114: the open card follows its ring")
            XCTAssertEqual(movedRing.minX - moved.maxX, ring.minX - plate.maxX, accuracy: 1, "G3-114: the card keeps its gap to the ring")
        }
        view.performPointerUp(atLocal: local, global: pulled)
        try await Task.sleep(for: .milliseconds(50))
        if let dropped = dock.cardPlateForChecks {
            let restingRing = screenRect(try XCTUnwrap(view.cardRingAnchor(id)))
            XCTAssertEqual(dropped.midY - restingRing.midY, plate.midY - ring.midY, accuracy: 1, "G3-114: the card sits by its ring after the drop")
        }
        events.hoverNozzle(nil)
        await app.stopLifecycle(); dock.close()
    }
}
