// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor private final class JourneyConsole: EngineRowsConsoleSurface {
    var opens = 0
    func show() { opens += 1 }
    func render() {}
    func hide() {}
}

@MainActor final class CockpitEntryJourneyTests: XCTestCase {
    func testV1KeepsLegacyOpeningPreferencesButHidesHoldAndCountdownRows() {
        XCTAssertFalse(SettingsCatalogue.visibleInV1(.opening))
        XCTAssertFalse(SettingsCatalogue.visibleInV1(.countdown))
        XCTAssertTrue(SettingsCatalogue.visibleInV1(.motion))
        XCTAssertTrue(SettingsCatalogue.visibleInV1(.language))
    }
    func testNormalEntryMenuAndDockOpenTheSameCockpit() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("s6-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let surface = JourneyConsole()
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true),
            settingsStore: try SettingsStore(url: root.appendingPathComponent("settings.json")), createsNativePanels: false,
            makeConsole: { _ in surface }, activateSettings: {})
        await app.prepare()
        let menu = try XCTUnwrap(app.liveStatusMenu)
        let open = try XCTUnwrap(menu.items.firstIndex { $0.title == EngineRowsText.cockpitMenu.value(app.composition.latestSettings?.effective.language ?? .english) })
        menu.performActionForItem(at: open)
        XCTAssertEqual(surface.opens, 1)
        app.composition.dock.setPresentationAllowed(true)
        let dockMenu = app.composition.dock.menu()
        let dockOpen = try XCTUnwrap(dockMenu.items.firstIndex { $0.title == EngineRowsText.cockpitMenu.value(app.composition.latestSettings?.effective.language ?? .english) })
        dockMenu.performActionForItem(at: dockOpen)
        XCTAssertEqual(surface.opens, 2)
        app.composition.dock.setPresentationAllowed(false)
    }
}
