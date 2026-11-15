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
        let outcome = await ShowQuotaWidgetRequest.perform(editor: editor)
        XCTAssertEqual(outcome, .unavailable)
    }
    func testHiddenWidgetCommitsOnlyAfterExplicitRequest() async throws {
        let editor = try await makeEditor()
        let outcome = await ShowQuotaWidgetRequest.perform(editor: editor)
        XCTAssertEqual(outcome, .ready)
        let saved = await editor.store.snapshot()
        XCTAssertTrue(saved.preferences.showDock)
    }
    /// G3-17/G3-18: the Help host saves its hint ledger through the same store while the
    /// widget is hidden. An unrelated write that the editor has not reloaded yet must not
    /// turn an explicit Show into "Settings changed"; it is kept and Show is saved on top.
    func testUnrelatedWriteBeforeShowIsKeptAndShowStillWins() async throws {
        let editor = try await makeEditor()
        _ = try await editor.store.update { $0.dockEdge = .bottom }
        let moved = await editor.store.snapshot()
        XCTAssertNotEqual(editor.snapshot?.revision, moved.revision, "Precondition: the editor has not reloaded the write")
        let outcome = await ShowQuotaWidgetRequest.perform(editor: editor)
        XCTAssertEqual(outcome, .ready)
        let saved = await editor.store.snapshot()
        XCTAssertTrue(saved.preferences.showDock); XCTAssertEqual(saved.preferences.dockEdge, .bottom)
        XCTAssertEqual(editor.snapshot?.revision, saved.revision)
    }
    func testConcurrentWriteDuringCommitIsReadAgainNotOverwritten() async throws {
        let editor = try await makeEditor()
        var attempts = 0
        let outcome = await ShowQuotaWidgetRequest.perform(editor: editor) { editor in
            attempts += 1
            if attempts == 1 { _ = try await editor.store.update { $0.dockEdge = .left } }
            return try await editor.commit(SettingsB21Edit.showDock(true))
        }
        XCTAssertEqual(outcome, .ready); XCTAssertEqual(attempts, 2)
        let saved = await editor.store.snapshot()
        XCTAssertTrue(saved.preferences.showDock); XCTAssertEqual(saved.preferences.dockEdge, .left)
    }
    func testRetriesAreBounded() async throws {
        let editor = try await makeEditor()
        var attempts = 0
        let outcome = await ShowQuotaWidgetRequest.perform(editor: editor) { editor in
            attempts += 1
            _ = try await editor.store.update { $0.dockEdge = attempts.isMultiple(of: 2) ? .left : .bottom }
            return try await editor.commit(SettingsB21Edit.showDock(true))
        }
        XCTAssertEqual(outcome, .changed); XCTAssertEqual(attempts, ShowQuotaWidgetRequest.attemptLimit)
        let saved = await editor.store.snapshot(); XCTAssertFalse(saved.preferences.showDock)
        XCTAssertEqual(editor.snapshot?.revision, saved.revision)
    }
    func testHideUsesTheSameRereadPath() async throws {
        let editor = try await makeEditor(hidden: false)
        _ = try await editor.store.update { $0.helpHints = .init(seen: [.findWidget]) }
        let outcome = await ShowQuotaWidgetRequest.setVisible(false, editor: editor)
        XCTAssertEqual(outcome, .ready)
        let saved = await editor.store.snapshot()
        XCTAssertFalse(saved.preferences.showDock); XCTAssertEqual(saved.preferences.helpHints, .init(seen: [.findWidget]))
    }
    func testSaveFailureIsReportedWithoutPretendingToShow() async throws {
        let editor = try await makeEditor()
        let outcome = await ShowQuotaWidgetRequest.perform(editor: editor) { _ in throw SyntheticFailure() }
        XCTAssertEqual(outcome, .failed)
        let saved = await editor.store.snapshot(); XCTAssertFalse(saved.preferences.showDock)
    }
    func testUserHideAfterCommitPreventsReveal() async throws {
        let editor = try await makeEditor()
        let outcome = await ShowQuotaWidgetRequest.perform(editor: editor) { editor in
            let receipt = try await editor.commit(SettingsB21Edit.showDock(true))
            _ = try await editor.store.update { $0.showDock = false }
            return receipt
        }
        XCTAssertEqual(outcome, .changed)
        let saved = await editor.store.snapshot(); XCTAssertFalse(saved.preferences.showDock)
    }
}
