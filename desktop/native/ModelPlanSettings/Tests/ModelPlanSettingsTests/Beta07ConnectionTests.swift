// SPDX-License-Identifier: MIT
import Foundation
import XCTest
@testable import ModelPlanSettings

@MainActor private final class ConnectionFake: SettingsConnectionService {
    var value = try! SettingsConnectionSnapshot()
    var pluginStatus: SettingsPluginInstallStatus = .planned
    var detects = 0
    var actions: [SettingsConnectionAction] = []
    var requests: [SettingsConnectionRequestContext] = []
    var returnedPluginTool: SettingsPluginTool?
    var detectGate: CheckedContinuation<SettingsConnectionSnapshot, Error>?
    var pauseDetect = false
    var error: Error?
    func detect() async throws -> SettingsConnectionSnapshot {
        detects += 1
        if pauseDetect { return try await withCheckedThrowingContinuation { detectGate = $0 } }
        if let error { throw error }; return value
    }
    func connect(_ tool: SettingsConnectionTool, access: SettingsConnectionAccess, request: SettingsConnectionRequestContext) async throws -> SettingsConnectionSnapshot {
        actions.append(.connect(tool, access)); requests.append(request); if let error { throw error }; return value
    }
    func disconnect(_ tool: SettingsConnectionTool, request: SettingsConnectionRequestContext) async throws -> SettingsConnectionSnapshot {
        actions.append(.disconnect(tool)); requests.append(request); if let error { throw error }; return value
    }
    func installPlugin(_ tool: SettingsPluginTool, request: SettingsConnectionRequestContext) async throws -> SettingsPluginInstallResult {
        actions.append(.installPlugin(tool)); requests.append(request); if let error { throw error }
        return .init(tool: returnedPluginTool ?? tool, status: pluginStatus)
    }
}

