// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanShell
import ModelPlanWire
@testable import ModelPlanAppIntegration

@MainActor private final class IgnitionConsoleProbe: EngineRowsConsoleSurface {
    var shows = 0
    func show() { shows += 1 }
    func render() {}
    func hide() {}
}

/// CKP-ENTRY-02 (C-34; owner C03, D59): in v1 holding the ignition opens the cockpit exactly as a press does.
/// There is no charge, countdown or entrance: the press, however long, opens once on release. The press lands on
/// the real ignition button of the normal entry on the real Dock panel.
///
/// The hold is driven through the button's own press API (highlight on mouse-down, action on mouse-up inside),
/// not through AppKit's private tracking loop: a synthetic mouse-down sent in-process does not enter that loop on
/// every window server (on the modelplan-mac-gui-2 VM it returned after ~1.5 ms without acting), so a real-timing
/// hold made the suite depend on the host. The panel's routing and the button's mouse-up-only, non-continuous
/// configuration are checked separately, so a real press takes the same path.
@MainActor final class IgnitionHoldEntryTests: XCTestCase {
    private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }

    func testHoldingTheIgnitionOpensTheCockpitOnceOnReleaseLikeAPress() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ignition-hold-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        _ = try await settings.update { $0.showDock = true; $0.autoHide = false }
        let wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-02T00:00:00Z"))
        let snapshot = try HostPairedProjectionTests.rows(weekly: 75, secondWeekly: 55)
        let probe = IgnitionConsoleProbe()
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: true,
            cockpitEntryEnabled: true, dockEnvironment: normalEntryTestEnvironment, deadlineNow: { wall },
            makeClient: { _, store in EntrySyntheticClient(store: store, rows: snapshot) },
            makeConsole: { _ in probe }, activateSettings: {})
        addTeardownBlock { @MainActor in app.composition.dock.close(); await app.composition.stop() }
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()

        let dock = app.composition.dock
        var button: NSButton?
        for _ in 0..<300 {
            if let panel = dock.nativePanel, let content = panel.contentView,
               let found = descendants(content).compactMap({ $0 as? NSButton }).first(where: {
                   $0.accessibilityIdentifier() == "dock.ignition" && !$0.isHiddenOrHasHiddenAncestor && $0.isEnabled }) {
                button = found; break
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        let ignition = try XCTUnwrap(button, "The normal entry shows an enabled ignition on the real Dock panel")
        let panel = try XCTUnwrap(ignition.window)
        let point = ignition.convert(CGPoint(x: ignition.bounds.midX, y: ignition.bounds.midY), to: nil)
        // The press must land on the ignition and not on a drag region or another view: say what it hit if not.
        let hit = try XCTUnwrap(panel.contentView).hitTest(try XCTUnwrap(panel.contentView?.superview).convert(point, from: nil))
        XCTAssertTrue(hit === ignition || hit?.isDescendant(of: ignition) == true,
                      "The press point hits \(String(describing: hit)) (panel visible \(panel.isVisible), alpha \(panel.alphaValue), ignores mouse \(panel.ignoresMouseEvents)), not the ignition")
        // The Dock panel hands a press here to AppKit instead of starting a widget drag.
        let global = panel.convertPoint(toScreen: point)
        let captured = dock.beginPanelMove(windowPoint: point, globalPoint: global)
        if captured { dock.cancelPanelMove() }
        XCTAssertFalse(captured, "A press on the ignition is not taken as a widget drag")
        // A real press acts once, on mouse-up inside, and never periodically while held.
        XCTAssertFalse(ignition.isContinuous, "The ignition sends no periodic action while it is held")
        let mask = ignition.sendAction(on: .leftMouseUp)
        XCTAssertEqual(UInt64(mask), NSEvent.EventTypeMask.leftMouseUp.rawValue, "The ignition acts on mouse-up only")

        /// Presses the ignition for `seconds` the way AppKit's tracking does: highlight on mouse-down, keep the main
        /// run loop running for the hold (so any hold timer would fire), then unhighlight and send the action once on
        /// mouse-up inside. The console and the cap pose are read halfway through the hold.
        func press(for seconds: TimeInterval) async throws -> (held: TimeInterval, opensDuringHold: Int, poseDuringHold: String) {
            let half = Int(seconds * 500)
            let started = ProcessInfo.processInfo.systemUptime
            ignition.highlight(true)
            try await Task.sleep(for: .milliseconds(half))
            let opens = probe.shows, pose = dock.ignitionPoseForChecks.pose
            try await Task.sleep(for: .milliseconds(half))
            ignition.highlight(false)
            XCTAssertTrue(ignition.sendAction(ignition.action, to: ignition.target), "The ignition's press reaches its target")
            return (ProcessInfo.processInfo.systemUptime - started, opens, pose)
        }

        // A hold past the v1.1 hold timing (200 ms + 3 x 250 ms = 950 ms) still opens like a press, once, on release.
        let hold = try await press(for: 1.2)
        XCTAssertGreaterThanOrEqual(hold.held, 1.1, "The ignition was held for the whole hold")
        XCTAssertEqual(hold.opensDuringHold, 0, "Nothing opens, charges or counts down while the ignition is held")
        XCTAssertEqual(hold.poseDuringHold, "pressed", "The held ignition shows its pressed cap")
        XCTAssertEqual(probe.shows, 1, "Releasing a held ignition opens the cockpit once")
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(probe.shows, 1, "Nothing more opens after the release")

        // A short press opens the same way.
        let tap = try await press(for: 0.08)
        XCTAssertLessThan(tap.held, 1)
        XCTAssertEqual(tap.opensDuringHold, 1, "Nothing opens before a short press is released")
        XCTAssertEqual(probe.shows, 2, "A press opens the cockpit once, the same as a hold")
    }
}
