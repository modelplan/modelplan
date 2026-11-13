// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanCockpitWeb

/// The expanded cockpit's drag area: open hand on hover, closed hand while dragging, and no grip drawn
/// at any time (D227, G3-99). A view only: no window or page.
@MainActor final class CockpitTitleDragHoverTests: XCTestCase {
  private func view() -> CockpitTitleDrag { CockpitTitleDrag(frame: NSRect(x: 0, y: 0, width: 390, height: 28)) }
  private func enter(_ type: NSEvent.EventType) throws -> NSEvent {
    try XCTUnwrap(NSEvent.enterExitEvent(with: type, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, trackingNumber: 0, userData: nil))
  }
  private func click(_ type: NSEvent.EventType) throws -> NSEvent {
    try XCTUnwrap(NSEvent.mouseEvent(with: type, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
  }
  /// Whether the strip paints any pixel: it is rendered into a clear bitmap and every alpha is read.
  private func paintsAnything(_ drag: CockpitTitleDrag) throws -> Bool {
    let rep = try XCTUnwrap(drag.bitmapImageRepForCachingDisplay(in: drag.bounds))
    drag.cacheDisplay(in: drag.bounds, to: rep)
    let data = try XCTUnwrap(rep.bitmapData), count = rep.bytesPerRow * rep.pixelsHigh
    return (0..<count).contains { data[$0] != 0 }
  }
  /// D227 (owner 2026-11-12, G3-99): no grip dots at all, without hover, on hover or while dragging.
  func testNoGripIsDrawnOnHoverOrWhileDraggingAndTheCursorStillShowsTheHand() throws {
    let drag = view()
    XCTAssertFalse(try paintsAnything(drag)); XCTAssertTrue(drag.currentCursor === NSCursor.openHand)
    drag.mouseEntered(with: try enter(.mouseEntered))
    XCTAssertTrue(drag.isHovered); XCTAssertTrue(drag.currentCursor === NSCursor.openHand)
    XCTAssertFalse(try paintsAnything(drag), "hover draws no grip")
    drag.mouseDown(with: try click(.leftMouseDown))
    XCTAssertTrue(drag.currentCursor === NSCursor.closedHand)
    XCTAssertFalse(try paintsAnything(drag), "dragging draws no grip")
    drag.mouseUp(with: try click(.leftMouseUp))
    XCTAssertTrue(drag.currentCursor === NSCursor.openHand)
    drag.mouseExited(with: try enter(.mouseExited))
    XCTAssertFalse(drag.isHovered)
  }
  /// Without the grip the strip still drives the drag: press, move and release reach the window controller.
  func testDraggingTheStripStillReportsEveryPhase() throws {
    let drag = view(); var phases: [CockpitTitleDrag.Phase] = []
    drag.event = { phase, _ in phases.append(phase) }
    drag.mouseDown(with: try click(.leftMouseDown))
    drag.mouseDragged(with: try click(.leftMouseDragged))
    drag.mouseUp(with: try click(.leftMouseUp))
    XCTAssertEqual(phases, [.began, .moved, .ended])
  }
  func testRightClickOnTheStripReachesTheContextMenu() throws {
    let drag = view(); var asked = 0
    drag.contextMenu = { _ in asked += 1 }
    drag.rightMouseDown(with: try click(.rightMouseDown))
    XCTAssertEqual(asked, 1)
  }
}
