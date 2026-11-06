// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanEngineClient
@testable import ModelPlanAppIntegration
import ModelPlanSettings

/// SET-9-18 / SET-9-29 through the normal entry: the packaged app's Settings (EngineRowsEntry,
/// v1 normal entry) never lists "Resets expiring" or "Data stopped arriving" (v1.1, owner
/// D36). The forecast-exhaustion kind is data-driven: hidden while the engine reports no
/// forecast producer (F1), shown and enabled once it does. Saved kinds are never changed.
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
        for key in [SettingKey.reset, .official] {
            XCTAssertNotNil(rows.first { $0.key == key }, "v1 notification kind missing: \(key)")
        }
        XCTAssertFalse(editor.context.capabilities.forecastProducerAvailable)
        XCTAssertFalse(rows.contains { $0.key == .forecast }, "SET-9-29: no forecast producer, so no forecast row")
        for query in ["May not last", "可能撑不到"] {
            let found = try SettingsCatalogue.rows(preferences: preferences, context: editor.context, query: query)
            XCTAssertFalse(found.contains { $0.key == .forecast }, "Search finds the hidden forecast kind: \(query)")
        }
        XCTAssertFalse(rows.contains { [.expiring, .stale].contains($0.key) }, "SET-9-18: v1.1 notification kinds must not appear in v1")
        for query in ["Resets expiring", "Data stopped", "重置即将到期", "数据停止更新"] {
            let found = try SettingsCatalogue.rows(preferences: preferences, context: editor.context, query: query)
            XCTAssertFalse(found.contains { [.expiring, .stale].contains($0.key) }, "Search finds a v1.1 kind: \(query)")
        }

        // The engine reports its forecast producer: the row appears, enabled, with the saved value.
        var context = editor.context
        context.observeForecastProducer(true)
        app.settingsHost.application.update(context: context)
        let withForecast = try SettingsCatalogue.rows(preferences: preferences, context: editor.context, paneID: "notifications")
        let forecast = try XCTUnwrap(withForecast.first { $0.key == .forecast }, "forecast kind missing once the producer exists")
        XCTAssertEqual(forecast.availability, .available, "SET-9-29: a shown forecast kind is usable")
        XCTAssertEqual(forecast.value, .toggle(preferences.notifications.kinds.contains(.forecast)))
        XCTAssertFalse(withForecast.contains { [.expiring, .stale].contains($0.key) })
        // The producer goes away again: hidden, and the saved kinds are untouched.
        context = editor.context
        context.observeForecastProducer(false)
        app.settingsHost.application.update(context: context)
        XCTAssertFalse(try SettingsCatalogue.rows(preferences: preferences, context: editor.context).contains { $0.key == .forecast })
        XCTAssertEqual(try XCTUnwrap(editor.snapshot).preferences.notifications.kinds, preferences.notifications.kinds)
        await app.composition.stop()
    }
}
