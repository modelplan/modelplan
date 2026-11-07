// SPDX-License-Identifier: MIT
import AppKit
import Foundation
import XCTest
import ModelPlanEngineClient
import ModelPlanDock
@testable import ModelPlanAppIntegration

/// MENU-12 through the normal entry: an actually open menu protects the dock, and a stale
/// menu-open flag does not block recovery. AppKit's balanced tracking notifications are the
/// authority: a latch whose session ended (the scrub path cancels tracking without a guaranteed
/// `menuDidClose`), or a latch that never saw a session, stops protecting at once, so the
/// visibility state machine regains its collapse deadline.
@MainActor final class MENU12DockMenuGuardJourneyTests: XCTestCase {
    func testMENU_12ActuallyOpenMenuProtectsDockAndStaleLatchRecovers() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("menu-12-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let config = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic",
                                               allowedEnvironment: [:], offline: true, readOnly: true)
        let app = EngineRowsEntry.make(configuration: config,
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en-US"]),
            createsNativePanels: false, dockEnvironment: normalEntryTestEnvironment, activateSettings: {})
        await app.prepare()
        let dock = app.composition.dock
        let menu = dock.menu()
        // An actually open menu (delegate callback plus AppKit's balanced tracking notification) protects the dock.
        dock.menuWillOpen(menu)
        NotificationCenter.default.post(name: NSMenu.didBeginTrackingNotification, object: menu)
        XCTAssertTrue(dock.menuOpen, "MENU-12: an actually open menu must protect the dock")
        // Scrub path: tracking ends without the delegate's menuDidClose; protection must drop at once.
        NotificationCenter.default.post(name: NSMenu.didEndTrackingNotification, object: menu)
        XCTAssertFalse(dock.menuOpen, "MENU-12: an ended tracking session must not keep protecting the dock")
        // Stale latch: a menuWillOpen signal arrives but no tracking session is live (missed or reordered signal).
        dock.menuWillOpen(menu)
        XCTAssertFalse(dock.menuOpen, "MENU-12: a stale menu flag must not block recovery")
        // A later full cycle protects again, and the delegate close stays authoritative.
        NotificationCenter.default.post(name: NSMenu.didBeginTrackingNotification, object: menu)
        XCTAssertTrue(dock.menuOpen)
        dock.menuDidClose(menu)
        XCTAssertFalse(dock.menuOpen)
        // An unbalanced extra end notification must not unbalance a fresh session.
        NotificationCenter.default.post(name: NSMenu.didEndTrackingNotification, object: menu)
        NotificationCenter.default.post(name: NSMenu.didBeginTrackingNotification, object: menu)
        XCTAssertTrue(dock.menuOpen)
        NotificationCenter.default.post(name: NSMenu.didEndTrackingNotification, object: menu)
        XCTAssertFalse(dock.menuOpen)
        await app.composition.stop()
    }
    func testMENU_12VisibilityKeepsCollapseAuthorityWhenTheMenuGuardRecovers() throws {
        // The guard only feeds DockPresence.menuActuallyOpen; the state machine keeps its
        // deadlines: no collapse while actually open, collapse after recovery.
        var state = DockVisibilityState(policy: .init())
        var presence = DockPresence()
        presence.autoHide = true; presence.pointer = .outside; presence.menuActuallyOpen = true
        _ = try state.step(presence, at: 0, intent: .reveal)
        XCTAssertFalse(try state.step(presence, at: 10).didCollapse, "MENU-12: an actually open menu protects the dock")
        presence.menuActuallyOpen = false
        XCTAssertFalse(try state.step(presence, at: 10.25).didCollapse, "leave grace still applies after recovery")
        XCTAssertTrue(try state.step(presence, at: 10.75).didCollapse, "MENU-12: recovery must restore the collapse deadline")
    }
}
