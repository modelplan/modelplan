// SPDX-License-Identifier: MIT
import Foundation
import AppKit
import XCTest
import ModelPlanSettings
import ModelPlanCommunityHost
@testable import ModelPlanAppIntegration

@MainActor private final class ConnectionSurfaceFake: SettingsWindowSurface {
    var prepares = 0, shows = 0, hides = 0
    var onPrepare: (() -> Void)?
    func prepare() async { prepares += 1; onPrepare?() }
    func show(paneID: String?) { shows += 1 }
    func hide() { hides += 1 }
}
@MainActor private final class ConnectionBackendFake: SettingsConnectionAllowing, SettingsConnectionAvailabilityProviding {
    var settingsConnectionAvailability = SettingsConnectionAvailability(canInspect: true, canGrant: true, canForget: true)
    var snapshot = try! SettingsConnectionSnapshot()
    var detects = 0, mutations = 0
    var pauseDetect = false
    var detectGate: CheckedContinuation<SettingsConnectionSnapshot, Never>?
    func detect() async throws -> SettingsConnectionSnapshot {
        detects += 1
        if pauseDetect { return await withCheckedContinuation { detectGate = $0 } }
        return snapshot
    }
    func applyStandardConsent(allow: [SettingsConnectionTool], deny: [SettingsConnectionTool], request: SettingsConnectionRequestContext) async throws -> SettingsConnectionSnapshot { mutations += 1; return snapshot }
    func connect(_ tool: SettingsConnectionTool, access: SettingsConnectionAccess, request: SettingsConnectionRequestContext) async throws -> SettingsConnectionSnapshot { mutations += 1; return snapshot }
    func disconnect(_ tool: SettingsConnectionTool, request: SettingsConnectionRequestContext) async throws -> SettingsConnectionSnapshot { mutations += 1; return snapshot }
    func installPlugin(_ tool: SettingsPluginTool, request: SettingsConnectionRequestContext) async throws -> SettingsPluginInstallResult { mutations += 1; return .init(tool: tool, status: .planned) }
}
@MainActor private final class UnwiredEntryStub: CommunitySettingsIntegration {
    var settingsMenuItem: NSMenuItem { fatalError("No menu should be constructed by a wiring check") }
    var restores = 0, pauseRestore = false
    var restoreGate: CheckedContinuation<Void, Never>?
    func restorePreferences() async {
        restores += 1
        if pauseRestore { await withCheckedContinuation { restoreGate = $0 } }
    }
    func suspend() {}
}
@MainActor final class ConnectionIntegrationTests: XCTestCase {
    private func application() throws -> SettingsApplicationCoordinator {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("connection-integration-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return SettingsApplicationCoordinator(store: try SettingsStore(url: root.appendingPathComponent("preferences.json")), apply: { _ in })
    }
    func testConstructionHasNoInspectionMutationOrSurfaceAndDefaultIsUnavailable() throws {
        let application = try application(), fake = ConnectionBackendFake(), surface = ConnectionSurfaceFake()
        var factories = 0
        let flow = try CommunityConnectionFlow(application: application, canPresent: { true }, showSettings: { _ in XCTFail("unexpected navigation") },
            makeFirstRun: { editor in XCTAssertTrue(editor === application.editor); factories += 1; return surface })
        XCTAssertEqual(application.editor.connections.phase, .unavailable)
        XCTAssertEqual(factories, 0); XCTAssertEqual(fake.detects, 0); XCTAssertEqual(fake.mutations, 0)
        flow.dispose(); XCTAssertFalse(application.editor.canPresentFirstRun)
    }
    func testFreshRestoreReachesExistingFirstRunWithSameEditorAndOnlyInspects() async throws {
        let application = try application(), backend = ConnectionBackendFake(), surface = ConnectionSurfaceFake()
        let editor = application.editor; var factories = 0, activations = 0
        let flow = try CommunityConnectionFlow(application: application, backend: backend, canPresent: { true },
            showSettings: { _ in XCTFail("fresh setup should use first run") }, activate: { activations += 1 },
            makeFirstRun: { current in XCTAssertTrue(current === editor); factories += 1; return surface })
        await flow.restoreFirstRunIfNeeded()
        XCTAssertEqual(backend.detects, 1); XCTAssertEqual(backend.mutations, 0)
        XCTAssertEqual(factories, 1); XCTAssertEqual(surface.shows, 1); XCTAssertEqual(activations, 0)
        await flow.openFirstRun(); XCTAssertEqual(factories, 1); XCTAssertEqual(surface.shows, 2); XCTAssertEqual(activations, 1)
        flow.dispose()
    }
    func testExistingFirstRunActionReachesSurfaceWithoutTakingSystemEffectReceiver() async throws {
        let application = try application(), surface = ConnectionSurfaceFake()
        await application.reload(); var hostRequests = 0
        application.editor.onHostRequest = { _ in hostRequests += 1 }
        let flow = try CommunityConnectionFlow(application: application, canPresent: { true }, showSettings: { _ in XCTFail("unexpected") },
            makeFirstRun: { _ in surface })
        try application.editor.request(.previewFirstRun)
        for _ in 0..<100 where surface.shows == 0 { await Task.yield() }
        XCTAssertEqual(surface.shows, 1); XCTAssertEqual(hostRequests, 0)
        flow.dispose()
    }
    func testLifecycleLossDuringPreparationDoesNotShowOrActivate() async throws {
        let application = try application(), surface = ConnectionSurfaceFake(); var active = true, activations = 0
        var flow: CommunityConnectionFlow?
        surface.onPrepare = { active = false; flow?.suspend() }
        flow = try CommunityConnectionFlow(application: application, canPresent: { active }, showSettings: { _ in XCTFail("unexpected") },
            activate: { activations += 1 }, makeFirstRun: { _ in surface })
        await flow!.openFirstRun()
        XCTAssertEqual(surface.shows, 0); XCTAssertEqual(activations, 0); XCTAssertEqual(surface.hides, 1)
        flow!.dispose()
    }
    func testCompletedSetupRoutesActionableMissingDataToConnectionsOrAbout() async throws {
        let application = try application(), surface = ConnectionSurfaceFake(), backend = ConnectionBackendFake()
        await application.reload()
        _ = try await application.editor.completeFirstRun(options: .init(preferences: application.editor.snapshot!.preferences),
            action: .done, host: .standalone, expectedRevision: application.editor.snapshot!.revision)
        var panes: [String?] = [], factories = 0
        let flow = try CommunityConnectionFlow(application: application, backend: backend, canPresent: { true }, showSettings: { panes.append($0) },
            makeFirstRun: { _ in factories += 1; return surface })
        await flow.restoreFirstRunIfNeeded(); XCTAssertEqual(backend.detects, 1); XCTAssertEqual(factories, 0)
        let allow = try XCTUnwrap(CommunityConnectionNextStep.forReason(.noConsent))
        XCTAssertEqual(allow.title.chinese, "授权读取")
        let action = flow.action(for: allow); action()
        for _ in 0..<100 where panes.isEmpty { await Task.yield() }
        XCTAssertEqual(panes.count, 1); XCTAssertEqual(panes[0], "subscriptions")
        await flow.perform(.about); XCTAssertEqual(panes.last!, "about")
        XCTAssertEqual(backend.mutations, 0); XCTAssertEqual(factories, 0)
        XCTAssertNil(CommunityConnectionNextStep.forReason(.fresh)); flow.dispose()
    }
    func testFactProjectionUsesVerifiedRefsAndKeepsSamePreferencesAndSafeAboutInput() async throws {
        let application = try application(); await application.reload()
        let store = application.editor.store, surface = ConnectionSurfaceFake()
        let flow = try CommunityConnectionFlow(application: application, canPresent: { false }, showSettings: { _ in XCTFail("not visible") }, makeFirstRun: { _ in surface })
        let snapshot = try SettingsConnectionSnapshot(consentGeneration: 3,
            tools: [.init(tool: .codex, authorization: .noConsent, connection: .off, quota: .stale, binding: .verified(references: ["verified-a"]))],
            subscriptions: [.init(reference: "verified-a", tool: .codex, name: .init("Synthetic plan", "合成方案"))])
        let notice = SettingsLicenseNotice(component: "Fixture component", license: "MIT", text: "Synthetic notice")
        flow.apply(.init(connections: snapshot, about: .init(appVersion: "1.2.3"), licenseNotices: [notice]))
        XCTAssertTrue(application.editor.store === store); XCTAssertEqual(application.editor.context.subscriptions.map(\.id), ["verified-a"])
        XCTAssertEqual(application.editor.context.subscriptions.first?.source, .stale)
        XCTAssertEqual(application.editor.context.licenseNotices, [notice]); XCTAssertEqual(application.editor.context.about.version, "1.2.3")
        try await application.editor.commit(.visible("verified-a", false))
        XCTAssertEqual(application.editor.connections.snapshot, snapshot); XCTAssertEqual(application.editor.context.subscriptions.count, 1)
        flow.dispose()
    }
    func testNewerFactsCannotBeOverwrittenByStaleApplicationInput() async throws {
        let application = try application(), surface = ConnectionSurfaceFake()
        let flow = try CommunityConnectionFlow(application: application, canPresent: { false }, showSettings: { _ in }, makeFirstRun: { _ in surface })
        let current = try SettingsConnectionSnapshot(consentGeneration: 8, tools: [.init(tool: .codex, authorization: .denied)])
        flow.apply(.init(connections: current, about: .init(appVersion: "2.0.0")))
        flow.apply(.init(connections: try SettingsConnectionSnapshot(consentGeneration: 7), about: .init(appVersion: "1.0.0")))
        XCTAssertEqual(application.editor.connections.snapshot, current); XCTAssertEqual(application.editor.context.about.version, "2.0.0")
        flow.dispose()
    }
    func testActualIntegrationEntryRefusesAbsentBackendAndCheckRejectsOldEntry() throws {
        let application = try application()
        let flow = try CommunityConnectionFlow(application: application, canPresent: { false }, showSettings: { _ in })
        XCTAssertThrowsError(try CommunityConnectionIntegration(base: UnwiredEntryStub(), flow: flow)) {
            XCTAssertEqual($0 as? CommunityConnectionWiringError, .backendMissing)
        }
        XCTAssertThrowsError(try CommunityConnectionWiring.requireInstalled(UnwiredEntryStub(), application: application, backend: ConnectionBackendFake())) {
            XCTAssertEqual($0 as? CommunityConnectionWiringError, .entryMissing)
        }
        flow.dispose()
    }
    func testEntryWiringCheckUsesReturnedIntegrationAndSameApplication() throws {
        let application = try application(), backend = ConnectionBackendFake()
        let flow = try CommunityConnectionFlow(application: application, backend: backend, canPresent: { false }, showSettings: { _ in })
        let entry = try CommunityConnectionIntegration(base: UnwiredEntryStub(), flow: flow)
        XCTAssertNoThrow(try CommunityConnectionWiring.requireInstalled(entry, application: application, backend: backend))
        XCTAssertThrowsError(try CommunityConnectionWiring.requireInstalled(entry, application: self.application(), backend: backend)) {
            XCTAssertEqual($0 as? CommunityConnectionWiringError, .differentApplication)
        }
        XCTAssertThrowsError(try CommunityConnectionWiring.requireInstalled(entry, application: application, backend: ConnectionBackendFake())) {
            XCTAssertEqual($0 as? CommunityConnectionWiringError, .differentBackend)
        }
        XCTAssertEqual(backend.detects, 0); XCTAssertEqual(backend.mutations, 0)
        flow.dispose()
    }
    func testCompletedOnboardingRestartRestoresCanonicalAdmissionExactlyOnceWithoutAWindow() async throws {
        let application = try application(); await application.reload()
        _ = try await application.editor.completeFirstRun(options: .init(preferences: application.editor.snapshot!.preferences),
            action: .done, host: .standalone, expectedRevision: application.editor.snapshot!.revision)
        let backend = ConnectionBackendFake(), base = UnwiredEntryStub(); var surfaces = 0
        backend.snapshot = try .init(consentGeneration: 7, tools: [.init(tool: .codex, authorization: .allowed)], mode: .automatic)
        let flow = try CommunityConnectionFlow(application: application, backend: backend, canPresent: { false }, showSettings: { _ in XCTFail("unexpected window") },
            makeFirstRun: { _ in surfaces += 1; return ConnectionSurfaceFake() })
        let entry = try CommunityConnectionIntegration(base: base, flow: flow)
        async let first: Void = entry.restorePreferences()
        async let second: Void = entry.restorePreferences()
        _ = await (first, second); await entry.restorePreferences()
        XCTAssertEqual(base.restores, 1); XCTAssertEqual(backend.detects, 1)
        XCTAssertEqual(application.editor.connections.snapshot, backend.snapshot)
        XCTAssertEqual(application.editor.connections.snapshot?.mode, .automatic); XCTAssertEqual(surfaces, 0)
        flow.dispose()
    }
    func testIncompleteEntryRestoreInspectsOnceAndThenShowsFirstRun() async throws {
        let application = try application(), backend = ConnectionBackendFake(), base = UnwiredEntryStub(), surface = ConnectionSurfaceFake()
        let flow = try CommunityConnectionFlow(application: application, backend: backend, canPresent: { true }, showSettings: { _ in }, makeFirstRun: { _ in surface })
        let entry = try CommunityConnectionIntegration(base: base, flow: flow)
        await entry.restorePreferences(); await entry.restorePreferences()
        XCTAssertEqual(backend.detects, 1); XCTAssertEqual(surface.shows, 1); XCTAssertEqual(backend.mutations, 0)
        flow.dispose()
    }
    func testSuspensionDuringBaseRestoreCannotInspectOrReopenLate() async throws {
        let application = try application(), backend = ConnectionBackendFake(), base = UnwiredEntryStub(), surface = ConnectionSurfaceFake()
        base.pauseRestore = true
        let flow = try CommunityConnectionFlow(application: application, backend: backend, canPresent: { true }, showSettings: { _ in }, makeFirstRun: { _ in surface })
        let entry = try CommunityConnectionIntegration(base: base, flow: flow)
        let pending = Task { await entry.restorePreferences() }
        for _ in 0..<100 where base.restoreGate == nil { await Task.yield() }
        let gate = try XCTUnwrap(base.restoreGate); entry.suspend(); gate.resume(); await pending.value
        XCTAssertEqual(backend.detects, 0); XCTAssertEqual(surface.shows, 0)
        flow.dispose()
    }
    func testSuspensionDuringCanonicalInspectionCannotPublishOrReopenLate() async throws {
        let application = try application(), backend = ConnectionBackendFake(), surface = ConnectionSurfaceFake()
        backend.pauseDetect = true
        let flow = try CommunityConnectionFlow(application: application, backend: backend, canPresent: { true }, showSettings: { _ in }, makeFirstRun: { _ in surface })
        let entry = try CommunityConnectionIntegration(base: UnwiredEntryStub(), flow: flow)
        let pending = Task { await entry.restorePreferences() }
        for _ in 0..<100 where backend.detectGate == nil { await Task.yield() }
        let gate = try XCTUnwrap(backend.detectGate); entry.suspend()
        gate.resume(returning: try .init(consentGeneration: 9, tools: [.init(tool: .codex, authorization: .allowed)], mode: .automatic))
        await pending.value
        XCTAssertEqual(backend.detects, 1); XCTAssertNil(application.editor.connections.snapshot); XCTAssertEqual(surface.shows, 0)
        flow.dispose()
    }
    func testUnavailableComponentHasOneLocalAboutActionAndNoServiceRetry() async throws {
        let application = try application(), backend = ConnectionBackendFake(), surface = ConnectionSurfaceFake()
        backend.settingsConnectionAvailability = .init(reason: .componentUnverified)
        var panes: [String?] = []
        let flow = try CommunityConnectionFlow(application: application, backend: backend, canPresent: { true }, showSettings: { panes.append($0) }, makeFirstRun: { _ in surface })
        let entry = try CommunityConnectionIntegration(base: UnwiredEntryStub(), flow: flow)
        await entry.restorePreferences(); await entry.restorePreferences()
        XCTAssertEqual(backend.detects, 0); XCTAssertEqual(backend.mutations, 0)
        XCTAssertEqual(application.editor.connections.phase, .unavailable); XCTAssertEqual(surface.shows, 1)
        XCTAssertTrue(application.editor.canPresentConnectionHelp)
        try application.editor.requestConnectionHelp()
        for _ in 0..<100 where panes.isEmpty { await Task.yield() }
        XCTAssertEqual(panes.count, 1); XCTAssertEqual(panes[0], "about")
        XCTAssertEqual(backend.detects, 0); XCTAssertEqual(backend.mutations, 0)
        flow.dispose(); XCTAssertFalse(application.editor.canPresentConnectionHelp)
    }
}
