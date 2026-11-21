// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanSettings

/// Sampling 11-21 S1 (#928, D232): ordinary Gemini consent (first-run Done with Gemini ticked, Settings On,
/// Select all) also allowed the token-refresh extension, so the saved refresh token could reach Google's token
/// endpoint without the separate opt-in. The facts below are the engine's Gemini scope facts (consent.ScopeFacts:
/// the extension shares the saved-login route and is not pre-selected).
@MainActor final class S1GeminiRefreshOptInTests: XCTestCase {
    private typealias Path = (scope: String, tool: String, route: String, state: String, detected: Bool, defaultCheck: Bool)
    private let refresh = "gemini.account_usage.token_refresh"
    private func controller() -> ScopeConsentController {
        ScopeConsentController(commands: EngineClientScopeConsentCommands(client: ScopeConsentTestClient(), ready: { true }, makeGrant: { intent in
            try .init(requestId: intent.requestID, expectStoreEpoch: "synthetic", expectGeneration: 1, consentTextVersion: 17,
                      allow: intent.allowIDs, deny: intent.denyIDs, forget: intent.forgetIDs)
        }))
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
    private func gemini(refreshState: String = "unset", others: String = "unset") throws -> WireConsentFacts {
        try facts([
            ("gemini.local_history", "gemini", "local_log", others, true, true),
            ("gemini.account_usage.saved_login", "gemini", "saved_login_api", others, true, false),
            (refresh, "gemini", "saved_login_api", refreshState, true, false),
        ])
    }

    func testFirstRunDoneWithGeminiTickedLeavesRefreshUnset() throws {
        let controller = controller()
        controller.receiveAcceptedFacts(try gemini())
        XCTAssertTrue(controller.isFirstRunToolChosen("gemini"))
        XCTAssertFalse(controller.firstRunTools.first { $0.tool == "gemini" }?.scopes.contains(refresh) ?? true, "the refresh path is not part of the Gemini row")
        let intent = try XCTUnwrap(controller.firstRunChoiceIntent())
        XCTAssertEqual(intent.allowIDs, ["gemini.account_usage.saved_login", "gemini.local_history"])
        XCTAssertFalse(intent.denyIDs.contains(refresh))
    }

    func testSettingsOnAndSelectAllLeaveRefreshUnset() throws {
        let controller = controller()
        controller.receiveAcceptedFacts(try gemini(others: "denied"))
        XCTAssertNotNil(controller.requestToolChoice("gemini", on: true))
        guard case .confirmation(let on) = controller.phase else { return XCTFail("switching Gemini on asks to confirm") }
        XCTAssertEqual(on.intent.allowIDs, ["gemini.account_usage.saved_login", "gemini.local_history"])
        controller.cancelConfirmation()
        controller.selectAll()
        XCTAssertFalse(controller.selectedIDs.contains(refresh), "Select all never includes the separate opt-in")
    }

    func testTheSeparateChoiceAllowsOnlyRefreshAndOffRefusesIt() throws {
        let controller = controller()
        controller.receiveAcceptedFacts(try gemini(others: "allowed"))
        controller.choose(refresh, selected: true)
        XCTAssertNotNil(controller.requestAllow())
        guard case .confirmation(let optIn) = controller.phase else { return XCTFail("the separate choice asks to confirm") }
        XCTAssertEqual(optIn.intent.allowIDs, [refresh])
        controller.cancelConfirmation()
        controller.receiveAcceptedFacts(try gemini(refreshState: "allowed", others: "allowed"))
        XCTAssertNotNil(controller.requestToolChoice("gemini", on: false))
        guard case .confirmation(let off) = controller.phase else { return XCTFail("switching Gemini off asks to confirm") }
        XCTAssertTrue(off.intent.denyIDs.contains(refresh), "Off refuses the allowed refresh path too")
    }
}
