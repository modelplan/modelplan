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
    func testOrdinaryClickClosesAfterLeavingSharedRegion() throws {
        var state = DockCardInteraction()
        try state.step(catalogue: ["synthetic"], hoveredID: nil, insideShared: true, parentOwnsHide: true, parentExpanded: true, menuActuallyOpen: false, at: 0)
        try state.click("synthetic", at: 0.01)
        XCTAssertEqual(state.visibility, .hover("synthetic"), "A click must not silently pin")
        try state.step(catalogue: ["synthetic"], hoveredID: nil, insideShared: true, parentOwnsHide: true, parentExpanded: true, menuActuallyOpen: false, at: 0.10)
        XCTAssertEqual(state.visibility, .hover("synthetic"), "A pointer inside the card keeps it open")
        try state.step(catalogue: ["synthetic"], hoveredID: nil, insideShared: false, parentOwnsHide: true, parentExpanded: true, menuActuallyOpen: false, at: 0.20)
        try state.step(catalogue: ["synthetic"], hoveredID: nil, insideShared: false, parentOwnsHide: true, parentExpanded: true, menuActuallyOpen: false, at: 0.46)
        XCTAssertEqual(state.visibility, .hidden, "An ordinary card must close after leave grace")
    }
    func testExplicitPinSurvivesPointerLeaveAndCanBeReleased() throws {
        var state = DockCardInteraction()
        try state.step(catalogue: ["synthetic"], hoveredID: nil, insideShared: true, parentOwnsHide: true, parentExpanded: true, menuActuallyOpen: false, at: 0)
        try state.click("synthetic", at: 0.01)
        try state.setPinned(true, id: "synthetic", at: 0.02)
        try state.step(catalogue: ["synthetic"], hoveredID: nil, insideShared: false, parentOwnsHide: true, parentExpanded: true, menuActuallyOpen: false, at: 1)
        XCTAssertEqual(state.visibility, .pinned("synthetic"))
        try state.setPinned(false, id: "synthetic", at: 1.01)
        try state.step(catalogue: ["synthetic"], hoveredID: nil, insideShared: false, parentOwnsHide: true, parentExpanded: true, menuActuallyOpen: false, at: 1.02)
        try state.step(catalogue: ["synthetic"], hoveredID: nil, insideShared: false, parentOwnsHide: true, parentExpanded: true, menuActuallyOpen: false, at: 1.30)
        XCTAssertEqual(state.visibility, .hidden)
        XCTAssertThrowsError(try state.setPinned(true, id: "synthetic", at: 1.31))
    }

    @MainActor func testOpenCardPollsSharedRegionWithoutPointerEvents() throws {
        var now = 0.0
        var env = DockInteractionEnvironment(catalogue: ["synthetic"], preferences: .init(), targets: [], insideShared: true,
            contents: ["synthetic": .init(subscriptionID: "synthetic", name: "Synthetic", rows: [])])
        let scheduler = CardLogicScheduler()
        let controller = DockInteractionController(clock: { now }, scheduler: scheduler, read: { env })
        controller.start(); controller.click("synthetic")
        XCTAssertEqual(controller.presentation?.card, .hover("synthetic"))
        XCTAssertEqual(scheduler.deadline ?? -1, 0.15, accuracy: 0.001)
        env.insideShared = false; now = 0.15; scheduler.fire()
        XCTAssertEqual(controller.presentation?.card, .hover("synthetic"))
        now = 0.41; scheduler.fire()
        XCTAssertEqual(controller.presentation?.card, .hidden)
        controller.stop(preservingPin: false)
    }

    @MainActor func testPinnedCardWithdrawsWhenMemberOrLifecycleIsInvalid() throws {
        var env = DockInteractionEnvironment(catalogue: ["synthetic"], preferences: .init(), targets: [], insideShared: true,
            contents: ["synthetic": .init(subscriptionID: "synthetic", name: "Synthetic", rows: [])])
        let scheduler = CardLogicScheduler()
        let controller = DockInteractionController(clock: { 0 }, scheduler: scheduler, read: { env })
        controller.start(); controller.click("synthetic"); controller.setCardPinned(true, id: "synthetic")
        XCTAssertEqual(controller.presentation?.card, .pinned("synthetic"))
        env.catalogue = []; env.contents = [:]; controller.refresh()
        XCTAssertEqual(controller.presentation?.card, .hidden)
        controller.click("synthetic"); controller.setCardPinned(true, id: "synthetic")
        XCTAssertEqual(controller.presentation?.card, .hidden, "A removed member cannot reopen")
        env.catalogue = ["synthetic"]; env.contents = ["synthetic": .init(subscriptionID: "synthetic", name: "Synthetic", rows: [])]
        controller.refresh(); controller.click("synthetic"); controller.setCardPinned(true, id: "synthetic")
        env.active = false; controller.refresh()
        XCTAssertEqual(controller.presentation?.card, .hidden, "Inactive lifecycle must withdraw even a pinned card")
        controller.stop(preservingPin: false)
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
