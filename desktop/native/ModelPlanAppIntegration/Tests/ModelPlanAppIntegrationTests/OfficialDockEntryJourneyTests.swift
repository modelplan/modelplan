// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanSettings
@_spi(DockResourceChecks) import ModelPlanDock
@testable import ModelPlanAppIntegration

@MainActor final class OfficialDockEntryJourneyTests: XCTestCase {
    func testNormalEmptyEntryUsesStudyQuestionMarkAndOpensSettings() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("official-dock-empty-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SettingsStore(url: root.appendingPathComponent("settings.json"))
        try await store.update { $0.language = .english; $0.autoHide = false }
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true), settingsStore: store, createsNativePanels: false)
        await app.prepare(); app.allowDockPresentation()
        let dock = app.composition.dock; defer { dock.close() }
        XCTAssertNil(dock.lastAppearanceError)
        let skin = try XCTUnwrap(dock.dockView.presentedSkinForChecks)
        let empty = try XCTUnwrap(skin.stations.first { $0.placeholderLabel != nil })
        XCTAssertEqual(empty.placeholderLabel, "?"); XCTAssertNil(empty.overflowCount)
        XCTAssertNotNil(empty.placeholderStyle); XCTAssertNotNil(dock.dockView.emptyStationRectForChecks)
        let children = try XCTUnwrap(dock.dockView.accessibilityChildren() as? [NSAccessibilityElement])
        let element = try XCTUnwrap(children.first { $0.accessibilityIdentifier() == "dock.empty" })
        XCTAssertEqual(element.accessibilityLabel(), "No subscriptions found")
        XCTAssertEqual(element.accessibilityHelp(), "Open Settings to connect a subscription")
        var opened = 0; dock.showSettings = { opened += 1 }
        XCTAssertTrue(element.accessibilityPerformPress()); XCTAssertEqual(opened, 1)
        // Exercise the real pointer dispatcher without fabricating a window event or bypassing the host gate.
        let rect = try XCTUnwrap(dock.dockView.emptyStationRectForChecks)
        XCTAssertFalse(try XCTUnwrap(dock.dockView.registeredDragRegions(excluding: [])).contains(CGPoint(x: rect.midX, y: rect.midY)))
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertTrue(dock.dockView.performPointerPress(atLocal: CGPoint(x: rect.midX, y: rect.midY)))
        XCTAssertEqual(opened, 2)
        dock.close()
        XCTAssertFalse(element.accessibilityPerformPress()); XCTAssertEqual(opened, 2)
    }

    func testNormalEngineRowsEntryPresentsOfficialDockHull() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("official-dock-entry-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = EngineRowsEntry.make(
            configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true),
            settingsStore: try SettingsStore(url: root.appendingPathComponent("settings.json")), createsNativePanels: false)
        await app.prepare()
        defer { app.composition.dock.close() }
        XCTAssertNil(app.composition.dock.lastAppearanceError, "Official appearance failed: \(String(describing: app.composition.dock.lastAppearanceError))")
        XCTAssertNotNil(app.composition.dock.dockView.registeredHullPath,
                        "The normal engine-rows entry must present the official Dock hull")
        XCTAssertNotNil(app.composition.dock.dockView.registeredMovePreviewImage,
                        "The official material must be available from the real production host")
        XCTAssertNil(app.composition.dock.nativePanel)
    }
}
