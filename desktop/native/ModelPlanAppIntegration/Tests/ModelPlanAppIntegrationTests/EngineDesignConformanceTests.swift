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
        try XCTUnwrap(dock.requestHideDock)()
        for _ in 0..<100 {
            if await store.snapshot().preferences.showDock == false { break }
            try await Task.sleep(for:.milliseconds(10))
        }
        let hidden=await store.snapshot()
        XCTAssertFalse(hidden.preferences.showDock)
        dock.close();restarted.composition.dock.close()
    }
    func testMenusFollowSettingsLanguageAndSpecOrder() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        let store=try SettingsStore(url:root.appendingPathComponent("settings.json"))
        for enabled in [false,true] {
            let entry=app(store,cockpitEntryEnabled:enabled)
            for language in [SettingsLanguage.chinese,.english] {
                try await store.update { $0.language=language };await entry.prepare()
                let en=language == .english
                let cockpit = enabled ? (en ? "Open Cockpit" : "打开驾驶舱") : (en ? "Coming soon" : "即将推出")
                let dock=entry.composition.dock.menu().items
                XCTAssertEqual(Array(dock.suffix(4)).map(\.title),[cockpit,en ? "Settings" : "设置",en ? "Close" : "关闭",en ? "Hide Quota Widget" : "隐藏额度挂件"])
                XCTAssertEqual(dock.first { $0.title == cockpit }?.isEnabled, enabled)
                let titles=try XCTUnwrap(entry.liveStatusMenu).items.filter { !$0.isSeparatorItem }.map(\.title)
                XCTAssertEqual(Array(titles.suffix(7)),en ? ["Website","Methodology","Privacy","Help…","Settings…","About","Quit"]:["网站","方法论","隐私","说明…","设置…","关于","退出"])
                XCTAssertFalse(titles.contains { $0.contains(" / ") })
            }
            entry.composition.dock.close()
        }
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
