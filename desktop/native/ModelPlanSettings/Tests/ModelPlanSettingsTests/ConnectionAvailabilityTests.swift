// SPDX-License-Identifier: MIT
import Foundation
import XCTest
@testable import ModelPlanSettings

@MainActor private final class AvailabilityFake: SettingsConnectionAllowing, SettingsConnectionAvailabilityProviding {
    var settingsConnectionAvailability = SettingsConnectionAvailability(reason: .componentUnverified)
    var calls: [String] = []
    var snapshot = try! SettingsConnectionSnapshot()
    func detect() async throws -> SettingsConnectionSnapshot { calls.append("inspect"); return snapshot }
    func applyStandardConsent(allow: [SettingsConnectionTool], deny: [SettingsConnectionTool], request: SettingsConnectionRequestContext) async throws -> SettingsConnectionSnapshot { calls.append("grant"); return snapshot }
    func connect(_ tool: SettingsConnectionTool, access: SettingsConnectionAccess, request: SettingsConnectionRequestContext) async throws -> SettingsConnectionSnapshot { calls.append("connect"); return snapshot }
    func disconnect(_ tool: SettingsConnectionTool, request: SettingsConnectionRequestContext) async throws -> SettingsConnectionSnapshot { calls.append("forget"); return snapshot }
    func installPlugin(_ tool: SettingsPluginTool, request: SettingsConnectionRequestContext) async throws -> SettingsPluginInstallResult { calls.append("plugin"); return .init(tool: tool, status: .installed) }
}
@MainActor final class ConnectionAvailabilityTests: XCTestCase {
    private func facts() throws -> SettingsConnectionSnapshot {
        try .init(consentGeneration: 1, tools: [.init(tool: .codex, presence: .detected, support: .full)],
            consentPreview: .init(textVersion: 1, notice: .init("Exact", "原文"), standardTools: [.codex], deniableTools: [.codex]), mode: .automatic)
    }
    func testInstalledButUnverifiedComponentDispatchesNoGuaranteedFailure() async throws {
        let fake = AvailabilityFake(), controller = SettingsConnectionController(service: fake)
        controller.receive(try facts())
        XCTAssertTrue(controller.hasAllowanceBackend); XCTAssertFalse(controller.isAvailable)
        XCTAssertEqual(controller.phase, .unavailable); XCTAssertEqual(controller.availability.reason, .componentUnverified)
        await controller.refresh()
        XCTAssertFalse(controller.canAllow(.init(snapshot: controller.snapshot!)))
        XCTAssertFalse(controller.canConnect(.codex, access: .standard)); XCTAssertFalse(controller.canForget(.codex))
        XCTAssertNil(controller.request(.installPlugin(.codex))); XCTAssertTrue(fake.calls.isEmpty)
    }
    func testVerifiedInspectionGrantAndPluginCapabilitiesAreIndependent() async throws {
        let fake = AvailabilityFake(), controller = SettingsConnectionController(service: fake)
        fake.snapshot = try facts()
        controller.updateAvailability(.init(canInspect: true, canGrant: true))
        await controller.refresh()
        XCTAssertEqual(fake.calls, ["inspect"])
        XCTAssertTrue(controller.canAllow(.init(snapshot: fake.snapshot)))
        XCTAssertFalse(controller.canForget(.codex)); XCTAssertNil(controller.request(.installPlugin(.codex)))
        controller.updateAvailability(.init(canInspect: true, pluginTools: [.claudeCode]))
        XCTAssertFalse(controller.canAllow(.init(snapshot: fake.snapshot)))
        XCTAssertNotNil(controller.request(.installPlugin(.claudeCode)))
        XCTAssertEqual(fake.calls, ["inspect"], "capability changes and confirmation presentation execute nothing")
    }
    func testUnavailableReasonsHaveHumanBilingualRemediation() {
        for reason in [SettingsConnectionUnavailableReason.componentMissing, .componentUpdating, .componentUnverified, .unavailable] {
            let copy = SettingsConnectionPresentation.availability(.init(reason: reason))
            XCTAssertTrue(copy!.english.contains("About")); XCTAssertTrue(copy!.chinese.contains("关于"))
            XCTAssertFalse(copy!.english.contains("Request unavailable:"))
        }
    }
    func testNoBackendCannotBeEnabledByCapabilityOnly() async {
        let controller = SettingsConnectionController()
        controller.updateAvailability(.init(canInspect: true, canGrant: true, pluginTools: [.codex]))
        XCTAssertFalse(controller.isAvailable); XCTAssertFalse(controller.availability.canInspect)
        XCTAssertTrue(controller.availability.pluginTools.isEmpty); await controller.refresh()
        XCTAssertEqual(controller.phase, .unavailable)
    }
    func testCapabilityRevocationFromObserverPreventsDispatch() async throws {
        let fake = AvailabilityFake(); fake.settingsConnectionAvailability = .init(canInspect: true, canGrant: true)
        let controller = SettingsConnectionController(service: fake); controller.receive(try facts())
        let observer = controller.observe { if case .running = controller.phase { controller.updateAvailability(.unverified) } }
        let request = try XCTUnwrap(controller.requestAllow(.init(snapshot: controller.snapshot!)))
        await controller.confirm(request.id)
        XCTAssertTrue(fake.calls.isEmpty); XCTAssertEqual(controller.phase, .unavailable)
        controller.removeObserver(observer)
    }
}
