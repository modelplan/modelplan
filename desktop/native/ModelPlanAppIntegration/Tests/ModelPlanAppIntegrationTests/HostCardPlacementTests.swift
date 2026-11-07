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
            let card = try XCTUnwrap(HostCardPlacement.place(ring: anchor, hull: nil, unit: 1, size: size, available: available, edge: edge))
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
        XCTAssertNil(HostCardPlacement.place(ring: nil, hull: nil, unit: 1, size: size, available: bounds, edge: .right))
        XCTAssertNil(HostCardPlacement.place(ring: CGRect(x: 2, y: 2, width: 0, height: 40), hull: nil, unit: 1, size: size, available: bounds, edge: .right))
    }

    func testFlipsWhenPreferredSideCannotFit() throws {
        let bounds = CGRect(x: 0, y: 0, width: 500, height: 300)
        let anchor = CGRect(x: 10, y: 130, width: 40, height: 40)
        let card = try XCTUnwrap(HostCardPlacement.place(ring: anchor, hull: nil, unit: 1, size: CGSize(width: 200, height: 100), available: bounds, edge: .right))
        XCTAssertGreaterThan(card.minX, anchor.maxX)
    }

    /// Card-to-ring gap as the prototype's card.js place() (:173-201): 12 x D/52 from the painted
    /// clock ring; the face can push the card out to its inner side + 12 - 2 (the seam), never in.
    func testCardKeepsThePrototypeGapFromTheClockRingAndTheFace() throws {
        let available = CGRect(x: 0, y: 0, width: 1440, height: 900), size = CGSize(width: 304, height: 200)
        for unit in [CGFloat(36) / 52, CGFloat(44) / 52, 1] {
            // Right edge, D = 52 x unit: ring centre 40 x unit in, clock ring radius (26 + 2.2 + 0.75) x unit.
            let r = 28.95 * unit, centre = CGPoint(x: 1440 - 40 * unit, y: 450)
            let ring = CGRect(x: centre.x - r, y: centre.y - r, width: 2 * r, height: 2 * r)
            // A one-ring face (76 x unit deep): the ring governs.
            let shallow = CGRect(x: 1440 - 76 * unit, y: 380, width: 76 * unit, height: 200)
            let card = try XCTUnwrap(HostCardPlacement.place(ring: ring, hull: shallow, unit: unit, size: size, available: available, edge: .right))
            XCTAssertEqual(ring.minX - card.maxX, 12 * unit, accuracy: 0.001, "12 x unit from the clock ring, not the nozzle box")
            // A bulging face (an end ring of five, 80.47 x unit deep): the face governs.
            let deep = CGRect(x: 1440 - 80.47 * unit, y: 200, width: 80.47 * unit, height: 500)
            let pushed = try XCTUnwrap(HostCardPlacement.place(ring: ring, hull: deep, unit: unit, size: size, available: available, edge: .right))
            XCTAssertEqual(deep.minX + 10 * unit - pushed.maxX, 12 * unit, accuracy: 0.001)
            // Bottom edge (y up): the card sits above the ring by the same gap.
            let bottomRing = CGRect(x: 700, y: 40 * unit - r, width: 2 * r, height: 2 * r)
            let above = try XCTUnwrap(HostCardPlacement.place(ring: bottomRing, hull: CGRect(x: 600, y: 0, width: 300, height: 76 * unit), unit: unit, size: size, available: available, edge: .bottom))
            XCTAssertEqual(above.minY - bottomRing.maxY, 12 * unit, accuracy: 0.001)
        }
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
