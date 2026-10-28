// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanSettings

@MainActor private final class DiagnosticFake: SettingsDiagnosticClipboard {
    var text: String?
    var accepted = true
    func writeDiagnostics(_ text: String) -> Bool { self.text = text; return accepted }
}
@MainActor final class Beta07AboutTests: XCTestCase {
    func testFinalCopyBoundarySanitizesVersionsAndOnlyCopiesAllowlistedFields() {
        var about = SettingsAbout(appVersion: "/Users/private/1.2.3", cliVersion: "email@example.test")
        about.macOSVersion = "26.1\nHOME=/private"
        about.enabledReaders = [.codex]; about.enabledConnectionTools = [.cursor, .qwen]
        about.recentErrorCodes = Array(repeating: .permissionDenied, count: 12)
        let clipboard = DiagnosticFake()
        XCTAssertTrue(SettingsDiagnosticCopy.copy(about, to: clipboard))
        XCTAssertEqual(clipboard.text, "app=unknown\ncli=unknown\nmacOS=unknown\nreaders=codex,cursor,qwen\nerrors=" + Array(repeating: "permissionDenied", count: 8).joined(separator: ","))
        for secret in ["/Users", "private", "example", "HOME", "email"] { XCTAssertFalse(clipboard.text!.contains(secret)) }
        clipboard.accepted = false
        XCTAssertFalse(SettingsDiagnosticCopy.copy(about, to: clipboard))
    }
    func testTrademarkNoticeDoesNotImplyBundledComponentsOrRootMITForOfficialArt() {
        let notice = SettingsAbout.trademarkNotice
        XCTAssertTrue(notice.english.contains("root MIT license does not cover"))
        XCTAssertTrue(notice.chinese.contains("不在根 MIT"))
        for component in ["three.js", "CodexBar", "font"] { XCTAssertFalse(notice.english.contains(component)) }
        XCTAssertTrue(SettingsPageContext().licenseNotices.isEmpty, "only the host's audited bundled notices may list dependencies")
    }
    func testPublicLinksOnlyReachInjectedHostWithoutPersonalQueryData() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("beta07-links-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let editor = SettingsEditor(store: try SettingsStore(url: root.appendingPathComponent("settings.json")))
        await editor.reload()
        var received: [SettingsPublicLink] = []
        editor.onHostRequest = { request in
            if case .openPublicLink(let link) = request.intent { received.append(link) }
        }
        for link in SettingsPublicLink.allCases { try editor.request(.openLink(link)) }
        XCTAssertEqual(received, SettingsPublicLink.allCases)
        for link in received {
            XCTAssertEqual(link.url.scheme, "https"); XCTAssertNil(link.url.query)
            XCTAssertNil(link.url.user); XCTAssertNil(link.url.password)
        }
    }
}
