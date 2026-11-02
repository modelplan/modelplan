// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanDock

@MainActor final class CardLeaveRegressionTests: XCTestCase {
    func testOrdinaryClickLeavesAfterPointerLeavesWidgetAndCard() throws {
        var state = DockCardInteraction()
        try state.step(catalogue: ["synthetic"], hoveredID: nil, insideShared: true, parentOwnsHide: true, parentExpanded: true, menuActuallyOpen: false, at: 0)
        try state.click("synthetic", at: 0.01)
        XCTAssertEqual(state.visibility, .hover("synthetic"), "An ordinary click must not silently pin the card")
        try state.step(catalogue: ["synthetic"], hoveredID: nil, insideShared: true, parentOwnsHide: true, parentExpanded: true, menuActuallyOpen: false, at: 0.10)
        XCTAssertEqual(state.visibility, .hover("synthetic"), "Moving into the card keeps it open")
        try state.step(catalogue: ["synthetic"], hoveredID: nil, insideShared: false, parentOwnsHide: true, parentExpanded: true, menuActuallyOpen: false, at: 0.20)
        XCTAssertEqual(state.visibility, .hover("synthetic"))
        try state.step(catalogue: ["synthetic"], hoveredID: nil, insideShared: false, parentOwnsHide: true, parentExpanded: true, menuActuallyOpen: false, at: 0.46)
        XCTAssertEqual(state.visibility, .hidden, "A non-pinned card closes after its own leave grace even when the widget remains open")
    }
    func testOrdinaryCardShowsLocalizedActionsWithoutWindow() throws {
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        for (enter, close) in [("Settings", "Close"), ("设置", "关闭")] {
            let card = DockCardView(frame: .zero)
            try card.apply(.init(subscriptionID: "synthetic", revision: 1, name: "Synthetic", rows: [], enterLabel: enter, dismissLabel: close), pinned: false)
            let buttons = descendants(card).compactMap { $0 as? NSButton }
            XCTAssertTrue(buttons.contains { $0.title == enter }, "The ordinary card must offer its contextual action")
            XCTAssertTrue(buttons.contains { $0.title == close }, "The ordinary card must offer close")
            XCTAssertFalse(buttons.contains { $0.accessibilityIdentifier() == "dock.card.pin" }, "Pinning uses the card body, not an extra visible button")
            XCTAssertNil(card.window)
            card.dispose()
        }
    }
    func testCardBodyAccessiblePressPinsCurrentContentOnly() throws {
        let card = DockCardView(frame: .zero)
        var pins = 0
        card.onPin = { pins += 1 }
        card.permitsAction = { _, revision in revision == 2 }
        try card.apply(.init(subscriptionID: "synthetic", revision: 2, name: "Synthetic", rows: []), pinned: false, pinAccessibilityHelp: "Press to pin card")
        XCTAssertTrue(card.accessibilityPerformPress())
        XCTAssertEqual(pins, 1)
        card.permitsAction = { _, _ in false }
        XCTAssertFalse(card.accessibilityPerformPress(), "Stale or withdrawn content cannot pin")
        XCTAssertEqual(pins, 1)
        card.dispose()
    }

}
