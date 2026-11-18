// SPDX-License-Identifier: MIT
import XCTest
import AppKit
import ModelPlanDock
import ModelPlanCockpitWeb
import ModelPlanSettings
@testable import ModelPlanAppIntegration

/// MENU-50 (WP-09): the status menu's grey total line, and the range words shared with the cockpit (V1-FINAL §0).
final class MenuRangeSummaryTests: XCTestCase {
    func testTokensUseKMBAndAreNeverTruncated() {
        XCTAssertEqual(MenuRangeSummary.tokens(0), "0")
        XCTAssertEqual(MenuRangeSummary.tokens(999), "999")
        XCTAssertEqual(MenuRangeSummary.tokens(45_300), "45.3k")
        XCTAssertEqual(MenuRangeSummary.tokens(33_900_000), "33.9M")
        XCTAssertEqual(MenuRangeSummary.tokens(212_000_000), "212M")
        XCTAssertEqual(MenuRangeSummary.tokens(788_400_000), "788M")
        XCTAssertEqual(MenuRangeSummary.tokens(1_200_000_000), "1.2B")
    }
    func testLineLeavesOutAMissingFigureAndIsAbsentWithNone() {
        XCTAssertEqual(MenuRangeSummary.line(tokens: 788_000_000, cost: "≈$383", language: .chinese), "全部订阅 ≈$383 · 788M")
        XCTAssertEqual(MenuRangeSummary.line(tokens: 788_000_000, cost: nil, language: .chinese), "全部订阅 · 788M")
        XCTAssertEqual(MenuRangeSummary.line(tokens: 788_000_000, cost: nil, language: .english), "All subscriptions · 788M")
        XCTAssertEqual(MenuRangeSummary.line(tokens: nil, cost: "≈$64", language: .english), "All subscriptions ≈$64")
        XCTAssertNil(MenuRangeSummary.line(tokens: nil, cost: nil, language: .english), "no figure, no line (never 0 or --)")
    }
    func testRangeWordsMatchTheCockpitKeys() {
        XCTAssertEqual(CockpitRange.allCases.map { EngineRowsText.range($0).value(.chinese) }, ["今天", "7天", "30天"])
        XCTAssertEqual(CockpitRange.allCases.map { EngineRowsText.range($0).value(.english) }, ["Today", "7d", "30d"])
        XCTAssertEqual(CockpitRange.allCases.map(\.rawValue), ["today", "7d", "30d"], "the page's range keys")
        XCTAssertEqual(EngineRowsText.subscriptionProblems(2).value(.chinese), "2 个订阅读不到 · 查看…")
    }
    /// MENU-52: switching an open menu to a range with no total must drop the old range's total.
    @MainActor func testOpenMenuTotalFollowsTheRangeAndClearsWhenItHasNoFigure() {
        let item = NSMenuItem(title: "全部订阅 · 788M", action: nil, keyEquivalent: "")
        MenuRangeSummary.apply(MenuRangeSummary.line(tokens: 212_000_000, cost: nil, language: .chinese), to: item)
        XCTAssertEqual(item.title, "全部订阅 · 212M"); XCTAssertFalse(item.isHidden)
        MenuRangeSummary.apply(MenuRangeSummary.line(tokens: nil, cost: nil, language: .chinese), to: item)
        XCTAssertTrue(item.isHidden); XCTAssertFalse(item.title.contains("212M"), "the old total must be gone")
        MenuRangeSummary.apply("全部订阅 · 1.2B", to: item)
        XCTAssertFalse(item.isHidden); XCTAssertEqual(item.title, "全部订阅 · 1.2B")
    }
    @MainActor func testMenuReplaceKeepsAHiddenTotalRowForAnOpenMenuToFill() {
        let menu = DockStatusMenu(labels: [:], handlers: [:])
        menu.replace(with: [.init(title: "", accessibilityID: "status.rangeTotal", hidden: true)])
        let item = menu.menu.items.first { $0.accessibilityIdentifier() == "status.rangeTotal" }
        XCTAssertNotNil(item); XCTAssertEqual(item?.isHidden, true)
    }
}
