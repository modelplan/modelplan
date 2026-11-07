// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanDock

/// G3-14: the widget holds a card open for a keyboard-focused ring, so a click must not focus one.
/// The click goes through the application's event queue, because that is where AppKit makes
/// the clicked view first responder and where the view can tell a click from the keyboard.
@MainActor final class DockClickFocusTests: XCTestCase {
    private func mountedView() throws -> (NSWindow, DockInstrumentView) {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: CGRect(x: 210, y: 320, width: 400, height: 500), styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        addTeardownBlock { @MainActor in window.close() }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let view = DockInstrumentView(frame: .zero)
        try view.applyCommunity(["first", "second"].map { id in
            try DockInstrumentProjection.evaluate(DockInstrumentInput(id: id, name: id, windows: [
                DockQuotaWindowInput(id: "short", period: .fiveHour, label: "5h", remainingPercent: 40,
                                     resetsAt: now.addingTimeInterval(9000), durationSeconds: 18000),
            ]), now: now)
        })
        // Order in first: a window coming on screen picks a first responder of its own.
        window.orderFrontRegardless()
        view.keyboardNavigationEnabled = true
        try XCTUnwrap(window.contentView).addSubview(view)
        return (window, view)
    }

    func testAClickDoesNotPickAKeyboardRing() throws {
        let (window, view) = try mountedView()
        XCTAssertFalse(window.firstResponder === view, "only the click may make it first responder here")
        let row = try XCTUnwrap(view.interactionAnchor("second"))
        let point = view.convert(CGPoint(x: row.midX, y: row.midY), to: nil)
        for (type, pressure) in [(NSEvent.EventType.leftMouseDown, Float(1)), (.leftMouseUp, 0)] {
            NSApp.postEvent(try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: 0,
                windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: pressure)), atStart: false)
            NSApp.sendEvent(try XCTUnwrap(NSApp.nextEvent(matching: .any, until: .distantFuture, inMode: .default, dequeue: true)))
        }
        XCTAssertTrue(window.firstResponder === view, "AppKit still makes the clicked view first responder")
        XCTAssertNil(view.keyboardTargetID)
    }

    func testKeyboardFocusStillPicksTheFirstRing() throws {
        let (window, view) = try mountedView()
        XCTAssertTrue(window.makeFirstResponder(view))
        XCTAssertEqual(view.keyboardTargetID, "first")
    }
}
