// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanCockpitWeb

/// CKP-SHELL-33 logic (owner D158, D175, D178, D181, D186-D188): the attached place under the icon, the key-detach
/// landing rule on the accepted demo's three screens (menubar-rack-v8.html), the rack's telescoping and the open order.
/// Pure geometry; no window.
final class CockpitLaunchRackTests: XCTestCase {
  // The demo's cockpit art: 480 pt wide, tall 693 pt (shoulder 40 pt), short 489 pt (shoulder 16 pt), 10 pt under the bar.
  private func home(screen: CGSize, icon: CGFloat, height: CGFloat = 693, shoulder: CGFloat = 40) -> CGRect {
    let x = max(0, min(icon - shoulder, screen.width - 480))
    return CGRect(x: x, y: screen.height - 10 - height, width: 480, height: height)
  }
  private func assertOnScreen(_ frame: CGRect, _ visible: CGRect, _ label: String, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(visible.insetBy(dx: -0.01, dy: -0.01).contains(frame), "\(label): the whole cockpit stays on screen (\(frame))", file: file, line: line)
  }
  private func assertClearsTheZone(_ frame: CGRect, _ home: CGRect, _ label: String, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertGreaterThanOrEqual(hypot(frame.minX - home.minX, frame.maxY - home.maxY), CockpitLaunchRackTiming.catchZone + 16 - 0.01,
                                "\(label): out of the 40 pt catch zone with the 16 pt margin", file: file, line: line)
  }

  /// Demo screen "big desk" 1512 x 982, icon at 360: rule 1, straight down 56 pt.
  func testLandingOnTheBigDeskGoesStraightDown() {
    let screen = CGSize(width: 1512, height: 982), visible = CGRect(origin: .zero, size: screen)
    let start = home(screen: screen, icon: 360)
    let plan = CockpitDetachLanding.plan(home: start, compactHome: home(screen: screen, icon: 360, height: 489, shoulder: 16), visible: visible)
    XCTAssertEqual(plan.rule, .down); XCTAssertFalse(plan.compact)
    XCTAssertEqual(plan.frame, start.offsetBy(dx: 0, dy: -56))
    assertOnScreen(plan.frame, visible, "big desk"); assertClearsTheZone(plan.frame, start, "big desk")
  }

  /// Demo screen "small laptop" 1280 x 720, icon at 360: the tall cockpit cannot go down, so 56 pt toward the centre (right).
  func testLandingOnTheSmallLaptopMovesTowardTheCentre() {
    let screen = CGSize(width: 1280, height: 720), visible = CGRect(origin: .zero, size: screen)
    let start = home(screen: screen, icon: 360)
    let plan = CockpitDetachLanding.plan(home: start, compactHome: home(screen: screen, icon: 360, height: 489, shoulder: 16), visible: visible)
    XCTAssertEqual(plan.rule, .towardCentre); XCTAssertFalse(plan.compact)
    XCTAssertEqual(plan.frame, start.offsetBy(dx: 56, dy: 0), "right, toward the screen centre")
    assertOnScreen(plan.frame, visible, "small laptop"); assertClearsTheZone(plan.frame, start, "small laptop")
  }

  /// Demo screen "icon near the right edge" 1280 x 720, icon at 840: 56 pt toward the centre, which is left.
  func testLandingWithTheIconNearTheRightEdgeMovesLeft() {
    let screen = CGSize(width: 1280, height: 720), visible = CGRect(origin: .zero, size: screen)
    let start = home(screen: screen, icon: 840)
    XCTAssertEqual(start.maxX, 1280, "the cockpit already touches the right edge")
    let plan = CockpitDetachLanding.plan(home: start, compactHome: home(screen: screen, icon: 840, height: 489, shoulder: 16), visible: visible)
    XCTAssertEqual(plan.rule, .towardCentre)
    XCTAssertEqual(plan.frame, start.offsetBy(dx: -56, dy: 0), "left, toward the screen centre")
    assertOnScreen(plan.frame, visible, "right edge"); assertClearsTheZone(plan.frame, start, "right edge")
  }

  /// D187: no diagonal. When neither step fits the full cockpit, the short version tries them again.
  func testLandingSwitchesToTheShortVersionWhenTheFullOneHasNoRoom() {
    let screen = CGSize(width: 500, height: 720), visible = CGRect(origin: .zero, size: screen)
    let start = home(screen: screen, icon: 260), short = home(screen: screen, icon: 260, height: 489, shoulder: 16)
    let plan = CockpitDetachLanding.plan(home: start, compactHome: short, visible: visible)
    XCTAssertEqual(plan.rule, .compactDown); XCTAssertTrue(plan.compact)
    XCTAssertEqual(plan.frame, short.offsetBy(dx: 0, dy: -56))
    assertOnScreen(plan.frame, visible, "narrow screen")
  }

  /// Nothing fits: the least sideways step that clears the catch zone, still never partly off-screen.
  func testLandingNeverEndsPartlyOffScreen() {
    let visible = CGRect(x: 0, y: 0, width: 500, height: 520)
    let short = CGRect(x: 10, y: 21, width: 480, height: 489)
    let plan = CockpitDetachLanding.plan(home: short, compactHome: nil, visible: visible)
    XCTAssertEqual(plan.rule, .minimum)
    assertOnScreen(plan.frame, visible, "tiny screen")
    XCTAssertEqual(plan.frame.maxY, short.maxY, "it stays at the same height")
    for (w, h, icon) in [(1512, 982, 360), (1280, 720, 360), (1280, 720, 840), (640, 700, 600), (500, 560, 10)] as [(CGFloat, CGFloat, CGFloat)] {
      let screen = CGSize(width: w, height: h), visible = CGRect(origin: .zero, size: screen)
      let tall = home(screen: screen, icon: icon), shortHome = home(screen: screen, icon: icon, height: 489, shoulder: 16)
      let start = visible.contains(tall) ? tall : shortHome
      let result = CockpitDetachLanding.plan(home: start, compactHome: start == tall ? shortHome : nil, visible: visible)
      assertOnScreen(result.frame, visible, "\(Int(w))x\(Int(h)) icon \(Int(icon))")
    }
  }

