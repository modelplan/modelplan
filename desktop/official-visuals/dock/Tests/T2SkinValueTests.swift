// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
import CoreGraphics
import XCTest
import ModelPlanDock
@testable import ModelPlanOfficialDock
import AppKit

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

    /// G3-74 (owner, build 14b): the percentage number is larger than the prototype's 11 (13 x D/52, about
    /// +2 pt at the reference size), same font and weight, and a full "100%" still fits the 56 x D/52 readout
    /// box with room for the notice dot, at S, M and L, without clipping.
    func testPercentageNumberIsLargerAndStillFitsAtEverySize() throws {
        for diameter in [CGFloat(36), 44, 52] {
            let (station, value) = try skin(diameter), unit = diameter / 52
            XCTAssertEqual(value.text.size, 13 * unit, accuracy: 1e-6, "D\(diameter)")
            XCTAssertEqual(value.text.weight, 400); XCTAssertGreaterThan(value.text.size, 11 * unit)
            let font = CTFontCreateUIFontForLanguage(.userFixedPitch, value.text.size, nil)!
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: "100%", attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]))
            var a: CGFloat = 0, d: CGFloat = 0, l: CGFloat = 0
            let width = CGFloat(CTLineGetTypographicBounds(line, &a, &d, &l))
            XCTAssertLessThanOrEqual(width, station.readout.width * 0.7, "D\(diameter): 100% fits the box")
            // The notice dot sits 22 units right of the centre and is 12 wide: the text must end before it.
            XCTAssertLessThanOrEqual(width / 2, (22 - 6) * unit, "D\(diameter): clear of the notice dot")
            XCTAssertLessThanOrEqual(CTFontGetCapHeight(font), station.readout.height, "D\(diameter): glyphs fit the box height")
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

    /// D167 / DOCK-3.8-22: the dots are white 80 % (was 60 %), the cockpit's --time-dot-on; the backing stays 55 %.
    func testClockDotsAreWhiteAtEightyPercentOnTheDarkBackRing() throws {
        for diameter in [CGFloat(36), 44, 52] {
            let (station, value) = try skin(diameter)
            XCTAssertEqual(station.clock.dotRadius, 0.65 * diameter / 52, accuracy: 1e-6)
            XCTAssertEqual(station.clock.backWidth, 1.5 * diameter / 52, accuracy: 1e-6)
            XCTAssertGreaterThanOrEqual(station.clock.positions, 24)
            let dot = try XCTUnwrap(value.palette["clock"]), back = try XCTUnwrap(value.palette["clockBack"])
            XCTAssertEqual([dot.r, dot.g, dot.b], [1, 1, 1]); XCTAssertEqual(dot.a, 0.8, accuracy: 1e-9)
            XCTAssertEqual(station.clock.pixelSnap, true, "1x dots snap to device pixels")
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

    /// DOCK-3.1-15 (upright readouts) is in T2GeometryTests; DOCK-3.2-12: the ring's vendor mark is 0.27 D wide
    /// (owner D47), square and centred on the ring, at S, M and L.
    func testVendorGlyphIsPointTwoSevenOfDiameter() throws {
        for diameter in [CGFloat(36), 44, 52] {
            let station = try skin(diameter).station
            XCTAssertEqual(station.glyphRect.width, 0.27 * diameter, accuracy: 1e-6, "D\(diameter)")
            XCTAssertEqual(station.glyphRect.height, 0.27 * diameter, accuracy: 1e-6, "D\(diameter)")
            XCTAssertEqual(station.glyphRect.midX, station.centre.x, accuracy: 1e-6)
            XCTAssertEqual(station.glyphRect.midY, station.centre.y, accuracy: 1e-6)
        }
    }

    /// DOCK-3.1.1-11: the logo-to-flame keep-out. The throat (the radial overlay's radius) clears the mark's
    /// corner by at least 3 x D/52, at S, M and L.
    func testLogoToFlameKeepOutIsThreeUnits() throws {
        for diameter in [CGFloat(36), 44, 52] {
            let station = try skin(diameter).station, unit = diameter / 52
            let corner = station.glyphRect.width * 2.0.squareRoot() / 2
            let throat = try XCTUnwrap(station.radialOverlay).radius
            XCTAssertGreaterThanOrEqual(throat - corner, 3 * unit - 1e-6, "D\(diameter): keep-out is \((throat - corner) / unit) units")
        }
    }

    /// DOCK-3.1-20: layers back to front. Per station the bell wall, deep centre, throat lip and exit lip; then the
    /// ignition's contact shadow, night cap, inner contact shadow and recessed guard.
    func testLayerOrderBackToFront() throws {
        for diameter in [CGFloat(36), 44, 52] {
            let (station, value) = try skin(diameter)
            let size = diameter <= 44 ? 44 : 52
            XCTAssertEqual(station.layers, ["a1-01-bell-wall", "a1-03-deep-centre", "a1-02-throat-lip", "a1-04-exit-lip"].map { "\($0)-\(size)px@3x.webp" }, "D\(diameter)")
            XCTAssertEqual(value.fixedLayers.map(\.resource), ["a5-outer-contact-shadow-56x56@3x.png", "a5-cap-night-idle-44x44@3x.png", "a5-inner-contact-shadow-52x52@3x.png", "a5-recessed-guard-52x52@3x.png"], "D\(diameter)")
        }
    }

    /// DOCK-3.3-03: the percentage sits wholly on the shared aft surface with a scaled gap (at least 2 x D/52) to
    /// the clock numbers. The text ink clears the clock envelope on every edge, and on the side edges (where the
    /// readout sits under the ring) the whole readout box does too. The ink also lies inside the face outline.
    func testPercentageSitsOnTheAftSurfaceWithScaledGap() throws {
        for edge in [T2Edge.right, .left, .bottom, .top] {
            for diameter in [CGFloat(36), 44, 52] {
                for count in [1, 4] {
                    let unit = diameter / 52
                    let geometry = try T2Geometry.make(subscriptions: (0..<count).map { .init(id: "member-\($0)") }, input: .init(coordinates: .init(edge: edge, width: 1470, height: 956, menuBarExclusion: 26), diameter: diameter))
                    let value = try T2DockSkin.make(geometry: geometry, rows: [], showsPercentages: true)
                    let font = CTFontCreateUIFontForLanguage(.userFixedPitch, value.text.size, nil)!
                    let line = CTLineCreateWithAttributedString(NSAttributedString(string: "100%", attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]))
                    var a: CGFloat = 0, d: CGFloat = 0, l: CGFloat = 0
                    let inkWidth = CGFloat(CTLineGetTypographicBounds(line, &a, &d, &l)), inkHeight = CTFontGetCapHeight(font)
                    let outline = CGMutablePath(); outline.addLines(between: geometry.outline); outline.closeSubpath()
                    func distance(_ rect: CGRect, from point: CGPoint) -> CGFloat {
                        hypot(max(rect.minX - point.x, 0, point.x - rect.maxX), max(rect.minY - point.y, 0, point.y - rect.maxY))
                    }
                    for station in value.stations {
                        let label = "\(edge) D\(diameter) x\(count)"
                        let envelope = station.clock.radius + max(station.clock.dotRadius, station.clock.backWidth / 2)
                        let ink = CGRect(x: station.readout.midX - inkWidth / 2, y: station.readout.midY - inkHeight / 2, width: inkWidth, height: inkHeight)
                        XCTAssertGreaterThanOrEqual(distance(ink, from: station.centre) - envelope, 2 * unit - 1e-6, "\(label): text clears the clock numbers")
                        if edge == .left || edge == .right {
                            XCTAssertGreaterThanOrEqual(distance(station.readout, from: station.centre) - envelope, 2 * unit - 1e-6, "\(label): readout box clears the clock numbers")
                        }
                        for corner in [CGPoint(x: ink.minX, y: ink.minY), CGPoint(x: ink.maxX, y: ink.minY), CGPoint(x: ink.minX, y: ink.maxY), CGPoint(x: ink.maxX, y: ink.maxY)] {
                            XCTAssertTrue(outline.contains(corner), "\(label): text corner \(corner) is on the aft surface")
                        }
                    }
                }
            }
        }
    }
}
