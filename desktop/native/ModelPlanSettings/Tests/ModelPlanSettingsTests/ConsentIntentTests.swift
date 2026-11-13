// SPDX-License-Identifier: MIT
import Foundation
import XCTest
@testable import ModelPlanSettings

@MainActor private class IntentInspectOnly: SettingsConnectionAvailabilityProviding {
    var settingsConnectionAvailability: SettingsConnectionAvailability { .init(canInspect: true) }
    var facts = try! SettingsConnectionSnapshot()
    var detects = 0
    func detect() async throws -> SettingsConnectionSnapshot { detects += 1; return facts }
    func connect(_ tool: SettingsConnectionTool, access: SettingsConnectionAccess, request: SettingsConnectionRequestContext) async throws -> SettingsConnectionSnapshot { throw SettingsConnectionFailure.unavailable }
    func disconnect(_ tool: SettingsConnectionTool, request: SettingsConnectionRequestContext) async throws -> SettingsConnectionSnapshot { throw SettingsConnectionFailure.unavailable }
    func installPlugin(_ tool: SettingsPluginTool, request: SettingsConnectionRequestContext) async throws -> SettingsPluginInstallResult { throw SettingsConnectionFailure.unavailable }
}
@MainActor private final class IntentAtomicFake: IntentInspectOnly, SettingsConnectionAllowing {
    override var settingsConnectionAvailability: SettingsConnectionAvailability { .init(canInspect: true, canGrant: true, canForget: true) }
    var calls: [([SettingsConnectionTool], [SettingsConnectionTool], SettingsConnectionRequestContext)] = []
    func applyStandardConsent(allow: [SettingsConnectionTool], deny: [SettingsConnectionTool], request: SettingsConnectionRequestContext) async throws -> SettingsConnectionSnapshot {
        calls.append((allow, deny, request)); return facts
    }
}
@MainActor final class ConsentIntentTests: XCTestCase {
    private func facts(generation: UInt64? = 1, version: Int? = 7, allowed: Bool = false, mode: SettingsReadingMode = .automatic) throws -> SettingsConnectionSnapshot {
        try .init(consentGeneration: generation, tools: [
            .init(tool: .codex, presence: .detected, authorization: allowed ? .allowed : .noConsent, support: .full),
            .init(tool: .cursor, presence: .detected, support: .full, access: .browserSession),
            .init(tool: .claude, presence: .notDetected, support: .full),
        ], consentPreview: version.map { .init(textVersion: $0, notice: .init("Synthetic consent", "合成授权说明"), standardTools: [.codex]) }, mode: mode)
    }
    func testPrecheckedStandardChoicesAreOnlyIntentAndBrowserSessionCannotJoin() throws {
        let snapshot = try facts(); var intent = SettingsConnectionIntent(snapshot: snapshot)
        XCTAssertEqual(intent.selected, [.codex]); XCTAssertEqual(snapshot.tools[0].authorization, .noConsent)
        intent.select(.cursor, enabled: true); intent.select(.claude, enabled: true)
        XCTAssertEqual(intent.orderedTools, [.codex])
        intent.select(.codex, enabled: false); XCTAssertTrue(intent.selected.isEmpty)
        XCTAssertEqual(snapshot.tools[0].authorization, .noConsent)
    }
    func testBatchRequiresAtomicBackendPreviewAndCanonicalGeneration() throws {
        let inspect = IntentInspectOnly()
        let readonly = SettingsConnectionController(service: inspect), value = try facts()
        readonly.receive(value); XCTAssertFalse(readonly.canAllow(.init(snapshot: value)))
        let atomic = IntentAtomicFake(), bound = SettingsConnectionController()
        XCTAssertTrue(bound.bind(service: atomic)); XCTAssertFalse(bound.bind(service: IntentAtomicFake()))
        for value in [try facts(version: nil), try facts(generation: nil)] {
            bound.receive(value); XCTAssertFalse(bound.canAllow(.init(snapshot: value)))
        }
        bound.receive(value); XCTAssertTrue(bound.canAllow(.init(snapshot: value)))
        XCTAssertTrue(atomic.calls.isEmpty); XCTAssertEqual(atomic.detects, 0)
    }
    func testOnlyExplicitConfirmationCallsOneAtomicBatchWithExactContext() async throws {
        let fake = IntentAtomicFake()
        let actual = SettingsConnectionController(service: fake), before = try facts()
        actual.receive(before); fake.facts = try facts(generation: 2, allowed: true)
        let request = try XCTUnwrap(actual.requestAllow(.init(snapshot: before)))
        XCTAssertTrue(fake.calls.isEmpty); XCTAssertEqual(actual.snapshot, before)
        await actual.confirm(UUID()); XCTAssertTrue(fake.calls.isEmpty)
        await actual.confirm(request.id); await actual.confirm(request.id)
        XCTAssertEqual(fake.calls.count, 1); XCTAssertEqual(fake.calls[0].0, [.codex])
        XCTAssertTrue(fake.calls[0].1.isEmpty)
        XCTAssertEqual(fake.calls[0].2.id, request.id)
        XCTAssertEqual(fake.calls[0].2.expectedConsentGeneration, 1); XCTAssertEqual(fake.calls[0].2.consentTextVersion, 7)
        XCTAssertEqual(actual.snapshot?.tools[0].authorization, .allowed)
    }
    func testNewPolicyOrObserverRevocationInvalidatesOldIntentBeforeDispatch() async throws {
        let fake = IntentAtomicFake()
        let controller = SettingsConnectionController(service: fake), before = try facts()
        controller.receive(before); let intent = SettingsConnectionIntent(snapshot: before)
        let newer = try facts(generation: 2, version: 8)
        controller.receive(newer); XCTAssertNil(controller.requestAllow(intent))
        let observer = controller.observe { if case .running = controller.phase { controller.receive(try! self.facts(generation: 3, version: 9)) } }
        let request = try XCTUnwrap(controller.requestAllow(.init(snapshot: newer)))
        await controller.confirm(request.id)
        XCTAssertTrue(fake.calls.isEmpty); XCTAssertEqual(controller.snapshot?.consentGeneration, 3)
        controller.removeObserver(observer)
    }
    func testIncompleteBatchReadbackIsNotSuccessOrAnAutomaticRetry() async throws {
        let fake = IntentAtomicFake(), controller = SettingsConnectionController(service: fake)
        let before = try facts(); controller.receive(before)
        fake.facts = try facts(generation: 2, allowed: false)
        let request = try XCTUnwrap(controller.requestAllow(.init(snapshot: before)))
        await controller.confirm(request.id)
        XCTAssertEqual(fake.calls.count, 1); XCTAssertEqual(controller.phase, .failed(.invalidResponse))
        XCTAssertEqual(controller.snapshot, fake.facts, "preserve actual canonical readback instead of inventing a grant or rollback")
    }
    func testPreviewCannotAdmitBrowserOrMissingTools() throws {
        XCTAssertThrowsError(try SettingsConnectionSnapshot(tools: [.init(tool: .cursor, presence: .detected, support: .full, access: .browserSession)],
            consentPreview: .init(textVersion: 1, notice: .init("Test", "测试"), standardTools: [.cursor])))
    }
    func testUncheckingAnAllowedToolOmitsItWithoutGeneratingDenyOrForget() async throws {
        let fake = IntentAtomicFake(), controller = SettingsConnectionController(service: fake)
        let before = try SettingsConnectionSnapshot(consentGeneration: 1, tools: [
            .init(tool: .codex, presence: .detected, authorization: .noConsent, support: .full),
            .init(tool: .claude, presence: .detected, authorization: .allowed, support: .full),
        ], consentPreview: .init(textVersion: 7, notice: .init("Exact", "原文"), standardTools: [.codex, .claude]), mode: .automatic)
        controller.receive(before); var intent = SettingsConnectionIntent(snapshot: before)
        intent.select(.claude, enabled: false)
        fake.facts = try SettingsConnectionSnapshot(consentGeneration: 2, tools: [
            .init(tool: .codex, presence: .detected, authorization: .allowed, support: .full),
            .init(tool: .claude, presence: .detected, authorization: .allowed, support: .full),
        ], mode: .automatic)
        let request = try XCTUnwrap(controller.requestAllow(intent)); await controller.confirm(request.id)
        XCTAssertEqual(fake.calls.count, 1); XCTAssertEqual(fake.calls[0].0, [.codex]); XCTAssertTrue(fake.calls[0].1.isEmpty)
        XCTAssertEqual(controller.snapshot?.tools.first { $0.tool == .claude }?.authorization, .allowed)
    }
    func testCanonicalBlockedModeIsNeverReportedAsLocalActivation() async throws {
        let fake = IntentAtomicFake(), controller = SettingsConnectionController(service: fake)
        let before = try facts(); controller.receive(before)
        fake.facts = try facts(generation: 2, allowed: true, mode: .off)
        let request = try XCTUnwrap(controller.requestAllow(.init(snapshot: before)))
        await controller.confirm(request.id)
        XCTAssertEqual(controller.snapshot?.mode, .off)
        XCTAssertEqual(controller.phase, .consentRecordedReadingBlocked(.off))
        XCTAssertFalse(controller.canAllow(.init(snapshot: fake.facts)))
    }
    func testExplicitForgetIsIndependentOfGrantEligibilityAndDoesNotOptIntoKeychain() async throws {
        let fake = IntentAtomicFake(), controller = SettingsConnectionController(service: fake)
        let before = try SettingsConnectionSnapshot(consentGeneration: 1, tools: [
            .init(tool: .codex, presence: .detected, authorization: .allowed, consentEligible: false, keychain: .denied),
        ], consentPreview: .init(textVersion: 7, notice: .init("Exact", "原文"), standardTools: [], deniableTools: [.codex]), mode: .off)
        controller.receive(before)
        XCTAssertFalse(controller.canAllow(.init(snapshot: before)))
        XCTAssertNil(controller.request(.applyStandardConsent(allow: [.codex], deny: [])))
        let request = try XCTUnwrap(controller.requestForget(.codex))
        XCTAssertTrue(SettingsConnectionPresentation.confirmation(request.action).english.contains("deletes"))
        XCTAssertTrue(fake.calls.isEmpty, "even explicit Forget must wait for confirmation")
        fake.facts = try .init(consentGeneration: 2, tools: [
            .init(tool: .codex, presence: .detected, authorization: .noConsent, consentEligible: false, keychain: .denied),
        ], mode: .off)
        await controller.confirm(request.id)
        XCTAssertEqual(fake.calls.count, 1); XCTAssertTrue(fake.calls[0].0.isEmpty); XCTAssertEqual(fake.calls[0].1, [.codex])
        XCTAssertEqual(controller.snapshot?.tools.first?.keychain, .denied)
        XCTAssertEqual(controller.phase, .consentRecordedReadingBlocked(.off))
    }
    func testFirstRunFailureCopyDoesNotClaimActivationOrExposeRawReasons() {
        XCTAssertTrue(SettingsConnectionPresentation.status(.unavailable).english.contains("About"))
        XCTAssertTrue(SettingsConnectionPresentation.status(.failed(.stale)).chinese.contains("当前说明"))
        XCTAssertTrue(SettingsConnectionPresentation.status(.failed(.invalidResponse)).english.contains("No successful permission"))
        let blocked = SettingsConnectionPresentation.status(.consentRecordedReadingBlocked(.off))
        XCTAssertTrue(blocked.english.contains("off") && blocked.english.contains("About"))
        XCTAssertTrue(blocked.chinese.contains("停用") && blocked.chinese.contains("关于"))
        XCTAssertNotEqual(blocked.english, "off", "A raw mode is not a human next step")
    }
}
