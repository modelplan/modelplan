// SPDX-License-Identifier: MIT
import XCTest
import ModelPlanSettings
@testable import ModelPlanAppIntegration

/// T3 (post-merge sampling 11-17): a drop's Settings save is asynchronous, so drops A -> B -> C can all be made
/// before any of their saves lands. The host held only the placement shown just before the latest drop (B), so the
/// delayed snapshot of A's save ended the hold and put the widget back on A. Every placement a pending save can
/// still report is now held until the latest drop's own save arrives.
final class HeldDockDropTests: XCTestCase {
    private typealias Fields = HeldDockDrop.Fields
    private let start = Fields(displayID: "primary", edge: .right, alongFraction: 0.5)
    private let a = Fields(displayID: "primary", edge: .bottom, alongFraction: 0.5)
    private let b = Fields(displayID: "primary", edge: .left, alongFraction: 0.3)
    private let c = Fields(displayID: "primary", edge: .top, alongFraction: 0.7)

    /// Drops A -> B -> C from `start`, as the host's drop commit does; returns the hold and the shown placement.
    private func dropChain(_ drops: [Fields], now: ContinuousClock.Instant) -> (HeldDockDrop?, Fields) {
        var hold: HeldDockDrop?, shown = start
        for drop in drops {
            hold = HeldDockDrop.after(drop: drop, showing: shown, previous: hold, now: now)
            shown = drop
        }
        return (hold, shown)
    }

    /// Fails before: the delayed snapshot of A (or of the pre-drop placement) after C snapped the widget back.
    func testDelayedSnapshotsOfEarlierDropsDoNotMoveTheWidgetBack() throws {
        let now = ContinuousClock.now
        var (hold, shown) = dropChain([a, b, c], now: now)
        XCTAssertEqual(shown, c)
        // Snapshots arrive in any order the saves and other writers produce: A, the pre-drop placement, B.
        for late in [a, start, b, a] {
            let admitted = try XCTUnwrap(hold, "the hold lasts until C is acknowledged").admit(late, now: now)
            XCTAssertEqual(admitted.show, c, "a snapshot carrying \(late.edge) predates C's save; C stands")
            hold = admitted.hold; shown = admitted.show
        }
        // C's own save is reported: the hold ends and C stays.
        let acknowledged = try XCTUnwrap(hold).admit(c, now: now)
        XCTAssertEqual(acknowledged.show, c)
        XCTAssertNil(acknowledged.hold, "the latest drop's save ends the hold")
        XCTAssertEqual(shown, c)
    }

    /// An earlier drop's save is not the latest drop's acknowledgement: the hold stays for C.
    func testAnIntermediateDropsSaveKeepsTheHold() throws {
        let now = ContinuousClock.now
        let (hold, _) = dropChain([a, b, c], now: now)
        let afterB = try XCTUnwrap(hold).admit(b, now: now)
        XCTAssertEqual(afterB.show, c)
        XCTAssertNotNil(afterB.hold)
        XCTAssertEqual(try XCTUnwrap(afterB.hold).admit(a, now: now).show, c, "A still predates C after B's save")
    }

    /// A placement that was never dropped (a choice made in Settings) ends the hold and is shown.
    func testAnotherPlacementEndsTheHold() throws {
        let now = ContinuousClock.now
        let (hold, _) = dropChain([a, b], now: now)
        let chosen = Fields(displayID: "other", edge: .left, alongFraction: 0.9)
        let admitted = try XCTUnwrap(hold).admit(chosen, now: now)
        XCTAssertEqual(admitted.show, chosen)
        XCTAssertNil(admitted.hold)
    }

    /// Dropping back onto an earlier placement leaves only the placements that differ from it held.
    func testDroppingBackOntoAnEarlierPlacement() throws {
        let now = ContinuousClock.now
        let (hold, shown) = dropChain([a, start], now: now)
        XCTAssertEqual(shown, start)
        let late = try XCTUnwrap(hold, "A's save is still pending").admit(a, now: now)
        XCTAssertEqual(late.show, start, "A's late snapshot cannot move the widget off the placement dropped last")
        XCTAssertNil(try XCTUnwrap(late.hold).admit(start, now: now).hold, "the drop back is acknowledged")
        XCTAssertNil(HeldDockDrop.after(drop: start, showing: start, previous: nil, now: now), "a drop in place holds nothing")
    }

    /// The limit still bounds the hold, and an expired hold is not carried into the next drop.
    func testTheLimitEndsTheHold() throws {
        let now = ContinuousClock.now, later = now + HeldDockDrop.limit + .seconds(1)
        let (hold, _) = dropChain([a, b], now: now)
        let admitted = try XCTUnwrap(hold).admit(a, now: later)
        XCTAssertEqual(admitted.show, a)
        XCTAssertNil(admitted.hold)
        let fresh = try XCTUnwrap(HeldDockDrop.after(drop: c, showing: b, previous: hold, now: later))
        XCTAssertEqual(fresh.superseded, [b], "only the placement shown before the new drop is held")
    }
}
