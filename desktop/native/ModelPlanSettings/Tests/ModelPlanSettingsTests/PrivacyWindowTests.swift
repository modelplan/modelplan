// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanSettings

@MainActor final class PrivacyWindowTests: XCTestCase {
    private final class Clipboard: SettingsDiagnosticClipboard {
        var accepted = true, writes = [String]()
        func writeDiagnostics(_ text: String) -> Bool { writes.append(text); return accepted }
    }
    private func editor() async throws -> SettingsEditor {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("privacy-window-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = try SettingsStore(url: directory.appendingPathComponent("preferences.json"))
        try await store.update { $0.language = .english }
        let editor = SettingsEditor(store: store); await editor.reload(); return editor
    }
    private func strings(_ view: NSView) -> [String] {
        ((view as? NSTextField).map { [$0.stringValue] } ?? [])
            + ((view as? NSTextView).map { [$0.string] } ?? []) + view.subviews.flatMap(strings)
    }
    func testNotificationAndPrivacyChoicesHaveTruthfulObservedStateAndNoCLIMutation() async throws {
        let editor = try await editor()
        var context = editor.context; context.notificationAuthorization = .denied; editor.update(context: context)
        var requests = [SettingsHostRequest](); editor.onHostRequest = { requests.append($0) }
        let controller = SettingsWindowController(editor: editor, environmentProvider: { .init() }, clipboard: Clipboard())
        await controller.prepare(); controller.selectPane("notifications")
        let consent = try XCTUnwrap(controller.choice(key: .notificationConsent))
        consent.selectItem(at: 0); XCTAssertTrue(consent.sendAction(consent.action, to: consent.target))
        await controller.waitForPendingSave()
        XCTAssertTrue(editor.snapshot!.preferences.notifications.optedIn)
        XCTAssertTrue(strings(controller.window!.contentView!).contains("System permission denied"))
        XCTAssertEqual(requests.last?.intent, .notificationConsentChanged(previous: false, enabled: true))
        controller.selectPane("privacy")
        let names = try XCTUnwrap(controller.choice(key: .projectNames))
        XCTAssertEqual(names.selectedItem?.representedObject as? String, "true")
        names.selectItem(at: 1); _ = names.sendAction(names.action, to: names.target); await controller.waitForPendingSave()
        XCTAssertFalse(editor.snapshot!.preferences.showProjectNames)
        XCTAssertNil(controller.actionControl(key: .clearCLI))
        XCTAssertFalse(try XCTUnwrap(controller.actionControl(key: .clearAppCache)).isEnabled)
        XCTAssertTrue(strings(controller.window!.contentView!).contains { $0.contains("35 days") && $0.contains("371 days") })
        controller.close()
    }
    func testAboutCopiesOnlyAllowlistedDiagnosticsAndLinksAreHostRequests() async throws {
        let editor = try await editor(), clipboard = Clipboard()
        try await editor.store.update { $0.subscriptionSettings["account-private"] = .init(alias: "private-name"); $0.readerConsent.gemini = true }
        var context = editor.context
        context.about = .init(appVersion: "1.2.3", cliVersion: "/private/credential")
        context.about.macOSVersion = "26.5.2"; context.about.enabledReaders = [.codex]
        context.about.architecture = .intelUntested
        context.licenseNotices = [.init(component: "Example", license: "MIT", text: "Example bundled notice text")]
        editor.update(context: context)
        var requests = [SettingsHostRequest](), commits = 0
        editor.onHostRequest = { requests.append($0) }; editor.onCommit = { _, _ in commits += 1 }
        let controller = SettingsWindowController(editor: editor, environmentProvider: { .init() }, clipboard: clipboard)
        await controller.prepare(); controller.selectPane("about")
        let revision = editor.snapshot!.revision
        let copy = try XCTUnwrap(controller.actionControl(key: .diagnostics))
        XCTAssertTrue(copy.sendAction(copy.action, to: copy.target))
        let payload = try XCTUnwrap(clipboard.writes.last)
        XCTAssertTrue(payload.contains("app=1.2.3")); XCTAssertTrue(payload.contains("cli=unknown"))
        for secret in ["/private", "account-private", "private-name", "gemini"] { XCTAssertFalse(payload.contains(secret)) }
        XCTAssertTrue(strings(controller.window!.contentView!).contains(SettingsAbout.intelNote.english))
        XCTAssertTrue(strings(controller.window!.contentView!).contains { $0.contains("Example bundled notice text") })
        let link = try XCTUnwrap(controller.actionControl(key: .feedback))
        XCTAssertTrue(link.sendAction(link.action, to: link.target))
        XCTAssertEqual(requests.last?.intent, .openPublicLink(.feedback))
        XCTAssertEqual(editor.snapshot!.revision, revision); XCTAssertEqual(commits, 0)
        let late = copy.onInvoke
        controller.selectPane("general"); late?(copy)
        XCTAssertEqual(clipboard.writes.count, 1, "retired copy control must not write again")
        controller.close()
    }
    func testAliasWarningClearsOnCancelOrRestoreAndPreservesClipboardErrors() async throws {
        let editor = try await editor(), clipboard = Clipboard(); clipboard.accepted = false
        var context = editor.context; context.subscriptions = [.init(id: "sample", name: .init("Sample", "示例"))]
        editor.update(context: context)
        let controller = SettingsWindowController(editor: editor, environmentProvider: { .init() }, clipboard: clipboard)
        await controller.prepare()
        controller.searchField.stringValue = "a"
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: controller.searchField))
        let field = try XCTUnwrap(controller.aliasControl(subscriptionID: "sample"))
        @MainActor func failAlias() async {
            field.stringValue = String(repeating: "x", count: 129)
            field.controlTextDidBeginEditing(Notification(name: NSControl.textDidBeginEditingNotification, object: field))
            field.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification, object: field))
            await controller.waitForPendingSave()
        }
        await failAlias(); XCTAssertNotNil(controller.errorMessage)
        field.stringValue = ""
        field.controlTextDidBeginEditing(Notification(name: NSControl.textDidBeginEditingNotification, object: field))
        field.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification, object: field))
        XCTAssertNil(controller.errorMessage, "restoring committed text must clear its alias warning")
        await failAlias()
        let copy = try XCTUnwrap(controller.actionControl(key: .diagnostics)); _ = copy.sendAction(copy.action, to: copy.target)
        let unrelated = try XCTUnwrap(controller.errorMessage)
        XCTAssertEqual(unrelated, "Could not copy diagnostics.")
        XCTAssertTrue(controller.window!.makeFirstResponder(field))
        let text = try XCTUnwrap(field.currentEditor() as? NSTextView)
        XCTAssertTrue(field.control(field, textView: text, doCommandBy: #selector(NSResponder.cancelOperation(_:))))
        XCTAssertEqual(controller.errorMessage, unrelated, "cancelling an alias cannot clear another operation's error")
        controller.close()
    }
    func testOnePageFirstRunZeroOneSixSubscriptionsSharesLoginAndCompletesPreview() async throws {
        let editor = try await editor()
        var events = [SettingsHostRequest](); editor.onHostRequest = { events.append($0) }
        for count in [0,1,6] {
            var context = editor.context
            context.subscriptions = (0..<count).map { .init(id: "sample-\($0)", name: .init("Plan \($0)", "套餐 \($0)")) }
            editor.update(context: context)
            let firstRun = SettingsFirstRunController(editor: editor, host: .standalone)
            await firstRun.prepare()
            XCTAssertEqual(firstRun.loginButton.state, count == 0 ? .on : .off)
            for button in firstRun.readerButtons.values { XCTAssertEqual(button.state, .off) }
            XCTAssertFalse(firstRun.helpButton.isEnabled)
            firstRun.loginButton.state = .off; _ = firstRun.loginButton.sendAction(firstRun.loginButton.action, to: firstRun.loginButton.target)
            _ = firstRun.doneButton.sendAction(firstRun.doneButton.action, to: firstRun.doneButton.target)
            await firstRun.waitForCompletion()
            XCTAssertFalse(editor.snapshot!.preferences.openAtLogin)
            XCTAssertTrue(editor.snapshot!.preferences.onboarding.completed)
            XCTAssertEqual(events.last?.intent, .firstRunCompleted(effects: [.returnToSettings], loginRequest: nil))
            let revision = editor.snapshot!.revision
            _ = firstRun.doneButton.sendAction(firstRun.doneButton.action, to: firstRun.doneButton.target)
            await firstRun.waitForCompletion(); XCTAssertEqual(editor.snapshot!.revision, revision)
            firstRun.close()
        }
        XCTAssertEqual(events.count, 3)
    }
    func testFirstRunHelpUsesExistingMapAndStaleChoicesRequireReview() async throws {
        let editor = try await editor()
        var context = editor.context; context.capabilities.helpMapAvailable = true; editor.update(context: context)
        var map = OptionHelpState(), events = [SettingsHostRequest]()
        editor.onHostRequest = { request in
            events.append(request)
            if case .firstRunCompleted(let effects, _) = request.intent, effects.contains(.latchOptionHelp) { map.latchFromFirstRun() }
        }
        let settings = SettingsWindowController(editor: editor, environmentProvider: { .init() }, clipboard: Clipboard())
        await settings.prepare()
        let firstRun = SettingsFirstRunController(editor: editor)
        await firstRun.prepare()
        firstRun.loginButton.state = .off; _ = firstRun.loginButton.sendAction(firstRun.loginButton.action, to: firstRun.loginButton.target)
        try await editor.commit(.language(.chinese))
        _ = firstRun.helpButton.sendAction(firstRun.helpButton.action, to: firstRun.helpButton.target)
        await firstRun.waitForCompletion()
        XCTAssertNotNil(firstRun.errorMessage); XCTAssertFalse(map.visible); XCTAssertTrue(events.isEmpty)
        XCTAssertFalse(editor.snapshot!.preferences.onboarding.completed)
        XCTAssertEqual(firstRun.loginButton.state, .off)
        _ = firstRun.helpButton.sendAction(firstRun.helpButton.action, to: firstRun.helpButton.target)
        await firstRun.waitForCompletion()
        XCTAssertTrue(map.latched); XCTAssertEqual(events.count, 1)
        XCTAssertEqual(settings.choice(key: .login)?.selectedItem?.representedObject as? String, "false")
        map.release(); XCTAssertFalse(map.visible)
        firstRun.close(); settings.close()
    }
}
