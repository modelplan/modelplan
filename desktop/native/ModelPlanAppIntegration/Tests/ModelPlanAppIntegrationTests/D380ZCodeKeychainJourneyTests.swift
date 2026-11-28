// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
@_spi(DockResourceChecks) import ModelPlanDock
@testable import ModelPlanAppIntegration

private actor D380Engine: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore, facts: WireConsentFacts, rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "d380", floor: .init(storeEpoch: "d380", generation: 1), revision: 1)
    var grants: [WireConsentGrantParams] = [], actions: [EngineUserAction?] = []
    init(store: EngineStore, facts: WireConsentFacts, rows: WireRowsSnapshot) { self.store = store; self.facts = facts; self.rows = rows }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        await store.consume(.consentChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: facts), delivery: context)))
        return context
    }
    func recorded() -> [WireConsentGrantParams] { grants }
    func userActions() -> Int { actions.compactMap { $0 }.count }
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func stop() async {}
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion {
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context), invalidRowCount: 0))
        return .init(requestID: .string("d380-rows"))
    }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("d380-facts")) }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion {
        grants.append(request); actions.append(userAction); return .init(requestID: .string(request.requestId))
    }
    private var refreshes = 0
    func refreshCount() -> Int { refreshes }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { refreshes += 1; throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

/// D380 through the normal entry: ZCode 3.19+ keeps its sign-in key in the Keychain. The engine row says
/// needs-Keychain only for such a store; Settings then states the need with the "Always Allow" hint and one
/// button, which is the consent and carries the user's action. Nothing reaches the system before it is pressed.
@MainActor final class D380ZCodeKeychainJourneyTests: XCTestCase {
    private static let scope = "zai.account_usage.saved_login"

    private func captures() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures", isDirectory: true).standardizedFileURL
    }
    private func facts(state: String, keychain: String) throws -> WireConsentFacts {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: captures().appendingPathComponent("WireConsentFacts.json"))) as? [String: Any])
        var scope = try XCTUnwrap((object["scopes"] as? [[String: Any]])?.first)
        scope["scope"] = Self.scope; scope["tool"] = "zai"; scope["route"] = "saved_login_api"; scope["state"] = state
        scope["detected"] = true; scope["retired"] = false; scope["defaultCheck"] = false; scope["cleanupPending"] = false
        scope["keychain"] = keychain; scope.removeValue(forKey: "disabledReason")
        object["scopes"] = [scope]
        return try WireDecoder.decode(WireConsentFacts.self, from: JSONSerialization.data(withJSONObject: object))
    }
    private func rows(state: String, code: String) throws -> WireRowsSnapshot {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: captures().appendingPathComponent("WireRowsSnapshot.json"))) as? [String: Any])
        var projection = try XCTUnwrap(json["projection"] as? [String: Any])
        var row = try XCTUnwrap((projection["rows"] as? [[String: Any]])?.first)
        row["id"] = "zai"; row["vendorKey"] = "zai"; row["name"] = ["en": "GLM", "zh": "GLM"]
        row["state"] = state; row["consent"] = "allowed"
        if state == "needs_keychain" {
            row["surfaces"] = ["menu", "settings"]; row["accounts"] = []
            row["nextStep"] = ["action": "open_settings_keychain", "text": ["en": "engine text", "zh": "engine text"]]
        } else {
            row["surfaces"] = ["dock", "menu", "settings"]; row.removeValue(forKey: "nextStep")
        }
        row["reason"] = ["code": code, "text": ["en": "engine text", "zh": "engine text"]]
        row["expiresAt"] = "2099-01-01T00:00:00Z"; row.removeValue(forKey: "stateAfterExpiry")
        projection["rows"] = [row]
        json["projection"] = projection
        return try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
    }
    private func launch(state: String = "allowed", keychain: String, rowState: String = "needs_keychain", code: String = "keychain_unset") async throws -> (EngineDockMenuApplication, D380Engine) {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("d380-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: profile) }
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        let consent = try facts(state: state, keychain: keychain), snapshot = try rows(state: rowState, code: code)
        final class Holder: @unchecked Sendable { var engine: D380Engine? }
        let holder = Holder()
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:]),
            settingsStore: store, createsNativePanels: false, dockEnvironment: normalEntryTestEnvironment,
            makeClient: { _, target in let value = D380Engine(store: target, facts: consent, rows: snapshot); holder.engine = value; return value }, activateSettings: {})
        await app.prepare(); await app.composition.start()
        let controller = app.scopeConsentEntry.controller
        for _ in 0..<500 where controller.facts == nil || controller.rowsSummary == nil { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertNotNil(controller.facts)
        addTeardownBlock { @MainActor in await app.composition.stop(); app.composition.dock.close() }
        return (app, try XCTUnwrap(holder.engine))
    }
    private func views(_ root: NSView) -> [NSView] { [root] + root.subviews.flatMap(views) }
    private func view(_ id: String, in root: NSView) -> NSView? { views(root).first { $0.accessibilityIdentifier() == id } }

    func testKeychainNeedSaysAlwaysAllowAndOnlyThePressSendsTheGrant() async throws {
        let (app, engine) = try await launch(keychain: "unset")
        let controller = app.scopeConsentEntry.controller
        XCTAssertTrue(controller.needsZCodeKeychainAccess)
        XCTAssertFalse(controller.needsKeychainAccess, "Claude Code's Keychain state is not ZCode's")
        let line = try XCTUnwrap(view("scope.keychain.zcode.needed", in: app.scopeConsentEntry.view) as? NSTextField)
        XCTAssertEqual(line.stringValue, SettingsScopeConsentView.zcodeKeychainLine.english)
        XCTAssertTrue(line.stringValue.contains("Always Allow"))
        XCTAssertTrue(SettingsScopeConsentView.zcodeKeychainLine.chinese.contains("始终允许"))
        XCTAssertNotNil(view("scope.keychain.zcode.allow", in: app.scopeConsentEntry.view))
        let before = await engine.recorded()
        XCTAssertTrue(before.isEmpty, "showing the need asks nothing of the system")
        for _ in 0..<500 where !controller.canMutate { try await Task.sleep(for: .milliseconds(10)) }
        await controller.allowKeychain(tool: "zai")
        let grants = await engine.recorded()
        XCTAssertEqual(grants.count, 1)
        XCTAssertEqual(grants.first?.allow, [Self.scope])
        XCTAssertEqual(grants.first?.keychain?[Self.scope], .allow)
        XCTAssertNil(grants.first?.keychain?["claude.account_usage.saved_login"])
        let actions = await engine.userActions()
        XCTAssertEqual(actions, 1, "the grant carries the user's action, which is what admits the foreground read")
    }
    func testAStoreThatReadsWithoutTheKeychainAsksNothing() async throws {
        let (app, engine) = try await launch(keychain: "unset", rowState: "fresh", code: "ok")
        XCTAssertFalse(app.scopeConsentEntry.controller.needsZCodeKeychainAccess)
        XCTAssertNil(view("scope.keychain.zcode.needed", in: app.scopeConsentEntry.view))
        let grants = await engine.recorded()
        XCTAssertTrue(grants.isEmpty)
    }
    func testNoKeychainQuestionBeforeTheSignInScopeIsAllowed() async throws {
        let (app, _) = try await launch(state: "unset", keychain: "unset")
        XCTAssertFalse(app.scopeConsentEntry.controller.needsZCodeKeychainAccess, "the saved-login consent comes first")
    }
}
