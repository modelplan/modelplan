// SPDX-License-Identifier: MIT
import AppKit
import Foundation
import XCTest

@testable import ModelPlanCockpitWeb

/// Build 14c, G3-76: with two displays the cockpit opens on the display the user clicked (the widget's ignition),
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
  private func page(session: CockpitShellSession = CockpitShellSession(), click: CGPoint?) throws -> CockpitWindowController {
    let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic", generation: 1)
    let icon = self.icon
    let page = CockpitWindowController(bundle: try bundle(), context: context, appearance: .init(theme: .night, locale: .en, profile: .full),
                                       shellSession: session, anchor: { icon }, openPoint: { click })
    let displays = [a, b]
    page.screens = { displays }
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
    XCTAssertEqual(anchor, CockpitShellLayout.hiddenIconAnchor(usable: b.visibleFrame), "B has no icon: top right of B, below its menu bar")
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
    XCTAssertEqual(placed.frame.midX, icon.midX, accuracy: 1, "centred under the icon (D88)")
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
