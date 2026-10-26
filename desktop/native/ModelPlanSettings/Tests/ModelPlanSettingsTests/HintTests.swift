// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanSettings

final class HintTests: XCTestCase {
    private func open(_ n: Int = 1, dock: Bool = false, seen: Set<FirstUseHintKind> = []) throws -> FirstUseHints {
        var h = FirstUseHints(preferences: .init(seen: seen, opens: n-1, reveals: dock ? 1 : 0))
        var c = HintContext(cockpitOpen: UUID(), dockReveal: dock ? UUID() : nil); c.captureReady = true
        try h.updateContext(c, at: 0); return h
    }
    func testCaptureCompletesBeforeInitialHintAndUnplaceableSpendsNothing() throws {
        var h = FirstUseHints(), c = HintContext(cockpitOpen: UUID()); c.captureReady = false
        try h.updateContext(c, at: 0)
        XCTAssertNil(try h.nextOffer(placeable: Set(FirstUseHintKind.allCases), at: 0))
        XCTAssertTrue(h.preferences.seen.isEmpty); XCTAssertFalse(h.cockpitBudgetUsed)
        c.captureReady = true; try h.updateContext(c, at: 0.1)
        XCTAssertNil(try h.nextOffer(placeable: [], at: 0.1))
        let offer = try XCTUnwrap(h.nextOffer(placeable: [.optionHelp], at: 0.1))
        XCTAssertTrue(h.preferences.seen.isEmpty); XCTAssertFalse(h.cockpitBudgetUsed)
        h.reject(offer); XCTAssertTrue(h.preferences.seen.isEmpty)
        let second = try XCTUnwrap(h.nextOffer(placeable: [.optionHelp], at: 0.2))
        try h.confirmShown(second, at: 0.2)
        XCTAssertEqual(h.visible?.offer.kind, .optionHelp); XCTAssertTrue(h.preferences.seen.contains(.optionHelp))
    }
    func testFixedPriorityOneOpenOneRevealAndNoConcurrentOffer() throws {
        var h = try open(2, dock: true)
        var c = h.context; c.cardPinned = true; try h.updateContext(c, at: 0)
        for k in FirstUseHintKind.allCases { h.request(k) }
        try h.beginDwell(.ignition, at: 0); try h.beginDwell(.field, at: 0)
        let offer = try XCTUnwrap(h.nextOffer(placeable: Set(FirstUseHintKind.allCases), at: 0.5))
        XCTAssertEqual(offer.kind, .ignition)
        XCTAssertNil(try h.nextOffer(placeable: Set(FirstUseHintKind.allCases), at: 0.5))
        try h.confirmShown(offer, at: 0.5)
        XCTAssertTrue(h.cockpitBudgetUsed); XCTAssertTrue(h.dockBudgetUsed)
        XCTAssertThrowsError(try h.confirmShown(offer, at: 0.5))
        h.dismiss(); h.request(.trial)
        XCTAssertNil(try h.nextOffer(placeable: Set(FirstUseHintKind.allCases), at: 1))
        c.cockpitOpen = UUID(); c.dockReveal = UUID(); try h.updateContext(c, at: 2)
        XCTAssertEqual(try h.nextOffer(placeable: Set(FirstUseHintKind.allCases), at: 2)?.kind, .detach)
        XCTAssertFalse(h.preferences.seen.contains(.shutter)); XCTAssertFalse(h.preferences.seen.contains(.trial))
    }
    func testSecondOpenShutterAndCountsRemainBoundedAcrossRelaunch() throws {
        var h = try open()
        h.request(.shutter)
        let first = try XCTUnwrap(h.nextOffer(placeable: [.optionHelp,.shutter], at: 0))
        XCTAssertEqual(first.kind, .optionHelp); try h.confirmShown(first, at: 0)
        let saved = try JSONDecoder().decode(FirstUseHintPreferences.self, from: JSONEncoder().encode(h.preferences))
        h = FirstUseHints(preferences: saved)
        var c = HintContext(cockpitOpen: UUID()); c.captureReady = true; try h.updateContext(c, at: 0)
        let second = try XCTUnwrap(h.nextOffer(placeable: [.optionHelp,.shutter], at: 0)); XCTAssertEqual(second.kind, .shutter)
        try h.confirmShown(second, at: 0)
        for i in 1...10 { c.cockpitOpen = UUID(); try h.updateContext(c, at: Double(i)) }
        XCTAssertEqual(h.preferences.opens, 2)
        XCTAssertEqual(try JSONDecoder().decode(FirstUseHintPreferences.self, from: Data("{\"cockpitOpens\":999999}".utf8)).opens, 2)
        XCTAssertEqual(try JSONDecoder().decode(FirstUseHintPreferences.self, from: Data("{\"cockpitOpens\":-3}".utf8)).opens, 0)
    }
    func testFieldAndIgnitionRequire500msAndLeavingCancels() throws {
        var h = try open(dock: true, seen: [.optionHelp,.shutter])
        h.request(.field); h.request(.ignition)
        XCTAssertNil(try h.nextOffer(placeable: [.field,.ignition], at: 0))
        try h.beginDwell(.field, at: 0); try h.beginDwell(.field, at: 0.2)
        XCTAssertNil(try h.nextOffer(placeable: [.field], at: 0.499))
        h.cancelDwell(.field); XCTAssertNil(try h.nextOffer(placeable: [.field], at: 0.6))
        try h.beginDwell(.field, at: 0.6)
        XCTAssertEqual(try h.nextOffer(placeable: [.field], at: 1.1)?.kind, .field)
        h.cancelDwell(.field); XCTAssertNil(h.offered)
        try h.beginDwell(.ignition, at: 1.1)
        XCTAssertNil(try h.nextOffer(placeable: [.ignition], at: 1.599))
        XCTAssertEqual(try h.nextOffer(placeable: [.ignition], at: 1.6)?.kind, .ignition)
    }
    func testSecondRevealDragDoesNotRequirePinAndKeepsPinnedReservation() throws {
        var h = FirstUseHints(), c = HintContext(dockReveal: UUID()); c.cardPinned = true
        try h.updateContext(c, at: 0)
        XCTAssertNil(try h.nextOffer(placeable: [.pinned], at: 0))
        try h.beginDockRevealDwell(at: 0)
        let ignition = try XCTUnwrap(h.nextOffer(placeable: [.ignition,.pinned], at: 0.5))
        XCTAssertEqual(ignition.kind, .ignition); try h.confirmShown(ignition, at: 0.5); h.dismiss()
        c.dockReveal = UUID(); c.cardPinned = false; try h.updateContext(c, at: 1)
        XCTAssertEqual(h.preferences.reveals, 2); try h.beginDockRevealDwell(at: 1)
        XCTAssertNil(try h.nextOffer(placeable: [.drag], at: 1.499))
        let drag = try XCTUnwrap(h.nextOffer(placeable: [.drag], at: 1.5)); XCTAssertEqual(drag.kind, .drag)
        try h.confirmShown(drag, at: 1.5); XCTAssertTrue(h.dockBudgetUsed)
    }
    func testContextualTieOrderAndDeferredUnseenTrigger() throws {
        var h = try open(2, seen: [.optionHelp,.shutter])
        for kind in [FirstUseHintKind.trial,.pinned,.page] { h.request(kind) }
        let page = try XCTUnwrap(h.nextOffer(placeable: [.page,.pinned,.trial], at: 0)); XCTAssertEqual(page.kind, .page)
        try h.confirmShown(page, at: 0); h.dismiss()
        XCTAssertNil(try h.nextOffer(placeable: [.trial], at: 0))
        var c = h.context; c.cockpitOpen = UUID(); try h.updateContext(c, at: 1)
        let rest = try XCTUnwrap(h.beginTrialRest(on: .init(id: "travel"), at: 1))
        XCTAssertEqual(try h.offerTrialRest(rest, placeable: [.trial], at: 1.5)?.kind, .trial)
    }
    func testFiveSecondLifetimeReducedMotionAndResetPreserveUnderlyingContext() throws {
        var h = try open(2), c = HintContext(cockpitOpen: UUID(), dockReveal: UUID()); c.captureReady = true; c.cardPinned = true
        try h.updateContext(c, at: 0)
        let offer = try XCTUnwrap(h.nextOffer(placeable: [.optionHelp], at: 0)); try h.confirmShown(offer, at: 0)
        c.reducedMotion = true; try h.updateContext(c, at: 1)
        XCTAssertEqual(h.visible?.fadeSeconds, 0); XCTAssertEqual(h.visible?.expiresAt, 5)
        try h.advance(at: 4.999); XCTAssertNotNil(h.visible)
        try h.advance(at: 5); XCTAssertNil(h.visible); XCTAssertEqual(h.context, c)
        h.reset(); XCTAssertEqual(h.context, c); XCTAssertEqual(h.preferences, .init())
        XCTAssertFalse(h.cockpitBudgetUsed); XCTAssertFalse(h.dockBudgetUsed)
        XCTAssertNotNil(try h.nextOffer(placeable: [.optionHelp], at: 5))
    }
    func testStaleOffersHelpMapAndInvalidClockCannotSpendFlags() throws {
        var h = try open(), c = h.context
        let offer = try XCTUnwrap(h.nextOffer(placeable: [.optionHelp], at: 0))
        c.cockpitOpen = UUID(); try h.updateContext(c, at: 1)
        XCTAssertThrowsError(try h.confirmShown(offer, at: 1)); XCTAssertTrue(h.preferences.seen.isEmpty)
        c.helpMapVisible = true; try h.updateContext(c, at: 2)
        XCTAssertNil(try h.nextOffer(placeable: Set(FirstUseHintKind.allCases), at: 2))
        XCTAssertThrowsError(try h.advance(at: 1)); XCTAssertThrowsError(try h.advance(at: .nan))
        XCTAssertTrue(h.preferences.seen.isEmpty)
    }
    func testEveryHintHasItsExactPriorityAndOnlyConfirmedFlagIsSpent() throws {
        let priority = FirstUseHintKind.allCases
        for index in priority.indices {
            let higher = Set(priority.prefix(index))
            var h = try open(2, dock: true, seen: higher), c = HintContext(cockpitOpen: UUID(), dockReveal: UUID())
            c.captureReady = true; c.cardPinned = true; try h.updateContext(c, at: 0)
            for kind in priority { h.request(kind) }
            try h.beginDwell(.field, at: 0); try h.beginDwell(.ignition, at: 0); try h.beginDwell(.drag, at: 0)
            _ = try h.beginTrialRest(on: .init(id: "travel"), at: 0)
            let offer = try XCTUnwrap(h.nextOffer(placeable: Set(priority), at: 0.5))
            XCTAssertEqual(offer.kind, priority[index]); try h.confirmShown(offer, at: 0.5)
            XCTAssertEqual(h.preferences.seen, higher.union([priority[index]]))
        }
    }
    func testIndependentBudgetsCannotBeResetByTheOtherContext() throws {
        var h = FirstUseHints(preferences: .init(seen: [.ignition])), c = HintContext(dockReveal: UUID()); c.cardPinned = true; c.captureReady = true
        try h.updateContext(c, at: 0)
        let pinned = try XCTUnwrap(h.nextOffer(placeable: [.pinned], at: 0)); try h.confirmShown(pinned, at: 0)
        c.cockpitOpen = UUID(); try h.updateContext(c, at: 1)
        XCTAssertTrue(h.dockBudgetUsed); XCTAssertFalse(h.cockpitBudgetUsed)
        XCTAssertNil(try h.nextOffer(placeable: [.drag], at: 1))
        let option = try XCTUnwrap(h.nextOffer(placeable: [.optionHelp], at: 1)); try h.confirmShown(option, at: 1)
        c.dockReveal = UUID(); try h.updateContext(c, at: 2)
        XCTAssertFalse(h.dockBudgetUsed); XCTAssertTrue(h.cockpitBudgetUsed)
        try h.beginDockRevealDwell(at: 2)
        XCTAssertNil(try h.nextOffer(placeable: [.drag], at: 2.5))
    }
    func testSameIdentityUnpinInvalidatesOfferWithoutSpendingAndValidNextHintCanProceed() throws {
        var h = FirstUseHints(), c = HintContext(cockpitOpen: UUID(), dockReveal: UUID())
        c.captureReady = true; c.cardPinned = true; try h.updateContext(c, at: 0)
        let offer = try XCTUnwrap(h.nextOffer(placeable: [.pinned], at: 0))
        c.cardPinned = false; try h.updateContext(c, at: 0.1)
        XCTAssertNil(h.offered); XCTAssertNil(h.visible)
        XCTAssertThrowsError(try h.confirmShown(offer, at: 0.1))
        XCTAssertFalse(h.preferences.seen.contains(.pinned)); XCTAssertFalse(h.cockpitBudgetUsed); XCTAssertFalse(h.dockBudgetUsed)
        XCTAssertEqual(try h.nextOffer(placeable: [.optionHelp], at: 0.2)?.kind, .optionHelp)
    }
    func testSameIdentityUnpinRemovesVisibleHintButKeepsRealFlagAndBudgetSpend() throws {
        var h = FirstUseHints(preferences: .init(seen: [.ignition])), c = HintContext(dockReveal: UUID()); c.cardPinned = true; c.captureReady = true
        try h.updateContext(c, at: 0)
        let offer = try XCTUnwrap(h.nextOffer(placeable: [.pinned], at: 0)); try h.confirmShown(offer, at: 0)
        c.cardPinned = false; try h.updateContext(c, at: 0.1)
        XCTAssertNil(h.visible); XCTAssertTrue(h.preferences.seen.contains(.pinned)); XCTAssertTrue(h.dockBudgetUsed)
        XCTAssertEqual(h.context, c)
        c.cockpitOpen = UUID(); try h.updateContext(c, at: 1)
        XCTAssertEqual(try h.nextOffer(placeable: [.optionHelp], at: 1)?.kind, .optionHelp)
    }
    func testCaptureLossInvalidatesOnlyExistingGuardedOffersAndRecoveryUnblocksThem() throws {
        for kind in [FirstUseHintKind.detach,.optionHelp,.shutter,.field,.page,.trial] {
            var h = try open(2, seen: Set(FirstUseHintKind.allCases).subtracting([kind])), c = HintContext(cockpitOpen: UUID())
            c.captureReady = true; try h.updateContext(c, at: 0)
            h.request(kind); if kind == .field { try h.beginDwell(kind, at: 0) }; if kind == .trial { _ = try h.beginTrialRest(on: .init(id: "travel"), at: 0) }
            let offer = try XCTUnwrap(h.nextOffer(placeable: [kind], at: 0.5))
            c.captureReady = false; try h.updateContext(c, at: 0.6)
            XCTAssertNil(h.offered); XCTAssertFalse(h.preferences.seen.contains(kind)); XCTAssertFalse(h.cockpitBudgetUsed)
            XCTAssertThrowsError(try h.confirmShown(offer, at: 0.6))
            c.captureReady = true; try h.updateContext(c, at: 0.7)
            if kind == .trial {
                let rest = try XCTUnwrap(h.beginTrialRest(on: .init(id: "travel"), at: 0.7))
                XCTAssertEqual(try h.offerTrialRest(rest, placeable: [kind], at: rest.deadline)?.kind, kind)
            } else { XCTAssertEqual(try h.nextOffer(placeable: [kind], at: 0.7)?.kind, kind) }
        }
    }
    func testCaptureLossRemovesGuardedVisibleHintWithoutUndoingSeenOrOpenBudget() throws {
        var h = try open(), c = h.context
        let offer = try XCTUnwrap(h.nextOffer(placeable: [.optionHelp], at: 0)); try h.confirmShown(offer, at: 0)
        c.captureReady = false; try h.updateContext(c, at: 0.1)
        XCTAssertNil(h.visible); XCTAssertTrue(h.preferences.seen.contains(.optionHelp)); XCTAssertTrue(h.cockpitBudgetUsed)
        c.captureReady = true; try h.updateContext(c, at: 0.2)
        h.request(.page); XCTAssertNil(try h.nextOffer(placeable: [.page], at: 0.2))
        c.cockpitOpen = UUID(); try h.updateContext(c, at: 1)
        XCTAssertEqual(try h.nextOffer(placeable: [.shutter], at: 1)?.kind, .shutter)
    }
    func testCaptureLossDoesNotAddBarrierToPinnedOrDragOffersOrVisibleHints() throws {
        for kind in [FirstUseHintKind.pinned,.drag] {
            var h = FirstUseHints(preferences: .init(seen: [.ignition], reveals: 1)), c = HintContext(cockpitOpen: UUID(), dockReveal: UUID())
            c.captureReady = true; c.cardPinned = true; try h.updateContext(c, at: 0)
            if kind == .drag { try h.beginDockRevealDwell(at: 0) }
            let offer = try XCTUnwrap(h.nextOffer(placeable: [kind], at: 0.5))
            c.captureReady = false; try h.updateContext(c, at: 0.6)
            XCTAssertEqual(h.offered, offer); try h.confirmShown(offer, at: 0.6)
            try h.updateContext(c, at: 0.7); XCTAssertEqual(h.visible?.offer.kind, kind)
            XCTAssertTrue(h.preferences.seen.contains(kind)); XCTAssertTrue(h.cockpitBudgetUsed)
        }
    }
    func testStorageOnlyContainsNineFlagsAndBoundedCounters() throws {
        let p = FirstUseHintPreferences(seen: Set(FirstUseHintKind.allCases), opens: Int.max, reveals: Int.max)
        let data = try JSONEncoder().encode(p), dictionary = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(dictionary.keys), ["seen","opens","reveals"])
        XCTAssertEqual(dictionary["opens"] as? Int, 2)
        XCTAssertEqual(try JSONDecoder().decode(FirstUseHintPreferences.self, from: data), p)
        XCTAssertThrowsError(try JSONDecoder().decode(FirstUseHintPreferences.self, from: Data("{\"seen\":[\"account-secret\"]}".utf8)))
    }
}
