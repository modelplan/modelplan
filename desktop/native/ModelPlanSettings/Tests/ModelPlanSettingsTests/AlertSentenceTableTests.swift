// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanSettings

/// ALR-50 (WP-11): the native sentence table and the cockpit page's table
/// (`desktop/tests/cockpit/unit/alr-50-alert-sentences.test.mjs`) assert the same shared fixture,
/// so the menu line and the widget card say exactly what the lamp and the alert list say.
final class AlertSentenceTableTests: XCTestCase {
    private struct Both: Decodable { let en: String; let zh: String }
    private struct Pair: Decodable { let text: String; let short: String }
    private struct Input: Decodable {
        let kind: String
        let subscription: Both?, window: Both?
        let remaining: Double?, runOutMinutes: Double?, resetMinutes: Double?
        let cause: String?, count: Int?, tool: String?
    }
    private struct Case: Decodable { let name: String; let input: Input; let en: Pair; let zh: Pair }
    private struct Fixture: Decodable { let cases: [Case]; let causes: [String: Both]; let notUnreadable: [String] }

    private func fixture() throws -> Fixture {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../tests/shared/alert-sentences.json").standardizedFileURL
        return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }
    private func text(_ b: Both) -> SettingsText { .init(b.en, b.zh) }

    func testALR_50EverySharedCaseReadsTheSame() throws {
        let cases = try fixture().cases
        XCTAssertGreaterThanOrEqual(cases.count, 10)
        for c in cases {
            let s: AlertSentenceText
            switch c.input.kind {
            case "quota":
                s = AlertSentence.quota(subscription: text(try XCTUnwrap(c.input.subscription)), window: text(try XCTUnwrap(c.input.window)),
                                        remaining: try XCTUnwrap(c.input.remaining), runOutMinutes: c.input.runOutMinutes, resetMinutes: c.input.resetMinutes)
            case "unreadable":
                s = AlertSentence.unreadable(subscription: text(try XCTUnwrap(c.input.subscription)), cause: c.input.cause, tool: c.input.tool)
            case "unreadableMany":
                s = AlertSentence.unreadableMany(try XCTUnwrap(c.input.count))
            default:
                XCTFail("unknown kind \(c.input.kind)"); continue
            }
            XCTAssertEqual(s.text.english, c.en.text, c.name); XCTAssertEqual(s.short.english, c.en.short, c.name)
            XCTAssertEqual(s.text.chinese, c.zh.text, c.name); XCTAssertEqual(s.short.chinese, c.zh.short, c.name)
        }
    }

    func testALR_50CausePhrasesMatchTheSharedTable() throws {
        let f = try fixture()
        for (code, phrase) in f.causes { XCTAssertEqual(AlertSentence.cause(code), text(phrase), code) }
        for code in ["other", "parse_error", "no_plan"] + f.notUnreadable { XCTAssertNil(AlertSentence.cause(code), code) }
        XCTAssertEqual(AlertSentence.notUnreadable, Set(f.notUnreadable))
        XCTAssertFalse(AlertSentence.isUnreadable(nil)); XCTAssertFalse(AlertSentence.isUnreadable("not_read_yet"))
        XCTAssertTrue(AlertSentence.isUnreadable("not_signed_in")); XCTAssertTrue(AlertSentence.isUnreadable("other"))
    }

    /// G3-218: Antigravity installed but not running says "not running", matching its card; other tools keep "not installed".
    func testAntigravityRuntimeMissingIsNotRunningNotNotInstalled() {
        XCTAssertEqual(AlertSentence.cause("runtime_missing", tool: "antigravity"), SettingsText("not running", "未运行"))
        XCTAssertEqual(AlertSentence.cause("runtime_missing", tool: "codex"), SettingsText("not installed", "未安装"))
        XCTAssertEqual(AlertSentence.cause("runtime_missing"), SettingsText("not installed", "未安装"))
        XCTAssertEqual(AlertSentence.cause("not_signed_in", tool: "antigravity"), SettingsText("not signed in", "未登录"))
    }
}
