// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanSettings

/// MOT-2.3-03 (Settings leg) and SET-9-24 through the real window. With Reduce Motion a diagram takes
/// its end state at once; otherwise focus and a value change each play it once, for 400 ms.
@MainActor final class SettingsDiagramReducedMotionTests: XCTestCase {
    private func store() throws -> SettingsStore {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("settings-diagram-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return try SettingsStore(url: directory.appendingPathComponent("preferences.json"))
    }

    func testFocusAndValueChangeEachPlayOnceWithoutLoopingOrMovingLayout() async throws {
        let controller = SettingsWindowController(editor: SettingsEditor(store: try store()), environmentProvider: { .init() })
        await controller.prepare(); controller.selectPane("dock")
        let diagram = try XCTUnwrap(controller.diagram(key: .size)), frame = diagram.frame
        let popup = try XCTUnwrap(controller.choice(key: .size)), window = try XCTUnwrap(controller.window)
        func assertPlayedOnce(_ trigger: String) throws {
            let animation = try XCTUnwrap(diagram.layer?.animation(forKey: "settings.lineMovement"), trigger)
            XCTAssertEqual(animation.duration, 0.4, trigger); XCTAssertEqual(animation.repeatCount, 0, trigger)
            XCTAssertTrue(animation.isRemovedOnCompletion, trigger); XCTAssertEqual(diagram.frame, frame, trigger)
        }
        XCTAssertTrue(window.makeFirstResponder(popup))
        try assertPlayedOnce("focus")
        diagram.stop()
        diagram.apply(.size(.large), reduceMotion: false, animate: true)
        try assertPlayedOnce("value change")
        diagram.stop()
        diagram.apply(.size(.large), reduceMotion: false, animate: true)
        XCTAssertNil(diagram.layer?.animation(forKey: "settings.lineMovement"), "an unchanged value does not replay")
        controller.close()
    }

    func testReducedMotionDiagramTakesItsEndStateWithoutAnimating() async throws {
        let store = try store()
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
