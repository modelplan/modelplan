// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
import ModelPlanCommunityHost
@testable import ModelPlanAppIntegration

@MainActor final class CommunitySettingsSessionTests: XCTestCase {
    private func application() throws -> SettingsApplicationCoordinator {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("community-settings-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return SettingsApplicationCoordinator(store: try SettingsStore(url: directory.appendingPathComponent("preferences.json"))) { _ in }
    }
    func testRootIntegrationRestoresTheSameEditorWithoutAWindowOrActivation() async throws {
        let app = try application(); var created = 0, activated = 0
        let session: any CommunitySettingsIntegration = CommunitySettingsSession(application: app, canPresent: { true },
            environment: { .init() }, activate: { activated += 1 }, makeSurface: { _ in created += 1; return TestSettingsSurface() })
        await session.restorePreferences()
        XCTAssertEqual(app.latest?.reason, .restore); XCTAssertEqual(app.latest?.snapshot.revision, 0)
        XCTAssertEqual(created, 0); XCTAssertEqual(activated, 0)
    }
    func testRootMenuUsesSharedEditorUserActivationAndLifecycleSuspension() async throws {
        let app = try application(), surface = TestSettingsSurface(), shown = expectation(description: "shared menu opened")
        var activated = 0
        surface.onShow = { shown.fulfill() }
        let session: any CommunitySettingsIntegration = CommunitySettingsSession(application: app, canPresent: { true },
            environment: { .init() }, activate: { activated += 1 }, makeSurface: { editor in XCTAssertTrue(editor === app.editor); return surface })
        let item = session.settingsMenuItem
        let target = try XCTUnwrap(item.target as? NSObject)
        _ = target.perform(try XCTUnwrap(item.action), with: item)
        await fulfillment(of: [shown], timeout: 2)
        session.suspend()
        XCTAssertEqual(activated, 1); XCTAssertEqual(surface.shown.count, 1); XCTAssertEqual(surface.hidden, 1)
    }
}
