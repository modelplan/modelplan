// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanShell

@MainActor final class PulsePrimitiveBehaviorTests: XCTestCase {
    func testFollowerRetriesRefusalThenDeduplicatesAndReprobes() {
        let follower = ActiveDisplayFollower(currentDisplayIdentifier: { "display-A" })
        var calls = 0
        follower.onEnter = { _ in calls += 1; return calls != 1 }
        follower.start(); defer { follower.stop() }
        follower.sample(); follower.sample(); follower.sample()
        XCTAssertEqual(calls, 2, "refusal must not remember an unhandled display")
        follower.forgetLastDisplay(); follower.sample()
        XCTAssertEqual(calls, 3, "screen changes must report the same id again")
    }
    func testFollowerStopPreventsSamplingAndRestartForgetsOldDisplay() {
        var reads = 0, calls = 0
        let follower = ActiveDisplayFollower(currentDisplayIdentifier: { reads += 1; return "display-A" })
        follower.onEnter = { _ in calls += 1; return true }
        follower.start(); follower.sample(); follower.stop(); follower.sample()
        XCTAssertEqual(reads, 1); XCTAssertEqual(calls, 1); XCTAssertFalse(follower.isRunning)
        follower.start(); defer { follower.stop() }; follower.sample()
        XCTAssertEqual(calls, 2)
    }
    func testCallbackCannotLatchAnIdentifierAfterStoppingItsFollower() {
        let follower = ActiveDisplayFollower(currentDisplayIdentifier: { "display-A" })
        var calls = 0
        follower.onEnter = { _ in calls += 1; follower.stop(); return true }
        follower.start(); follower.sample()
        XCTAssertFalse(follower.isRunning)
        follower.start(); follower.sample(); follower.stop()
        XCTAssertEqual(calls, 2, "the stopped callback cannot suppress the restart sample")
    }
}
