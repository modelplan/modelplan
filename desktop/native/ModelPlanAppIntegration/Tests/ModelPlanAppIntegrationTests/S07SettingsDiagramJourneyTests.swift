// SPDX-License-Identifier: MIT
import AppKit
import QuartzCore
import XCTest
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class S07SettingsDiagramJourneyTests: XCTestCase {
    func testNormalSettingsDiagramHoverRespectsReduceMotionWithoutLayoutShift() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("s07-diagram-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
        let config = EngineClientConfiguration(executableURL: profile.appendingPathComponent("synthetic"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true)
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        let app = EngineRowsEntry.make(configuration: config, settingsStore: store, createsNativePanels: false,
            dockEnvironment: normalEntryTestEnvironment,
            makeClient: { _, engineStore in SettingsJourneyClient(store: engineStore, rows: rows) }, activateSettings: {})
        await app.prepare()
        defer { app.composition.dock.close() }
        let before = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
        await app.settingsHost.present(paneID: "dock", origin: .userInitiated)
        let window = try XCTUnwrap(NSApplication.shared.windows.first { !before.contains(ObjectIdentifier($0)) && $0.isVisible })
        defer { window.close() }
        let controller = try XCTUnwrap(window.windowController as? SettingsWindowController)
        var environment = controller.editor.environment
        environment.reduceMotion = false
        controller.editor.update(environment: environment)
        controller.selectPane("dock")
        let diagram = try XCTUnwrap(controller.diagram(key: .showPercentages))
        let row = try XCTUnwrap(diagram.superview?.superview as? SettingsNativeRow)
        window.contentView?.layoutSubtreeIfNeeded()
        let rowFrame = row.frame, diagramFrame = diagram.frame
        let event = try XCTUnwrap(NSEvent.enterExitEvent(with: .mouseEntered, location: .zero,
            modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil,
            eventNumber: 1, trackingNumber: 0, userData: nil))
        row.mouseEntered(with: event)
        let animation = try XCTUnwrap(diagram.layer?.animation(forKey: "settings.lineMovement"))
        XCTAssertEqual(animation.repeatCount, 0, "The explanation diagram animates once")
        XCTAssertEqual(animation.duration, SettingsDiagramPolicy(reduceMotion: false).duration, accuracy: 0.001)
        XCTAssertEqual(row.frame, rowFrame); XCTAssertEqual(diagram.frame, diagramFrame)

        controller.selectPane("appearance")
        let popup = try XCTUnwrap(controller.choice(key: .motion))
        let index = try XCTUnwrap(popup.itemArray.firstIndex { ($0.representedObject as? String) == "on" })
        popup.selectItem(at: index)
        XCTAssertTrue(NSApplication.shared.sendAction(try XCTUnwrap(popup.action), to: popup.target, from: popup))
        await controller.waitForPendingSave()
        controller.selectPane("dock")
        let reducedDiagram = try XCTUnwrap(controller.diagram(key: .showPercentages))
        let reducedRow = try XCTUnwrap(reducedDiagram.superview?.superview as? SettingsNativeRow)
        window.contentView?.layoutSubtreeIfNeeded()
        let reducedRowFrame = reducedRow.frame, reducedFrame = reducedDiagram.frame
        XCTAssertTrue(reducedDiagram.reduceMotion)
        reducedRow.mouseEntered(with: event)
        XCTAssertNil(reducedDiagram.layer?.animation(forKey: "settings.lineMovement"))
        XCTAssertEqual(reducedRow.frame, reducedRowFrame); XCTAssertEqual(reducedDiagram.frame, reducedFrame)
        await app.composition.stop()
    }
}
