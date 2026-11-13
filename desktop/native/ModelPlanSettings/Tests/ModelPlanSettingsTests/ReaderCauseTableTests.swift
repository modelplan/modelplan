// SPDX-License-Identifier: MIT
import Foundation
import XCTest
@testable import ModelPlanSettings

/// D87 slice 4: one shared table from the engine's fixed cause code to a reason and one action.
final class ReaderCauseTableTests: XCTestCase {
    func testEachCauseHasItsOwnReasonAndActionInBothLanguages() throws {
        let cases: [(String, String?, String?, String, String, String, String, ReaderCauseTarget)] = [
            ("runtime_missing", nil, nil, "Node.js is required", "需要 Node.js", "Install Node.js, then refresh", "安装 Node.js 后刷新", .guidance),
            ("not_found", "codex", "Codex", "Can't find the Codex command", "找不到 Codex 命令", "Check connected tools in Settings", "在设置检查已连接工具", .openSettings),
            ("timeout", nil, nil, "The reading timed out; it will retry on its own", "读取超时，稍后自动重试", "No action needed; it retries on its own", "无需操作，会自动重试", .guidance),
            ("rpc_error", "codex", "Codex", "Codex's background service returned an error", "Codex 后台服务出错", "It retries on its own; reopen the tool if it keeps failing", "会自动重试；若持续失败请重新打开该工具", .guidance),
            ("closed", nil, nil, "The tool's background service closed unexpectedly", "工具后台服务意外退出", "It retries on its own; reopen the tool if it keeps failing", "会自动重试；若持续失败请重新打开该工具", .guidance),
            ("keychain_unset", "claude", "Claude Code", "Keychain access needed", "需要允许读取钥匙串", "Allow Keychain reading in Settings", "在设置允许读取钥匙串", .openSettings),
            ("key_missing", "zai", "GLM", "Sign in to the GLM Coding Plan in ZCode", "在 ZCode 里登录 GLM 编程套餐", "Open ZCode and sign in", "打开 ZCode 并登录", .guidance),
            ("region_refused", "zai", "GLM", "This address is a third-party relay, so its quota can't be read", "这个地址是第三方转发服务，查不到额度", "Use the official address to read its quota", "改用官方地址才能读取额度", .guidance),
            ("consent_required", nil, nil, "Reading permission needed", "需要读取授权", "Review permission in Settings", "在设置检查授权", .openSettings),
        ]
        for (code, tool, name, reasonEN, reasonZH, actionEN, actionZH, target) in cases {
            let entry = try XCTUnwrap(ReaderCauseTable.entry(code: code, tool: tool, toolName: name), code)
            XCTAssertEqual(entry.reason, SettingsText(reasonEN, reasonZH), code)
            XCTAssertEqual(entry.action, SettingsText(actionEN, actionZH), code)
            XCTAssertEqual(entry.target, target, code)
        }
    }

    /// D228: a balance-only reading names X Subscription for Grok and the tool otherwise; no control is drawn.
    func testUsageNotReportedNamesTheXSubscriptionForGrok() throws {
        let grok = try XCTUnwrap(ReaderCauseTable.entry(code: "usage_not_reported", tool: "grok", toolName: "Grok Build"))
        XCTAssertEqual(grok.reason, SettingsText("The X Subscription reports no usage percentage; only the balance is shown", "X 订阅不提供用量百分比，只显示余额"))
        XCTAssertEqual(grok.target, .guidance)
        let other = try XCTUnwrap(ReaderCauseTable.entry(code: "usage_not_reported", tool: "kimi", toolName: "Kimi Code"))
        XCTAssertEqual(other.reason.chinese, "Kimi Code 不提供用量百分比，只显示余额")
    }

    /// Review finding (GLM Q2): no step may suggest a button that does not exist. Only the card's Settings entry is a
    /// real control, so every cause either points at it or is plain guidance that renders no control.
    func testEveryCauseNextStepIsTheWiredSettingsEntryOrPlainGuidance() throws {
        let codes = ["not_found", "runtime_missing", "timeout", "rpc_error", "closed", "not_signed_in", "login_expired",
                     "keychain_unset", "keychain_unavailable", "keychain_not_found", "keychain_denied", "key_missing",
                     "region_refused", "consent_required"]
        let buttonWords = ["Retry", "Retry now", "Why?", "Install Node.js", "Open ZCode", "How to allow it", "Allow reading"]
        for code in codes {
            for tool in [nil, "zai", "codex"] {
                let entry = try XCTUnwrap(ReaderCauseTable.entry(code: code, tool: tool, toolName: tool.map { $0.capitalized }), code)
                XCTAssertTrue([ReaderCauseTarget.openSettings, .guidance].contains(entry.target), code)
                XCTAssertEqual(entry.target.rendersControl, entry.target == .openSettings, code)
                if entry.target == .guidance {
                    XCTAssertFalse(buttonWords.contains(entry.action.english), "\(code): guidance must not read like a button")
                    XCTAssertFalse(entry.action.english.hasSuffix("…"), code)
                } else {
                    XCTAssertTrue(entry.action.english.contains("Settings"), "\(code): the wired step names the Settings entry")
                }
            }
        }
    }

