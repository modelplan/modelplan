// SPDX-License-Identifier: MIT
import AppKit
import Foundation
import XCTest

@testable import ModelPlanCockpitWeb

/// Build 14c, G3-79: with two displays the cockpit opens on the display the user clicked (the widget's ignition),
/// not on the menu bar icon's; a drag takes it to any display; a remembered detached origin is replayed only while it
/// is still on a display. Uses a fixed two-display arrangement through the controller's `screens` seam.
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
  private func page(session: CockpitShellSession? = nil, click: CGPoint?) throws -> CockpitWindowController {
    let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic", generation: 1)
    let icon = self.icon
    let page = CockpitWindowController(bundle: try bundle(), context: context, appearance: .init(theme: .night, locale: .en, profile: .full),
                                       shellSession: session ?? CockpitShellSession(), anchor: { icon }, openPoint: { click })
    let displays = [a, b]
    page.screens = { displays }
    page.separateSpaces = { true } // the macOS default: every display has its own menu bar
    return page
  }
  private func assertInside(_ frame: CGRect, _ usable: CGRect, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(usable.contains(frame), "\(message): \(NSStringFromRect(frame)) is not inside \(NSStringFromRect(usable))", file: file, line: line)
  }

  func testTheClickScreenWinsOverTheIconScreen() {
    XCTAssertEqual(CockpitScreenSelection.openScreen(point: clickOnB, anchor: icon, screens: [a, b]), b, "a click on B opens on B")
    XCTAssertEqual(CockpitScreenSelection.openScreen(point: nil, anchor: icon, screens: [a, b]), a, "no click: the icon's display")
    XCTAssertEqual(CockpitScreenSelection.openScreen(point: CGPoint(x: -5000, y: 0), anchor: icon, screens: [a, b]), a,
                   "a click on no display falls back to the icon's display")
    XCTAssertEqual(CockpitScreenSelection.openScreen(point: nil, anchor: nil, screens: [b, a]), b, "nothing known: the first (main) display")
    XCTAssertEqual(CockpitScreenSelection.containing(CGPoint(x: 4072, y: 1440), in: [a, b]), b, "B's top-right corner is on B")
  }

  /// The owner's 14c report: the ignition on B opened the cockpit on A, under the icon.
  func testIgnitionOnTheSecondDisplayOpensTheCockpitThere() throws {
    let page = try page(click: clickOnB)
    let (usable, anchor) = try XCTUnwrap(page.environment())
    XCTAssertEqual(usable, b.visibleFrame, "the cockpit lays out on B")
    // D204: B's own menu bar shows the icon at the same distance from its top-right corner as A's.
    XCTAssertEqual(anchor, CGRect(x: 3660, y: 1407, width: 28, height: 24), "under the icon on B's menu bar")
    let placed = try XCTUnwrap(page.placement())
    assertInside(placed.frame, b.visibleFrame, "attached open from B")
  }

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
    let start = try XCTUnwrap(page.placement()).frame
    let from = CGPoint(x: start.minX + 100, y: start.maxY - 20)
    // Well into B, then hard against B's bottom-right corner: before 14c this was clamped back into A.
    for to in [CGPoint(x: 2600, y: 600), CGPoint(x: 4071, y: 1)] {
      let moved = page.dragFrame(start: start, from: from, to: to)
      assertInside(moved, b.visibleFrame, "drag to \(to)")
      XCTAssertEqual(moved.size, start.size, "a drag never resizes")
    }
    let back = page.dragFrame(start: start, from: from, to: CGPoint(x: 300, y: 300))
    assertInside(back, a.visibleFrame, "and back onto A")
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

  /// macrev2-845-1: a drop on a shorter display fits the cockpit there. Before, the drag kept B's full-size frame and
  /// clamped only its origin, so on a 775 pt visible frame its top stayed above the display.
  func testADropOnAShorterDisplayFitsTheCockpitThere() throws {
    let short = CockpitScreen(frame: CGRect(x: 0, y: 0, width: 1280, height: 800), visibleFrame: CGRect(x: 0, y: 0, width: 1280, height: 775))
    let large = CockpitScreen(frame: CGRect(x: 1280, y: 0, width: 2560, height: 1440), visibleFrame: CGRect(x: 1280, y: 0, width: 2560, height: 1415))
    let session = CockpitShellSession()
    let page = try page(session: session, click: CGPoint(x: 3000, y: 700))
    let displays = [short, large]
    page.screens = { displays }
    page.prewarm()
    defer { page.discard() }
    let window = try XCTUnwrap(page.window)
    assertInside(window.frame, large.visibleFrame, "opened on the large display, where the click was")
    XCTAssertGreaterThan(window.frame.height, short.visibleFrame.height, "the large display's cockpit is taller than the short display")
    let from = CGPoint(x: window.frame.minX + 60, y: window.frame.maxY - 30)
    page.titleDrag(.began, point: from)
    page.titleDrag(.moved, point: CGPoint(x: from.x - 40, y: from.y))
    page.titleDrag(.moved, point: CGPoint(x: 600, y: 400))
    page.titleDrag(.ended, point: CGPoint(x: 600, y: 400))
    XCTAssertFalse(page.isAttached)
    assertInside(window.frame, short.visibleFrame, "the whole cockpit is on the short display after the drop")
    let fitted = try XCTUnwrap(page.placement())
    XCTAssertEqual(window.frame, fitted.frame, "the layout is the short display's fit")
    let expected = try XCTUnwrap(CockpitShellLayout.fit(usable: short.visibleFrame, anchor: CockpitShellLayout.hiddenIconAnchor(usable: short.visibleFrame),
                                                        shutterClosed: false, screenWidth: short.frame.width))
    XCTAssertEqual(fitted.frame.size, expected.frame.size, "zoom and profile are the short display's")
    XCTAssertEqual(session.origin(for: page.arrangement), window.frame.origin, "the fitted place is remembered")
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
}
