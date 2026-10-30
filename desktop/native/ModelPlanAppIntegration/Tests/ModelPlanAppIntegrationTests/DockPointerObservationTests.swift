// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanDock
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor private final class PointerObservationScheduler: DockEdgeScheduling {
    var action: (@MainActor () -> Void)?
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) { self.action = action }
    func cancel() { action = nil }
    func fire() { let value = action; action = nil; value?() }
}
@MainActor final class DockPointerObservationTests: XCTestCase {
    func testNormalHostConsumesSamplerAndEntryWithoutBypassingDwellAndStopsOnClose() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("pointer-observation-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SettingsStore(url: root.appendingPathComponent("settings.json"))
        try await store.update { $0.autoHide = true }
        let screen = DockDisplayArea(id: "synthetic", frame: CGRect(x: 0, y: 0, width: 1200, height: 900), visibleFrame: CGRect(x: 0, y: 0, width: 1200, height: 900))
        var elapsed: TimeInterval = 0, local: CGPoint?
        var pointer = CGPoint(x: 500, y: 400), sampleReads = 0
        let scheduler = PointerObservationScheduler()
        let host = StaticDockPreviewHost(appearance: { view, rows, _ in
            try view.applyCommunity(rows); view.setFrameSize(CGSize(width: 80, height: 180))
            return .init(hoverRects: [view.bounds])
        }, currentDate: { Date(timeIntervalSince1970: 1_800_000_000) }, createsNativePanels: false,
            nativeEnvironment: { .init(displays: [screen], layouts: [], primaryDisplayID: screen.id, pointer: pointer) },
            elapsedClock: { elapsed }, edgeScheduling: scheduler,
            pointerSampleSource: { sampleReads += 1; return local })
        defer { host.close() }
        let app = SettingsApplicationCoordinator(store: store) { host.apply($0) }
        await app.reload(); host.setPresentationAllowed(true)
        let bytes = try Data(contentsOf: root.appendingPathComponent("settings.json"))
        let surface = host.pointerInputView
        XCTAssertTrue(surface.isActive); XCTAssertNil(host.nativePanel)
        surface.sampleNow(); XCTAssertEqual(host.edgePresentation?.state, .sliver)
        let place = try XCTUnwrap(host.edgePresentation?.placement)
        pointer = CGPoint(x: place.wakeFrame.midX, y: place.wakeFrame.midY)
        // local remains nil, simulating entry arriving after an absent sample.
        let entry = try XCTUnwrap(surface.subviews.first { !$0.trackingAreas.isEmpty })
        let event = try XCTUnwrap(NSEvent.enterExitEvent(with: .mouseEntered, location: .zero,
            modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
            eventNumber: 1, trackingNumber: 0, userData: nil))
        entry.mouseEntered(with: event)
        XCTAssertEqual(host.edgePresentation?.state, .sliver, "entry must not bypass the controller's dwell")
        elapsed = 0.15; scheduler.fire()
        XCTAssertEqual(host.edgePresentation?.state, .expanded)
        XCTAssertTrue(surface.isActive)
        local = CGPoint(x: 1, y: 1); surface.sampleNow()
        pointer = CGPoint(x: 500, y: 400); local = nil; surface.sampleNow()
        elapsed = 0.65; scheduler.fire()
        XCTAssertEqual(host.edgePresentation?.state, .sliver)
        host.setPresentationAllowed(false); XCTAssertFalse(surface.isActive)
        host.setPresentationAllowed(true); XCTAssertTrue(surface.isActive)
        host.close(); let stoppedReads = sampleReads
        entry.mouseEntered(with: event); surface.sampleNow()
        XCTAssertEqual(sampleReads, stoppedReads); XCTAssertFalse(surface.isActive)
        XCTAssertNil(host.nativePanel)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("settings.json")), bytes)
    }
}
