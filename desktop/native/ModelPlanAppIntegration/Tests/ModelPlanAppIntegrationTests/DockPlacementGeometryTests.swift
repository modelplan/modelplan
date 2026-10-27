// SPDX-License-Identifier: MIT
import XCTest
import ModelPlanDock

final class DockPlacementGeometryTests: XCTestCase {
    private let left = DockDisplayArea(id: "left", frame: CGRect(x: -1200, y: -200, width: 1200, height: 900),
                                       visibleFrame: CGRect(x: -1200, y: -200, width: 1200, height: 875))
    private let right = DockDisplayArea(id: "right", frame: CGRect(x: 0, y: 0, width: 1600, height: 1000),
                                        visibleFrame: CGRect(x: 0, y: 0, width: 1600, height: 975))
    private func layouts(_ displays: [DockDisplayArea]) -> [DockEdgeLayout] {
        displays.flatMap { display in DockEdgeGeometry.allowedEdges.map { edge in
            DockEdgeLayout(displayID: display.id, edge: edge,
                expandedSize: edge == .bottom ? CGSize(width: 180, height: 80) : CGSize(width: 80, height: 180),
                sliverLength: 160, sliverThickness: 4, hoverRects: [])
        } }
    }
    private func place(_ preference: DockEdgePreference, displays: [DockDisplayArea], pointer: CGPoint, nearest: Bool = false) throws -> DockEdgePlacement {
        try XCTUnwrap(DockEdgeGeometry.resolve(preference: preference, displays: displays, layouts: layouts(displays),
            pointer: pointer, primaryID: "right", nearest: nearest))
    }
    func testPointerFollowingChangesDisplayOnly() throws {
        let preference = DockEdgePreference(edge: .bottom, alongFraction: 0.37)
        let first = try place(preference, displays: [left, right], pointer: CGPoint(x: -500, y: 200))
        let same = try place(preference, displays: [left, right], pointer: CGPoint(x: -900, y: 500))
        let crossed = try place(preference, displays: [left, right], pointer: CGPoint(x: 500, y: 700))
        let overMenuBar = try place(preference, displays: [left, right], pointer: CGPoint(x: -500, y: 890 - 200))
        XCTAssertEqual(first, overMenuBar, "menu-bar space belongs to the same physical display")
        XCTAssertEqual(first, same); XCTAssertEqual(first.displayID, "left"); XCTAssertEqual(crossed.displayID, "right")
        XCTAssertEqual(first.alongFraction, 0.37, accuracy: 1e-9)
        XCTAssertEqual(crossed.alongFraction, 0.37, accuracy: 1e-9)
    }
    func testFixedDisplaySharedEdgeDisconnectAndReconnectNeverRewriteIntent() throws {
        let preference = DockEdgePreference(displayID: "left", edge: .right, alongFraction: 0.61)
        let initial = try place(preference, displays: [left, right], pointer: CGPoint(x: 700, y: 500))
        XCTAssertEqual(initial.displayID, "left"); XCTAssertNotEqual(initial.edge, .right)
        XCTAssertTrue(left.visibleFrame.contains(initial.sliverFrame))
        let absentA = try place(preference, displays: [right], pointer: CGPoint(x: 50, y: 50))
        let absentB = try place(preference, displays: [right], pointer: CGPoint(x: 1500, y: 900))
        XCTAssertEqual(absentA, absentB); XCTAssertEqual(absentA.displayID, "right")
        let restored = try place(preference, displays: [left, right], pointer: CGPoint(x: 50, y: 50))
        XCTAssertEqual(initial, restored)
        XCTAssertEqual(preference.displayID, "left"); XCTAssertEqual(preference.alongFraction, 0.61)
    }
    func testExplicitNearestDragStillMoves() throws {
        let preference = DockEdgePreference(displayID: "left", edge: .bottom, alongFraction: 0.5)
        let a = try place(preference, displays: [left, right], pointer: CGPoint(x: -800, y: -195), nearest: true)
        let b = try place(preference, displays: [left, right], pointer: CGPoint(x: 800, y: 2), nearest: true)
        XCTAssertEqual(a.edge, .bottom); XCTAssertEqual(b.edge, .bottom)
        XCTAssertEqual(a.displayID, "left"); XCTAssertEqual(b.displayID, "right")
        XCTAssertNotEqual(a.alongFraction, b.alongFraction)
    }
}
