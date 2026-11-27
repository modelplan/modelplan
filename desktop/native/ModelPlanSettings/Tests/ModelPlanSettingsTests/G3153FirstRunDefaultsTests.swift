// SPDX-License-Identifier: MIT
import AppKit
import Foundation
import XCTest
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanSettings

/// Owner reports on internal build 2 (G3-153..155), through the first-run page and its Done grant.
///  - A tool is ticked by default only if it can be read: a definitive "nothing to read" answer is unticked,
///    a transient failure stays ticked with its retry, and a choice the user made always stands.
///  - ZCode's QR-code sign-in (D369) is a choosable opt-in, off by default, never allowed by the tool's own tick,
///    and never described as unsupported.
@MainActor final class G3153FirstRunDefaultsTests: XCTestCase {
    private typealias Path = (scope: String, tool: String, route: String, state: String, detected: Bool, defaultCheck: Bool)
    private let zcodeLogin = "zai.account_usage.saved_login"
    private func entry() -> ScopeConsentEntry {
        ScopeConsentEntry(client: ScopeConsentTestClient(), ready: { true }, makeGrant: { intent in
            try .init(requestId: intent.requestID, expectStoreEpoch: "synthetic", expectGeneration: 1, consentTextVersion: 17, allow: intent.allowIDs, deny: intent.denyIDs)
        })
    }
    private func facts(_ paths: [Path]) throws -> WireConsentFacts {
        var root = URL(fileURLWithPath: #filePath).resolvingSymlinksInPath().deletingLastPathComponent()
        while root.path != "/", !FileManager.default.fileExists(atPath: root.appendingPathComponent("schema/app-cli/captures/WireConsentFacts.json").path) { root.deleteLastPathComponent() }
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("schema/app-cli/captures/WireConsentFacts.json"))) as? [String: Any])
        let base = try XCTUnwrap((object["scopes"] as? [[String: Any]])?.first)
        object["scopes"] = paths.map { path -> [String: Any] in
            var value = base
            value["scope"] = path.scope; value["tool"] = path.tool; value["route"] = path.route; value["state"] = path.state
            value["detected"] = path.detected; value["retired"] = false; value["defaultCheck"] = path.defaultCheck; value["cleanupPending"] = false
            value.removeValue(forKey: "keychain"); value.removeValue(forKey: "disabledReason")
            return value
        }
        return try WireDecoder.decode(WireConsentFacts.self, from: JSONSerialization.data(withJSONObject: object))
    }
    private func tools(zcode: Bool = false) throws -> WireConsentFacts {
        var paths: [Path] = [
            ("codex.local_history", "codex", "local_log", "unset", true, true),
            ("cursor.local_history", "cursor", "local_log", "unset", true, true),
            ("grok.local_history", "grok", "local_log", "unset", true, true),
            ("zai.local_history", "zai", "local_log", "unset", true, true),
            ("zai.account_usage.api_key", "zai", "api_key_api", "unset", true, true),
        ]
        if zcode { paths.append((zcodeLogin, "zai", "saved_login_api", "unset", true, false)) }
        return try facts(paths)
    }
    private func texts(_ root: NSView) -> [String] {
        ([(root as? NSTextField)?.stringValue, (root as? NSButton)?.title].compactMap { $0 }) + root.subviews.flatMap(texts)
    }
    private func identifiers(_ root: NSView) -> [String] { [root.accessibilityIdentifier()] + root.subviews.flatMap(identifiers) }

    // MARK: G3-153 default selection

    func testADefinitiveNothingToReadAnswerIsUntickedAndATransientFailureStaysTicked() throws {
        let controller = entry().controller
        controller.receiveAcceptedFacts(try tools())
        for (tool, code) in [("cursor", "no_plan"), ("grok", "file_unreadable")] { controller.setRowForTesting(tool, state: .failed, code: code) }
        XCTAssertFalse(controller.isFirstRunToolChosen("cursor"), "this account has no plan to read")
        XCTAssertFalse(controller.isFirstRunToolChosen("grok"), "cannot read the local login data")
        XCTAssertTrue(controller.isFirstRunToolChosen("codex"), "a readable tool stays ticked")
        for code in ["timeout", "network", "http_5xx", "http_429", "rpc_error", "other"] {
            controller.setRowForTesting("grok", state: .failed, code: code)
            XCTAssertTrue(controller.isFirstRunToolChosen("grok"), "\(code) is transient: it stays ticked")
        }
        for code in ["no_plan", "not_signed_in", "unsupported_login", "file_missing", "file_unreadable"] {
            controller.setRowForTesting("grok", state: .failed, code: code)
            XCTAssertFalse(controller.isFirstRunToolChosen("grok"), "\(code) is a definitive answer")
        }
    }
    func testAChoiceTheUserMadeNeverChanges() throws {
        let controller = entry().controller
        controller.receiveAcceptedFacts(try tools())
        controller.setRowForTesting("cursor", state: .failed, code: "no_plan")
        controller.chooseFirstRunTool("cursor", chosen: true)
        XCTAssertTrue(controller.isFirstRunToolChosen("cursor"), "ticked by the user: stays ticked")
        controller.setRowForTesting("grok", state: .failed, code: "timeout")
        controller.chooseFirstRunTool("grok", chosen: false)
        controller.setRowForTesting("grok", state: .fresh)
        XCTAssertFalse(controller.isFirstRunToolChosen("grok"), "unticked by the user: stays unticked")
        controller.setRowForTesting("cursor", state: .failed, code: "timeout")
        XCTAssertTrue(controller.isFirstRunToolChosen("cursor"))
    }
    func testDoneSendsTheDefaultsAndANothingToReadToolDoesNotHoldDoneBack() throws {
        let controller = entry().controller
        controller.receiveAcceptedFacts(try facts([("cursor.local_history", "cursor", "local_log", "unset", true, true)]))
        controller.setRowForTesting("cursor", state: .failed, code: "no_plan")
        XCTAssertFalse(controller.isFirstRunToolChosen("cursor"))
        XCTAssertTrue(controller.firstRunChoiceSatisfied, "nothing readable is not a dead end")
        XCTAssertEqual(controller.firstRunChoiceIntent()?.denyIDs, ["cursor.local_history"])
    }
    func testAnUntickedToolShowsItsCauseAndATransientOneKeepsItsRetry() async throws {
        let entry = entry()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("g3153-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let editor = SettingsEditor(store: try SettingsStore(url: directory.appendingPathComponent("preferences.json")))
        let page = SettingsFirstRunController(editor: editor, scopeConsentEntry: entry)
        page.presence = FirstRunPresenceDetector(home: "/h", searchDirectories: []) { ["/h/.cursor", "/h/.grok"].contains($0) }
        await page.prepare()
        entry.controller.receiveAcceptedFacts(try tools())
        entry.controller.setRowForTesting("cursor", state: .failed, code: "no_plan")
        entry.controller.setRowForTesting("grok", state: .failed, code: "timeout")
        let root = try XCTUnwrap(page.window?.contentView)
        func box(_ tool: String) throws -> NSButton { try XCTUnwrap(findButton(root, "scope.firstRun.tool." + tool)) }
        XCTAssertEqual(try box("cursor").state, .off)
        XCTAssertEqual(try box("grok").state, .on, "a timeout stays ticked")
        XCTAssertTrue(identifiers(root).contains("scope.firstRun.prereq.cursor"), "the cause line stays")
    }
    private func findButton(_ root: NSView, _ id: String) -> NSButton? {
        if let button = root as? NSButton, button.accessibilityIdentifier() == id { return button }
        for view in root.subviews { if let found = findButton(view, id) { return found } }
        return nil
    }

    // MARK: G3-154 / G3-155 ZCode QR-code sign-in

    func testTheZCodeSignInIsOffByDefaultAndTheToolTickNeverAllowsIt() throws {
        let controller = entry().controller
        controller.receiveAcceptedFacts(try tools(zcode: true))
        XCTAssertEqual(controller.firstRunOptIn(forTool: "zai")?.scope, zcodeLogin)
        XCTAssertFalse(controller.isFirstRunOptInChosen(zcodeLogin), "default off")
        XCTAssertFalse(controller.firstRunTools.first { $0.tool == "zai" }?.scopes.contains(zcodeLogin) ?? true)
        let intent = try XCTUnwrap(controller.firstRunChoiceIntent())
        XCTAssertFalse(intent.allowIDs.contains(zcodeLogin))
        XCTAssertFalse(intent.denyIDs.contains(zcodeLogin))
        controller.selectAll()
        XCTAssertFalse(controller.selectedIDs.contains(zcodeLogin), "Select all never includes it")
    }
    func testTickingTheZCodeSignInAllowsItWithDoneAndOnlyWhileTheToolIsTicked() throws {
        let controller = entry().controller
        controller.receiveAcceptedFacts(try tools(zcode: true))
        controller.chooseFirstRunOptIn(zcodeLogin, chosen: true)
        XCTAssertTrue(controller.isFirstRunOptInChosen(zcodeLogin))
        XCTAssertTrue(try XCTUnwrap(controller.firstRunChoiceIntent()).allowIDs.contains(zcodeLogin))
        controller.chooseFirstRunTool("zai", chosen: false)
        let off = try XCTUnwrap(controller.firstRunChoiceIntent())
        XCTAssertFalse(off.allowIDs.contains(zcodeLogin), "an unticked tool reads nothing")
    }
    func testNoZCodeSignInFoundOffersNoOptIn() throws {
        let controller = entry().controller
        controller.receiveAcceptedFacts(try tools(zcode: false))
        XCTAssertNil(controller.firstRunOptIn(forTool: "zai"))
    }
    private func mark(_ step: String) { FileHandle.standardError.write(Data(("G3155DIAG " + step + "\n").utf8)) }
    func testTheFirstRunRowOffersTheOptInAndNeverSaysUnsupported() async throws {
        mark("start")
        signal(SIGABRT) { _ in
            var frames = [UnsafeMutableRawPointer?](repeating: nil, count: 128)
            let count = backtrace(&frames, 128)
            let header = "G3155DIAG SIGABRT backtrace\n"
            _ = header.withCString { write(2, $0, strlen($0)) }
            backtrace_symbols_fd(&frames, count, 2)
            _ = "G3155DIAG end of backtrace\n".withCString { write(2, $0, strlen($0)) }
            signal(SIGABRT, SIG_DFL); raise(SIGABRT)
        }
        let entry = entry()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("g3155-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let editor = SettingsEditor(store: try SettingsStore(url: directory.appendingPathComponent("preferences.json")))
        let page = SettingsFirstRunController(editor: editor, scopeConsentEntry: entry)
        page.presence = FirstRunPresenceDetector(home: "/h", searchDirectories: []) { $0 == "/h/.zcode" }
        mark("before prepare")
        await page.prepare()
        mark("after prepare")
        let zcodeFacts = try tools(zcode: true)
        mark("after tools")
        entry.controller.receiveAcceptedFacts(zcodeFacts)
        mark("after facts")
        entry.controller.setRowForTesting("zai", state: .needsConsent, code: "consent_required")
        mark("after row")
        guard let root = page.window?.contentView else { mark("no contentView"); XCTFail("no content view"); return }
        mark("ids: " + identifiers(root).filter { $0.hasPrefix("scope.firstRun.") }.joined(separator: ","))
        guard let optIn = findButton(root, "scope.firstRun.optin.zai") else { mark("no optin"); XCTFail("no opt-in box"); return }
        mark("found optin state=\(optIn.state.rawValue) title=\(optIn.title)")
        XCTAssertEqual(optIn.state, .off)
        XCTAssertTrue([SettingsScopeConsentView.zcodeOptInTitle.english, SettingsScopeConsentView.zcodeOptInTitle.chinese].contains(optIn.title))
        XCTAssertTrue(SettingsScopeConsentView.zcodeOptInTitle.chinese.contains("检测到扫码登录 · 勾选后读取本机登录信息查询额度（只读，不上传）"))
        entry.controller.chooseFirstRunOptIn(zcodeLogin, chosen: true)
        mark("after choose")
        guard let ticked = page.window?.contentView.flatMap({ findButton($0, "scope.firstRun.optin.zai") }) else { mark("no ticked"); XCTFail("no ticked box"); return }
        mark("ticked state=\(ticked.state.rawValue)")
        XCTAssertEqual(ticked.state, .on, "the box shows the user's tick")
        for text in texts(root) { XCTAssertFalse(text.contains("暂不支持") || text.lowercased().contains("unsupported"), text) }
        mark("after texts")
        // A layout the reader found nothing readable in says so plainly, not "unsupported".
        for block in [ScopeToolBlock.unsupportedLogin] {
            let line = SettingsScopeConsentView.blockLine(block, tool: "zai")
            XCTAssertFalse(line.chinese.contains("暂不支持"))
            XCTAssertFalse(line.english.lowercased().contains("unsupported"))
        }
        mark("end")
    }
}
