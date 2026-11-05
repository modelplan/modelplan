// SPDX-License-Identifier: MIT
import CoreGraphics
import XCTest
import ModelPlanDock
@testable import ModelPlanAppIntegration

final class HostCardPlacementTests: XCTestCase {
    func testActualEdgeUsesRingAndAvoidsOverlap() throws {
        let available = CGRect(x: 0, y: 0, width: 800, height: 600)
        let size = CGSize(width: 250, height: 120)
        for (edge, anchor) in [(DockEdge.left, CGRect(x: 10, y: 250, width: 40, height: 40)),
                               (.right, CGRect(x: 750, y: 250, width: 40, height: 40)),
                               (.bottom, CGRect(x: 380, y: 10, width: 40, height: 40))] {
            let card = try XCTUnwrap(HostCardPlacement.place(anchor: anchor, size: size, available: available, edge: edge))
            XCTAssertTrue(available.contains(card)); XCTAssertFalse(card.intersects(anchor))
            switch edge {
            case .left: XCTAssertGreaterThan(card.minX, anchor.maxX)
            case .right: XCTAssertLessThan(card.maxX, anchor.minX)
            case .bottom: XCTAssertGreaterThan(card.minY, anchor.maxY)
            case .top: XCTFail("Unsupported edge")
            }
        }
    }

    func testMissingRingAndUnsupportedEdgeNeverInventPlacement() {
        let bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
        let size = CGSize(width: 250, height: 120)
        XCTAssertNil(HostCardPlacement.place(anchor: nil, size: size, available: bounds, edge: .right))
        XCTAssertNil(HostCardPlacement.place(anchor: CGRect(x: 2, y: 2, width: 0, height: 40), size: size, available: bounds, edge: .right))
        XCTAssertNil(HostCardPlacement.place(anchor: CGRect(x: 300, y: 300, width: 40, height: 40), size: size, available: bounds, edge: .top))
    }

    func testFlipsWhenPreferredSideCannotFit() throws {
        let bounds = CGRect(x: 0, y: 0, width: 500, height: 300)
        let anchor = CGRect(x: 10, y: 130, width: 40, height: 40)
        let card = try XCTUnwrap(HostCardPlacement.place(anchor: anchor, size: CGSize(width: 200, height: 100), available: bounds, edge: .right))
        XCTAssertGreaterThan(card.minX, anchor.maxX)
    }
}
