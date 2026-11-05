// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanInstruments
import ModelPlanWire
@testable import ModelPlanAppIntegration

@MainActor final class G312StatusHelpJourneyTests: XCTestCase {
    private func descendants(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap(descendants)
    }

    func testS06StatusMenuEscapeReturnsFocusAfterTheRealHelpMap() async throws {
        // Do not construct a window until the normal entry can isolate its notification ledger.
        throw XCTSkip("S-06 SEAM-NEEDED: EngineRowsEntry.isolatedResetNotificationLedger")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("g312-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        _ = try await store.update { $0.onboarding.next(in: .task65) }
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true),
            settingsStore: store, createsNativePanels: true, dockEnvironment: normalEntryTestEnvironment,
            makeClient: { _, engineStore in SettingsJourneyClient(store: engineStore, rows: rows) }, activateSettings: {})
        _ = NSApplication.shared
        app.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        defer {
            app.composition.dock.close()
            app.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
        }
        await app.prepare()
        app.allowDockPresentation()
        await app.composition.start()
        for _ in 0..<200 where app.composition.dock.currentDockHelpSurface == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertNotNil(app.composition.dock.currentDockHelpSurface)
        let item = try XCTUnwrap(app.liveStatusMenu?.items.first { $0.accessibilityIdentifier() == "status.help" })
        XCTAssertTrue(item.isEnabled)
        _ = try XCTUnwrap(item.target as? NSObject).perform(try XCTUnwrap(item.action), with: item)
        let requestID = try XCTUnwrap(app.statusHelpRequestID)
        let layers = NSApplication.shared.windows.filter { $0.isVisible }.flatMap { window in
            window.contentView.map(descendants) ?? []
        }.compactMap { $0 as? HelpUILayerView }
        let map = try XCTUnwrap(layers.first { $0.input?.map.mode == .latched })
        XCTAssertEqual(app.statusHelpRequestID, requestID)
        map.onAction?(.dismissMap(reason: .escape, returnFocusID: nil))
        for _ in 0..<100 where app.statusHelpRequestID != nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertNil(app.statusHelpRequestID, "The same real status-menu request must be retired")
        XCTAssertTrue(app.statusHelpButtonFocused, "Escape must restore focus to the status item")
        await app.composition.stop()
    }
}
