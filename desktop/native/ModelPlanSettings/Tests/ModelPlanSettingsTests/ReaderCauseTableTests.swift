// SPDX-License-Identifier: MIT
import Foundation
import XCTest
@testable import ModelPlanSettings

/// D87 slice 4: one shared table from the engine's fixed cause code to a reason and one action.
final class ReaderCauseTableTests: XCTestCase {
    func testEachCauseHasItsOwnReasonAndActionInBothLanguages() throws {
        let cases: [(String, String?, String?, String, String, String, String, ReaderCauseTarget)] = [
            ("runtime_missing", nil, nil, "Node.js is required", "需要 Node.js", "Install Node.js", "安装 Node.js", .installNode),
            ("not_found", "codex", "Codex", "Install the Codex CLI, or make sure Codex runs from a terminal", "安装 Codex CLI，或确认 Codex 在命令行里能运行", "Open install page", "打开安装页面", .installTool),
            ("timeout", nil, nil, "The reading timed out; it will retry on its own", "读取超时，稍后自动重试", "Retry now", "立即重试", .retry),
            ("rpc_error", "codex", "Codex", "Codex's background service returned an error", "Codex 后台服务出错", "Retry", "重试", .retry),
            ("closed", nil, nil, "The tool's background service closed unexpectedly", "工具后台服务意外退出", "Retry", "重试", .retry),
            ("keychain_unset", "claude", "Claude Code", "Keychain access needed", "需要允许读取钥匙串", "Allow reading", "允许读取", .allowKeychain),
            ("key_missing", "zai", "GLM", "Sign in to the GLM Coding Plan in ZCode", "在 ZCode 里登录 GLM 编程套餐", "Open ZCode", "打开 ZCode", .openTool),
            ("region_refused", "zai", "GLM", "This address is a third-party relay, so its quota can't be read", "这个地址是第三方转发服务，查不到额度", "Why?", "了解原因", .explain),
            ("consent_required", nil, nil, "Reading permission needed", "需要读取授权", "Review permission in Settings", "在设置检查授权", .openSettings),
        ]
        for (code, tool, name, reasonEN, reasonZH, actionEN, actionZH, target) in cases {
            let entry = try XCTUnwrap(ReaderCauseTable.entry(code: code, tool: tool, toolName: name), code)
            XCTAssertEqual(entry.reason, SettingsText(reasonEN, reasonZH), code)
            XCTAssertEqual(entry.action, SettingsText(actionEN, actionZH), code)
            XCTAssertEqual(entry.target, target, code)
        }
    }

    func testLedgerNamesAreAliasesAndNoKeyDependsOnTheTool() throws {
        XCTAssertEqual(ReaderCauseTable.entry(code: "keychain_needed"), ReaderCauseTable.entry(code: "keychain_unset"))
        XCTAssertEqual(ReaderCauseTable.entry(code: "consent_needed"), ReaderCauseTable.entry(code: "consent_required"))
        XCTAssertEqual(ReaderCauseTable.entry(code: "no_key", tool: "zai")?.reason.chinese, "在 ZCode 里登录 GLM 编程套餐")
        XCTAssertEqual(ReaderCauseTable.entry(code: "no_key", tool: "opencode")?.reason.chinese, "需要配置密钥")
        XCTAssertEqual(ReaderCauseTable.entry(code: "tool_not_found")?.reason.chinese, "安装这个工具，或确认它在命令行里能运行")
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
        XCTAssertEqual(values.first { $0.id == "codex" }?.value, "需要 Node.js · 安装 Node.js")
        XCTAssertEqual(values.first { $0.id == "grok" }?.value, "unavailable")
    }
}
