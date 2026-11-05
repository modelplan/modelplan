// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class I03FirstRunCopyJourneyTests: XCTestCase {
    private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
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
            await app.composition.stop()
        }
    }
}
