// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
import ModelPlanShell
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
///   Pulse rebuilds nothing during a drag: the held widget is never re-rendered; a content update that lands
///   during the press is applied once, after it.
/// - G3-114: a ring's open card stayed where it was while the widget moved away from it. Pulse closes the card
///   when a carry starts (FloatingUsagePanelContent `.onChange(of: placement.isDragging)` -> `deselect()`).
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
        let fullPasses = dock.fullRebuildPassesForChecks, carriedPasses = dock.carriedRebuildPassesForChecks

        // A delivery lands while the widget is held: the composition's clear, then its reinstall.
        dock.withdrawAdmittedContent(privacy: false)
        dock.refreshDockContent()
        XCTAssertEqual(ringNodes(), rings, "G3-113: the carried widget keeps its rings through a content replacement")
        XCTAssertEqual(dock.fullRebuildPassesForChecks, fullPasses, "G3-113 (Pulse): nothing is rebuilt while the widget is held")
        XCTAssertEqual(dock.carriedRebuildPassesForChecks, carriedPasses, "G3-113 (Pulse): the held widget is not repainted mid-carry")
        if official {
            let skin = try XCTUnwrap(view.presentedSkinForChecks, "G3-113: the official face stays painted, not retired")
            XCTAssertEqual(Set(skin.stations.compactMap(\.subscriptionID)), [first, second])
            XCTAssertNotNil(view.presentedImageForChecks)
        }
        XCTAssertEqual(dock.edgePresentation?.paintedFrame, carried, "the repaint never moves the held widget")
        XCTAssertEqual(dock.edgePresentation?.moving, true, "the carry goes on")

        // The carry still follows the pointer and the drop saves the new position.
        let further = CGPoint(x: down.x, y: down.y - 160)
        view.performPointerDrag(atLocal: CGPoint(x: local.x, y: local.y + 160), global: further)
        XCTAssertEqual(try XCTUnwrap(dock.edgePresentation?.paintedFrame).midY, carried.midY - 40, accuracy: 1)
        XCTAssertEqual(dock.fullRebuildPassesForChecks, fullPasses, "no rebuild per move")
        XCTAssertEqual(dock.carriedRebuildPassesForChecks, carriedPasses, "no edge-view preparation per move")
        view.performPointerUp(atLocal: CGPoint(x: local.x, y: local.y + 160), global: further)
        XCTAssertGreaterThan(dock.fullRebuildPassesForChecks, fullPasses, "the held content update is applied once the press ends")
        try await waitForSettings(editor) { (editor.snapshot?.revision ?? 0) > revision && !editor.isSaving }
        XCTAssertLessThan(try XCTUnwrap(dock.edgePresentation?.paintedFrame).midY, start.midY - 100, "the drop saved the new position")
        let settled = ContinuousClock.now + .seconds(2)
        while ringNodes() != rings && ContinuousClock.now < settled { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(ringNodes(), rings, "the rings are there after the drop")
    }

    /// Item 3 (Pulse `finish`: a press that never moved does nothing): a plain click on the widget body ran a full
    /// rebuild under the pointer (the unmoved press was "cancelled" and the host rebuilt), which re-fired tracking
    /// and flickered the card. A content update that lands during the click is held and applied once at mouse-up.
    func testAnUnmovedBodyClickRebuildsNothingAndAppliesAHeldUpdateOnce() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dock-click-" + UUID().uuidString)
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
        let dock = app.composition.dock, view = dock.dockView
        let start = try XCTUnwrap(dock.edgePresentation?.paintedFrame)
        let drag = try XCTUnwrap(view.backgroundDragDelegate, "the widget body is draggable")
        let local = try XCTUnwrap(stride(from: 4.0, to: view.bounds.height, by: 4).lazy.flatMap { y in
            stride(from: 4.0, to: view.bounds.width, by: 4).map { CGPoint(x: $0, y: y) }
        }.first { drag.backgroundCanDrag(local: $0) }, "a body point")
        let down = CGPoint(x: start.minX + local.x - view.bounds.minX, y: start.maxY - local.y + view.bounds.minY)
        let arrival = ContinuousClock.now + .seconds(1)
        while !drag.beginBackgroundMove(local: local, global: down) {
            guard ContinuousClock.now < arrival else { return XCTFail("a body press is taken") }
            try await Task.sleep(for: .milliseconds(10))
        }
        let full = dock.fullRebuildPassesForChecks
        dock.withdrawAdmittedContent(privacy: false)
        dock.refreshDockContent()
        XCTAssertEqual(dock.fullRebuildPassesForChecks, full, "nothing is rebuilt while the press is held")
        drag.updateBackgroundMove(global: CGPoint(x: down.x + 2, y: down.y + 1))
        drag.endBackgroundMove(global: CGPoint(x: down.x + 2, y: down.y + 1))
        XCTAssertGreaterThan(dock.fullRebuildPassesForChecks, full, "the held update is applied at mouse-up")
        XCTAssertEqual(dock.edgePresentation?.paintedFrame, start, "a click never moves the widget")

        // A click with nothing held back rebuilds nothing at all.
        let again = ContinuousClock.now + .seconds(1)
        while !drag.beginBackgroundMove(local: local, global: down) {
            guard ContinuousClock.now < again else { return XCTFail("a second body press is taken") }
            try await Task.sleep(for: .milliseconds(10))
        }
        let quiet = dock.fullRebuildPassesForChecks
        drag.endBackgroundMove(global: down)
        XCTAssertEqual(dock.fullRebuildPassesForChecks, quiet, "Pulse: a plain body click does nothing")
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

    /// The normal entry with native panels on the right edge, a ring's card open from hover (no magnification),
    /// and the ring pressed (D244: the press is the start of a carry). `pointer` is the native pointer sample.
    private final class Pointer { var at = CGPoint(x: 600, y: 450) }
    private struct Opened {
        let app: EngineDockMenuApplication, dock: StaticDockPreviewHost, view: DockInstrumentView, store: SettingsStore
        let id: String, plate: CGRect, ring: CGRect, local: CGPoint, start: CGRect
    }
    private func openCardAndPressItsRing(_ pointer: Pointer, screen: DockDisplayArea) async throws -> Opened {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("dock-carry-card-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: profile) }
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        _ = try await store.update { p in
            p.showDock = true; p.autoHide = false; p.dockEdge = .right; p.size = .medium; p.magnification = .none
            p.motion = .system; for _ in 0..<16 { p.onboarding.next() }
        }
        let snapshot = try rows([("codex", "openai"), ("claude-code", "claude"), ("zcode", "zhipu")])
        let clock = CarryClock()
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: store, createsNativePanels: true, bundleURL: profile.appendingPathComponent("Synthetic.app"),
            dockEnvironment: { .init(displays: [screen], layouts: [], primaryDisplayID: "primary", pointer: pointer.at) },
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
        let anchor = try XCTUnwrap(view.interactionAnchor(id))
        let hit = window.convertToScreen(view.convert(anchor, to: nil))
        pointer.at = CGPoint(x: hit.midX, y: hit.midY)
        let events = try XCTUnwrap(view.nozzleEventDelegate)
        events.hoverNozzle(nil); events.hoverNozzle(id)
        clock.elapsed += 0.6; clock.wall.addTimeInterval(0.6); dock.interactionControllerForChecks?.refresh()
        for _ in 0..<200 where dock.cardPlateForChecks == nil { try await Task.sleep(for: .milliseconds(10)); dock.interactionControllerForChecks?.refresh() }
        let plate = try XCTUnwrap(dock.cardPlateForChecks, "the ring's card is open")
        let ring = window.convertToScreen(view.convert(try XCTUnwrap(view.cardRingAnchor(id)), to: nil))
        let local = CGPoint(x: anchor.midX, y: anchor.midY)
        let start = try XCTUnwrap(dock.edgePresentation?.paintedFrame)
        let arrival = ContinuousClock.now + .seconds(1)
        while !view.performPointerDown(atLocal: local, global: pointer.at) {
            guard ContinuousClock.now < arrival else { XCTFail("a press on a ring is taken"); throw CancellationError() }
            try await Task.sleep(for: .milliseconds(10))
        }
        return .init(app: app, dock: dock, view: view, store: store, id: id, plate: plate, ring: ring, local: local, start: start)
    }
    private let screen = DockDisplayArea(id: "primary", frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 80, width: 1440, height: 795), backingScale: 2)

    /// G3-114: with a ring's card open, a press-drag on that ring carries the whole widget (D244). Like Pulse, the
    /// card closes on the carry's first moved frame and stays closed while the widget is carried; a press that has not
    /// moved is still the ring's click and leaves the card. Fails before: the card stayed open and was re-placed.
    func testG3114ACarryClosesTheOpenCardOnItsFirstMovedFrame() async throws {
        let pointer = Pointer()
        let o = try await openCardAndPressItsRing(pointer, screen: screen)
        let view = o.view, dock = o.dock
        XCTAssertNotNil(dock.cardPlateForChecks, "a press that has not moved leaves the card open")
        // Pull the pressed ring 150 pt along the right edge: the whole widget is carried (D244).
        let pulled = CGPoint(x: pointer.at.x, y: pointer.at.y - 150)
        pointer.at = pulled
        view.performPointerDrag(atLocal: o.local, global: pulled)
        XCTAssertEqual(dock.edgePresentation?.moving, true, "D244: the ring press carries the widget")
        let carried = try XCTUnwrap(dock.edgePresentation?.paintedFrame)
        XCTAssertLessThan(carried.midY, o.start.midY - 100, "the widget follows the pointer")
        XCTAssertNil(dock.cardPlateForChecks, "G3-114 (Pulse): the carry closes the card")
        XCTAssertTrue(dock.card.isHidden)
        let further = CGPoint(x: pulled.x, y: pulled.y - 40)
        pointer.at = further
        view.performPointerDrag(atLocal: o.local, global: further)
        dock.interactionControllerForChecks?.refresh()
        XCTAssertNil(dock.cardPlateForChecks, "nothing reopens while the widget is carried")
        view.performPointerUp(atLocal: o.local, global: further)
        XCTAssertNotEqual(dock.edgePresentation?.moving, true, "the release ended the carry")
        await o.app.stopLifecycle(); dock.close()
    }

    /// macrevc-960-1 / G3-114: a carry onto another edge swaps that edge's view into the panel. The card is closed
    /// by the carry, so it is never left by the old edge nor re-placed from a view that is not in the window yet.
    func testG3114ACarryOntoAnotherEdgeClosesTheCard() async throws {
        let pointer = Pointer()
        let o = try await openCardAndPressItsRing(pointer, screen: screen)
        let dock = o.dock
        XCTAssertEqual(dock.edgePresentation?.placement?.edge, .right)
        // Pull the pressed ring straight to the middle of the bottom edge.
        let bottom = CGPoint(x: screen.visibleFrame.midX, y: screen.visibleFrame.minY + 2)
        pointer.at = bottom
        o.view.performPointerDrag(atLocal: o.local, global: bottom)
        XCTAssertEqual(dock.edgePresentation?.moving, true, "D244: the ring press carries the widget")
        XCTAssertEqual(dock.edgePresentation?.placement?.edge, .bottom, "precondition: the carry shows the bottom edge")
        XCTAssertNil(dock.cardPlateForChecks, "G3-114 (Pulse): the carry closed the card; it is not left on the right edge")
        dock.cancelPanelMove()
        await o.app.stopLifecycle(); dock.close()
    }

    /// Item 4: Pulse persists the dock it showed, synchronously. Ours saves asynchronously, so a Settings snapshot
    /// from before the save landed (another writer, such as the help-hint host, saved in between) was applied and
    /// its old placement put the widget straight back on the right edge. Fails before: the widget jumped back.
    func testADropOntoAnotherEdgeIsNotUndoneByASettingsSnapshotFromBeforeItsSave() async throws {
        let pointer = Pointer()
        let o = try await openCardAndPressItsRing(pointer, screen: screen)
        let dock = o.dock, view = o.view
        let stale = try XCTUnwrap(dock.applicationForChecks, "the pre-drop Settings snapshot")
        XCTAssertEqual(stale.snapshot.preferences.dockEdge, .right)
        let bottom = CGPoint(x: screen.visibleFrame.midX, y: screen.visibleFrame.minY + 2)
        pointer.at = bottom
        view.performPointerDrag(atLocal: o.local, global: bottom)
        XCTAssertEqual(dock.edgePresentation?.placement?.edge, .bottom, "precondition: the carry shows the bottom edge")
        view.performPointerUp(atLocal: o.local, global: bottom)
        XCTAssertEqual(dock.edgePresentation?.placement?.edge, .bottom, "the drop lands on the bottom edge at mouse-up")
        // The stale snapshot arrives before the save does.
        dock.apply(stale)
        XCTAssertEqual(dock.edgePresentation?.placement?.edge, .bottom, "a snapshot from before the save cannot move the widget back")
        let saveBy = ContinuousClock.now + .seconds(10)
        var saved = await o.store.snapshot().preferences
        while saved.dockEdge != .bottom && ContinuousClock.now < saveBy {
            try await Task.sleep(for: .milliseconds(50)); saved = await o.store.snapshot().preferences
        }
        XCTAssertEqual(saved.dockEdge, .bottom, "the drop is saved to the Settings document")
        XCTAssertEqual(dock.edgePresentation?.placement?.edge, .bottom)
        await o.app.stopLifecycle(); dock.close()
    }

    /// After a ring carry swaps in another edge's view, the rest of the drag and its release still reach the carry:
    /// the view that took the press keeps its handler while the carry is held, and the panel routes a held carry's
    /// drag and release (live pointer) whichever view took the press. Before, the press view lost its handler on the
    /// edge change, so the release never ended the carry and the widget could not be dragged again.
    func testRingCarryOntoAnotherEdgeStillDropsAndTheWidgetDragsAgain() async throws {
        let pointer = Pointer()
        let o = try await openCardAndPressItsRing(pointer, screen: screen)
        let dock = o.dock, view = o.view
        let bottom = CGPoint(x: screen.visibleFrame.midX, y: screen.visibleFrame.minY + 2)
        pointer.at = bottom
        view.performPointerDrag(atLocal: o.local, global: bottom)
        XCTAssertEqual(dock.edgePresentation?.placement?.edge, .bottom, "precondition: the carry shows the bottom edge")
        XCTAssertTrue(dock.hasPanelCarry, "the panel routes the held carry")
        let first = try XCTUnwrap(dock.edgePresentation?.paintedFrame)

        // The press view keeps receiving the drag: the carry follows it along the bottom edge.
        let along = CGPoint(x: bottom.x + 100, y: bottom.y)
        pointer.at = along
        view.performPointerDrag(atLocal: o.local, global: along)
        let followed = try XCTUnwrap(dock.edgePresentation?.paintedFrame)
        XCTAssertEqual(followed.midX - first.midX, 100, accuracy: 1, "the carry still follows the pointer after the edge change")

        // ... and the release ends the carry and saves the bottom edge. The check reads the persisted Settings
        // document (the store the commit writes), not the edge controller's in-memory destination (macrevc-969-1).
        view.performPointerUp(atLocal: o.local, global: along)
        XCTAssertFalse(dock.hasPanelCarry, "the release ended the carry")
        XCTAssertNotEqual(dock.edgePresentation?.moving, true)
        XCTAssertEqual(dock.edgePresentation?.placement?.edge, .bottom, "the drop lands on the bottom edge")
        let saveBy = ContinuousClock.now + .seconds(10)
        var saved = await o.store.snapshot().preferences
        while saved.dockEdge != .bottom && ContinuousClock.now < saveBy {
            try await Task.sleep(for: .milliseconds(50)); saved = await o.store.snapshot().preferences
        }
        XCTAssertEqual(saved.dockEdge, .bottom, "the drop is saved: stored display \(saved.dockDisplayID ?? "nil"), fraction \(saved.dockAlongFraction)")
        XCTAssertEqual(saved.dockDisplayID, "primary")

        // A second drag, on the body of the bottom-edge widget, still moves it.
        try await Task.sleep(for: .milliseconds(50))
        let painted = try XCTUnwrap(dock.edgePresentation?.paintedFrame)
        let window = try XCTUnwrap(NSApplication.shared.windows.first { $0 is PulseDockPanel && $0.isVisible && $0.frame.insetBy(dx: 1, dy: 1).intersects(painted) },
                                   "the widget panel")
        let shown = try XCTUnwrap(window.contentView?.subviews.compactMap { $0 as? DockInstrumentView }.first, "the bottom-edge view is in the panel")
        let drag = try XCTUnwrap(shown.backgroundDragDelegate, "the presented view has the drag handler")
        let local = try XCTUnwrap(stride(from: 4.0, to: shown.bounds.height, by: 4).lazy.flatMap { y in
            stride(from: 4.0, to: shown.bounds.width, by: 4).map { CGPoint(x: $0, y: y) }
        }.first { drag.backgroundCanDrag(local: $0) }, "the widget body is draggable")
        let rest = try XCTUnwrap(dock.edgePresentation?.paintedFrame)
        let down = window.convertToScreen(shown.convert(CGRect(origin: local, size: .zero), to: nil)).origin
        pointer.at = down
        XCTAssertTrue(drag.beginBackgroundMove(local: local, global: down), "a new drag is taken")
        let next = CGPoint(x: down.x - 150, y: down.y)
        pointer.at = next
        drag.updateBackgroundMove(global: next)
        let again = try XCTUnwrap(dock.edgePresentation?.paintedFrame)
        XCTAssertEqual(again.midX - rest.midX, -150, accuracy: 1, "the second drag moves the widget")
        drag.endBackgroundMove(global: next)
        await o.app.stopLifecycle(); dock.close()
    }
}
