// SPDX-License-Identifier: MIT
import Foundation
import CoreGraphics
import AppKit
import XCTest
import ModelPlanDock
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor func normalEntryTestEnvironment() -> DockEdgeEnvironment {
    .init(displays:[.init(id:"synthetic-display",frame:.init(x:0,y:0,width:1440,height:900),visibleFrame:.init(x:0,y:80,width:1440,height:820))],
          layouts:[],primaryDisplayID:"synthetic-display",pointer:CGPoint(x:700,y:400))
}

@MainActor private final class SettingsConditionWait {
    let editor: SettingsEditor, condition: @MainActor () -> Bool
    var token: UUID?, timeout: Task<Void,Never>?, continuation: CheckedContinuation<Bool,Never>?
    init(_ editor:SettingsEditor,condition:@escaping @MainActor () -> Bool) { self.editor=editor;self.condition=condition }
    func wait() async -> Bool {
        if condition() { return true }
        return await withCheckedContinuation { continuation in
            self.continuation=continuation
            token=editor.observeChanges { [weak self] in guard let self else{return};if self.condition(){self.finish(true)} }
            timeout=Task { @MainActor [weak self] in
                do { try await Task.sleep(for:.seconds(5)) } catch { return }
                self?.finish(false)
            }
            if condition(){finish(true)}
        }
    }
    func finish(_ result:Bool) {
        if let token { editor.removeChangeObserver(token);self.token=nil }
        timeout?.cancel();timeout=nil
        let saved=continuation;continuation=nil;saved?.resume(returning:result)
    }
}
@MainActor func waitForSettings(_ editor:SettingsEditor,file:StaticString=#filePath,line:UInt=#line,
                                condition:@escaping @MainActor () -> Bool) async throws {
    let completed=await SettingsConditionWait(editor,condition:condition).wait()
    if !completed { XCTFail("Settings event did not deliver the required committed state",file:file,line:line);throw CancellationError() }
}

/// The status menu's checkable Show Quota Widget item (owner decision 11-06, G3-18): waits until
/// the item is actionable with its checkmark showing `checked`, chooses it, then waits until the
/// stored switch and the checkmark both show the opposite. Titles never change while toggling.
@MainActor func chooseShowQuotaWidget(_ app: EngineDockMenuApplication, checked: Bool, title: String = "Show Quota Widget",
                                      file: StaticString = #filePath, line: UInt = #line) async throws {
    func item() -> NSMenuItem? { app.liveStatusMenu?.items.first { $0.title == title } }
    func ready(_ state: Bool) -> Bool {
        guard let item = item() else { return false }
        return item.isEnabled && item.state == (state ? .on : .off)
    }
    let start = ContinuousClock.now
    while !ready(checked) && ContinuousClock.now - start < .seconds(5) { try await Task.sleep(for: .milliseconds(20)) }
    let current = try XCTUnwrap(item(), "Missing status item \(title)", file: file, line: line)
    XCTAssertTrue(ready(checked), "\(title) must be actionable and show checked=\(checked)", file: file, line: line)
    _ = try XCTUnwrap(current.target as? NSObject, file: file, line: line).perform(try XCTUnwrap(current.action, file: file, line: line), with: current)
    let editor = app.settingsHost.application.editor
    try await waitForSettings(editor, file: file, line: line) { editor.snapshot?.preferences.showDock == !checked && !editor.isSaving }
    let settled = ContinuousClock.now
    while !ready(!checked) && ContinuousClock.now - settled < .seconds(5) { try await Task.sleep(for: .milliseconds(20)) }
    XCTAssertTrue(ready(!checked), "the checkmark follows the saved switch", file: file, line: line)
}

@MainActor final class SettingsWaitEventTests: XCTestCase {
    func testWaitResumesOnDeliveredSettingsChange() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("settings-wait-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        let store=try SettingsStore(url:root.appendingPathComponent("settings.json")), editor:SettingsEditor
        editor=SettingsEditor(store:store);await editor.reload()
        let writer=Task { @MainActor in _ = try await store.update{$0.showDock=false};await editor.reload() }
        try await waitForSettings(editor){editor.snapshot?.preferences.showDock == false}
        try await writer.value
        XCTAssertEqual(editor.snapshot?.preferences.showDock,false)
        _ = try await store.update{$0.showDock=true};await editor.reload()
        XCTAssertEqual(editor.snapshot?.preferences.showDock,true,"The completed waiter must not retain a continuation")
    }
    func testAlreadySatisfiedSettingsDoesNotNeedAnotherEvent() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("settings-wait-ready-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        let editor=SettingsEditor(store:try SettingsStore(url:root.appendingPathComponent("settings.json")))
        await editor.reload();let revision=editor.snapshot?.revision
        try await waitForSettings(editor){editor.snapshot != nil && !editor.isSaving}
        XCTAssertEqual(editor.snapshot?.revision,revision)
    }
}

/// D56 (owner 2026-11-08) made a fresh profile start with the Quota Widget collapsed. Journeys
/// written for an expanded widget open a new profile with Auto-Collapse saved off; a profile that
/// already exists keeps whatever it saved. Fresh defaults are covered by FindQuotaWidgetJourneyTests
/// and SET909DockDefaultsJourneyTests, which use EngineRowsEntry.makeSettingsStore directly.
@MainActor func expandedWidgetSettingsStore(applicationSupport root: URL, rowIDMap: [String: String] = [:],
                                            preferredLanguages: [String] = Locale.preferredLanguages) async throws -> SettingsStore {
    let newProfile = !FileManager.default.fileExists(atPath: root.path)
    let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, rowIDMap: rowIDMap, preferredLanguages: preferredLanguages)
    if newProfile { _ = try await store.update { $0.autoHide = false } }
    return store
}
