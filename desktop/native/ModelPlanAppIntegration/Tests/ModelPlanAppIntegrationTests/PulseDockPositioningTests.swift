// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanDock
import ModelPlanShell
@testable import ModelPlanAppIntegration

@MainActor private final class PulsePositionScheduler: DockEdgeScheduling {
    var action: (@MainActor () -> Void)?
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) { self.action = action }
    func cancel() { action = nil }
}

@MainActor final class PulseDockPositioningTests: XCTestCase {
    private let display = DockDisplayArea(id: "synthetic", frame: CGRect(x: -1200, y: -200, width: 1200, height: 900),
        visibleFrame: CGRect(x: -1200, y: -200, width: 1200, height: 875))
    private func environment(_ displays: [DockDisplayArea]) -> DockEdgeEnvironment {
        .init(displays: displays, layouts: displays.flatMap { display in
            DockEdgeGeometry.allowedEdges.map { edge in
                .init(displayID: display.id, edge: edge,
                    expandedSize: edge == .bottom ? CGSize(width: 180, height: 80) : CGSize(width: 80, height: 180),
                    sliverLength: 140, sliverThickness: 4, hoverRects: [], alongAnchor: 73)
            }
        }, primaryDisplayID: display.id, pointer: CGPoint(x: -500, y: 200))
    }
    func testBorrowedWindowGeometryKeepsRegisteredAnchorOnEveryAllowedEdge() throws {
        let env = environment([display])
        for edge in DockEdgeGeometry.allowedEdges { for fraction in [0.0, 0.23, 0.5, 1.0] {
            let request = DockPlacementRequest(preference: .init(displayID: display.id, edge: edge, alongFraction: fraction), environment: env)
            let actual = try XCTUnwrap(PulseDockPositioning.resolve(request))
            let eligible = try XCTUnwrap(request.resolveEligibleEdge())
            XCTAssertEqual(actual.edge, edge)
            XCTAssertEqual(actual.frame.minX, eligible.frame.minX, accuracy: 1e-8)
            XCTAssertEqual(actual.frame.minY, eligible.frame.minY, accuracy: 1e-8)
            XCTAssertEqual(actual.sliverFrame.midX - actual.frame.minX, eligible.sliverFrame.midX - eligible.frame.minX, accuracy: 1e-8)
            XCTAssertEqual(actual.sliverFrame.midY - actual.frame.minY, eligible.sliverFrame.midY - eligible.frame.minY, accuracy: 1e-8)
            XCTAssertTrue(display.usableFrame.insetBy(dx: -1e-8, dy: -1e-8).contains(actual.frame))
        } }
    }
    func testDisplayRecoveryAndAdjoiningSeamRemainPolicyWithoutSavingIntent() throws {
        let neighbour = DockDisplayArea(id: "next", frame: CGRect(x: 0, y: -200, width: 1000, height: 900),
            visibleFrame: CGRect(x: 0, y: -200, width: 1000, height: 875))
        let preference = DockEdgePreference(displayID: display.id, edge: .right, alongFraction: 0.61)
        let joined = try XCTUnwrap(PulseDockPositioning.resolve(.init(preference: preference, environment: environment([display, neighbour]))))
        XCTAssertNotEqual(joined.edge, .right, "a physical adjoining edge is not a wake destination")
        let recovered = try XCTUnwrap(PulseDockPositioning.resolve(.init(preference: preference, environment: environment([neighbour]))))
        XCTAssertEqual(recovered.displayID, neighbour.id)
        XCTAssertEqual(preference.displayID, display.id); XCTAssertEqual(preference.edge, .right)
        let restored = try XCTUnwrap(PulseDockPositioning.resolve(.init(preference: preference, environment: environment([display]))))
        XCTAssertEqual(restored.edge, .right); XCTAssertEqual(restored.displayID, display.id)
    }
    func testOneControllerUsesBorrowedPositioningForPlacementPreviewReleaseAndStop() throws {
        var env = environment([display]); env.presence.autoHide = false
        var elapsed: TimeInterval = 0
        let scheduler = PulsePositionScheduler()
        var nearestCalls = 0, fixedCalls = 0, commits: [DockEdgePreference] = []
        let controller = DockEdgeController(preference: .init(displayID: display.id), clock: { elapsed }, scheduler: scheduler, read: { env }, position: { request in
            if request.nearest { nearestCalls += 1 } else { fixedCalls += 1 }
            return try PulseDockPositioning.resolve(request)
        })
        controller.onCommittedPlacement = { commits.append($0) }
        controller.start(); defer { controller.stop() }
        elapsed = 1
        let initial = try XCTUnwrap(controller.presentation?.placement)
        controller.dragRegions = .init(body: CGPath(rect: CGRect(origin: .zero, size: initial.frame.size), transform: nil), excludedControls: [])
        XCTAssertTrue(controller.beginBackgroundMove(local: CGPoint(x: 20, y: 20), global: CGPoint(x: initial.frame.midX, y: initial.frame.midY)))
        let destination = CGPoint(x: display.usableFrame.minX, y: display.usableFrame.midY)
        controller.updateBackgroundMove(global: destination)
        XCTAssertEqual(controller.presentation?.snapPreview?.edge, .left)
        XCTAssertTrue(commits.isEmpty, "preview never persists")
        controller.endBackgroundMove(global: destination); controller.endBackgroundMove(global: destination)
        XCTAssertEqual(commits.count, 1); XCTAssertEqual(commits.first?.edge, .left)
        XCTAssertGreaterThan(nearestCalls, 0); XCTAssertGreaterThan(fixedCalls, 0)
        let staleSample = scheduler.action
        controller.stop(); staleSample?()
        XCTAssertEqual(controller.presentation?.state, .suppressed(.lifecycle))
        XCTAssertNil(controller.presentation?.snapPreview); XCTAssertNil(scheduler.action)
        XCTAssertEqual(commits.count, 1, "stopped work cannot create a late commit")
    }
}