@MainActor final class Beta07ConnectionTests: XCTestCase {
    private func snapshot(generation: UInt64? = 1, access: SettingsConnectionAccess = .standard,
                          authorization: SettingsSharedAuthorization = .noConsent) throws -> SettingsConnectionSnapshot {
        try .init(consentGeneration: generation, tools: [
            .init(tool: .cursor, presence: .detected, authorization: authorization,
                  connection: .notConnectedYet, quota: .stale, support: .full, access: access, beta: true),
        ])
    }
    private func waitForGate(_ fake: ConnectionFake) async throws {
        for _ in 0..<100 where fake.detectGate == nil { await Task.yield() }
        XCTAssertNotNil(fake.detectGate)
        if fake.detectGate == nil { throw SettingsConnectionFailure.requestFailed }
    }
    func testUnavailableDefaultCannotPretendAnActionSucceeded() async {
        let controller = SettingsConnectionController()
        XCTAssertEqual(controller.phase, .unavailable)
        XCTAssertNil(controller.request(.installPlugin(.codex)))
        await controller.refresh(); await controller.confirm(UUID())
        XCTAssertNil(controller.snapshot); XCTAssertEqual(controller.phase, .unavailable)
    }
    func testPresenceConsentConnectionQuotaAndBindingAreIndependentInBothLanguages() throws {
        let value = try snapshot(), tool = try XCTUnwrap(value.tools.first)
        XCTAssertEqual(tool.presence, .detected); XCTAssertEqual(tool.authorization, .noConsent)
        XCTAssertEqual(tool.connection, .notConnectedYet); XCTAssertEqual(tool.quota, .stale)
        XCTAssertEqual(tool.binding, .unknown); XCTAssertTrue(value.subscriptions.isEmpty)
        let text = SettingsConnectionPresentation.summary(tool)
        for part in ["Detected", "No shared consent", "Not connected yet", "Quota stale", "Subscription unverified"] {
            XCTAssertTrue(text.english.contains(part), part)
        }
        for part in ["已检测到", "尚无共享授权", "尚未连接", "额度已过期", "订阅未验证"] { XCTAssertTrue(text.chinese.contains(part), part) }
        XCTAssertFalse(SettingsConnectionPresentation.summary(.init(tool: .codex)).english.contains("Not detected"), "unknown is not absent")
    }
    func testNoSubscriptionCanBeInventedFromDetectionOrQuota() throws {
        let sub = SettingsVerifiedSubscription(reference: "sub-a", tool: .codex, name: .init("Synthetic", "合成"))
        XCTAssertThrowsError(try SettingsConnectionSnapshot(tools: [.init(tool: .codex, presence: .detected, quota: .available)], subscriptions: [sub]))
        let row = SettingsConnectionToolState(tool: .codex, binding: .verified(references: ["sub-a"]))
        let valid = try SettingsConnectionSnapshot(tools: [row], subscriptions: [sub])
        XCTAssertEqual(valid.subscriptions.map(\.reference), ["sub-a"])
        XCTAssertThrowsError(try SettingsConnectionSnapshot(tools: [row, row]))
        XCTAssertThrowsError(try SettingsConnectionSnapshot(tools: [.init(tool: .codex, binding: .verified(references: ["\n"]))]))
        let second = SettingsVerifiedSubscription(reference: "sub-b", tool: .codex, name: .init("Second", "第二个"))
        let both = SettingsConnectionToolState(tool: .codex, binding: .verified(references: ["sub-a", "sub-b"]))
        XCTAssertEqual(try SettingsConnectionSnapshot(tools: [both], subscriptions: [sub, second]).subscriptions.count, 2)
    }
    func testUnknownCatalogueToolsRemainVisibleWithoutBecomingActionIDs() throws {
        let future = SettingsUnrecognizedTool(id: "future-tool", title: "Future tool", presence: .detected, access: .browserSession)
        let value = try SettingsConnectionSnapshot(unrecognizedTools: [future])
        XCTAssertEqual(value.unrecognizedTools, [future]); XCTAssertTrue(value.tools.isEmpty)
        XCTAssertNil(SettingsConnectionTool(rawValue: future.id))
        XCTAssertThrowsError(try SettingsConnectionSnapshot(unrecognizedTools: [future, future]))
        XCTAssertThrowsError(try SettingsConnectionSnapshot(unrecognizedTools: [.init(id: "../profile", title: "Unsafe")]))
        XCTAssertThrowsError(try SettingsConnectionSnapshot(unrecognizedTools: [.init(id: "codex", title: "Ambiguous")]))
    }
    func testRequestConfirmIsSingleUseAndPreviewNeverBecomesPermission() async throws {
        let fake = ConnectionFake(); fake.value = try snapshot()
        let controller = SettingsConnectionController(service: fake)
        await controller.refresh()
        let request = try XCTUnwrap(controller.request(.connect(.cursor, .standard)))
        XCTAssertTrue(fake.actions.isEmpty)
        XCTAssertEqual(controller.snapshot?.tools.first?.authorization, .noConsent)
        await controller.confirm(UUID()); XCTAssertTrue(fake.actions.isEmpty)
        await controller.confirm(request.id); await controller.confirm(request.id)
        XCTAssertEqual(fake.actions, [.connect(.cursor, .standard)])
        XCTAssertEqual(fake.requests.map(\.id), [request.id]); XCTAssertEqual(fake.requests.first?.expectedConsentGeneration, 1)
        XCTAssertEqual(controller.snapshot?.tools.first?.authorization, .noConsent, "only canonical observation can report permission")
    }
    func testAdvancedRequiresSeparateMatchingRequestAndStartsWithoutActions() async throws {
        let fake = ConnectionFake(); fake.value = try snapshot(access: .browserSession)
        let controller = SettingsConnectionController(service: fake)
        XCTAssertTrue(fake.actions.isEmpty); XCTAssertEqual(fake.detects, 0, "construction performs no detection")
        await controller.refresh()
        XCTAssertTrue(controller.snapshot!.standardTools.isEmpty)
        XCTAssertEqual(controller.snapshot!.advancedTools.count, 1)
        XCTAssertNil(controller.request(.connect(.cursor, .standard)))
        XCTAssertTrue(fake.actions.isEmpty)
        let confirmation = try XCTUnwrap(controller.request(.connect(.cursor, .browserSession)))
        XCTAssertTrue(SettingsConnectionPresentation.confirmation(confirmation.action).english.contains("separate consent"))
        controller.cancel(); await controller.confirm(confirmation.id)
        XCTAssertTrue(fake.actions.isEmpty)
    }
    func testPluginPlannedInstructionsAndFailedAreNotInstalled() async throws {
        let fake = ConnectionFake(), controller = SettingsConnectionController(service: nil)
        XCTAssertEqual(controller.phase, .unavailable)
        let available = SettingsConnectionController(service: fake)
        for status in [SettingsPluginInstallStatus.planned, .instructions, .failed, .installed] {
            fake.pluginStatus = status
            let confirmation = try XCTUnwrap(available.request(.installPlugin(.claudeCode)))
            await available.confirm(confirmation.id)
            let result = SettingsPluginInstallResult(tool: .claudeCode, status: status)
            XCTAssertEqual(available.phase, .pluginResult(result)); XCTAssertEqual(result.isInstalled, status == .installed)
            if status == .planned || status == .instructions {
                XCTAssertTrue(SettingsConnectionPresentation.status(available.phase).english.contains("not installed"))
            }
        }
    }
    func testMismatchedPluginReceiptIsNotAnInstallationSuccess() async throws {
        let fake = ConnectionFake(); fake.returnedPluginTool = .codex; fake.pluginStatus = .installed
        let controller = SettingsConnectionController(service: fake)
        let confirmation = try XCTUnwrap(controller.request(.installPlugin(.claudeCode)))
        await controller.confirm(confirmation.id)
        XCTAssertEqual(controller.phase, .failed(.invalidResponse))
    }
    func testBusyRejectsReentryAndOldDetectionCannotOverwriteNewObservation() async throws {
        let fake = ConnectionFake(); fake.pauseDetect = true
        let controller = SettingsConnectionController(service: fake)
        let pending = Task { await controller.refresh() }; try await waitForGate(fake)
        await controller.refresh(); XCTAssertEqual(fake.detects, 1)
        XCTAssertNil(controller.request(.installPlugin(.codex)))
        let newest = try snapshot(generation: 9, authorization: .denied)
        controller.receive(newest)
        fake.detectGate!.resume(returning: try snapshot(generation: 1, authorization: .allowed)); fake.detectGate = nil
        await pending.value
        XCTAssertEqual(controller.snapshot, newest); XCTAssertEqual(controller.phase, .idle)
    }
    func testCancelledUncooperativeResponseCannotChangeSnapshot() async throws {
        let fake = ConnectionFake(); fake.pauseDetect = true
        let controller = SettingsConnectionController(service: fake)
        let before = try snapshot(generation: 3); controller.receive(before)
        let pending = Task { await controller.refresh() }; try await waitForGate(fake)
        controller.cancel()
        fake.detectGate!.resume(returning: try snapshot(generation: 4, authorization: .allowed)); fake.detectGate = nil
        await pending.value
        XCTAssertEqual(controller.snapshot, before); XCTAssertEqual(controller.phase, .cancelled)
    }
    func testTaskCancellationAndCanonicalRollbackRemainExplicit() async throws {
        let fake = ConnectionFake(); fake.pauseDetect = true
        let controller = SettingsConnectionController(service: fake)
        let current = try snapshot(generation: 8); controller.receive(current)
        let pending = Task { await controller.refresh() }; try await waitForGate(fake)
        pending.cancel(); fake.detectGate!.resume(returning: try snapshot(generation: 9)); fake.detectGate = nil
        await pending.value
        XCTAssertEqual(controller.phase, .cancelled); XCTAssertEqual(controller.snapshot, current)
        fake.pauseDetect = false; fake.value = try snapshot(generation: 7)
        await controller.refresh()
        XCTAssertEqual(controller.phase, .failed(.stale)); XCTAssertEqual(controller.snapshot, current)
        fake.value = try snapshot(generation: nil)
        await controller.refresh()
        XCTAssertEqual(controller.phase, .failed(.stale)); XCTAssertEqual(controller.snapshot, current)
    }
    func testConfirmationIsInvalidatedByReentryAndNewObservation() async throws {
        let fake = ConnectionFake()
        let real = SettingsConnectionController(service: fake)
        real.receive(try snapshot())
        let old = try XCTUnwrap(real.request(.connect(.cursor, .standard)))
        real.receive(try snapshot(generation: 2))
        await real.confirm(old.id); XCTAssertTrue(fake.actions.isEmpty)
        let next = try XCTUnwrap(real.request(.disconnect(.cursor)))
        real.cancel(); await real.confirm(next.id); XCTAssertTrue(fake.actions.isEmpty)
    }
    func testRawFailureNeverEntersPresentation() async {
        let fake = ConnectionFake()
        fake.error = NSError(domain: "/Users/private/email@example.test/token", code: 4,
                             userInfo: [NSLocalizedDescriptionKey: "account-session-secret"])
        let controller = SettingsConnectionController(service: fake)
        await controller.refresh(); XCTAssertEqual(controller.phase, .failed(.requestFailed))
        let text = SettingsConnectionPresentation.status(controller.phase).english
        for secret in ["/Users", "email", "token", "session", "secret"] { XCTAssertFalse(text.contains(secret)) }
    }
    func testDisconnectReceiptCannotEraseVerifiedOwnership() async throws {
        let fake = ConnectionFake(), controller = SettingsConnectionController(service: nil)
        XCTAssertEqual(controller.phase, .unavailable)
        let available = SettingsConnectionController(service: fake)
        let row = SettingsConnectionToolState(tool: .codex, authorization: .allowed,
            binding: .verified(references: ["sub-a"]))
        let prior = try SettingsConnectionSnapshot(consentGeneration: 1, tools: [row],
            subscriptions: [.init(reference: "sub-a", tool: .codex, name: .init("Synthetic", "合成"))])
        available.receive(prior)
        fake.value = try SettingsConnectionSnapshot(consentGeneration: 2, tools: [.init(tool: .codex, authorization: .noConsent, connection: .off)])
        let confirmation = try XCTUnwrap(available.request(.disconnect(.codex)))
        await available.confirm(confirmation.id)
        XCTAssertEqual(available.phase, .failed(.invalidResponse)); XCTAssertEqual(available.snapshot, prior)
        XCTAssertEqual(fake.actions, [.disconnect(.codex)], "a rejected receipt does not pretend the external request never happened")
    }
    func testVisibilityIsIntentOnlyAndDoesNotEraseOwnershipOrGrantConsent() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("beta07-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SettingsStore(url: root.appendingPathComponent("settings.json"))
        var context = SettingsPageContext(); context.subscriptions = [.init(id: "sub-a", name: .init("Synthetic", "合成"))]
        let fake = ConnectionFake(), editor = SettingsEditor(store: store, context: context, connectionService: fake)
        let row = SettingsConnectionToolState(tool: .codex, authorization: .noConsent, connection: .off, binding: .verified(references: ["sub-a"]))
        let truth = try SettingsConnectionSnapshot(tools: [row], subscriptions: [.init(reference: "sub-a", tool: .codex, name: .init("Synthetic", "合成"))])
        editor.connections.receive(truth); await editor.reload()
        try await editor.commit(.visible("sub-a", false))
        XCTAssertEqual(editor.connections.snapshot, truth); XCTAssertEqual(editor.context.subscriptions.count, 1)
        XCTAssertTrue(editor.snapshot!.preferences.subscriptions.hiddenIDs.contains("sub-a")); XCTAssertTrue(fake.actions.isEmpty)
        try await editor.commit(.readerConsent(.gemini, true))
        XCTAssertEqual(editor.connections.snapshot?.tools.first?.authorization, .noConsent)
        XCTAssertTrue(fake.actions.isEmpty, "legacy local flags are not a shared grant or service call")
    }
}