    func testLedgerNamesAreAliasesAndNoKeyDependsOnTheTool() throws {
        XCTAssertEqual(ReaderCauseTable.entry(code: "keychain_needed"), ReaderCauseTable.entry(code: "keychain_unset"))
        XCTAssertEqual(ReaderCauseTable.entry(code: "consent_needed"), ReaderCauseTable.entry(code: "consent_required"))
        XCTAssertEqual(ReaderCauseTable.entry(code: "no_key", tool: "zai")?.reason.chinese, "在 ZCode 里登录 GLM 编程套餐")
        XCTAssertEqual(ReaderCauseTable.entry(code: "no_key", tool: "opencode")?.reason.chinese, "需要配置密钥")
        XCTAssertEqual(ReaderCauseTable.entry(code: "tool_not_found")?.reason.chinese, "找不到工具命令")
    }

    func testUnknownAndGenericCodesKeepTheEngineText() {
        for code in ["other", "reader_error", "parse_error", "stale_reading", "", "surprise"] {
            XCTAssertNil(ReaderCauseTable.entry(code: code), code)
        }
    }

    func testStaleLineNamesTheAgeAndTheCause() throws {
        let entry = try XCTUnwrap(ReaderCauseTable.entry(code: "timeout"))
        XCTAssertEqual(ReaderCauseTable.staleLine(entry: entry, ageSeconds: 3 * 3600 + 20, language: .chinese),
                       "上次成功读取：3 小时前 · 原因：读取超时，稍后自动重试")
        XCTAssertEqual(ReaderCauseTable.staleLine(entry: entry, ageSeconds: 5 * 60, language: .english),
                       "Last good reading 5m ago · cause: The reading timed out; it will retry on its own")
        XCTAssertTrue(ReaderCauseTable.staleLine(entry: entry, ageSeconds: 49 * 3600, language: .chinese).contains("2 天前"))
        XCTAssertTrue(ReaderCauseTable.staleLine(entry: entry, ageSeconds: -5, language: .chinese).contains("不到 1 分钟前"))
    }

    func testSettingsSourceRowShowsTheCauseInsteadOfTheBareState() throws {
        var context = SettingsPageContext()
        context.subscriptions = [SettingsSubscription(id: "codex", name: .init("Codex", "Codex"), source: .unavailable, causeCode: "runtime_missing"),
                                 SettingsSubscription(id: "grok", name: .init("Grok", "Grok"), source: .unavailable)]
        var preferences = SettingsPreferences(); preferences.language = .chinese
        let row = try XCTUnwrap(SettingsCatalogue.rows(preferences: preferences, context: context).first { $0.key == .source })
        guard case .subscriptions(let values) = row.value else { return XCTFail("not per-subscription") }
        XCTAssertEqual(values.first { $0.id == "codex" }?.value, "unavailable" + SubscriptionSourceState.causeSeparator + "需要 Node.js · 安装 Node.js 后刷新")
        XCTAssertEqual(values.first { $0.id == "grok" }?.value, "unavailable")
    }

    private func texts(in view: NSView) -> [String] {
        var out: [String] = []
        if let field = view as? NSTextField { out.append(field.stringValue) }
        for sub in view.subviews { out += texts(in: sub) }
        return out
    }

    /// The real renderer: the cause must reach the native row, and a stale source keeps its own status.
    @MainActor func testNativeSourceRowShowsTheCauseAndStaleKeepsItsStatus() throws {
        var context = SettingsPageContext(); context.configureV1NormalEntry()
        context.subscriptions = [SettingsSubscription(id: "codex", name: .init("Codex", "Codex"), source: .unavailable, causeCode: "runtime_missing"),
                                 SettingsSubscription(id: "claude", name: .init("Claude", "Claude"), source: .stale, causeCode: "timeout"),
                                 SettingsSubscription(id: "grok", name: .init("Grok", "Grok"), source: .unavailable)]
        for language in [SettingsLanguage.english, .chinese] {
            var preferences = SettingsPreferences(); preferences.language = language
            let snapshot = SettingsSnapshot(revision: 0, preferences: preferences)
            let rows = try SettingsCatalogue.rows(preferences: preferences, context: context)
            let row = SettingsNativeRow(key: .source)
            row.apply(try XCTUnwrap(rows.first { $0.key == .source }), language: language, saving: false,
                input: nil, reduced: false, onChoice: #selector(NSObject.description), target: self,
                snapshot: snapshot, context: context, holdAvailable: false, hasHost: true,
                onEdit: { _, _ in }, onSurfaceAction: { _, _ in }, onDraftCleared: { _ in })
            let shown = texts(in: row).joined(separator: "\n")
            let cause = try XCTUnwrap(ReaderCauseTable.entry(code: "runtime_missing", tool: "", toolName: "Codex"))
            XCTAssertTrue(shown.contains(cause.reason.value(language)), shown)
            XCTAssertTrue(shown.contains(cause.action.value(language)), shown)
            XCTAssertTrue(shown.contains("Claude · " + (language == .english ? "Stale" : "数据已过时")), shown)
            XCTAssertTrue(shown.contains("Grok · " + (language == .english ? "Unavailable" : "不可用")), shown)
        }
    }
}
