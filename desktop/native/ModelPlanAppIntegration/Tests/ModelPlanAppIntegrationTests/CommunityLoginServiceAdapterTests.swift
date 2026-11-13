// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanShell
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor private final class AdapterLoginService: PulseLoginService {
    var value: PulseLoginState = .off, reads = 0, registers = 0, unregisters = 0
    var state: PulseLoginState { reads += 1; return value }
    var notFound = false
    var isNotFound: Bool { notFound }
    func register() throws { registers += 1; value = .needsApproval }
    func unregister() throws { unregisters += 1; value = .off }
}
@MainActor final class CommunityLoginServiceAdapterTests: XCTestCase {
    /// G3-69: only SMAppService `.notFound` (service reports it) is "not in Applications"; other unavailable causes stay generic.
    func testNotFoundIsDistinguishedFromOtherUnavailableCauses() {
        let service = AdapterLoginService(); service.value = .unavailable
        let adapter = CommunityLoginServiceAdapter(item: .init(isAppBundle: true, service: service))
        XCTAssertEqual(adapter.observedState, .unavailable); XCTAssertFalse(adapter.observedNotInApplications)
        service.notFound = true; XCTAssertTrue(adapter.observedNotInApplications)
        service.value = .off; XCTAssertFalse(adapter.observedNotInApplications)
        let bare = CommunityLoginServiceAdapter(item: .init(isAppBundle: false, service: service))
        XCTAssertFalse(bare.observedNotInApplications)
    }
    private func editor() async throws -> (SettingsEditor, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("login-adapter-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("settings.json")
        let editor = SettingsEditor(store: try SettingsStore(url: url))
        await editor.reload(); return (editor, url)
    }
    func testExplicitEditorRequestRequiresAuthorizationRejectsReplayAndKeepsSavedChoice() async throws {
        let (editor, url) = try await editor()
        let service = AdapterLoginService(), adapter = CommunityLoginServiceAdapter(item: .init(isAppBundle: true, service: service))
        XCTAssertTrue(try XCTUnwrap(editor.snapshot).preferences.openAtLogin)
        XCTAssertEqual(service.reads, 0); XCTAssertEqual(service.registers, 0)
        var emitted: SettingsHostRequest?
        editor.onHostRequest = { emitted = $0 }
        let current = try await editor.commit(SettingsB21Edit.login(true))
        let request = try XCTUnwrap(emitted), bytes = try Data(contentsOf: url)
        XCTAssertEqual(adapter.handle(request, current: current), .notAuthorized)
        XCTAssertEqual(service.reads, 0)
        XCTAssertEqual(adapter.handle(request, current: current, mayChangeLoginItem: true), .performed(.requiresApproval))
        XCTAssertEqual(service.registers, 1); XCTAssertEqual(adapter.observedState, .requiresApproval)
        XCTAssertEqual(adapter.handle(request, current: current, mayChangeLoginItem: true), .alreadyHandled)
        XCTAssertEqual(service.registers, 1); XCTAssertEqual(try Data(contentsOf: url), bytes)
        XCTAssertTrue(try XCTUnwrap(editor.snapshot).preferences.openAtLogin)
        let later = try await editor.commit(SettingsB21Edit.autoHide(false))
        let reads = service.reads
        XCTAssertEqual(adapter.handle(request, current: later, mayChangeLoginItem: true), .stale)
        XCTAssertEqual(service.reads, reads)
    }
    func testFirstRunExplicitRequestUsesSameAdapterWithoutBootRegistration() async throws {
        let (editor, _) = try await editor()
        let service = AdapterLoginService(), adapter = CommunityLoginServiceAdapter(item: .init(isAppBundle: true, service: service))
        XCTAssertEqual(service.registers, 0)
        var emitted: SettingsHostRequest?; editor.onHostRequest = { emitted = $0 }
        let options = OnboardingOptions(preferences: try XCTUnwrap(editor.snapshot).preferences)
        _ = try await editor.completeFirstRun(options: options, action: .done, host: .standalone, expectedRevision: try XCTUnwrap(editor.snapshot).revision)
        let request = try XCTUnwrap(emitted), current = try XCTUnwrap(editor.snapshot)
        XCTAssertEqual(service.registers, 0, "persisting the first-run preference is not an OS effect")
        XCTAssertEqual(adapter.handle(request, current: current, mayChangeLoginItem: true), .performed(.requiresApproval))
        XCTAssertEqual(service.registers, 1)
    }
    func testNormalEntryDoneAppliesCheckedAndUncheckedLoginChoicesOnce() async throws {
        for enabled in [true, false] {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("first-run-login-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: directory, preferredLanguages: ["en"])
            let app = EngineRowsEntry.make(configuration: .init(executableURL: directory.appendingPathComponent("not-launched"),
                applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: store,
                createsNativePanels: false, dockEnvironment: normalEntryTestEnvironment, activateSettings: {})
            defer { app.composition.dock.close() }
            let service = AdapterLoginService()
            app.loginServiceAdapter = CommunityLoginServiceAdapter(item: .init(isAppBundle: true, service: service))
            await app.prepare()
            let editor = app.settingsHost.application.editor
            let before = try XCTUnwrap(editor.snapshot)
            XCTAssertTrue(before.preferences.openAtLogin)
            XCTAssertEqual(service.registers, 0)
            var options = OnboardingOptions(preferences: before.preferences)
            options.openAtLogin = enabled
            _ = try await editor.completeFirstRun(options: options, action: .done, host: .popup,
                expectedRevision: before.revision)
            XCTAssertEqual(editor.snapshot?.preferences.openAtLogin, enabled)
            XCTAssertEqual(service.registers, enabled ? 1 : 0)
            XCTAssertEqual(service.unregisters, 0)
            await app.prepare()
            XCTAssertEqual(service.registers, enabled ? 1 : 0, "Restoration must not repeat the login effect")
        }
    }

    func testUnrelatedHostRequestIsNotClaimedOrObserved() async throws {
        let (editor, _) = try await editor()
        let service = AdapterLoginService(), adapter = CommunityLoginServiceAdapter(item: .init(isAppBundle: true, service: service))
        var emitted: SettingsHostRequest?; editor.onHostRequest = { emitted = $0 }
        let current = try await editor.commit(SettingsB21Edit.resetHints)
        XCTAssertEqual(adapter.handle(try XCTUnwrap(emitted), current: current, mayChangeLoginItem: true), .unhandled)
        XCTAssertEqual(service.reads, 0); XCTAssertEqual(service.registers, 0)
    }
}
