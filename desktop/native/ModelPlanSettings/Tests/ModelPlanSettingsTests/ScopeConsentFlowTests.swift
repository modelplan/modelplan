// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanSettings

@MainActor final class ScopeConsentFlowTests: XCTestCase {
    func testEntryConsumesAcceptedFactsAndClearsWithoutAFactory() throws {
        let entry = ScopeConsentEntry(client: ScopeConsentTestClient(), ready: { true }, language: .english)
        entry.acceptedFacts(try ScopeConsentFixtures.facts())
        XCTAssertNotNil(entry.controller.facts)
        XCTAssertFalse(entry.controller.canMutate, "Absent authoritative parameters must disable mutation")
        XCTAssertEqual(entry.view.accessibilityIdentifier(), "settings.scopeConsent")
        entry.clearPrivateViews()
        XCTAssertNil(entry.controller.facts)
        XCTAssertTrue(entry.controller.selectedIDs.isEmpty)
    }
    private func control(_ root: NSView, _ id: String) throws -> NSButton {
        func find(_ view: NSView) -> NSButton? {
            if let value = view as? NSButton, value.accessibilityIdentifier() == id { return value }
            return view.subviews.lazy.compactMap(find).first
        }
        return try XCTUnwrap(find(root))
    }
    private func activate(_ root: NSView, _ id: String) async throws {
        let button = try control(root, id)
        if let asynchronous = button as? ScopeConsentButton { await asynchronous.invoke?() }
        else if let synchronous = button as? ConnectionButton { synchronous.invoke?() }
        else { XCTFail("Unexpected scope control") }
    }
    func testAcceptedClearDuringSendingNotificationPreventsCommandDispatch() async throws {
        let engine = ScopeConsentTestClient()
        let commands = EngineClientScopeConsentCommands(client: engine, ready: { true }, makeGrant: { intent in
            try .init(requestId: intent.requestID, expectStoreEpoch: "synthetic-epoch", expectGeneration: 7,
                consentTextVersion: 17, allow: intent.allowIDs, deny: intent.denyIDs)
        })
        let controller = ScopeConsentController(commands: commands)
        controller.receiveAcceptedFacts(try ScopeConsentFixtures.facts())
        let request = try XCTUnwrap(controller.requestAllow())
        let observer = controller.observe {
            if case .sending = controller.phase { controller.clearAcceptedPrivateState() }
        }
        await controller.confirm(request.id)
        controller.removeObserver(observer)
        let grants = await engine.recordedGrants()
        XCTAssertTrue(grants.isEmpty, "A cleared UI intent must not cross the command seam")
        XCTAssertNil(controller.facts)
    }
    func testLateRPCCompletionCannotRestoreClearedUIPresentation() async throws {
        let engine = ScopeConsentTestClient(); await engine.holdGrant()
        let commands = EngineClientScopeConsentCommands(client: engine, ready: { true }, makeGrant: { intent in
            try .init(requestId: intent.requestID, expectStoreEpoch: "synthetic-epoch", expectGeneration: 7,
                consentTextVersion: 17, allow: intent.allowIDs, deny: intent.denyIDs)
        })
        let controller = ScopeConsentController(commands: commands)
        controller.receiveAcceptedFacts(try ScopeConsentFixtures.facts())
        let request = try XCTUnwrap(controller.requestAllow())
        let task = Task { await controller.confirm(request.id) }
        await engine.waitForGrantStart()
        controller.clearAcceptedPrivateState()
        await engine.finishGrant(); await task.value
        XCTAssertNil(controller.facts)
        XCTAssertTrue(controller.selectedIDs.isEmpty)
        if case .idle = controller.phase {} else { XCTFail("Late completion must not replace the cleared UI state") }
    }
    func testAcceptedMetadataRefreshPreservesLocalChoicesAndDoesNotSelectO() throws {
        let engine = ScopeConsentTestClient()
        let commands = EngineClientScopeConsentCommands(client: engine, ready: { true }, makeGrant: { intent in
            try .init(requestId: intent.requestID, expectStoreEpoch: "synthetic-epoch", expectGeneration: 7,
                consentTextVersion: 17, allow: intent.allowIDs, deny: intent.denyIDs)
        })
        let controller = ScopeConsentController(commands: commands)
        let initial = try ScopeConsentFixtures.facts()
        controller.receiveAcceptedFacts(initial)
        controller.choose(ScopeConsentFixtures.gemini, selected: true)
        controller.choose(ScopeConsentFixtures.local, selected: false)
        let request = try XCTUnwrap(controller.requestAllow())
        controller.receiveAcceptedFacts(initial)
        XCTAssertEqual(controller.selectedIDs, [ScopeConsentFixtures.gemini])
        if case .confirmation(let current) = controller.phase { XCTAssertEqual(current.id, request.id) }
        else { XCTFail("Unchanged store fanout must not erase a visible draft") }
        controller.receiveAcceptedFacts(try ScopeConsentFixtures.facts(cursorDefault: true))
        XCTAssertEqual(controller.selectedIDs, [ScopeConsentFixtures.gemini], "New metadata cannot replace already-present intent defaults")
        if case .idle = controller.phase {} else { XCTFail("A changed visible basis retires its old confirmation") }
    }
    func testUndetectedRetiredPathCanBeRevokedAndForgottenWithSeparateConfirmations() async throws {
        let engine = ScopeConsentTestClient()
        let commands = EngineClientScopeConsentCommands(client: engine, ready: { true }, makeGrant: { intent in
            try .init(requestId: intent.requestID, expectStoreEpoch: "synthetic-epoch", expectGeneration: 7,
                consentTextVersion: 17, allow: intent.allowIDs, deny: intent.denyIDs,
                forget: intent.forgetIDs.isEmpty ? nil : intent.forgetIDs)
        })
        let controller = ScopeConsentController(commands: commands)
        controller.receiveAcceptedFacts(try ScopeConsentFixtures.facts(grantedGemini: true, retiredGemini: true))
        let view = SettingsScopeConsentView(controller: controller, language: .english)
        XCTAssertFalse(try control(view, "scope.allow." + ScopeConsentFixtures.gemini).isEnabled)
        try await activate(view, "scope.revoke." + ScopeConsentFixtures.gemini)
        let before = await engine.recordedGrants(); XCTAssertTrue(before.isEmpty)
        try await activate(view, "scope.confirm")
        let revoked = await engine.recordedGrants()
        XCTAssertEqual(revoked.first?.deny, [ScopeConsentFixtures.gemini])
        XCTAssertEqual(revoked.first?.allow, [])
        XCTAssertTrue(controller.isAllowed(ScopeConsentFixtures.gemini), "RPC completion is not a deny receipt")
        controller.receiveAcceptedFacts(try ScopeConsentFixtures.facts(retiredGemini: true))
        try await activate(view, "scope.forget." + ScopeConsentFixtures.gemini)
        try await activate(view, "scope.confirm")
        let forgotten = await engine.recordedGrants()
        XCTAssertEqual(forgotten.count, 2)
        XCTAssertEqual(forgotten.last?.forget, [ScopeConsentFixtures.gemini])
        XCTAssertEqual(forgotten.last?.deny, [])
        XCTAssertEqual(forgotten.last?.allow, [])
    }
    func testUnknownMutationOutcomeRequiresReadbackAndNeverReplaysGrant() async throws {
        let engine = ScopeConsentTestClient()
        await engine.failGrant(.mutationOutcomeUnknown(requestID: "opaque", expected: .init(storeEpoch: "epoch", generation: 7)))
        let commands = EngineClientScopeConsentCommands(client: engine, ready: { true }, makeGrant: { intent in
            try .init(requestId: intent.requestID, expectStoreEpoch: "synthetic-epoch", expectGeneration: 7,
                consentTextVersion: 17, allow: intent.allowIDs, deny: intent.denyIDs)
        })
        let controller = ScopeConsentController(commands: commands)
        controller.receiveAcceptedFacts(try ScopeConsentFixtures.facts())
        let view = SettingsScopeConsentView(controller: controller, language: .english)
        try await activate(view, "scope.allowSelected"); try await activate(view, "scope.confirm")
        XCTAssertFalse(try control(view, "scope.allowSelected").isEnabled)
        XCTAssertTrue(viewTexts(view).contains { $0.contains("outcome is unknown") })
        try await activate(view, "scope.inspect")
        let readCount = await engine.inspectionCount(); XCTAssertEqual(readCount, 1)
        let grants = await engine.recordedGrants(); XCTAssertEqual(grants.count, 1)
        XCTAssertFalse(controller.canMutate, "Read completion without accepted facts cannot unblock a mutation")
        XCTAssertFalse(controller.isAllowed(ScopeConsentFixtures.gemini))
        controller.receiveAcceptedFacts(try ScopeConsentFixtures.facts())
        XCTAssertTrue(controller.canMutate)
    }
    private func viewTexts(_ root: NSView) -> [String] {
        ([ (root as? NSTextField)?.stringValue ].compactMap { $0 }) + root.subviews.flatMap(viewTexts)
    }
    func testExplicitSelectAllIncludesOPerScopeWithoutSendingBeforeConfirmation() async throws {
        let engine = ScopeConsentTestClient()
        let commands = EngineClientScopeConsentCommands(client: engine, ready: { true }, makeGrant: { intent in
            try .init(requestId: intent.requestID, expectStoreEpoch: "synthetic-epoch", expectGeneration: 7,
                consentTextVersion: 17, allow: intent.allowIDs, deny: intent.denyIDs)
        })
        let controller = ScopeConsentController(commands: commands)
        controller.receiveAcceptedFacts(try ScopeConsentFixtures.facts())
        let view = SettingsScopeConsentView(controller: controller, language: .english)
        try await activate(view, "scope.selectAll")
        XCTAssertEqual(controller.selectedIDs, [ScopeConsentFixtures.local, ScopeConsentFixtures.gemini, ScopeConsentFixtures.cursor])
        let before = await engine.recordedGrants(); XCTAssertTrue(before.isEmpty)
        try await activate(view, "scope.allowSelected"); try await activate(view, "scope.confirm")
        let sent = await engine.recordedGrants()
        XCTAssertEqual(Set(sent.first?.allow ?? []), [ScopeConsentFixtures.local, ScopeConsentFixtures.gemini, ScopeConsentFixtures.cursor])
        XCTAssertFalse(controller.isAllowed(ScopeConsentFixtures.cursor))
    }
    func testDiagnosticsCopyContainsOnlyAllowlistedReportAndClearWithdrawsIt() async throws {
        let engine = ScopeConsentTestClient()
        let commands = EngineClientScopeConsentCommands(client: engine, ready: { true })
        let controller = ScopeConsentController(commands: commands)
        let view = SettingsScopeConsentView(controller: controller, language: .english)
        controller.receiveAcceptedDiagnostics(try .init(protocolVersion: "/private/secret-path", serverVersion: "token-canary",
            uptimeSeconds: 12, scopes: [], lastErrorClass: "private-account-canary"))
        XCTAssertTrue(viewTexts(view).contains { $0.contains("12") })
        XCTAssertFalse(viewTexts(view).joined().contains("canary"))
        XCTAssertFalse(viewTexts(view).joined().contains("secret-path"))
        XCTAssertTrue(try control(view, "scope.copyDiagnostics").isEnabled == false, "No injected copy adapter means no side effect")
        controller.clearAcceptedPrivateState()
        XCTAssertFalse(viewTexts(view).contains { $0.contains("Uptime seconds: 12") })
        var copied: [String] = []
        let withCopy = ScopeConsentController(commands: commands, copyReport: { copied.append($0) })
        let copyView = SettingsScopeConsentView(controller: withCopy, language: .english)
        withCopy.receiveAcceptedDiagnostics(try .init(protocolVersion: "path-canary", serverVersion: "token-canary", uptimeSeconds: 12, scopes: [], lastErrorClass: "account-canary"))
        try await activate(copyView, "scope.copyDiagnostics")
        XCTAssertEqual(copied, ["ModelPlan engine diagnostics\nScope count: 0\nUptime seconds: 12"])
        withCopy.clearAcceptedPrivateState()
        XCTAssertFalse(try control(copyView, "scope.copyDiagnostics").isEnabled)
    }
    func testAcceptedCleanupReceiptIsStatusOnlyAndHistoricalReceiptCannotRestoreIt() async throws {
        let engine = ScopeConsentTestClient()
        let commands = EngineClientScopeConsentCommands(client: engine, ready: { true }, makeGrant: { intent in
            try .init(requestId: intent.requestID, expectStoreEpoch: "synthetic-epoch", expectGeneration: 7,
                consentTextVersion: 17, allow: intent.allowIDs, deny: intent.denyIDs, forget: intent.forgetIDs)
        })
        let controller = ScopeConsentController(commands: commands)
        controller.receiveAcceptedFacts(try ScopeConsentFixtures.facts(grantedGemini: true))
        let request = try XCTUnwrap(controller.requestForget(ScopeConsentFixtures.gemini))
        await controller.confirm(request.id)
        let receipt = try WireConsentReceipt(requestId: request.intent.requestID, committed: true, committedGeneration: 8,
            cleanupPending: [ScopeConsentFixtures.gemini], code: .cleanupPending)
        let floor = EngineConsentFloor(storeEpoch: "epoch", generation: 8)
        let delivery = EngineDeliveryContext(sessionID: "session", floor: floor, revision: 1)
        controller.receiveAcceptedGrant(.init(receipt: receipt, committedAt: floor, delivery: delivery, supersededByLaterConsent: false))
        let view = SettingsScopeConsentView(controller: controller, language: .english)
        XCTAssertTrue(viewTexts(view).contains { $0.contains("cleanup is pending") })
        XCTAssertTrue(controller.isAllowed(ScopeConsentFixtures.gemini), "Even a receipt cannot replace canonical facts")
        controller.receiveAcceptedFacts(try ScopeConsentFixtures.facts())
        controller.receiveAcceptedGrant(.init(receipt: receipt, committedAt: floor, delivery: delivery, supersededByLaterConsent: true))
        XCTAssertFalse(viewTexts(view).contains { $0.contains("cleanup is pending") })
        XCTAssertFalse(controller.isAllowed(ScopeConsentFixtures.gemini))
        controller.clearAcceptedPrivateState()
        controller.receiveAcceptedGrant(.init(receipt: receipt, committedAt: floor, delivery: delivery, supersededByLaterConsent: false))
        XCTAssertNil(controller.facts)
        XCTAssertFalse(viewTexts(view).contains { $0.contains("cleanup is pending") })
    }
    func testPluginUsesEngineClientAfterConfirmationAndMissingResultNeverClaimsInstalled() async throws {
        let engine = ScopeConsentTestClient()
        let commands = EngineClientScopeConsentCommands(client: engine, ready: { true })
        let controller = ScopeConsentController(commands: commands)
        let view = SettingsScopeConsentView(controller: controller, language: .english)
        try await activate(view, "scope.plugin.codex")
        let before = await engine.recordedPlugins(); XCTAssertTrue(before.isEmpty)
        try await activate(view, "scope.plugin.confirm")
        let sent = await engine.recordedPlugins()
        XCTAssertEqual(sent.count, 1); XCTAssertEqual(sent.first?.tool, .codex)
        XCTAssertTrue(viewTexts(view).contains { $0.contains("installation could not be verified") })
        XCTAssertFalse(viewTexts(view).contains { $0 == "Installed" })
        XCTAssertNil(controller.facts)
    }
    func testFuturePathCannotBeAllowedButSavedPermissionCanStillBeTightened() async throws {
        let engine = ScopeConsentTestClient()
        let commands = EngineClientScopeConsentCommands(client: engine, ready: { true }, makeGrant: { intent in
            try .init(requestId: intent.requestID, expectStoreEpoch: "synthetic-epoch", expectGeneration: 7,
                consentTextVersion: 17, allow: intent.allowIDs, deny: intent.denyIDs)
        })
        let controller = ScopeConsentController(commands: commands)
        controller.receiveAcceptedFacts(try ScopeConsentFixtures.facts(unknownGeminiRoute: true))
        let view = SettingsScopeConsentView(controller: controller, language: .english)
        XCTAssertFalse(try control(view, "scope.allow." + ScopeConsentFixtures.gemini).isEnabled)
        XCTAssertTrue(viewTexts(view).contains { $0.contains("Update the app") })
        XCTAssertFalse(viewTexts(view).joined().contains("future-route-canary"))
        try await activate(view, "scope.revoke." + ScopeConsentFixtures.gemini)
        try await activate(view, "scope.confirm")
        let sent = await engine.recordedGrants(); XCTAssertEqual(sent.first?.deny, [ScopeConsentFixtures.gemini])
    }
    func testRetiredSurfaceWithdrawsDraftAndCapturedConfirmationBeforeAnyCommand() async throws {
        let engine = ScopeConsentTestClient()
        let commands = EngineClientScopeConsentCommands(client: engine, ready: { true }, makeGrant: { intent in
            try .init(requestId: intent.requestID, expectStoreEpoch: "synthetic-epoch", expectGeneration: 7,
                consentTextVersion: 17, allow: intent.allowIDs, deny: intent.denyIDs)
        })
        let controller = ScopeConsentController(commands: commands)
        controller.receiveAcceptedFacts(try ScopeConsentFixtures.facts())
        let view = SettingsScopeConsentView(controller: controller, language: .english)
        try await activate(view, "scope.allowSelected")
        let old = try XCTUnwrap(control(view, "scope.confirm") as? ScopeConsentButton)
        let captured = old.invoke
        view.suspend()
        XCTAssertNil(controller.facts); XCTAssertTrue(controller.selectedIDs.isEmpty)
        XCTAssertTrue(viewTexts(view).isEmpty)
        await captured?()
        let sent = await engine.recordedGrants(); XCTAssertTrue(sent.isEmpty)
        XCTAssertFalse(old.isEnabled)
    }
    func testAcceptedBasisChangeBeforeDispatchInvalidatesCapturedAllow() async throws {
        let engine = ScopeConsentTestClient()
        let commands = EngineClientScopeConsentCommands(client: engine, ready: { true }, makeGrant: { intent in
            try .init(requestId: intent.requestID, expectStoreEpoch: "synthetic-epoch", expectGeneration: 7,
                consentTextVersion: 17, allow: intent.allowIDs, deny: intent.denyIDs)
        })
        let controller = ScopeConsentController(commands: commands)
        controller.receiveAcceptedFacts(try ScopeConsentFixtures.facts())
        let request = try XCTUnwrap(controller.requestAllow())
        let changed = try ScopeConsentFixtures.facts(grantedGemini: true)
        var delivered = false
        let observer = controller.observe {
            if case .sending = controller.phase, !delivered {
                delivered = true; controller.receiveAcceptedFacts(changed)
            }
        }
        await controller.confirm(request.id)
        controller.removeObserver(observer)
        let sent = await engine.recordedGrants(); XCTAssertTrue(sent.isEmpty)
        XCTAssertTrue(controller.canMutate, "A withdrawn pre-dispatch intent must not leave a stuck Sending UI")
    }
    func testValidatedCommitWithInterruptedDeliveryShowsReadbackNeededNotUnknownOutcome() async throws {
        let engine = ScopeConsentTestClient()
        await engine.failGrant(.receiptDeliveryInterrupted(requestID: "opaque", committedAt: .init(storeEpoch: "epoch", generation: 8)))
        let commands = EngineClientScopeConsentCommands(client: engine, ready: { true }, makeGrant: { intent in
            try .init(requestId: intent.requestID, expectStoreEpoch: "synthetic-epoch", expectGeneration: 7,
                consentTextVersion: 17, allow: intent.allowIDs, deny: intent.denyIDs)
        })
        let controller = ScopeConsentController(commands: commands)
        controller.receiveAcceptedFacts(try ScopeConsentFixtures.facts())
        let view = SettingsScopeConsentView(controller: controller, language: .english)
        try await activate(view, "scope.allowSelected"); try await activate(view, "scope.confirm")
        XCTAssertTrue(viewTexts(view).contains { $0.contains("engine recorded the change") })
        XCTAssertFalse(viewTexts(view).contains { $0.contains("outcome is unknown") })
        XCTAssertFalse(controller.canMutate)
        XCTAssertFalse(controller.isAllowed(ScopeConsentFixtures.gemini))
    }
    func testMissingMetadataDisablesMutationsAndParameterFactoryCannotExpandGesture() async throws {
        let engine = ScopeConsentTestClient()
        let missing = EngineClientScopeConsentCommands(client: engine, ready: { true })
        let controller = ScopeConsentController(commands: missing)
        controller.receiveAcceptedFacts(try ScopeConsentFixtures.facts())
        let view = SettingsScopeConsentView(controller: controller, language: .english)
        XCTAssertFalse(try control(view, "scope.allowSelected").isEnabled)
        XCTAssertTrue(try control(view, "scope.inspect").isEnabled)
        XCTAssertTrue(viewTexts(view).contains { $0.contains("Permission changes are unavailable") })
        try await activate(view, "scope.allowSelected")
        XCTAssertNil(controller.requestAllow())
        let expanded = EngineClientScopeConsentCommands(client: engine, ready: { true }, makeGrant: { intent in
            try .init(requestId: intent.requestID, expectStoreEpoch: "synthetic-epoch", expectGeneration: 7,
                consentTextVersion: 17, allow: [ScopeConsentFixtures.local, ScopeConsentFixtures.gemini], deny: [])
        })
        let intent = ScopeConsentIntent(mutation: .allow(scopes: [ScopeConsentFixtures.local], keychain: []))
        do { _ = try await expanded.grant(intent, userAction: .init(id: UUID())); XCTFail("Factory cannot widen a confirmed gesture") }
        catch ScopeConsentCommandFailure.intentMismatch {} catch { XCTFail("Unexpected bounded failure") }
        let sent = await engine.recordedGrants(); XCTAssertTrue(sent.isEmpty)
    }
    func testEmptyAcceptedCatalogueShowsRecoveryAndNoEnabledAllowAction() throws {
        let engine = ScopeConsentTestClient()
        let commands = EngineClientScopeConsentCommands(client: engine, ready: { true }, makeGrant: { intent in
            try .init(requestId: intent.requestID, expectStoreEpoch: "synthetic-epoch", expectGeneration: 7,
                consentTextVersion: 17, allow: intent.allowIDs, deny: intent.denyIDs)
        })
        let controller = ScopeConsentController(commands: commands)
        controller.receiveAcceptedFacts(try .init(scopes: []))
        let view = SettingsScopeConsentView(controller: controller, language: .english)
        XCTAssertFalse(try control(view, "scope.allowSelected").isEnabled)
        XCTAssertTrue(try control(view, "scope.inspect").isEnabled)
        XCTAssertTrue(viewTexts(view).contains { $0.contains("No saved or detected reading paths") })
    }
    func testCancelConfirmationInvalidatesItsCapturedCallbackWithoutGranting() async throws {
        let engine = ScopeConsentTestClient()
        let commands = EngineClientScopeConsentCommands(client: engine, ready: { true }, makeGrant: { intent in
            try .init(requestId: intent.requestID, expectStoreEpoch: "synthetic-epoch", expectGeneration: 7,
                consentTextVersion: 17, allow: intent.allowIDs, deny: intent.denyIDs)
        })
        let controller = ScopeConsentController(commands: commands)
        controller.receiveAcceptedFacts(try ScopeConsentFixtures.facts())
        let view = SettingsScopeConsentView(controller: controller, language: .english)
        try await activate(view, "scope.allowSelected")
        let captured = try XCTUnwrap(control(view, "scope.confirm") as? ScopeConsentButton).invoke
        try await activate(view, "scope.cancel")
        await captured?()
        let sent = await engine.recordedGrants(); XCTAssertTrue(sent.isEmpty)
        XCTAssertNotNil(controller.facts)
        if case .idle = controller.phase {} else { XCTFail("Cancel must leave the confirmation") }
    }
    func testAcceptedPluginPlanIsCorrelatedBeforeCompletionAndShownAfterward() async throws {
        let engine = ScopeConsentTestClient(); await engine.holdPlugin()
        let commands = EngineClientScopeConsentCommands(client: engine, ready: { true })
        let controller = ScopeConsentController(commands: commands)
        let view = SettingsScopeConsentView(controller: controller, language: .english)
        try await activate(view, "scope.plugin.codex")
        let confirm = try XCTUnwrap(control(view, "scope.plugin.confirm") as? ScopeConsentButton)
        let task = Task { await confirm.invoke?() }
        await engine.waitForPluginStart()
        let result = try WirePluginInstallResult(schemaVersion: 1, tool: .codex, status: .planned,
            commands: [["codex", "one"], ["codex", "two"]], completed: 0, docs: "https://example.invalid")
        controller.receiveAcceptedPluginResult(requestID: .string("rpc-u8"), result: result)
        XCTAssertFalse(viewTexts(view).contains { $0.contains("plan is ready") }, "The request ID is not correlated until completion")
        await engine.finishPlugin(); await task.value
        XCTAssertTrue(viewTexts(view).contains { $0.contains("plan is ready") })
        XCTAssertFalse(viewTexts(view).contains { $0 == "Installed" })
    }
    func testAcceptedPluginResultRejectsOtherRequestAndClearWithdrawsState() async throws {
        let engine = ScopeConsentTestClient(); await engine.holdPlugin()
        let commands = EngineClientScopeConsentCommands(client: engine, ready: { true })
        let controller = ScopeConsentController(commands: commands)
        let view = SettingsScopeConsentView(controller: controller, language: .english)
        try await activate(view, "scope.plugin.codex")
        let confirm = try XCTUnwrap(control(view, "scope.plugin.confirm") as? ScopeConsentButton)
        let task = Task { await confirm.invoke?() }; await engine.waitForPluginStart()
        let result = try WirePluginInstallResult(schemaVersion: 1, tool: .codex, status: .installed,
            commands: [["codex", "one"], ["codex", "two"]], completed: 2, docs: "https://example.invalid")
        controller.receiveAcceptedPluginResult(requestID: .string("other-request"), result: result)
        await engine.finishPlugin(); await task.value
        XCTAssertFalse(viewTexts(view).contains { $0.contains("reports the plugin installed") })
        controller.receiveAcceptedPluginResult(requestID: .string("other-request"), result: result)
        XCTAssertFalse(viewTexts(view).contains { $0.contains("reports the plugin installed") })
        controller.receiveAcceptedPluginResult(requestID: .string("rpc-u8"), result: result)
        XCTAssertTrue(viewTexts(view).contains { $0.contains("reports the plugin installed") })
        controller.clearAcceptedPrivateState()
        controller.receiveAcceptedPluginResult(requestID: .string("rpc-u8"), result: result)
        XCTAssertFalse(viewTexts(view).contains { $0.contains("reports the plugin installed") })
    }
    func testOffscreenScopeControlRequiresConfirmationAndOnlyAcceptedFactsAuthorize() async throws {
        let engine = ScopeConsentTestClient()
        let commands = EngineClientScopeConsentCommands(client: engine, ready: { true }, makeGrant: { intent in
            try .init(requestId: intent.requestID, expectStoreEpoch: "synthetic-epoch", expectGeneration: 7,
                consentTextVersion: 17, allow: intent.allowIDs, deny: intent.denyIDs,
                forget: intent.forgetIDs.isEmpty ? nil : intent.forgetIDs)
        })
        let controller = ScopeConsentController(commands: commands)
        controller.receiveAcceptedFacts(try ScopeConsentFixtures.facts())
        let view = SettingsScopeConsentView(controller: controller, language: .english)
        XCTAssertEqual(try control(view, "scope.allow." + ScopeConsentFixtures.local).state, .on)
        XCTAssertEqual(try control(view, "scope.allow." + ScopeConsentFixtures.gemini).state, .off)
        XCTAssertEqual(try control(view, "scope.allow." + ScopeConsentFixtures.cursor).state, .off)
        let initial = await engine.recordedGrants(); XCTAssertTrue(initial.isEmpty)
        try await activate(view, "scope.allow." + ScopeConsentFixtures.gemini)
        try await activate(view, "scope.allowSelected")
        let unconfirmed = await engine.recordedGrants(); XCTAssertTrue(unconfirmed.isEmpty)
        try await activate(view, "scope.confirm")
        let sent = await engine.recordedGrants()
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(Set(sent.first?.allow ?? []), [ScopeConsentFixtures.local, ScopeConsentFixtures.gemini])
        XCTAssertEqual(sent.first?.consentTextVersion, 17)
        XCTAssertEqual(sent.first?.expectGeneration, 7)
        XCTAssertFalse(controller.isAllowed(ScopeConsentFixtures.gemini), "RPC completion cannot create current authorization")
        controller.receiveAcceptedFacts(try ScopeConsentFixtures.facts(grantedGemini: true))
        XCTAssertTrue(controller.isAllowed(ScopeConsentFixtures.gemini))
        XCTAssertNil(view.window, "Offscreen command binding is not real input or L2")
    }
}
