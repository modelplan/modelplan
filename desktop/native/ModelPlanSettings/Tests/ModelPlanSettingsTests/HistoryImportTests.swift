// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanSettings

/// HIST-IMP-02 (Settings row), HIST-IMP-03 (first-run line and import after consent).
@MainActor final class HistoryImportTests: XCTestCase {
    private final class Commands: HistoryImportCommands {
        var ready = true
        var calls: [String] = []
        func start(days: Int, firstRun: Bool) async throws { calls.append("start \(days) \(firstRun)") }
        func status() async throws { calls.append("status") }
        func cancel() async throws { calls.append("cancel") }
        func remove() async throws { calls.append("remove") }
    }
    private func status(_ phase: String, done: Int = 0, total: Int = 0, rows: Int = 0, days: Int = 30, coverage: Bool = false) throws -> WireHistoryImportStatus {
        let cov = coverage ? #"[{"source":"claude-code","from":"2026-10-10","through":"2026-11-08","rows":\#(rows)}]"# : "[]"
        let json = #"{"schemaVersion":1,"phase":"\#(phase)","days":\#(days),"filesDone":\#(done),"filesTotal":\#(total),"firstRunDone":false,"importedRows":\#(rows),"coverage":\#(cov),"sources":[]}"#
        return try WireDecoder.decode(WireHistoryImportStatus.self, from: Data(json.utf8))
    }
    private func find(_ id: String, in view: NSView) -> NSView? {
        if view.accessibilityIdentifier() == id { return view }
        for child in view.subviews { if let hit = find(id, in: child) { return hit } }
        return nil
    }
    private func strings(_ view: NSView) -> [String] {
        ((view as? NSTextField).map { [$0.stringValue] } ?? []) + view.subviews.flatMap(strings)
    }
    private func editor() async throws -> SettingsEditor {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("history-import-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = try SettingsStore(url: directory.appendingPathComponent("preferences.json"))
        try await store.update { $0.language = .english }
        let editor = SettingsEditor(store: store); await editor.reload(); return editor
    }

    func testModelStatesFollowTheEngineStatusOnly() throws {
        let commands = Commands(); let model = HistoryImportModel(commands: commands)
        XCTAssertEqual(model.days, 30); XCTAssertTrue(model.canStart); XCTAssertFalse(model.canRemove)
        model.receive(try status("running", done: 1, total: 4))
        XCTAssertTrue(model.isRunning); XCTAssertFalse(model.canStart); XCTAssertEqual(model.fraction, 0.25)
        XCTAssertEqual(HistoryImportText.line(model).english, "Importing 30 days of local history…")
        model.receive(try status("done", rows: 12, coverage: true))
        XCTAssertFalse(model.isRunning); XCTAssertTrue(model.canRemove)
        XCTAssertTrue(HistoryImportText.line(model).english.contains("12 daily rows"))
        commands.ready = false
        XCTAssertFalse(model.canStart); XCTAssertFalse(model.canRemove)
        model.stop()
    }

    func testSettingsRowStartsWithDayCountCancelsAndRemoves() async throws {
        let editor = try await editor(), commands = Commands()
        let entry = ScopeConsentEntry(client: ScopeConsentTestClient(), ready: { true }, language: .english)
        let model = HistoryImportModel(commands: commands); entry.historyImport = model
        let controller = SettingsWindowController(editor: editor, environmentProvider: { .init() }, scopeConsentEntry: entry)
        await controller.prepare(); controller.selectPane("privacy")
        let content = try XCTUnwrap(controller.window?.contentView)
        let row = try XCTUnwrap(find("settings.historyImport", in: content))
        XCTAssertFalse(row.isHidden)
        XCTAssertTrue(strings(row).contains("Import usage history"))
        let days = try XCTUnwrap(find("settings.historyImport.days", in: row) as? NSPopUpButton)
        XCTAssertEqual(days.selectedItem?.tag, 30, "default 30 days")
        days.selectItem(withTag: 90); _ = days.sendAction(days.action, to: days.target)
        let start = try XCTUnwrap(find("settings.historyImport.start", in: row) as? NSButton)
        _ = start.sendAction(start.action, to: start.target)
        try await settle { commands.calls.contains("start 90 false") }
        // the engine reports progress; the row shows the running line, the bar and Cancel
        model.receive(try status("running", done: 1, total: 2, days: 90))
        let cancel = try XCTUnwrap(find("settings.historyImport.cancel", in: row) as? NSButton)
        XCTAssertFalse(cancel.isHidden); XCTAssertFalse(start.isEnabled)
        XCTAssertTrue(strings(row).contains("Importing 90 days of local history…"))
        _ = cancel.sendAction(cancel.action, to: cancel.target)
        try await settle { commands.calls.contains("cancel") }
        model.receive(try status("done", rows: 5, coverage: true))
        let remove = try XCTUnwrap(find("settings.historyImport.remove", in: row) as? NSButton)
        XCTAssertTrue(remove.isEnabled)
        _ = remove.sendAction(remove.action, to: remove.target)
        try await settle { commands.calls.contains("remove") }
        controller.selectPane("general")
        XCTAssertTrue(row.isHidden, "the row belongs to Data & Privacy only")
        controller.close()
    }

    func testFirstRunShowsOnePlainLineAndImportsAfterConsentWithoutADialog() async throws {
        let entry = ScopeConsentEntry(client: ScopeConsentTestClient(), ready: { true }, language: .english)
        entry.acceptedFacts(try ScopeConsentFixtures.facts())
        let view = try entry.makeFirstRunView(language: .english)
        let line = try XCTUnwrap(find("scope.firstRun.import", in: view) as? NSTextField)
        XCTAssertEqual(line.stringValue, HistoryImportText.firstRunLine.english)
        XCTAssertTrue(line.stringValue.contains("up to 30 days"))
        XCTAssertNil(find("settings.historyImport.start", in: view), "no extra dialog or control on the consent page")
        entry.endFirstRunPresentation()
        let commands = Commands(); let model = HistoryImportModel(commands: commands)
        await model.runAfterFirstRunConsent()
        XCTAssertEqual(commands.calls, ["start 30 true"])
        model.receive(try status("running", done: 0, total: 1))
        await model.runAfterFirstRunConsent()
        XCTAssertEqual(commands.calls, ["start 30 true"], "a running import is not started twice")
    }

    private func settle(_ check: @escaping @MainActor () -> Bool) async throws {
        for _ in 0..<200 { if check() { return }; try await Task.sleep(for: .milliseconds(10)) }
        XCTFail("condition never held")
    }
}
