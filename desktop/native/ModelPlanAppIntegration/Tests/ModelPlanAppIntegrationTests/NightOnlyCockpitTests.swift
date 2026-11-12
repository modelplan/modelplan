// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
@testable import ModelPlanCockpitWeb
@testable import ModelPlanAppIntegration

/// CKP-SHELL-40 (owner D205): v1 is night-only. Through the normal entry (the console owner adopting the saved
/// settings) the cockpit theme is night in light mode and for a saved day theme; the one `dayCockpit` switch
/// brings the day paths back for v1.1.
final class NightOnlyCockpitTests: XCTestCase {
    private func ownerWithSettings(night label: String, theme: SettingsTheme) async throws -> (CockpitConsoleOwner, SettingsSnapshot) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("night-only-\(label)-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root)
        _ = try await store.update { $0.theme = theme }
        let owner = await MainActor.run { CockpitConsoleOwner(bundle: root, settingsStore: store) }
        return (owner, await store.snapshot())
    }

    @MainActor private func withLightMode<T>(_ body: () async throws -> T) async rethrows -> T {
        let app = NSApplication.shared, saved = app.appearance
        app.appearance = NSAppearance(named: .aqua)
        defer { app.appearance = saved }
        return try await body()
    }

    func testDayCockpitIsOffByDefault() { XCTAssertFalse(CockpitDayPolicy.dayCockpit) }

    @MainActor func testLightModeSystemThemeStillRendersNightCockpit() async throws {
        let (owner, snapshot) = try await ownerWithSettings(night: "system", theme: .system)
        await withLightMode {
            owner.adoptAppearance(snapshot, applied: nil)
            XCTAssertEqual(owner.appearance.theme, .night)
        }
    }

    @MainActor func testSavedDayThemeStillRendersNightCockpit() async throws {
        let (owner, snapshot) = try await ownerWithSettings(night: "savedday", theme: .day)
        owner.adoptAppearance(snapshot, applied: nil)
        XCTAssertEqual(owner.appearance.theme, .night)
    }

    @MainActor func testDayCockpitSwitchOnRestoresDayInLightMode() async throws {
        let (owner, snapshot) = try await ownerWithSettings(night: "flagon", theme: .system)
        CockpitDayPolicy.dayCockpit = true
        defer { CockpitDayPolicy.dayCockpit = false }
        await withLightMode {
            owner.adoptAppearance(snapshot, applied: nil)
            XCTAssertEqual(owner.appearance.theme, .day)
        }
    }

    func testPolicyResolvesBothWays() {
        XCTAssertEqual(CockpitDayPolicy.resolve(.day), .night)
        XCTAssertTrue(CockpitDayPolicy.resolveField(dark: false))
        CockpitDayPolicy.dayCockpit = true
        defer { CockpitDayPolicy.dayCockpit = false }
        XCTAssertEqual(CockpitDayPolicy.resolve(.day), .day)
        XCTAssertFalse(CockpitDayPolicy.resolveField(dark: false))
    }
}
