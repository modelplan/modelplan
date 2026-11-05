// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanDock
@testable import ModelPlanAppIntegration

@MainActor private final class EvidenceScheduler: DockEdgeScheduling {
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) {}
    func cancel() {}
}
@MainActor final class CardPointerEvidenceTests: XCTestCase {
    func testPaintedRegionDriftDoesNotCloseTrackedRowAndMissingResampleCannotReopenExitedCard() throws {
        var now = 0.0
        let row = CGRect(x: 20, y: 20, width: 40, height: 40)
        var env = DockInteractionEnvironment(catalogue: ["synthetic"], preferences: .init(), targets: [], hoverEventRevision: 1,
            hoveredID: "synthetic", insideShared: true, contents: ["synthetic": .init(subscriptionID: "synthetic", name: "Synthetic", rows: [])])
        let controller = DockInteractionController(clock: { now }, scheduler: EvidenceScheduler(), read: { env })
        controller.start(); now = 0.3; controller.refresh()
        XCTAssertEqual(controller.presentation?.card, .hover("synthetic"))
        // Painted regions now miss the row after a rebuild, but its tracked view geometry has not moved.
        env.insideShared = StaticDockPreviewHost.cardPointerEvidence(sampled: false, pointer: .init(x: 30, y: 30), trackedRow: row)
        now = 1; controller.refresh(); now = 1.4; controller.refresh()
        XCTAssertEqual(controller.presentation?.card, .hover("synthetic"))
        XCTAssertNil(StaticDockPreviewHost.cardPointerEvidence(sampled: false, pointer: nil, trackedRow: row))
        env.insideShared = nil; now = 2; controller.refresh()
        XCTAssertEqual(controller.presentation?.card, .hover("synthetic"), "Missing input does not prove an exit")
        env.insideShared = StaticDockPreviewHost.cardPointerEvidence(sampled: false, pointer: .init(x: 200, y: 200), trackedRow: row)
        now = 3; controller.refresh()
        controller.onPresent = { value in if value.card == .hidden { env.insideShared = nil } }
        now = 3.3; controller.refresh()
        XCTAssertEqual(controller.presentation?.card, .hidden)
        now = 4; controller.refresh(); now = 4.5; controller.refresh()
        XCTAssertEqual(controller.presentation?.card, .hidden, "A render-time nil sample cannot resurrect retired hover input")
        env.hoverEventRevision += 1; env.insideShared = true
        now = 5; controller.refresh(); now = 5.3; controller.refresh()
        XCTAssertEqual(controller.presentation?.card, .hover("synthetic"), "A new real hover event can reopen the same row")
        controller.stop()
    }
}
