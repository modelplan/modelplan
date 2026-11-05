// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
// Copyright (c) 2026 ModelPlan. All rights reserved.
import XCTest
@testable import ModelPlanOfficialDock

final class V11GapTests: XCTestCase {
    func testV11VerticalStationsShrinkGapBeforeOverflow() throws {
        let subscriptions = (0..<3).map { T2Subscription(id: "synthetic-\($0)") }
        var compact: T2Geometry?
        for height in stride(from: 240, through: 900, by: 10) {
            let coordinates = T2EdgeCoordinates(edge: .right, width: 400, height: CGFloat(height), menuBarExclusion: 26)
            let input = T2GeometryInput(coordinates: coordinates, diameter: 52, showsPercentages: true)
            let geometry = try T2Geometry.make(subscriptions: subscriptions, input: input)
            if geometry.overflow.isEmpty && geometry.gap < 13.99 {
                compact = geometry
                break
            }
        }
        let compactSkin = try compact.map { try T2DockSkin.make(geometry: $0, rows: [], showsPercentages: true) }
        let options = XCTExpectedFailure.Options()
        options.isStrict = true
        XCTExpectFailure("V-11: vertical station gap does not shrink before overflow", options: options) {
            XCTAssertNotNil(compact, "A constrained vertical Dock must reduce its station gap before overflowing")
        }
        // Only the missing compact layout is expected to fail. Once one exists,
        // bad pitch or an overlapping readout must be an ordinary test failure.
        if let geometry = compact {
            XCTAssertGreaterThanOrEqual(geometry.gap, 6)
            XCTAssertLessThan(geometry.stations[0].pitch - 52 - 16, 13.99, "The real pitch must shrink, not just the reported gap")
        }
        if let skin = compactSkin {
            let stations = skin.stations.sorted { $0.centre.y < $1.centre.y }
            for (first, next) in zip(stations, stations.dropFirst()) {
                let extent = next.clock.radius + max(next.clock.dotRadius, next.clock.backWidth / 2)
                let overlapsHorizontally = first.readout.maxX > next.centre.x - extent && first.readout.minX < next.centre.x + extent
                if overlapsHorizontally {
                    XCTAssertLessThanOrEqual(first.readout.maxY, next.centre.y - extent,
                                             "A compact readout must not overlap the next clock")
                }
            }
        }
    }
}
