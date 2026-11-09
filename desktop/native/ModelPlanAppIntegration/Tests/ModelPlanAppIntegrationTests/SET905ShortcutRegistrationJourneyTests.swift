// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanEngineClient
@testable import ModelPlanAppIntegration
import ModelPlanSettings

@MainActor private final class JourneyShortcutRegistrar: EngineShortcutRegistering {
    var onPress: ((ShortcutAction) -> Void)?
    var outcome: ShortcutRegistration = .registered
    private(set) var registered: [ShortcutAction: ShortcutChord] = [:]
    func register(_ chord: ShortcutChord, action: ShortcutAction) -> ShortcutRegistration {
        if outcome == .registered { registered[action] = chord }
        return outcome
    }
    func unregisterAll() { registered = [:] }
}

/// SET-9-05 / SET-9-06 (D37) through the normal entry: nothing registers by default, a saved
/// chord registers, Settings shows the outcome, and pressing it reaches its consumer. Since D56
/// the widget slot is the Find Quota Widget shortcut (FindQuotaWidgetJourneyTests covers the spotlight).
@MainActor final class SET905ShortcutRegistrationJourneyTests: XCTestCase {
    func testSET_9_05SavedChordRegistersAndFindsTheWidget() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("set-9-05-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let config = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic",
                                               allowedEnvironment: [:], offline: true, readOnly: true)
        let app = EngineRowsEntry.make(configuration: config,
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en-US"]),
            createsNativePanels: false, dockEnvironment: normalEntryTestEnvironment, activateSettings: {})
        let registrar = JourneyShortcutRegistrar()
        app.shortcutRegistrar = registrar
        await app.prepare()
        let editor = app.settingsHost.application.editor
        XCTAssertTrue(registrar.registered.isEmpty, "D37: a fresh profile registers nothing")
        XCTAssertNil(editor.context.unavailableControls[.dockShortcut])
        let chord = ShortcutChord("K", modifiers: [.command, .option])
        try await editor.commit(SettingsB21Edit.shortcut(.toggleDock, chord))
        XCTAssertEqual(registrar.registered[.toggleDock], chord)
        XCTAssertEqual(editor.context.shortcutPolicy(preferences: try XCTUnwrap(editor.snapshot).preferences).dockRegistration, .registered)
        XCTAssertEqual(try XCTUnwrap(editor.snapshot).preferences.showDock, true)
        // D56: pressing it finds the widget; it no longer turns it off.
        registrar.onPress?(.toggleDock)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(try XCTUnwrap(editor.snapshot).preferences.showDock, true, "the Find shortcut never hides the widget")
        // The press saves on its own task; let it finish, as a person's next action would.
        for _ in 0..<500 where editor.isSaving { try await Task.sleep(for: .milliseconds(10)) }
        registrar.outcome = .conflict
        let taken = ShortcutChord("J", modifiers: [.command, .option])
        try await editor.commit(SettingsB21Edit.shortcut(.toggleDock, taken))
        XCTAssertEqual(editor.context.shortcutPolicy(preferences: try XCTUnwrap(editor.snapshot).preferences).dockRegistration, .conflict)
        await app.composition.stop()
    }
    private func makeApp(_ profile: URL, cockpit: Bool = false) throws -> EngineDockMenuApplication {
        let config = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic",
                                               allowedEnvironment: [:], offline: true, readOnly: true)
        return EngineRowsEntry.make(configuration: config,
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en-US"]),
            createsNativePanels: false, cockpitEntryEnabled: cockpit, dockEnvironment: normalEntryTestEnvironment, activateSettings: {})
    }
    func testSET_9_05SavedChordRegistersAgainAfterRelaunch() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("set-9-05-relaunch-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let chord = ShortcutChord("K", modifiers: [.command, .option])
        let first = try makeApp(profile)
        first.shortcutRegistrar = JourneyShortcutRegistrar()
        await first.prepare()
        try await first.settingsHost.application.editor.commit(SettingsB21Edit.shortcut(.toggleDock, chord))
        await first.composition.stop()
        let registrar = JourneyShortcutRegistrar()
        let second = try makeApp(profile)
        second.shortcutRegistrar = registrar
        await second.prepare()
        XCTAssertEqual(registrar.registered[.toggleDock], chord, "a saved chord must work after a restart")
        await second.composition.stop()
    }
    func testOpenCockpitShortcutFollowsTheCockpitEntry() async throws {
        for cockpit in [false, true] {
            let profile = FileManager.default.temporaryDirectory.appendingPathComponent("set-9-05-cockpit-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: profile) }
            let chord = ShortcutChord("L", modifiers: [.command, .option])
            let registrar = JourneyShortcutRegistrar()
            let app = try makeApp(profile, cockpit: cockpit)
            app.shortcutRegistrar = registrar
            await app.prepare()
            let editor = app.settingsHost.application.editor
            let rows = try SettingsCatalogue.rows(preferences: try XCTUnwrap(editor.snapshot).preferences, context: editor.context)
            XCTAssertEqual(rows.first { $0.key == .openShortcut }?.availability, cockpit ? .available : .serviceUnavailable)
            XCTAssertEqual(rows.first { $0.key == .dockShortcut }?.availability, .available)
            try await editor.commit(SettingsB21Edit.shortcut(.openCockpit, chord))
            XCTAssertEqual(registrar.registered[.openCockpit], cockpit ? chord : nil)
            await app.composition.stop()
        }
    }
    func testQuotaResetNoticeHidesTheNameWhenProjectNamesAreOff() {
        XCTAssertEqual(EngineResetNotifier.quotaResetText(name: "Codex", english: true, showNames: true).1, "Codex: a new quota cycle was read.")
        XCTAssertEqual(EngineResetNotifier.quotaResetText(name: "Codex", english: true, showNames: false).1, "A new quota cycle was read.")
        XCTAssertFalse(EngineResetNotifier.quotaResetText(name: "Codex", english: false, showNames: false).1.contains("Codex"))
    }
    func testCarbonMappingCoversTheRecorderKeys() {
        XCTAssertEqual(CarbonShortcutRegistrar.keyCode("A"), 0)
        XCTAssertNotNil(CarbonShortcutRegistrar.keyCode("9"))
        XCTAssertNil(CarbonShortcutRegistrar.keyCode("é"))
        XCTAssertNotEqual(CarbonShortcutRegistrar.modifiers(.init("A", modifiers: [.command, .shift])), 0)
    }
}
