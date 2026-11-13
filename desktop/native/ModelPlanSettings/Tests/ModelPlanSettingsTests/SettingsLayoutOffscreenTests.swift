// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanSettings

/// Constructs detached views only: no application, window, event or service.
@MainActor final class SettingsLayoutOffscreenTests: XCTestCase {
    func testSidebarLabelCentersInSelectionRowForBothLanguages() throws {
        for title in ["General", "通用"] {
            let cell = SettingsSidebarCell.make(title: title, identifier: "synthetic.pane")
            cell.frame = NSRect(x: 0, y: 0, width: 220, height: 36)
            cell.layoutSubtreeIfNeeded()
            let label = try XCTUnwrap(cell.subviews.first as? NSTextField)
            XCTAssertEqual(label.frame.midY, cell.bounds.midY, accuracy: 0.5)
            XCTAssertEqual(label.stringValue, title)
        }
    }

    func testExplanatoryCopyWrapsAndFitsAtNarrowAndWideWidths() {
        let row = SettingsNativeRow(key: .login)
        XCTAssertEqual(row.subtitle.lineBreakMode, .byWordWrapping)
        XCTAssertEqual(row.subtitle.maximumNumberOfLines, 0)
        for width in [CGFloat(160), 320, 520] {
            row.subtitle.preferredMaxLayoutWidth = width
            for text in ["A long explanatory sentence stays readable when the settings pane is resized.",
                         "调整设置面板大小时，这段较长的说明文字仍应完整显示。"] {
                row.subtitle.stringValue = text
                let available = NSSize(width: width, height: 10_000)
                let required = row.subtitle.sizeThatFits(available)
                XCTAssertGreaterThan(required.height, 0)
                XCTAssertLessThanOrEqual(required.width, width + 1)
                XCTAssertGreaterThanOrEqual(row.subtitle.intrinsicContentSize.height + 1, required.height)
            }
        }
    }
}
