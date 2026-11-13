// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
@testable import ModelPlanAppIntegration
import ModelPlanSettings

@MainActor private final class MenuJourneyRegistrar: EngineShortcutRegistering {
    var onPress: ((ShortcutAction) -> Void)?
    private(set) var registered: [ShortcutAction: ShortcutChord] = [:]
    func register(_ chord: ShortcutChord, action: ShortcutAction) -> ShortcutRegistration { registered[action] = chord; return .registered }
    func unregisterAll() { registered = [:] }
}

/// MENU-13 through the normal entry: a host request from Settings or a menu reaches its real consumer.
/// Open at login needs the app bundle, so it is covered by CommunityLoginServiceAdapterTests.
@MainActor final class MENU13HostRequestJourneyTests: XCTestCase {
    func testMENU_13SettingsAndMenuRequestsAreDispatched() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("menu-13-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let config = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic",
                                               allowedEnvironment: [:], offline: true, readOnly: true)
        let app = EngineRowsEntry.make(configuration: config,
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en-US"]),
            createsNativePanels: false, dockEnvironment: normalEntryTestEnvironment, activateSettings: {})
        let registrar = MenuJourneyRegistrar(), notifications = JourneyNotificationService()
        app.shortcutRegistrar = registrar; app.notificationAuthorizationService = notifications
        var links: [URL] = [], panes: [URL] = []
        app.openPublicURL = { links.append($0) }; app.openSystemSettings = { panes.append($0) }
        await app.prepare()
        let editor = app.settingsHost.application.editor

        // Links: from Settings and from the menu's own action.
        try editor.request(.openLink(.website))
        XCTAssertEqual(links, [SettingsPublicLink.website.url])
        let item = NSMenuItem(); item.representedObject = SettingsPublicLink.website.rawValue
        _ = app.perform(Selector(("openPublicLink:")), with: item)
        XCTAssertEqual(links.count, 2, "the menu's link reaches the same opener")

        // System Settings panes.
        try editor.request(.openSystemSettings(.notifications))
        XCTAssertEqual(panes, [SettingsSystemPane.notifications.url])

        // Shortcuts.
        let chord = ShortcutChord("K", modifiers: [.command, .option])
        try await editor.commit(SettingsB21Edit.shortcut(.toggleDock, chord))
        XCTAssertEqual(registrar.registered[.toggleDock], chord)

        // Notifications: consent asks macOS once, only after the choice.
        XCTAssertEqual(notifications.requests, 0)
        try await editor.commit(SettingsB22Edit.notificationConsent(true))
        for _ in 0..<200 where notifications.requests == 0 { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(notifications.requests, 1)
        await app.composition.stop()
    }
}
