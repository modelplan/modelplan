// SPDX-License-Identifier: MIT
#if MODELPLAN_DOCK_HELP_NATIVE_JOURNEY
import AppKit
import Foundation
import XCTest
import ModelPlanDock
@testable import ModelPlanAppIntegration

@MainActor final class DockHelpNativePanelJourneyTests: XCTestCase {
    func testS07NativeHostPublishesFocusOnceAndWithdrawsIt() async throws {
        _ = NSApplication.shared
        let screen = try XCTUnwrap(NSScreen.main)
        let display = DockDisplayArea(id: "test-display", frame: screen.frame, visibleFrame: screen.visibleFrame)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dock-help-native-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-02T00:00:00Z"))
        let snapshot = try HostPairedProjectionTests.rows(weekly: 75)
        let outside = CGPoint(x: display.visibleFrame.midX, y: display.visibleFrame.midY)
        var pointer = outside
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: true,
            dockEnvironment: { .init(displays: [display], layouts: [], primaryDisplayID: display.id,
                pointer: pointer) },
            deadlineNow: { wall },
            makeClient: { _, store in EntrySyntheticClient(store: store, rows: snapshot) },
            isolatedResetNotificationLedger: root.appendingPathComponent("test-notifications.json"), activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        let dock = app.composition.dock
        var changes: [DockHelpInteraction?] = []
        dock.dockHelpInteractionDidChange = { changes.append($0) }
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        let deadline = ContinuousClock.now + .seconds(2)
        while dock.currentDockHelpSurface == nil, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        let panel = try XCTUnwrap(dock.nativePanel)
        XCTAssertTrue(panel.isVisible)
        let surface = try XCTUnwrap(dock.currentDockHelpSurface)
        let view = dock.dockView
        XCTAssertTrue(view.window === panel)
        let nodes = (view.accessibilityChildren() ?? []).compactMap { $0 as? NSAccessibilityElement }
        let id = "aaaaaaaaaaaaaaaa"
        let ring = try XCTUnwrap(surface.mapAnchors.first { $0.id == "dock.rings." + id })
        let grip = try XCTUnwrap(surface.mapAnchors.first { $0.id == "dock.grip.0" })
        let subscription = try XCTUnwrap(nodes.first { $0.accessibilityIdentifier() == "dock.subscription." + id })
        let gripNode = try XCTUnwrap(nodes.first { $0.accessibilityIdentifier() == grip.id })

        let ringFocus = DockHelpInteraction(anchor: ring, source: .keyboard)
        let gripFocus = DockHelpInteraction(anchor: grip, source: .keyboard)
        let gripPointer = DockHelpInteraction(anchor: grip, source: .pointer)
        XCTAssertNil(dock.currentDockHelpInteraction)
        XCTAssertTrue(changes.isEmpty)
        func movePointer(to point: CGPoint) {
            pointer = point
            dock.pointerInputView.reportAgain()
            dock.pointerInputView.sampleNow()
        }
        movePointer(to: CGPoint(x: grip.rect.midX, y: grip.rect.midY))
        XCTAssertEqual(changes, [gripPointer])
        subscription.setAccessibilityFocused(true)
        subscription.setAccessibilityFocused(true)
        XCTAssertEqual(changes, [gripPointer, ringFocus])
        XCTAssertEqual(dock.currentDockHelpInteraction, ringFocus)

        movePointer(to: outside)
        XCTAssertEqual(changes, [gripPointer, ringFocus], "Keyboard focus takes precedence over a pointer change")
        subscription.setAccessibilityFocused(false)
        XCTAssertEqual(changes, [gripPointer, ringFocus, nil])
        gripNode.setAccessibilityFocused(true)
        gripNode.setAccessibilityFocused(true)
        XCTAssertEqual(changes, [gripPointer, ringFocus, nil, gripFocus])

        dock.setPresentationAllowed(false)
        XCTAssertFalse(panel.isVisible)
        XCTAssertNil(dock.currentDockHelpSurface)
        XCTAssertNil(dock.currentDockHelpInteraction)
        XCTAssertEqual(changes, [gripPointer, ringFocus, nil, gripFocus, nil])
        dock.refreshPresence()
        XCTAssertEqual(changes, [gripPointer, ringFocus, nil, gripFocus, nil], "A withdrawn host cannot publish the old focus again")
    }
}
#endif
