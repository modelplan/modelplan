// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanSettings

@MainActor final class MixedMemberControlsTests: XCTestCase {
    func testEmptySubscriptionReadoutReturnsAfterMembersDisappear() async throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("empty-members-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try SettingsStore(url: directory.appendingPathComponent("settings.json"))
        let snapshot = await store.snapshot()
        for key in [SettingKey.visible, .alias, .percentagePin] {
            let view = SettingsNativeRow(key: key)
            var context = SettingsPageContext()
            context.subscriptions = [.init(id: "stable", name: .init("Stable", "稳定"))]
            func apply() throws {
                let row = try XCTUnwrap(SettingsCatalogue.rows(preferences: snapshot.preferences, context: context).first { $0.key == key })
                view.apply(row, language: .english, saving: false, input: nil, reduced: false,
                    onChoice: #selector(NSApplication.terminate(_:)), target: NSApplication.shared,
                    snapshot: snapshot, context: context, holdAvailable: true, hasHost: false,
                    onEdit: { _, _ in }, onSurfaceAction: { _, _ in }, onDraftCleared: { _ in })
            }
            try apply()
            context.subscriptions = []
            try apply()
            let readout = try XCTUnwrap(view.controls.arrangedSubviews.compactMap { $0 as? NSTextField }.first)
            XCTAssertFalse(readout.isHiddenOrHasHiddenAncestor, "The empty state must be visible for \(key)")
            XCTAssertEqual(readout.stringValue, "No subscriptions detected", "The empty state must explain \(key)")
        }
    }
    func testOnlyUnstableMemberControlsCarryTheDisabledReason() async throws {
        _ = NSApplication.shared
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("mixed-members-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let store=try SettingsStore(url:directory.appendingPathComponent("settings.json"))
        let snapshot=await store.snapshot()
        var context=SettingsPageContext()
        context.subscriptions=[.init(id:"stable",name:.init("Stable","稳定")),
                               .init(id:"row#source#1",name:.init("Unverified","未验证"),isUnstable:true)]
        let rows=try SettingsCatalogue.rows(preferences:snapshot.preferences,context:context)
        for key in [SettingKey.visible,.alias,.percentagePin] {
            let value=try XCTUnwrap(rows.first { $0.key == key })
            let view=SettingsNativeRow(key:key)
            view.apply(value,language:.english,saving:false,input:nil,reduced:false,
                       onChoice:#selector(NSApplication.terminate(_:)),target:NSApplication.shared,
                       snapshot:snapshot,context:context,holdAvailable:true,hasHost:false,
                       onEdit:{_,_ in},onSurfaceAction:{_,_ in},onDraftCleared:{_ in})
            if key == .alias {
                XCTAssertTrue(try XCTUnwrap(view.aliases["stable"]).isEnabled)
                XCTAssertFalse(try XCTUnwrap(view.aliases["row#source#1"]).isEnabled)
            } else {
                XCTAssertTrue(try XCTUnwrap(view.choices["stable"]).isEnabled)
                XCTAssertFalse(try XCTUnwrap(view.choices["row#source#1"]).isEnabled)
            }
            let reason = "Unverified account — changes can't be saved yet"
            XCTAssertFalse(view.subtitle.isHiddenOrHasHiddenAncestor)
            XCTAssertTrue(view.subtitle.stringValue.contains(reason), "The actual visible subtitle must explain the disabled member")
            if key == .alias {
                XCTAssertNil(try XCTUnwrap(view.aliases["stable"]).toolTip)
                XCTAssertEqual(try XCTUnwrap(view.aliases["row#source#1"]).toolTip, reason)
            } else {
                XCTAssertNil(try XCTUnwrap(view.choices["stable"]).toolTip)
                XCTAssertEqual(try XCTUnwrap(view.choices["row#source#1"]).toolTip, reason)
            }
        }
    }
    func testOrderKeepsStableRowsInteractiveButRejectsUnstableDrag() throws {
        _ = NSApplication.shared
        let control=SettingsOrderControl(frame:.zero)
        control.configure(ids:["a","row#source#1","b"],names:[:],language:.english,canReset:false,
                          disabledReasons:["row#source#1":"Unverified account — changes can't be saved yet"])
        XCTAssertTrue(control.isEnabled)
        XCTAssertNil(control.tableView(control.table,pasteboardWriterForRow:1))
        XCTAssertNotNil(control.tableView(control.table,pasteboardWriterForRow:2))
        control.table.selectRowIndexes(IndexSet(integer:2),byExtendingSelection:false)
        XCTAssertTrue(control.up.isEnabled,"stable members remain reorderable across an unstable row")
    }
}
