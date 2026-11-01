// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
import XCTest
import AppKit
import ModelPlanDock
@testable import ModelPlanOfficialDock

final class T2OracleTests: XCTestCase {
    // DOCK-3.1-05/-07/-08/-12/-15/-16/-17/-22/-23/-29.
    // Fixtures are outputs of the pinned study JavaScript, not this Swift port.
    func testEveryNativeSampleMatchesStudyAcrossSizesEdgesAndOverflow() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "geometry-oracle", withExtension: "json"))
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let cases = try XCTUnwrap(root["cases"] as? [[String: Any]])
        XCTAssertEqual(cases.count, 45)
        for test in cases {
            let edgeName = try XCTUnwrap(test["edge"] as? String)
            let edge: T2Edge = edgeName == "right" ? .right : edgeName == "left" ? .left : .bottom
            let count = try XCTUnwrap(test["count"] as? Int)
            let diameter = CGFloat(try XCTUnwrap(test["D"] as? Double))
            let aliases = test["aliases"] as? Bool ?? false
            let rows = (0..<count).map { T2Subscription(id: "synthetic-\($0)", alias: aliases ? "账户\($0)" : "") }
            let c = T2EdgeCoordinates(edge: edge, width: 1470, height: 956, menuBarExclusion: 26)
            let actual = try T2Geometry.make(subscriptions: rows, input: T2GeometryInput(coordinates: c, diameter: diameter))
            let outline = try XCTUnwrap(test["outline"] as? [[Double]])
            XCTAssertEqual(actual.outline.count, outline.count)
            for (point, reference) in zip(actual.outline, outline) {
                XCTAssertEqual(point.x, reference[0], accuracy: 1e-7)
                XCTAssertEqual(point.y, reference[1], accuracy: 1e-7)
            }
            let stations = try XCTUnwrap(test["stations"] as? [[String: Any]])
            XCTAssertEqual(actual.stations.count, stations.count)
            for (station, reference) in zip(actual.stations, stations) {
                XCTAssertEqual(station.centre.x, try XCTUnwrap(reference["x"] as? Double), accuracy: 1e-7)
                XCTAssertEqual(station.centre.y, try XCTUnwrap(reference["y"] as? Double), accuracy: 1e-7)
                let readout = try XCTUnwrap(reference["readout"] as? [Double])
                XCTAssertEqual(station.readoutCentre.x, readout[0], accuracy: 1e-7)
                XCTAssertEqual(station.readoutCentre.y, readout[1], accuracy: 1e-7)
                XCTAssertEqual(station.pitch, try XCTUnwrap(reference["pitch"] as? Double), accuracy: 1e-7)
            }
            XCTAssertEqual(actual.shown.map(\.id), test["shown"] as? [String])
            XCTAssertEqual(actual.overflow.map(\.id), test["overflow"] as? [String])
            let button = try XCTUnwrap(test["button"] as? [Double])
            XCTAssertEqual(actual.button.x, button[0], accuracy: 1e-7)
            XCTAssertEqual(actual.button.y, button[1], accuracy: 1e-7)
            XCTAssertEqual(actual.buttonOverhang, try XCTUnwrap(test["overhang"] as? Double), accuracy: 1e-12)
            XCTAssertEqual(actual.gap, try XCTUnwrap(test["gap"] as? Double), accuracy: 1e-7)
            XCTAssertEqual(actual.span, try XCTUnwrap(test["span"] as? Double), accuracy: 1e-7)
        }
    }

    func testTimeRingUsesTheUnchanged52PointNozzleScale() throws {
        let now = Date(timeIntervalSince1970: 1_792_506_300)
        var input = DockInstrumentInput(id: "synthetic", name: "Synthetic", windows: [
            .init(id: "weekly", period: .week, label: "Weekly", remainingPercent: 76,
                  resetsAt: now.addingTimeInterval(7410 * 60), durationSeconds: 10080 * 60)])
        input.dataState = .fresh
        let reading = try DockInstrumentProjection.evaluate(input, now: now)
        XCTAssertEqual(reading.litTimePoints(positions: 37), 28)
        for diameter in [CGFloat(36), 44, 52] {
            let coordinates = T2EdgeCoordinates(edge: .right, width: 1470, height: 956, menuBarExclusion: 26)
            let geometry = try T2Geometry.make(subscriptions: [.init(id: "synthetic")], input: .init(coordinates: coordinates, diameter: diameter))
            let skin = try T2DockSkin.make(geometry: geometry, rows: [reading], showsPercentages: true)
            XCTAssertEqual(skin.readoutPalette?["normal"], "lcdWhite")
            let white = try XCTUnwrap(skin.palette["lcdWhite"])
            XCTAssertEqual(white.r, 233.0 / 255.0, accuracy: 1e-9)
            XCTAssertEqual(white.g, 237.0 / 255.0, accuracy: 1e-9)
            XCTAssertEqual(white.b, 240.0 / 255.0, accuracy: 1e-9)
            let clock = try XCTUnwrap(skin.stations.first?.clock)
            XCTAssertEqual(clock.positions, 37)
            XCTAssertEqual(clock.radius, 28.2 * diameter / 52, accuracy: 1e-9)
            XCTAssertEqual(clock.dotRadius, 0.65 * diameter / 52, accuracy: 1e-9)
        }
    }

    func testSingleWindowBackingUsesOuterRingRatherThanAbsentInnerRing() throws {
        let now = Date(timeIntervalSince1970: 1_792_506_300)
        var input = DockInstrumentInput(id: "single", name: "Synthetic", windows: [
            .init(id: "monthly", period: .month, label: "Month", remainingPercent: 61,
                  resetsAt: nil, durationSeconds: nil)])
        input.dataState = .fresh
        let reading = try DockInstrumentProjection.evaluate(input, now: now)
        XCTAssertNil(reading.inner)
        for diameter in [CGFloat(36), 44, 52] {
            let coordinates = T2EdgeCoordinates(edge: .right, width: 1470, height: 956, menuBarExclusion: 26)
            let geometry = try T2Geometry.make(subscriptions: [.init(id: "single")], input: .init(coordinates: coordinates, diameter: diameter))
            let skin = try T2DockSkin.make(geometry: geometry, rows: [reading], showsPercentages: true)
            let station = try XCTUnwrap(skin.stations.first)
            let unit = diameter / 52
            let expectedOuter = diameter / 2 - unit - diameter * 0.058 / 2
            XCTAssertEqual(station.outer.radius, expectedOuter, accuracy: 1e-9)
            XCTAssertEqual(try XCTUnwrap(station.singleWindowCaseInnerRadius), expectedOuter - diameter * 0.058 / 2 - unit, accuracy: 1e-9)
            XCTAssertGreaterThan(try XCTUnwrap(station.singleWindowCaseInnerRadius), station.caseInnerRadius)
        }
    }

    func testOriginalP1LayersDepthAndBetaMarkAreExplicit() throws {
        let now = Date(timeIntervalSince1970: 1_792_506_300)
        var input = DockInstrumentInput(id: "synthetic", name: "GLM", windows: [])
        input.vendorResourceKey = "zhipu"
        let reading = try DockInstrumentProjection.evaluate(input, now: now)
        let geometry = try T2Geometry.make(subscriptions: [.init(id: "synthetic")], input: .init(coordinates: .init(edge: .right, width: 1470, height: 956, menuBarExclusion: 26)))
        let neutral = try T2DockSkin.make(geometry: geometry, rows: [reading], showsPercentages: true)
        let beta = try T2DockSkin.make(geometry: geometry, rows: [reading], showsPercentages: true, zaiMarkEnabled: true)
        let station = try XCTUnwrap(beta.stations.first)
        XCTAssertNil(neutral.stations.first?.glyphs["zhipu"])
        XCTAssertEqual(station.glyphs["zhipu"], "logo-zai-white")
        XCTAssertEqual(station.layers, ["a1-01-bell-wall-44px@3x.webp", "a1-03-deep-centre-44px@3x.webp", "a1-02-throat-lip-44px@3x.webp", "a1-04-exit-lip-44px@3x.webp"])
        let depth = try XCTUnwrap(station.radialOverlay)
        XCTAssertEqual(depth.alphas.count, 65)
        XCTAssertEqual(depth.alphas[0], 1 - 0.1 * exp(-4.078), accuracy: 1e-7)
        XCTAssertEqual(depth.alphas[64], 0, accuracy: 1e-9)
    }

    func testStaticNoiseHasSVGNeutralLatticeAndNoPerRenderRandomness() {
        let noise = T2Grain()
        XCTAssertEqual(noise.channels(x: 0, y: 0), [0.5, 0.5, 0.5, 0.5])
        let first = noise.channels(x: 32.25, y: 17.75)
        XCTAssertEqual(first, T2Grain().channels(x: 32.25, y: 17.75))
        XCTAssertNotEqual(first, noise.channels(x: 32.75, y: 17.75))
        XCTAssertTrue(first.allSatisfy { (0...1).contains($0) })
    }

    @MainActor func testFaceRetinaOutputHasExpectedExtentAndAlpha() async throws {
        let coordinates = T2EdgeCoordinates(edge: .right, width: 300, height: 400, menuBarExclusion: 26)
        let geometry = try T2Geometry.make(subscriptions: [.init(id: "synthetic")], input: T2GeometryInput(coordinates: coordinates))
        let image = try T2FaceMaterial().render(geometry: geometry, viewport: CGRect(x: 200, y: 100, width: 100, height: 220), scale: 2)
        XCTAssertEqual(image.width, 200); XCTAssertEqual(image.height, 440)
        let pixels = NSBitmapImageRep(cgImage: image)
        XCTAssertEqual(try XCTUnwrap(pixels.colorAt(x: 0, y: 0)).alphaComponent, 0, accuracy: 1.0/255)
        XCTAssertEqual(try XCTUnwrap(pixels.colorAt(x: 196, y: 220)).alphaComponent, 1, accuracy: 1.0/255)
    }

    // DOCK-3.1-10/-11. This qualifies the isolated face layer, not a complete Dock.
    @MainActor func testFaceIsClippedOpaqueAndRepeatable() async throws {
        let c = T2EdgeCoordinates(edge: .right, width: 300, height: 400, menuBarExclusion: 26)
        let geometry = try T2Geometry.make(subscriptions: [.init(id: "synthetic")], input: T2GeometryInput(coordinates: c))
        let viewport = CGRect(x: 200, y: 100, width: 100, height: 220)
        let material = T2FaceMaterial()
        let first = try material.render(geometry: geometry, viewport: viewport, scale: 1)
        let second = try material.render(geometry: geometry, viewport: viewport, scale: 1)
        XCTAssertEqual(first.dataProvider?.data as Data?, second.dataProvider?.data as Data?)
        let pixels = NSBitmapImageRep(cgImage: first)
        XCTAssertEqual(try XCTUnwrap(pixels.colorAt(x: 0, y: 0)).alphaComponent, 0)
        XCTAssertEqual(try XCTUnwrap(pixels.colorAt(x: 98, y: 110)).alphaComponent, 1, accuracy: 1.0/255)
    }
}
