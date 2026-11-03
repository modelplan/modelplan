// SPDX-License-Identifier: MIT
import XCTest
import ModelPlanDock

@MainActor private final class CardLogicScheduler: DockEdgeScheduling {
    private(set) var deadline: TimeInterval?
    private var action: (@MainActor () -> Void)?
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) { self.deadline = deadline; self.action = action }
    func cancel() { deadline = nil; action = nil }
    func fire() { let current = action; action = nil; deadline = nil; current?() }
}

final class CardLeaveLogicTests: XCTestCase {
    func testHoverStaysAcrossGapAndClosesAfterLeaving() throws {
        var state = DockCardInteraction()
        try state.step(catalogue: ["synthetic"], hoveredID: "synthetic", insideShared: true, parentOwnsHide: true, parentExpanded: true, menuActuallyOpen: false, at: 0)
        try state.step(catalogue: ["synthetic"], hoveredID: "synthetic", insideShared: true, parentOwnsHide: true, parentExpanded: true, menuActuallyOpen: false, at: 0.25)
        XCTAssertEqual(state.visibility, .hover("synthetic"))
        try state.step(catalogue: ["synthetic"], hoveredID: nil, insideShared: false, parentOwnsHide: true, parentExpanded: true, menuActuallyOpen: false, at: 0.30)
        try state.step(catalogue: ["synthetic"], hoveredID: nil, insideShared: true, parentOwnsHide: true, parentExpanded: true, menuActuallyOpen: false, at: 0.45)
        XCTAssertEqual(state.visibility, .hover("synthetic"), "Crossing the gap keeps the card open")
        try state.step(catalogue: ["synthetic"], hoveredID: nil, insideShared: false, parentOwnsHide: true, parentExpanded: true, menuActuallyOpen: false, at: 1.02)
        try state.step(catalogue: ["synthetic"], hoveredID: nil, insideShared: false, parentOwnsHide: true, parentExpanded: true, menuActuallyOpen: false, at: 1.30)
        XCTAssertEqual(state.visibility, .hidden)
    }

    @MainActor func testOpenCardPollsSharedRegionWithoutPointerEvents() throws {
        var now = 0.0
        var env = DockInteractionEnvironment(catalogue: ["synthetic"], preferences: .init(), targets: [], hoveredID: "synthetic", insideShared: true,
            contents: ["synthetic": .init(subscriptionID: "synthetic", name: "Synthetic", rows: [])])
        let scheduler = CardLogicScheduler()
        let controller = DockInteractionController(clock: { now }, scheduler: scheduler, read: { env })
        controller.start(); now = 0.25; scheduler.fire()
        XCTAssertEqual(controller.presentation?.card, .hover("synthetic"))
        XCTAssertEqual(scheduler.deadline ?? -1, 0.40, accuracy: 0.001)
        env.hoveredID = nil; env.insideShared = false; now = 0.40; scheduler.fire()
        XCTAssertEqual(controller.presentation?.card, .hover("synthetic"))
        now = 0.66; scheduler.fire()
        XCTAssertEqual(controller.presentation?.card, .hidden)
        controller.stop()
    }

    @MainActor func testNoMovementActivatesButDragDoesNot() {
        let env = DockInteractionEnvironment(catalogue: ["synthetic"], preferences: .init(),
            targets: [.init(id: "synthetic", along: 0)], insideShared: true)
        let controller = DockInteractionController(clock: { 0 }, scheduler: CardLogicScheduler(), read: { env })
        var activated: [String] = []
        controller.onActivate = { activated.append($0) }
        controller.start()
        XCTAssertTrue(controller.beginNozzle(id: "synthetic", along: 0))
        controller.moveNozzle(along: 10)
        controller.endNozzle(insideMain: true, overSameSource: true)
        XCTAssertTrue(activated.isEmpty, "A drag must not request refresh")
        XCTAssertTrue(controller.beginNozzle(id: "synthetic", along: 0))
        controller.endNozzle(insideMain: true, overSameSource: true)
        XCTAssertEqual(activated, ["synthetic"])
        controller.stop()
    }

    @MainActor func testHoveredCardWithdrawsWhenMemberOrLifecycleIsInvalid() throws {
        var now = 0.0
        var env = DockInteractionEnvironment(catalogue: ["synthetic"], preferences: .init(), targets: [], hoveredID: "synthetic", insideShared: true,
            contents: ["synthetic": .init(subscriptionID: "synthetic", name: "Synthetic", rows: [])])
        let scheduler = CardLogicScheduler()
        let controller = DockInteractionController(clock: { now }, scheduler: scheduler, read: { env })
        controller.start(); now = 0.25; scheduler.fire()
        XCTAssertEqual(controller.presentation?.card, .hover("synthetic"))
        env.catalogue = []; env.contents = [:]; controller.refresh()
        XCTAssertEqual(controller.presentation?.card, .hidden)
        controller.click("synthetic")
        XCTAssertEqual(controller.presentation?.card, .hidden, "A removed member cannot reopen")
        env.catalogue = ["synthetic"]; env.contents = ["synthetic": .init(subscriptionID: "synthetic", name: "Synthetic", rows: [])]
        controller.refresh()
        env.active = false; controller.refresh()
        XCTAssertEqual(controller.presentation?.card, .hidden, "Inactive lifecycle must withdraw the card")
        controller.stop()
    }

    func testOnlyKeyWindowFocusedDescendantControlProtectsCard() {
        XCTAssertFalse(DockCardFocus.protectsCard(isKeyWindow: false, isDescendant: true, isFocusableControl: true))
        XCTAssertFalse(DockCardFocus.protectsCard(isKeyWindow: true, isDescendant: false, isFocusableControl: false))
        XCTAssertFalse(DockCardFocus.protectsCard(isKeyWindow: true, isDescendant: true, isFocusableControl: false))
        XCTAssertTrue(DockCardFocus.protectsCard(isKeyWindow: true, isDescendant: true, isFocusableControl: true))
        XCTAssertFalse(DockCardFocus.protectsCard(isKeyWindow: true, isDescendant: true, isFocusableControl: true, isCurrent: false), "Stale cards must not protect visibility")
    }

    func testFocusedCardProtectsAutoHideUntilFocusLeavesAndLifecycleWins() throws {
        var visibility = DockVisibilityState(), presence = DockPresence()
        presence.autoHide = true; presence.pointer = .outside; presence.cardFocused = true
        XCTAssertEqual(try visibility.step(presence, at: 0, intent: .reveal).state, .expanded)
        XCTAssertEqual(try visibility.step(presence, at: 4).state, .expanded)
        presence.cardFocused = false
        XCTAssertEqual(try visibility.step(presence, at: 4.1).state, .expanded, "Focus loss starts a fresh leave grace")
        XCTAssertEqual(try visibility.step(presence, at: 4.61).state, .sliver)
        presence.cardFocused = true
        _ = try visibility.step(presence, at: 5, intent: .reveal)
        let oldGeneration = visibility.generation
        presence.lifecycleActive = false
        XCTAssertEqual(try visibility.step(presence, at: 5.1, intent: .lifecycleCancel).state, .suppressed(.lifecycle))
        XCTAssertThrowsError(try visibility.step(presence, at: 5.2, expectedGeneration: oldGeneration))
    }

}
