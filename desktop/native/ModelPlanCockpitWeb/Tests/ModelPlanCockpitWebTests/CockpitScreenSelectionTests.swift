// SPDX-License-Identifier: MIT
import AppKit
import Foundation
import XCTest

@testable import ModelPlanCockpitWeb

/// Build 14c, G3-79: with two displays a detached open goes to the display the user clicked (the widget's ignition);
/// a drag takes it to any display; a remembered detached origin is replayed only while it is still on a display.
/// Build 15, G3-128: attached (open, rack, catch zone, put back) it always belongs to the status item's display.
/// Uses a fixed two-display arrangement through the controller's `screens` seam.
@MainActor final class CockpitScreenSelectionTests: XCTestCase {
  /// A: the built-in 1512 x 982 display with the menu bar (33 pt) and the status item. B: a 2560 x 1440 display to its right.
  private let a = CockpitScreen(frame: CGRect(x: 0, y: 0, width: 1512, height: 982), visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 949))
  private let b = CockpitScreen(frame: CGRect(x: 1512, y: 0, width: 2560, height: 1440), visibleFrame: CGRect(x: 1512, y: 0, width: 2560, height: 1415))
  /// The status item on A's menu bar.
  private let icon = CGRect(x: 1100, y: 949, width: 28, height: 24)
  /// The ignition click on the widget, resting on B's right edge.
  private let clickOnB = CGPoint(x: 3990, y: 700)

  private func bundle() throws -> VerifiedCockpitBundle {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("cockpit-screens-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: root) }
    let html = Data("<!doctype html><title>synthetic</title>".utf8); try html.write(to: root.appendingPathComponent("index.html"))
    let manifest = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "edition": "community", "interfaceOnly": true, "files": ["index.html": VerifiedCockpitBundle.digest(html)]])
    try manifest.write(to: root.appendingPathComponent("bundle-manifest.json"))
    return try VerifiedCockpitBundle(root: root, manifestSHA256: VerifiedCockpitBundle.digest(manifest))
  }
  /// The production controller with the app's anchor and open-point closures, on the fixed arrangement.
  private func page(session: CockpitShellSession? = nil, click: CGPoint?, reduceMotion: Bool = false) throws -> CockpitWindowController {
    let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic", generation: 1)
    let icon = self.icon
    let page = CockpitWindowController(bundle: try bundle(), context: context, appearance: .init(theme: .night, locale: .en, profile: .full, reduceMotion: reduceMotion),
                                       shellSession: session ?? CockpitShellSession(), anchor: { icon }, openPoint: { click })
    let displays = [a, b]
    page.screens = { displays }
    return page
  }
  private func assertInside(_ frame: CGRect, _ usable: CGRect, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(usable.contains(frame), "\(message): \(NSStringFromRect(frame)) is not inside \(NSStringFromRect(usable))", file: file, line: line)
  }

  private func hull(_ windowFrame: CGRect, reserve: CGFloat) -> CGRect {
    let (_, hull) = windowFrame.divided(atDistance: reserve, from: .minYEdge)
    return hull
  }

  func testTheClickScreenWinsOverTheIconScreen() {
    XCTAssertEqual(CockpitScreenSelection.openScreen(point: clickOnB, anchor: icon, screens: [a, b]), b, "a click on B opens on B")
    XCTAssertEqual(CockpitScreenSelection.openScreen(point: nil, anchor: icon, screens: [a, b]), a, "no click: the icon's display")
    XCTAssertEqual(CockpitScreenSelection.openScreen(point: CGPoint(x: -5000, y: 0), anchor: icon, screens: [a, b]), a,
                   "a click on no display falls back to the icon's display")
    XCTAssertEqual(CockpitScreenSelection.openScreen(point: nil, anchor: nil, screens: [b, a]), b, "nothing known: the first (main) display")
    XCTAssertEqual(CockpitScreenSelection.containing(CGPoint(x: 4072, y: 1440), in: [a, b]), b, "B's top-right corner is on B")
  }

  /// G3-128 (a), owner build 15: the ignition on B opened the attached cockpit on B, under a computed icon on B's menu
  /// bar, and the rack had no real icon there. Attached, it belongs to the status item's display (A), under the icon.
  func testAnAttachedOpenFromTheSecondDisplayGoesUnderTheStatusItem() throws {
    let page = try page(click: clickOnB)
    let (usable, anchor) = try XCTUnwrap(page.environment())
    XCTAssertEqual(usable, a.visibleFrame, "the cockpit lays out on the status item's display")
    XCTAssertEqual(anchor, icon, "under the status item itself")
    let placed = try XCTUnwrap(page.placement())
    assertInside(placed.frame, a.visibleFrame, "attached open from B")
    XCTAssertEqual(page.rackIcon(), icon, "the rack hangs from the status item")
    XCTAssertEqual(page.attachedHome(), placed.frame, "home is that same place")
  }

  func testSqueezedStatusItemKeepsTheCockpitAndRackOnItsDisplay() throws {
    let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic", generation: 1)
    let barDisplay = b
    let page = CockpitWindowController(bundle: try bundle(), context: context,
      appearance: .init(theme: .night, locale: .en, profile: .full), statusScreen: { barDisplay.frame },
      openPoint: { CGPoint(x: 500, y: 400) })
    let displays = [a, b]
    page.screens = { displays }
    let placement = try XCTUnwrap(page.placement())
    assertInside(placement.frame, barDisplay.visibleFrame, "a hidden icon still owns its cockpit display")
    XCTAssertEqual(page.rackIcon(), CockpitShellLayout.menuBarEdgeAnchor(screen: barDisplay))
    XCTAssertTrue(CockpitWindowController.opensRackFirst(.fromIcon, reduceMotion: false, detached: false, icon: page.rackIcon()))
  }

  /// G3-128 (b): a cockpit opened from B, detached and left on B, goes home to the status item's display. Before, the
  /// put back target was computed with the open's click point and so stayed on B.
  func testPutBackHomeIsOnTheStatusItemsDisplayAfterADetachToTheOtherDisplay() throws {
    let session = CockpitShellSession()
    let page = try page(session: session, click: clickOnB)
    session.detached = true
    session.remember(CGPoint(x: 2600, y: 300), arrangement: page.arrangement)
    let (usable, _) = try XCTUnwrap(page.environment())
    XCTAssertEqual(usable, b.visibleFrame, "detached it stays where it was left, on B")
    let home = try XCTUnwrap(page.attachedHome())
    let attached = try XCTUnwrap(CockpitShellLayout.fit(usable: a.visibleFrame, anchor: icon, shutterClosed: false, screenWidth: a.frame.width))
    XCTAssertEqual(home, attached.frame, "home is under the status item on A")
    XCTAssertEqual(page.rackIcon(), icon, "and the rack that catches it hangs from the status item")
    XCTAssertTrue(page.inCatchZone(home), "the catch zone is around that home")
    let bHome = try XCTUnwrap(CockpitShellLayout.fit(usable: b.visibleFrame, anchor: CockpitShellLayout.hiddenIconAnchor(usable: b.visibleFrame),
                                                     shutterClosed: false, screenWidth: b.frame.width))
    XCTAssertFalse(page.inCatchZone(bHome.frame), "B's top-right is not home")
    XCTAssertTrue(session.detached, "asking for home does not change the session")
  }

  #if MODELPLAN_TEST_ONLY_SPI
  /// G3-128 (a)+(b) through the real window: prewarmed from a press on B it sits on A; dragged onto B and put back with
  /// the strip key it returns to A under the icon, attached. Window server: GUI leg.
  func testTheStripKeyPutBackReturnsToTheStatusItemsDisplay() throws {
    let session = CockpitShellSession()
    let page = try page(session: session, click: clickOnB, reduceMotion: true)
    page.prewarm()
    page.verificationWebView?.navigationDelegate = nil // the headless synthetic load must not discard the window
    defer { page.discard() }
    let window = try XCTUnwrap(page.window)
    let home = try XCTUnwrap(CockpitShellLayout.fit(usable: a.visibleFrame, anchor: icon, shutterClosed: false, screenWidth: a.frame.width)).frame
    assertInside(window.frame, a.visibleFrame, "opened from B, attached under the status item on A")
    let from = CGPoint(x: window.frame.minX + 60, y: window.frame.maxY - 30)
    page.titleDrag(.began, point: from)
    page.titleDrag(.moved, point: CGPoint(x: from.x + 40, y: from.y))
    page.titleDrag(.moved, point: CGPoint(x: 2800, y: 900))
    page.titleDrag(.ended, point: CGPoint(x: 2800, y: 900))
    XCTAssertFalse(page.isAttached)
    assertInside(window.frame, b.visibleFrame, "detached on B")
    page.setAttached(true) // the strip's put-back key
    XCTAssertTrue(page.isAttached, "Reduce Motion: latched at once")
    XCTAssertEqual(window.frame, home, "back under the status item on A, not B's top right")
    XCTAssertEqual(page.verificationRack.target, 1, "the rack holds it from the status item")
  }
  #endif

  /// C-24 stays as it was: the menu bar icon (no click point) opens attached under the icon on A.
  func testTheIconStillOpensUnderTheIcon() throws {
    let page = try page(click: nil)
    let (usable, anchor) = try XCTUnwrap(page.environment())
    XCTAssertEqual(usable, a.visibleFrame); XCTAssertEqual(anchor, icon)
    let placed = try XCTUnwrap(page.placement())
    assertInside(placed.frame, a.visibleFrame, "attached open from the icon")
    let attached = try XCTUnwrap(CockpitShellLayout.fit(usable: a.visibleFrame, anchor: icon, shutterClosed: false, screenWidth: a.frame.width))
    XCTAssertEqual(placed.frame, attached.frame, "the attached place under the icon (CKP-SHELL-33: its left shoulder, kept on screen)")
  }

  func testADragOntoTheOtherDisplayEndsInsideIt() throws {
    let page = try page(click: nil)
    let placement = try XCTUnwrap(page.placement())
    let start = placement.frame
    let reserve = placement.fit.hullBottomInset
    let from = CGPoint(x: start.minX + 100, y: start.maxY - 20)
    // Well into B, then hard against B's bottom-right corner: before 14c this was clamped back into A.
    for to in [CGPoint(x: 2600, y: 600), CGPoint(x: 4071, y: 1)] {
      let moved = page.dragFrame(start: start, from: from, to: to)
      assertInside(hull(moved, reserve: reserve), b.visibleFrame, "drag to \(to)")
      XCTAssertEqual(moved.size, start.size, "a drag never resizes")
    }
    let back = page.dragFrame(start: start, from: from, to: CGPoint(x: 300, y: 300))
    assertInside(hull(back, reserve: reserve), a.visibleFrame, "and back onto A")
    XCTAssertEqual(back.size, start.size, "the return drag keeps the same size")
  }

  /// The normal drag entry: the title strip's phases move the real window onto B and remember the origin there.
  func testTheTitleStripDragsTheWindowOntoTheOtherDisplay() throws {
    let session = CockpitShellSession()
    let page = try page(session: session, click: nil)
    page.prewarm()
    defer { page.discard() }
    let window = try XCTUnwrap(page.window)
    assertInside(window.frame, a.visibleFrame, "prewarmed on the icon's display")
    let from = CGPoint(x: window.frame.minX + 60, y: window.frame.maxY - 30)
    page.titleDrag(.began, point: from)
    page.titleDrag(.moved, point: CGPoint(x: from.x + 40, y: from.y))
    page.titleDrag(.moved, point: CGPoint(x: 2800, y: 900))
    page.titleDrag(.ended, point: CGPoint(x: 2800, y: 900))
    XCTAssertFalse(page.isAttached, "a drag detaches")
    assertInside(window.frame, b.visibleFrame, "the window followed the pointer onto B")
    XCTAssertEqual(session.origin(for: page.arrangement), window.frame.origin, "the place on B is remembered")
  }

  /// G3-132 (owner, 11-18; replaces macrev2-845-1's refit at the drop): one cockpit size on every display, capped by
  /// the smallest one. A drag between displays never resizes it (no "too big then shrink", no "small then grow"), and it
  /// is fully inside whichever display it is dropped on. Window server: GUI leg.
  func testOneCockpitSizeOnEveryDisplayAndADragNeverResizesIt() throws {
    let short = CockpitScreen(frame: CGRect(x: 0, y: 0, width: 1280, height: 800), visibleFrame: CGRect(x: 0, y: 0, width: 1280, height: 775))
    let large = CockpitScreen(frame: CGRect(x: 1280, y: 0, width: 2560, height: 1440), visibleFrame: CGRect(x: 1280, y: 0, width: 2560, height: 1415))
    let session = CockpitShellSession()
    let page = try page(session: session, click: CGPoint(x: 3000, y: 700))
    let displays = [short, large]
    page.screens = { displays }
    page.prewarm()
    defer { page.discard() }
    let window = try XCTUnwrap(page.window)
    let size = window.frame.size
    let smallest = try XCTUnwrap(CockpitShellLayout.fit(usable: short.visibleFrame, anchor: CockpitShellLayout.hiddenIconAnchor(usable: short.visibleFrame),
                                                        shutterClosed: false, screenWidth: short.frame.width))
    XCTAssertEqual(size, smallest.frame.size, "the short display's size")
    let from = CGPoint(x: window.frame.minX + 60, y: window.frame.maxY - 30)
    page.titleDrag(.began, point: from)
    page.titleDrag(.moved, point: CGPoint(x: from.x - 40, y: from.y))
    for to in [CGPoint(x: 1200, y: 500), CGPoint(x: 1600, y: 900), CGPoint(x: 3000, y: 1200)] {
      page.titleDrag(.moved, point: to)
      XCTAssertEqual(window.frame.size, size, "mid-drag at \(to): the size never changes")
    }
    page.titleDrag(.ended, point: CGPoint(x: 3000, y: 1200))
    XCTAssertFalse(page.isAttached)
    XCTAssertEqual(window.frame.size, size, "dropped on the large display: the same size")
    assertInside(window.frame, large.visibleFrame, "on the large display")
    let back = CGPoint(x: window.frame.minX + 60, y: window.frame.maxY - 30)
    page.titleDrag(.began, point: back)
    page.titleDrag(.moved, point: CGPoint(x: back.x - 40, y: back.y))
    page.titleDrag(.moved, point: CGPoint(x: 600, y: 400))
    page.titleDrag(.ended, point: CGPoint(x: 600, y: 400))
    XCTAssertEqual(window.frame.size, size, "and back on the short display: the same size")
    let droppedHull = hull(window.frame, reserve: smallest.hullBottomInset)
    assertInside(droppedHull, short.visibleFrame, "the hull is on the short display")
    XCTAssertEqual(droppedHull.minY, short.visibleFrame.minY, accuracy: 1, "the hull reaches the bottom")
    XCTAssertEqual(try XCTUnwrap(page.placement()).frame.size, size)
    XCTAssertEqual(session.origin(for: page.arrangement), window.frame.origin, "the place is remembered")
  }

  /// G3-132 (owner, 11-18; D66 amended): Auto is judged on the set of connected displays (85 % if any is laptop-width,
  /// 100 % only if all are wider), and every choice is capped by the smallest display's visible height, down to
  /// the D444 floor. Headless: the pure fit with the displays' basis, and the controller's `screens` seam.
  func testAutoAndTheCapFollowTheSetOfDisplays() throws {
    let air = CockpitScreen(frame: CGRect(x: 0, y: 0, width: 1470, height: 956), visibleFrame: CGRect(x: 0, y: 70, width: 1470, height: 849))
    let wide = CockpitScreen(frame: CGRect(x: 1470, y: 0, width: 2560, height: 1440), visibleFrame: CGRect(x: 1470, y: 0, width: 2560, height: 1415))
    let hd = CockpitScreen(frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080), visibleFrame: CGRect(x: -1920, y: 0, width: 1920, height: 1055))
    let small = CockpitScreen(frame: CGRect(x: 0, y: 0, width: 1280, height: 800), visibleFrame: CGRect(x: 0, y: 0, width: 1280, height: 775))
    func scales(_ set: [CockpitScreen], _ size: CockpitSize = .automatic) throws -> [CGFloat] {
      let basis = try XCTUnwrap(CockpitSizeBasis(screens: set))
      return try set.map { screen in
        let fit = try XCTUnwrap(CockpitShellLayout.fit(usable: screen.visibleFrame, anchor: CockpitShellLayout.hiddenIconAnchor(usable: screen.visibleFrame),
                                                      shutterClosed: false, size: size, screenWidth: screen.frame.width, basis: basis))
        XCTAssertTrue(screen.visibleFrame.contains(fit.frame), "fully visible on \(NSStringFromRect(screen.frame))")
        return fit.scale
      }
    }
    // A laptop and an external display: Auto is 85 % on both (before, 100 % on the external one).
    XCTAssertEqual(try scales([air, wide]), [0.85, 0.85])
    XCTAssertEqual(try scales([wide, air]), [0.85, 0.85], "whichever display is listed first")
    // Two external displays: 100 % on both, capped by neither (the 1080p one has 1045 pt under the gap).
    XCTAssertEqual(try scales([wide, hd]), [1, 1])
    // A fixed 100 % with a small display connected: capped on both by the small display's room (765 / 951).
    for value in try scales([small, wide], .percent100) { XCTAssertEqual(value, 765 / 951, accuracy: 1e-9) }
    for value in try scales([small, wide], .percent80) { XCTAssertEqual(value, 0.8, accuracy: 1e-9, "80 % fits the small display") }
    // D444: a display too short for the full cockpit at 75 % scales the one layout down on every display (no short version).
    let tiny = CockpitScreen(frame: CGRect(x: 0, y: 0, width: 1280, height: 720), visibleFrame: CGRect(x: 0, y: 0, width: 1280, height: 695))
    let basis = try XCTUnwrap(CockpitSizeBasis(screens: [tiny, wide]))
    let onWide = try XCTUnwrap(CockpitShellLayout.fit(usable: wide.visibleFrame, anchor: CockpitShellLayout.hiddenIconAnchor(usable: wide.visibleFrame),
                                                      shutterClosed: false, screenWidth: wide.frame.width, basis: basis))
    XCTAssertEqual(onWide.profile, .full)
    XCTAssertEqual(onWide.scale, (695 - 10) / 951, accuracy: 1e-9, "the tiny display's scale on the wide display too")
    XCTAssertFalse(onWide.forcedClosed)
    XCTAssertNil(CockpitSizeBasis(screens: []))

    // The controller: a drag (detached, remembered on either display) keeps the size; adding or removing a display
    // recomputes it.
    let session = CockpitShellSession()
    let page = try page(session: session, click: nil)
    page.screens = { [air, wide] }
    session.detached = true
    session.remember(CGPoint(x: 2000, y: 300), arrangement: page.arrangement)
    let onTheWide = try XCTUnwrap(page.placement()).frame
    session.remember(CGPoint(x: 200, y: 200), arrangement: page.arrangement)
    let onTheAir = try XCTUnwrap(page.placement()).frame
    XCTAssertEqual(onTheWide.size, onTheAir.size, "the same size on both displays")
    XCTAssertEqual(onTheWide.width, 541, "Auto 85 %, judged on the set")
    page.screens = { [wide] }
    session.remember(CGPoint(x: 2000, y: 300), arrangement: page.arrangement)
    XCTAssertEqual(try XCTUnwrap(page.placement()).frame.width, 636, "the Air unplugged: the external display alone is 100 %")
    page.screens = { [wide, small] }
    session.remember(CGPoint(x: 2000, y: 300), arrangement: page.arrangement)
    XCTAssertEqual(try XCTUnwrap(page.placement()).frame.width, (636 * 765 / 951).rounded(.up), accuracy: 1,
                   "a small display plugged in: Auto 85 % capped by its 775 pt")
  }

  /// A remembered origin on a display that is no longer there is not replayed; the open goes to the click's display.
  func testAStaleDetachedOriginIsPlacedOnTheClickScreen() throws {
    let session = CockpitShellSession()
    let page = try page(session: session, click: clickOnB)
    session.detached = true
    session.remember(CGPoint(x: -3000, y: 200), arrangement: page.arrangement)
    let (usable, _) = try XCTUnwrap(page.environment())
    XCTAssertEqual(usable, b.visibleFrame, "the stale origin does not pick a display")
    assertInside(try XCTUnwrap(page.placement()).frame, b.visibleFrame, "placed on the click's display")
    XCTAssertNil(CockpitScreenSelection.replayFrame(origin: CGPoint(x: -3000, y: 200), size: CGSize(width: 636, height: 900), screens: [a, b]))
  }

  /// A remembered origin that is still on a display is replayed there, whichever display was clicked.
  func testARememberedOriginOnADisplayIsReplayed() throws {
    let session = CockpitShellSession()
    let page = try page(session: session, click: clickOnB)
    session.detached = true
    let origin = CGPoint(x: 200, y: 0)
    session.remember(origin, arrangement: page.arrangement)
    let (usable, _) = try XCTUnwrap(page.environment())
    XCTAssertEqual(usable, a.visibleFrame)
    let placed = try XCTUnwrap(page.placement())
    XCTAssertEqual(placed.frame.origin, origin, "replayed where it was left")
    // Partly off A's bottom: pulled back inside A rather than dropped.
    let clamped = try XCTUnwrap(CockpitScreenSelection.replayFrame(origin: CGPoint(x: 1300, y: -100), size: CGSize(width: 400, height: 300), screens: [a, b]))
    assertInside(clamped, a.visibleFrame, "clamped into the display it overlaps most")
  }

  func testReopeningAfterABottomEdgeDragKeepsTheTargetDisplayAndSize() throws {
    let session = CockpitShellSession()
    let drag = try page(session: session, click: nil)
    let start = try XCTUnwrap(drag.placement())
    let from = CGPoint(x: start.frame.minX + 100, y: start.frame.maxY - 20)
    let dropped = drag.dragFrame(start: start.frame, from: from, to: CGPoint(x: 2600, y: 1))
    session.detached = true
    session.remember(dropped.origin, arrangement: drag.arrangement)

    let reopened = try page(session: session, click: nil)
    let placement = try XCTUnwrap(reopened.placement())
    let visibleHull = hull(placement.frame, reserve: placement.fit.hullBottomInset)
    assertInside(visibleHull, b.visibleFrame, "the reopened hull is on the display where it was dropped")
    XCTAssertEqual(visibleHull.minY, b.visibleFrame.minY, accuracy: 1)
    XCTAssertEqual(placement.frame, dropped, "reopening keeps the origin and window size")
  }

  /// G3-159 (owner, build 2): the clamp counted the transparent flame reserve under the hull as part of the window, so a
  /// detached cockpit stopped a gap above the screen's bottom edge. The hull's bottom reaches the visible frame's bottom.
  func testADragToTheBottomPutsTheHullOnTheVisibleFramesBottomEdge() throws {
    let page = try page(click: nil)
    let start = try XCTUnwrap(page.placement())
    let from = CGPoint(x: start.frame.minX + 100, y: start.frame.maxY - 20)
    for (screen, target) in [(a, CGPoint(x: 700, y: 1)), (b, CGPoint(x: 2600, y: 1))] {
      let moved = page.dragFrame(start: start.frame, from: from, to: target)
      let hullBottom = moved.minY + start.fit.hullBottomInset
      XCTAssertEqual(hullBottom, screen.visibleFrame.minY, accuracy: 2, "hull bottom on \(NSStringFromRect(screen.visibleFrame))")
      XCTAssertGreaterThan(start.fit.hullBottomInset, 20, "the reserve under the hull is real")
      XCTAssertEqual(moved.size, start.frame.size)
    }
    // Top edge rule unchanged: dragged to the very top it stays under the menu bar.
    let top = page.dragFrame(start: start.frame, from: from, to: CGPoint(x: 700, y: 5000))
    XCTAssertLessThanOrEqual(top.maxY, a.visibleFrame.maxY)
  }
  func testTheClampLetsOnlyTheBottomOverhang() {
    let usable = CGRect(x: 0, y: 0, width: 1000, height: 800)
    let rect = CGRect(x: 10, y: -500, width: 300, height: 400)
    XCTAssertEqual(CockpitScreenSelection.clamp(rect, into: usable).minY, 0)
    XCTAssertEqual(CockpitScreenSelection.clamp(rect, into: usable, bottomOverhang: 34).minY, -34)
    XCTAssertEqual(CockpitScreenSelection.clamp(CGRect(x: 10, y: 900, width: 300, height: 400), into: usable, bottomOverhang: 34).maxY, 800)
  }
}
