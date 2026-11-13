// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanSettings
@testable import ModelPlanAppIntegration

final class ConsentContractTests: XCTestCase {
    private func tool(_ id: String = "codex", access: CommunityConsentAccessClass = .standard,
                      detected: Bool = true, allowed: Bool = false, keychain: CommunityConsentKeychain = .unset) -> CommunityConsentToolFacts {
        .init(id: id, displayName: "Synthetic " + id, accessClass: access, detected: detected, allowed: allowed,
              backend: "native", readerId: "native:" + id, keychain: keychain, hosts: ["provider.example.test"])
    }
    private func preview(_ tools: [CommunityConsentToolFacts], mode: SettingsReadingMode = .automatic) throws -> CommunityConsentPreviewFacts {
        try .init(generation: 12, consentTextVersion: 3, mode: mode, tools: tools,
                  consentText: .init("Exact synthetic English text", "精确的合成中文说明"))
    }
    func testPreviewMapsPresenceAndCanonicalConsentWithoutInventingReadings() throws {
        let facts = try preview([tool(), tool("cursor", access: .browserSession), tool("future-tool")])
        let snapshot = try facts.projecting()
        XCTAssertEqual(snapshot.tools.first?.presence, .detected); XCTAssertEqual(snapshot.tools.first?.authorization, .noConsent)
        XCTAssertEqual(snapshot.tools.first?.quota, .unknown); XCTAssertEqual(snapshot.tools.first?.binding, .unknown)
        XCTAssertTrue(snapshot.subscriptions.isEmpty); XCTAssertEqual(snapshot.unrecognizedTools.map(\.id), ["future-tool"])
        XCTAssertEqual(snapshot.consentPreview?.notice, facts.consentText)
        XCTAssertEqual(snapshot.tools.first?.keychain, .unset)
        XCTAssertEqual(snapshot.tools.first?.providerHosts, ["provider.example.test"])
        XCTAssertEqual(SettingsConnectionIntent(snapshot: snapshot).selected, [.codex])
    }
    func testGrantEncodesOnlyFinalNamedFieldsAndAnEmptyKeychainObject() throws {
        let facts = try preview([tool(), tool("claude", allowed: true)])
        let id = UUID(), request = SettingsConnectionRequestContext(id: id, expectedConsentGeneration: 12, consentTextVersion: 3)
        let payload = try CommunityConsentGrantPayload(preview: facts, allow: [.codex], deny: [.claude], request: request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["requestId", "expectGeneration", "consentTextVersion", "allow", "deny", "keychain"])
        XCTAssertEqual(object["requestId"] as? String, id.uuidString)
        XCTAssertEqual(object["expectGeneration"] as? Int, 12); XCTAssertEqual(object["consentTextVersion"] as? Int, 3)
        XCTAssertEqual(object["allow"] as? [String], ["codex"]); XCTAssertEqual(object["deny"] as? [String], ["claude"])
        XCTAssertEqual((object["keychain"] as? [String: Any])?.count, 0)
    }
    func testStaleVersionGenerationDuplicatesAndUnsupportedToolClassesAreRejected() throws {
        let request = SettingsConnectionRequestContext(id: UUID(), expectedConsentGeneration: 12, consentTextVersion: 3)
        for facts in [try preview([tool(access: .browserSession)]), try preview([tool(access: .notRead)]),
                      try preview([tool(detected: false)])] {
            XCTAssertThrowsError(try CommunityConsentGrantPayload(preview: facts, allow: [.codex], deny: [], request: request))
        }
        let facts = try preview([tool()])
        XCTAssertThrowsError(try CommunityConsentGrantPayload(preview: facts, allow: [.codex], deny: [.codex], request: request))
        XCTAssertThrowsError(try CommunityConsentGrantPayload(preview: facts, allow: [.codex], deny: [],
            request: .init(id: UUID(), expectedConsentGeneration: 11, consentTextVersion: 3)))
        XCTAssertThrowsError(try CommunityConsentGrantPayload(preview: facts, allow: [.codex], deny: [],
            request: .init(id: UUID(), expectedConsentGeneration: 12, consentTextVersion: 2)))
        XCTAssertThrowsError(try CommunityConsentGrantPayload(preview: facts, allow: [.cursor], deny: [], request: request))
        let keychain = try preview([tool(keychain: .denied)], mode: .off)
        let revoke = try CommunityConsentGrantPayload(preview: keychain, allow: [], deny: [.codex], request: request)
        XCTAssertEqual(revoke.deny, ["codex"]); XCTAssertTrue(revoke.keychain.isEmpty, "revocation must not require or manufacture Keychain permission")
        for state in [CommunityConsentKeychain.unset, .denied, .allowed] {
            let preview = try self.preview([tool(keychain: state)])
            let grant = try CommunityConsentGrantPayload(preview: preview, allow: [.codex], deny: [], request: request)
            XCTAssertTrue(grant.keychain.isEmpty)
            XCTAssertEqual(try preview.projecting().tools.first?.keychain, state)
        }
    }
    func testCanonicalOffModeBlocksGrantAndPreviewDoesNotEraseOwnershipEvidence() throws {
        let facts = try preview([tool(allowed: true)], mode: .off)
        let previous = try SettingsConnectionSnapshot(tools: [.init(tool: .codex, quota: .stale, binding: .verified(references: ["verified-a"]))],
            subscriptions: [.init(reference: "verified-a", tool: .codex, name: .init("Synthetic", "合成"))])
        let result = try facts.projecting(over: previous)
        XCTAssertEqual(result.mode, .off); XCTAssertEqual(result.tools.first?.connection, .off)
        XCTAssertEqual(result.tools.first?.authorization, .allowed); XCTAssertEqual(result.tools.first?.quota, .stale)
        XCTAssertEqual(result.subscriptions, previous.subscriptions)
        XCTAssertThrowsError(try CommunityConsentGrantPayload(preview: facts, allow: [.codex], deny: [],
            request: .init(id: UUID(), expectedConsentGeneration: 12, consentTextVersion: 3)))
    }
    func testMissingPreviewToolsBecomeUnknownIneligibleWhileEvidenceRemains() throws {
        let previous = try SettingsConnectionSnapshot(tools: [.init(tool: .codex, presence: .detected, authorization: .allowed, support: .full)])
        let result = try preview([]).projecting(over: previous)
        XCTAssertEqual(result.tools.first?.presence, .unknown); XCTAssertEqual(result.tools.first?.authorization, .unknown)
        XCTAssertFalse(result.tools.first!.canRequestConnection)
    }
    func testHostsAreDisplayMetadataAndUnsetDoesNotBecomeKeychainGrant() throws {
        let value = tool(keychain: .unset)
        let snapshot = try preview([value]).projecting()
        XCTAssertTrue(snapshot.tools.first!.canRequestConnection); XCTAssertEqual(snapshot.tools.first!.keychain, .unset)
        let describedEndpoint = CommunityConsentToolFacts(id: "codex", displayName: "Codex", accessClass: .standard,
            detected: true, allowed: false, backend: "native", readerId: "native:codex", keychain: .unset,
            hosts: ["https://account@example.test/private"])
        let described = try preview([describedEndpoint]).projecting()
        XCTAssertEqual(described.tools.first?.providerHosts, ["example.test"], "URL user info and path are not display labels or authority")
        XCTAssertEqual(described.tools.first?.keychain, .unset)
        XCTAssertEqual(String(data: try JSONEncoder().encode(CommunityConsentKeychainDecision.allow), encoding: .utf8), "\"allow\"")
        XCTAssertEqual(String(data: try JSONEncoder().encode(CommunityConsentKeychainDecision.deny), encoding: .utf8), "\"deny\"")
    }
    func testExplicitClaudeKeychainAllowsOnlySupportedSelectedNativeTool() throws {
        let request = SettingsConnectionRequestContext(id: UUID(), expectedConsentGeneration: 12, consentTextVersion: 3, keychainAllow: [.claude])
        let facts = try preview([tool("claude")])
        XCTAssertTrue(try facts.projecting().tools[0].keychainEligible)
        let payload = try CommunityConsentGrantPayload(preview: facts, allow: [.claude], deny: [], request: request)
        XCTAssertEqual(payload.keychain["claude"], .allow)
        for (allow, deny) in [([SettingsConnectionTool](), [SettingsConnectionTool.claude]), ([.codex], [])] {
            XCTAssertThrowsError(try CommunityConsentGrantPayload(preview: facts, allow: allow, deny: deny, request: request))
        }
        for value in [tool("claude", access: .browserSession), tool("claude", detected: false), tool(),
                      CommunityConsentToolFacts(id: "claude", displayName: "Synthetic", accessClass: .standard,
                          detected: true, allowed: false, backend: "codexbar", readerId: "codexbar:claude", keychain: .unset)] {
            let preview = try self.preview([value])
            XCTAssertFalse(try preview.projecting().tools[0].keychainEligible)
            XCTAssertThrowsError(try CommunityConsentGrantPayload(preview: preview, allow: [.claude], deny: [], request: request))
        }
        var intent = SettingsConnectionIntent(snapshot: try facts.projecting())
        XCTAssertTrue(intent.orderedKeychainTools.isEmpty)
        intent.selectKeychain(.codex, enabled: true); XCTAssertTrue(intent.orderedKeychainTools.isEmpty)
        intent.selectKeychain(.claude, enabled: true); XCTAssertEqual(intent.orderedKeychainTools, [.claude])
        intent.select(.claude, enabled: false); XCTAssertTrue(intent.orderedKeychainTools.isEmpty)
    }

}
