// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
import ModelPlanEngineClient
@testable import ModelPlanAppIntegration

@MainActor final class StatusHelpMenuTests: XCTestCase {
    private func application(language: String = "en") async throws -> EngineDockMenuApplication {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("status-help-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: [language])
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true), settingsStore: store, createsNativePanels: false, activateSettings: {})
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
    #if MODELPLAN_DOCK_NATIVE_JOURNEY
    func testNativeJourneyCleanupRetiresTheStatusMenu() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("status-teardown-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: store, createsNativePanels: false,
            dockEnvironment: normalEntryTestEnvironment, activateSettings: {})
        await app.prepare()
        app.renderMenu()
        let retired = try XCTUnwrap(app.liveStatusMenu)
        XCTAssertFalse(retired.items.isEmpty)
        await app.stopNativeDockJourney()
        XCTAssertNil(app.liveStatusMenu)
        XCTAssertTrue(retired.items.isEmpty)
    }

    func testS14NormalLaunchDoesNotOverrideSystemAppearance() async throws {
        let application = NSApplication.shared
        let previousAppearance = application.appearance
        let previousPolicy = application.activationPolicy()
        defer {
            application.appearance = previousAppearance
            application.setActivationPolicy(previousPolicy)
        }
        // Restore inheritance within the test process only.
        application.appearance = nil
        let systemDark = SettingsWindowController.systemEnvironment().darkAppearance
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("system-appearance-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: store,
            createsNativePanels: false, bundleURL: root.appendingPathComponent("Synthetic.app"),
            dockEnvironment: normalEntryTestEnvironment, activateSettings: {})
        app.setActivityPaused(true)
        app.applicationDidFinishLaunching(.init(name: NSApplication.didFinishLaunchingNotification, object: application))
        XCTAssertNil(application.appearance, "The normal launch must inherit rather than pin an appearance")
        XCTAssertEqual(SettingsWindowController.systemEnvironment().darkAppearance, systemDark)
        await app.stopNativeDockJourney()
    }
    #endif

}
