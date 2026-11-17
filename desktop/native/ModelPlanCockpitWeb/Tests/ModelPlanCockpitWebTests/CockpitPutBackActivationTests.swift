// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanCockpitWeb

/// Walkthrough 11-17 (build b2b50b34): after a put back the app's flip to accessory deactivated it and the page's first
/// Close press was dropped. The decision to activate again, on an injected clock.
final class CockpitPutBackActivationTests: XCTestCase {
  func testAnActiveAppThatTheFlipDeactivatedIsActivatedAgain() {
    var state = CockpitPutBackActivation()
    state.arm(wasActive: true, now: 1_000)
    XCTAssertFalse(state.reactivates(isActive: true, presentable: true, now: 1_000, consume: false), "still active: nothing to do")
    XCTAssertTrue(state.reactivates(isActive: false, presentable: true, now: 1_000, consume: false), "deactivated at once by the flip")
    XCTAssertTrue(state.reactivates(isActive: false, presentable: true, now: 1_200, consume: true), "or by the flip's later resign")
    XCTAssertFalse(state.reactivates(isActive: false, presentable: true, now: 1_250, consume: true), "one resign is answered once")
  }

  func testAnAppThatWasNotActiveIsLeftInactive() {
    var state = CockpitPutBackActivation()
    state.arm(wasActive: false, now: 1_000)
    XCTAssertFalse(state.reactivates(isActive: false, presentable: true, now: 1_000, consume: false))
    XCTAssertNil(state.armedUntil)
  }

  func testALaterSwitchToAnotherAppIsNotFought() {
    var state = CockpitPutBackActivation()
    state.arm(wasActive: true, now: 1_000)
    XCTAssertFalse(state.reactivates(isActive: false, presentable: true, now: 1_000 + CockpitPutBackActivation.windowMilliseconds + 1, consume: true))
    XCTAssertNil(state.armedUntil, "expired: disarmed")
  }

  func testAClosingOrDetachedCockpitIsNotActivatedFor() {
    var state = CockpitPutBackActivation()
    state.arm(wasActive: true, now: 1_000)
    XCTAssertFalse(state.reactivates(isActive: false, presentable: false, now: 1_010, consume: false))
    XCTAssertFalse(state.reactivates(isActive: false, presentable: true, now: 1_020, consume: false), "disarmed by the close")
    state.arm(wasActive: true, now: 2_000); state.cancel()
    XCTAssertFalse(state.reactivates(isActive: false, presentable: true, now: 2_010, consume: false), "discard cancels it")
  }
}
