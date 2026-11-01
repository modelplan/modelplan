// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor private final class RemainingConsoleProbe: EngineRowsConsoleSurface {
    var opens = 0
    func show() { opens += 1 }
    func render() {}
    func hide() {}
}

/// Local acceptance regressions while #403 waits for coordinator integration.
/// These use real normal-entry view composition with synthetic files/rows, never
/// order a window, and do not substitute a visible hit target or page readiness.
@MainActor final class CockpitRemainingAcceptanceTests: XCTestCase {
    private func root() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("s6-remaining-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }
    private func populatedRows() throws -> WireRowsSnapshot {
        let file = URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var value = try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:file)) as? [String:Any])
        var projection = try XCTUnwrap(value["projection"] as? [String:Any])
        var rows = try XCTUnwrap(projection["rows"] as? [[String:Any]])
        rows[0]["surfaces"] = ["dock","menu"]; rows[0]["expiresAt"] = "2027-01-01T00:00:00Z"
        projection["rows"] = rows; value["projection"] = projection
        return try WireDecoder.decode(WireRowsSnapshot.self,from:JSONSerialization.data(withJSONObject:value))
    }
    func testNormalPopulatedA5MustBeVisibleAndHitTestBeforeHeldPress() async throws {
        let profile = try root(), console = RemainingConsoleProbe()
        let app = EngineRowsEntry.make(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-executed"),applicationVersion:"synthetic",allowedEnvironment:[:],offline:true,readOnly:true),
            settingsStore:try SettingsStore(url:profile.appendingPathComponent("settings.json")),createsNativePanels:false,
            makeConsole:{ _ in console },activateSettings:{})
        defer { app.composition.dock.close() }
        await app.prepare()
        let context = EngineDeliveryContext(sessionID:"s-00000000-0000-0000-0000-000000000002",floor:.init(storeEpoch:"synthetic-a5",generation:1),revision:1)
        await app.composition.store.consume(.connection(.ready(context)))
        await app.composition.store.consume(.rowsChanged(.init(envelope:try .init(sessionId:context.sessionID,storeEpoch:context.floor.storeEpoch,consentGeneration:1,data:populatedRows()),delivery:context),invalidRowCount:0))
        app.composition.dock.setPresentationAllowed(true)
        XCTAssertFalse(app.composition.provider.dockContent.dockRows.isEmpty,"Use populated normal rows, not an empty-state exception")
        let button = app.composition.dock.consoleButton
        XCTAssertFalse(button.isHiddenOrHasHiddenAncestor,"CKP-ENTRY-01/02 require a reachable visible A5 target")
        guard !button.isHiddenOrHasHiddenAncestor else { return }
        XCTAssertFalse(button.frame.isEmpty)
        let host = try XCTUnwrap(button.superview)
        let centre = button.convert(CGPoint(x:button.bounds.midX,y:button.bounds.midY),to:host)
        let target = try XCTUnwrap(host.hitTest(centre),"A5 centre must resolve through the actual hierarchy")
        XCTAssertTrue(target === button)
        guard target === button else { return }
        let press = try XCTUnwrap(NSEvent.mouseEvent(with:.leftMouseDown,location:centre,modifierFlags:[],timestamp:0,windowNumber:0,context:nil,eventNumber:1,clickCount:1,pressure:1))
        target.mouseDown(with:press) // No release: a held A5 must already quick-open.
        XCTAssertEqual(console.opens,1)
        XCTAssertNil(app.composition.dock.nativePanel,"No GUI window or device input is part of this test")
    }
    func testNormalAppearanceAndSearchHideThemeButKeepAccessibilityAndLegacyValue() async throws {
        let profile = try root(), url = profile.appendingPathComponent("settings.json")
        let store = try SettingsStore(url:url)
        let saved = try await store.update { $0.language = .english; $0.theme = .day }
        let app = EngineRowsEntry.make(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-executed"),applicationVersion:"synthetic",allowedEnvironment:[:],offline:true,readOnly:true),settingsStore:store,createsNativePanels:false,activateSettings:{})
        defer { app.composition.dock.close() }
        await app.prepare()
        let controller = SettingsWindowController(editor:app.settingsHost.application.editor,environmentProvider:{ .init() })
        defer { controller.close() }
        await controller.prepare(); controller.selectPane("appearance")
        XCTAssertFalse(controller.window?.isVisible ?? true,"The normal Settings controller stays offscreen")
        XCTAssertFalse(controller.visibleSettingKeys.contains(.theme),"CKP-MOT-04: Theme is absent in the v1 Appearance pane")
        XCTAssertTrue(controller.visibleSettingKeys.contains(.motion))
        XCTAssertTrue(controller.visibleSettingKeys.contains(.transparency))
        controller.searchField.stringValue = "Theme"
        controller.controlTextDidChange(Notification(name:NSControl.textDidChangeNotification,object:controller.searchField))
        XCTAssertFalse(controller.visibleSettingKeys.contains(.theme),"Searching must not expose the hidden v1 Theme row")
        for (query,key) in [("Reduce motion",SettingKey.motion),("transparency",.transparency)] {
            controller.searchField.stringValue = query
            controller.controlTextDidChange(Notification(name:NSControl.textDidChangeNotification,object:controller.searchField))
            XCTAssertTrue(controller.visibleSettingKeys.contains(key))
        }
        let after = await store.snapshot(), restored = try SettingsStore(url:url)
        let reloaded = await restored.snapshot()
        XCTAssertEqual(after.revision,saved.revision)
        XCTAssertEqual(after.preferences.theme,.day)
        XCTAssertEqual(reloaded.preferences.theme,.day,"Hiding Theme must not migrate or overwrite a saved legacy value")
    }
}
