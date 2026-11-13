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
                // D48: the study puts the ring at the station depth; the owner moved it halfway
                // across the face. Only the inward axis differs, and the readout moves with it.
                let x = try XCTUnwrap(reference["x"] as? Double), y = try XCTUnwrap(reference["y"] as? Double)
                let inward = edge == .right ? 1470 - x : edge == .left ? x : 956 - y
                let shift = (Double(actual.freeDepth) - Double(actual.stationDepth) - inward) / 2
                let dx = edge == .right ? -shift : edge == .left ? shift : 0, dy = edge == .bottom ? -shift : 0
                XCTAssertEqual(station.centre.x, x + dx, accuracy: 1e-7)
                XCTAssertEqual(station.centre.y, y + dy, accuracy: 1e-7)
                let readout = try XCTUnwrap(reference["readout"] as? [Double])
                XCTAssertEqual(station.readoutCentre.x, readout[0] + dx, accuracy: 1e-7)
                XCTAssertEqual(station.readoutCentre.y, readout[1] + dy, accuracy: 1e-7)
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
                  resetsAt: now.addingTimeInterval(7410.0 * 60), durationSeconds: 10080.0 * 60)])
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
        XCTAssertEqual(neutral.stations.first?.glyphs["zhipu"], "logo-zhipu", "D43: Zhipu has its own mark when the beta mark is off")
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

    private func srgb(_ image: CGImage, x: Int, y: Int) -> NSColor? {
        NSBitmapImageRep(cgImage: image).colorAt(x: x, y: y)?.usingColorSpace(.sRGB)
    }

    /// DOCK-3.1-13: a critical (red) readout is bare ink. The real renderer draws the same Dock with the readout
    /// switched off and on; the pixels of the 56 x 16 u readout box that change are only the glyph ink (a
    /// minority of the box), and the box's corners are untouched, so nothing is painted behind the text.
    @MainActor func testCriticalReadoutHasNoSeparateBacking() throws {
        let now = Date(timeIntervalSince1970: 1_792_506_300)
        var input = DockInstrumentInput(id: "member-a", name: "Synthetic", windows: [
            .init(id: "weekly", period: .week, label: "Weekly", remainingPercent: 3, resetsAt: nil, durationSeconds: nil)])
        input.dataState = .fresh
        let reading = try DockInstrumentProjection.evaluate(input, now: now)
        XCTAssertEqual(reading.status, .critical)
        let store = try DockArtworkStore(root: FileManager.default.temporaryDirectory, manifest: DockResourceManifest(files: [:]))
        let scale = 3
        for diameter in [CGFloat(36), 44, 52] {
            let unit = diameter / 52
            let geometry = try T2Geometry.make(subscriptions: [.init(id: "member-a")], input: .init(coordinates: .init(edge: .right, width: 1470, height: 956, menuBarExclusion: 26), diameter: diameter))
            var skin = try T2DockSkin.make(geometry: geometry, rows: [reading], showsPercentages: true)
            // Artwork and the bundled mono font are not needed for a backing check: use the system font, no layers.
            skin.fixedLayers = []
            skin.text = try JSONDecoder().decode(DockTextRecipe.self, from: Data("{\"useSystemUIFont\":true,\"size\":\(skin.text.size),\"weight\":400}".utf8))
            for index in skin.stations.indices { skin.stations[index].layers = []; skin.stations[index].radialOverlay = nil }
            let box = try XCTUnwrap(skin.stations.first).readout
            func render(readout: Bool) throws -> CGImage {
                var copy = skin
                copy.stations[0].showsReadout = readout
                return try DockInstrumentRenderer(resources: store).render(skin: copy, readings: ["member-a": reading], scale: scale).image
            }
            let bare = try render(readout: false), withText = try render(readout: true)
            let x0 = Int((box.minX - skin.bounds.minX) * CGFloat(scale)), y0 = Int((box.minY - skin.bounds.minY) * CGFloat(scale))
            let w = Int(box.width * CGFloat(scale)), h = Int(box.height * CGFloat(scale))
            func changed(_ x: Int, _ y: Int) throws -> Bool {
                let a = try XCTUnwrap(srgb(bare, x: x, y: y)), b = try XCTUnwrap(srgb(withText, x: x, y: y))
                return abs(a.redComponent - b.redComponent) + abs(a.greenComponent - b.greenComponent) + abs(a.blueComponent - b.blueComponent) + abs(a.alphaComponent - b.alphaComponent) > 0.02
            }
            var changedCount = 0
            for y in y0..<(y0 + h) { for x in x0..<(x0 + w) { if try changed(x, y) { changedCount += 1 } } }
            XCTAssertGreaterThan(changedCount, 0, "D\(diameter): the readout text is drawn")
            XCTAssertLessThan(Double(changedCount) / Double(w * h), 0.5, "D\(diameter): only glyph ink changes, not the whole box")
            let inset = Int(2 * unit * CGFloat(scale))
            for (x, y) in [(x0 + inset, y0 + inset), (x0 + w - 1 - inset, y0 + inset), (x0 + inset, y0 + h - 1 - inset), (x0 + w - 1 - inset, y0 + h - 1 - inset)] {
                XCTAssertFalse(try changed(x, y), "D\(diameter): corner (\(x), \(y)) of the readout box is unbacked")
            }
        }
    }

    /// THM-2.4-05: the Dock is the same in day and night. The face has no theme input; rendered under the Aqua and
    /// the Dark Aqua appearance it is byte-identical, and so is the whole skin (ignition art included).
    @MainActor func testFaceIsIdenticalInAquaAndDarkAqua() throws {
        let c = T2EdgeCoordinates(edge: .right, width: 300, height: 400, menuBarExclusion: 26)
        let geometry = try T2Geometry.make(subscriptions: [.init(id: "synthetic")], input: T2GeometryInput(coordinates: c))
        let viewport = CGRect(x: 200, y: 100, width: 100, height: 220)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        var faces = [Data](), skins = [Data]()
        for name in [NSAppearance.Name.aqua, .darkAqua] {
            let appearance = try XCTUnwrap(NSAppearance(named: name))
            var face: Data?, skin: Data?, failure: Error?
            appearance.performAsCurrentDrawingAppearance {
                do {
                    face = try T2FaceMaterial().render(geometry: geometry, viewport: viewport, scale: 1).dataProvider?.data as Data?
                    skin = try encoder.encode(T2DockSkin.make(geometry: geometry, rows: [], showsPercentages: true))
                } catch { failure = error }
            }
            XCTAssertNil(failure, "\(name)")
            faces.append(try XCTUnwrap(face, "\(name)")); skins.append(try XCTUnwrap(skin, "\(name)"))
        }
        XCTAssertEqual(faces[0], faces[1], "face pixels differ between Aqua and Dark Aqua")
        XCTAssertEqual(skins[0], skins[1], "skin differs between Aqua and Dark Aqua")
        let caps = try JSONDecoder().decode(DockInstrumentSkin.self, from: skins[1]).fixedLayers.map(\.resource).filter { $0.contains("cap") }
        XCTAssertEqual(caps, ["a5-cap-night-idle-44x44@3x.png"], "the night cap in both appearances")
    }

    /// DOCK-3.1-21: no perimeter rim, crown, bright stroke or face extension. Away from the grip, every pixel clearly
    /// outside the body outline is transparent, and the band just inside the outline is face-dark, not a bright stroke.
    @MainActor func testNoRimCrownOrStrokeOutsideTheBody() throws {
        let c = T2EdgeCoordinates(edge: .right, width: 300, height: 400, menuBarExclusion: 26)
        let geometry = try T2Geometry.make(subscriptions: [.init(id: "synthetic")], input: T2GeometryInput(coordinates: c))
        let viewport = CGRect(x: 200, y: 100, width: 100, height: 220)
        let image = try T2FaceMaterial().render(geometry: geometry, viewport: viewport, scale: 1)
        let outline = CGMutablePath(); outline.addLines(between: geometry.outline); outline.closeSubpath()
        let band = outline.copy(strokingWithWidth: 4, lineCap: .butt, lineJoin: .round, miterLimit: 10)
        let unit = geometry.input.diameter / 52
        var outside = 0, inBand = 0
        var worstOutsideAlpha: CGFloat = 0, brightestBand: CGFloat = 0
        for y in 0..<image.height {
            for x in 0..<image.width {
                let point = CGPoint(x: viewport.minX + CGFloat(x) + 0.5, y: viewport.minY + CGFloat(y) + 0.5)
                if hypot(point.x - geometry.grip.x, point.y - geometry.grip.y) < 20 * unit { continue }
                guard let colour = srgb(image, x: x, y: y) else { continue }
                if band.contains(point) {
                    guard outline.contains(point) else { continue }
                    inBand += 1
                    brightestBand = max(brightestBand, 0.2126 * colour.redComponent + 0.7152 * colour.greenComponent + 0.0722 * colour.blueComponent)
                } else if !outline.contains(point) {
                    outside += 1; worstOutsideAlpha = max(worstOutsideAlpha, colour.alphaComponent)
                }
            }
        }
        XCTAssertGreaterThan(outside, 1000); XCTAssertGreaterThan(inBand, 100)
        XCTAssertLessThanOrEqual(worstOutsideAlpha, 1.0 / 255, "nothing is painted outside the body")
        XCTAssertLessThan(brightestBand, 0.35, "no bright stroke along the outline (the face is #151d23 to #363f44)")
    }
}
