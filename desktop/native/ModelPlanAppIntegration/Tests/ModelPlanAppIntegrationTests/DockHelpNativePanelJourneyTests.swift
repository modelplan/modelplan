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
            bundleURL: root.appendingPathComponent("Synthetic.app"), cockpitEntryEnabled: true,
            dockEnvironment: { .init(displays: [display], layouts: [], primaryDisplayID: display.id,
                pointer: pointer) },
            deadlineNow: { wall },
            makeClient: { _, store in EntrySyntheticClient(store: store, rows: snapshot) },
            isolatedResetNotificationLedger: root.appendingPathComponent("test-notifications.json"), activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        let dock = app.composition.dock
        var changes: [DockHelpInteraction?] = []
        dock.dockHelpInteractionDidChange = { changes.append($0) }
        await app.prepare()
        XCTAssertNil(app.loginServiceAdapter)
        XCTAssertNil(app.notificationAuthorizationService)
        app.allowDockPresentation()
        await app.composition.start()
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
        let ignition = try XCTUnwrap(panel.contentView?.subviews.compactMap { $0 as? NSButton }
            .first { $0.accessibilityIdentifier() == "dock.ignition" })
        let ignitionAnchor = try XCTUnwrap(surface.mapAnchors.first { $0.id == "dock.ignition" })
        XCTAssertTrue(ignition.window === panel)
        XCTAssertTrue(ignition.isEnabled)

        func interaction(_ anchor: DockRequestedHelpAnchor, _ source: DockHelpInteraction.Source) throws -> DockHelpInteraction {
            let value = try XCTUnwrap(dock.currentDockHelpInteraction)
            XCTAssertEqual(value.anchor, anchor)
            XCTAssertEqual(value.source, source)
            return value
        }
        func movePointer(to point: CGPoint) {
            pointer = point
            dock.pointerInputView.reportAgain()
            dock.pointerInputView.sampleNow()
        }

        let originalValue = subscription.accessibilityValue() as? String
        let originalHelp = subscription.accessibilityHelp()
        XCTAssertNil(dock.currentDockHelpInteraction)
        XCTAssertTrue(changes.isEmpty)
        movePointer(to: CGPoint(x: grip.rect.midX, y: grip.rect.midY))
        let gripPointer = try interaction(grip, .pointer)
        XCTAssertEqual(changes, [gripPointer])
        XCTAssertFalse(dock.setDockHelpAccessibilityExplanation("Pointer only", for: gripPointer, on: surface))

        subscription.setAccessibilityFocused(true)
        let ringFocus = try interaction(ring, .keyboard)
        let ringSurface = try XCTUnwrap(dock.currentDockHelpSurface)
        let ringText = "Quota ring\nShows the current window."
        XCTAssertTrue(dock.setDockHelpAccessibilityExplanation(ringText, for: ringFocus, on: ringSurface))
        XCTAssertEqual(subscription.accessibilityHelp(), ringText)
        XCTAssertEqual(subscription.accessibilityValue() as? String, originalValue)
        subscription.setAccessibilityFocused(true)
        XCTAssertEqual(changes, [gripPointer, ringFocus])
        movePointer(to: outside)
        XCTAssertEqual(changes, [gripPointer, ringFocus], "Keyboard focus takes precedence over a pointer change")
        subscription.setAccessibilityFocused(false)
        XCTAssertEqual(changes, [gripPointer, ringFocus, nil])
        XCTAssertEqual(subscription.accessibilityHelp(), originalHelp)

        subscription.setAccessibilityFocused(true)
        let secondVisit = try interaction(ring, .keyboard)
        let secondSurface = try XCTUnwrap(dock.currentDockHelpSurface)
        XCTAssertEqual(secondSurface.layoutID, ringSurface.layoutID)
        XCTAssertNotEqual(secondVisit.receipt, ringFocus.receipt)
        XCTAssertTrue(dock.setDockHelpAccessibilityExplanation(ringText, for: secondVisit, on: secondSurface))
        XCTAssertFalse(dock.setDockHelpAccessibilityExplanation(nil, for: ringFocus, on: ringSurface))
        XCTAssertEqual(subscription.accessibilityHelp(), ringText)
        subscription.setAccessibilityFocused(false)

        gripNode.setAccessibilityFocused(true)
        let gripFocus = try interaction(grip, .keyboard)
        let gripSurface = try XCTUnwrap(dock.currentDockHelpSurface)
        let gripText = "Move the widget\nDrag the grip to another edge."
        XCTAssertTrue(dock.setDockHelpAccessibilityExplanation(gripText, for: gripFocus, on: gripSurface))
        XCTAssertEqual(gripNode.accessibilityHelp(), gripText)
        gripNode.setAccessibilityFocused(true)
        let throughGrip: [DockHelpInteraction?] = [gripPointer, ringFocus, nil, secondVisit, nil, gripFocus]
        XCTAssertEqual(changes, throughGrip)
        gripNode.setAccessibilityFocused(false)
        XCTAssertNil(gripNode.accessibilityHelp())

        ignition.setAccessibilityFocused(true)
        let ignitionFocus = try interaction(ignitionAnchor, .keyboard)
        let ignitionSurface = try XCTUnwrap(dock.currentDockHelpSurface)
        let ignitionText = "Ignition\nOpen the cockpit."
        XCTAssertTrue(dock.setDockHelpAccessibilityExplanation(ignitionText, for: ignitionFocus, on: ignitionSurface))
        XCTAssertEqual(ignition.accessibilityHelp(), ignitionText)
        XCTAssertFalse(dock.setDockHelpAccessibilityExplanation(gripText, for: gripFocus, on: gripSurface))

        dock.cockpitEntryEnabled = false
        XCTAssertFalse(ignition.isEnabled)
        XCTAssertNil(dock.currentDockHelpInteraction)
        XCTAssertNil(ignition.accessibilityHelp())
        XCTAssertFalse(dock.setDockHelpAccessibilityExplanation(ignitionText, for: ignitionFocus, on: ignitionSurface))
        dock.cockpitEntryEnabled = true
        XCTAssertNil(dock.currentDockHelpInteraction)
        ignition.setAccessibilityFocused(true)
        let nextIgnitionFocus = try interaction(ignitionAnchor, .keyboard)
        let nextIgnitionSurface = try XCTUnwrap(dock.currentDockHelpSurface)
        XCTAssertTrue(dock.setDockHelpAccessibilityExplanation(ignitionText, for: nextIgnitionFocus, on: nextIgnitionSurface))
        let beforeWithdrawal = throughGrip + [nil, ignitionFocus, nil, nextIgnitionFocus]
        XCTAssertEqual(changes, beforeWithdrawal)
        dock.setPresentationAllowed(false)
        XCTAssertFalse(panel.isVisible)
        XCTAssertNil(dock.currentDockHelpSurface)
        XCTAssertNil(dock.currentDockHelpInteraction)
        XCTAssertNil(gripNode.accessibilityHelp())
        XCTAssertNil(ignition.accessibilityHelp())
        XCTAssertEqual(changes, beforeWithdrawal + [nil])
        XCTAssertFalse(dock.setDockHelpAccessibilityExplanation(gripText, for: gripFocus, on: gripSurface))
        dock.refreshPresence()
        XCTAssertEqual(changes, beforeWithdrawal + [nil], "A withdrawn host cannot publish the old focus again")
    }
}
#endif
