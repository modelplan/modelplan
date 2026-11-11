// SPDX-License-Identifier: MIT
import Foundation
import XCTest

@testable import ModelPlanCockpitWeb

/// The enlarged field's lifetime: nothing exists before open, and every close path destroys the page.
final class CockpitFieldPanelTests: XCTestCase {
  @MainActor private func bundle(_ root: URL) throws -> VerifiedCockpitBundle {
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let html = Data("<!doctype html><title>synthetic field</title>".utf8)
    try html.write(to: root.appendingPathComponent("field.html"))
    try html.write(to: root.appendingPathComponent("index.html"))
    let manifest = try JSONSerialization.data(withJSONObject: [
      "schemaVersion": 1, "edition": "community", "interfaceOnly": true,
      "files": ["field.html": VerifiedCockpitBundle.digest(html), "index.html": VerifiedCockpitBundle.digest(html)],
    ])
    try manifest.write(to: root.appendingPathComponent("bundle-manifest.json"))
    return try VerifiedCockpitBundle(root: root, manifestSHA256: VerifiedCockpitBundle.digest(manifest))
  }
  @MainActor func testIdleClosesThePanelOnceAndCloseIsIdempotent() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("field-panel-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let panel = CockpitFieldPanel(bundle: try bundle(root), idleSeconds: 0.05)
    var closed = 0
    panel.onClosed = { closed += 1 }
    XCTAssertFalse(panel.isOpen)
    panel.close()
    XCTAssertEqual(closed, 0, "Closing an unopened panel does nothing")
    panel.open(payload: "{}", near: nil)
    XCTAssertTrue(panel.isOpen)
    for _ in 0..<100 where panel.isOpen { try await Task.sleep(for: .milliseconds(20)) }
    XCTAssertFalse(panel.isOpen, "The idle timer closes the panel")
    XCTAssertEqual(closed, 1)
    panel.close()
    XCTAssertEqual(closed, 1)
    panel.open(payload: "{}", near: nil)
    XCTAssertTrue(panel.isOpen, "A closed panel can open again")
    panel.close()
    XCTAssertEqual(closed, 2)
  }
  /// CKP-PORT-11E: a click outside the field makes its panel resign key, which closes it once and destroys the page.
  @MainActor func testLosingKeyClosesTheField() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("field-key-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let panel = CockpitFieldPanel(bundle: try bundle(root))
    var closed = 0
    panel.onClosed = { closed += 1 }
    panel.open(payload: "{}", near: nil)
    XCTAssertTrue(panel.isOpen)
    panel.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification))
    XCTAssertFalse(panel.isOpen, "the outside click closes the field")
    XCTAssertEqual(closed, 1)
    panel.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification))
    XCTAssertEqual(closed, 1, "a second resign does nothing")
  }
  /// CKP-PORT-11 (D63, task 91 round 5): the composition's bounds follow the prototype's fieldFrame.
  func testCompositionBoundsFollowThePrototypeFrame() {
    XCTAssertEqual(CockpitFieldPanel.frame(in: NSRect(x: 0, y: 0, width: 1470, height: 919)),
                   NSRect(x: 73.5, y: 92, width: 1323, height: 735), "a 14-inch laptop: 90% wide, 80% high")
    XCTAssertEqual(CockpitFieldPanel.frame(in: NSRect(x: 0, y: 0, width: 1024, height: 743)),
                   NSRect(x: 32, y: 71.5, width: 960, height: 600), "the 960 x 600 floor")
    XCTAssertEqual(CockpitFieldPanel.frame(in: NSRect(x: 0, y: 0, width: 900, height: 600)),
                   NSRect(x: 16, y: 16, width: 868, height: 568), "16 pt from every edge on a tiny screen")
    XCTAssertEqual(CockpitFieldPanel.frame(in: NSRect(x: 2000, y: 25, width: 2560, height: 1415)).size,
                   NSSize(width: 1440, height: 900))
  }
  /// CKP-PORT-11 in the native panel: the frosted card blurs the desktop. A transparent web view cannot do that with
  /// CSS, so the page reports its card and the panel puts a behind-window blur exactly there; junk is ignored.
  @MainActor func testTheFrostedCardBlursTheDesktopWhereThePageSaysItIs() throws {
    XCTAssertEqual(CockpitFieldPanel.cardFrame(x: 0, y: 35.5, width: 430, height: 664, in: NSRect(x: 0, y: 0, width: 1323, height: 735)),
                   NSRect(x: 0, y: 35.5, width: 430, height: 664), "top-left page coordinates become bottom-left points")
    XCTAssertEqual(CockpitFieldPanel.cardFrame(x: 0, y: 20, width: 430, height: 600, in: NSRect(x: 0, y: 0, width: 960, height: 700)),
                   NSRect(x: 0, y: 80, width: 430, height: 600))
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("field-card-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let panel = CockpitFieldPanel(bundle: try bundle(root))
    panel.open(payload: "{}", near: nil)
    defer { panel.close() }
    XCTAssertNil(panel.cardBlurFrame, "no blur before the page has laid out its card")
    panel.receive(#"{"type":"card","x":"left","y":0,"width":430,"height":664}"#)
    XCTAssertNil(panel.cardBlurFrame, "a malformed rect is ignored")
    panel.receive(#"{"type":"card","x":0,"y":20,"width":430,"height":500,"radius":12}"#)
    let frame = try XCTUnwrap(panel.cardBlurFrame)
    XCTAssertEqual(frame.size, NSSize(width: 430, height: 500))
    XCTAssertEqual(frame.minX, 0)
  }

  // MARK: Build 14c, G3-77: placement, moving and refitting across displays

  private let screenA = CockpitScreen(frame: NSRect(x: 0, y: 0, width: 1512, height: 982), visibleFrame: NSRect(x: 0, y: 0, width: 1512, height: 949))
  private let screenB = CockpitScreen(frame: NSRect(x: 1512, y: 0, width: 2560, height: 1440), visibleFrame: NSRect(x: 1512, y: 0, width: 2560, height: 1415))
  private func assertInside(_ frame: NSRect, _ visible: NSRect, margin: CGFloat = 16, _ message: String,
                            file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(visible.insetBy(dx: margin, dy: margin).contains(frame),
                  "\(message): \(NSStringFromRect(frame)) is not \(margin) pt inside \(NSStringFromRect(visible))", file: file, line: line)
  }
  /// The size rule (90% wide within 960-1440, 80% high within 600-900) on common visible frames, wherever the display
  /// sits in the arrangement, always at least 16 pt inside.
  func testTheSizeRuleStaysSixteenPointsInsideCommonDisplays() {
    let cases: [(NSRect, NSSize)] = [
      (NSRect(x: 0, y: 0, width: 1280, height: 800), NSSize(width: 1152, height: 640)),
      (NSRect(x: -1512, y: 0, width: 1512, height: 982), NSSize(width: 1361, height: 786)),
      (NSRect(x: 1280, y: 25, width: 2560, height: 1440), NSSize(width: 1440, height: 900)),
    ]
    for (visible, size) in cases {
      let frame = CockpitFieldPanel.frame(in: visible)
      XCTAssertEqual(frame.size, size, NSStringFromRect(visible))
      assertInside(frame, visible, "centred")
      for corner in [CGPoint(x: visible.minX, y: visible.minY), CGPoint(x: visible.maxX, y: visible.maxY), CGPoint(x: visible.minX - 500, y: visible.maxY + 500)] {
        let kept = CockpitFieldPanel.frame(in: visible, centredAt: corner)
        XCTAssertEqual(kept.size, size)
        assertInside(kept, visible, "centred toward \(corner)")
      }
    }
  }
  func testTheDragStripSitsAboveTheCardAndClearOfTheCloseKey() {
    let bounds = NSRect(x: 0, y: 0, width: 1323, height: 735)
    let card = CockpitFieldPanel.cardFrame(x: 0, y: 35.5, width: 430, height: 664, in: bounds)
    let strip = CockpitFieldPanel.dragStripFrame(card: card, in: bounds)
    XCTAssertEqual(strip, NSRect(x: 0, y: card.maxY, width: 430, height: 20), "the bare band above the card")
    // The page's × is at left 438 px, top card-top - 8 px: right of the card, never under the strip.
    let close = NSRect(x: 438, y: bounds.height - (35.5 - 8) - 24, width: 24, height: 24)
    XCTAssertFalse(strip.intersects(close))
    XCTAssertEqual(CockpitFieldPanel.dragStripFrame(card: NSRect(x: 0, y: 0, width: 430, height: 731), in: bounds), .zero, "no room, no strip")
  }
  /// The owner's 14c report: the field opened on the menu bar icon's display and could not be moved.
  @MainActor func testTheFieldOpensOnTheClickDisplayAndMovesToAnotherDisplay() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("field-move-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let panel = CockpitFieldPanel(bundle: try bundle(root))
    let displays = [screenA, screenB]
    panel.screens = { displays }
    panel.open(payload: "{}", near: NSRect(x: 1100, y: 949, width: 28, height: 24), at: CGPoint(x: 2800, y: 700))
    defer { panel.close() }
    let window = try XCTUnwrap(panel.verificationWindow)
    XCTAssertTrue(window.isMovable)
    XCTAssertEqual(window.frame, CockpitFieldPanel.frame(in: screenB.visibleFrame), "opens on the click's display B, not the icon's A")
    XCTAssertNil(panel.dragRegionFrame, "no strip before the page has laid out its card")
    let height = window.frame.height
    panel.receive(#"{"type":"card","x":0,"y":118,"width":430,"height":664,"radius":12}"#)
    let strip = try XCTUnwrap(panel.dragRegionFrame)
    XCTAssertEqual(strip.minY, height - 118, accuracy: 0.5, "the strip starts at the card's top edge")
    let from = CGPoint(x: window.frame.minX + 200, y: window.frame.maxY - 108)
    panel.drag(.began, point: from)
    panel.drag(.moved, point: CGPoint(x: from.x + 1, y: from.y))
    XCTAssertEqual(window.frame, CockpitFieldPanel.frame(in: screenB.visibleFrame), "under 3 pt nothing moves")
    panel.drag(.moved, point: CGPoint(x: 600, y: 500))
    panel.drag(.ended, point: CGPoint(x: 600, y: 500))
    XCTAssertTrue(panel.isOpen, "a drag does not close the field")
    assertInside(window.frame, screenA.visibleFrame, "dropped on A")
    XCTAssertEqual(window.frame.size, CockpitFieldPanel.frame(in: screenA.visibleFrame).size, "refitted to A's size rule")
  }
  /// A press on the strip that never moves is a click on bare desktop: it closes the field, as the page does.
  @MainActor func testAClickOnTheStripClosesLikeBareDesktop() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("field-strip-click-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let panel = CockpitFieldPanel(bundle: try bundle(root))
    let displays = [screenA]
    panel.screens = { displays }
    var closed = 0
    panel.onClosed = { closed += 1 }
    panel.open(payload: "{}", near: nil)
    let point = CGPoint(x: 700, y: 800)
    panel.drag(.began, point: point)
    panel.drag(.ended, point: point)
    XCTAssertFalse(panel.isOpen)
    XCTAssertEqual(closed, 1)
  }
  /// Unplugging the display the field is on, or the field landing on another display, refits it there.
  @MainActor func testADisplayChangeRefitsTheFieldOnTheDisplayItIsOn() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("field-refit-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let panel = CockpitFieldPanel(bundle: try bundle(root))
    var displays = [screenA, screenB]
    panel.screens = { displays }
    panel.open(payload: "{}", near: nil, at: CGPoint(x: 2800, y: 700))
    defer { panel.close() }
    let window = try XCTUnwrap(panel.verificationWindow)
    XCTAssertEqual(window.frame.size, NSSize(width: 1440, height: 900), "B's size rule")
    displays = [screenA]
    NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
    for _ in 0..<50 where !screenA.visibleFrame.insetBy(dx: 16, dy: 16).contains(window.frame) {
      try await Task.sleep(for: .milliseconds(20))
    }
    assertInside(window.frame, screenA.visibleFrame, "B unplugged: back on A")
    XCTAssertEqual(window.frame.size, CockpitFieldPanel.frame(in: screenA.visibleFrame).size)
    // Moved onto another display without a drag: the window's screen changes and the size rule follows.
    displays = [screenA, screenB]
    window.setFrame(NSRect(x: 2000, y: 300, width: window.frame.width, height: window.frame.height), display: false)
    panel.windowDidChangeScreen(Notification(name: NSWindow.didChangeScreenNotification))
    assertInside(window.frame, screenB.visibleFrame, "now on B")
    XCTAssertEqual(window.frame.size, NSSize(width: 1440, height: 900), "B's size rule again")
  }
}
