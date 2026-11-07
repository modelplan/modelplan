// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
@testable import ModelPlanAppIntegration

/// The owner's bad case 01 against the r7 card: measurements are the prototype's own, taken from its rendered DOM.
/// Set MODELPLAN_CARD_RENDER_DIR to also write the card as a PNG for a side-by-side.
@MainActor final class QuotaWidgetCardPrototypeTests: XCTestCase {
    private func card(_ rows: [DockCardRow], name: String) throws -> DockCardView {
        let content = DockCardContent(subscriptionID: "codex", name: "Codex", plan: "Pro", sourceAndAge: "工具运行时 · 1分钟前", rows: rows)
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
        XCTAssertEqual(window.minX, 11); XCTAssertEqual(window.width, 282); XCTAssertEqual(window.height, 75)
        XCTAssertEqual(view.frame.height - window.maxY, 29, "The empty events band and the plate padding")
        let rows = try ["quota:weekly", "reserve", "today"].map { try XCTUnwrap(view.rowFrameForChecks($0)) }
        XCTAssertEqual(rows.map { $0.minY - window.minY }, [7, 28, 49])
        XCTAssertEqual(rows.map(\.height), [19, 19, 19])
        XCTAssertEqual(rows.map(\.minX), [18, 18, 18])
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
