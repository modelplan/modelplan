// SPDX-License-Identifier: MIT
// The Mac side of the pure entrance checks (the same suite runs on Linux through ModelPlanEntranceChecks).
import XCTest
import ModelPlanEntranceChecksKit

final class EntranceLogicTests: XCTestCase {
    func testEntranceTimelineTailLayoutAndCameraRailMatchTheReference() {
        let run = EntranceChecks.run()
        XCTAssertEqual(run.failures, [], run.failures.joined(separator: "\n"))
        XCTAssertGreaterThanOrEqual(run.passed.count, 8)
    }
}
