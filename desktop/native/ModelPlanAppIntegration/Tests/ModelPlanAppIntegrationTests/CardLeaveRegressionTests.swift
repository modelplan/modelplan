// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanDock

@MainActor final class CardLeaveRegressionTests: XCTestCase {
    func testHoverPreviewLeavesAfterPointerLeavesWidgetAndCard() throws {
        var state = DockCardInteraction()
        try state.step(catalogue: ["synthetic"], hoveredID: "synthetic", insideShared: true, parentOwnsHide: true, parentExpanded: true, menuActuallyOpen: false, at: 0)
        try state.step(catalogue: ["synthetic"], hoveredID: "synthetic", insideShared: true, parentOwnsHide: true, parentExpanded: true, menuActuallyOpen: false, at: 0.25)
        XCTAssertEqual(state.visibility, .hover("synthetic"), "Dwell opens an unpinned preview")
        try state.step(catalogue: ["synthetic"], hoveredID: nil, insideShared: true, parentOwnsHide: true, parentExpanded: true, menuActuallyOpen: false, at: 0.30)
        XCTAssertEqual(state.visibility, .hover("synthetic"), "Moving into the card keeps it open")
        try state.step(catalogue: ["synthetic"], hoveredID: nil, insideShared: false, parentOwnsHide: true, parentExpanded: true, menuActuallyOpen: false, at: 0.40)
        XCTAssertEqual(state.visibility, .hover("synthetic"))
        try state.step(catalogue: ["synthetic"], hoveredID: nil, insideShared: false, parentOwnsHide: true, parentExpanded: true, menuActuallyOpen: false, at: 0.66)
        XCTAssertEqual(state.visibility, .hidden, "A non-pinned card closes after its own leave grace even when the widget remains open")
    }
    func testOrdinaryCardShowsLocalizedActionsWithoutWindow() throws {
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        for (enter, close) in [("Settings", "Close"), ("设置", "关闭")] {
            let card = DockCardView(frame: .zero)
            try card.apply(.init(subscriptionID: "synthetic", revision: 1, name: "Synthetic", rows: [], enterLabel: enter, dismissLabel: close))
            let buttons = descendants(card).compactMap { $0 as? NSButton }
            XCTAssertTrue(buttons.contains { $0.title == enter }, "The ordinary card must offer its contextual action")
            XCTAssertTrue(buttons.contains { $0.title == close }, "The ordinary card must offer close")
            XCTAssertFalse(buttons.contains { $0.accessibilityIdentifier() == "dock.card.pin" }, "Pinning uses the card body, not an extra visible button")
            XCTAssertNil(card.window)
            card.dispose()
        }
    }

}