  /// D158/D178: attached, the window top is 10 pt under the menu bar and the icon sits above the left canopy shoulder.
  func testTheAttachedCockpitHangsTenPointsUnderTheBarWithTheIconOverItsLeftShoulder() throws {
    let usable = CGRect(x: 0, y: 0, width: 1728, height: 1080)
    let icon = CGRect(x: 900, y: 1080, width: 28, height: 37)
    let full = try XCTUnwrap(CockpitShellLayout.fit(usable: usable, anchor: icon, shutterClosed: false, screenWidth: 1728))
    XCTAssertEqual(full.profile, .full)
    XCTAssertEqual(full.frame.maxY, 1080 - CockpitShellLayout.menuBarGap)
    XCTAssertEqual(CockpitShellLayout.menuBarGap, 10)
    XCTAssertEqual(full.shoulder.x, icon.midX, accuracy: 0.5, "the icon is above the left shoulder")
    XCTAssertLessThan(full.shoulder.x, full.frame.minX + full.frame.width / 4, "the LEFT shoulder")
    let short = try XCTUnwrap(CockpitShellLayout.fit(usable: usable, anchor: icon, shutterClosed: false, screenWidth: 1728, forceCompact: true))
    XCTAssertEqual(short.profile, .compact, "a key-detach landing can force the short version")
    XCTAssertEqual(short.shoulder.x, icon.midX, accuracy: 0.5)
    XCTAssertEqual(short.frame.maxY, full.frame.maxY)
    // Near the right edge the cockpit shifts just enough to stay on the screen.
    let edge = try XCTUnwrap(CockpitShellLayout.fit(usable: usable, anchor: CGRect(x: 1700, y: 1080, width: 28, height: 37), shutterClosed: false, screenWidth: 1728))
    XCTAssertEqual(edge.frame.maxX, 1728)
  }

  /// The rack telescopes from the icon: nothing below the bar when in, the top section (the part visible in the gap and at
  /// the shoulder) fully out at one third, all three sections out at one.
  func testTheRackTelescopesTopSectionFirst() {
    for mast in [CockpitRackMast.night, .day] {
      let folded = mast.geometry(at: 0)
      XCTAssertTrue(folded.sections.allSatisfy { $0.bottom - $0.top <= 0.001 }, "retracted into the icon")
      let third = mast.geometry(at: 1.0 / 3)
      XCTAssertEqual(third.sections[0].top, 0, accuracy: 0.001)
      XCTAssertEqual(third.sections[0].bottom, (mast.collar1 - mast.cap) * 0.1, accuracy: 0.001, "the top section is out")
      XCTAssertEqual(third.sections[1].bottom - third.sections[1].top, 0, accuracy: 0.001, "the hidden sections are still in")
      XCTAssertEqual(third.sections[2].bottom - third.sections[2].top, 0, accuracy: 0.001)
      let out = mast.geometry(at: 1)
      XCTAssertEqual(out.sections[2].bottom, (mast.foot - mast.cap) * 0.1, accuracy: 0.001, "fully out")
      XCTAssertLessThanOrEqual(out.sections[2].bottom, CockpitRackMast.length)
      XCTAssertTrue(out.beacons.allSatisfy { $0.out })
    }
  }

  /// D186/D188: the visible rack first (0.25 s), then the cockpit (0.25 s); only an attached open from a real icon, with motion.
  func testTheIconOpenExtendsTheRackFirstOnlyWhenItCan() {
    XCTAssertEqual(CockpitLaunchRackTiming.rackOpen, 0.25); XCTAssertEqual(CockpitLaunchRackTiming.cockpitOpen, 0.25)
    XCTAssertEqual(CockpitLaunchRackTiming.keyDetachBurn, 0.6); XCTAssertEqual(CockpitLaunchRackTiming.catchZone, 40)
    XCTAssertEqual(CockpitLaunchRackTiming.landingStep, 56)
    let icon = CGRect(x: 900, y: 1080, width: 28, height: 37)
    XCTAssertTrue(CockpitWindowController.opensRackFirst(.fromIcon, reduceMotion: false, detached: false, icon: icon))
    XCTAssertFalse(CockpitWindowController.opensRackFirst(.fade, reduceMotion: false, detached: false, icon: icon), "the ignition keeps its fade")
    XCTAssertFalse(CockpitWindowController.opensRackFirst(.fromIcon, reduceMotion: true, detached: false, icon: icon))
    XCTAssertFalse(CockpitWindowController.opensRackFirst(.fromIcon, reduceMotion: false, detached: true, icon: icon))
    XCTAssertFalse(CockpitWindowController.opensRackFirst(.fromIcon, reduceMotion: false, detached: false, icon: nil))
    XCTAssertEqual(CockpitLaunchRackTiming.flight(length: 0), 0.82); XCTAssertEqual(CockpitLaunchRackTiming.flight(length: 5000), 1.3)
  }
}
