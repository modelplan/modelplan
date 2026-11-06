// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanEngineClient
@testable import ModelPlanAppIntegration
import ModelPlanSettings

/// SET-9-18 through the normal entry: the packaged app's Settings (EngineRowsEntry, v1 normal
/// entry) offers the three v1 notification kinds only. "Resets expiring" and "Data stopped
/// arriving" are v1.1 (owner, 2026-11-06 06:50Z): they are neither listed nor found by search.
@MainActor final class SET918NotificationKindsJourneyTests: XCTestCase {
    func testSET_9_18NormalEntryOffersOnlyTheV1NotificationKinds() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("set-9-18-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let config = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic",
                                               allowedEnvironment: [:], offline: true, readOnly: true)
        let app = EngineRowsEntry.make(configuration: config,
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en-US"]),
            createsNativePanels: false, dockEnvironment: normalEntryTestEnvironment, activateSettings: {})
        await app.prepare()
        let editor = app.settingsHost.application.editor
        XCTAssertTrue(editor.context.v1NormalEntry)
        let preferences = try XCTUnwrap(editor.snapshot).preferences
        let rows = try SettingsCatalogue.rows(preferences: preferences, context: editor.context)
        for key in [SettingKey.forecast, .reset, .official] {
            XCTAssertNotNil(rows.first { $0.key == key }, "v1 notification kind missing: \(key)")
        }
        XCTAssertFalse(rows.contains { [.expiring, .stale].contains($0.key) }, "SET-9-18: v1.1 notification kinds must not appear in v1")
        for query in ["Resets expiring", "Data stopped", "重置即将到期", "数据停止更新"] {
            let found = try SettingsCatalogue.rows(preferences: preferences, context: editor.context, query: query)
            XCTAssertFalse(found.contains { [.expiring, .stale].contains($0.key) }, "Search finds a v1.1 kind: \(query)")
        }
        await app.composition.stop()
    }
}
