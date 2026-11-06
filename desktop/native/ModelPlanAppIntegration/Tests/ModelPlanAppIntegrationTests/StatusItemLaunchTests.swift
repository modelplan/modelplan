// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanAppIntegration

/// G3-22: the menu bar item must never be blank. Uses the window server (status bar), so GUI leg.
@MainActor final class StatusItemLaunchTests: XCTestCase {
    private func application() async throws -> EngineDockMenuApplication {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("status-item-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true), settingsStore: store, createsNativePanels: false, activateSettings: {})
        await app.prepare()
        return app
    }

    func testLaunchedStatusButtonShowsTheTemplateImageOrAVisibleTitle() async throws {
        let app = try await application()
        defer { app.removeStatusItemForTesting(); app.composition.dock.close() }
        // The same install step applicationDidFinishLaunching runs, without starting the engine lifecycle.
        app.installStatusItem()
        let button = try XCTUnwrap(app.statusButtonForTesting)
        if let image = button.image {
            XCTAssertTrue(image.isTemplate)
            XCTAssertGreaterThan(image.size.width, 0); XCTAssertGreaterThan(image.size.height, 0)
            XCTAssertFalse(image.representations.isEmpty)
        } else {
            XCTAssertEqual(button.title, EngineDockMenuApplication.statusFallbackTitle)
        }
        XCTAssertTrue(button.image != nil || !button.title.isEmpty, "The status item must never be zero-width")
        XCTAssertNotNil(button.image, "Template image lookup: \(CommunityMenuBarResources.lastLookup)")
    }

    func testMissingTemplateImageFallsBackToAVisibleTitle() async throws {
        let app = try await application()
        defer { app.composition.dock.close() }
        let button = NSButton(title: "", target: nil, action: nil)
        EngineDockMenuApplication.configureStatusButton(button, image: nil, barThickness: 22)
        app.applyStatusContent(to: button, detail: "")
        XCTAssertNil(button.image)
        let presented = app.composition.menuPresentation.title
        XCTAssertEqual(button.title, presented.isEmpty ? EngineDockMenuApplication.statusFallbackTitle : presented)
        XCTAssertFalse(button.title.isEmpty)
    }

    func testPackagedLookupResolvesFromTheAppResourceDirectoryAtAnyInstallPath() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("status-install-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        for parent in ["Applications", "Downloads/nested folder"] {
            let app = root.appendingPathComponent(parent).appendingPathComponent("ModelPlan Community.app")
            let resources = app.appendingPathComponent("Contents/Resources")
            try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
            let main = try XCTUnwrap(Bundle(url: app))
            let resolved = try XCTUnwrap(CommunityMenuBarResources.packagedBundleURL(main: main))
            XCTAssertEqual(resolved.lastPathComponent, CommunityMenuBarResources.bundleName)
            XCTAssertEqual(resolved.deletingLastPathComponent().resolvingSymlinksInPath().path, resources.resolvingSymlinksInPath().path)
            XCTAssertNil(CommunityMenuBarResources.templateImage(appURL: app))
            XCTAssertTrue(CommunityMenuBarResources.lastLookup.hasPrefix("missing"))
            try FileManager.default.copyItem(at: CommunityMenuBarResources.buildBundleURL, to: resources.appendingPathComponent(CommunityMenuBarResources.bundleName))
            XCTAssertTrue(try XCTUnwrap(CommunityMenuBarResources.templateImage(appURL: app)).isTemplate)
            XCTAssertTrue(CommunityMenuBarResources.lastLookup.hasPrefix("loaded"))
        }
        XCTAssertNil(CommunityMenuBarResources.packagedBundleURL(main: try XCTUnwrap(Bundle(url: root))), "Outside an .app the build bundle is used")
    }
}
