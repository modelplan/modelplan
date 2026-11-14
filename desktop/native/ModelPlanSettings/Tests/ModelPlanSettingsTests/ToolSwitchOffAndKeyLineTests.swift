// SPDX-License-Identifier: MIT
import Foundation
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanSettings

/// Build 14f sampling (#910, findings 2 and 3).
/// 2: switching a tool off in Settings refused only the paths detected at that moment, so an allowed path that was
///    undetected then (an absent OpenCode Go key) resumed reading against the user's Off once it came back.
/// 3: with a found OpenCode Go subscription and the engine's key_missing row, Settings hid the only line saying why
///    no quota is shown (the reader takes the key only from OPENCODE_API_KEY; D230 never reads the saved key).
@MainActor final class ToolSwitchOffAndKeyLineTests: XCTestCase {
    private typealias Path = (scope: String, tool: String, route: String, state: String, detected: Bool, defaultCheck: Bool)
    private func controller(_ engine: ScopeConsentTestClient = ScopeConsentTestClient()) -> ScopeConsentController {
        ScopeConsentController(commands: EngineClientScopeConsentCommands(client: engine, ready: { true }, makeGrant: { intent in
            try .init(requestId: intent.requestID, expectStoreEpoch: "synthetic", expectGeneration: 1, consentTextVersion: 17,
                      allow: intent.allowIDs, deny: intent.denyIDs, forget: intent.forgetIDs)
        }))
    }
    private func captures(_ name: String) throws -> URL {
        var root = URL(fileURLWithPath: #filePath).resolvingSymlinksInPath().deletingLastPathComponent()
        while root.path != "/", !FileManager.default.fileExists(atPath: root.appendingPathComponent("schema/app-cli/captures/" + name).path) { root.deleteLastPathComponent() }
        return root.appendingPathComponent("schema/app-cli/captures/" + name)
    }
    private func facts(_ paths: [Path]) throws -> WireConsentFacts {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: captures("WireConsentFacts.json"))) as? [String: Any])
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
    /// The engine's OpenCode Go row: installed, key missing (what main's reader reports without OPENCODE_API_KEY).
    private func keyMissingRows() throws -> WireRowsSnapshot {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: captures("WireRowsSnapshot.json"))) as? [String: Any])
        var projection = try XCTUnwrap(json["projection"] as? [String: Any])
        var row = try XCTUnwrap((projection["rows"] as? [[String: Any]])?.first)
        row["id"] = "opencodego"; row["vendorKey"] = "opencodego"; row["name"] = ["en": "OpenCode Go", "zh": "OpenCode Go"]
        row["kind"] = "tool"; row["state"] = "needs_action"; row["consent"] = "implicit"; row["surfaces"] = ["menu", "settings"]
        row["accounts"] = [[String: Any]]()
        row["reason"] = ["code": "key_missing", "text": ["en": "engine text", "zh": "engine text"]]
        row["expiresAt"] = "2099-01-01T00:00:00Z"; row.removeValue(forKey: "stateAfterExpiry"); row.removeValue(forKey: "nextStep")
        projection["rows"] = [row]; json["projection"] = projection
        return try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
    }
    private func denyIDs(_ controller: ScopeConsentController, off tool: String) throws -> [String] {
        XCTAssertNotNil(controller.requestToolChoice(tool, on: false))
        guard case .confirmation(let confirmation) = controller.phase else { XCTFail("switching a tool off asks to confirm"); return [] }
        return confirmation.intent.denyIDs
    }

    /// Finding 2: the OpenCode Go key is absent while the user switches OpenCode off; its allowed key path is refused too.
    func testSwitchingOpenCodeOffRefusesItsUndetectedKeyPath() throws {
        let controller = controller()
        controller.receiveAcceptedFacts(try facts([
            ("opencodego.local_history", "opencodego", "local_log", "allowed", true, true),
            ("opencodego.account_usage.api_key", "opencodego", "api_key_api", "allowed", false, true),
        ]))
        XCTAssertEqual(controller.firstRunTools.first { $0.tool == "opencodego" }?.scopes, ["opencodego.local_history"], "the key path is undetected now")
        XCTAssertEqual(try denyIDs(controller, off: "opencodego"), ["opencodego.account_usage.api_key", "opencodego.local_history"], "deny ids are sorted (ScopeConsentIntent.denyIDs)")
    }

    /// Finding 2, every tool: a saved allow or a default-on path that is undetected now is refused with the tool;
    /// an already refused path is not sent again, and another tool's paths are untouched.
    func testSwitchingAnyToolOffRefusesEverySavedOrDefaultOnPath() throws {
        let controller = controller()
        controller.receiveAcceptedFacts(try facts([
            ("cursor.local_history", "cursor", "local_log", "unset", true, true),
            ("cursor.account_usage.saved_login", "cursor", "saved_login_api", "allowed", false, false),
            ("cursor.account_usage.api_key", "cursor", "api_key_api", "unset", false, true),
            ("cursor.runtime_usage", "cursor", "runtime_rpc", "denied", false, true),
            ("gemini.local_history", "gemini", "local_log", "allowed", true, true),
        ]))
        XCTAssertEqual(try denyIDs(controller, off: "cursor"),
                       ["cursor.account_usage.api_key", "cursor.account_usage.saved_login", "cursor.local_history"], "deny ids are sorted")
        controller.cancelConfirmation()
        // Switching on still allows only the paths the row shows.
        controller.receiveAcceptedFacts(try facts([
            ("cursor.local_history", "cursor", "local_log", "denied", true, true),
            ("cursor.account_usage.saved_login", "cursor", "saved_login_api", "denied", false, false),
        ]))
        XCTAssertNotNil(controller.requestToolChoice("cursor", on: true))
        guard case .confirmation(let on) = controller.phase else { return XCTFail("switching a tool on asks to confirm") }
        XCTAssertEqual(on.intent.allowIDs, ["cursor.local_history"])
    }

    /// Finding 3: a found OpenCode Go subscription (key path detected) with the engine's key_missing row still
    /// says why no quota is shown; with no subscription found the existing line stays.
    func testFoundSubscriptionWithAMissingKeyStillShowsTheKeyLine() throws {
        let controller = controller()
        controller.receiveAcceptedFacts(try facts([
            ("opencodego.local_history", "opencodego", "local_log", "unset", true, true),
            ("opencodego.account_usage.api_key", "opencodego", "api_key_api", "unset", true, true),
        ]))
        controller.receiveAcceptedRows(try keyMissingRows())
        let tool = try XCTUnwrap(controller.settingsTools.first { $0.tool == "opencodego" })
        XCTAssertTrue(tool.keyMissing); XCTAssertTrue(tool.routes.contains(.apiKeyApi))
        let view = SettingsScopeConsentView(controller: controller, language: .english, compactTools: true)
        let status = try XCTUnwrap(views(view).first { $0.accessibilityIdentifier() == "scope.settings.status.opencodego" } as? NSTextField,
                                   "the row says why no OpenCode Go quota is shown")
        XCTAssertTrue(status.stringValue.hasPrefix("An OpenCode Go sign-in was found"), status.stringValue)
        XCTAssertTrue(status.stringValue.contains("OPENCODE_API_KEY"), status.stringValue)
        let chinese = try XCTUnwrap(SettingsScopeConsentView.keyMissingLine(tool)).chinese
        XCTAssertTrue(chinese.hasPrefix("找到了 OpenCode Go 登录"), chinese)
        let noSubscription = FirstRunTool(tool: "opencodego", scopes: ["opencodego.local_history"], routes: [.localLog], block: nil,
                                          promptsKeychain: false, keyMissing: true)
        XCTAssertTrue(try XCTUnwrap(SettingsScopeConsentView.keyMissingLine(noSubscription)).english.hasPrefix("No OpenCode Go subscription key was found"))
        XCTAssertNil(SettingsScopeConsentView.keyMissingLine(FirstRunTool(tool: "cursor", scopes: [], routes: [], block: nil, promptsKeychain: false, keyMissing: true)))
    }

    private func views(_ root: NSView) -> [NSView] { [root] + root.subviews.flatMap { views($0) } }
}
