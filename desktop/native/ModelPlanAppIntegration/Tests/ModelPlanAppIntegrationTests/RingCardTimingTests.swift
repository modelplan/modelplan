// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings
import ModelPlanWire
@testable import ModelPlanAppIntegration

/// G3-120: the ring card opens and closes like Pulse. Timing model (DockCardInteraction):
/// open after a 250 ms dwell on one ring; a quicker pass opens nothing; one card at a time, switching at
/// once to another ring; held by its ring, the card and the band between them; closed 250 ms after the
/// pointer leaves that hold, at once on a press outside it. Every check runs on an injected clock.
@MainActor private final class RingCardDeadlines: DockEdgeScheduling {
    var deadline: TimeInterval?
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) { self.deadline = deadline }
    func cancel() { deadline = nil }
}

@MainActor final class RingCardTimingTests: XCTestCase {
    private struct Rig {
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
    private func at(_ time: TimeInterval, _ rig: Rig, hover: String?, inside: Bool?, pressed: Bool = false) {
        now = time; env.hoveredID = hover; env.insideShared = inside; env.pressedOutside = pressed
        env.hoverEventRevision &+= 1
        rig.controller.refresh()
    }
    private func open(_ rig: Rig, _ id: String = "a") {
        at(now, rig, hover: id, inside: true)
        at(now + DockCardInteraction.entryDwell, rig, hover: id, inside: true)
        XCTAssertEqual(rig.card, id)
    }

    func testTimingModelConstants() {
        XCTAssertEqual(DockCardInteraction.entryDwell, 0.250)
        XCTAssertEqual(DockCardInteraction.independentLeaveGrace, 0.250)
    }

    func testOpensAfterTheDwellAndNotBefore() {
        let r = rig()
        at(1.0, r, hover: "a", inside: true)
        XCTAssertNil(r.card)
        XCTAssertEqual(r.deadlines.deadline ?? -1, 1.25, accuracy: 0.0001, "the open is armed at the dwell deadline")
        at(1.249, r, hover: "a", inside: true)
        XCTAssertNil(r.card, "not before the dwell")
        at(1.25, r, hover: "a", inside: true)
        XCTAssertEqual(r.card, "a")
    }

    func testAQuickPassOpensNothing() {
        let r = rig()
        at(1.0, r, hover: "a", inside: true)
        at(1.1, r, hover: nil, inside: false)
        at(1.3, r, hover: nil, inside: false)
        at(2.0, r, hover: nil, inside: false)
        XCTAssertNil(r.card, "a pointer that crossed the ring and left opens no card")
        // Crossing two rings in turn restarts the dwell for each; neither opens on the way.
        at(3.0, r, hover: "a", inside: true)
        at(3.2, r, hover: "b", inside: true)
        at(3.3, r, hover: "a", inside: true)
        XCTAssertNil(r.card)
    }

    func testTheCardStaysWhileThePointerCrossesFromRingToCard() {
        let r = rig(); now = 1; open(r)
        // Off the ring, inside the band between ring and card, then on the card: well past the grace.
        for step in 1...20 { at(now + 0.1, r, hover: nil, inside: true); XCTAssertEqual(r.card, "a", "step \(step)") }
    }

    func testLeavingClosesAfterTheGraceAndComingBackCancelsIt() {
        let r = rig(); now = 1; open(r)
        let left = now + 0.1
        at(left, r, hover: nil, inside: false)
        XCTAssertEqual(r.card, "a", "the grace starts on the first outside sample")
        XCTAssertEqual(r.deadlines.deadline ?? -1, left + DockCardInteraction.independentLeaveGrace, accuracy: 0.0001)
        at(left + 0.2, r, hover: nil, inside: true)
        at(left + 0.3, r, hover: nil, inside: false)
        at(left + 0.3 + 0.249, r, hover: nil, inside: false)
        XCTAssertEqual(r.card, "a", "an inside sample restarted the grace")
        at(left + 0.3 + 0.25, r, hover: nil, inside: false)
        XCTAssertNil(r.card, "closed once the pointer stayed out for the grace")
        XCTAssertNil(r.deadlines.deadline, "nothing left armed after the close")
    }

    func testAPressOutsideClosesAtOnce() {
        let r = rig(); now = 1; open(r)
        at(now + 0.01, r, hover: nil, inside: false, pressed: true)
        XCTAssertNil(r.card, "an outside click closes without the grace")
        // A press inside the hold (the card, its ring, or a held widget carry) keeps it.
        open(r)
        at(now + 0.01, r, hover: nil, inside: true, pressed: false)
        env.pressedOutside = false
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
        XCTAssertEqual(r.card, "b", "with a card open, the next ring's card shows without a second dwell")
        at(now + 0.01, r, hover: "a", inside: true)
        XCTAssertEqual(r.card, "a")
        XCTAssertTrue(shown.allSatisfy { $0 != nil }, "the switch never passes through a closed card")
        XCTAssertEqual(shown, ["b", "a"], "exactly one card at each step")
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
    /// resting pointer (no mouse-moved yet) never opened its card.
    func testARingUnderARestingPointerOpensItsCardAfterTheDwellWithoutAnyHoverEvent() async throws {
        let (dock, id, ring) = try await widget()
        pointer = CGPoint(x: ring.midX, y: ring.midY)
        tick(dock, 0)
        XCTAssertTrue(dock.card.isHidden, "not before the dwell")
        tick(dock, 0.2)
        XCTAssertTrue(dock.card.isHidden)
        tick(dock, 0.06)
        XCTAssertFalse(dock.card.isHidden, "the sampled ring opens its card after 250 ms")
        XCTAssertEqual(dock.interactionControllerForChecks?.presentation?.card.subscriptionID, id)
    }

    /// Fails before G3-120: the whole widget body held an open card, so a pointer resting on the widget away
    /// from the ring kept the card up indefinitely ("stays up far too long").
    func testThePointerRestingOnTheWidgetBodyAwayFromTheRingClosesTheCardAfterTheGrace() async throws {
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
        XCTAssertFalse(dock.card.isHidden, "still inside the grace")
        tick(dock, 0.26)
        XCTAssertTrue(dock.card.isHidden, "closed 250 ms after the pointer left the ring and card")
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
        tick(dock, 0.1); tick(dock, 0.2)
        XCTAssertTrue(dock.card.isHidden, "off ring, band and card: closed after the grace")
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
        XCTAssertTrue(dock.card.isHidden, "an outside press closes without the grace")
        pressed = false
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
