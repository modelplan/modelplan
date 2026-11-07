// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanDock
import ModelPlanSettings
import ModelPlanEngineStore
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanAppIntegration

/// MENU-13: requests from the status menu and Settings reach the host at normal entry.
/// Login is covered by CommunityLoginServiceAdapterTests; shortcuts by SET905ShortcutRegistrationJourneyTests.
@MainActor final class MenuHostDispatchJourneyTests: XCTestCase {
    private func makeApp() throws -> EngineDockMenuApplication {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("menu-host-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
        let config = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true)
        return EngineRowsEntry.make(configuration: config,
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"]),
            createsNativePanels: false, dockEnvironment: normalEntryTestEnvironment,
            makeClient: { _, store in SettingsJourneyClient(store: store, rows: rows) }, activateSettings: {})
    }

    func testStatusMenuAndSettingsLinksReachTheHostOpener() async throws {
        let app = try makeApp(); defer { app.composition.dock.close() }
        var opened: [URL] = []
        app.openPublicURL = { opened.append($0) }
        await app.prepare()
        app.renderMenu()
        let menu = try XCTUnwrap(app.liveStatusMenu)
        for title in ["Website", "Methodology", "Privacy"] {
            let item = try XCTUnwrap(menu.items.first { $0.title == title }, title)
            XCTAssertTrue(item.isEnabled, title)
            _ = try XCTUnwrap(item.target as? NSObject).perform(try XCTUnwrap(item.action), with: item)
        }
        XCTAssertEqual(opened, [SettingsPublicLink.website.url, SettingsPublicLink.methodology.url, SettingsPublicLink.privacy.url])
        opened = []
        let editor = app.settingsHost.application.editor
        try editor.request(.openLink(.repository))
        try editor.request(.openLink(.feedback))
        XCTAssertEqual(opened, [SettingsPublicLink.repository.url, SettingsPublicLink.feedback.url])
    }

    func testNotificationConsentFromSettingsAsksTheSystemOnce() async throws {
        let app = try makeApp(); defer { app.composition.dock.close() }
        let notifications = JourneyNotificationService()
        app.notificationAuthorizationService = notifications
        await app.prepare()
        let editor = app.settingsHost.application.editor
        try await editor.commit(SettingsB22Edit.notificationConsent(true))
        for _ in 0..<500 where editor.context.notificationAuthorization != .authorized { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(notifications.requests, 1)
        XCTAssertEqual(editor.context.notificationAuthorization, .authorized)
        try await editor.commit(SettingsB22Edit.notificationConsent(false))
        try await editor.commit(SettingsB22Edit.notificationConsent(true))
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(notifications.requests, 1, "an answered system prompt is not asked again")
    }
}
