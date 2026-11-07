// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanEngineClient
@testable import ModelPlanAppIntegration
import ModelPlanSettings

/// SET-9-26 through the normal entry: when macOS refuses the login item or notifications, the
/// row says why and a fallback row opens the matching System Settings pane.
@MainActor final class SET926SystemFallbackJourneyTests: XCTestCase {
    private func makeApp(_ profile: URL) throws -> EngineDockMenuApplication {
        let config = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic",
                                               allowedEnvironment: [:], offline: true, readOnly: true)
        return EngineRowsEntry.make(configuration: config,
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en-US"]),
            createsNativePanels: false, dockEnvironment: normalEntryTestEnvironment, activateSettings: {})
    }
    func testSET_9_26DeniedServicesOfferSystemSettings() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("set-9-26-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try makeApp(profile)
        let notifications = JourneyNotificationService(); notifications.state = .denied
        app.notificationAuthorizationService = notifications
        var opened: [URL] = []
        app.openSystemSettings = { opened.append($0) }
        await app.prepare()
        let editor = app.settingsHost.application.editor
        let preferences = try XCTUnwrap(editor.snapshot).preferences
        let rows = try SettingsCatalogue.rows(preferences: preferences, context: editor.context)
        // The test host is not the app bundle, so macOS has no login item for it.
        XCTAssertEqual(editor.context.capabilities.login, .unavailable)
        let login = try XCTUnwrap(rows.first { $0.key == .login })
        XCTAssertTrue(login.subtitle.english.contains("System Settings"), login.subtitle.english)
        XCTAssertFalse(login.subtitle.english.contains("first-run"), "the reason must be true in production")
        for key in [SettingKey.loginSystemSettings, .notificationSystemSettings] {
            XCTAssertEqual(rows.first { $0.key == key }?.availability, .available, "fallback row missing: \(key)")
        }
        try editor.request(.openSystemSettings(.notifications))
        try editor.request(.openSystemSettings(.loginItems))
        XCTAssertEqual(opened, [SettingsSystemPane.notifications.url, SettingsSystemPane.loginItems.url])
        await app.composition.stop()
    }
    func testSET_9_26WorkingNotificationsShowNoFallback() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("set-9-26-ok-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try makeApp(profile)
        let notifications = JourneyNotificationService(); notifications.state = .authorized
        app.notificationAuthorizationService = notifications
        await app.prepare()
        let editor = app.settingsHost.application.editor
        let rows = try SettingsCatalogue.rows(preferences: try XCTUnwrap(editor.snapshot).preferences, context: editor.context)
        XCTAssertFalse(rows.contains { $0.key == .notificationSystemSettings })
        await app.composition.stop()
    }
}
