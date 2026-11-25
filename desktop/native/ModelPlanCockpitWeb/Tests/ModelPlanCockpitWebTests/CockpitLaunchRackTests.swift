// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanCockpitWeb

/// CKP-SHELL-33 logic (owner D158, D175, D178, D181, D186-D188): the attached place under the icon, the key-detach
/// landing rule on the accepted demo's three screens (menubar-rack-v8.html), the one-piece docking boom and the open order.
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
    // glm-872-2/3: on a visible frame too narrow to clear the catch zone, staying on screen wins (D187); the frame is
    // clamped to the visible edge, so it may sit inside the zone. Nothing auto-latches: the zone arms only after leaving it.
    XCTAssertEqual(plan.frame.minX, visible.minX, "clamped to the visible edge (10 pt from home), not pushed off screen")
    for (w, h, icon) in [(1512, 982, 360), (1280, 720, 360), (1280, 720, 840), (640, 700, 600), (500, 560, 10)] as [(CGFloat, CGFloat, CGFloat)] {
      let screen = CGSize(width: w, height: h), visible = CGRect(origin: .zero, size: screen)
      let tall = home(screen: screen, icon: icon), shortHome = home(screen: screen, icon: icon, height: 489, shoulder: 16)
      let start = visible.contains(tall) ? tall : shortHome
      let result = CockpitDetachLanding.plan(home: start, compactHome: start == tall ? shortHome : nil, visible: visible)
      assertOnScreen(result.frame, visible, "\(Int(w))x\(Int(h)) icon \(Int(icon))")
    }
  }

  /// Owner 11-18: the rack's mask line follows the shutter. Closed, the window's top edge is the slab's top edge, so the
  /// line is 0 pt below it; open, it is the hull's shoulder depth. A toggle while attached moves only the line (the
  /// window top stays), so the mask's top edge is the same y apart from that depth.
  func testTheRackMaskLineFollowsTheShutterState() throws {
    let usable = CGRect(x: 0, y: 0, width: 1728, height: 1080)
    let icon = CGRect(x: 900, y: 1080, width: 28, height: 37)
    for forceCompact in [false, true] {
      let open = try XCTUnwrap(CockpitShellLayout.fit(usable: usable, anchor: icon, shutterClosed: false, screenWidth: 1728, forceCompact: forceCompact))
      let closed = try XCTUnwrap(CockpitShellLayout.fit(usable: usable, anchor: icon, shutterClosed: true, screenWidth: 1728, forceCompact: forceCompact))
      XCTAssertEqual(open.rackMaskDrop, CockpitShellLayout.shoulderDrop(open.profile, closed: false) * open.scale)
      XCTAssertGreaterThan(open.rackMaskDrop, 0, "open: the rack meets the canopy shoulder")
      XCTAssertEqual(closed.rackMaskDrop, 0, "closed: the rack ends at the slab's top edge, nothing hangs in empty space")
      XCTAssertEqual(closed.shoulder.y, closed.frame.maxY)
      XCTAssertEqual(open.shoulder.y, open.frame.maxY - open.rackMaskDrop)
      XCTAssertEqual(open.frame.maxY, closed.frame.maxY, "attached, the top edge stays when the shutter toggles")
      XCTAssertEqual(open.shoulder.x, closed.shoulder.x, "the icon stays over the same shoulder")
    }
    let forced = try XCTUnwrap(CockpitShellLayout.fit(usable: CGRect(x: 0, y: 0, width: 1728, height: 500), anchor: icon.offsetBy(dx: 0, dy: -580), shutterClosed: false, screenWidth: 1728))
    if forced.forcedClosed { XCTAssertEqual(forced.rackMaskDrop, 0, "a forced-closed cockpit is closed too") }
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

  /// D447 (owner, 11-25): the boom is as wide as the status item's WIDEST occupied width this session, bounded 24-96 pt.
  /// The item changes width with its text; the boom never shrinks below the widest width seen.
  func testBoomWidthIsTheWidestStatusWidthClamped() {
    var tracker = CockpitDockingBoom.WidthTracker()
    XCTAssertEqual(tracker.width, 40, "nominal width before any status item was measured")
    tracker.observe(30); XCTAssertEqual(tracker.width, 30)
    tracker.observe(58); XCTAssertEqual(tracker.width, 58, "a wider item widens the boom")
    tracker.observe(22); XCTAssertEqual(tracker.width, 58, "a narrower item never shrinks it")
    tracker.observe(.nan); tracker.observe(-5); tracker.observe(.infinity); XCTAssertEqual(tracker.width, 58, "invalid widths are ignored")
    tracker.observe(140); XCTAssertEqual(tracker.width, 96, "bounded at 96 pt")
    var narrow = CockpitDockingBoom.WidthTracker()
    narrow.observe(8); XCTAssertEqual(narrow.width, 24, "bounded at 24 pt")
    XCTAssertEqual(narrow.widest, 8)
  }

  @MainActor func testBoomPanelIsCentredUnderTheIconAtTheGivenWidth() {
    for (slot, expected) in [(CGFloat(8), CGFloat(24)), (28, 28), (40, 40), (72, 72), (140, 96)] {
      let icon = CGRect(x: 900, y: 1080, width: slot, height: 37)
      let frame = CockpitLaunchRack.frame(icon: icon)
      XCTAssertEqual(frame.width, expected)
      XCTAssertEqual(frame.midX, icon.midX, accuracy: 0.5, "the boom stays centred under the item")
      XCTAssertEqual(frame.maxY, icon.minY)
      XCTAssertEqual(frame.height, CockpitDockingBoom.length)
      let widest = CockpitLaunchRack.frame(icon: icon, width: 64)
      XCTAssertEqual(widest.width, 64, "the session's widest width wins over the current slot")
      XCTAssertEqual(widest.midX, icon.midX, accuracy: 0.5)
    }
    XCTAssertEqual(CockpitDockingBoom.width(for: 0), 40, "invalid slot size uses the nominal width")
    XCTAssertEqual(CockpitDockingBoom.width(for: .nan), 40)
  }

  /// D430: one piece. The slide only moves the boom; its size never changes (no telescoping), and it goes from fully
  /// tucked behind the menu bar to its rest place, monotonically. Decision C (11-25): at rest the clamp's grip sits on
  /// the lug's pin above the canopy line and the upper part (mount plate included) stays behind the menu bar.
  func testTheBoomSlidesAsOnePieceWithoutTelescoping() throws {
    let m = CockpitDockingBoom.metrics
    for width in [CGFloat(24), 40, 58, 96] {
      for line in [CGFloat(10), 35] {
        let h = width * m.aspect
        var lastTop = -CGFloat.infinity
        for step in 0...40 {
          let slide = CGFloat(step) / 40
          let pose = CockpitDockingBoom.pose(width: width, line: line, slide: slide, closure: 0, lugShown: false)
          XCTAssertEqual(pose.boom.width, width, accuracy: 1e-9, "never narrower or wider")
          XCTAssertEqual(pose.boom.height, h, accuracy: 1e-9, "never shorter: one rigid piece, no telescoping")
          XCTAssertEqual(pose.boom.minX, 0)
          XCTAssertGreaterThanOrEqual(pose.boom.minY, lastTop - 1e-9, "only moves down while it slides out")
          lastTop = pose.boom.minY
        }
        let tucked = CockpitDockingBoom.pose(width: width, line: line, slide: 0, closure: 0, lugShown: false)
        XCTAssertEqual(tucked.boom.maxY, 0, accuracy: 1e-9, "slide 0: entirely behind the menu bar")
        let rest = CockpitDockingBoom.pose(width: width, line: line, slide: 1, closure: 1, lugShown: true)
        let lug = try XCTUnwrap(rest.lug)
        XCTAssertEqual(lug.maxY, line, accuracy: 1e-9, "the lug's base sits on the canopy line")
        let grip = CGPoint(x: rest.boom.minX + width * m.gripX, y: rest.boom.minY + h * m.gripY)
        let pin = CGPoint(x: lug.minX + lug.width * m.lugPinTip, y: lug.minY + lug.height * m.lugPinY)
        XCTAssertEqual(grip.x, pin.x, accuracy: 1e-9, "the pin's tip is in the clamp")
        XCTAssertEqual(grip.y, pin.y, accuracy: 1e-9, "closed and settled: the grip is on the pin")
        XCTAssertLessThan(rest.boom.minY, 0, "the mount plate stays tucked behind the menu bar (gap unchanged)")
        XCTAssertLessThanOrEqual(rest.boom.maxY - line, 0.12 * width, "only the lower jaw's lip tucks behind the canopy frame")
        XCTAssertGreaterThanOrEqual(lug.minX, 0); XCTAssertLessThanOrEqual(lug.maxX, width, "the lug fits the panel")
      }
    }
  }

  /// Decision C / macrev2-1207-2: with the shutter closed only the clamp shows, at every width: no shaft ink below the
  /// menu bar, the 10 pt gap and the pin in the grip. Open, the boom is the widest status width (D447); the shutter's
  /// travel changes the drawn width continuously.
  func testClosedShutterShowsOnlyTheClampAtEveryWidth() throws {
    let m = CockpitDockingBoom.metrics, gap = CockpitShellLayout.menuBarGap
    for widest in [CGFloat(24), 28, 32, 40, 58, 96] {
      let width = CockpitDockingBoom.drawnWidth(widest: widest, line: gap, closed: 1)
      XCTAssertGreaterThanOrEqual(width, widest, "never narrower than the widest status width")
      let pose = CockpitDockingBoom.pose(width: width, line: gap, slide: 1, closure: 1, lugShown: true)
      let clampTop = pose.boom.minY + pose.boom.height * m.clampTop
      XCTAssertLessThanOrEqual(clampTop, 1e-9, "\(widest) pt: no shaft below the menu bar")
      let lug = try XCTUnwrap(pose.lug)
      XCTAssertEqual(lug.maxY, gap, accuracy: 1e-9, "\(widest) pt: the lug on the closed shell's top edge, 10 pt down")
      XCTAssertEqual(pose.boom.minY + pose.boom.height * m.gripY, lug.minY + lug.height * m.lugPinY, accuracy: 1e-9, "pin in the grip")
      XCTAssertEqual(pose.boom.minX + width * m.gripX, lug.minX + lug.width * m.lugPinTip, accuracy: 1e-9)
      XCTAssertEqual(CockpitDockingBoom.drawnWidth(widest: widest, line: 35, closed: 0), widest, "open: the widest status width")
      var last = CockpitDockingBoom.drawnWidth(widest: widest, line: gap, closed: 0)
      for step in 1...20 {
        let next = CockpitDockingBoom.drawnWidth(widest: widest, line: gap, closed: CGFloat(step) / 20)
        XCTAssertGreaterThanOrEqual(next, last - 1e-9); XCTAssertLessThanOrEqual(next - last, 2.5, "no jump while the shutter moves")
        last = next
      }
    }
  }

  /// D439 (macrev2-1207-1): a departure holds still while the clamp opens: its full travel from closed, part of it from
  /// partly closed, nothing when it is open or under Reduce Motion.
  func testTheReleaseHoldsForTheClampsRemainingTravel() {
    XCTAssertEqual(CockpitDockingBoom.releaseHold(closure: 1, reduceMotion: false), CockpitDockingBoom.clampTravel)
    XCTAssertEqual(CockpitDockingBoom.releaseHold(closure: 0.5, reduceMotion: false), CockpitDockingBoom.clampTravel / 2, accuracy: 1e-12)
    XCTAssertEqual(CockpitDockingBoom.releaseHold(closure: 0, reduceMotion: false), 0)
    XCTAssertEqual(CockpitDockingBoom.releaseHold(closure: 1, reduceMotion: true), 0)
    XCTAssertEqual(CockpitDockingBoom.releaseHold(closure: .nan, reduceMotion: false), 0)
  }

  /// D439/D446: the clamp is open while the boom slides and while the cockpit is away, closes once the boom is down and
  /// the cockpit is home, and opens first on the way back. The settle is a small dip that is gone at either end.
  func testTheClampOpensAndClosesAtTheRightPhases() {
    XCTAssertEqual(CockpitDockingBoom.clampTarget(slide: 0, cockpitHome: false), 0)
    XCTAssertEqual(CockpitDockingBoom.clampTarget(slide: 0.6, cockpitHome: true), 0, "still sliding: open")
    XCTAssertEqual(CockpitDockingBoom.clampTarget(slide: 1, cockpitHome: false), 0, "down but the cockpit has not arrived: open")
    XCTAssertEqual(CockpitDockingBoom.clampTarget(slide: 1, cockpitHome: true), 1, "down and home: closes on the lug")
    XCTAssertEqual(CockpitDockingBoom.clampPhase(closure: 0, target: 0), .open)
    XCTAssertEqual(CockpitDockingBoom.clampPhase(closure: 0.3, target: 1), .closing)
    XCTAssertEqual(CockpitDockingBoom.clampPhase(closure: 1, target: 1), .closed)
    XCTAssertEqual(CockpitDockingBoom.clampPhase(closure: 0.7, target: 0), .opening)
    // The driver: closes over `clampTravel`, opens the same way, at once under Reduce Motion.
    var c: CGFloat = 0, elapsed: TimeInterval = 0
    while c < 1 { c = CockpitWindowController.advanceClamp(c, toward: 1, by: 1.0 / 60, reduceMotion: false); elapsed += 1.0 / 60 }
    XCTAssertEqual(elapsed, CockpitDockingBoom.clampTravel, accuracy: 1.0 / 60)
    XCTAssertEqual(CockpitWindowController.advanceClamp(1, toward: 0, by: 1.0 / 60, reduceMotion: true), 0)
    XCTAssertEqual(CockpitWindowController.advanceClamp(1, toward: 1, by: 1, reduceMotion: false), 1, "at rest nothing moves")
    let open = CockpitDockingBoom.pose(width: 40, line: 35, slide: 1, closure: 0, lugShown: true)
    let mid = CockpitDockingBoom.pose(width: 40, line: 35, slide: 1, closure: 0.5, lugShown: true)
    let closed = CockpitDockingBoom.pose(width: 40, line: 35, slide: 1, closure: 1, lugShown: true)
    XCTAssertEqual(open.boom.minY, closed.boom.minY, accuracy: 1e-9, "the settle leaves no offset at rest")
    XCTAssertEqual(mid.boom.minY - open.boom.minY, 40 * CockpitDockingBoom.settleDepth, accuracy: 1e-9, "a small dip")
    XCTAssertLessThanOrEqual(mid.boom.minY - open.boom.minY, 1.5)
    XCTAssertNil(CockpitDockingBoom.pose(width: 40, line: 35, slide: 1, closure: 0, lugShown: false).lug, "no lug unless attached")
  }

  /// D186/D188: the visible rack first (0.25 s), then the cockpit (0.25 s); only an attached open from a real icon, with motion.
  func testTheIconOpenExtendsTheRackFirstOnlyWhenItCan() {
    XCTAssertEqual(CockpitLaunchRackTiming.rackOpen, 0.25); XCTAssertEqual(CockpitLaunchRackTiming.cockpitOpen, 0.25)
    XCTAssertEqual(CockpitLaunchRackTiming.keyDetachBurn, 0.6); XCTAssertEqual(CockpitLaunchRackTiming.catchZone, 40)
    XCTAssertEqual(CockpitLaunchRackTiming.landingStep, 56)
    let icon = CGRect(x: 900, y: 1080, width: 28, height: 37)
    XCTAssertTrue(CockpitWindowController.opensRackFirst(.fromIcon, reduceMotion: false, detached: false, icon: icon))
    XCTAssertFalse(CockpitWindowController.opensRackFirst(.fade, reduceMotion: false, detached: false, icon: icon), "an ordinary open keeps its fade")
    XCTAssertFalse(CockpitWindowController.opensRackFirst(.fromIcon, reduceMotion: true, detached: false, icon: icon))
    XCTAssertFalse(CockpitWindowController.opensRackFirst(.fromIcon, reduceMotion: false, detached: true, icon: icon))
    XCTAssertFalse(CockpitWindowController.opensRackFirst(.fromIcon, reduceMotion: false, detached: false, icon: nil))
    XCTAssertEqual(CockpitLaunchRackTiming.flight(length: 0), 0.82); XCTAssertEqual(CockpitLaunchRackTiming.flight(length: 5000), 1.3)
  }

  /// G3-130 (owner, 11-18): the rack and the put back start together at their normal speeds. A long flight (0.82 s or
  /// more) lands on a full rack (0.56 s); a short move or a ride home lands while the rack is still coming down.
  func testWhereTheRackIsWhenTheCockpitLands() {
    let full = CockpitLaunchRackTiming.fullTravel
    XCTAssertEqual(CockpitLaunchRackTiming.rackAtLanding(motion: CockpitLaunchRackTiming.flight(length: 0), rackExtension: 0), 1, "long: full")
    XCTAssertEqual(CockpitLaunchRackTiming.rackAtLanding(motion: CockpitLaunchRackTiming.flight(length: 900), rackExtension: 0), 1)
    XCTAssertEqual(CockpitLaunchRackTiming.rackAtLanding(motion: CockpitLaunchRackTiming.rideHome, rackExtension: 0), CGFloat(0.3 / full),
                   accuracy: 1e-9, "a ride home released at once: partly out")
    XCTAssertEqual(CockpitLaunchRackTiming.rackAtLanding(motion: 0.1, rackExtension: 0.2), CGFloat(0.2 + 0.1 / full), accuracy: 1e-9, "short")
    XCTAssertEqual(CockpitLaunchRackTiming.rackAtLanding(motion: CockpitLaunchRackTiming.rideHome, rackExtension: 0.6), 1, "already mostly out")
  }

  /// G3-130: the controller's 60 Hz driver (`rackTick`): the rack advances at the full-travel pace, the motion runs on
  /// its own clock. For short, medium and long put backs, from any rack position and with uneven ticks: the cockpit lands
  /// at its own motion time (never delayed), the rack there is where `rackAtLanding` says (< 1 short, 1 long), and after
  /// the landing it carries on at the same pace to 1 with no jump.
  func testTheCockpitLandsOnTimeAndTheRackCarriesOnSmoothly() {
    let full = CockpitLaunchRackTiming.fullTravel
    let motions: [TimeInterval] = [0.01, 0.1, CockpitLaunchRackTiming.rideHome, CockpitLaunchRackTiming.flight(length: 0),
                                   CockpitLaunchRackTiming.flight(length: 900)]
    for motion in motions {
      for start in [CGFloat(0), 0.2, 0.75, 1] {
        for jitter in [0.0, 0.004, 0.011] {
          var ext = start, elapsed = 0.0, n = 0, landedAt: Double?, extAtLanding: CGFloat?
          while ext < 1 || landedAt == nil {
            n += 1; if n > 10_000 { XCTFail("never settled"); break }
            let dt = 1.0 / 60 + (n % 3 == 0 ? jitter : -jitter / 2)
            elapsed += dt
            let before = ext
            ext = min(1, ext + CGFloat(dt / full))
            XCTAssertLessThanOrEqual(ext - before, CGFloat(dt / full) + 1e-9, "no jump in the rack")
            XCTAssertGreaterThanOrEqual(ext, before, "the rack never goes back")
            if landedAt == nil, elapsed >= motion { landedAt = elapsed; extAtLanding = ext }
          }
          let label = "motion \(motion) s from rack \(start), jitter \(jitter)"
          XCTAssertLessThan((landedAt ?? .infinity) - motion, 1.0 / 60 + jitter + 1e-9, "\(label): the landing is not delayed")
          let expected = CockpitLaunchRackTiming.rackAtLanding(motion: landedAt ?? motion, rackExtension: start)
          XCTAssertEqual(extAtLanding ?? -1, expected, accuracy: 1e-6, label)
          if start == 0, motion < full - 0.05 { XCTAssertLessThan(extAtLanding ?? 1, 1, "\(label): short, partly out") }
          if motion >= full + 0.05 { XCTAssertEqual(extAtLanding, 1, "\(label): long, fully out") }
        }
      }
    }
  }

  /// macrevb/macrev2-1038-1: every put-back path starts exactly where the cockpit is and moves without a jump, also from
  /// above home: a detached cockpit on a display stacked above (home (0, 0), start (0, 1080), aligned x) and a drag
  /// released just above home. Before, the flight and the ride clamped y to home's height, so the first frame was home.
  func testPutBackPathsStartWhereTheCockpitIsAndNeverJump() {
    let zone = CockpitLaunchRackTiming.catchZone, home = CGPoint.zero
    func assertContinuous(_ name: String, _ p0: CGPoint, duration: TimeInterval, _ path: (CGFloat) -> CGPoint,
                          file: StaticString = #filePath, line: UInt = #line) {
      XCTAssertEqual(path(0), p0, "\(name): the first frame is where the cockpit is", file: file, line: line)
      XCTAssertEqual(path(1).x, home.x, accuracy: 1e-9, file: file, line: line)
      XCTAssertEqual(path(1).y, home.y, accuracy: 1e-9, "\(name): it ends at home", file: file, line: line)
      // At 60 Hz no frame moves more than a fifth of the whole path, plus 1 pt (the old clamp jumped all of it at once).
      let frames = max(1, Int((duration * 60).rounded(.up)))
      var travel: CGFloat = 0, previous = path(0)
      for n in 1...frames { let next = path(CGFloat(n) / CGFloat(frames)); travel += hypot(next.x - previous.x, next.y - previous.y); previous = next }
      previous = path(0)
      for n in 1...frames {
        let next = path(CGFloat(n) / CGFloat(frames))
        XCTAssertLessThanOrEqual(hypot(next.x - previous.x, next.y - previous.y), travel / 5 + 1,
                                 "\(name): frame \(n) jumps", file: file, line: line)
        previous = next
      }
    }
    for p0 in [CGPoint(x: 0, y: 1080), CGPoint(x: 0, y: 5), CGPoint(x: 900, y: 1200), CGPoint(x: -300, y: -56), CGPoint(x: 1500, y: -700)] {
      let c = CockpitPutBackPath.control(from: p0, to: home, zone: zone)
      let length = hypot(c.x - p0.x, c.y - p0.y) + hypot(home.x - c.x, home.y - c.y)
      assertContinuous("key flight from \(p0)", p0, duration: CockpitLaunchRackTiming.flight(length: length)) {
        CockpitPutBackPath.flight(from: p0, to: home, zone: zone, at: $0)
      }
      // The last part runs straight up the rack: just before the landing the cockpit is under home, on its x.
      let late = CockpitPutBackPath.flight(from: p0, to: home, zone: zone, at: 0.98)
      XCTAssertLessThanOrEqual(late.y, home.y + 1e-9, "from \(p0): it comes up into home")
      if p0.y <= home.y {
        for n in 0...100 { XCTAssertLessThanOrEqual(CockpitPutBackPath.flight(from: p0, to: home, zone: zone, at: CGFloat(n) / 100).y, home.y + 1e-9,
                                                    "from below it never rises above home") }
      }
    }
    for p0 in [CGPoint(x: 0, y: 5), CGPoint(x: 12, y: -30), CGPoint(x: -20, y: 25)] {
      assertContinuous("ride home from \(p0)", p0, duration: CockpitLaunchRackTiming.rideHome) {
        CockpitPutBackPath.straight(from: p0, to: home, at: $0)
      }
    }
  }
  /// D299 (amends D188; WP-17, CKP-SHELL-53): the open from the icon overlaps the rack and cockpit phases. The rack leads
  /// (nothing of the cockpit at the click), the cockpit starts before the rack's visible part is out, the whole open takes
  /// about 0.37 s (within the 400 ms budget), and rack and cockpit only grow, ending together, fully out.
  func testIconOpenOverlapsTheRackAndTheCockpitInAbout037Seconds() {
    let total = CockpitLaunchRackTiming.overlappedOpen
    XCTAssertEqual(total, 0.37, accuracy: 0.005)
    XCTAssertLessThanOrEqual(total, 0.4, "the open animation budget")
    XCTAssertGreaterThan(CockpitLaunchRackTiming.cockpitOpenDelay, 0, "the rack still leads")
    XCTAssertLessThan(CockpitLaunchRackTiming.cockpitOpenDelay, CockpitLaunchRackTiming.rackOpen,
                      "the cockpit starts before the rack's visible part is out")
    let start = CockpitLaunchRackTiming.openProgress(elapsed: 0)
    XCTAssertEqual(start.rack, 0); XCTAssertEqual(start.cockpit, 0)
    let led = CockpitLaunchRackTiming.openProgress(elapsed: CockpitLaunchRackTiming.cockpitOpenDelay)
    XCTAssertGreaterThan(led.rack, 0); XCTAssertEqual(led.cockpit, 0, "the cockpit has not started yet")
    let overlap = CockpitLaunchRackTiming.openProgress(elapsed: 0.2)
    XCTAssertGreaterThan(overlap.cockpit, 0, "both move at 0.2 s")
    XCTAssertLessThan(overlap.rack, 1)
    let end = CockpitLaunchRackTiming.openProgress(elapsed: total)
    XCTAssertEqual(end.rack, 1, accuracy: 1e-9); XCTAssertEqual(end.cockpit, 1, accuracy: 1e-9)
    var last = start
    for step in 1...100 {
      let now = CockpitLaunchRackTiming.openProgress(elapsed: total * Double(step) / 100)
      XCTAssertGreaterThanOrEqual(now.rack, last.rack); XCTAssertGreaterThanOrEqual(now.cockpit, last.cockpit)
      XCTAssertLessThan(now.rack - last.rack, 0.05, "no jump in the rack")
      last = now
    }
  }
}
