// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class I05FirstRunLoginJourneyTests: XCTestCase {
    private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
    func testNormalFirstRunDispatchesExplicitLoginChoice() async throws {
        for wantsLogin in [true, false] {
            let profile = FileManager.default.temporaryDirectory.appendingPathComponent("i05-login-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: profile) }
            let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
            let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
            let config = EngineClientConfiguration(executableURL: profile.appendingPathComponent("synthetic"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true)
            let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
            let app = EngineRowsEntry.make(configuration: config, settingsStore: store, createsNativePanels: false,
                dockEnvironment: normalEntryTestEnvironment,
                makeClient: { _, engineStore in SettingsJourneyClient(store: engineStore, rows: rows) }, activateSettings: {})
            let service = JourneyLoginService()
            app.loginServiceAdapter = CommunityLoginServiceAdapter(item: .init(isAppBundle: true, service: service))
            await app.prepare(); await app.composition.start()
            defer { app.composition.dock.close() }
            let before = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
            await app.restoreFirstRunIfNeeded()
            let window = try XCTUnwrap(NSApplication.shared.windows.first { !before.contains(ObjectIdentifier($0)) && $0.isVisible })
            defer { window.close() }
            let views = descendants(try XCTUnwrap(window.contentView))
            let login = try XCTUnwrap(views.first { $0.accessibilityIdentifier() == "firstRun.login" } as? NSButton)
            XCTAssertTrue(login.isEnabled); XCTAssertEqual(login.state, .on)
            if !wantsLogin { login.performClick(nil) }
            XCTAssertEqual(login.state == .on, wantsLogin)
            let done = try XCTUnwrap(views.first { $0.accessibilityIdentifier() == "firstRun.done" } as? NSButton)
            XCTAssertTrue(done.isEnabled); done.performClick(nil)
            var saved = await store.snapshot()
            for _ in 0..<200 where !saved.preferences.onboarding.completed {
                try await Task.sleep(for: .milliseconds(10)); saved = await store.snapshot()
            }
            XCTAssertTrue(saved.preferences.onboarding.completed)
            XCTAssertEqual(saved.preferences.openAtLogin, wantsLogin)
            if wantsLogin {
                XCTExpectFailure("I-05 product-missing: normal first-run completion discards the login request") {
                    XCTAssertEqual(service.registrations, 1)
                }
            } else { XCTAssertEqual(service.registrations, 0) }
            await app.composition.stop()
        }
    }
}
