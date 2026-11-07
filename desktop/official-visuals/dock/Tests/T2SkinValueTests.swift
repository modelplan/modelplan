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

    /// DOCK-3.1-11: the seeded grain's constants.
    func testFaceGrainConstants() {
        XCTAssertEqual(T2Grain.seed, 23); XCTAssertEqual(T2Grain.octaves, 3); XCTAssertEqual(T2Grain.opacity, 0.018)
        XCTAssertEqual(T2Grain.frequencyX, 0.91); XCTAssertEqual(T2Grain.frequencyY, 0.73)
    }

    /// DOCK-3.1-11: #151d23, #363f44, #263239, #101b24, #030911 at 0, .17, .43, .74 and 1.
    func testFaceGradientStops() {
        XCTAssertEqual(T2FaceGradient.inks, [[0x15, 0x1d, 0x23], [0x36, 0x3f, 0x44], [0x26, 0x32, 0x39], [0x10, 0x1b, 0x24], [0x03, 0x09, 0x11]])
        XCTAssertEqual(T2FaceGradient.locations, [0, 0.17, 0.43, 0.74, 1])
    }

    /// DOCK-3.1-29: 18 arc px inside the tip opposite the ignition, at half the tip width, never under 9.
    func testGripSitsInsideTheOppositeTip() throws {
        for diameter in [CGFloat(36), 44, 52] {
            for (edge, atEnd) in [(T2Edge.right, false), (.left, false), (.bottom, true), (.top, true)] {
                let g = try T2Geometry.make(subscriptions: [.init(id: "member-a")], input: .init(coordinates: .init(edge: edge, width: 1470, height: 956, menuBarExclusion: 26), diameter: diameter, ignitionAtEnd: atEnd))
                let unit = diameter / 52
                XCTAssertEqual(g.gripArc, atEnd ? g.start + 18 * unit : g.end - 18 * unit, accuracy: 1e-6)
                XCTAssertGreaterThanOrEqual(g.gripDepth, 9 * unit - 1e-6)
            }
        }
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
