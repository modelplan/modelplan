// SPDX-License-Identifier: MIT
import Foundation
import XCTest

final class HostDeadlineFenceTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000)
    private func ticket(_ directive: HostDeadlineFence.Directive) throws -> HostDeadlineFence.Ticket {
        guard case .clear(let value) = directive else { throw Failure.expectedClear }; return value
    }
    private enum Failure: Error { case expectedClear }

    func testExpiryRequiresClearBeforeRecomputeAndRejectsDuplicateTimer() throws {
        var fence = HostDeadlineFence()
        let initial = try ticket(fence.invalidateAndRecompute())
        XCTAssertEqual(fence.didClear(initial), .recompute(initial))
        let deadline = t0.addingTimeInterval(10)
        XCTAssertEqual(fence.didRecompute(initial, plan: .init(next: deadline, hasUnknownDeadline: false), now: t0), .schedule(initial, deadline, hasUnknownDeadline: false))
        XCTAssertEqual(fence.timerFired(initial, now: t0.addingTimeInterval(9)), .schedule(initial, deadline, hasUnknownDeadline: false))
        let expiry = try ticket(fence.timerFired(initial, now: deadline))
        XCTAssertEqual(fence.timerFired(initial, now: deadline), .none)
        XCTAssertEqual(fence.didClear(expiry), .recompute(expiry))
        XCTAssertEqual(fence.didClear(expiry), .none)
    }
    func testReplacementAndRevocationInvalidateOldCallbacks() throws {
        var fence = HostDeadlineFence()
        let old = try ticket(fence.invalidateAndRecompute())
        XCTAssertEqual(fence.didClear(old), .recompute(old))
        _ = fence.didRecompute(old, plan: .init(next: t0.addingTimeInterval(10), hasUnknownDeadline: false), now: t0)
        let replaced = try ticket(fence.invalidateAndRecompute())
        XCTAssertEqual(fence.timerFired(old, now: t0.addingTimeInterval(10)), .none)
        let withdrawn = try ticket(fence.withdraw())
        XCTAssertEqual(fence.didClear(replaced), .none)
        XCTAssertEqual(fence.didClear(withdrawn), .none)
        XCTAssertEqual(fence.didRecompute(replaced, plan: .init(next: nil, hasUnknownDeadline: true), now: t0), .none)
    }
    func testUnknownAndOverdueRequireDecisionWithoutTimerOrSpin() throws {
        var fence = HostDeadlineFence()
        let unknown = try ticket(fence.invalidateAndRecompute()); _ = fence.didClear(unknown)
        XCTAssertEqual(fence.didRecompute(unknown, plan: .init(next: nil, hasUnknownDeadline: true), now: t0), .authorityRequired(unknown))
        XCTAssertEqual(fence.timerFired(unknown, now: t0), .none)
        let overdue = try ticket(fence.invalidateAndRecompute()); _ = fence.didClear(overdue)
        XCTAssertEqual(fence.didRecompute(overdue, plan: .init(next: t0, hasUnknownDeadline: false), now: t0), .overdue(overdue))
        XCTAssertEqual(fence.timerFired(overdue, now: t0), .none)
    }
    func testPauseResumeCloseAndClockCorrectionFenceCallbacks() throws {
        var fence = HostDeadlineFence()
        let first = try ticket(fence.invalidateAndRecompute()); _ = fence.didClear(first)
        _ = fence.didRecompute(first, plan: .init(next: t0.addingTimeInterval(10), hasUnknownDeadline: false), now: t0)
        let pause = try ticket(fence.withdraw()); _ = fence.didClear(pause)
        XCTAssertEqual(fence.timerFired(first, now: t0.addingTimeInterval(20)), .none)
        XCTAssertEqual(fence.invalidateAndRecompute(), .none, "An event cannot silently resume a paused host")
        let resume = try ticket(fence.resume()); _ = fence.didClear(resume)
        let correction = try ticket(fence.invalidateAndRecompute())
        XCTAssertEqual(fence.didRecompute(resume, plan: .init(next: nil, hasUnknownDeadline: true), now: t0), .none)
        let close = try ticket(fence.close())
        XCTAssertEqual(fence.didClear(correction), .none); XCTAssertEqual(fence.didClear(close), .none)
        XCTAssertEqual(fence.invalidateAndRecompute(), .none)
    }
    func testKnownAndUnknownDeadlinesRemainIndependent() throws {
        var fence = HostDeadlineFence()
        let mixed = try ticket(fence.invalidateAndRecompute()); _ = fence.didClear(mixed)
        let future = t0.addingTimeInterval(30)
        XCTAssertEqual(fence.didRecompute(mixed, plan: .init(next: future, hasUnknownDeadline: true), now: t0),
                       .schedule(mixed, future, hasUnknownDeadline: true))
        XCTAssertEqual(fence.timerFired(mixed, now: t0.addingTimeInterval(5)),
                       .schedule(mixed, future, hasUnknownDeadline: true))
        let none = try ticket(fence.invalidateAndRecompute()); _ = fence.didClear(none)
        XCTAssertEqual(fence.didRecompute(none, plan: .init(next: nil, hasUnknownDeadline: false), now: t0), .noFutureDeadline(none))
        let invalid = try ticket(fence.invalidateAndRecompute()); _ = fence.didClear(invalid)
        let bad = Date(timeIntervalSinceReferenceDate: .infinity)
        XCTAssertEqual(fence.didRecompute(invalid, plan: .init(next: bad, hasUnknownDeadline: false), now: t0), .authorityRequired(invalid))
    }

}
