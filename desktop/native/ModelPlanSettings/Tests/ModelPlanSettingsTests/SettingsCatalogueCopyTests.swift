// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanSettings

final class SettingsCatalogueCopyTests: XCTestCase {
    func testGlossaryTermsAreUsedByTheSettingsCatalogue() throws {
        let rows = try SettingsCatalogue.rows(preferences: .init(), context: .init())
        func row(_ key: SettingKey) throws -> SettingsRow { try XCTUnwrap(rows.first { $0.key == key }) }
        XCTAssertEqual(try row(.percentagePin).subtitle.chinese, "为每个订阅选择最紧的、5小时或每周窗口。")
        XCTAssertEqual(try row(.detectedReaders).subtitle.english, "Read-only local reader status.")
        XCTAssertEqual(try row(.detectedReaders).subtitle.chinese, "本地读取器的只读状态。")
        XCTAssertEqual(try row(.menuDisplay).subtitle.chinese, "图标、最紧的百分比或并列两个窗口。")
        XCTAssertEqual(try row(.openShortcut).title.chinese, "打开驾驶舱快捷键")
        XCTAssertEqual(try row(.opening).title.chinese, "打开驾驶舱方式")
        XCTAssertEqual(try row(.resetHints).subtitle.chinese, "再次显示首次使用提示。")
        XCTAssertEqual(try row(.resetHints).subtitle.english, "Show the first-use hints again.")
        XCTAssertEqual(try row(.reset).subtitle.chinese, "读取到重置时通知。")
        XCTAssertEqual(try row(.expiring).title.english, "Resets expiring")
        XCTAssertEqual(try row(.expiring).title.chinese, "重置即将到期")
        XCTAssertEqual(try row(.expiring).subtitle.chinese, "已过期的重置不再重新显示。")
        XCTAssertFalse(try row(.source).subtitle.chinese.contains("采集器"))
        XCTAssertFalse(try row(.diagnostics).subtitle.chinese.contains("读取器ID"))
    }
    func testQuotaWindowChoicesUseGlossaryLabelsInBothLanguages() {
        XCTAssertEqual(SettingsWords.option("5h", key: .percentagePin, language: .english), "5h")
        XCTAssertEqual(SettingsWords.option("5h", key: .percentagePin, language: .chinese), "5小时")
        XCTAssertEqual(SettingsWords.option("tightest", key: .menuDisplay, language: .chinese), "最紧的百分比")
        XCTAssertEqual(SettingsDiagramWords.quotaWindow(.auto, language: .english), "Auto")
        XCTAssertEqual(SettingsDiagramWords.quotaWindow(.fiveHour, language: .english), "5h")
        XCTAssertEqual(SettingsDiagramWords.quotaWindow(.week, language: .english), "Weekly")
        XCTAssertEqual(SettingsDiagramWords.quotaWindow(.auto, language: .chinese), "自动")
        XCTAssertEqual(SettingsDiagramWords.quotaWindow(.fiveHour, language: .chinese), "5小时")
        XCTAssertEqual(SettingsDiagramWords.quotaWindow(.week, language: .chinese), "每周")
    }
    @MainActor func testShortcutAccessibilityUsesCockpitGlossaryName() {
        let control = SettingsShortcutControl(key: .openShortcut, chord: .init("O", modifiers: [.command, .shift]))
        control.configure(chord: .init("O", modifiers: [.command, .shift]), language: .chinese)
        XCTAssertEqual(control.accessibilityLabel(), "打开驾驶舱快捷键")
    }

}
