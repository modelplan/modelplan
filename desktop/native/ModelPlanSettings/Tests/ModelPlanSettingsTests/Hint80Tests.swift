// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanSettings

final class Hint80Tests: XCTestCase {
    private func cockpit(seen: Set<FirstUseHintKind> = []) throws -> FirstUseHints {
        var value = FirstUseHints(preferences: .init(seen: seen))
        var context = HintContext(cockpitOpen: UUID()); context.captureReady = true
        try value.updateContext(context, at: 0); return value
    }
    func testNineKindPriorityDetachFirstOpenThenOptionOnNextOpen() throws {
        XCTAssertEqual(FirstUseHintKind.allCases, [.ignition,.detach,.optionHelp,.shutter,.field,.drag,.page,.pinned,.trial])
        var value = try cockpit()
        let detach = try XCTUnwrap(value.nextOffer(placeable: [.detach,.optionHelp], at: 0))
        XCTAssertEqual(detach.kind, .detach); try value.confirmShown(detach, at: 0); value.dismiss()
        XCTAssertNil(try value.nextOffer(placeable: [.optionHelp], at: 1))
        var context = value.context; context.cockpitOpen = UUID(); try value.updateContext(context, at: 2)
        XCTAssertEqual(try value.nextOffer(placeable: [.detach,.optionHelp], at: 2)?.kind, .optionHelp)
    }
    func testReservationSurvivesUnplaceableIgnitionAndPinAcrossUnseenReveals() throws {
        var value = FirstUseHints(), context = HintContext(dockReveal: UUID()); context.cardPinned = true
        for i in 0..<3 {
            if i > 0 { context.dockReveal = UUID() }
            try value.updateContext(context, at: Double(i))
            XCTAssertEqual(value.reservedDockHint, .ignition)
            XCTAssertNil(try value.nextOffer(placeable: [.pinned,.drag], at: Double(i)))
            try value.beginDockRevealDwell(at: Double(i))
            XCTAssertNil(try value.nextOffer(placeable: [.pinned,.drag], at: Double(i)+0.5))
            XCTAssertFalse(value.dockBudgetUsed); XCTAssertTrue(value.preferences.seen.isEmpty)
        }
        XCTAssertEqual(value.preferences.reveals, 2)
    }
    func testUnseenIgnitionSpendsSecondRevealAndDragWaitsForThird() throws {
        var value = FirstUseHints(), context = HintContext(dockReveal: UUID())
        try value.updateContext(context, at: 0)
        context.dockReveal = UUID(); try value.updateContext(context, at: 1)
        try value.beginDockRevealDwell(at: 1)
        let offer = try XCTUnwrap(value.nextOffer(placeable: [.ignition,.drag], at: 1.5))
        XCTAssertEqual(offer.kind, .ignition); try value.confirmShown(offer, at: 1.5); value.dismiss()
        try value.beginDwell(.drag, at: 1.5)
        XCTAssertNil(try value.nextOffer(placeable: [.drag], at: 2))
        context.dockReveal = UUID(); try value.updateContext(context, at: 3); try value.beginDockRevealDwell(at: 3)
        XCTAssertEqual(try value.nextOffer(placeable: [.drag], at: 3.5)?.kind, .drag)
    }
    func testUnplaceableDragReservesSecondRevealAgainstPin() throws {
        var value = FirstUseHints(preferences: .init(seen: [.ignition])), context = HintContext(dockReveal: UUID())
        try value.updateContext(context, at: 0); context.dockReveal = UUID(); context.cardPinned = true
        try value.updateContext(context, at: 1); try value.beginDockRevealDwell(at: 1)
        XCTAssertNil(try value.nextOffer(placeable: [.pinned], at: 1.5))
        XCTAssertFalse(value.dockBudgetUsed); XCTAssertEqual(value.preferences.seen, [.ignition])
        XCTAssertEqual(try value.nextOffer(placeable: [.drag,.pinned], at: 1.5)?.kind, .drag)
    }
    func testCountersTrackRealIdentityTransitionsOnlyAndCapAfterRestart() throws {
        var value = FirstUseHints(), context = HintContext(cockpitOpen: UUID(), dockReveal: UUID())
        try value.updateContext(context, at: 0)
        for i in 1...6 { context.cardPinned.toggle(); try value.updateContext(context, at: Double(i)) }
        XCTAssertEqual(value.preferences.opens, 1); XCTAssertEqual(value.preferences.reveals, 1)
        let loaded = try JSONDecoder().decode(FirstUseHintPreferences.self, from: JSONEncoder().encode(value.preferences))
        value = FirstUseHints(preferences: loaded); try value.updateContext(context, at: 0)
        XCTAssertEqual(value.preferences.opens, 2); XCTAssertEqual(value.preferences.reveals, 2)
        for i in 1...6 { context.cockpitOpen = UUID(); context.dockReveal = UUID(); try value.updateContext(context, at: Double(i)) }
        XCTAssertEqual(value.preferences.opens, 2); XCTAssertEqual(value.preferences.reveals, 2)
    }
    func testMigrationDropsObsoletePinWithoutInventingRevealHistory() throws {
        let raw = Data(#"{"seen":["ignition","optionHelp"],"cockpitOpens":999,"hasPinned":true}"#.utf8)
        let prefs = try JSONDecoder().decode(FirstUseHintPreferences.self, from: raw)
        XCTAssertEqual(prefs.opens, 2); XCTAssertEqual(prefs.reveals, 0); XCTAssertEqual(prefs.seen, [.ignition,.optionHelp])
        let encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(prefs)) as? [String:Any])
        XCTAssertEqual(Set(encoded.keys), ["seen","opens","reveals"])
        XCTAssertEqual(encoded["reveals"] as? Int, 0)
        let newer = try JSONDecoder().decode(FirstUseHintPreferences.self, from: Data(#"{"opens":1,"reveals":999,"cockpitOpens":2,"hasPinned":"obsolete"}"#.utf8))
        XCTAssertEqual(newer.opens, 1); XCTAssertEqual(newer.reveals, 2)
        XCTAssertThrowsError(try JSONDecoder().decode(FirstUseHintPreferences.self, from: Data(#"{"opens":null,"cockpitOpens":2}"#.utf8)))
    }
    func testTrialNeedsStationary500msAndCannotBeRequestedByDrag() throws {
        var value = try cockpit()
        value.request(.trial); try value.beginDwell(.trial, at: 0)
        XCTAssertNil(try value.nextOffer(placeable: [.trial], at: 1))
        let rest = try XCTUnwrap(value.beginTrialRest(on: .init(id: "fader-a"), at: 1))
        XCTAssertNil(try value.offerTrialRest(rest, placeable: [.trial], at: 1.499))
        let offer = try XCTUnwrap(value.offerTrialRest(rest, placeable: [.trial], at: 1.5))
        XCTAssertEqual(offer.kind, .trial); XCTAssertEqual(offer.trialTarget, .init(id: "fader-a"))
        XCTAssertTrue(value.preferences.seen.isEmpty); XCTAssertFalse(value.cockpitBudgetUsed)
        try value.confirmShown(offer, at: 1.5)
        XCTAssertEqual(value.visible?.expiresAt, 6.5); XCTAssertEqual(value.preferences.seen, [.trial])
    }
    func testCapAndTravelRepeatEntryUsesOneRestAndOneCentralDeadline() throws {
        var value = try cockpit()
        let first = try XCTUnwrap(value.beginTrialRest(on: .init(id: "travel-a"), at: 0))
        let same = try XCTUnwrap(value.beginTrialRest(on: .init(id: "travel-a"), at: 0.2))
        XCTAssertEqual(first, same); XCTAssertEqual(value.nextDeadline, 0.5)
        let offer = try XCTUnwrap(value.offerTrialRest(same, placeable: [.trial], at: 0.5))
        try value.confirmShown(offer, at: 0.5); XCTAssertNil(value.trialRest)
        XCTAssertEqual(value.nextDeadline, 5.5)
    }
    func testEveryCancellationInvalidatesTokenAndUnshownOfferWithoutSpend() throws {
        for reason in TrialHintCancellation.allCases {
            var value = try cockpit()
            let rest = try XCTUnwrap(value.beginTrialRest(on: .init(id: "travel-a"), at: 0))
            let offer = try XCTUnwrap(value.offerTrialRest(rest, placeable: [.trial], at: 0.5))
            XCTAssertTrue(value.cancelTrialRest(rest, reason: reason)); XCTAssertNil(value.offered)
            XCTAssertNil(try value.offerTrialRest(rest, placeable: [.trial], at: 0.6))
            XCTAssertThrowsError(try value.confirmShown(offer, at: 0.6))
            XCTAssertTrue(value.preferences.seen.isEmpty); XCTAssertFalse(value.cockpitBudgetUsed)
        }
    }
    func testMovementRestartsDelayAndOldTargetCallbackCannotCancelReplacement() throws {
        var value = try cockpit()
        let first = try XCTUnwrap(value.beginTrialRest(on: .init(id: "travel-a"), at: 0))
        value.cancelTrialRest(first, reason: .pointerMovement)
        let second = try XCTUnwrap(value.beginTrialRest(on: .init(id: "travel-a"), at: 0.2))
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertFalse(value.cancelTrialRest(first, reason: .targetRemoval))
        XCTAssertNil(try value.offerTrialRest(first, placeable: [.trial], at: 0.5))
        XCTAssertNil(try value.offerTrialRest(second, placeable: [.trial], at: 0.699))
        XCTAssertEqual(try value.offerTrialRest(second, placeable: [.trial], at: 0.7)?.trialTarget?.id, "travel-a")
    }
    func testDifferentTargetAndContextReplacementInvalidateOldRest() throws {
        var value = try cockpit()
        let first = try XCTUnwrap(value.beginTrialRest(on: .init(id: "travel-a"), at: 0))
        let second = try XCTUnwrap(value.beginTrialRest(on: .init(id: "travel-b"), at: 0.1))
        XCTAssertNil(try value.offerTrialRest(first, placeable: [.trial], at: 0.5))
        var context = value.context; context.cockpitOpen = UUID(); try value.updateContext(context, at: 0.6)
        XCTAssertNil(try value.offerTrialRest(second, placeable: [.trial], at: 0.6)); XCTAssertNil(value.trialRest)
    }
    func testTrialMaturesThroughSamePriorityAndCannotCreateSecondOffer() throws {
        var value = try cockpit()
        let rest = try XCTUnwrap(value.beginTrialRest(on: .init(id: "travel-a"), at: 0))
        let offer = try XCTUnwrap(value.offerTrialRest(rest, placeable: [.detach,.trial], at: 0.5))
        XCTAssertEqual(offer.kind, .detach); XCTAssertNil(offer.trialTarget)
        XCTAssertNil(try value.offerTrialRest(rest, placeable: [.trial], at: 0.5))
        try value.confirmShown(offer, at: 0.5); value.dismiss()
        XCTAssertNil(try value.nextOffer(placeable: [.trial], at: 1))
    }
    func testUnplaceableTrialDefersWithoutSpendingOrChangingTarget() throws {
        var value = try cockpit()
        let rest = try XCTUnwrap(value.beginTrialRest(on: .init(id: "travel-a"), at: 0))
        XCTAssertNil(try value.offerTrialRest(rest, placeable: [], at: 0.5))
        XCTAssertFalse(value.cockpitBudgetUsed); XCTAssertTrue(value.preferences.seen.isEmpty)
        XCTAssertEqual(try value.offerTrialRest(rest, placeable: [.trial], at: 0.6)?.trialTarget?.id, "travel-a")
    }
    func testCaptureLossHelpMapAndResetRetirePendingTrialWithoutNewOpen() throws {
        var value = try cockpit()
        let rest = try XCTUnwrap(value.beginTrialRest(on: .init(id: "travel-a"), at: 0))
        var context = value.context; context.captureReady = false; try value.updateContext(context, at: 0.1)
        XCTAssertNil(value.trialRest); XCTAssertNil(try value.offerTrialRest(rest, placeable: [.trial], at: 0.5))
        context.captureReady = true; try value.updateContext(context, at: 0.6)
        let next = try XCTUnwrap(value.beginTrialRest(on: .init(id: "travel-a"), at: 0.6))
        context.helpMapVisible = true; try value.updateContext(context, at: 0.7)
        XCTAssertNil(try value.offerTrialRest(next, placeable: [.trial], at: 1.1))
        value.reset(); XCTAssertEqual(value.preferences, .init()); XCTAssertEqual(value.context, context)
        XCTAssertFalse(value.cockpitBudgetUsed); XCTAssertFalse(value.dockBudgetUsed); XCTAssertNil(value.nextDeadline)
    }
    func testCancellationAfterConfirmedHintKeepsItsLifetimeAndSeenBudget() throws {
        var value = try cockpit()
        let rest = try XCTUnwrap(value.beginTrialRest(on: .init(id: "travel-a"), at: 0))
        let offer = try XCTUnwrap(value.offerTrialRest(rest, placeable: [.trial], at: 0.5)); try value.confirmShown(offer, at: 0.5)
        XCTAssertFalse(value.cancelTrialRest(rest, reason: .pointerLeave)); XCTAssertNotNil(value.visible)
        XCTAssertTrue(value.cockpitBudgetUsed); XCTAssertEqual(value.preferences.seen, [.trial])
        try value.advance(at: 5.5); XCTAssertNil(value.visible)
    }
    func testInvalidTargetsAndClocksCannotCreateTrialOrSpendFlags() throws {
        var value = try cockpit()
        XCTAssertThrowsError(try value.beginTrialRest(on: .init(id: ""), at: 0))
        XCTAssertThrowsError(try value.beginTrialRest(on: .init(id: String(repeating: "x", count: 257)), at: 0))
        XCTAssertThrowsError(try value.beginTrialRest(on: .init(id: "travel"), at: .nan))
        XCTAssertTrue(value.preferences.seen.isEmpty); XCTAssertFalse(value.cockpitBudgetUsed)
    }
}
