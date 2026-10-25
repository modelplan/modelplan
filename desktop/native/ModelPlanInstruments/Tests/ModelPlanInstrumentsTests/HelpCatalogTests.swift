// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanInstruments

final class HelpCatalogTests: XCTestCase {
    func testEveryTopicHasTwoLocalizedLinesAndIdenticalAccessibleDescription() {
        XCTAssertEqual(Set(HelpTopic.allCases.map(\.rawValue)).count, HelpTopic.allCases.count)
        for language in [InstrumentLanguage.chinese, .english] {
            let catalog = HelpCatalog(language)
            for topic in HelpTopic.allCases {
                let context = HelpContext(fact: language == .chinese ? "示例读数" : "Example reading", value: "58 t/s")
                let text = catalog.explanation(topic, context: context)
                XCTAssertFalse(text.title.isEmpty, topic.rawValue); XCTAssertFalse(text.body.isEmpty, topic.rawValue)
                XCTAssertEqual(text.accessibleDescription, text.title + "\n" + text.body)
                XCTAssertEqual(text.accessibleDescription.components(separatedBy: "\n").count, 2)
                XCTAssertFalse(text.body.contains("{"), topic.rawValue)
                XCTAssertFalse(text.body.contains("}"), topic.rawValue)
            }
        }
    }

    func testGlossaryAndEnglishHaveNoInternalOrRetiredTerms() {
        // Script-extension matching also classifies punctuation such as · as Han on this ICU.
        let han = #"[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]"#
        XCTAssertNotNil("订阅".range(of: han, options: .regularExpression))
        XCTAssertNil("· ★ ⌥".range(of: han, options: .regularExpression))
        let banned = ["重置卡", "reset card", "source scope", "read here", "observation", "fixture", "envelope", "public screen"]
        for language in [InstrumentLanguage.chinese, .english] {
            let catalog = HelpCatalog(language), map = HelpMapCatalog(language)
            var strings = HelpTopic.allCases.map { catalog.explanation($0).accessibleDescription }
            strings += HelpMapRegion.allCases.map { map.sentence($0) }
            strings += FirstUseHint.allCases.compactMap { catalog.hint(.init($0, pageNumber: 2)) }
            strings += [map.menuTitle, map.title, map.metaphor, map.dismissal, catalog.resetHints, catalog.hintsReset]
            for text in strings {
                for term in banned { XCTAssertFalse(text.lowercased().contains(term.lowercased()), "\(term): \(text)") }
                if language == .english {
                    XCTAssertNil(text.range(of: han, options: .regularExpression), text)
                }
            }
        }
        XCTAssertEqual(HelpCatalog(.chinese).explanation(.reserve).title, "储备")
        XCTAssertEqual(HelpCatalog(.chinese).explanation(.credits).title, "点数")
        XCTAssertEqual(HelpCatalog(.chinese).explanation(.recommended).title, "★推荐")
        XCTAssertEqual(HelpCatalog(.english).explanation(.window).title, "Window")
        XCTAssertTrue(HelpCatalog(.english).explanation(.screen).body.contains("Destinations"))
    }

    func testFiveHintTextsAndResetAction() {
        let zh = HelpCatalog(.chinese), en = HelpCatalog(.english)
        XCTAssertEqual(zh.hint(.init(.trial)), "这只是本地比较，不会改你的会话")
        XCTAssertEqual(en.hint(.init(.trial)), "Just a local comparison; your session is unchanged")
        XCTAssertEqual(zh.hint(.init(.ignition)), "点按打开，长按点火")
        XCTAssertEqual(en.hint(.init(.ignition)), "Tap to open · hold to ignite")
        XCTAssertEqual(zh.hint(.init(.pinned)), "已钉住，按 Esc 或点别处取消")
        XCTAssertEqual(en.hint(.init(.pinned)), "Pinned · Esc or click elsewhere to release")
        XCTAssertEqual(zh.hint(.init(.page, pageNumber: 3)), "还有订阅在第 3 页")
        XCTAssertEqual(en.hint(.init(.page, pageNumber: 3)), "More subscriptions on page 3")
        XCTAssertEqual(zh.hint(.init(.cockpit)), "按住 ⌥ 查看说明")
        XCTAssertEqual(en.hint(.init(.cockpit)), "Hold ⌥ for help")
        XCTAssertNil(zh.hint(.init(.page))); XCTAssertNil(en.hint(.init(.page, pageNumber: 0)))
        XCTAssertEqual(zh.resetHints, "重新显示提示"); XCTAssertEqual(en.resetHints, "Show hints again")
    }

    func testSpeedBasesStayDistinctAndMissingPeriodIsNotInvented() {
        let en = HelpCatalog(.english)
        XCTAssertTrue(en.explanation(.liveSpeed).body.contains("last 60 seconds"))
        XCTAssertTrue(en.explanation(.sessionSpeed).body.contains("whole session"))
        XCTAssertTrue(en.explanation(.todaySpeed).body.contains("Today's"))
        XCTAssertTrue(en.explanation(.periodSpeed, context: .init(statisticsPeriod: .days7)).body.contains("last 7 days"))
        XCTAssertTrue(en.explanation(.periodSpeed, context: .init(statisticsPeriod: .days30)).body.contains("last 30 days"))
        XCTAssertTrue(en.explanation(.periodSpeed).body.contains("unavailable"))
        XCTAssertFalse(en.explanation(.periodSpeed).body.contains("7"))
        XCTAssertTrue(en.explanation(.cardToday).body.contains("averaging window is unavailable"))
        XCTAssertEqual(en.explanation(.liveSpeed).title, "Speed · --")
    }

