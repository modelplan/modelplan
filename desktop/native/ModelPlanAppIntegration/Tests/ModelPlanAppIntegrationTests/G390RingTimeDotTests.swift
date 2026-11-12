// SPDX-License-Identifier: MIT
import CoreGraphics
import Foundation
import ImageIO
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanDockResources
import ModelPlanOfficialDock

/// G3-90 / D167 / DOCK-3.8-22: the ring's time marks (clock dots) are white 80 % instead of 60 % on the unchanged
/// 55 % backing, and on a 1x display each dot is centred on a device pixel and covers at least that pixel.
/// CKP-FAD-19 (D150): the cockpit's quota-bar time dots already use white 80 % (--time-dot-on), so both match.
///
/// The rendered checks use the production T2 path (geometry, skin, official artwork, vendor marks, face
/// material) and composite the transparent raster over flat wallpapers, the way the desktop shows it.
/// The before/after board for the owner is written to
/// $RUNNER_TEMP/dock-instrument-checks/dock-visual/g3-90/ (the GUI leg archives dock-visual/).
@MainActor final class G390RingTimeDotTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let diameter: CGFloat = 44
    /// Flat wallpapers (grey level): dark, mid-grey and bright.
    private let wallpapers: [(name: String, grey: CGFloat)] = [("dark", 38), ("mid", 128), ("bright", 235)]

    // MARK: geometry

    /// The renderer's base transform for a raster of `bounds` at `scale` (translate, flip, scale, origin).
    private func base(_ bounds: CGRect, scale: CGFloat) -> CGAffineTransform {
        let height = ceil(bounds.height * scale)
        return CGAffineTransform(translationX: -bounds.minX, y: -bounds.minY)
            .concatenating(CGAffineTransform(scaleX: scale, y: -scale))
            .concatenating(CGAffineTransform(translationX: 0, y: height))
    }

    private func dotCentres(_ station: DockStationRecipe, count: Int? = nil) -> [CGPoint] {
        (0..<(count ?? station.clock.positions)).map { i in
            let a = Double(i) * 2 * .pi / Double(station.clock.positions)
            return CGPoint(x: station.centre.x + sin(a) * station.clock.radius, y: station.centre.y - cos(a) * station.clock.radius)
        }
    }

    /// At scale 1 every dot centre lands on a device-pixel centre and its radius is at least √½ device px
    /// (so at least 0.5), at every size and edge, at rest and under a hover pose. 2x keeps the recipe's dot.
    func testOneXDotsLandOnPixelCentresWithAtLeastOneFullPixel() throws {
        func fraction(_ v: CGFloat) -> CGFloat { v - v.rounded(.down) }
        for diameter in [CGFloat(36), 44, 52] {
            for edge in [T2Edge.right, .left, .bottom] {
                let geometry = try T2Geometry.make(subscriptions: [.init(id: "member-a")],
                    input: .init(coordinates: .init(edge: edge, width: 1470, height: 956, menuBarExclusion: 26), diameter: diameter))
                let skin = try T2DockSkin.make(geometry: geometry, rows: [], showsPercentages: true)
                let station = try XCTUnwrap(skin.stations.first)
                XCTAssertEqual(station.clock.pixelSnap, true)
                let rest = base(skin.bounds, scale: 1)
                let pose = CGAffineTransform(translationX: -station.centre.x, y: -station.centre.y)
                    .concatenating(CGAffineTransform(scaleX: 1.25, y: 1.25))
                    .concatenating(CGAffineTransform(translationX: station.centre.x - 3.3, y: station.centre.y + 1.7))
                for (label, toDevice) in [("rest", rest), ("pose", pose.concatenating(rest))] {
                    for p in dotCentres(station) {
                        let (centre, radius) = DockClockDotPlacement.dot(centre: p, radius: station.clock.dotRadius, snap: true, scale: 1, toDevice: toDevice)
                        let device = centre.applying(toDevice), pixel = hypot(toDevice.a, toDevice.b)
                        let tag = "D\(diameter) \(edge) \(label) \(p)"
                        XCTAssertEqual(fraction(device.x), 0.5, accuracy: 1e-6, tag)
                        XCTAssertEqual(fraction(device.y), 0.5, accuracy: 1e-6, tag)
                        XCTAssertGreaterThanOrEqual(radius * pixel, 0.5, tag)
                        XCTAssertGreaterThanOrEqual(radius * pixel, CGFloat(0.5).squareRoot() - 1e-9, "covers the whole centre pixel: \(tag)")
                        XCTAssertLessThanOrEqual(hypot(device.x - p.applying(toDevice).x, device.y - p.applying(toDevice).y), CGFloat(0.5).squareRoot() + 1e-9, "moves at most half a pixel diagonal: \(tag)")
                    }
                }
                for p in dotCentres(station) {
                    let two = DockClockDotPlacement.dot(centre: p, radius: station.clock.dotRadius, snap: true, scale: 2, toDevice: base(skin.bounds, scale: 2))
                    XCTAssertEqual(two.centre, p, "2x keeps the exact position"); XCTAssertEqual(two.radius, station.clock.dotRadius, "2x keeps the size")
                    let off = DockClockDotPlacement.dot(centre: p, radius: station.clock.dotRadius, snap: false, scale: 1, toDevice: rest)
                    XCTAssertEqual(off.centre, p, "skins without pixelSnap are unchanged"); XCTAssertEqual(off.radius, station.clock.dotRadius)
                }
            }
        }
    }

    /// CKP-FAD-19 (D150): the cockpit's quota-bar time dots and the ring's clock dots are the same white 80 %.
    func testCockpitTimeDotsMatchTheRingClockInk() throws {
        let css = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../cockpit/prototype/prototype-theme.css").standardizedFileURL
        let text = try String(contentsOf: css, encoding: .utf8)
        XCTAssertTrue(text.contains("--time-dot-on:rgba(255,255,255,.8)"), "cockpit --time-dot-on is white 80 %")
        let geometry = try T2Geometry.make(subscriptions: [.init(id: "member-a")],
            input: .init(coordinates: .init(edge: .right, width: 1470, height: 956, menuBarExclusion: 26), diameter: diameter))
        let ink = try XCTUnwrap(T2DockSkin.make(geometry: geometry, rows: [], showsPercentages: true).palette["clock"])
        XCTAssertEqual([ink.r, ink.g, ink.b], [1, 1, 1]); XCTAssertEqual(ink.a, 0.8, accuracy: 1e-9)
    }

    // MARK: rendering

    private func reading() throws -> DockInstrumentReading {
        var input = DockInstrumentInput(id: "member-a", name: "Codex", windows: [
            .init(id: "short", period: .fiveHour, label: "5h", remainingPercent: 62, resetsAt: now.addingTimeInterval(3 * 3600), durationSeconds: 18000)])
        input.vendorResourceKey = "openai"; input.dataState = .fresh
        return try DockInstrumentProjection.evaluate(input, now: now)
    }

    private struct Render { let image: CGImage; let skin: DockInstrumentSkin; let station: DockStationRecipe; let lit: Int; let scale: Int }

    /// `before: true` restores the pre-D167 recipe (white 60 %, no snapping) on the same production path.
    private func render(scale: Int, before: Bool) throws -> Render {
        let value = try reading()
        let geometry = try T2Geometry.make(subscriptions: [.init(id: value.subscriptionID)],
            input: .init(coordinates: .init(edge: .right, width: 1470, height: 956, menuBarExclusion: 26), diameter: diameter, showsPercentages: true))
        var skin = try T2DockSkin.make(geometry: geometry, rows: [value], showsPercentages: true)
        if before {
            skin.palette["clock"] = DockInk(1, 1, 1, 0.6)
            for index in skin.stations.indices { skin.stations[index].clock.pixelSnap = nil }
        }
        let artwork = try T2BundledArtwork.records().mapValues { DockResourceFile(path: $0.path, sha256: $0.sha256, bytes: $0.bytes) }
        let official = try DockArtworkStore(root: T2BundledArtwork.rootURL(), manifest: .init(files: artwork))
        let vendorManifest = try JSONDecoder().decode(DockResourceManifest.self, from: DockThirdPartyResources.manifestData(zaiMarkEnabled: false))
        let vendor = try DockArtworkStore(root: DockThirdPartyResources.rootURL(), manifest: vendorManifest)
        let material = T2FaceMaterial()
        let renderer = DockInstrumentRenderer(resources: official, supplementalResources: vendor) { supplied, scale in
            try material.render(geometry: geometry, viewport: supplied.bounds, scale: scale)
        }
        let image = try renderer.render(skin: skin, readings: [value.subscriptionID: value], scale: scale).image
        let station = try XCTUnwrap(skin.stations.first { $0.subscriptionID == value.subscriptionID })
        let lit = try XCTUnwrap(value.litTimePoints(positions: station.clock.positions))
        return Render(image: image, skin: skin, station: station, lit: lit, scale: scale)
    }

    /// The raster drawn 1:1 over a flat wallpaper; rows are stored top first.
    private struct Composite {
        let width: Int, height: Int, bytes: [UInt8]
        func rgb(_ x: Int, _ y: Int) -> (Double, Double, Double) {
            let i = (y * width + x) * 4; return (Double(bytes[i]), Double(bytes[i + 1]), Double(bytes[i + 2]))
        }
    }

    private func composite(_ image: CGImage, grey: CGFloat) throws -> Composite {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let ok = bytes.withUnsafeMutableBytes { raw -> Bool in
            guard let c = CGContext(data: raw.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            c.setFillColor(CGColor(srgbRed: grey / 255, green: grey / 255, blue: grey / 255, alpha: 1)); c.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
            c.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        XCTAssertTrue(ok)
        return Composite(width: image.width, height: image.height, bytes: bytes)
    }

    private func luminance(_ v: (Double, Double, Double)) -> Double {
        func lin(_ c: Double) -> Double { let s = c / 255; return s <= 0.04045 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(v.0) + 0.7152 * lin(v.1) + 0.0722 * lin(v.2)
    }
    private func contrast(_ a: Double, _ b: Double) -> Double { (max(a, b) + 0.05) / (min(a, b) + 0.05) }

    /// The device pixel that holds a dot's drawn centre (snapped at 1x for the new recipe).
    private func pixel(_ r: Render, _ p: CGPoint) -> (Int, Int) {
        let s = CGFloat(r.scale)
        var centre = p
        if r.station.clock.pixelSnap == true {
            centre = DockClockDotPlacement.dot(centre: p, radius: r.station.clock.dotRadius, snap: true, scale: r.scale, toDevice: base(r.skin.bounds, scale: s)).centre
        }
        return (Int(((centre.x - r.skin.bounds.minX) * s).rounded(.down)), Int(((centre.y - r.skin.bounds.minY) * s).rounded(.down)))
    }

    /// The rendered dot pixel is brighter than before at 1x and 2x, and on the backing it reaches at least 3:1
    /// (non-text contrast) over a mid-grey and a bright wallpaper. The backing reference is an unlit position on
    /// the 2x raster, where the 1.5-unit backing fully covers the sampled pixel.
    func testRenderedDotsAreBrighterAndReachThreeToOneOnTheBacking() throws {
        var backing = [String: Double]()
        let reference = try render(scale: 2, before: false)
        XCTAssertLessThan(reference.lit, reference.station.clock.positions, "the fixture leaves unlit positions")
        for wall in wallpapers {
            let c = try composite(reference.image, grey: wall.grey)
            let unlit = dotCentres(reference.station).suffix(from: reference.lit + 2).prefix(4)
            backing[wall.name] = unlit.map { luminance(c.rgb(pixel(reference, $0).0, pixel(reference, $0).1)) }.reduce(0, +) / Double(unlit.count)
        }
        for scale in [1, 2] {
            let before = try render(scale: scale, before: true), after = try render(scale: scale, before: false)
            XCTAssertEqual(before.lit, after.lit)
            for wall in wallpapers {
                let b = try composite(before.image, grey: wall.grey), a = try composite(after.image, grey: wall.grey)
                let lit = dotCentres(after.station, count: after.lit)
                let old = lit.map { luminance(b.rgb(pixel(before, $0).0, pixel(before, $0).1)) }
                let new = lit.map { luminance(a.rgb(pixel(after, $0).0, pixel(after, $0).1)) }
                let tag = "\(scale)x over \(wall.name)"
                XCTAssertGreaterThan(new.reduce(0, +) / Double(new.count), old.reduce(0, +) / Double(old.count) * 1.15, "brighter than before: \(tag)")
                XCTAssertGreaterThan(new.min() ?? 0, (old.min() ?? 0), "the faintest dot is brighter too: \(tag)")
                if wall.name != "dark" {
                    let back = try XCTUnwrap(backing[wall.name])
                    let worst = new.map { contrast($0, back) }.min() ?? 0
                    XCTAssertGreaterThanOrEqual(worst, 3, "≥ 3:1 against the backing: \(tag)")
                }
            }
        }
    }

    // MARK: before/after board

    /// Writes crops of the ring before and after D167 at 1x and 2x over dark, mid-grey and bright wallpapers,
    /// each at actual pixels, plus one magnified board (1x ×8, 2x ×4, nearest neighbour, same physical size).
    func testWriteBeforeAfterBoard() throws {
        let root = ProcessInfo.processInfo.environment["RUNNER_TEMP"].map { URL(fileURLWithPath: $0, isDirectory: true) } ?? FileManager.default.temporaryDirectory
        let out = root.appendingPathComponent("dock-instrument-checks/dock-visual/g3-90", isDirectory: true)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let unit = diameter / 52
        var tiles = [[CGImage]]()
        var rows = [String]()
        for wall in wallpapers {
            for scale in [1, 2] {
                var row = [CGImage]()
                for before in [true, false] {
                    let r = try render(scale: scale, before: before)
                    let s = CGFloat(scale), half = r.station.clock.radius + 4 * unit
                    let crop = CGRect(x: (r.station.centre.x - half - r.skin.bounds.minX) * s, y: (r.station.centre.y - half - r.skin.bounds.minY) * s,
                                      width: 2 * half * s, height: 2 * half * s).integral
                    let flat = try flatten(r.image, grey: wall.grey)
                    let piece = try XCTUnwrap(flat.cropping(to: crop))
                    try write(piece, out.appendingPathComponent("\(before ? "before" : "after")-\(wall.name)-\(scale)x.png"))
                    row.append(try magnify(piece, by: 8 / scale))
                }
                tiles.append(row); rows.append("\(wall.name) wallpaper (grey \(Int(wall.grey))), \(scale)x")
            }
        }
        let gap = 12, tw = tiles.map { $0.map(\.width).max() ?? 0 }.max() ?? 0, th = tiles.map { $0.map(\.height).max() ?? 0 }.max() ?? 0
        let width = 2 * tw + 3 * gap, height = tiles.count * (th + gap) + gap
        let board = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        board.setFillColor(CGColor(srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 1)); board.fill(CGRect(x: 0, y: 0, width: width, height: height))
        board.interpolationQuality = .none
        for (i, row) in tiles.enumerated() {
            for (j, tile) in row.enumerated() {
                board.draw(tile, in: CGRect(x: gap + j * (tw + gap), y: height - (i + 1) * (th + gap), width: tile.width, height: tile.height))
            }
        }
        try write(try XCTUnwrap(board.makeImage()), out.appendingPathComponent("g3-90-board.png"))
        let legend = ["G3-90 / D167 ring time dots: left column before (white 60 %, unsnapped), right column after (white 80 %, 1x pixel-snapped).",
                      "Board rows top to bottom; 1x tiles are magnified 8x and 2x tiles 4x (nearest neighbour), so both show the same physical size.",
                      "Medium nozzle (44 pt), 5-hour window 3 h of 5 h left, production T2 artwork. Actual-size crops: before|after-<wallpaper>-<scale>x.png."]
            + rows.enumerated().map { "row \($0.offset + 1): \($0.element)" }
        try legend.joined(separator: "\n").appending("\n").write(to: out.appendingPathComponent("README.txt"), atomically: true, encoding: .utf8)
    }

    private func flatten(_ image: CGImage, grey: CGFloat) throws -> CGImage {
        let c = try XCTUnwrap(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        c.setFillColor(CGColor(srgbRed: grey / 255, green: grey / 255, blue: grey / 255, alpha: 1)); c.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        c.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return try XCTUnwrap(c.makeImage())
    }

    private func magnify(_ image: CGImage, by factor: Int) throws -> CGImage {
        let c = try XCTUnwrap(CGContext(data: nil, width: image.width * factor, height: image.height * factor, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        c.interpolationQuality = .none
        c.draw(image, in: CGRect(x: 0, y: 0, width: image.width * factor, height: image.height * factor))
        return try XCTUnwrap(c.makeImage())
    }

    private func write(_ image: CGImage, _ url: URL) throws {
        let writer = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(writer, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(writer))
    }
}
