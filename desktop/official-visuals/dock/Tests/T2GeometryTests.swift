// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
import XCTest
import CoreGraphics
@testable import ModelPlanOfficialDock

final class T2GeometryTests: XCTestCase {
    func testEdgeMappingUsesOneTopLeftCoordinateTransform() {
        let expected: [(T2Edge, CGPoint, CGVector)] = [
            (.right, CGPoint(x: 970, y: 220), CGVector(dx: -30, dy: 20)),
            (.left, CGPoint(x: 30, y: 220), CGVector(dx: 30, dy: 20)),
            (.bottom, CGPoint(x: 220, y: 770), CGVector(dx: 20, dy: -30)),
            (.top, CGPoint(x: 220, y: 54), CGVector(dx: 20, dy: 30))
        ]
        for (edge, point, direction) in expected {
            let c = T2EdgeCoordinates(edge: edge, width: 1000, height: 800, menuBarExclusion: 24)
            XCTAssertEqual(c.point(along: 20, inward: 30, midpoint: 200), point)
            let actual = c.direction(along: 20, inward: 30)
            XCTAssertEqual(actual.dx, direction.dx)
            XCTAssertEqual(actual.dy, direction.dy)
        }
    }

    func testAcceptedSamplingAndPhysicalWakeTargetAcrossNewSizes() throws {
        for edge in [T2Edge.right, .bottom] {
            for diameter in [CGFloat(36), 44, 52] {
                for count in [1, 4, 7] {
                    let rows = (0..<count).map { T2Subscription(id: "synthetic-\($0)") }
                    let coordinates = T2EdgeCoordinates(edge: edge, width: 1470, height: 956, menuBarExclusion: 26)
                    let geometry = try T2Geometry.make(subscriptions: rows,
                        input: T2GeometryInput(coordinates: coordinates, diameter: diameter))
                    XCTAssertEqual(geometry.outline.count, 962)
                    XCTAssertEqual(geometry.outlineLocal.count, 962)
                    XCTAssertEqual(geometry.shown.map(\.id) + geometry.overflow.map(\.id), rows.map(\.id))
                    if edge == .right {
                        XCTAssertEqual(geometry.stations[0].centre.x, 1470 - geometry.freeDepth / 2, accuracy: 0.000001)
                    } else {
                        XCTAssertEqual(geometry.stations[0].centre.y, 956 - geometry.freeDepth / 2, accuracy: 0.000001)
                    }
                    XCTAssertEqual(geometry.buttonOverhang, 0.4, accuracy: 1.0 / 4096)
                    XCTAssertEqual(geometry.clockRadius, diameter / 2 + 3 * diameter / 52)
                    XCTAssertTrue(geometry.outline.allSatisfy { $0.x.isFinite && $0.y.isFinite })
                }
            }
        }
        XCTAssertEqual(T2GeometryConstants.wakeDepth, 20)
    }

    func testOverflowPreservesIdentityRatherThanShrinkingStations() throws {
        let rows = (0..<30).map { T2Subscription(id: "synthetic-\($0)", alias: "账户\($0)") }
        let c = T2EdgeCoordinates(edge: .right, width: 1000, height: 500, menuBarExclusion: 26)
        let result = try T2Geometry.make(subscriptions: rows, input: T2GeometryInput(coordinates: c, diameter: 52))
        XCTAssertFalse(result.overflow.isEmpty)
        XCTAssertEqual(result.shown.map(\.id) + result.overflow.map(\.id), rows.map(\.id))
        XCTAssertEqual(result.stations.filter(\.isOverflow).count, 1)
        XCTAssertEqual(result.stationDepth, 40)
    }

    func testInvalidDimensionsAndDuplicateIdentitiesRefuse() {
        let c = T2EdgeCoordinates(edge: .right, width: 1000, height: 800, menuBarExclusion: 26)
        XCTAssertThrowsError(try T2Geometry.make(subscriptions: [], input: T2GeometryInput(coordinates: c, diameter: 64)))
        XCTAssertThrowsError(try T2Geometry.make(subscriptions: [.init(id: "same"), .init(id: "same")],
            input: T2GeometryInput(coordinates: c)))
    }

    func testIgnitionControlRegistersTheGuardInRasterLocalCoordinates() throws {
        for edge in [T2Edge.left, .right, .bottom] {
            for diameter in [CGFloat(36), 44, 52] {
                for count in [1, 4, 7] {
                    let c = T2EdgeCoordinates(edge: edge, width: 1470, height: 956, menuBarExclusion: 26)
                    let rows = (0..<count).map { T2Subscription(id: "synthetic-\($0)") }
                    let geometry = try T2Geometry.make(subscriptions: rows, input: T2GeometryInput(coordinates: c, diameter: diameter))
                    let path = CGMutablePath(); path.addLines(between: geometry.outline); path.closeSubpath()
                    let raster = path.boundingBoxOfPath.union(geometry.ignitionBounds).insetBy(dx: -18, dy: -18)
                    let target = try geometry.consoleButtonRect(in: raster)
                    XCTAssertEqual(target.midX + raster.minX, geometry.button.x, accuracy: 1e-7)
                    XCTAssertEqual(target.midY + raster.minY, geometry.button.y, accuracy: 1e-7)
                    XCTAssertEqual(target.width, 34 * diameter / 52, accuracy: 1e-7)
                    XCTAssertEqual(target.height, target.width, accuracy: 1e-7)
                    XCTAssertTrue(CGRect(origin: .zero, size: raster.size).contains(target))
                    XCTAssertThrowsError(try geometry.consoleButtonRect(in:
                        CGRect(x: geometry.button.x, y: geometry.button.y, width: 1, height: 1)))
                }
            }
        }
    }
}
