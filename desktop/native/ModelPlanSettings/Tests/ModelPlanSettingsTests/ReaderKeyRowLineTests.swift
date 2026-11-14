// SPDX-License-Identifier: MIT
import Foundation
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanSettings

/// D90 manual key on the Settings tool row, against main's #954 OpenCode Go key line.
/// GLMREV 795 Q2 / DESIGN (terra) @6fa8c82e: a saved key with reading off must not say "no key found".
/// #954 consistency: with the key entry on the row, OpenCode Go shows one line (pointing to the entry), not two.
@MainActor final class ReaderKeyRowLineTests: XCTestCase {
    private typealias Path = (scope: String, tool: String, route: String, state: String, detected: Bool, defaultCheck: Bool)
    @MainActor private final class StoredKeyBackend: ReaderKeyBackend {
        let present: Bool
        init(present: Bool) { self.present = present }
        func status(_ provider: ReaderKeyProvider) async -> ReaderKeyStatus { .init(present: present, region: present && provider == .zai ? .global : nil) }
        func set(_ provider: ReaderKeyProvider, key: String, region: ReaderKeyRegion?) async -> ReaderKeyReply { .init(outcome: .failed, status: .init(present: present, region: nil)) }
        func test(_ provider: ReaderKeyProvider, key: String?, region: ReaderKeyRegion?) async -> ReaderKeyReply { .init(outcome: .failed, status: .init(present: present, region: nil)) }
        func remove(_ provider: ReaderKeyProvider) async -> ReaderKeyReply { .init(outcome: .failed, status: .init(present: present, region: nil)) }
        func allowReading(_ provider: ReaderKeyProvider) async -> Bool { false }
    }
    private func controller() -> ScopeConsentController {
        ScopeConsentController(commands: EngineClientScopeConsentCommands(client: ScopeConsentTestClient(), ready: { true }, makeGrant: { intent in
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
    private func views(_ root: NSView) -> [NSView] { [root] + root.subviews.flatMap { views($0) } }
    private func text(_ root: NSView, _ id: String) -> String? {
        (views(root).first { $0.accessibilityIdentifier() == id } as? NSTextField)?.stringValue
    }
    private func loadEntry(_ root: NSView, _ provider: String) async throws {
        let entry = try XCTUnwrap(views(root).first { $0.accessibilityIdentifier() == "readerkey." + provider } as? ReaderKeyEntryView)
        await entry.entry.load()
    }

    func testASavedKeyWithReadingOffDoesNotSayNoKeyWasFound() async throws {
        for present in [false, true] {
            let controller = controller()
            controller.receiveAcceptedFacts(try facts([("zai.account_usage.api_key", "zai", "api_key_api", "denied", true, true)]))
            let view = SettingsScopeConsentView(controller: controller, language: .english, compactTools: true)
            view.readerKeys = StoredKeyBackend(present: present)
            try await loadEntry(view, "zai")
            let line = try XCTUnwrap(text(view, "scope.settings.nokey.zai"), "present=\(present)")
            if present {
                XCTAssertTrue(line.hasPrefix("A key is saved, but reading ZCode / GLM is off"), line)
            } else {
                XCTAssertTrue(line.hasPrefix("No GLM key found"), line)
            }
        }
    }

    func testOpenCodeGoKeyMissingShowsOneLineThatPointsToTheEntry() async throws {
        let controller = controller()
        controller.receiveAcceptedFacts(try facts([
            ("opencodego.local_history", "opencodego", "local_log", "unset", true, true),
            ("opencodego.account_usage.api_key", "opencodego", "api_key_api", "unset", true, true),
        ]))
        controller.receiveAcceptedRows(try keyMissingRows())
        let view = SettingsScopeConsentView(controller: controller, language: .english, compactTools: true)
        view.readerKeys = StoredKeyBackend(present: false)
        try await loadEntry(view, "opencodego")
        let status = try XCTUnwrap(text(view, "scope.settings.status.opencodego"))
        XCTAssertTrue(status.hasPrefix("An OpenCode Go sign-in was found"), status)
        XCTAssertTrue(status.contains("OPENCODE_API_KEY") && status.contains("add it below"), status)
        XCTAssertNil(text(view, "scope.settings.nokey.opencodego"), "#954's key line already says why; no second no-key line")
        // Without the entry (no reader_key engine), #954's line is unchanged.
        let tool = try XCTUnwrap(controller.settingsTools.first { $0.tool == "opencodego" })
        XCTAssertFalse(try XCTUnwrap(SettingsScopeConsentView.keyMissingLine(tool)).english.contains("below"))
    }
}
