// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings
import ModelPlanWire
@testable import ModelPlanAppIntegration

private actor FirstRunConsentEngine: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore
    let context = EngineDeliveryContext(sessionID: "first-run-synthetic", floor: .init(storeEpoch: "first-run-synthetic", generation: 1), revision: 1)
    private var grants: [WireConsentGrantParams] = []
    init(store: EngineStore) { self.store = store }
    func recorded() -> [WireConsentGrantParams] { grants }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context)))
        await store.consume(.context(context))
        return context
    }
    func stop() async {}
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("rows")) }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("consent")) }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion {
        grants.append(request); return .init(requestID: .string(request.requestId))
    }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

@MainActor final class FirstRunConsentNormalEntryTests: XCTestCase {
    func testI04DoneGrantsOnlyCheckedReadersAfterExplicitChoice() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("first-run-i04-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireConsentFacts.json").standardizedFileURL
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        let base = try XCTUnwrap((object["scopes"] as? [[String: Any]])?.first)
        var scopes = [("one.local", "local_log", "codex"), ("two.runtime", "runtime_rpc", "claude"), ("three.browser", "browser_session", "cursor"), ("four.key", "api_key_api", "codex"), ("five.status", "status_line", "codex")].map { id, route, tool in
            var scope = base; scope["scope"] = id; scope["tool"] = tool; scope["route"] = route
            scope["state"] = "unset"; scope["detected"] = true; scope["retired"] = false
            scope["defaultCheck"] = true; scope["cleanupPending"] = false
            scope.removeValue(forKey: "disabledReason"); scope.removeValue(forKey: "keychain")
            return scope
        }
        func facts() throws -> WireConsentFacts {
            object["scopes"] = scopes
            return try WireDecoder.decode(WireConsentFacts.self, from: JSONSerialization.data(withJSONObject: object))
        }
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/never-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true), settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: directory, preferredLanguages: ["en-US"]), createsNativePanels: false, makeClient: { _, store in FirstRunConsentEngine(store: store) }, activateSettings: {})
        await app.prepare(); await app.composition.start()
        let engine = try XCTUnwrap(app.composition.client as? FirstRunConsentEngine)
        let delivery = try XCTUnwrap(app.composition.store.snapshot.delivery)
        func publishFacts() async throws {
            await app.composition.store.consume(.consentChanged(.init(envelope: try .init(sessionId: delivery.sessionID, storeEpoch: delivery.floor.storeEpoch, consentGeneration: delivery.floor.generation, data: facts()), delivery: delivery)))
        }
        try await publishFacts()
        var context = app.settingsHost.application.editor.context
        context.subscriptions = [
            .init(id: "first", name: .init("First plan", "第一项")),
            .init(id: "second", name: .init("Second plan", "第二项")),
            .init(id: "third", name: .init("Browser plan", "浏览器项"))
        ]
        app.settingsHost.application.update(context: context)
        let existing = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
        await app.restoreFirstRunIfNeeded()
        let window = try XCTUnwrap(NSApplication.shared.windows.first { !existing.contains(ObjectIdentifier($0)) && $0.isVisible })
        defer { window.close(); app.composition.dock.close() }
        func views(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(views) }
        func button(_ id: String) throws -> NSButton {
            try XCTUnwrap(views(try XCTUnwrap(window.contentView)).first { $0.accessibilityIdentifier() == id } as? NSButton)
        }
        XCTAssertTrue(app.scopeConsentEntry.controller.selectedIDs.isEmpty)
        let summary = try XCTUnwrap(views(try XCTUnwrap(window.contentView)).first { $0.accessibilityIdentifier() == "firstRun.subscriptions" } as? NSTextField)
        XCTAssertFalse(summary.isHiddenOrHasHiddenAncestor)
        for name in ["First plan", "Second plan", "Browser plan"] { XCTAssertTrue(summary.stringValue.contains(name)) }
        for id in ["one.local", "two.runtime", "three.browser"] { XCTAssertEqual(try button("scope.allow." + id).state, .off) }
        XCTAssertNil(views(try XCTUnwrap(window.contentView)).first { $0.accessibilityIdentifier() == "scope.allow.four.key" })
        XCTAssertNil(views(try XCTUnwrap(window.contentView)).first { $0.accessibilityIdentifier() == "scope.allow.five.status" })
        try button("scope.selectAll").performClick(nil)
        XCTAssertEqual(app.scopeConsentEntry.controller.selectedIDs, ["one.local", "two.runtime"])
        try button("scope.allow.one.local").performClick(nil)
        XCTAssertEqual(app.scopeConsentEntry.controller.selectedIDs, ["two.runtime"])
        let before = await engine.recorded(); XCTAssertTrue(before.isEmpty)
        try button("firstRun.done").performClick(nil)
        var recorded = await engine.recorded()
        for _ in 0..<200 where recorded.isEmpty { try await Task.sleep(for: .milliseconds(10)); recorded = await engine.recorded() }
        XCTAssertEqual(recorded.count, 1)
        XCTAssertEqual(recorded.first?.allow, ["two.runtime"])
        XCTAssertTrue(window.isVisible, "RPC completion alone does not prove accepted consent")
        try await publishFacts() // An unchanged accepted snapshot is not the grant result.
        XCTAssertFalse(try button("firstRun.done").isEnabled, "An unresolved grant cannot be resubmitted")
        XCTAssertFalse(try button("scope.allow.one.local").isEnabled)
        window.close()
        await app.restoreFirstRunIfNeeded()
        XCTAssertTrue(window.isVisible, "An incomplete first run can be reopened while its grant is unresolved")
        XCTAssertFalse(try button("firstRun.done").isEnabled)
        XCTAssertTrue(try button("scope.inspect").isEnabled, "The user can inspect the existing request without replaying it")
        scopes[1]["state"] = "allowed"
        try await publishFacts()
        XCTAssertTrue(try button("firstRun.done").isEnabled, "Accepted facts settle the old request after reopening")
        try button("firstRun.done").performClick(nil)
        var snapshot = await app.foundationStore.snapshot()
        for _ in 0..<200 where !snapshot.preferences.onboarding.completed { try await Task.sleep(for: .milliseconds(10)); snapshot = await app.foundationStore.snapshot() }
        XCTAssertTrue(snapshot.preferences.onboarding.completed)
        XCTAssertTrue(app.scopeConsentEntry.controller.isAllowed("two.runtime"))
        XCTAssertFalse(app.scopeConsentEntry.controller.isAllowed("one.local"))
        XCTAssertFalse(app.scopeConsentEntry.controller.isAllowed("three.browser"))
        for _ in 0..<200 where window.isVisible { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(window.isVisible)
        await app.settingsHost.present(paneID: "subscriptions", origin: .userInitiated)
        let settings = app.scopeConsentEntry.view
        XCTAssertTrue(settings.window?.isVisible == true)
        XCTAssertFalse(settings.isHiddenOrHasHiddenAncestor)
        for (id, expected) in [("one.local", false), ("two.runtime", true), ("three.browser", false)] {
            let state = try XCTUnwrap(views(settings).first { $0.accessibilityIdentifier() == "scope.state." + id } as? NSTextField)
            XCTAssertEqual(state.stringValue == "Allowed", expected, "Settings must show the accepted scope decision")
        }
        settings.window?.close()
    }
}
