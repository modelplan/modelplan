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

    /// Evidence and check: the overlay over a light and a dark desktop fill, and with Increase Contrast, with a
    /// stand-in widget in the hole; written to dock-visual/find-overlay (uploaded with the other dock-visual
    /// captures). The accent halo must read against the dimmed surroundings on both fills.
    func testD56WritesTheFeatheredOverlayOverLightAndDarkFills() throws {
        _ = NSApplication.shared
        let display = CGRect(x: 0, y: 0, width: 640, height: 480)
        let widget = CGRect(x: 540, y: 80, width: 64, height: 320)
        let target = QuotaWidgetSpotlightTarget(widget: widget, display: display, displayID: "capture")
        let hole = QuotaWidgetSpotlightStyle.hole(for: target)
        let root = ProcessInfo.processInfo.environment["RUNNER_TEMP"].map { URL(fileURLWithPath: $0, isDirectory: true) } ?? FileManager.default.temporaryDirectory
        let out = root.appendingPathComponent("dock-instrument-checks/dock-visual/find-overlay", isDirectory: true)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        func luma(_ bitmap: NSBitmapImageRep, x: CGFloat, y: CGFloat) -> CGFloat {
            let scale = CGFloat(bitmap.pixelsWide) / display.width
            let c = bitmap.colorAt(x: Int(x * scale), y: Int((display.height - y) * scale))?.usingColorSpace(.sRGB)
            return c.map { 0.2126 * $0.redComponent + 0.7152 * $0.greenComponent + 0.0722 * $0.blueComponent } ?? 0
        }
        /// Mean luminance of the halo band (2 to 12 pt outside the hole's left edge) and of the dimmed area beyond the feather.
        func bandAndSurround(_ bitmap: NSBitmapImageRep) -> (band: CGFloat, surround: CGFloat) {
            let y = hole.midY
            let band = (2...12).map { luma(bitmap, x: hole.minX - CGFloat($0), y: y) }
            let surround = (40...60).map { luma(bitmap, x: hole.minX - CGFloat($0), y: y) }
            return (band.reduce(0, +) / CGFloat(band.count), surround.reduce(0, +) / CGFloat(surround.count))
        }
        for (name, fill, dark, contrast) in [
            ("light-normal", NSColor(srgbRed: 0.93, green: 0.94, blue: 0.96, alpha: 1), false, false),
            ("dark-normal", NSColor(srgbRed: 0.12, green: 0.13, blue: 0.15, alpha: 1), true, false),
            ("dark-increase-contrast", NSColor(srgbRed: 0.12, green: 0.13, blue: 0.15, alpha: 1), true, true),
            ("light-increase-contrast", NSColor(srgbRed: 0.93, green: 0.94, blue: 0.96, alpha: 1), false, true),
        ] {
            let canvas = NSView(frame: display)
            canvas.wantsLayer = true
            canvas.layer?.backgroundColor = fill.cgColor
            let stand = NSView(frame: widget)
            stand.wantsLayer = true
            stand.layer?.backgroundColor = NSColor.systemOrange.cgColor
            stand.layer?.cornerRadius = 10
            canvas.addSubview(stand)
            let overlay = QuotaWidgetSpotlightView(frame: display)
            overlay.backdropIsDark = dark; overlay.increaseContrast = contrast
            overlay.hole = hole
            canvas.addSubview(overlay)
            let drawn = overlay.drawnForChecks
            XCTAssertFalse(drawn.hasStrokeOrBorder, "the halo is a glow, never a ring")
            XCTAssertFalse(drawn.hasShadow)
            let bitmap = try XCTUnwrap(canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds))
            canvas.cacheDisplay(in: canvas.bounds, to: bitmap)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: out.appendingPathComponent("find-overlay-\(name).png"))
            let (band, surround) = bandAndSurround(bitmap)
            if dark {
                // The dimmed dark desktop is about 0.07 luminance; the accent glow must lift the band clearly above it.
                XCTAssertGreaterThan(band - surround, 0.04, "\(name): the halo reads on a dark desktop (band \(band), around \(surround))")
            } else {
                // On a light desktop the glow tints rather than brightens: it must still differ clearly.
                XCTAssertGreaterThan(abs(band - surround), 0.02, "\(name): the halo is visible on a light desktop (band \(band), around \(surround))")
            }
        }
    }

    /// glm-780-1: the feather raster must land upright on the layer. The hole sits within 24 pt of the display top, so the
    /// feather region is clipped and not mirror-symmetric; a vertically mirrored image would show the dimmed far end of
    /// the ramp flush against the widget's lower edge.
    func testD56FeatherIsUprightWhenTheHoleIsClippedAtTheDisplayTop() throws {
        _ = NSApplication.shared
        let display = CGRect(x: 0, y: 0, width: 640, height: 480)
        let widget = CGRect(x: 280, y: 400, width: 80, height: 64)
        let hole = QuotaWidgetSpotlightStyle.hole(for: QuotaWidgetSpotlightTarget(widget: widget, display: display, displayID: "capture"))
        XCTAssertGreaterThan(hole.maxY, display.height - QuotaWidgetSpotlightStyle.featherRadius, "the feather region is clipped at the top")
        let canvas = NSView(frame: display)
        canvas.wantsLayer = true
        canvas.layer?.backgroundColor = NSColor(srgbRed: 0.8, green: 0.8, blue: 0.8, alpha: 1).cgColor
        let overlay = QuotaWidgetSpotlightView(frame: display)
        overlay.backdropIsDark = false
        overlay.hole = hole
        canvas.addSubview(overlay)
        let bitmap = try XCTUnwrap(canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds))
        canvas.cacheDisplay(in: canvas.bounds, to: bitmap)
        let scale = CGFloat(bitmap.pixelsWide) / display.width
        func luma(below d: CGFloat) -> CGFloat {
            let c = bitmap.colorAt(x: Int(hole.midX * scale), y: Int((display.height - (hole.minY - d)) * scale))?.usingColorSpace(.sRGB)
            return c.map { 0.2126 * $0.redComponent + 0.7152 * $0.greenComponent + 0.0722 * $0.blueComponent } ?? 0
        }
        XCTAssertGreaterThan(luma(below: 3), luma(below: 21) + 0.1, "near the widget the surface is nearly clear, further out it is dimmed (not mirrored)")
    }

    func testD56HaloIsAFeatherNotARing() {
        let peak = QuotaWidgetSpotlightStyle.haloPeak(dark: true, increaseContrast: false)
        XCTAssertEqual(peak, 0.35, accuracy: 0.001)
        XCTAssertLessThan(QuotaWidgetSpotlightStyle.haloPeak(dark: false, increaseContrast: false), peak, "weaker on light")
        XCTAssertGreaterThan(QuotaWidgetSpotlightStyle.haloPeak(dark: true, increaseContrast: true), peak, "Increase Contrast: a bit stronger")
        XCTAssertEqual(QuotaWidgetSpotlightStyle.haloAlpha(atDistance: 0, peak: peak), peak, accuracy: 0.001, "starts at the gap edge")
        XCTAssertEqual(QuotaWidgetSpotlightStyle.haloAlpha(atDistance: 20, peak: peak), 0, accuracy: 0.001, "gone after the 20 pt feather")
        XCTAssertEqual(QuotaWidgetSpotlightStyle.haloAlpha(atDistance: -6, peak: peak), 0, accuracy: 0.001, "no hard edge inside either")
        var last = peak
        for d in stride(from: CGFloat(0), through: 20, by: 1) {
            let a = QuotaWidgetSpotlightStyle.haloAlpha(atDistance: d, peak: peak)
            XCTAssertLessThanOrEqual(a, last + 0.0001); last = a
        }
    }
}