    func testDynamicFactsKeepTwoLinesAndExpandOnlyCompactDurations() {
        let catalog = HelpCatalog(.chinese)
        let explanation = catalog.explanation(.quota, context: .init(fact: "剩余 89%\n  3h18后重置"))
        XCTAssertTrue(explanation.body.contains("3 小时 18 分后重置"))
        XCTAssertFalse(explanation.body.contains("\n"))
        XCTAssertEqual(catalog.explanation(.control).title, "选项")
        XCTAssertEqual(catalog.explanation(.control, context: .init(fact: "  重新显示\n提示  ")).title, "重新显示 提示")
        XCTAssertEqual(HelpDurationText.expand("1d6h · 30h后 · 5m", language: .chinese), "1 天 6 小时 · 30 小时后 · 5 分")
        XCTAssertEqual(HelpDurationText.expand("in 3h18", language: .english), "in 3h18m")
        XCTAssertEqual(HelpDurationText.expand("in 3h18m", language: .english), "in 3h18m")
        XCTAssertEqual(HelpDurationText.expand("2026-10-25 · GPT-6 Luna · abc30h", language: .chinese), "2026-10-25 · GPT-6 Luna · abc30h")
    }

    func testTypedQuotaFactsUseRelativeResetTimeInBothLanguages() {
        let now = Fixtures.now, date = now.addingTimeInterval(3 * 3600 + 18 * 60)
        for language in [InstrumentLanguage.chinese, .english] {
            let explanation = HelpCatalog(language).explanation(.quota, context: .quota(remaining: 89, resetsAt: date, now: now, language: language))
            XCTAssertTrue(explanation.body.contains(language == .chinese ? "3 小时 18 分后重置" : "resets in 3h 18m"))
            XCTAssertFalse(explanation.body.contains("2026"))
        }
        let unknown = HelpCatalog(.english).explanation(.quota, context: .quota(remaining: nil, resetsAt: nil, now: now, language: .english))
        XCTAssertTrue(unknown.body.contains("--")); XCTAssertFalse(unknown.body.contains("0%"))
    }

    func testSpecialExplanationsDoNotChangeTheirBasis() {
        let en = HelpCatalog(.english)
        XCTAssertTrue(en.explanation(.publicReset).body.contains("does not prove an account reset"))
        XCTAssertTrue(en.explanation(.comparison).body.contains("Current as the reference"))
        XCTAssertTrue(en.explanation(.effort).body.contains("session unchanged"))
        XCTAssertTrue(en.explanation(.effortLCD).body.contains("hold to pin"))
        XCTAssertTrue(en.explanation(.nozzle, context: .init(nozzleLocation: .overflow)).body.contains("cannot be dragged"))
        XCTAssertTrue(en.explanation(.nozzle).body.contains("drag along the Dock"))
        XCTAssertFalse(en.explanation(.nativeSetting).body.contains("browser"))
    }

    func testMapDirectoryHasEveryReferenceRegionInStableSurfaceOrder() {
        let map = HelpMapCatalog(.chinese)
        let cockpit = map.entries(for: .cockpit), dock = map.entries(for: .dock)
        XCTAssertEqual(cockpit.map(\.region), [.window, .shutter, .alert, .settings, .pin, .close, .fiveHours, .weekly, .other, .faders, .screen, .record, .base])
        XCTAssertEqual(dock.map(\.region), [.nozzle, .dockMove, .overflow, .rings, .number, .eventDot, .ignition, .sliver])
        XCTAssertEqual(Set((cockpit + dock).map(\.region)), Set(HelpMapRegion.allCases))
        XCTAssertEqual(Set((cockpit + dock).map(\.id)).count, 21)
        for language in [InstrumentLanguage.chinese, .english] {
            let local = HelpMapCatalog(language)
            for entry in local.entries(for: .cockpit) + local.entries(for: .dock) {
                XCTAssertFalse(entry.sentence.isEmpty); XCTAssertFalse(entry.sentence.contains("\n"))
            }
        }
        XCTAssertEqual(HelpMapCatalog(.english).metaphor, "Engine = subscription · Fader = model · Flame = working now")
        XCTAssertEqual(map.menuTitle, "说明…"); XCTAssertTrue(map.dismissal.contains("Esc"))
    }

    func testMapPreservesQuotaBlankAndOtherMeaningsAndNoFlameAlert() {
        let map = HelpMapCatalog(.chinese)
        XCTAssertTrue(map.sentence(.fiveHours).contains("空白表示没有此额度"))
        XCTAssertTrue(map.sentence(.weekly).contains("空白表示没有此额度"))
        XCTAssertTrue(map.sentence(.other).contains("+N"))
        XCTAssertTrue(map.sentence(.base).contains("不表示额度告警"))
        XCTAssertTrue(map.sentence(.faders).contains("每个代表一个模型"))
        XCTAssertTrue(map.sentence(.overflow).contains("暂不支持拖动排序"))
    }
}
