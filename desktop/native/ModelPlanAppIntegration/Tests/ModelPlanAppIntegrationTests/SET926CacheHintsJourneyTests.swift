// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanEngineClient
@testable import ModelPlanAppIntegration
import ModelPlanSettings

/// SET-9-05 / SET-9-26 through the normal entry: "Clear app cache" and "Show hints again" work.
@MainActor final class SET926CacheHintsJourneyTests: XCTestCase {
    func testSET_9_26NormalEntryClearsCacheAndResetsHints() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("set-9-26-cache-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let config = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic",
                                               allowedEnvironment: [:], offline: true, readOnly: true)
        let app = EngineRowsEntry.make(configuration: config,
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en-US"]),
            createsNativePanels: false, dockEnvironment: normalEntryTestEnvironment, activateSettings: {})
        var clears = 0
        app.clearAppCache = { clears += 1 }
        await app.prepare()
        let editor = app.settingsHost.application.editor
        let rows = try SettingsCatalogue.rows(preferences: try XCTUnwrap(editor.snapshot).preferences, context: editor.context)
        for key in [SettingKey.clearAppCache, .resetHints] {
            XCTAssertEqual(rows.first { $0.key == key }?.availability, .available, "not usable: \(key)")
        }
        try editor.request(.clearAppCache)
        XCTAssertEqual(clears, 1)
        let before = try XCTUnwrap(editor.snapshot).revision
        try await editor.commit(SettingsB21Edit.resetHints)
        let saved = try XCTUnwrap(editor.snapshot)
        XCTAssertGreaterThan(saved.revision, before)
        XCTAssertEqual(saved.preferences.helpHints, FirstUseHintPreferences())
        await app.composition.stop()
    }
    func testAppCacheClearKeepsTheCLICacheAndRefusesOtherFolders() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("app-cache-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let own = root.appendingPathComponent("org.modelplan.synthetic"), cli = root.appendingPathComponent("modelplan")
        for folder in [own, cli] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data("synthetic".utf8).write(to: folder.appendingPathComponent("item"))
        }
        XCTAssertTrue(EngineAppCache.clear(cachesRoot: root, bundleIdentifier: "org.modelplan.synthetic"))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: own.path), [])
        XCTAssertFalse(EngineAppCache.clear(cachesRoot: root, bundleIdentifier: "modelplan"))
        XCTAssertFalse(EngineAppCache.clear(cachesRoot: root, bundleIdentifier: "../modelplan"))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: cli.path), ["item"])
    }
}
