// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings
import ModelPlanWire
@testable import ModelPlanAppIntegration

/// G3-120 / G3-114: the ring card opens and closes like Pulse (qunqin24/Pulse 7668384, behaviour only).
/// Timing model (DockCardInteraction): a ring's card opens on arrival, with no dwell (Pulse `select`; the 250 ms
/// `notchDwell` is the notch housing's, never a ring's); one card at a time, switching at once to another ring;
/// held by its ring, the card and the band between them; closed on the first 150 ms sample off that hold (Pulse
/// `PanelPointerWatcher.interval`, `pointerMoved` -> `deselect`), at once on a press outside it; closed when a
/// carry starts, and not reopened by the drop alone (FUC:204-206). Every check runs on an injected clock.
@MainActor private final class RingCardDeadlines: DockEdgeScheduling {
    var deadline: TimeInterval?
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) { self.deadline = deadline }
    func cancel() { deadline = nil }
}

@MainActor final class RingCardTimingTests: XCTestCase {
    @MainActor private struct Rig {
        let controller: DockInteractionController
        let deadlines: RingCardDeadlines
        var card: String? { controller.presentation?.card.subscriptionID }
    }
    private var now: TimeInterval = 0
    private var env = DockInteractionEnvironment(catalogue: ["a", "b"], preferences: .init(), targets: [], insideShared: false,
        contents: ["a": .init(subscriptionID: "a", name: "A", rows: []), "b": .init(subscriptionID: "b", name: "B", rows: [])])

    private func rig() -> Rig {
        let deadlines = RingCardDeadlines()
        let controller = DockInteractionController(clock: { [unowned self] in self.now }, scheduler: deadlines) { [unowned self] in self.env }
        controller.start()
        return Rig(controller: controller, deadlines: deadlines)
    }
    private func at(_ time: TimeInterval, _ rig: Rig, hover: String?, inside: Bool?, pressed: Bool = false, carrying: Bool = false) {
        now = time; env.hoveredID = hover; env.insideShared = inside; env.pressedOutside = pressed; env.carrying = carrying
        env.hoverEventRevision &+= 1
        rig.controller.refresh()
    }
    private func open(_ rig: Rig, _ id: String = "a") {
        at(now, rig, hover: id, inside: true)
        XCTAssertEqual(rig.card, id)
    }

    func testTimingModelConstants() {
        XCTAssertEqual(DockCardInteraction.leaveSample, 0.150, "Pulse PanelPointerWatcher.interval")
    }

    /// Fails before: the card waited out a 250 ms ring dwell that Pulse does not have.
    func testARingOpensItsCardOnArrivalWithNoDwell() {
        let r = rig()
        at(1.0, r, hover: "a", inside: true)
        XCTAssertEqual(r.card, "a", "the card opens on the first sample on the ring")
        XCTAssertEqual(r.deadlines.deadline ?? -1, 1.15, accuracy: 0.0001, "an open card is re-sampled every 150 ms")
    }

    func testAPassOverTheRingsShowsEachInTurnAndLeavingClosesOnTheNextSample() {
        let r = rig()
        at(1.0, r, hover: "a", inside: true)
        at(1.05, r, hover: "b", inside: true)
        XCTAssertEqual(r.card, "b", "one card at a time, the ring under the pointer")
        at(1.1, r, hover: nil, inside: false)
        XCTAssertEqual(r.card, "b")
        at(1.3, r, hover: nil, inside: false)
        XCTAssertNil(r.card, "closed by the next sample after the pointer left")
    }

    func testTheCardStaysWhileThePointerCrossesFromRingToCard() {
        let r = rig(); now = 1; open(r)
        // Off the ring, inside the band between ring and card, then on the card: many samples long.
        for step in 1...20 { at(now + 0.1, r, hover: nil, inside: true); XCTAssertEqual(r.card, "a", "step \(step)") }
    }

