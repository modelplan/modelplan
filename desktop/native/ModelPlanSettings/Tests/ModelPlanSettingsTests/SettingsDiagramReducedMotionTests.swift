// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanSettings

/// MOT-2.3-03, Settings leg, through the real window: with Reduce Motion a diagram takes its end
/// state at once. A hover or a value change starts nothing, and the drawing still updates.
@MainActor final class SettingsDiagramReducedMotionTests: XCTestCase {
    func testReducedMotionDiagramTakesItsEndStateWithoutAnimating() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("settings-diagram-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = try SettingsStore(url: directory.appendingPathComponent("preferences.json"))
        var environment = SettingsEnvironment(); environment.reduceMotion = true
        let controller = SettingsWindowController(editor: SettingsEditor(store: store), environmentProvider: { environment })
        await controller.prepare(); controller.selectPane("dock")
        let diagram = try XCTUnwrap(controller.diagram(key: .size))
        let frame = diagram.frame
        XCTAssertTrue(diagram.reduceMotion)
        diagram.play()
        XCTAssertNil(diagram.layer?.animation(forKey: "settings.lineMovement"), "a hover or focus must not animate")
        diagram.apply(.size(.large), reduceMotion: true, animate: true)
        XCTAssertEqual(diagram.input, .size(.large))
        XCTAssertNil(diagram.layer?.animation(forKey: "settings.lineMovement"), "a value change must not animate")
        XCTAssertEqual(diagram.frame, frame)
        environment.reduceMotion = false; controller.refreshEnvironment()
        diagram.play()
        XCTAssertEqual(diagram.layer?.animation(forKey: "settings.lineMovement")?.duration, 0.4)
        controller.close()
    }
}
