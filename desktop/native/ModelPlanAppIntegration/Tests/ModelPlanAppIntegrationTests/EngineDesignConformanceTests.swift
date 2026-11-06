// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanDock
import ModelPlanSettings
import ModelPlanEngineClient
@testable import ModelPlanAppIntegration

@MainActor final class EngineDesignConformanceTests: XCTestCase {
    private func app(_ store:SettingsStore, cockpitEntryEnabled: Bool = false) -> EngineDockMenuApplication {
        EngineRowsEntry.make(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/modelplan"),applicationVersion:"synthetic",allowedEnvironment:[:],offline:true,readOnly:true),settingsStore:store,createsNativePanels:false,cockpitEntryEnabled:cockpitEntryEnabled)
    }
    func testDragCommitSurvivesContentRebuildAndRestart() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        let url=root.appendingPathComponent("settings.json"),store=try SettingsStore(url:url),entry=app(store)
        await entry.prepare()
        let dock=entry.composition.dock
        XCTAssertNotNil(dock.displayChoicesChanged);XCTAssertNotNil(dock.catalogueChanged);XCTAssertNotNil(dock.onPlacementObserved)
        let commit=try XCTUnwrap(dock.commitDisplayPlacement)
        commit("drag-display",.left,0.31)
        for _ in 0..<100 {
            if await store.snapshot().preferences.dockDisplayID == "drag-display" { break }
            try await Task.sleep(for:.milliseconds(10))
        }
        dock.refreshDockContent()
        let persisted=await store.snapshot()
        XCTAssertEqual(persisted.preferences.dockDisplayID,"drag-display")
        XCTAssertEqual(persisted.preferences.dockEdge,.left)
        XCTAssertEqual(persisted.preferences.dockAlongFraction,0.31)
        XCTAssertEqual(dock.currentMenuBarPreferences?.dockAlongFraction,0.31)
        let restarted=app(try SettingsStore(url:url));await restarted.prepare()
        restarted.composition.dock.refreshDockContent()
        XCTAssertEqual(restarted.composition.dock.currentMenuBarPreferences?.dockDisplayID,"drag-display")
        XCTAssertEqual(restarted.composition.dock.currentMenuBarPreferences?.dockEdge,.left)
        XCTAssertEqual(restarted.composition.dock.currentMenuBarPreferences?.dockAlongFraction,0.31)
        // G3-28: the widget menu's Auto-Collapse writes the same stored setting as Settings.
        let autoCollapse=try XCTUnwrap(dock.requestAutoCollapse)
        autoCollapse(false)
        for _ in 0..<100 {
            if await store.snapshot().preferences.autoHide == false { break }
            try await Task.sleep(for:.milliseconds(10))
        }
        let collapsed=await store.snapshot()
        XCTAssertFalse(collapsed.preferences.autoHide)
        XCTAssertTrue(collapsed.preferences.showDock, "Auto-Collapse never turns the widget off")
        dock.close();restarted.composition.dock.close()
    }
    func testMenusFollowSettingsLanguageAndSpecOrder() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        let store=try SettingsStore(url:root.appendingPathComponent("settings.json"))
        for enabled in [false,true] {
            let entry=app(store,cockpitEntryEnabled:enabled)
            for language in [SettingsLanguage.chinese,.english] {
                try await store.update { $0.language=language };await entry.prepare();entry.allowDockPresentation()
                let en=language == .english
                // Owner HIG decision 11-06: [Auto-Collapse ✓, Settings…] — [Quit ModelPlan]; no Hide item, no shortcuts (D37).
                let dock=entry.composition.dock.menu().items
                let dockTitles=dock.map { $0.isSeparatorItem ? "—" : $0.title }
                let group=[en ? "Auto-Collapse" : "自动收起",en ? "Settings…" : "设置…","—",en ? "Quit ModelPlan" : "退出 ModelPlan"]
                XCTAssertEqual(dockTitles,enabled ? [en ? "Open Cockpit" : "打开驾驶舱","—"]+group : group)
                XCTAssertFalse(dockTitles.contains { $0.contains("Hide") || $0.contains("隐藏") || $0.contains("Close") || $0.contains("关闭") })
                let toggle=try XCTUnwrap(dock.first { $0.title == (en ? "Auto-Collapse" : "自动收起") })
                let storedAutoHide=await store.snapshot().preferences.autoHide
                XCTAssertEqual(toggle.state,storedAutoHide ? .on : .off)
                let settings=try XCTUnwrap(dock.first { $0.title == (en ? "Settings…" : "设置…") })
                // D37 (11-06): the widget's contextual menu shows no shortcut hints.
                XCTAssertEqual(settings.keyEquivalent,"")
                let quit=try XCTUnwrap(dock.last)
                XCTAssertEqual(quit.keyEquivalent,"")
                XCTAssertTrue(dock.allSatisfy { $0.keyEquivalent.isEmpty }, "no item in the widget menu carries a shortcut")
                let titles=try XCTUnwrap(entry.liveStatusMenu).items.filter { !$0.isSeparatorItem }.map(\.title)
                XCTAssertEqual(Array(titles.suffix(7)),en ? ["Website","Methodology","Privacy","Help…","Settings…","About ModelPlan","Quit ModelPlan"]:["网站","方法论","隐私","说明…","设置…","关于 ModelPlan","退出 ModelPlan"])
                XCTAssertFalse(titles.contains { $0.contains(" / ") })
            }
            entry.composition.dock.close()
        }
    }
    /// G3-28: the widget menu's checkable Auto-Collapse, Settings' "鼠标离开后自动收起" switch
    /// and the stored setting stay in sync in both directions; the title never changes.
    func testWidgetMenuAutoCollapseAndSettingsSwitchStayInSync() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        let store=try SettingsStore(url:root.appendingPathComponent("settings.json"))
        try await store.update { $0.language = .chinese; $0.autoHide = false }
        let entry=app(store);await entry.prepare();entry.allowDockPresentation()
        defer { entry.composition.dock.close() }
        let editor=entry.settingsHost.application.editor
        func row() throws -> SettingsRow {
            let snapshot=try XCTUnwrap(editor.snapshot)
            return try XCTUnwrap(SettingsCatalogue.rows(preferences:snapshot.preferences,context:editor.context,paneID:nil).first { $0.key == .autoHide })
        }
        XCTAssertEqual(try row().title.chinese,"鼠标离开后自动收起")
        for expected in [true,false] {
            let item=try XCTUnwrap(entry.composition.dock.menu().items.first { $0.title == "自动收起" })
            XCTAssertEqual(item.state,expected ? .off : .on);XCTAssertTrue(item.isEnabled)
            _ = try XCTUnwrap(item.target as? NSObject).perform(try XCTUnwrap(item.action),with:item)
            try await waitForSettings(editor) { editor.snapshot?.preferences.autoHide == expected && !editor.isSaving }
            XCTAssertEqual(try row().value,.toggle(expected),"the Settings switch follows the widget menu")
            let saved=await store.snapshot()
            XCTAssertEqual(saved.preferences.autoHide,expected);XCTAssertTrue(saved.preferences.showDock)
        }
        _ = try await editor.commit(SettingsB21Edit.autoHide(true))
        let item=try XCTUnwrap(entry.composition.dock.menu().items.first { $0.title == "自动收起" })
        XCTAssertEqual(item.state,.on,"the widget menu follows the Settings switch")
    }
    func testUnreadableFaceShowsReasonAndClearsItWithRows() throws {
        let view=DockInstrumentView(frame:.zero),now=Date()
        var input=DockInstrumentInput(id:"one",name:"One",windows:[])
        input.unavailableReason="Reader consent needed"
        let unreadable=try DockInstrumentProjection.evaluate(input,now:now)
        try view.applyCommunity([unreadable])
        XCTAssertTrue(view.communityRowIsDimmed("one"))
        XCTAssertTrue(try XCTUnwrap(view.communityRowText("one")).contains("Reader consent needed"))
        input.dataState = .fresh
        input.windows=[.init(id:"window",period:.day,label:"Day",remainingPercent:70,resetsAt:nil,durationSeconds:nil)]
        try view.applyCommunity([DockInstrumentProjection.evaluate(input,now:now)])
        XCTAssertFalse(view.communityRowIsDimmed("one"))
        XCTAssertFalse(try XCTUnwrap(view.communityRowText("one")).contains("Reader consent needed"))
        try view.applyCommunity([])
        XCTAssertNil(view.communityRowText("one"))
    }
}
