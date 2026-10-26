// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanSettings

/// Native delegate/action paths with synthetic context; no window ordering or service execution.
@MainActor final class BehaviorWindowTests: XCTestCase {
    private func makeEditor() async throws -> SettingsEditor {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("settings-behavior-window-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = try SettingsStore(url: directory.appendingPathComponent("preferences.json"))
        try await store.update { $0.language = .english }
        var context = SettingsPageContext()
        context.subscriptions = ["a","b","c"].map { .init(id: $0, name: .init("Plan " + $0, "套餐 " + $0)) }
        let editor = SettingsEditor(store: store, context: context); await editor.reload(); return editor
    }
    private func labels(_ view: NSView) -> [String] {
        ((view as? NSTextField).map { [$0.stringValue] } ?? []) + view.subviews.flatMap(labels)
    }
    private func capture(_ name: String, controller: SettingsWindowController) throws {
        guard let path = ProcessInfo.processInfo.environment["MODELPLAN_B21_EVIDENCE"] else { return }
        let root = try XCTUnwrap(controller.window?.contentView); root.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(root.bitmapImageRepForCachingDisplay(in: root.bounds))
        root.cacheDisplay(in: root.bounds, to: bitmap)
        let data = try XCTUnwrap(bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.75]))
        try data.write(to: URL(fileURLWithPath: path).appendingPathComponent(name + ".jpg"))
    }
    private func choose(_ value: String, key: SettingKey, subscriptionID: String = "",
                        controller: SettingsWindowController) async throws {
        let popup = try XCTUnwrap(controller.choice(key: key, subscriptionID: subscriptionID))
        let index = try XCTUnwrap(popup.itemArray.firstIndex { $0.representedObject as? String == value })
        let committed = expectation(description: "persisted \(key.rawValue) action")
        controller.editor.onCommit = { _, _ in committed.fulfill() }
        popup.selectItem(at: index); XCTAssertTrue(popup.sendAction(popup.action, to: popup.target))
        await fulfillment(of: [committed], timeout: 3)
    }
    func testGeneralChoicesKeepObservedLoginSeparateAndGateNativeOnlyActions() async throws {
        let editor = try await makeEditor()
        var context = editor.context; context.capabilities.login = .requiresApproval; editor.update(context: context)
        let controller = SettingsWindowController(editor: editor, environmentProvider: { .init() })
        await controller.prepare()
        XCTAssertEqual(controller.selectedPaneID, "general")
        try await choose("false", key: .login, controller: controller)
        XCTAssertFalse(editor.snapshot!.preferences.openAtLogin)
        XCTAssertTrue(labels(controller.window!.contentView!).contains("System: approval required"))
        try await choose("twoWindows", key: .menuDisplay, controller: controller)
        try await choose("false", key: .automaticUpdates, controller: controller)
        XCTAssertFalse(editor.context.capabilities.updateServiceAvailable)
        try capture("general-en-day-offscreen", controller: controller)
        try await choose("zh-CN", key: .language, controller: controller)
        XCTAssertTrue(labels(controller.window!.contentView!).contains("登录时自动打开"))
        XCTAssertTrue(labels(controller.window!.contentView!).contains("自动检查更新"))
        try await choose("en", key: .language, controller: controller)
        controller.selectPane("dock")
        XCTAssertNil(controller.choice(key: .captureHiding))
        XCTAssertTrue(labels(controller.window!.contentView!).contains("Unavailable"))
        controller.selectPane("cockpit")
        let opening = try XCTUnwrap(controller.choice(key: .opening))
        XCTAssertFalse(try XCTUnwrap(opening.itemArray.first { $0.representedObject as? String == "hold" }).isEnabled)
        XCTAssertFalse(try XCTUnwrap(controller.choice(key: .countdown)).isEnabled)
        XCTAssertEqual(editor.effective?.opening, .quick)
        controller.selectPane("notifications")
        XCTAssertTrue(try XCTUnwrap(controller.choice(key: .notificationConsent)).isEnabled)
        controller.close()
    }
    func testAliasMarkedTextSurvivesEnvironmentAndContextRefreshThenCommitsOnce() async throws {
        let editor = try await makeEditor()
        var environment = SettingsEnvironment()
        let controller = SettingsWindowController(editor: editor, environmentProvider: { environment })
        await controller.prepare(); controller.selectPane("subscriptions")
        let field = try XCTUnwrap(controller.aliasControl(subscriptionID: "a")), window = try XCTUnwrap(controller.window)
        XCTAssertTrue(window.makeFirstResponder(field))
        let text = try XCTUnwrap(field.currentEditor() as? NSTextView)
        field.controlTextDidBeginEditing(Notification(name: NSControl.textDidBeginEditingNotification, object: field))
        text.setMarkedText("工", selectedRange: NSRange(location: 1, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertTrue(text.hasMarkedText()); XCTAssertTrue(field.draft.composing)
        environment.reduceTransparency = true; environment.darkAppearance = true; controller.refreshEnvironment()
        try await editor.store.update { $0.theme = .night }; await editor.reload()
        var context = editor.context
        context.subscriptions.append(.init(id: "d", name: .init("Plan d", "套餐 d"))); editor.update(context: context)
        XCTAssertTrue(controller.aliasControl(subscriptionID: "a") === field)
        XCTAssertTrue(field.currentEditor() === text)
        XCTAssertTrue(text.hasMarkedText()); XCTAssertTrue(text.string.contains("工"))
        XCTAssertNil(editor.snapshot?.preferences.subscriptionSettings["a"])
        text.unmarkText(); text.string = "工作"; field.stringValue = "工作"
        let committed = expectation(description: "completed alias saved")
        var count = 0; editor.onCommit = { _, _ in count += 1; committed.fulfill() }
        XCTAssertTrue(window.makeFirstResponder(controller.searchField))
        await fulfillment(of: [committed], timeout: 3)
        XCTAssertEqual(count, 1); XCTAssertEqual(editor.snapshot?.preferences.subscriptionSettings["a"]?.alias, "工作")
        try capture("subscriptions-en-night-offscreen", controller: controller)
        controller.close()
    }
    func testAliasFinishedDuringAnotherSaveRetainsDraftAndCanBeRetried() async throws {
        let editor = try await makeEditor()
        let controller = SettingsWindowController(editor: editor, environmentProvider: { .init() })
        await controller.prepare(); controller.selectPane("subscriptions")
        let first = try XCTUnwrap(controller.aliasControl(subscriptionID: "a"))
        let second = try XCTUnwrap(controller.aliasControl(subscriptionID: "b"))
        let revision = editor.snapshot!.revision
        let refresh = editor.onChange
        defer { editor.onChange = refresh }
        var finishedSecond = false, receipts = [UInt64]()
        let firstSaved = expectation(description: "first save finishes")
        editor.onCommit = { snapshot, _ in receipts.append(snapshot.revision); firstSaved.fulfill() }
        second.stringValue = "Second"
        second.controlTextDidBeginEditing(Notification(name: NSControl.textDidBeginEditingNotification, object: second))
        editor.onChange = {
            refresh?()
            guard editor.isSaving, !finishedSecond else { return }
            // Hold the first transaction here, before it can write, and end a second live alias.
            finishedSecond = true; editor.onChange = refresh
            second.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification, object: second))
            controller.refreshEnvironment()
            XCTAssertEqual(second.stringValue, "Second", "a completed alias must survive refresh while another save is pending")
            XCTAssertNotNil(controller.errorMessage, "a rejected save must have explicit retry feedback")
        }
        first.stringValue = "First"
        first.controlTextDidBeginEditing(Notification(name: NSControl.textDidBeginEditingNotification, object: first))
        first.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification, object: first))
        await fulfillment(of: [firstSaved], timeout: 3)
        await controller.waitForPendingSave()
        XCTAssertTrue(finishedSecond)
        XCTAssertEqual(editor.snapshot?.preferences.subscriptionSettings["a"]?.alias, "First")
        XCTAssertNil(editor.snapshot?.preferences.subscriptionSettings["b"])
        XCTAssertEqual(second.stringValue, "Second")
        XCTAssertTrue(controller.errorMessage?.contains("not saved") == true)
        let retried = expectation(description: "explicit retry saves the retained alias")
        editor.onCommit = { snapshot, _ in receipts.append(snapshot.revision); retried.fulfill() }
        second.controlTextDidBeginEditing(Notification(name: NSControl.textDidBeginEditingNotification, object: second))
        second.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification, object: second))
        await fulfillment(of: [retried], timeout: 3)
        await controller.waitForPendingSave()
        XCTAssertEqual(receipts, [revision + 1, revision + 2])
        let persisted = await editor.store.snapshot()
        XCTAssertEqual(persisted.preferences.subscriptionSettings["a"]?.alias, "First")
        XCTAssertEqual(persisted.preferences.subscriptionSettings["b"]?.alias, "Second")
        XCTAssertEqual(second.stringValue, "Second"); XCTAssertNil(controller.errorMessage)
        controller.close()
    }
    func testFailedAliasRetainsDraftWithoutReceiptAndEscapeCancelsIt() async throws {
        let editor = try await makeEditor()
        let controller = SettingsWindowController(editor: editor, environmentProvider: { .init() })
        await controller.prepare(); controller.selectPane("subscriptions")
        let field = try XCTUnwrap(controller.aliasControl(subscriptionID: "a"))
        let revision = editor.snapshot!.revision, invalid = String(repeating: "x", count: 129)
        var commits = 0, requests = 0
        editor.onCommit = { _, _ in commits += 1 }; editor.onHostRequest = { _ in requests += 1 }
        field.stringValue = invalid
        field.controlTextDidBeginEditing(Notification(name: NSControl.textDidBeginEditingNotification, object: field))
        field.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification, object: field))
        await controller.waitForPendingSave()
        XCTAssertEqual(commits, 0); XCTAssertEqual(requests, 0)
        XCTAssertEqual(editor.snapshot?.revision, revision)
        XCTAssertEqual(field.stringValue, invalid); XCTAssertNotNil(controller.errorMessage)
        XCTAssertTrue(try XCTUnwrap(controller.window).makeFirstResponder(field))
        let text = try XCTUnwrap(field.currentEditor() as? NSTextView)
        XCTAssertTrue(field.control(field, textView: text, doCommandBy: #selector(NSResponder.cancelOperation(_:))))
        XCTAssertEqual(field.stringValue, ""); XCTAssertEqual(editor.snapshot?.revision, revision)
        XCTAssertNil(controller.errorMessage, "cancelling the final alias draft must clear only its warning")
        XCTAssertNil(editor.snapshot?.preferences.subscriptionSettings["a"])
        controller.close()
    }
    func testRetiredAliasShortcutAndHintCallbacksCannotPersist() async throws {
        let editor = try await makeEditor()
        let controller = SettingsWindowController(editor: editor, environmentProvider: { .init() })
        await controller.prepare()
        let recorder = try XCTUnwrap(controller.shortcutControl(key: .openShortcut))
        let hint = try XCTUnwrap(controller.hintsResetControl), lateHint = hint.onInvoke, lateChord = recorder.onRecord
        controller.selectPane("subscriptions")
        let alias = try XCTUnwrap(controller.aliasControl(subscriptionID: "a")), lateAlias = alias.onFinish
        controller.selectPane("general")
        let revision = editor.snapshot!.revision
        let noCommit = expectation(description: "retired callbacks emit nothing"); noCommit.isInverted = true
        editor.onCommit = { _, _ in noCommit.fulfill() }
        editor.onHostRequest = { _ in noCommit.fulfill() }
        lateHint?(hint); lateChord?(recorder, .init("K",modifiers: [.command,.shift]))
        var draft = AliasDraft(subscriptionID: "a", committed: ""); draft.input("stale", composing: false)
        lateAlias?(alias, draft)
        await fulfillment(of: [noCommit], timeout: 0.1)
        XCTAssertEqual(editor.snapshot?.revision, revision)
        XCTAssertTrue(alias.isRetired); XCTAssertNil(alias.onFinish)
        XCTAssertTrue(recorder.isRetired); XCTAssertTrue(hint.isRetired)
        XCTAssertFalse(controller.shortcutControl(key: .openShortcut) === recorder)
        controller.close()
    }
    func testShortcutRecorderUsesNativeKeyPathAndDoesNotPretendGlobalRegistration() async throws {
        let editor = try await makeEditor()
        var context = editor.context
        context.shortcutObservations = [.init(action: .openCockpit, chord: editor.snapshot!.preferences.openShortcut, registration: .registered)]
        editor.update(context: context)
        let controller = SettingsWindowController(editor: editor, environmentProvider: { .init() })
        await controller.prepare()
        let recorder = try XCTUnwrap(controller.shortcutControl(key: .openShortcut))
        recorder.beginRecording()
        XCTAssertTrue(recorder.recording)
        XCTAssertFalse(recorder.record(key: ",", modifiers: [.command]))
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.command,.shift],
            timestamp: 0, windowNumber: controller.window!.windowNumber, context: nil, characters: "K", charactersIgnoringModifiers: "k", isARepeat: false, keyCode: 40))
        let committed = expectation(description: "recorded chord saved")
        editor.onCommit = { _, _ in committed.fulfill() }
        XCTAssertTrue(recorder.performKeyEquivalent(with: event))
        await fulfillment(of: [committed], timeout: 3)
        XCTAssertEqual(editor.snapshot?.preferences.openShortcut, .init("K", modifiers: [.command,.shift]))
        XCTAssertTrue(labels(controller.window!.contentView!).contains("Not registered; works in app"))
        XCTAssertFalse(recorder.recording)
        controller.close()
    }
    func testOrderButtonsAndLocalDropPersistButStaleAndRetiredCallbacksDoNot() async throws {
        let editor = try await makeEditor()
        let controller = SettingsWindowController(editor: editor, environmentProvider: { .init() })
        await controller.prepare(); controller.selectPane("dock")
        let live = controller.editor, order = try XCTUnwrap(controller.orderControl)
        let moved = expectation(description: "arrow reorder persisted")
        live.onCommit = { _, _ in moved.fulfill() }
        XCTAssertTrue(order.down.sendAction(order.down.action, to: order.down.target))
        await fulfillment(of: [moved], timeout: 3)
        XCTAssertEqual(try live.snapshot!.preferences.presentedSubscriptionIDs(["a","b","c"], includingHidden: true), ["b","a","c"])
        let item = try XCTUnwrap(order.tableView(order.table, pasteboardWriterForRow: 0) as? NSPasteboardItem)
        let token = try XCTUnwrap(item.string(forType: SettingsOrderControl.dragType))
        XCTAssertNotEqual(token, "b"); XCTAssertEqual(item.types, [SettingsOrderControl.dragType])
        let dropped = expectation(description: "local drop persisted")
        live.onCommit = { _, _ in dropped.fulfill() }
        XCTAssertTrue(order.acceptLocalDrop(token: token, source: order.table, row: 3))
        await fulfillment(of: [dropped], timeout: 3)
        XCTAssertEqual(try live.snapshot!.preferences.presentedSubscriptionIDs(["a","b","c"], includingHidden: true), ["a","c","b"])
        let stale = try XCTUnwrap(order.tableView(order.table, pasteboardWriterForRow: 0) as? NSPasteboardItem)
        var context = live.context; context.subscriptions.append(.init(id: "d", name: .init("D","丁"))); live.update(context: context)
        XCTAssertFalse(order.acceptLocalDrop(token: stale.string(forType: SettingsOrderControl.dragType), source: order.table, row: 3))
        let late = order.onMove, before = live.snapshot!.revision
        controller.selectPane("general")
        late?(order, "a", 1, ["a","c","b","d"])
        XCTAssertTrue(order.isRetired); XCTAssertNil(order.onMove)
        XCTAssertEqual(live.snapshot?.revision, before)
        controller.close()
    }
    func testHintResetAndReaderConsentArePersistedWithoutReaderActivation() async throws {
        let editor = try await makeEditor()
        try await editor.store.update { $0.helpHints = .init(seen: Set(FirstUseHintKind.allCases), opens: 2, reveals: 2) }
        let controller = SettingsWindowController(editor: editor, environmentProvider: { .init() })
        await controller.prepare()
        let request = expectation(description: "shared hint reset intent")
        editor.onHostRequest = { value in XCTAssertEqual(value.intent, .action(.resetHelpHints)); request.fulfill() }
        let button = try XCTUnwrap(controller.hintsResetControl)
        XCTAssertTrue(button.sendAction(button.action, to: button.target))
        await fulfillment(of: [request], timeout: 3)
        XCTAssertEqual(editor.snapshot?.preferences.helpHints, FirstUseHintPreferences())
        controller.selectPane("subscriptions")
        try await choose("true", key: .optionalReaders, subscriptionID: "gemini", controller: controller)
        XCTAssertTrue(editor.snapshot!.preferences.readerConsent.gemini)
        XCTAssertTrue(editor.context.readerObservations.isEmpty)
        XCTAssertNil(controller.choice(key: .detectedReaders))
        controller.close()
    }
}
