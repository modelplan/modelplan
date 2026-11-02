// SPDX-License-Identifier: MIT
import XCTest
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class ShowQuotaWidgetRequestTests: XCTestCase {
    private struct SyntheticFailure: Error {}
    private func makeEditor(hidden: Bool = true) async throws -> SettingsEditor {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("show-widget-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = try SettingsStore(url: root.appendingPathComponent("settings.json"))
        if hidden { _ = try await store.update { $0.showDock = false } }
        let editor = SettingsEditor(store: store); await editor.reload(); return editor
    }
    func testAdmissionReportsLoadingSavingAndPause() async throws {
        XCTAssertEqual(ShowQuotaWidgetRequest.availability(paused: false, loaded: false, saving: false), .loading)
        XCTAssertEqual(ShowQuotaWidgetRequest.availability(paused: false, loaded: true, saving: true), .saving)
        XCTAssertEqual(ShowQuotaWidgetRequest.availability(paused: true, loaded: true, saving: false), .paused)
        XCTAssertEqual(ShowQuotaWidgetRequest.availability(paused: false, loaded: true, saving: false), .ready)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("show-widget-unloaded-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let editor = SettingsEditor(store: try SettingsStore(url: root.appendingPathComponent("settings.json")))
        let outcome = await ShowQuotaWidgetRequest.perform(editor: editor, expectedRevision: 0)
        XCTAssertEqual(outcome, .unavailable)
    }
    func testHiddenWidgetCommitsOnlyAfterExplicitRequest() async throws {
        let editor = try await makeEditor()
        let revision = try XCTUnwrap(editor.snapshot?.revision)
        let outcome = await ShowQuotaWidgetRequest.perform(editor: editor, expectedRevision: revision)
        XCTAssertEqual(outcome, .ready)
        let saved = await editor.store.snapshot()
        XCTAssertTrue(saved.preferences.showDock)
    }
    func testStaleRequestDoesNotOverwriteLaterUserChoice() async throws {
        let editor = try await makeEditor()
        let revision = try XCTUnwrap(editor.snapshot?.revision)
        _ = try await editor.store.update { $0.dockEdge = .bottom; $0.showDock = false }
        let outcome = await ShowQuotaWidgetRequest.perform(editor: editor, expectedRevision: revision)
        XCTAssertEqual(outcome, .changed)
        let saved = await editor.store.snapshot()
        XCTAssertFalse(saved.preferences.showDock); XCTAssertEqual(saved.preferences.dockEdge, .bottom)
        XCTAssertEqual(editor.snapshot?.revision, saved.revision)
    }
    func testConcurrentWriteDuringCommitIsNotRetriedOrOverwritten() async throws {
        let editor = try await makeEditor()
        let revision = try XCTUnwrap(editor.snapshot?.revision)
        var attempts = 0
        let outcome = await ShowQuotaWidgetRequest.perform(editor: editor, expectedRevision: revision) { editor in
            attempts += 1
            _ = try await editor.store.update { $0.dockEdge = .left; $0.showDock = false }
            return try await editor.commit(SettingsB21Edit.showDock(true))
        }
        XCTAssertEqual(outcome, .changed); XCTAssertEqual(attempts, 1)
        let saved = await editor.store.snapshot()
        XCTAssertFalse(saved.preferences.showDock); XCTAssertEqual(saved.preferences.dockEdge, .left)
    }
    func testSaveFailureIsReportedWithoutPretendingToShow() async throws {
        let editor = try await makeEditor()
        let revision = try XCTUnwrap(editor.snapshot?.revision)
        let outcome = await ShowQuotaWidgetRequest.perform(editor: editor, expectedRevision: revision) { _ in throw SyntheticFailure() }
        XCTAssertEqual(outcome, .failed)
        let saved = await editor.store.snapshot(); XCTAssertFalse(saved.preferences.showDock)
    }
    func testUserHideAfterCommitPreventsReveal() async throws {
        let editor = try await makeEditor()
        let revision = try XCTUnwrap(editor.snapshot?.revision)
        let outcome = await ShowQuotaWidgetRequest.perform(editor: editor, expectedRevision: revision) { editor in
            let receipt = try await editor.commit(SettingsB21Edit.showDock(true))
            _ = try await editor.store.update { $0.showDock = false }
            return receipt
        }
        XCTAssertEqual(outcome, .changed)
        let saved = await editor.store.snapshot(); XCTAssertFalse(saved.preferences.showDock)
    }
}
