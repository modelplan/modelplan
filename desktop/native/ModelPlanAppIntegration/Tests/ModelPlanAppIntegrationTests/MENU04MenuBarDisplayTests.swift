// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanDock
import ModelPlanEngineClient
@testable import ModelPlanAppIntegration
import ModelPlanSettings

/// MENU-03 / MENU-04 and SET-9-05: the menu-bar display setting reaches the status item text.
@MainActor final class MENU04MenuBarDisplayTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func input(_ id: String, five: Double, week: Double) -> DockInstrumentInput {
        var input = DockInstrumentInput(id: id, name: id, windows: [
            .init(id: id + ".5h", period: .fiveHour, label: "5h", remainingPercent: five, resetsAt: now.addingTimeInterval(3600), durationSeconds: 18_000),
            .init(id: id + ".week", period: .week, label: "week", remainingPercent: week, resetsAt: now.addingTimeInterval(86_400), durationSeconds: 604_800)])
        input.dataState = .fresh
        return input
    }
    func testMENU_04EachDisplayChoice() {
        var preferences = SettingsPreferences()
        let inputs = [input("a", five: 60, week: 70), input("b", five: 9, week: 15)]
        preferences.menuDisplay = .icon
        XCTAssertEqual(EngineMenuBarTitle.make(inputs: inputs, preferences: preferences, now: now), "")
        preferences.menuDisplay = .tightest
        XCTAssertEqual(EngineMenuBarTitle.make(inputs: inputs, preferences: preferences, now: now), "9%")
        preferences.menuDisplay = .twoWindows; preferences.language = .chinese
        XCTAssertEqual(EngineMenuBarTitle.make(inputs: inputs, preferences: preferences, now: now), "5h 9% 周 15%")
        preferences.language = .english
        XCTAssertEqual(EngineMenuBarTitle.make(inputs: inputs, preferences: preferences, now: now), "5h 9% wk 15%")
    }
    func testMENU_03NoReadingLeavesTheIconAlone() {
        var preferences = SettingsPreferences(); preferences.menuDisplay = .tightest
        XCTAssertEqual(EngineMenuBarTitle.make(inputs: [], preferences: preferences, now: now), "")
    }
    func testSET_9_05NormalEntryEnablesLanguageAndMenuDisplay() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("menu-04-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let config = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic",
                                               allowedEnvironment: [:], offline: true, readOnly: true)
        let app = EngineRowsEntry.make(configuration: config,
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en-US"]),
            createsNativePanels: false, dockEnvironment: normalEntryTestEnvironment, activateSettings: {})
        await app.prepare()
        let editor = app.settingsHost.application.editor
        let rows = try SettingsCatalogue.rows(preferences: try XCTUnwrap(editor.snapshot).preferences, context: editor.context)
        for key in [SettingKey.language, .menuDisplay] {
            XCTAssertEqual(rows.first { $0.key == key }?.availability, .available, "not usable: \(key)")
        }
        XCTAssertEqual(rows.first { $0.key == .projectNames }?.availability, .available, "the cockpit reads this through applySettings")
        await app.composition.stop()
    }
}
