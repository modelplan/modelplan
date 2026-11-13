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
    func testCopiedVersionsRemoveFreeTextMetadataAndUnrecognizedPrereleaseTags() {
        var about = SettingsAbout(appVersion: "1.2.3+account-private", cliVersion: "0.5.41-session-private")
        about.macOSVersion = "26.1+home-private"
        let clipboard = DiagnosticFake()
        XCTAssertTrue(SettingsDiagnosticCopy.copy(about, to: clipboard))
        XCTAssertEqual(clipboard.text, "app=1.2.3\ncli=unknown\nmacOS=26.1\nreaders=\nerrors=")
        XCTAssertEqual(about.version, "1.2.3+account-private", "UI version display remains independent of the copy projection")
        about.appVersion = "1.2.3-beta07+private-build"; about.cliVersion = "v0.5.42-rc.1"
        XCTAssertTrue(SettingsDiagnosticCopy.copy(about, to: clipboard))
        XCTAssertTrue(clipboard.text!.hasPrefix("app=1.2.3-beta07\ncli=v0.5.42-rc.1\n"))
        for secret in ["account", "session", "home", "private"] { XCTAssertFalse(clipboard.text!.contains(secret)) }
        about.appVersion = "1.2.3\n"; about.cliVersion = "0.5.41\r"; about.macOSVersion = "26.1\t"
        XCTAssertTrue(SettingsDiagnosticCopy.copy(about, to: clipboard))
        XCTAssertEqual(clipboard.text, "app=unknown\ncli=unknown\nmacOS=unknown\nreaders=\nerrors=")
        for separator in ["\u{2028}", "\u{2029}"] {
            about.macOSVersion = "26.1" + separator
            XCTAssertTrue(SettingsDiagnosticCopy.copy(about, to: clipboard))
            XCTAssertEqual(clipboard.text, "app=unknown\ncli=unknown\nmacOS=unknown\nreaders=\nerrors=")
        }
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
