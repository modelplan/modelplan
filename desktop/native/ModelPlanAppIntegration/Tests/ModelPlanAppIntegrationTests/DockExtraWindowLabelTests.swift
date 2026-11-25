// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanWire
@_spi(DockResourceChecks) import ModelPlanDock
@testable import ModelPlanAppIntegration

/// D417: the card's extra rows are named by what they are (MCP, Opus, Fable), never "Other", and the label shows in full.
@MainActor final class DockExtraWindowLabelTests: XCTestCase {
    func testExtraWindowRowsTakeTheEngineShortLabel() {
        let quota = EngineDockContentProvider.rowLabel
        XCTAssertEqual(quota(.monthly, "mcp", false, "MCP", false), "MCP", "the ZCode MCP allowance names itself")
        XCTAssertEqual(quota(.monthly, "mcp", false, "MCP", true), "MCP")
        XCTAssertEqual(quota(.weekly, "other", true, "Fable", true), "Fable", "a model-only weekly window names the model")
        XCTAssertEqual(quota(.weekly, "other", true, "Opus", false), "Opus")
        XCTAssertEqual(quota(.weekly, "weekly", false, "每周", false), "每周", "a general window keeps its role heading")
        XCTAssertEqual(quota(.session, "five_hour", false, "会话", true), "5h")
        XCTAssertEqual(quota(.other, "other", false, "其他限额", false), "其他", "only a truly unknown window stays generic")
        XCTAssertEqual(quota(.other, "other", false, "Other limit", true), "Other")
    }

    private func fields(in view: NSView) -> [NSTextField] {
        var found: [NSTextField] = []
        if let field = view as? NSTextField { found.append(field) }
        for sub in view.subviews { found += fields(in: sub) }
        return found
    }

    /// The label column is capped at the style's fixed first column; the widest names must fit inside it, unclipped.
    func testShortLabelsFitTheNarrowestLabelColumnUnclipped() throws {
        var style = DockCardStyle()
        style.width = 240
        let font: NSFont = style.readoutSmallFont ?? .monospacedSystemFont(ofSize: style.smallFontSize, weight: .regular)
        let names = ["MCP", "Opus", "Son", "Fable", "Flash", "Pro"]
        for name in names {
            XCTAssertLessThanOrEqual(name.count, 5)
            let width = ceil((name as NSString).size(withAttributes: [.font: font]).width)
            XCTAssertLessThanOrEqual(width, style.columns[0], "\(name) fits the label column")
        }
        let rows = names.enumerated().map { index, name in
            DockCardRow(id: "q\(index)", kind: .extraQuota, label: name, value: "40%", fillFraction: .some(0.4), tone: .unknown)
        }
        let card = DockCardView(frame: .zero)
        try card.apply(DockCardContent(subscriptionID: "0123456789abcdef", name: "Synthetic", plan: "", sourceAndAge: "", rows: rows), style: style)
        for name in names {
            let field = try XCTUnwrap(fields(in: card).first { $0.stringValue == name }, "\(name) is drawn")
            let natural = ceil((name as NSString).size(withAttributes: [.font: font]).width)
            XCTAssertGreaterThanOrEqual(field.frame.width + 0.5, natural, "\(name) is not clipped")
        }
        card.dispose()
    }
}
