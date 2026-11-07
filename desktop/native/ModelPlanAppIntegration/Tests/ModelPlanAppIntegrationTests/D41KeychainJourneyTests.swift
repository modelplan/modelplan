// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
@_spi(DockResourceChecks) import ModelPlanDock
@testable import ModelPlanAppIntegration

private actor D41Engine: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore, facts: WireConsentFacts, rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "d41", floor: .init(storeEpoch: "d41", generation: 1), revision: 1)
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
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context, invalidRowCount: 0)))
        return .init(requestID: .string("d41-rows"))
    }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("d41-facts")) }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion {
        grants.append(request); actions.append(userAction); return .init(requestID: .string(request.requestId))
    }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

/// D41 through the normal entry: the first-run line asks once, the macOS dialog can only follow
/// Allow (the engine's foreground read follows the grant), and Later or a refusal leaves a
/// standing state on the Claude row and in Data & Privacy, with no further prompt.
@MainActor final class D41KeychainJourneyTests: XCTestCase {
    private static let scope = "claude.account_usage.saved_login"

    private func captures() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures", isDirectory: true).standardizedFileURL
    }
    private func facts(keychain: String) throws -> WireConsentFacts {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: captures().appendingPathComponent("WireConsentFacts.json"))) as? [String: Any])
        var scope = try XCTUnwrap((object["scopes"] as? [[String: Any]])?.first)
        scope["scope"] = Self.scope; scope["tool"] = "claude"; scope["route"] = "saved_login_api"; scope["state"] = "unset"
        scope["detected"] = true; scope["retired"] = false; scope["defaultCheck"] = true; scope["cleanupPending"] = false
        scope["keychain"] = keychain; scope.removeValue(forKey: "disabledReason")
        object["scopes"] = [scope]
        return try WireDecoder.decode(WireConsentFacts.self, from: JSONSerialization.data(withJSONObject: object))
    }
    private func rows(state: String, code: String) throws -> WireRowsSnapshot {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: captures().appendingPathComponent("WireRowsSnapshot.json"))) as? [String: Any])
        var projection = try XCTUnwrap(json["projection"] as? [String: Any])
        var row = try XCTUnwrap((projection["rows"] as? [[String: Any]])?.first)
        row["id"] = "claude"; row["vendorKey"] = "claude"; row["name"] = ["en": "Claude Code", "zh": "Claude Code"]
        row["state"] = state; row["consent"] = "implicit"; row["surfaces"] = ["dock", "menu", "settings"]
        row["reason"] = ["code": code, "text": ["en": "engine text", "zh": "engine text"]]
        row["expiresAt"] = "2099-01-01T00:00:00Z"; row.removeValue(forKey: "stateAfterExpiry"); row.removeValue(forKey: "nextStep")
        projection["rows"] = [row]
        json["projection"] = projection
        return try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
    }
    private func launch(keychain: String, rowState: String = "needs_keychain", code: String = "keychain_unset") async throws -> (EngineDockMenuApplication, D41Engine) {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("d41-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: profile) }
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        let consent = try facts(keychain: keychain), snapshot = try rows(state: rowState, code: code)
        final class Holder: @unchecked Sendable { var engine: D41Engine? }
        let holder = Holder()
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:]),
            settingsStore: store, createsNativePanels: false, dockEnvironment: normalEntryTestEnvironment,
            makeClient: { _, target in let value = D41Engine(store: target, facts: consent, rows: snapshot); holder.engine = value; return value }, activateSettings: {})
        await app.prepare(); await app.composition.start()
        let controller = app.scopeConsentEntry.controller
        for _ in 0..<500 where controller.facts == nil || (app.composition.accountMembers.members.isEmpty) { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertNotNil(controller.facts)
        addTeardownBlock { @MainActor in await app.composition.stop(); app.composition.dock.close() }
        return (app, try XCTUnwrap(holder.engine))
    }
    private func views(_ root: NSView) -> [NSView] { [root] + root.subviews.flatMap(views) }
    private func view(_ id: String, in root: NSView) -> NSView? { views(root).first { $0.accessibilityIdentifier() == id } }
    private func card(_ app: EngineDockMenuApplication) throws -> DockCardContent {
        let member = try XCTUnwrap(app.composition.accountMembers.members.first?.id)
        return try XCTUnwrap(try app.composition.dock.cardContent(for: member))
    }

    func testAllowIsTheOnlyThingThatSendsTheKeychainGrant() async throws {
        let (app, engine) = try await launch(keychain: "unset")
        let sheet = try app.scopeConsentEntry.makeFirstRunView(language: .english)
        let line = try XCTUnwrap(view("scope.firstRun.keychain", in: sheet) as? NSTextField)
        XCTAssertTrue(line.stringValue.contains("Keychain") && line.stringValue.contains("Always Allow"), line.stringValue)
        let grantsBefore = await engine.recorded()
        XCTAssertTrue(grantsBefore.isEmpty, "presenting the sheet asks nothing of the system")
        let allow = try XCTUnwrap(view("scope.keychain.allow", in: sheet) as? NSButton)
        XCTAssertEqual(allow.title, "Allow reading")
        allow.performClick(nil)
        var grants = [WireConsentGrantParams]()
        for _ in 0..<300 where grants.isEmpty { grants = await engine.recorded(); try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(grants.count, 1)
        XCTAssertEqual(grants.first?.allow, [Self.scope])
        XCTAssertEqual(grants.first?.keychain?[Self.scope], .allow)
        let actions = await engine.userActions()
        XCTAssertEqual(actions, 1, "the grant carries the user's action, which is what admits the foreground read")
    }

    func testLaterRecordsNothingAndLeavesTheStandingState() async throws {
        let (app, engine) = try await launch(keychain: "unset")
        let sheet = try app.scopeConsentEntry.makeFirstRunView(language: .english)
        (try XCTUnwrap(view("scope.keychain.later", in: sheet) as? NSButton)).performClick(nil)
        for _ in 0..<100 where view("scope.firstRun.keychain", in: sheet) != nil { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertNil(view("scope.firstRun.keychain", in: sheet), "Later closes the question")
        XCTAssertFalse(app.scopeConsentEntry.controller.asksForKeychainOnFirstRun)
        let grants = await engine.recorded()
        XCTAssertTrue(grants.isEmpty, "Later records nothing and starts no read")
        XCTAssertNotNil(view("scope.keychain.needed", in: app.scopeConsentEntry.view), "Data & Privacy states the need")
        XCTAssertNotNil(view("scope.keychain.allow", in: app.scopeConsentEntry.view), "with the same button")
        let content = try card(app)
        XCTAssertEqual(content.stateLabel, "Keychain access needed")
        XCTAssertEqual(content.actionLabel, "Allow reading")
    }

    func testDeniedIsShownAndNotAskedAgain() async throws {
        let (app, engine) = try await launch(keychain: "deny", code: "keychain_denied")
        let sheet = try app.scopeConsentEntry.makeFirstRunView(language: .english)
        XCTAssertNil(view("scope.firstRun.keychain", in: sheet), "a refusal is not asked again")
        XCTAssertNotNil(view("scope.keychain.needed", in: app.scopeConsentEntry.view))
        XCTAssertEqual(try card(app).actionLabel, "Allow reading")
        let grants = await engine.recorded()
        XCTAssertTrue(grants.isEmpty)
        // The same button is how a refusal is reversed.
        await app.scopeConsentEntry.controller.allowKeychain()
        let after = await engine.recorded()
        XCTAssertEqual(after.first?.keychain?[Self.scope], .allow)
    }

    func testALoginThatAlreadyReadsAsksNothing() async throws {
        let (app, _) = try await launch(keychain: "unset", rowState: "fresh", code: "ok")
        XCTAssertFalse(app.scopeConsentEntry.controller.asksForKeychainOnFirstRun)
        XCTAssertFalse(app.scopeConsentEntry.controller.needsKeychainAccess)
        XCTAssertEqual(try card(app).actionLabel, "")
    }
}
