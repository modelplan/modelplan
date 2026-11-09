// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanAppIntegration

/// D56 Find Quota Widget, the native overlay (GUI leg): one click-through window over the widget's
/// whole display, above the menu bar, on the current Space including a full-screen one; it never
/// becomes key, never takes a mouse event, and leaves a feathered hole over the widget.
@MainActor final class FindQuotaWidgetWindowTests: XCTestCase {
    private func target() throws -> QuotaWidgetSpotlightTarget {
        _ = NSApplication.shared
        let screen = try XCTUnwrap(NSScreen.screens.first, "a display is needed")
        let frame = screen.frame
        let widget = CGRect(x: frame.maxX - 70, y: frame.midY - 160, width: 64, height: 320)
        return .init(widget: widget, display: frame, displayID: "main")
    }

    func testD56OverlayIgnoresMouseEventsAndCoversTheWidgetsWholeDisplay() throws {
        let target = try target()
        let surface = QuotaWidgetSpotlightWindowSurface()
        surface.show(target, fadeIn: 0)
        defer { surface.hide(fadeOut: 0) }
        let window = try XCTUnwrap(surface.window)
        XCTAssertTrue(window.isVisible)
        XCTAssertTrue(window.ignoresMouseEvents, "the overlay never takes mouse events")
        XCTAssertFalse(window.canBecomeKey); XCTAssertFalse(window.canBecomeMain)
        XCTAssertEqual(window.frame, target.display, "the whole display, menu bar included")
        XCTAssertGreaterThan(window.level.rawValue, NSWindow.Level.statusBar.rawValue, "dims the menu bar and its items too")
        XCTAssertTrue(window.collectionBehavior.contains(.fullScreenAuxiliary), "works over a full-screen app")
        XCTAssertTrue(window.collectionBehavior.contains(.canJoinAllSpaces), "on the current Space")
        XCTAssertTrue(window.collectionBehavior.contains(.ignoresCycle))
        XCTAssertEqual(window.alphaValue, 1, "Reduce Motion: dims at once")
        let view = try XCTUnwrap(window.contentView as? QuotaWidgetSpotlightView)
        XCTAssertNil(view.hitTest(NSPoint(x: 10, y: 10)))
        XCTAssertEqual(view.dimAlphaForChecks, QuotaWidgetSpotlightStyle.dimAlpha, accuracy: 0.001)
        XCTAssertEqual(view.hole, QuotaWidgetSpotlightStyle.hole(for: target).offsetBy(dx: -target.display.minX, dy: -target.display.minY))
        surface.hide(fadeOut: 0)
        XCTAssertFalse(window.isVisible, "restores at once")
    }

    func testD56OverlayFadesInAndOutWhenMotionIsAllowed() async throws {
        let target = try target()
        let surface = QuotaWidgetSpotlightWindowSurface()
        surface.show(target, fadeIn: 0.2)
        let window = try XCTUnwrap(surface.window)
        XCTAssertTrue(window.isVisible)
        XCTAssertLessThan(window.alphaValue, 1, "starts transparent and fades in")
        try await Task.sleep(for: .milliseconds(450))
        XCTAssertEqual(window.alphaValue, 1, accuracy: 0.01)
        surface.hide(fadeOut: 0.3)
        let end = ContinuousClock.now + .seconds(2)
        while window.isVisible && ContinuousClock.now < end { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertFalse(window.isVisible, "ordered out once the fade ends")
    }
}
