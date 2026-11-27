// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanSettings

/// D380 and owner 11-22: ZCode's own causes in the shared table (Dock card cause line, Settings row, first run).
@MainActor final class D380ZCodeCauseTests: XCTestCase {
    private let ownerLine = "无法自动读取 ZCode 登录 · 可粘贴智谱 / Z.ai 的 API key 读取额度"

    func testUnreadableZCodeStoreOffersThePastedKeyNeverABareNotSupported() throws {
        for code in ["unsupported_login", "unknown_store_format"] {
            let card = try XCTUnwrap(ReaderCauseTable.entry(code: code, tool: "zai", toolName: "GLM"))
            XCTAssertEqual(card.reason.chinese, ownerLine)
            XCTAssertEqual(card.action.chinese, "粘贴 key…")
            XCTAssertEqual(card.target, .openSettings)
            let row = try XCTUnwrap(ReaderCauseTable.rowEntry(code: code, tool: "zai", toolName: "GLM", keyEntryAvailable: true))
            XCTAssertEqual(row.reason.chinese, ownerLine)
            XCTAssertEqual(row.action.chinese, "粘贴 key…")
            XCTAssertEqual(row.target, .addKey, "the action opens the D90 key field on the row")
            XCTAssertEqual(ReaderCauseTable.rowEntry(code: code, tool: "zai", toolName: "GLM", keyEntryAvailable: false)?.target, .openSettings)
            XCTAssertFalse(row.reason.chinese.contains("不支持"))
        }
        XCTAssertEqual(SettingsScopeConsentView.blockLine(.unsupportedLogin, tool: "zai").chinese, ownerLine)
        // Other tools keep their own wording.
        XCTAssertNotEqual(ReaderCauseTable.entry(code: "unsupported_login", tool: "claude")?.reason.chinese, ownerLine)
    }
    func testKeyConsoleLinksByRegion() {
        XCTAssertEqual(ReaderKeyRegion.global.keyConsoleURL.host, "z.ai")
        XCTAssertEqual(ReaderKeyRegion.china.keyConsoleURL.host, "bigmodel.cn")
    }
    func testKeychainCausesSayAlwaysAllowAndAllowReading() throws {
        for code in ["keychain_unset", "keychain_denied", "keychain_canceled", "keychain_confirmation_needed", "keychain_unavailable"] {
            let card = try XCTUnwrap(ReaderCauseTable.entry(code: code, tool: "zai"), code)
            XCTAssertTrue(card.action.english.contains("Always Allow"), code)
            XCTAssertTrue(card.action.chinese.contains("始终允许"), code)
            XCTAssertEqual(ReaderCauseTable.rowEntry(code: code, tool: "zai", keyEntryAvailable: true)?.target, .allowKeychain, code)
        }
        XCTAssertTrue(SettingsScopeConsentView.zcodeKeychainLine.english.contains("Always Allow"))
    }
}