    func testLeavingClosesOnTheNextSampleAndComingBackCancelsIt() {
        let r = rig(); now = 1; open(r)
        let left = now + 0.1
        at(left, r, hover: nil, inside: false)
        XCTAssertEqual(r.card, "a", "the first outside sample arms the close")
        XCTAssertEqual(r.deadlines.deadline ?? -1, left + DockCardInteraction.leaveSample, accuracy: 0.0001)
        at(left + 0.1, r, hover: nil, inside: true)
        at(left + 0.2, r, hover: nil, inside: false)
        at(left + 0.2 + 0.149, r, hover: nil, inside: false)
        XCTAssertEqual(r.card, "a", "an inside sample called the close off")
        at(left + 0.2 + 0.15, r, hover: nil, inside: false)
        XCTAssertNil(r.card, "closed once the next sample was still outside")
        XCTAssertNil(r.deadlines.deadline, "nothing left armed after the close")
    }

    func testAPressOutsideClosesAtOnce() {
        let r = rig(); now = 1; open(r)
        at(now + 0.01, r, hover: nil, inside: false, pressed: true)
        XCTAssertNil(r.card, "an outside click closes without waiting for a sample")
        // A press inside the hold (the card, its ring, or a held widget press) keeps it.
        at(now + 0.01, r, hover: nil, inside: false)
        open(r)
        at(now + 0.01, r, hover: nil, inside: true, pressed: false)
        XCTAssertEqual(r.card, "a")
    }

    func testAnOpenWidgetMenuIsNotClosedByAnOutsidePress() {
        let r = rig(); now = 1; open(r)
        env.menuActuallyOpen = true
        at(now + 0.01, r, hover: nil, inside: false, pressed: true)
        at(now + 1, r, hover: nil, inside: false)
        XCTAssertEqual(r.card, "a")
        env.menuActuallyOpen = false
    }

    func testNeverTwoCardsAndASecondRingSwitchesAtOnce() {
        let r = rig(); now = 1; open(r)
        var shown = [String?]()
        r.controller.onPresent = { shown.append($0.card.subscriptionID) }
        at(now + 0.01, r, hover: "b", inside: true)
        XCTAssertEqual(r.card, "b", "with a card open, the next ring's card shows at once")
        at(now + 0.01, r, hover: "a", inside: true)
        XCTAssertEqual(r.card, "a")
        XCTAssertTrue(shown.allSatisfy { $0 != nil }, "the switch never passes through a closed card")
        XCTAssertEqual(shown, ["b", "a"], "exactly one card at each step")
    }

    /// G3-114 (Pulse FUC:204-206): a carry closes the card on its first moved frame; nothing opens while it is held,
    /// and the drop alone does not reopen the card of the ring that was carried under the pointer.
    func testACarryClosesTheCardAndTheDropAloneReopensNothing() {
        let r = rig(); now = 1; open(r)
        at(now + 0.01, r, hover: "a", inside: true, carrying: true)
        XCTAssertNil(r.card, "the carry closes the card at once")
        XCTAssertNil(r.deadlines.deadline, "nothing is armed while carried")
        at(now + 0.2, r, hover: "b", inside: true, carrying: true)
        XCTAssertNil(r.card, "sweeping the rings while carried opens nothing")
        at(now + 0.01, r, hover: "b", inside: true)
        at(now + 0.5, r, hover: "b", inside: true)
        XCTAssertNil(r.card, "the drop alone reopens nothing")
        at(now + 0.01, r, hover: nil, inside: false)
        at(now + 0.01, r, hover: "b", inside: true)
        XCTAssertEqual(r.card, "b", "arriving on a ring after the drop opens it as usual")
    }
}

// MARK: - The host: the pointer sample reads the ring and decides the hold.

private actor RingCardClient: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore, rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "g3-120", floor: .init(storeEpoch: "g3-120", generation: 1), revision: 1)
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch,
            consentGeneration: 1, data: rows), delivery: context), invalidRowCount: rows.projection.invalidRowCount))
        return context
    }
    func stop() async {}
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("g3-120-rows")) }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}
@MainActor private final class RingCardHostTimer: DockEdgeScheduling {
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) {}
    func cancel() {}
}

