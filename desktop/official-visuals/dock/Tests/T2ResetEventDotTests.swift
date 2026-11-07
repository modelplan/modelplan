// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
import CoreGraphics
import XCTest
@testable import ModelPlanOfficialDock

final class T2ResetEventDotTests: XCTestCase {
    func testReadoutAndRimAnchorsUseTheSameInstrumentSkin() throws {
        for edge in [T2Edge.left, .right, .bottom] {
            for diameter in [CGFloat(36), 44, 52] {
                let geometry = try T2Geometry.make(subscriptions: [.init(id: "member-a")], input: .init(coordinates: .init(edge: edge, width: 1470, height: 956, menuBarExclusion: 26), diameter: diameter))
                let station = try XCTUnwrap(geometry.stations.first)
                let withReading = try T2DockSkin.make(geometry: geometry, rows: [], showsPercentages: true).stations[0]
                let rim = try T2DockSkin.make(geometry: geometry, rows: [], showsPercentages: false).stations[0]
                XCTAssertEqual(withReading.eventRect.midX, station.readoutCentre.x + 22 * diameter / 52, accuracy: 1e-7)
                XCTAssertEqual(withReading.eventRect.midY, station.readoutCentre.y, accuracy: 1e-7)
                XCTAssertEqual(rim.eventRect.midX, station.centre.x + diameter * 0.25, accuracy: 1e-7)
                XCTAssertEqual(rim.eventRect.midY, station.centre.y - diameter * 0.433013, accuracy: 1e-7)
                for skin in [withReading, rim] {
                    XCTAssertEqual(try XCTUnwrap(skin.eventSolidDiameter), 5 * diameter / 52, accuracy: 1e-7)
                    XCTAssertEqual(try XCTUnwrap(skin.eventHollowDiameter), 6 * diameter / 52, accuracy: 1e-7)
                    XCTAssertEqual(try XCTUnwrap(skin.eventStrokeWidth), 1.2 * diameter / 52, accuracy: 1e-7)
                }
            }
        }
    }
    func testOverflowHasARegisteredNoticeAnchor() throws {
        let geometry = try T2Geometry.make(subscriptions: (0..<30).map { .init(id: "member-\($0)") }, input: .init(coordinates: .init(edge: .right, width: 1470, height: 956, menuBarExclusion: 26), diameter: 52))
        XCTAssertFalse(geometry.overflow.isEmpty)
        let skin = try T2DockSkin.make(geometry: geometry, rows: [], showsPercentages: false)
        let overflow = try XCTUnwrap(skin.stations.first { $0.overflowCount != nil })
        XCTAssertEqual(overflow.overflowNoticeKey, "__t2_overflow_notice__")
        let position = try XCTUnwrap(geometry.stations.first { $0.isOverflow })
        let readingSkin = try T2DockSkin.make(geometry: geometry, rows: [], showsPercentages: true)
        let readingOverflow = try XCTUnwrap(readingSkin.stations.first { $0.overflowCount != nil })
        XCTAssertEqual(readingOverflow.eventRect.midX, position.centre.x + 52 * 0.25, accuracy: 1e-7)
        XCTAssertEqual(readingOverflow.eventRect.midY, position.centre.y - 52 * 0.433013, accuracy: 1e-7)
    }
}
