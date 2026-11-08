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

@MainActor private final class HoldObservation {
    var opensDuringHold: Int?
}

/// CKP-ENTRY-02 (C-34; owner C03, D59): in v1 holding the ignition opens the cockpit exactly as a press does.
/// There is no charge, countdown or entrance: the press, however long, opens once on release. The press goes
/// through the real Dock panel's event handling to the real ignition button of the normal entry.
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
        // The Dock panel asks where the pointer is for its drag transaction; keep it on the ignition.
        (panel as? PulseDockPanel)?.pointerLocation = { panel.convertPoint(toScreen: point) }
        // Earlier tests can leave events queued; AppKit's tracking loop would read those first.
        while NSApp.nextEvent(matching: .any, until: .distantPast, inMode: .default, dequeue: true) != nil {}
        func mouse(_ type: NSEvent.EventType) throws -> NSEvent {
            try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: panel.windowNumber, context: nil,
                eventNumber: 0, clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1))
        }
        /// Presses the ignition for `seconds`. The button tracks the press until the mouse-up, which a timer posts
        /// while AppKit's tracking loop runs; a second timer reads the console halfway through the hold.
        func press(for seconds: TimeInterval) throws -> (held: TimeInterval, opensDuringHold: Int?) {
            let observation = HoldObservation(), up = try mouse(.leftMouseUp)
            let check = Timer(timeInterval: seconds / 2, repeats: false) { _ in
                MainActor.assumeIsolated { observation.opensDuringHold = probe.shows }
            }
            let release = Timer(timeInterval: seconds, repeats: false) { _ in
                MainActor.assumeIsolated { NSApp.postEvent(up, atStart: true) }
            }
            RunLoop.main.add(check, forMode: .common); RunLoop.main.add(release, forMode: .common)
            let started = ProcessInfo.processInfo.systemUptime
            panel.sendEvent(try mouse(.leftMouseDown))
            let held = ProcessInfo.processInfo.systemUptime - started
            check.invalidate(); release.invalidate()
            return (held, observation.opensDuringHold)
        }

        // A hold past the v1.1 hold timing (200 ms + 3 x 250 ms = 950 ms) still opens like a press, once, on release.
        let hold = try press(for: 1.2)
        XCTAssertGreaterThanOrEqual(hold.held, 1.1, "The ignition tracked the whole hold")
        XCTAssertEqual(hold.opensDuringHold, 0, "Nothing opens, charges or counts down while the ignition is held")
        XCTAssertEqual(probe.shows, 1, "Releasing a held ignition opens the cockpit once")

        // A short press opens the same way.
        let tap = try press(for: 0.08)
        XCTAssertLessThan(tap.held, 1)
        XCTAssertEqual(probe.shows, 2, "A press opens the cockpit once, the same as a hold")
    }
}
