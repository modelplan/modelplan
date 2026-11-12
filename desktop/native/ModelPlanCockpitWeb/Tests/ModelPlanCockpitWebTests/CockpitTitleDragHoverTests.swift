// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanCockpitWeb

/// The expanded cockpit's drag area: open hand and a faint grip on hover, closed hand while dragging,
/// nothing without hover. A view only: no window or page.
@MainActor final class CockpitTitleDragHoverTests: XCTestCase {
  private func view() -> CockpitTitleDrag { CockpitTitleDrag(frame: NSRect(x: 0, y: 0, width: 390, height: 28)) }
  private func enter(_ type: NSEvent.EventType) throws -> NSEvent {
    try XCTUnwrap(NSEvent.enterExitEvent(with: type, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, trackingNumber: 0, userData: nil))
  }
  private func click(_ type: NSEvent.EventType) throws -> NSEvent {
    try XCTUnwrap(NSEvent.mouseEvent(with: type, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
  }
  func testNothingShowsWithoutHoverThenAnOpenHandAndGripAppear() throws {
    let drag = view()
    XCTAssertFalse(drag.showsGrip); XCTAssertFalse(drag.isHovered)
    XCTAssertTrue(drag.currentCursor === NSCursor.openHand)
    drag.mouseEntered(with: try enter(.mouseEntered))
    XCTAssertTrue(drag.showsGrip); XCTAssertTrue(drag.currentCursor === NSCursor.openHand)
    drag.mouseExited(with: try enter(.mouseExited))
    XCTAssertFalse(drag.showsGrip, "the grip goes away when the pointer leaves")
  }
  func testClosedHandAndGripWhileDraggingThenBackToOpenHand() throws {
    let drag = view(); var phases: [CockpitTitleDrag.Phase] = []
    drag.event = { phase, _ in phases.append(phase) }
    drag.mouseDown(with: try click(.leftMouseDown))
    XCTAssertTrue(drag.currentCursor === NSCursor.closedHand); XCTAssertTrue(drag.showsGrip)
    drag.mouseUp(with: try click(.leftMouseUp))
    XCTAssertTrue(drag.currentCursor === NSCursor.openHand); XCTAssertFalse(drag.showsGrip)
    XCTAssertEqual(phases, [.began, .ended])
  }
  func testRightClickOnTheStripReachesTheContextMenu() throws {
    let drag = view(); var asked = 0
    drag.contextMenu = { _ in asked += 1 }
    drag.rightMouseDown(with: try click(.rightMouseDown))
    XCTAssertEqual(asked, 1)
  }
}
