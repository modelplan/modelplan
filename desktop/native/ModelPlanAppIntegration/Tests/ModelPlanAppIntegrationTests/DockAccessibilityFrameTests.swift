// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanDock

/// The frame VoiceOver draws and hit-tests must be the frame the view paints, in screen space.
/// DockInstrumentView is flipped and AppKit's parent space is not.
@MainActor final class DockAccessibilityFrameTests: XCTestCase {
    private let ids = ["top", "middle", "bottom"]

    private func mountedView() throws -> (NSWindow, DockInstrumentView) {
        let window = NSWindow(contentRect: CGRect(x: 210, y: 320, width: 400, height: 500), styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        addTeardownBlock { @MainActor in window.close() }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let view = DockInstrumentView(frame: .zero)
        try view.applyCommunity(ids.map { id in
            try DockInstrumentProjection.evaluate(DockInstrumentInput(id: id, name: id, windows: [
                DockQuotaWindowInput(id: "short", period: .fiveHour, label: "5h", remainingPercent: 40,
                                     resetsAt: now.addingTimeInterval(9000), durationSeconds: 18000),
            ]), now: now)
        })
        view.setFrameOrigin(CGPoint(x: 30, y: 70))
        try XCTUnwrap(window.contentView).addSubview(view)
        return (window, view)
    }

    private func node(_ id: String, in view: DockInstrumentView) throws -> NSAccessibilityElement {
        let nodes = (view.accessibilityChildren() ?? []).compactMap { $0 as? NSAccessibilityElement }
        return try XCTUnwrap(nodes.first { $0.accessibilityIdentifier() == "dock.subscription." + id })
    }

    private func assertFramesMatchPaint(_ window: NSWindow, _ view: DockInstrumentView,
                                        file: StaticString = #filePath, line: UInt = #line) throws {
        for id in ids {
            let painted = window.convertToScreen(view.convert(try XCTUnwrap(view.interactionAnchor(id)), to: nil))
            XCTAssertEqual(try node(id, in: view).accessibilityFrame(), painted, id, file: file, line: line)
        }
    }

    func testNodeFramesAreThePaintedFramesOnScreen() throws {
        let (window, view) = try mountedView()
        try assertFramesMatchPaint(window, view)
        let top = try node("top", in: view).accessibilityFrame(), bottom = try node("bottom", in: view).accessibilityFrame()
        XCTAssertGreaterThan(top.minY, bottom.minY, "the first row is the highest on screen, whose y grows upward")
    }

    func testHitTestAtAPaintedRowAnswersThatRow() throws {
        let (window, view) = try mountedView()
        for id in ids {
            let painted = window.convertToScreen(view.convert(try XCTUnwrap(view.interactionAnchor(id)), to: nil))
            let hit = view.accessibilityHitTest(CGPoint(x: painted.midX, y: painted.midY)) as? NSAccessibilityElement
            XCTAssertEqual(hit?.accessibilityIdentifier(), "dock.subscription." + id)
        }
    }

    func testFramesFollowAHeightChangeWithoutANewReading() throws {
        let (window, view) = try mountedView()
        view.setFrameSize(CGSize(width: view.frame.width, height: view.frame.height + 90))
        try assertFramesMatchPaint(window, view)
    }
}
