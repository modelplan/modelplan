// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanShell
import ModelPlanWire
@testable import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class I06FirstRunRelaunchJourneyTests: XCTestCase {
    private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }

    func testNormalEntryDoesNotPresentFirstRunAfterDoneAndStoreReopen() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("i06-relaunch-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
        let config = EngineClientConfiguration(executableURL: profile.appendingPathComponent("synthetic"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true)
        do {
            let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
            let app = EngineRowsEntry.make(configuration: config, settingsStore: store, createsNativePanels: false,
                dockEnvironment: normalEntryTestEnvironment,
                makeClient: { _, engineStore in SettingsJourneyClient(store: engineStore, rows: rows) }, activateSettings: {})
            app.loginServiceAdapter = CommunityLoginServiceAdapter(item: .init(isAppBundle: true, service: JourneyLoginService()))
            await app.prepare(); await app.composition.start()
            defer { app.composition.dock.close() }
            let before = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
            await app.restoreFirstRunIfNeeded()
            let window = try XCTUnwrap(NSApplication.shared.windows.first {
                !before.contains(ObjectIdentifier($0)) && $0.isVisible && $0.windowController is SettingsFirstRunController
            })
            defer { window.close() }
            let done = try XCTUnwrap(descendants(try XCTUnwrap(window.contentView)).first {
                $0.accessibilityIdentifier() == "firstRun.done"
            } as? NSButton)
            XCTAssertTrue(done.isEnabled); done.performClick(nil)
            var snapshot = await store.snapshot()
            for _ in 0..<200 where !snapshot.preferences.onboarding.completed {
                try await Task.sleep(for: .milliseconds(10)); snapshot = await store.snapshot()
            }
            XCTAssertTrue(snapshot.preferences.onboarding.completed)
            for _ in 0..<200 where window.isVisible { try await Task.sleep(for: .milliseconds(10)) }
            XCTAssertFalse(window.isVisible, "Done must close the real first-run window")
            await app.composition.stop()
        }
        do {
            let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
            let saved = await store.snapshot()
            XCTAssertTrue(saved.preferences.onboarding.completed)
            let app = EngineRowsEntry.make(configuration: config, settingsStore: store, createsNativePanels: false,
                dockEnvironment: normalEntryTestEnvironment,
                makeClient: { _, engineStore in SettingsJourneyClient(store: engineStore, rows: rows) }, activateSettings: {})
            app.loginServiceAdapter = CommunityLoginServiceAdapter(item: .init(isAppBundle: true, service: JourneyLoginService()))
            await app.prepare(); await app.composition.start()
            defer { app.composition.dock.close() }
            let before = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
            await app.restoreFirstRunIfNeeded()
            XCTAssertFalse(NSApplication.shared.windows.contains {
                !before.contains(ObjectIdentifier($0)) && $0.isVisible && $0.windowController is SettingsFirstRunController
            }, "A completed first run must not reopen from the restored store")
            await app.composition.stop()
        }
    }
}
