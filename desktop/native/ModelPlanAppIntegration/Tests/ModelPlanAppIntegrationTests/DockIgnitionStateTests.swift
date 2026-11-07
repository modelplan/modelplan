// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanAppIntegration

/// D-6 ignition states; the values are the prototype's ignition.css.
final class DockIgnitionStateTests: XCTestCase {
    func testStatesFollowThePointerAndNeverMoveADisabledCap() {
        XCTAssertEqual(DockIgnitionState.resolve(enabled: true, hovering: false, focused: false, pressing: false), .rest)
        XCTAssertEqual(DockIgnitionState.resolve(enabled: true, hovering: true, focused: false, pressing: false), .raised)
        XCTAssertEqual(DockIgnitionState.resolve(enabled: true, hovering: false, focused: true, pressing: false), .raised)
        XCTAssertEqual(DockIgnitionState.resolve(enabled: true, hovering: true, focused: false, pressing: true), .pressed)
        XCTAssertEqual(DockIgnitionState.resolve(enabled: false, hovering: true, focused: true, pressing: true), .rest)
    }
    func testLiftContactAndTiming() {
        XCTAssertEqual(DockIgnitionState.raised.capLift, 1); XCTAssertEqual(DockIgnitionState.pressed.capLift, -1)
        XCTAssertEqual(DockIgnitionState.rest.capLift, 0); XCTAssertEqual(DockIgnitionState.transition, 0.12)
        // 1 - (1 - .33)(1 - x) = .55 gives x of about .33.
        XCTAssertEqual(1 - (1 - 0.33) * (1 - Double(DockIgnitionState.pressed.extraContact)), 0.55, accuracy: 0.01)
    }
}
