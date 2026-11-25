// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
@testable import ModelPlanAppIntegration

/// The owner's bad case 01 against the r7 card: measurements are the prototype's own, taken from its rendered DOM.
/// Set MODELPLAN_CARD_RENDER_DIR to also write the card as a PNG for a side-by-side.
@MainActor final class QuotaWidgetCardPrototypeTests: XCTestCase {
    private func card(_ rows: [DockCardRow], name: String, plan: String = "Pro") throws -> DockCardView {
        let content = DockCardContent(subscriptionID: "codex", name: "Codex", plan: plan, sourceAndAge: "工具运行时 · 1分钟前", rows: rows)
        var style = StaticDockPreviewHost.prototypeCardStyle
        style.showsActions = false
        let view = DockCardView(frame: .zero)
        try view.apply(content, style: style)
        if let directory = ProcessInfo.processInfo.environment["MODELPLAN_CARD_RENDER_DIR"] {
            let scale: CGFloat = 2
            let rep = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(view.frame.width * scale), pixelsHigh: Int(view.frame.height * scale),
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
            rep.size = view.frame.size
            view.cacheDisplay(in: view.bounds, to: rep)
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            try XCTUnwrap(rep.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: directory).appendingPathComponent(name + ".png"))
        }
        return view
    }
    private let badCase: [DockCardRow] = [
        .init(id: "quota:weekly", kind: .quota, label: "每周", value: "3%", detail: "3d21h 后重置", remainingFraction: 0.03, tone: .critical, emphasised: true),
        .init(id: "reserve", kind: .reserve, label: "储备", value: "4,449 点数"),
        .init(id: "today", kind: .statistic, label: "今日", value: "1.2M · 64 t/s · 1 个运行中"),
    ]
    func testBadCaseMatchesThePrototypeGrid() throws {
        let view = try card(badCase, name: "train-card")
        XCTAssertEqual(view.frame.width, 304)
        let window = try XCTUnwrap(view.readoutWindowForChecks)
        XCTAssertEqual(window.minX, 11); XCTAssertEqual(window.minY, 50); XCTAssertEqual(window.width, 282); XCTAssertEqual(window.height, 75)
        XCTAssertEqual(view.frame.height - window.maxY, 10, "Only the plate padding: the owner removed the empty events band")
        let rows = try ["quota:weekly", "reserve", "today"].map { try XCTUnwrap(view.rowFrameForChecks($0)) }
        XCTAssertEqual(rows.map { $0.minY - window.minY }, [7, 28, 49])
        XCTAssertEqual(rows.map(\.height), [19, 19, 19])
        XCTAssertEqual(rows.map(\.minX), [18, 18, 18])
    }
    /// D388: the 33 pt header is the approved two-line reserve; a title that fits on one line (no plan line
    /// under the name) shrinks the header to that line, so the readout window starts higher.
    func testOneLineTitleShrinksTheHeaderToItsLine() throws {
        let view = try card(badCase, name: "train-card-one-line-header", plan: "")
        let window = try XCTUnwrap(view.readoutWindowForChecks)
        let name = try XCTUnwrap(view.nameFrameForChecks)
        XCTAssertEqual(window.minY, 10 + name.height + 7, accuracy: 0.5,
                       "plate padding + the title's own line + the header bottom gap, not the 33 pt reserve")
        XCTAssertLessThan(window.minY, 50, "the reserve (readout starting at 50) is kept only for a two-line title")
    }
    /// D388: the label and percent columns size to the card's own content, so the short 每周 / 储备 rows leave
    /// no reserved gap; the bar column keeps the approved 78 pt ten-segment width.
    func testLabelAndValueColumnsSizeToTheirContent() throws {
        let view = try card(badCase, name: "train-card-columns")
        let cells = view.rowCellsForChecks("quota:weekly")
        XCTAssertGreaterThanOrEqual(cells.count, 3)
        XCTAssertEqual(cells[1].width, 78, accuracy: 0.5, "the bar column keeps the approved width")
        XCTAssertEqual(cells[1].minX - cells[0].maxX, 5, accuracy: 0.5); XCTAssertEqual(cells[2].minX - cells[1].maxX, 5, accuracy: 0.5)
        func fields(_ v: NSView) -> [NSTextField] { ((v as? NSTextField).map { [$0] } ?? []) + v.subviews.flatMap(fields) }
        func textWidth(_ f: NSTextField) -> CGFloat { ceil(f.cell?.cellSize(forBounds: CGRect(x: 0, y: 0, width: 10_000, height: 10_000)).width ?? 0) }
        let labels = fields(view).filter { $0.accessibilityIdentifier().hasPrefix("dock.card.text.row.") && $0.accessibilityIdentifier().hasSuffix(".label") }
        let value = try XCTUnwrap(fields(view).first { $0.accessibilityIdentifier() == "dock.card.text.row.quota:weekly.value" })
        XCTAssertEqual(cells[0].width, min(labels.map(textWidth).max() ?? 0, 56), accuracy: 1.5, "the label column is the card's widest label (D388)")
        XCTAssertEqual(cells[2].width, min(textWidth(value), 34), accuracy: 1.5, "the percent column is the value's own width (D388)")
        XCTAssertLessThan(cells[0].width, 56, "short labels leave no reserved gap")
    }
    /// Digits and Latin must reach the pixels: an unregistered readout font left them blank.
    func testReadoutValuesAreActuallyDrawn() throws {
        let view = try card(badCase, name: "train-card-ink")
        let rep = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)
        func ink(_ rect: CGRect) -> Int {
            var count = 0
            for x in stride(from: Int(rect.minX), to: Int(rect.maxX), by: 1) { for y in stride(from: Int(rect.minY), to: Int(rect.maxY), by: 1) {
                let px = rep.colorAt(x: x * rep.pixelsWide / Int(view.bounds.width), y: y * rep.pixelsHigh / Int(view.bounds.height))?.usingColorSpace(.sRGB)
                if let px, max(px.redComponent, px.greenComponent, px.blueComponent) > 0.45 { count += 1 }
            } }
            return count
        }
        for (row, cell) in [("quota:weekly", 2), ("reserve", 1), ("today", 1)] {
            let cells = view.rowCellsForChecks(row)
            XCTAssertGreaterThan(cells.count, cell, row)
            XCTAssertGreaterThan(ink(cells[cell]), 5, row + " has no drawn value")
        }
    }
    func testNoSettingsOrCloseButtonsAndNoSourceRow() throws {
        let view = try card(badCase, name: "train-card-check")
        func labels(_ v: NSView) -> [String] { v.subviews.flatMap { labels($0) + (($0 as? NSButton).map { [$0.title] } ?? []) + (($0 as? NSTextField).map { [$0.stringValue] } ?? []) } }
        let text = labels(view)
        for gone in ["设置", "关闭", "来源"] { XCTAssertFalse(text.contains(gone), gone) }
    }
    func testAnnouncedResetHasItsOwnWindow() throws {
        let notice = DockCardRow(id: "reset-event:a:announced", kind: .notice, label: "↺ 额外重置", value: "预告 12:00 重置", detail: "公告不等于你的账户已重置", pill: "已预告")
        let view = try card(badCase + [notice], name: "train-card-notice")
        let window = try XCTUnwrap(view.readoutWindowForChecks), row = try XCTUnwrap(view.rowFrameForChecks("reset-event:a:announced"))
        XCTAssertGreaterThanOrEqual(row.minY - window.maxY, 13, "Below the readout: a 7 pt gap and a 6 pt inset")
        XCTAssertEqual(row.minX, 19)
    }
}
