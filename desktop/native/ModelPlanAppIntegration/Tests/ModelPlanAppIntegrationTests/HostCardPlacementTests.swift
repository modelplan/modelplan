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
                               (.bottom, CGRect(x: 380, y: 10, width: 40, height: 40)),
                               (.top, CGRect(x: 380, y: 550, width: 40, height: 40))] {
            let card = try XCTUnwrap(HostCardPlacement.place(anchor: anchor, size: size, available: available, edge: edge))
            XCTAssertTrue(available.contains(card)); XCTAssertFalse(card.intersects(anchor))
            switch edge {
            case .left: XCTAssertGreaterThan(card.minX, anchor.maxX)
            case .right: XCTAssertLessThan(card.maxX, anchor.minX)
            case .bottom: XCTAssertGreaterThan(card.minY, anchor.maxY)
            // G3-27: below the menu bar the card unfolds downwards.
            case .top: XCTAssertLessThan(card.maxY, anchor.minY)
            }
        }
    }

    func testMissingRingNeverInventsPlacement() {
        let bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
        let size = CGSize(width: 250, height: 120)
        XCTAssertNil(HostCardPlacement.place(anchor: nil, size: size, available: bounds, edge: .right))
        XCTAssertNil(HostCardPlacement.place(anchor: CGRect(x: 2, y: 2, width: 0, height: 40), size: size, available: bounds, edge: .right))
    }

    func testFlipsWhenPreferredSideCannotFit() throws {
        let bounds = CGRect(x: 0, y: 0, width: 500, height: 300)
        let anchor = CGRect(x: 10, y: 130, width: 40, height: 40)
        let card = try XCTUnwrap(HostCardPlacement.place(anchor: anchor, size: CGSize(width: 200, height: 100), available: bounds, edge: .right))
        XCTAssertGreaterThan(card.minX, anchor.maxX)
    }

    /// G3-05 (R64 D-3): the pointer arrow from the plate to its ring, as the prototype card.js place():
    /// 16 pt wide, tip 2 pt before the ring, 1 pt over the plate, centred on the ring and kept 16 pt from corners.
    func testCardPointerArrowReachesTowardTheRingOnEverySide() throws {
        let ring = CGRect(x: 1000, y: 400, width: 44, height: 44)
        let right = try XCTUnwrap(HostCardPointer.layout(plate: CGRect(x: 685, y: 300, width: 304, height: 240), ring: ring))
        XCTAssertEqual(right.side, .right)
        XCTAssertEqual(right.arrow[1].x, ring.minX - 2, accuracy: 0.001, "tip stops 2 pt before the ring")
        XCTAssertEqual(right.arrow[0].x, 989 - 1, accuracy: 0.001, "base overlaps the plate by 1 pt")
        XCTAssertEqual(right.arrow[1].y, ring.midY, accuracy: 0.001)
        XCTAssertEqual(abs(right.arrow[0].y - right.arrow[2].y), 16, accuracy: 0.001)
        XCTAssertTrue(right.panel.contains(CGRect(x: 685, y: 300, width: 304, height: 240)))
        let left = try XCTUnwrap(HostCardPointer.layout(plate: CGRect(x: 1056, y: 300, width: 304, height: 240), ring: ring))
        XCTAssertEqual(left.side, .left); XCTAssertEqual(left.arrow[1].x, ring.maxX + 2, accuracy: 0.001)
        let up = try XCTUnwrap(HostCardPointer.layout(plate: CGRect(x: 870, y: 100, width: 304, height: 288), ring: ring))
        XCTAssertEqual(up.side, .up); XCTAssertEqual(up.arrow[1].y, ring.minY - 2, accuracy: 0.001)
        let down = try XCTUnwrap(HostCardPointer.layout(plate: CGRect(x: 870, y: 456, width: 304, height: 200), ring: ring))
        XCTAssertEqual(down.side, .down); XCTAssertEqual(down.arrow[1].y, ring.maxY + 2, accuracy: 0.001)
        // Near a plate corner the arrow stays 16 pt inside the plate edge.
        let low = try XCTUnwrap(HostCardPointer.layout(plate: CGRect(x: 685, y: 410, width: 304, height: 240), ring: ring))
        XCTAssertEqual(low.arrow[1].y, 410 + 16, accuracy: 0.001)
        XCTAssertNil(HostCardPointer.layout(plate: CGRect(x: 990, y: 300, width: 304, height: 240), ring: ring), "overlapping plate: no arrow")
    }
}
