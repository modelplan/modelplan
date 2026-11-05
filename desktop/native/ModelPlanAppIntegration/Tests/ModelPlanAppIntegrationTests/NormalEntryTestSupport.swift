// SPDX-License-Identifier: MIT
import Foundation
import CoreGraphics
import XCTest
import ModelPlanDock
import ModelPlanSettings

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
