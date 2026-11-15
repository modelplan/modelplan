// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanSettings

/// Settings → Diagnostics → Export diagnostics…: a host request only, shown in v1 once the app can write the file.
@MainActor final class DiagnosticsExportSettingsTests: XCTestCase {
    private func editor() async throws -> SettingsEditor {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("diagnostics-export-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = try SettingsStore(url: directory.appendingPathComponent("preferences.json"))
        try await store.update { $0.language = .english }
        let editor = SettingsEditor(store: store); await editor.reload(); return editor
    }

    func testV1ShowsTheExportRowOnlyWhenTheHostCanWriteTheFile() throws {
        var context = SettingsPageContext(); context.configureV1NormalEntry()
        let hidden = try SettingsCatalogue.rows(preferences: .init(), context: context, paneID: "diagnostics")
        XCTAssertFalse(hidden.contains { $0.key == .exportDiagnostics }, "no dead control in v1")
        context.capabilities.diagnosticsExportAvailable = true
        let rows = try SettingsCatalogue.rows(preferences: .init(), context: context, paneID: "diagnostics")
        let row = try XCTUnwrap(rows.first { $0.key == .exportDiagnostics })
        XCTAssertEqual(row.availability, .available)
        XCTAssertEqual(row.title, SettingsText("Export diagnostics…", "导出诊断包…"))
        XCTAssertEqual(rows.last?.key, .exportDiagnostics, "it follows Copy diagnostics")
    }

    func testTheButtonSendsOneHostRequestAndChangesNoSetting() async throws {
        let editor = try await editor()
        var requests = [SettingsHostRequest](), commits = 0
        editor.onHostRequest = { requests.append($0) }; editor.onCommit = { _, _ in commits += 1 }
        XCTAssertThrowsError(try editor.request(.exportDiagnostics), "unavailable until the host can write the file")
        var context = editor.context; context.capabilities.diagnosticsExportAvailable = true; editor.update(context: context)
        let revision = editor.snapshot!.revision
        let controller = SettingsWindowController(editor: editor, environmentProvider: { .init() })
        await controller.prepare(); controller.selectPane("diagnostics")
        let button = try XCTUnwrap(controller.actionControl(key: .exportDiagnostics))
        XCTAssertTrue(button.isEnabled)
        XCTAssertTrue(button.sendAction(button.action, to: button.target))
        XCTAssertEqual(requests.map(\.intent), [.exportDiagnostics])
        XCTAssertEqual(editor.snapshot!.revision, revision); XCTAssertEqual(commits, 0)
        controller.close()
    }
}
