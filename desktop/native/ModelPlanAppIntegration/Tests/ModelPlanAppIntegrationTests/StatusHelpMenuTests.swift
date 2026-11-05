// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
import ModelPlanEngineClient
@_spi(DockResourceChecks) import ModelPlanDock
@testable import ModelPlanAppIntegration

@MainActor final class StatusHelpMenuTests: XCTestCase {
    private func application(language: String = "en") async throws -> EngineDockMenuApplication {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("status-help-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: [language])
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true), settingsStore: store, createsNativePanels: false, dockEnvironment: normalEntryTestEnvironment, activateSettings: {})
        await app.prepare()
        return app
    }
    private func invoke(_ title: String, on app: EngineDockMenuApplication) throws {
        let item = try XCTUnwrap(app.liveStatusMenu?.items.first { $0.title == title })
        XCTAssertTrue(item.isEnabled)
        _ = try XCTUnwrap(item.target as? NSObject).perform(try XCTUnwrap(item.action), with: item)
    }
    func testShowFeedbackNeverDecoratesTheStatusItemTitle() async throws {
        let app = try await application()
        defer { app.composition.dock.close() }
        let expected = app.composition.menuPresentation.title
        // A concurrent preference writer makes the explicit Show request stale.
        _ = try await app.foundationStore.update { $0.showDock = false; $0.dockEdge = .left }
        try invoke("Show Quota Widget", on: app)
        let feedback = "Settings changed. Choose Show Quota Widget again."
        for _ in 0..<250 {
            if app.liveStatusMenu?.items.contains(where: { $0.title == feedback }) == true { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertTrue(app.liveStatusMenu?.items.contains(where: { $0.title == feedback }) == true)
        let button = NSButton(), icon = NSImage(size: .init(width: 16, height: 16))
        button.image = icon
        app.applyStatusContent(to: button, detail: feedback)
        XCTAssertTrue(button.image === icon, "Feedback must preserve the status icon")
        XCTAssertEqual(button.title, expected)
        XCTAssertEqual(button.title, app.composition.menuPresentation.title)
        XCTAssertFalse(button.title.contains("!"))
        XCTAssertEqual(button.toolTip, feedback)
        let saved = await app.foundationStore.snapshot()
        XCTAssertFalse(saved.preferences.showDock, "Failed Show must not pretend to reveal the widget")
    }
    func testS06HelpHasAStableMenuActionIdentifier() async throws {
        let app = try await application()
        defer { app.composition.dock.close() }
        let help = try XCTUnwrap(app.liveStatusMenu?.items.first { $0.title == "Help…" })
        XCTAssertEqual(help.accessibilityIdentifier(), "status.help")
        app.requestHelpMap = { true }
        try invoke("Help…", on: app)
        let request = try XCTUnwrap(app.statusHelpRequestID)
        app.statusHelpDidDismiss(UUID())
        XCTAssertEqual(app.statusHelpRequestID, request)
        app.statusHelpDidDismiss(request)
        XCTAssertNil(app.statusHelpRequestID)
        XCTAssertFalse(app.statusHelpButtonFocused, "A detached view cannot report native status focus")
    }

    func testS10NormalEntryRegistersThePaintedGripAsADragTarget() async throws {
        let app = try await application()
        defer { app.composition.dock.close() }
        app.allowDockPresentation()
        let view = app.composition.dock.dockView
        let regions = try XCTUnwrap(view.registeredDragRegions(excluding: []))
        let grip = try XCTUnwrap(regions.grips.first, "The painted grip needs an explicit event target")
        let point = CGPoint(x: grip.boundingBox.midX, y: grip.boundingBox.midY)
        XCTAssertTrue(view.isPainted(atLocal: point))
        XCTAssertTrue(view.backgroundDragDelegate?.backgroundCanDrag(local: point) == true)
        let key = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: 0, context: nil, characters: "\t",
            charactersIgnoringModifiers: "\t", isARepeat: false, keyCode: 48))
        view.keyDown(with: key)
        XCTAssertEqual(view.focusedGripIndex, 0)
        XCTAssertEqual(view.emphasizedGripFrameForChecks, grip.boundingBox)
        _ = view.resignFirstResponder()
        XCTAssertNil(view.emphasizedGripFrameForChecks)
    }

    func testHelpMenuRequestsExistingMapAndReportsFailureInBothLanguages() async throws {
        for (language, title, failure) in [("en", "Help…", "Help unavailable. Try again when the Quota Widget is visible."), ("zh-CN", "说明…", "说明暂不可用，请在额度挂件可见时重试。")] {
            let app = try await application(language: language)
            defer { app.composition.dock.close() }
            var requests = 0, succeeds = true
            app.requestHelpMap = { requests += 1; return succeeds }
            try invoke(title, on: app)
            XCTAssertEqual(requests, 1)
            succeeds = false
            try invoke(title, on: app)
            XCTAssertEqual(requests, 2)
            XCTAssertTrue(app.liveStatusMenu?.items.contains(where: { $0.title == failure }) == true)
            succeeds = true
            try invoke(title, on: app)
            XCTAssertEqual(requests, 3)
            XCTAssertFalse(app.liveStatusMenu?.items.contains(where: { $0.title == failure }) == true)
        }
    }
}
