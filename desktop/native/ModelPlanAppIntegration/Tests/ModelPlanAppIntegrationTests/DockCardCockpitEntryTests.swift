// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
@testable import ModelPlanAppIntegration

/// D371 B4e (owner 11-21, option A): every Dock card (subscription, Resources, Calendar) ends in one full-width footer row
/// under a hairline: the glyph, "在驾驶舱查看", the target's name in grey and "›". The whole row is the button and lights on
/// hover. Fails before: the card had no such row (a plugin card had a pill button, a subscription card nothing).
@MainActor final class DockCardCockpitEntryTests: XCTestCase {
    private func content(label: String = "在驾驶舱查看", target: String = "Codex") -> DockCardContent {
        DockCardContent(subscriptionID: "0123456789abcdef", name: "Codex Pro 100", plan: "", sourceAndAge: "4 分钟前",
                        rows: [DockCardRow(id: "q", kind: .quota, label: "每周", value: "0%", fillFraction: .some(0), tone: .critical)],
                        cockpitLabel: label, cockpitTarget: target)
    }

    func testTheFooterRowIsFullWidthBelowTheRowsAndTheWholeRowPresses() throws {
        let card = DockCardView(frame: .zero)
        var opened: [String] = []
        card.onOpenCockpit = { opened.append($0) }
        let glyph = NSImage(size: CGSize(width: 16, height: 16))
        try card.apply(content(), style: DockCardStyle(), cockpitGlyph: glyph)
        let row = try XCTUnwrap(card.cockpitRowFrameForChecks, "the card has the footer row")
        XCTAssertEqual(row.minX, 8, accuracy: 0.5, "it reaches 4 pt past the text margin")
        XCTAssertEqual(row.width, card.frame.width - 16, accuracy: 0.5, "full width")
        XCTAssertEqual(row.height, 30, accuracy: 0.5)
        XCTAssertEqual(row.maxY, card.frame.height - 4, accuracy: 0.5, "it closes the card")
        XCTAssertGreaterThan(row.minY, 40, "below the rows, not in the header")
        XCTAssertEqual(card.cockpitRowLabelForChecks, "在驾驶舱查看 Codex")
        let parts = try XCTUnwrap(card.cockpitRowPartsForChecks)
        XCTAssertLessThan(parts.glyph.maxX, parts.title.minX, "glyph, then the label")
        XCTAssertLessThan(parts.title.maxX, parts.target.minX, "then the target name")
        XCTAssertLessThan(parts.target.maxX, parts.chevron.minX + 0.5, "then the chevron at the right")
        XCTAssertEqual(parts.chevron.maxX, row.width - 8, accuracy: 1, "the chevron sits at the row's right edge")
        // Hover lights the whole row; a press (pointer, Return or VoiceOver reach the same path) reports the card's ID.
        XCTAssertTrue(card.pressCockpitRowForChecks())
        XCTAssertEqual(opened, ["0123456789abcdef"])
        XCTAssertFalse(card.cockpitRowHoveredForChecks)
        card.hoverCockpitRowForChecks(true)
        XCTAssertTrue(card.cockpitRowHoveredForChecks, "the whole row highlights on hover")
    }

    func testNoLabelNoRowAndARefreshedCardKeepsOneRow() throws {
        let card = DockCardView(frame: .zero)
        try card.apply(content(label: ""), style: DockCardStyle())
        XCTAssertNil(card.cockpitRowFrameForChecks, "no label, no row")
        let without = card.frame.height
        try card.apply(content(), style: DockCardStyle())
        XCTAssertNotNil(card.cockpitRowFrameForChecks)
        XCTAssertGreaterThan(card.frame.height, without, "the row adds height")
        try card.apply(content(target: "Codex Pro 100"), style: DockCardStyle())
        XCTAssertEqual(card.subviews.filter { $0.accessibilityIdentifier() == "dock.card.cockpit" }.count, 1, "refreshing replaces, never stacks")
        XCTAssertEqual(card.cockpitRowLabelForChecks, "在驾驶舱查看 Codex Pro 100")
        try card.apply(content(label: ""), style: DockCardStyle())
        XCTAssertNil(card.cockpitRowFrameForChecks)
        XCTAssertTrue(card.subviews.allSatisfy { $0.accessibilityIdentifier() != "dock.card.cockpit" }, "the row is removed with its label")
    }

    /// One replaceable asset: the glyph is the menu-bar icon, named in exactly one place.
    func testTheGlyphIsTheMenuBarIconInOnePlace() {
        let glyph = CockpitEntryGlyph.image
        let menu = CommunityMenuBarResources.statusImage()
        XCTAssertNotNil(glyph)
        XCTAssertEqual(glyph?.size, menu?.size)
        XCTAssertEqual(glyph?.isTemplate, true)
    }
}
