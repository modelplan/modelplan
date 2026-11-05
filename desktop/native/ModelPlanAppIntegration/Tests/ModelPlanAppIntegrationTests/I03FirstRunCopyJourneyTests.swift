// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanShell
import ModelPlanWire
@testable import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class I03FirstRunCopyJourneyTests: XCTestCase {
    private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
    func testNormalFirstRunWithNoSubscriptionsShowsEmptyStateAndCanFinish() async throws {
        for locale in ["en", "zh-CN"] {
            let profile = FileManager.default.temporaryDirectory.appendingPathComponent("i03-empty-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: profile) }
            let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
            var document = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
            var projection = try XCTUnwrap(document["projection"] as? [String: Any])
            projection["rows"] = []; projection["resetEvents"] = []
            document["projection"] = projection
            let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: document))
            let config = EngineClientConfiguration(executableURL: profile.appendingPathComponent("synthetic"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true)
            let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: [locale])
            let app = EngineRowsEntry.make(configuration: config, settingsStore: store, createsNativePanels: false,
                dockEnvironment: normalEntryTestEnvironment,
                makeClient: { _, engineStore in SettingsJourneyClient(store: engineStore, rows: rows) }, activateSettings: {})
            // Done can dispatch the checked login choice once the real host wiring lands.
            // Keep this journey isolated from the machine's Login Items in either version.
            app.loginServiceAdapter = CommunityLoginServiceAdapter(item: .init(isAppBundle: true, service: JourneyLoginService()))
            await app.prepare(); await app.composition.start()
            defer { app.composition.dock.close() }
            let before = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
            await app.restoreFirstRunIfNeeded()
            let window = try XCTUnwrap(NSApplication.shared.windows.first { !before.contains(ObjectIdentifier($0)) && $0.isVisible })
            defer { window.close() }
            let views = descendants(try XCTUnwrap(window.contentView))
            let expected = locale == "en" ? "No subscriptions found" : "未检测到订阅"
            XCTAssertTrue(views.compactMap { $0 as? NSTextField }.contains {
                !$0.isHiddenOrHasHiddenAncestor && $0.stringValue == expected
            })
            let done = try XCTUnwrap(views.first { $0.accessibilityIdentifier() == "firstRun.done" } as? NSButton)
            XCTAssertTrue(done.isEnabled); done.performClick(nil)
            var snapshot = await store.snapshot()
            for _ in 0..<200 where !snapshot.preferences.onboarding.completed {
                try await Task.sleep(for: .milliseconds(10)); snapshot = await store.snapshot()
            }
            XCTAssertTrue(snapshot.preferences.onboarding.completed)
            let beforeSettings = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
            await app.settingsHost.present(paneID: "subscriptions", origin: .userInitiated)
            let settingsWindow = try XCTUnwrap(NSApplication.shared.windows.first {
                !beforeSettings.contains(ObjectIdentifier($0)) && $0.isVisible && $0.windowController is SettingsWindowController
            })
            defer { settingsWindow.close() }
            let settingsController = try XCTUnwrap(settingsWindow.windowController as? SettingsWindowController)
            func assertEmptyText(_ keys: [SettingKey]) throws {
                let settingsRows = descendants(try XCTUnwrap(settingsWindow.contentView)).compactMap { $0 as? SettingsNativeRow }
                for key in keys {
                    let row = try XCTUnwrap(settingsRows.first { $0.key == key && !$0.isHiddenOrHasHiddenAncestor })
                    XCTAssertTrue(descendants(row).compactMap { $0 as? NSTextField }.contains {
                        !$0.isHiddenOrHasHiddenAncestor && $0.stringValue == expected
                    }, "The empty subscription copy should match first run for \(key)")
                }
            }
            try assertEmptyText([.visible, .alias])
            settingsController.selectPane("dock")
            try assertEmptyText([.percentagePin])
            await app.composition.stop()
        }
    }
    func testNormalFirstRunShowsPrivacyAndPublicRecommendationInBothLanguages() async throws {
        for locale in ["en", "zh-CN"] {
            let profile = FileManager.default.temporaryDirectory.appendingPathComponent("i03-first-run-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: profile) }
            let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
            let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
            let config = EngineClientConfiguration(executableURL: profile.appendingPathComponent("synthetic"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true)
            let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: [locale])
            let app = EngineRowsEntry.make(configuration: config, settingsStore: store, createsNativePanels: false,
                dockEnvironment: normalEntryTestEnvironment,
                makeClient: { _, engineStore in SettingsJourneyClient(store: engineStore, rows: rows) }, activateSettings: {})
            await app.prepare()
            await app.composition.start()
            defer { app.composition.dock.close() }
            let before = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
            await app.restoreFirstRunIfNeeded()
            let window = try XCTUnwrap(NSApplication.shared.windows.first { !before.contains(ObjectIdentifier($0)) && $0.isVisible })
            defer { window.close() }
            let views = descendants(try XCTUnwrap(window.contentView))
            let visibleCopy = views.compactMap { $0 as? NSTextField }
                .filter { !$0.isHiddenOrHasHiddenAncestor }.map(\.stringValue)
            let internalTerm = locale == "en" ? "engine" : "引擎"
            XCTAssertFalse(visibleCopy.contains { $0.localizedCaseInsensitiveContains(internalTerm) },
                           "The first-run surface must not expose internal implementation names")
            let privacy = try XCTUnwrap(views.first { $0.accessibilityIdentifier() == "firstRun.privacy" } as? NSTextField)
            let recommendation = try XCTUnwrap(views.first { $0.accessibilityIdentifier() == "firstRun.publicRecommendation" } as? NSTextField)
            XCTAssertFalse(privacy.isHiddenOrHasHiddenAncestor)
            XCTAssertFalse(recommendation.isHiddenOrHasHiddenAncestor)
            XCTAssertEqual(privacy.stringValue, locale == "en" ? "Nothing on this Mac is uploaded; only public data is downloaded" : "不上传任何本机数据，只下载公开数据")
            XCTAssertEqual(recommendation.stringValue, locale == "en" ? "Recommendations use public data." : "推荐基于公开数据。")
            let stack = try XCTUnwrap(privacy.superview as? NSStackView)
            let privacyIndex = try XCTUnwrap(stack.arrangedSubviews.firstIndex(of: privacy))
            let recommendationIndex = try XCTUnwrap(stack.arrangedSubviews.firstIndex(of: recommendation))
            XCTAssertEqual(recommendationIndex, privacyIndex + 1)
            XCTAssertTrue(views.compactMap { $0 as? NSTextField }.contains { !$0.isHiddenOrHasHiddenAncestor && $0.stringValue == (locale == "en" ? "You can turn this off in Settings" : "可随时在设置里关闭") })
            let done = try XCTUnwrap(views.first { $0.accessibilityIdentifier() == "firstRun.done" } as? NSButton)
            let help = try XCTUnwrap(views.first { $0.accessibilityIdentifier() == "firstRun.help" } as? NSButton)
            XCTAssertFalse(done.isHiddenOrHasHiddenAncestor); XCTAssertFalse(help.isHiddenOrHasHiddenAncestor)
            XCTAssertEqual(done.title, locale == "en" ? "Done" : "完成")
            XCTAssertEqual(help.title, locale == "en" ? "See what's here" : "看看都有什么")
            let buttons = try XCTUnwrap(done.superview as? NSStackView)
            XCTAssertTrue(help.superview === buttons)
            XCTAssertEqual(buttons.orientation, .horizontal)
            let doneIndex = try XCTUnwrap(buttons.arrangedSubviews.firstIndex(of: done))
            let helpIndex = try XCTUnwrap(buttons.arrangedSubviews.firstIndex(of: help))
            XCTAssertEqual(helpIndex, doneIndex + 1, "The exploration link must sit next to Done")
            let login = try XCTUnwrap(views.first { $0.accessibilityIdentifier() == "firstRun.login" } as? NSButton)
            let loginBlock = try XCTUnwrap(login.superview as? NSStackView)
            let page = try XCTUnwrap(buttons.superview as? NSStackView)
            let loginIndex = try XCTUnwrap(page.arrangedSubviews.firstIndex(of: loginBlock))
            let buttonsIndex = try XCTUnwrap(page.arrangedSubviews.firstIndex(of: buttons))
            XCTAssertLessThan(loginIndex, buttonsIndex, "The login choice must precede Done")
            await app.composition.stop()
        }
    }
}
