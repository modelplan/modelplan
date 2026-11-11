// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanDock

/// G3-14: the widget holds a card open for a keyboard-focused ring, so a click must not focus one.
/// The click goes through the application's event queue, because that is where AppKit makes
/// the clicked view first responder and where the view can tell a click from the keyboard.
/// A borderless window that can be key: a key window makes the clicked view first responder
/// whatever state earlier tests left the application in.
@MainActor private final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

@MainActor final class DockClickFocusTests: XCTestCase {
    private func mountedView() throws -> (NSWindow, DockInstrumentView) {
        _ = NSApplication.shared
        let window = KeyableWindow(contentRect: CGRect(x: 210, y: 320, width: 400, height: 500), styleMask: [.borderless],
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
        window.makeKeyAndOrderFront(nil)
        view.keyboardNavigationEnabled = true
        try XCTUnwrap(window.contentView).addSubview(view)
        return (window, view)
    }

    func testAClickDoesNotPickAKeyboardRing() throws {
        let (window, view) = try mountedView()
        XCTAssertFalse(window.firstResponder === view, "only the click may make it first responder here")
        let row = try XCTUnwrap(view.interactionAnchor("second"))
        let point = view.convert(CGPoint(x: row.midX, y: row.midY), to: nil)
        try click(at: point, in: window)
        XCTAssertTrue(window.firstResponder === view, "AppKit still makes the clicked view first responder")
        XCTAssertNil(view.keyboardTargetID)
    }

    /// Earlier tests in the same process can leave events queued, and reading back "any" event
    /// then delivered one of those instead of the click. Drop them, post the click, and read back
    /// only that event, so NSApp.currentEvent is the click when AppKit picks a first responder.
    private func click(at point: CGPoint, in window: NSWindow, file: StaticString = #filePath, line: UInt = #line) throws {
        while NSApp.nextEvent(matching: .any, until: .distantPast, inMode: .default, dequeue: true) != nil {}
        for (type, mask, pressure) in [(NSEvent.EventType.leftMouseDown, NSEvent.EventTypeMask.leftMouseDown, Float(1)),
                                       (.leftMouseUp, .leftMouseUp, 0)] {
            // AppKit renumbers posted events, so the click is recognised by its window and location.
            NSApp.postEvent(try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
                eventNumber: 0, clickCount: 1, pressure: pressure), file: file, line: line), atStart: true)
            let read = try XCTUnwrap(NSApp.nextEvent(matching: mask, until: Date(timeIntervalSinceNow: 2), inMode: .default, dequeue: true),
                                     "the posted \(type) never came back", file: file, line: line)
            XCTAssertEqual(read.windowNumber, window.windowNumber, "another \(type) was read instead of the click", file: file, line: line)
            XCTAssertEqual(read.locationInWindow, point, "another \(type) was read instead of the click", file: file, line: line)
            NSApp.sendEvent(read)
            XCTAssertTrue(NSApp.currentEvent === read, "AppKit's current event is the click it delivered", file: file, line: line)
        }
    }

    func testKeyboardFocusStillPicksTheFirstRing() throws {
        let (window, view) = try mountedView()
        XCTAssertTrue(window.makeFirstResponder(view))
        XCTAssertEqual(view.keyboardTargetID, "first")
    }
}
