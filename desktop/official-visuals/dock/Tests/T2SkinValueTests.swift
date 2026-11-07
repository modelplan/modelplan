// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
import CoreGraphics
import XCTest
import ModelPlanDock
@testable import ModelPlanOfficialDock

/// Values the production Dock draws from, checked on the real skin at every size.
/// DOCK-3.1-12, DOCK-3.1-22a, DOCK-3.2-02a, DOCK-3.2-03, DOCK-3.3-08 and DOCK-3.3-09.
final class T2SkinValueTests: XCTestCase {
    private func skin(_ diameter: CGFloat) throws -> (station: DockStationRecipe, skin: DockInstrumentSkin) {
        let geometry = try T2Geometry.make(subscriptions: [.init(id: "member-a")], input: .init(coordinates: .init(edge: .right, width: 1470, height: 956, menuBarExclusion: 26), diameter: diameter))
        let value = try T2DockSkin.make(geometry: geometry, rows: [], showsPercentages: true)
        return (try XCTUnwrap(value.stations.first), value)
    }

    func testReadoutBoxScalesWithTheNozzle() throws {
        for diameter in [CGFloat(36), 44, 52] {
            let box = try skin(diameter).station.readout
            XCTAssertEqual(box.width, 56 * diameter / 52, accuracy: 1e-6)
            XCTAssertEqual(box.height, 16 * diameter / 52, accuracy: 1e-6)
        }
    }

    func testRingNumbers() throws {
        for diameter in [CGFloat(36), 44, 52] {
            let station = try skin(diameter).station
            XCTAssertEqual(station.outer.width / diameter, 0.058, accuracy: 1e-6)
            XCTAssertEqual(station.inner.width / diameter, 0.031, accuracy: 1e-6)
            XCTAssertEqual(station.inner.opacity, 0.85); XCTAssertEqual(station.inner.trackOpacity, 0.65)
            XCTAssertEqual(station.inner.minimumVisibleFraction, 1.0 / 60, accuracy: 1e-9, "6 degrees")
            XCTAssertEqual(station.notchWidth / diameter, 0.014, accuracy: 1e-6)
        }
    }

    func testClockDotsAreWhiteAtSixtyPercentOnTheDarkBackRing() throws {
        for diameter in [CGFloat(36), 44, 52] {
            let (station, value) = try skin(diameter)
            XCTAssertEqual(station.clock.dotRadius, 0.65 * diameter / 52, accuracy: 1e-6)
            XCTAssertEqual(station.clock.backWidth, 1.5 * diameter / 52, accuracy: 1e-6)
            XCTAssertGreaterThanOrEqual(station.clock.positions, 24)
            let dot = try XCTUnwrap(value.palette["clock"]), back = try XCTUnwrap(value.palette["clockBack"])
            XCTAssertEqual([dot.r, dot.g, dot.b], [1, 1, 1]); XCTAssertEqual(dot.a, 0.6, accuracy: 1e-9)
            XCTAssertEqual(back.r * 255, 5, accuracy: 1e-6); XCTAssertEqual(back.a, 0.55, accuracy: 1e-9)
        }
    }

    func testReadoutInkFollowsTheStatusAndNoReadingIsDim() throws {
        let value = try skin(44).skin
        XCTAssertEqual(value.readoutPalette?["normal"], "lcdWhite", "white above the amber band")
        XCTAssertNil(value.readoutPalette?["warning"], "amber and red numbers use the status ink itself")
        XCTAssertNil(value.readoutPalette?["critical"])
        let dim = try XCTUnwrap(value.palette["unknown"]), white = try XCTUnwrap(value.palette["lcdWhite"])
        XCTAssertLessThan(dim.g, white.g * 0.7, "-- reads dimmer than a live number")
    }
}