@MainActor final class RingCardHostTimingTests: XCTestCase {
    private var pointer = CGPoint(x: 700, y: 450), elapsed = 0.0, pressed = false, cardFrame: CGRect?

    private func widget() async throws -> (dock: StaticDockPreviewHost, id: String, ring: CGRect) {
        _ = NSApplication.shared
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g3-120-card-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(root["projection"] as? [String: Any])
        var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
        var row = rows[0], accounts = try XCTUnwrap(row["accounts"] as? [[String: Any]])
        var account = accounts[0], windows = try XCTUnwrap(account["windows"] as? [[String: Any]])
        row["id"] = "codex"; row["state"] = "fresh"; row["consent"] = "allowed"; row["surfaces"] = ["dock"]
        row["expiresAt"] = "2028-12-01T00:00:00Z"
        account["subscriptionRef"] = "aaaaaaaaaaaaaaaa"; account["valueState"] = "current"
        account["observedAt"] = "2026-12-01T00:00:00Z"; account["freshUntil"] = "2028-12-01T00:00:00Z"
        account["lastFailure"] = NSNull()
        windows[0].removeValue(forKey: "modelScope"); windows[0]["current"] = true
        windows[0]["observedAt"] = "2026-12-01T00:00:00Z"; windows[0]["validUntil"] = "2028-12-01T00:00:00Z"
        windows[0]["resetsAt"] = "2028-12-01T00:00:00Z"; windows[0]["remainingPercent"] = 42.0
        account["windows"] = [windows[0]]; row["accounts"] = [account]; rows[0] = row
        projection["rows"] = rows; projection.removeValue(forKey: "resetEvents"); root["projection"] = projection
        let snapshot = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
        let settings = try await expandedWidgetSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-01-01T00:00:00Z"))
        let display = DockDisplayArea(id: "synthetic", frame: .init(x: 0, y: 0, width: 1440, height: 900), visibleFrame: .init(x: 0, y: 80, width: 1440, height: 820))
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true),
            settingsStore: settings, createsNativePanels: false,
            dockEnvironment: { [unowned self] in
                var presence = DockPresence(); presence.mouseButtonDown = self.pressed
                return .init(displays: [display], layouts: [], primaryDisplayID: "synthetic", pointer: self.pointer, presence: presence, cardFrame: self.cardFrame)
            },
            deadlineNow: { now }, deadlineElapsed: { [unowned self] in self.elapsed }, deadlineScheduling: RingCardHostTimer(),
            makeClient: { _, store in RingCardClient(store: store, rows: snapshot) }, activateSettings: {})
        addTeardownBlock { @MainActor in app.composition.dock.close() }
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        let dock = app.composition.dock, id = "aaaaaaaaaaaaaaaa"
        XCTAssertEqual(dock.edgePresentation?.state, .expanded)
        let placement = try XCTUnwrap(dock.edgePresentation?.placement), anchor = try XCTUnwrap(dock.dockView.interactionAnchor(id))
        let ring = try XCTUnwrap(StaticDockPreviewHost.interactionGlobal(anchor, view: dock.dockView, frame: placement.frame, expanded: true))
        return (dock, id, ring)
    }
    private func tick(_ dock: StaticDockPreviewHost, _ seconds: TimeInterval) {
        elapsed += seconds; dock.interactionControllerForChecks?.refresh()
    }

    /// Fails before G3-120: only a tracking event could name the ring, so a widget that opened under a
    /// resting pointer (no mouse-moved yet) never opened its card; and the card then waited out a ring dwell.
    func testARingUnderARestingPointerOpensItsCardOnTheFirstSampleWithoutAnyHoverEvent() async throws {
        let (dock, id, ring) = try await widget()
        pointer = CGPoint(x: ring.midX, y: ring.midY)
        tick(dock, 0)
        XCTAssertFalse(dock.card.isHidden, "the sampled ring opens its card at once, no dwell")
        XCTAssertEqual(dock.interactionControllerForChecks?.presentation?.card.subscriptionID, id)
    }

    /// Fails before G3-120: the whole widget body held an open card, so a pointer resting on the widget away
    /// from the ring kept the card up indefinitely ("stays up far too long").
    func testThePointerRestingOnTheWidgetBodyAwayFromTheRingClosesTheCardOnTheNextSample() async throws {
        let (dock, id, ring) = try await widget()
        let placement = try XCTUnwrap(dock.edgePresentation?.placement)
        pointer = CGPoint(x: ring.midX, y: ring.midY)
        try XCTUnwrap(dock.dockView.nozzleEventDelegate).hoverNozzle(id)
        tick(dock, 0.251)
        XCTAssertFalse(dock.card.isHidden)
        // A painted point of the widget body, well clear of the ring and of every ring unit.
        let hold = ring.insetBy(dx: -40, dy: -40)
        var body: CGPoint?
        search: for rect in placement.globalHoverRects {
            for y in stride(from: rect.minY + 2, to: rect.maxY - 2, by: 2) {
                for x in stride(from: rect.minX + 2, to: rect.maxX - 2, by: 2) {
                    let p = CGPoint(x: x, y: y)
                    guard !hold.contains(p), abs(p.y - ring.midY) > 60 || abs(p.x - ring.midX) > 60,
                          let local = StaticDockPreviewHost.interactionLocal(p, view: dock.dockView, frame: placement.frame),
                          dock.dockView.ringUnitID(atLocal: local) == nil else { continue }
                    body = p; break search
                }
            }
        }
        pointer = try XCTUnwrap(body, "the widget paints body away from its ring")
        try XCTUnwrap(dock.dockView.nozzleEventDelegate).hoverNozzle(nil)
        XCTAssertEqual(dock.interactionEnvironment().insideShared, false, "the widget body is not the card's hold")
        tick(dock, 0.1)
        XCTAssertFalse(dock.card.isHidden, "the first outside sample only arms the close")
        tick(dock, 0.16)
        XCTAssertTrue(dock.card.isHidden, "closed by the next 150 ms sample off the ring and card")
    }

    func testTheBandBetweenRingAndCardHoldsTheCard() async throws {
        let (dock, id, ring) = try await widget()
        let edge = try XCTUnwrap(dock.edgePresentation?.placement?.edge)
        pointer = CGPoint(x: ring.midX, y: ring.midY)
        try XCTUnwrap(dock.dockView.nozzleEventDelegate).hoverNozzle(id)
        tick(dock, 0.251)
        XCTAssertFalse(dock.card.isHidden)
        // The card sits 12 pt inward of its ring (detached host: its frame is the injected card frame).
        let card: CGRect, path: [CGPoint]
        switch edge {
        case .left:
            card = CGRect(x: ring.maxX + 12, y: ring.midY - 100, width: 300, height: 200)
            path = stride(from: ring.maxX + 2, through: card.midX, by: 6).map { CGPoint(x: $0, y: ring.midY + 30) }
        case .bottom:
            card = CGRect(x: ring.midX - 150, y: ring.maxY + 12, width: 300, height: 200)
            path = stride(from: ring.maxY + 2, through: card.midY, by: 6).map { CGPoint(x: ring.midX + 30, y: $0) }
        default:
            card = CGRect(x: ring.minX - 12 - 300, y: ring.midY - 100, width: 300, height: 200)
            path = stride(from: ring.minX - 2, through: card.midX, by: -6).map { CGPoint(x: $0, y: ring.midY + 30) }
        }
        cardFrame = card
        try XCTUnwrap(dock.dockView.nozzleEventDelegate).hoverNozzle(nil)
        for p in path {
            pointer = p
            XCTAssertEqual(dock.interactionEnvironment().insideShared, true, "\(p): ring, band and card hold the card")
            tick(dock, 0.1)
            XCTAssertFalse(dock.card.isHidden, "\(p)")
        }
        tick(dock, 1)
        XCTAssertFalse(dock.card.isHidden, "resting on the card keeps it")
        pointer = CGPoint(x: 700, y: 450)
        tick(dock, 0.1); tick(dock, 0.16)
        XCTAssertTrue(dock.card.isHidden, "off ring, band and card: closed on the next sample")
        cardFrame = nil
    }

    /// Fails before G3-120: an outside click waited out the grace like a slow leave.
    func testAPressOutsideClosesTheCardAtOnce() async throws {
        let (dock, id, ring) = try await widget()
        pointer = CGPoint(x: ring.midX, y: ring.midY)
        try XCTUnwrap(dock.dockView.nozzleEventDelegate).hoverNozzle(id)
        tick(dock, 0.251)
        XCTAssertFalse(dock.card.isHidden)
        pointer = CGPoint(x: 200, y: 400); pressed = true
        try XCTUnwrap(dock.dockView.nozzleEventDelegate).hoverNozzle(nil)
        tick(dock, 0)
        XCTAssertTrue(dock.card.isHidden, "an outside press closes at once")
        pressed = false
    }

    /// T4 (post-merge sampling 11-17): the card closed on an outside press only when a 150 ms sample saw the button
    /// down. A click pressed and released between two samples was missed, so the card waited out the leave deadline.
    /// The mouse-down monitor reports the press for an immediate sample. Fails before: the card is still shown.
    func testAnOutsideClickBetweenTwoSamplesClosesTheCardAtOnce() async throws {
        let (dock, id, ring) = try await widget()
        pointer = CGPoint(x: ring.midX, y: ring.midY)
        try XCTUnwrap(dock.dockView.nozzleEventDelegate).hoverNozzle(id)
        tick(dock, 0.251)
        XCTAssertFalse(dock.card.isHidden)
        pointer = CGPoint(x: 200, y: 400)
        try XCTUnwrap(dock.dockView.nozzleEventDelegate).hoverNozzle(nil)
        tick(dock, 0.01)
        XCTAssertFalse(dock.card.isHidden, "precondition: one outside sample only arms the close")
        // Pressed and released before the next sample: no sample ever sees the button down.
        elapsed += 0.05
        dock.observeMouseDown()
        XCTAssertFalse(pressed)
        XCTAssertTrue(dock.card.isHidden, "the outside press closes the card at once, not at the leave deadline")
    }

    /// T4: a press on the card's own ring is not an outside press; the card stays.
    func testAPressOnTheOpenCardsRingKeepsTheCard() async throws {
        let (dock, id, ring) = try await widget()
        pointer = CGPoint(x: ring.midX, y: ring.midY)
        try XCTUnwrap(dock.dockView.nozzleEventDelegate).hoverNozzle(id)
        tick(dock, 0.251)
        XCTAssertFalse(dock.card.isHidden)
        dock.observeMouseDown()
        XCTAssertFalse(dock.card.isHidden, "a press on the ring holds the card")
    }

    /// #960 post-merge sampling (P3): a ring carry released or cancelled through the panel route (hasPanelCarry)
    /// never reaches the view's pointerUp, which was the only place the closed-hand cursor was reset.
    func testAPanelRoutedReleaseOrCancelRestoresTheArrowCursor() async throws {
        let (dock, _, ring) = try await widget()
        var restored = 0
        dock.restorePanelMoveCursor = { restored += 1 }
        dock.finishPanelMove(globalPoint: CGPoint(x: ring.midX, y: ring.midY))
        XCTAssertEqual(restored, 1, "a panel-routed drop restores the arrow")
        dock.cancelPanelMove()
        XCTAssertEqual(restored, 2, "a panel-routed cancel restores the arrow")
    }
}
