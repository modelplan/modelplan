// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanCockpitWeb

/// Walkthrough 11-17 (build b2b50b34): after a put back the app's flip to accessory deactivated it and the page's first
/// Close press was dropped. The decision to activate again, on an injected clock (macrevd-1033-1: only for that flip).
final class CockpitPutBackActivationTests: XCTestCase {
  func testTheFlipsImmediateDeactivationIsAnsweredOnce() {
    var state = CockpitPutBackActivation()
    state.arm(wasActive: true, leftRegular: true, commandHeld: false, now: 1_000)
    XCTAssertTrue(state.reactivates(isActive: false, presentable: true, now: 1_000), "deactivated at once by the flip")
    XCTAssertNil(state.armedUntil, "answered: retired")
    XCTAssertFalse(state.reactivates(isActive: false, presentable: true, now: 1_200), "a genuine switch inside the window is not fought")
  }

  func testTheFlipsLaterResignIsAnsweredOnce() {
    var state = CockpitPutBackActivation()
    state.arm(wasActive: true, leftRegular: true, commandHeld: false, now: 1_000)
    XCTAssertFalse(state.reactivates(isActive: true, presentable: true, now: 1_000), "still active at the latch: nothing to do yet")
    XCTAssertTrue(state.reactivates(isActive: false, presentable: true, now: 1_200), "the flip's resign a moment later")
    XCTAssertFalse(state.reactivates(isActive: false, presentable: true, now: 1_300), "a second resign is the user's")
  }

  func testAPutBackWithoutAPolicyFlipArmsNothing() {
    var state = CockpitPutBackActivation()
    state.arm(wasActive: true, leftRegular: false, commandHeld: false, now: 1_000) // Settings open: the app stays regular
    XCTAssertNil(state.armedUntil)
    XCTAssertFalse(state.reactivates(isActive: false, presentable: true, now: 1_100), "a switch within 500 ms is the user's")
  }

  func testAnAppThatWasNotActiveIsLeftInactive() {
    var state = CockpitPutBackActivation()
    state.arm(wasActive: false, leftRegular: true, commandHeld: false, now: 1_000)
    XCTAssertFalse(state.reactivates(isActive: false, presentable: true, now: 1_000))
    XCTAssertNil(state.armedUntil)
  }

  func testAUserSwitchStartedBeforeTheResignRetiresIt() {
    var state = CockpitPutBackActivation()
    state.arm(wasActive: true, leftRegular: true, commandHeld: false, now: 1_000)
    state.userSwitchesAway() // a press in another app, or the Command key of Cmd-Tab
    XCTAssertFalse(state.reactivates(isActive: false, presentable: true, now: 1_100))
  }

  /// macrev2-1033-1: switch intent seen during the put back is not overwritten by the latch's arm.
  func testASwitchStartedDuringThePutBackKeepsTheLatchFromArming() {
    var state = CockpitPutBackActivation()
    state.beginPutBack()
    state.userSwitchesAway() // Command pressed (and released) during the flight
    state.arm(wasActive: true, leftRegular: true, commandHeld: false, now: 1_000)
    XCTAssertNil(state.armedUntil)
    XCTAssertFalse(state.reactivates(isActive: false, presentable: true, now: 1_100), "the user's resign is not fought")
  }

  /// macrev2-1033-1: Command held across the latch (Tab then needs no new Command event).
  func testCommandHeldAtTheLatchArmsNothing() {
    var state = CockpitPutBackActivation()
    state.beginPutBack()
    state.arm(wasActive: true, leftRegular: true, commandHeld: true, now: 1_000)
    XCTAssertNil(state.armedUntil)
    XCTAssertFalse(state.reactivates(isActive: false, presentable: true, now: 1_100))
  }

  /// Intent from before a put back began does not count against it.
  func testANewPutBackClearsAnEarlierSwitch() {
    var state = CockpitPutBackActivation()
    state.userSwitchesAway()
    state.beginPutBack()
    state.arm(wasActive: true, leftRegular: true, commandHeld: false, now: 1_000)
    XCTAssertTrue(state.reactivates(isActive: false, presentable: true, now: 1_100))
  }

  func testTheWindowExpires() {
    var state = CockpitPutBackActivation()
    state.arm(wasActive: true, leftRegular: true, commandHeld: false, now: 1_000)
    XCTAssertFalse(state.reactivates(isActive: false, presentable: true, now: 1_000 + CockpitPutBackActivation.windowMilliseconds + 1))
    XCTAssertNil(state.armedUntil, "expired: retired")
  }

  func testAClosingOrDetachedCockpitIsNotActivatedFor() {
    var state = CockpitPutBackActivation()
    state.arm(wasActive: true, leftRegular: true, commandHeld: false, now: 1_000)
    XCTAssertFalse(state.reactivates(isActive: false, presentable: false, now: 1_010))
    XCTAssertFalse(state.reactivates(isActive: false, presentable: true, now: 1_020), "retired by the close")
  }
}
