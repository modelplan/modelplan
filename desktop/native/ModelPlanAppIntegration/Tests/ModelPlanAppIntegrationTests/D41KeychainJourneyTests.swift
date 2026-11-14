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
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context), invalidRowCount: 0))
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
        row["state"] = state; row["consent"] = "implicit"
        if state == "needs_keychain" {
            // What the engine emits since G3-38: no value, so no Dock ring. The Keychain prompt is
            // reached through Settings and the menu (D87 puts fix actions in Settings rows).
            row["surfaces"] = ["menu", "settings"]; row["accounts"] = []
            row["nextStep"] = ["action": "open_settings_keychain", "text": ["en": "Allow Keychain for Claude Code in Settings", "zh": "在设置中允许 Claude Code 访问钥匙串"]]
        } else if state == "pending" {
            // G3-38: a tool waiting for its first read has no ring; the Dock summary says so at t=0.
            row["surfaces"] = ["menu", "settings"]; row["accounts"] = []
            row["nextStep"] = ["action": "none", "text": ["en": "Wait for the next available reading", "zh": "等待下一次可用读数"]]
            projection["rowsSummary"] = ["state": "pending", "reason": ["code": "not_read_yet", "text": ["en": "Waiting for the first reading", "zh": "等待首次读取"]],
                                         "text": ["en": "Reading Claude Code…", "zh": "正在读取 Claude Code…"], "nextStep": NSNull()]
        } else {
            row["surfaces"] = ["dock", "menu", "settings"]; row.removeValue(forKey: "nextStep")
        }
        row["reason"] = ["code": code, "text": ["en": "engine text", "zh": "engine text"]]
        row["expiresAt"] = "2099-01-01T00:00:00Z"; row.removeValue(forKey: "stateAfterExpiry")
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
        for _ in 0..<500 where controller.facts == nil || controller.rowsSummary == nil || (rowState == "fresh" && app.composition.accountMembers.members.isEmpty) { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertNotNil(controller.facts)
        addTeardownBlock { @MainActor in await app.composition.stop(); app.composition.dock.close() }
        return (app, try XCTUnwrap(holder.engine))
    }
    /// The consent buttons act only in a visible window, as a real click would.
    private func show(_ content: NSView) {
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 560, height: 480), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = content; window.orderFrontRegardless()
        addTeardownBlock { @MainActor in window.orderOut(nil) }
    }
    private func views(_ root: NSView) -> [NSView] { [root] + root.subviews.flatMap(views) }
    private func view(_ id: String, in root: NSView) -> NSView? { views(root).first { $0.accessibilityIdentifier() == id } }
    private func card(_ app: EngineDockMenuApplication) throws -> DockCardContent {
        let member = try XCTUnwrap(app.composition.accountMembers.members.first?.id)
        return try XCTUnwrap(try app.composition.dock.cardContent(for: member))
    }

    /// G3-45 (owner 11-08) replaced the first-run Allow/Later line with the tool list; FR-9-11 (owner 11-12) puts Allow and
    /// Later back on Claude Code's row. The row says macOS asks once for the Keychain, and Done with the row checked
    /// is still the consent when neither button was pressed.
    /// Presenting the page still asks nothing of the system.
    func testDoneWithClaudeCheckedIsTheOnlyThingThatSendsTheKeychainGrant() async throws {
        let (app, engine) = try await launch(keychain: "unset")
        let sheet = try app.scopeConsentEntry.makeFirstRunView(language: .english)
        show(sheet)
        let line = try XCTUnwrap(view("scope.firstRun.reads.claude", in: sheet) as? NSTextField)
        XCTAssertEqual(line.stringValue, FirstRunCopy.keychainLine.english)
        XCTAssertNotNil(view("scope.firstRun.keychain.allow", in: sheet), "FR-9-11: Allow sits on the Claude Code row")
        XCTAssertNotNil(view("scope.firstRun.keychain.later", in: sheet), "and so does Later")
        let box = try XCTUnwrap(view("scope.firstRun.tool.claude", in: sheet) as? NSButton)
        XCTAssertEqual(box.state, .on, "a readable tool starts checked")
        XCTAssertNil(view("scope.keychain.allow", in: sheet), "no separate Keychain button on the first-run page")
        let grantsBefore = await engine.recorded()
        XCTAssertTrue(grantsBefore.isEmpty, "presenting the sheet asks nothing of the system")
        let committed = await app.scopeConsentEntry.controller.commitFirstRunChoices()
        XCTAssertTrue(committed)
        let grants = await engine.recorded()
        XCTAssertEqual(grants.count, 1)
        XCTAssertEqual(grants.first?.allow, [Self.scope])
        XCTAssertEqual(grants.first?.deny, [])
        XCTAssertEqual(grants.first?.keychain?[Self.scope], .allow)
        let actions = await engine.userActions()
        XCTAssertEqual(actions, 1, "the grant carries the user's action, which is what admits the foreground read")
    }

    /// FR-9-11 / D41: Allow on the Claude Code row is the Keychain consent, sent with the user's own action; nothing is
    /// sent before it is pressed.
    func testAllowOnTheClaudeRowSendsTheKeychainGrantWithTheUsersAction() async throws {
        let (app, engine) = try await launch(keychain: "unset")
        let sheet = try app.scopeConsentEntry.makeFirstRunView(language: .english)
        show(sheet)
        let allow = try XCTUnwrap(view("scope.firstRun.keychain.allow", in: sheet) as? NSButton)
        XCTAssertEqual(allow.title, "Allow")
        let before = await engine.recorded()
        XCTAssertTrue(before.isEmpty, "showing the row asks nothing of the system")
        allow.performClick(nil)
        var grants: [WireConsentGrantParams] = []
        for _ in 0..<300 where grants.isEmpty { try await Task.sleep(for: .milliseconds(10)); grants = await engine.recorded() }
        XCTAssertEqual(grants.count, 1)
        XCTAssertEqual(grants.first?.allow, [Self.scope])
        XCTAssertEqual(grants.first?.keychain?[Self.scope], .allow)
        let actions = await engine.userActions()
        XCTAssertEqual(actions, 1, "the grant carries the user's action, which is what admits the foreground read")
    }

    /// FR-9-11 / D41: Later hides the two buttons and asks nothing; Done then allows the tool without a Keychain read.
    func testLaterOnTheClaudeRowSendsNoKeychainRead() async throws {
        let (app, engine) = try await launch(keychain: "unset")
        let sheet = try app.scopeConsentEntry.makeFirstRunView(language: .english)
        show(sheet)
        let later = try XCTUnwrap(view("scope.firstRun.keychain.later", in: sheet) as? NSButton)
        XCTAssertEqual(later.title, "Later")
        later.performClick(nil)
        XCTAssertNil(view("scope.firstRun.keychain.allow", in: sheet), "after Later the question is not asked again on this page")
        XCTAssertNil(view("scope.firstRun.keychain.later", in: sheet))
        let none = await engine.recorded()
        XCTAssertTrue(none.isEmpty, "Later records nothing")
        let committed = await app.scopeConsentEntry.controller.commitFirstRunChoices()
        XCTAssertTrue(committed)
        let grants = await engine.recorded()
        XCTAssertEqual(grants.count, 1)
        XCTAssertEqual(grants.first?.allow, [Self.scope])
        XCTAssertTrue(grants.first?.keychain?.isEmpty != false, "no Keychain read after Later")
    }

    /// Unticking Claude Code requests no Keychain read and the standing state stays visible. It is
    /// the only tool here, so D61 (3) also holds Done back: nothing is sent at all.
    func testUncheckedClaudeIsRefusedWithoutAKeychainRequest() async throws {
        let (app, engine) = try await launch(keychain: "unset")
        let sheet = try app.scopeConsentEntry.makeFirstRunView(language: .english)
        show(sheet)
        (try XCTUnwrap(view("scope.firstRun.tool.claude", in: sheet) as? NSButton)).performClick(nil)
        for _ in 0..<100 where app.scopeConsentEntry.controller.isFirstRunToolChosen("claude") { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(app.scopeConsentEntry.controller.isFirstRunToolChosen("claude"))
        XCTAssertEqual((try XCTUnwrap(view("scope.firstRun.tool.claude", in: sheet) as? NSButton)).state, .off)
        let before = await engine.recorded()
        XCTAssertTrue(before.isEmpty, "unchecking records nothing until Done")
        XCTAssertFalse(app.scopeConsentEntry.controller.firstRunChoiceSatisfied, "D61: at least one tool must be ticked")
        let committed = await app.scopeConsentEntry.controller.commitFirstRunChoices()
        XCTAssertFalse(committed, "with nothing ticked the choice cannot be sent")
        let grants = await engine.recorded()
        XCTAssertTrue(grants.isEmpty, "an unticked Keychain tool starts no Keychain read")
        XCTAssertNotNil(view("scope.keychain.needed", in: app.scopeConsentEntry.view), "Data & Privacy states the need")
        XCTAssertNotNil(view("scope.keychain.allow", in: app.scopeConsentEntry.view), "with the same button")
        XCTAssertTrue(app.scopeConsentEntry.controller.needsKeychainAccess, "the standing state is in Settings")
        XCTAssertTrue(app.composition.accountMembers.members.isEmpty, "an unreadable Claude row has no Dock ring or card")
    }

    func testDeniedIsShownAndNotAskedAgain() async throws {
        let (app, engine) = try await launch(keychain: "deny", code: "keychain_denied")
        let sheet = try app.scopeConsentEntry.makeFirstRunView(language: .english)
        XCTAssertNil(view("scope.firstRun.keychain", in: sheet), "a refusal is not asked again")
        XCTAssertNotNil(view("scope.keychain.needed", in: app.scopeConsentEntry.view))
        XCTAssertNotNil(view("scope.keychain.allow", in: app.scopeConsentEntry.view), "Settings carries the button")
        let grants = await engine.recorded()
        XCTAssertTrue(grants.isEmpty)
        // The same button is how a refusal is reversed.
        await app.scopeConsentEntry.controller.allowKeychain()
        let after = await engine.recorded()
        XCTAssertEqual(after.first?.keychain?[Self.scope], .allow)
    }

    /// D87 slice 9: a card whose reading failed for a named cause no longer says only "Settings": its action links to
    /// that subscription's row, which shows the same reason from the shared table. Only the Keychain card asks for the Keychain.
    func testACardCauseLinksToItsSubscriptionsRow() async throws {
        let (app, engine) = try await launch(keychain: "allow", rowState: "failed", code: "timeout")
        XCTAssertEqual(try card(app).actionLabel, "Open in Settings")
        XCTAssertFalse(app.scopeConsentEntry.controller.needsKeychainAccess, "this card is not the Keychain card")
        XCTAssertNotNil(app.composition.dock.cardActionRequested, "the card action is wired")
        let member = try XCTUnwrap(app.composition.accountMembers.members.first?.id)
        let settings = app.scopeConsentEntry.view
        settings.apply(language: .english)
        settings.setSubscriptionRows(SubscriptionRowsContext(
            subscriptions: [SettingsSubscription(id: member, name: .init("Claude Code", "Claude Code"), vendor: "claude", source: .unavailable, causeCode: "timeout")],
            orderedIDs: [member], hiddenIDs: [], canSave: true))
        settings.revealSubscriptionRow(member)
        XCTAssertNotNil(view("subscriptions.row." + member, in: settings), "the row the card links to exists")
        XCTAssertEqual((view("subscriptions.status." + member, in: settings) as? NSTextField)?.stringValue, "The reading timed out; it will retry on its own")
        let grants = await engine.recorded()
        XCTAssertTrue(grants.isEmpty, "linking to a row asks the system for nothing")
    }

    func testALoginThatAlreadyReadsAsksNothing() async throws {
        let (app, _) = try await launch(keychain: "unset", rowState: "fresh", code: "ok")
        XCTAssertFalse(app.scopeConsentEntry.controller.asksForKeychainOnFirstRun)
        XCTAssertFalse(app.scopeConsentEntry.controller.needsKeychainAccess)
    }

    /// G3-38: at t=0 a tool waiting for its first read has no ring, and the Dock says it is being read
    /// rather than that no readings are available.
    func testDockSaysReadingAtTimeZero() async throws {
        let (app, _) = try await launch(keychain: "unset", rowState: "pending", code: "not_read_yet")
        XCTAssertTrue(app.composition.accountMembers.members.isEmpty, "no ring for a tool not read yet")
        let text = try XCTUnwrap(app.composition.presentedContent.emptyText)
        XCTAssertEqual(text, "Reading Claude Code…")
        XCTAssertFalse(text.contains("No readings"))
        XCTAssertFalse(text.contains("Settings"), "the reading summary does not send the user to consent settings")
    }
}
