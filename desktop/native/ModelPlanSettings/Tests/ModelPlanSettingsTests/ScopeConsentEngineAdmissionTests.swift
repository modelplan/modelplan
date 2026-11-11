// SPDX-License-Identifier: MIT
import Foundation
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanSettings

/// G3-67 (build 14b): Settings ticked tools the engine did not read. A path that is only on by the compiled default
/// is shown as read only when the engine's own rows agree; a tick then completes through the grant and the engine's
/// accepted consent and rows, never through local state alone.
@MainActor final class ScopeConsentEngineAdmissionTests: XCTestCase {
    private func controller(_ engine: ScopeConsentTestClient) -> ScopeConsentController {
        ScopeConsentController(commands: EngineClientScopeConsentCommands(client: engine, ready: { true }, makeGrant: { intent in
            try .init(requestId: intent.requestID, expectStoreEpoch: "synthetic", expectGeneration: 1, consentTextVersion: 17, allow: intent.allowIDs, deny: intent.denyIDs)
        }))
    }
    private func facts(localAllowed: Bool) throws -> WireConsentFacts {
        let base = try ScopeConsentFixtures.facts()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(base)) as? [String: Any])
        var scopes = try XCTUnwrap(object["scopes"] as? [[String: Any]])
        for index in scopes.indices where scopes[index]["scope"] as? String == ScopeConsentFixtures.local {
            scopes[index]["state"] = localAllowed ? "allowed" : "unset"
        }
        object["scopes"] = scopes
        return try WireDecoder.decode(WireConsentFacts.self, from: JSONSerialization.data(withJSONObject: object))
    }
    /// Rows with at most one tool row (the tool of the fixture's local path), carrying the engine's consent for it.
    private func rows(toolConsent: String?) throws -> WireRowsSnapshot {
        var root = URL(fileURLWithPath: #filePath).resolvingSymlinksInPath().deletingLastPathComponent()
        while root.path != "/", !FileManager.default.fileExists(atPath: root.appendingPathComponent("schema/app-cli/captures/WireRowsSnapshot.json").path) { root.deleteLastPathComponent() }
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("schema/app-cli/captures/WireRowsSnapshot.json"))) as? [String: Any])
        var projection = try XCTUnwrap(object["projection"] as? [String: Any])
        var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
        if let toolConsent {
            var row = try XCTUnwrap(rows.first)
            row["id"] = "gemini"; row["kind"] = "tool"; row["consent"] = toolConsent
            rows = [row]
        } else { rows = [] }
        projection["rows"] = rows; object["projection"] = projection
        return try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
    }
    func testDefaultOnPathIsNotTickedWhileTheEngineAdmitsNothing() throws {
        let controller = controller(ScopeConsentTestClient())
        controller.receiveAcceptedFacts(try facts(localAllowed: false))
        XCTAssertTrue(controller.isReading(ScopeConsentFixtures.local), "before any rows the compiled default stands")
        controller.receiveAcceptedRows(try rows(toolConsent: nil))
        XCTAssertFalse(controller.isReading(ScopeConsentFixtures.local), "the engine has no row for the tool: it is not read, so it is not ticked")
        controller.receiveAcceptedRows(try rows(toolConsent: "unset"))
        XCTAssertFalse(controller.isReading(ScopeConsentFixtures.local))
        controller.receiveAcceptedRows(try rows(toolConsent: "implicit"))
        XCTAssertTrue(controller.isReading(ScopeConsentFixtures.local), "the engine reads it by default")
    }
    func testTickGrantsThenTheEngineConsentAndRowMakeTheToolRead() async throws {
        let engine = ScopeConsentTestClient()
        let controller = controller(engine)
        controller.receiveAcceptedFacts(try facts(localAllowed: false))
        controller.receiveAcceptedRows(try rows(toolConsent: nil))
        XCTAssertFalse(controller.isReading(ScopeConsentFixtures.local))
        controller.choose(ScopeConsentFixtures.local, selected: true)
        let request = try XCTUnwrap(controller.requestAllow())
        await controller.confirm(request.id)
        let sent = await engine.recordedGrants()
        XCTAssertEqual(sent.first?.allow, [ScopeConsentFixtures.local], "the tick is sent to the engine")
        XCTAssertFalse(controller.isReading(ScopeConsentFixtures.local), "the grant alone changes nothing: only accepted facts do")
        controller.receiveAcceptedFacts(try facts(localAllowed: true))
        controller.receiveAcceptedRows(try rows(toolConsent: "allowed"))
        XCTAssertTrue(controller.isReading(ScopeConsentFixtures.local))
    }
    func testStatusLineAgreesWithTheSwitchWhenTheEngineIsNotReading() throws {
        let controller = controller(ScopeConsentTestClient())
        controller.receiveAcceptedFacts(try facts(localAllowed: false))
        let id = ScopeConsentFixtures.local
        XCTAssertEqual(SettingsScopeConsentView.pathStatus(controller, id: id, denied: false).english.hasPrefix("On by default"), true, "before rows the default stands")
        controller.receiveAcceptedRows(try rows(toolConsent: nil))
        XCTAssertFalse(controller.isReading(id))
        let status = SettingsScopeConsentView.pathStatus(controller, id: id, denied: false)
        XCTAssertFalse(status.english.hasPrefix("On by default"), "the switch is unticked, so the line must not claim it is on")
        XCTAssertTrue(status.english.hasPrefix("Not being read"))
        XCTAssertTrue(status.chinese.hasPrefix("目前未读取"))
        XCTAssertFalse(controller.selectedIDs.contains(id), "Settings does not pre-select a path the engine does not read")
        let view = SettingsScopeConsentView(controller: controller, language: .english)
        let box = try XCTUnwrap(find(view, id: "scope.allow." + id))
        XCTAssertEqual(box.state, .off, "the switch agrees: unticked, Allow this path")
        controller.choose(id, selected: true)
        XCTAssertNotNil(controller.requestAllow(), "ticking it then allows the path through the normal confirm")
        controller.receiveAcceptedRows(try rows(toolConsent: "implicit"))
        XCTAssertTrue(SettingsScopeConsentView.pathStatus(controller, id: id, denied: false).english.hasPrefix("On by default"))
    }
    private func find(_ root: NSView, id: String) -> NSButton? {
        if let button = root as? NSButton, button.accessibilityIdentifier() == id { return button }
        for child in root.subviews { if let hit = find(child, id: id) { return hit } }
        return nil
    }
}
