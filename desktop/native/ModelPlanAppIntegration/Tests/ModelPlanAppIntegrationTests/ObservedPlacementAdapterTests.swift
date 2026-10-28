// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanDock
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class ObservedPlacementAdapterTests: XCTestCase {
    func testProducerFactsUpdateContextOnceAndNeverPersistRecovery() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("placement-facts-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SettingsStore(url: root.appendingPathComponent("prefs.json"))
        try await store.update { $0.dockEdge = .right; $0.dockAlongFraction = 0.75; $0.dockDisplayID = "preferred" }
        var deliveries = 0
        let application = SettingsApplicationCoordinator(store: store, apply: { _ in deliveries += 1 })
        await application.reload(); let before = try XCTUnwrap(application.editor.snapshot)
        let frame = CGRect(x: 0, y: 0, width: 60, height: 200)
        let layout = DockEdgeLayout(displayID: "recovery", edge: .left, expandedSize: frame.size,
            sliverLength: 100, sliverThickness: 4, hoverRects: [frame])
        let display = CGRect(x: 0, y: 0, width: 1200, height: 900)
        let placement = try XCTUnwrap(DockEdgeGeometry.resolve(preference: .init(displayID: "recovery", edge: .right),
            displays: [.init(id: "recovery", frame: display, visibleFrame: display)], layouts: [layout], pointer: nil, primaryID: "recovery"))
        XCTAssertThrowsError(try CommunityDockPlacementFacts.requireSynchronized(placement, recovering: true, application: application))
        XCTAssertTrue(try CommunityDockPlacementFacts.apply(placement, recovering: true, application: application))
        XCTAssertNoThrow(try CommunityDockPlacementFacts.requireSynchronized(placement, recovering: true, application: application))
        let delivered = deliveries
        XCTAssertFalse(try CommunityDockPlacementFacts.apply(placement, recovering: true, application: application))
        XCTAssertEqual(deliveries, delivered)
        XCTAssertEqual(application.editor.context.dockPlacementObservation?.edge, .left)
        XCTAssertEqual(application.editor.snapshot?.revision, before.revision)
        XCTAssertEqual(application.editor.snapshot?.preferences.dockEdge, .right)
        XCTAssertEqual(application.editor.snapshot?.preferences.dockDisplayID, "preferred")
        XCTAssertEqual(application.editor.snapshot?.preferences.dockAlongFraction, 0.75)
        XCTAssertTrue(try CommunityDockPlacementFacts.apply(nil, recovering: false, application: application))
        XCTAssertNil(application.editor.context.dockPlacementObservation)
        XCTAssertThrowsError(try CommunityDockPlacementFacts.requireSynchronized(placement, recovering: true, application: application))
    }
}
