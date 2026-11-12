// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanShell

/// SET-9-38 / SET-9-39 at the root layer: the neutral surface shows one language, chosen by the macOS list.
@MainActor final class NativeSurfaceLanguageTests: XCTestCase {
    func testRuleWalksTheWholeListWithAnEnglishFallback() {
        let table: [([String], Bool)] = [
            (["en-US", "zh-Hans"], false), (["fr-FR", "zh-Hans"], true), (["zh-TW"], true), (["zh-Hant-HK"], true),
            (["fr-FR"], false), ([], false), (["zh_CN"], true),
        ]
        for (list, chinese) in table {
            XCTAssertEqual(NativeSurfaceLanguage.prefersChinese(preferredLanguages: list), chinese, "\(list)")
        }
    }
    private func texts(_ view: NSView) -> [String] {
        (view as? NSTextField).map { [$0.stringValue] } ?? view.subviews.flatMap(texts)
    }
    func testNeutralOverviewShowsOneLanguageOnly() {
        for (list, chinese) in [(["en-US"], false), (["zh-Hans"], true)] {
            let surface = NeutralSurfaceProvider(preferredLanguages: list).makeOverview()
            let shown = texts(surface.view)
            XCTAssertFalse(shown.isEmpty)
            for text in shown {
                let hasCJK = text.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }
                XCTAssertEqual(hasCJK, chinese, "\(list): \(text)")
                XCTAssertFalse(text.contains(" / "), "never both languages at once: \(text)")
            }
            XCTAssertTrue(shown.contains(chinese ? "未连接" : "Not connected"))
        }
    }
}
