// SPDX-License-Identifier: MIT
import AppKit
import Foundation
import ModelPlanDock
import ModelPlanSettings
@_spi(DockResourceChecks) @testable import ModelPlanAppIntegration
import XCTest

@MainActor private final class ManyMembers: DockContentProvider {
    let inputs: [DockInstrumentInput]
    init(now: Date) {
        inputs = (0..<30).map { index in
            var value = DockInstrumentInput(id: "synthetic-\(index)", name: "Synthetic \(index)", windows: [
                .init(id: "quota", period: .fiveHour, label: "5h", remainingPercent: 76,
                      resetsAt: now.addingTimeInterval(600), durationSeconds: 18000)])
            value.dataState = .fresh
            return value
        }
    }
    func makeContent(_ context: DockContentContext) -> DockContent { .init(snapshot: .init(inputs: inputs)) }
}

/// DOCK-3.1-18 with a real panel: the +N tray opens on an opaque background that scrolls.
/// Needs a window server, so it stays on the GUI leg.
@MainActor final class DockOverflowTrayWindowTests: XCTestCase {
    func testOpenTrayIsOpaqueAndScrolls() async throws {
        _ = NSApplication.shared
        let now = Date(timeIntervalSince1970: 1_792_506_300)
        let display = DockDisplayArea(id: "synthetic", frame: .init(x: 0, y: 0, width: 1000, height: 420), visibleFrame: .init(x: 0, y: 0, width: 1000, height: 396))
        let environment = DockEdgeEnvironment(displays: [display], layouts: [], primaryDisplayID: "synthetic")
        let host = ProductionDockFactory.community(createsNativePanels: true, nativeEnvironment: { environment }, currentDate: { now })
        defer { host.close() }
        host.setDockContentProvider(ManyMembers(now: now))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("overflow-tray-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SettingsStore(url: root.appendingPathComponent("settings.json"))
        try await store.update { $0.autoHide = false }
        let coordinator = SettingsApplicationCoordinator(store: store) { host.apply($0) }
        await coordinator.reload(); host.setPresentationAllowed(true)
        host.interactionControllerForChecks?.toggleOverflow()
        for _ in 0..<200 where !host.overflowSurfaceForChecks.shown { try await Task.sleep(for: .milliseconds(10)) }
        let surface = host.overflowSurfaceForChecks
        XCTAssertTrue(surface.shown, "30 members on a short display must overflow into the tray")
        XCTAssertTrue(surface.opaque); XCTAssertTrue(surface.scrolls)
    }
}
