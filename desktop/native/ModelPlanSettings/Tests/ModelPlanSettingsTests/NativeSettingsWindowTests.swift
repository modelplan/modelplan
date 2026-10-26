// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanSettings

/// Offscreen AppKit tests only. No activation, orderFront, system permission or desktop visibility assertion.
@MainActor final class NativeSettingsWindowTests: XCTestCase {
    private func store() throws -> SettingsStore {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("settings-window-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return try SettingsStore(url: directory.appendingPathComponent("preferences.json"))
    }
    private func search(_ text: String, in controller: SettingsWindowController) {
        controller.searchField.stringValue = text
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: controller.searchField))
    }
    private func assertRetiredCannotCommit(_ popup: SettingsChoiceControl, target: AnyObject?, action: Selector,
                                          editor: SettingsEditor) async throws {
        let before = await editor.store.snapshot()
        let noCommit = expectation(description: "retired control emits no commit receipt")
        noCommit.isInverted = true
        editor.onCommit = { _, _ in noCommit.fulfill() }
        popup.selectItem(at: popup.numberOfItems - 1)
        _ = popup.sendAction(action, to: target)
        // Simulate an already-captured target/action, bypassing the control's current callback fields.
        _ = NSApplication.shared.sendAction(action, to: target, from: popup)
        await fulfillment(of: [noCommit], timeout: 0.1)
        let after = await editor.store.snapshot()
        XCTAssertEqual(after.revision, before.revision, "retired sender persisted a change")
        XCTAssertNil(popup.target); XCTAssertNil(popup.action); XCTAssertNil(popup.onInteraction)
        guard !popup.isEnabled else { XCTFail("retired control is still enabled"); return }
        XCTAssertFalse(popup.accessibilityPerformPress())
    }
    func testRetiredPaneAndSearchPopupsCannotCommitWhileCurrentPopupStillWorks() async throws {
        let editor = SettingsEditor(store: try store())
        let controller = SettingsWindowController(editor: editor, environmentProvider: { .init() })
        await controller.prepare(); controller.selectPane("appearance")
        let panePopup = try XCTUnwrap(controller.choice(key: .theme))
        let target = panePopup.target, action = try XCTUnwrap(panePopup.action)
        controller.selectPane("dock")
        try await assertRetiredCannotCommit(panePopup, target: target, action: action, editor: editor)

        controller.selectPane("appearance")
        let searchPopup = try XCTUnwrap(controller.choice(key: .theme))
        XCTAssertFalse(searchPopup === panePopup)
        search("no-such-setting-123", in: controller)
        try await assertRetiredCannotCommit(searchPopup, target: target, action: action, editor: editor)

        search("", in: controller)
        let current = try XCTUnwrap(controller.choice(key: .theme))
        XCTAssertFalse(current === searchPopup)
        XCTAssertTrue(try XCTUnwrap(controller.window).makeFirstResponder(current))
        search("Theme", in: controller)
        controller.refreshEnvironment()
        XCTAssertTrue(controller.choice(key: .theme) === current)
        XCTAssertTrue(controller.window?.firstResponder === current)
        let committed = expectation(description: "current control still commits")
        editor.onCommit = { _, _ in committed.fulfill() }
        current.selectItem(at: 2)
        XCTAssertTrue(current.sendAction(current.action, to: current.target))
        await fulfillment(of: [committed], timeout: 3)
        XCTAssertEqual(editor.snapshot?.preferences.theme, .night)
        controller.close()
    }
    func testReplacedSubscriptionPopupCannotCommitForStillPresentID() async throws {
        var context = SettingsPageContext()
        context.subscriptions = [.init(id: "sample", name: .init("Sample", "示例"))]
        let editor = SettingsEditor(store: try store(), context: context)
        let controller = SettingsWindowController(editor: editor, environmentProvider: { .init() })
        await controller.prepare(); controller.selectPane("dock")
        let old = try XCTUnwrap(controller.choice(key: .percentagePin, subscriptionID: "sample"))
        let target = old.target, action = try XCTUnwrap(old.action)
        context.subscriptions.append(.init(id: "second", name: .init("Second", "第二个")))
        editor.update(context: context)
        let current = try XCTUnwrap(controller.choice(key: .percentagePin, subscriptionID: "sample"))
        XCTAssertFalse(current === old)
        try await assertRetiredCannotCommit(old, target: target, action: action, editor: editor)
        let committed = expectation(description: "replacement control commits")
        editor.onCommit = { _, _ in committed.fulfill() }
        current.selectItem(at: 2)
        XCTAssertTrue(current.sendAction(current.action, to: current.target))
        await fulfillment(of: [committed], timeout: 3)
        XCTAssertEqual(editor.snapshot?.preferences.subscriptionSettings["sample"]?.percentagePin, .week)
        controller.close()
    }
    func testNativePopupPersistsAndUpdatesTheSameControlAndWindowAppearance() async throws {
        let store = try store(), editor = SettingsEditor(store: store)
        let controller = SettingsWindowController(editor: editor, environmentProvider: { .init() })
        await controller.prepare(); controller.selectPane("appearance")
        let popup = try XCTUnwrap(controller.choice(key: .theme))
        let committed = expectation(description: "persisted native popup action")
        editor.onCommit = { _, effective in XCTAssertTrue(effective.darkAppearance); committed.fulfill() }
        popup.selectItem(at: 2)
        XCTAssertTrue(popup.sendAction(popup.action, to: popup.target))
        await fulfillment(of: [committed], timeout: 3)
        XCTAssertEqual(editor.snapshot?.preferences.theme, .night)
        XCTAssertEqual(controller.window?.appearance?.name, .darkAqua)
        XCTAssertTrue(controller.choice(key: .theme) === popup)
        XCTAssertNil(controller.errorMessage)
        controller.close()
    }
    func testBilingualGlobalSearchAndOnlyReleasedControlsAreEditable() async throws {
        let editor = SettingsEditor(store: try store())
        let controller = SettingsWindowController(editor: editor, environmentProvider: { .init() })
        await controller.prepare()
        search("Numbers", in: controller)
        XCTAssertTrue(controller.visibleSettingKeys.contains(.percentagePin))
        XCTAssertTrue(controller.visibleSettingKeys.contains(.percentageMode))
        search("减少", in: controller)
        XCTAssertTrue(controller.visibleSettingKeys.contains(.motion))
        XCTAssertTrue(controller.visibleSettingKeys.contains(.transparency))
        search("no-such-setting-123", in: controller)
        XCTAssertTrue(controller.visibleSettingKeys.isEmpty)
        search("", in: controller); controller.selectPane("dock")
        XCTAssertTrue(try XCTUnwrap(controller.choice(key: .size)).isEnabled)
        XCTAssertTrue(try XCTUnwrap(controller.choice(key: .autoHide)).isEnabled)
        XCTAssertTrue(try XCTUnwrap(controller.choice(key: .dockEdge)).isEnabled)
        controller.selectPane("notifications")
        XCTAssertFalse(try XCTUnwrap(controller.choice(key: .notificationConsent)).isEnabled)
        controller.selectPane("dock")
        for key: SettingKey in [.dockEdge, .showPercentages, .autoHide, .size, .percentagePin] {
            XCTAssertNotNil(controller.diagram(key: key))
        }
        controller.close()
    }
    func testAccessibilityTransactionKeepsNativeFocusAndStopsFiniteIllustration() async throws {
        var environment = SettingsEnvironment()
        let store = try store()
        try await store.update { $0.theme = .day }
        let editor = SettingsEditor(store: store)
        let controller = SettingsWindowController(editor: editor, environmentProvider: { environment })
        await controller.prepare(); controller.selectPane("dock")
        let popup = try XCTUnwrap(controller.choice(key: .size)), window = try XCTUnwrap(controller.window)
        XCTAssertTrue(window.makeFirstResponder(popup))
        let diagram = try XCTUnwrap(controller.diagram(key: .size))
        diagram.play()
        let animation = try XCTUnwrap(diagram.layer?.animation(forKey: "settings.lineMovement"))
        XCTAssertEqual(animation.duration, 0.4); XCTAssertEqual(animation.repeatCount, 0)
        environment.reduceMotion = true; environment.reduceTransparency = true; environment.darkAppearance = true
        environment.increaseContrast = true
        controller.refreshEnvironment()
        XCTAssertTrue(window.firstResponder === popup)
        XCTAssertTrue(controller.choice(key: .size) === popup)
        XCTAssertEqual(window.appearance?.name, .aqua)
        XCTAssertTrue(try XCTUnwrap(editor.effective).increaseContrast)
        XCTAssertNil(diagram.layer?.animation(forKey: "settings.lineMovement"))
        environment.reduceMotion = false; controller.refreshEnvironment()
        XCTAssertNil(diagram.layer?.animation(forKey: "settings.lineMovement"))
        XCTAssertEqual(editor.snapshot?.preferences.motion, .system)
        controller.close()
    }
    func testZeroOneSixSubscriptionsAcrossLocalesAndThemesKeepPinsAndControlsWithinWindow() async throws {
        let store = try store()
        for language in [SettingsLanguage.chinese, .english] {
            for theme in [SettingsTheme.day, .night] {
                for count in [0, 1, 6] {
                    try await store.update { p in p.language = language; p.theme = theme }
                    var context = SettingsPageContext()
                    context.subscriptions = (0..<count).map { .init(id: "sample-\($0)", name: .init("Sample \($0)", "示例 \($0)"), plan: "Plan") }
                    let editor = SettingsEditor(store: store, context: context)
                    let controller = SettingsWindowController(editor: editor, environmentProvider: { .init() })
                    await controller.prepare(); search("Numbers", in: controller)
                    let root = try XCTUnwrap(controller.window?.contentView)
                    root.layoutSubtreeIfNeeded()
                    let basis = try XCTUnwrap(controller.choice(key: .percentageMode))
                    let threshold = try XCTUnwrap(controller.choice(key: .redBelow))
                    XCTAssertEqual(basis.convert(basis.bounds, to: root).maxX,
                                   threshold.convert(threshold.bounds, to: root).maxX, accuracy: 1)
                    for index in 0..<count {
                        let popup = try XCTUnwrap(controller.choice(key: .percentagePin, subscriptionID: "sample-\(index)"))
                        XCTAssertTrue(popup.isEnabled)
                        XCTAssertEqual(popup.numberOfItems, 3)
                        let rect = popup.convert(popup.bounds, to: root)
                        XCTAssertGreaterThanOrEqual(rect.minX, 236)
                        XCTAssertLessThanOrEqual(rect.maxX, root.bounds.width)
                        XCTAssertGreaterThan(popup.bounds.height, 0)
                    }
                    if count == 6, let directory = ProcessInfo.processInfo.environment["MODELPLAN_SETTINGS_EVIDENCE"] {
                        // Optional neutral view render, explicitly not a WindowServer/desktop screenshot.
                        let bitmap = try XCTUnwrap(root.bitmapImageRepForCachingDisplay(in: root.bounds))
                        root.cacheDisplay(in: root.bounds, to: bitmap)
                        let data = try XCTUnwrap(bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.75]))
                        let url = URL(fileURLWithPath: directory).appendingPathComponent("offscreen-\(language.rawValue)-\(theme.rawValue).jpg")
                        try data.write(to: url)
                    }
                    controller.close()
                }
            }
        }
    }
}
