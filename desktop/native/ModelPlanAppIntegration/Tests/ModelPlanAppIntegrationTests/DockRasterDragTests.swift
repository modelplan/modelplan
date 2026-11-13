// SPDX-License-Identifier: MIT
import AppKit
import CryptoKit
import ImageIO
import XCTest
import ModelPlanDock

@MainActor final class DockRasterDragTests: XCTestCase {
    // A precomposited body has pixels but no vector polygon. This is a public,
    // synthetic fixture; no official artwork or dimensions are required.
    func testPrecompositedBodyRegistersOnlyPaintedNonControlDragArea() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("dock-raster-drag-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let context = try XCTUnwrap(CGContext(data: nil, width: 128, height: 128,
            bitsPerComponent: 8, bytesPerRow: 512, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(NSColor.gray.cgColor)
        context.fillEllipse(in: CGRect(x: 16, y: 16, width: 96, height: 96))
        let image = try XCTUnwrap(context.makeImage())
        let url = folder.appendingPathComponent("synthetic-body.png")
        let writer = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(writer, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(writer))
        let data = try Data(contentsOf: url)
        let store = try DockArtworkStore(root: folder, manifest: .init(files: ["body": .init(
            path: url.lastPathComponent, sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), bytes: data.count)]))
        let json: [String: Any] = ["schemaVersion": 1, "bounds": [[0, 0], [64, 64]],
            "bodyPolygon": [], "fixedLayers": [["resource": "body", "rect": [[0, 0], [64, 64]]]],
            "palette": [:], "text": ["size": 10, "weight": 400], "aliasText": ["size": 10, "weight": 400],
            "stations": [["subscriptionID": "synthetic", "centre": [32, 32], "diameter": 8,
                "readout": [[28, 40], [8, 4]], "aliasRect": [[20, 46], [24, 4]],
                "eventRect": [[40, 30], [4, 4]], "glyphRect": [[28, 28], [8, 8]],
                "layers": [], "glyphs": [:], "outer": ["radius": 4, "width": 1, "minimumVisibleFraction": 0, "opacity": 1],
                "inner": ["radius": 2, "width": 1, "minimumVisibleFraction": 0, "opacity": 1],
                "clock": ["radius": 5, "dotRadius": 0.5, "backWidth": 1, "positions": 10],
                "notchWidth": 1, "caseInnerRadius": 1]]]
        var skin = try JSONDecoder().decode(DockInstrumentSkin.self, from: JSONSerialization.data(withJSONObject: json))
        let renderer = DockInstrumentRenderer(resources: store)
        for scale in [1, 2] {
            let view = DockInstrumentView(frame: .zero)
            try view.applyOfficial(skin: skin, rows: [], renderer: renderer, scale: scale, locale: "en")
            XCTAssertNil(view.registeredHullPath, "raster fallback must not invent a vector hull")
            let regions = try XCTUnwrap(view.registeredDragRegions(excluding: [CGRect(x: 20, y: 20, width: 4, height: 4)]),
                "the host must receive a drag registration even when the body is precomposited")
            XCTAssertTrue(regions.contains(CGPoint(x: 18, y: 32)), "visible body is an obvious grab area")
            XCTAssertFalse(regions.contains(CGPoint(x: 1, y: 1)), "transparent raster padding stays click-through")
            for point in [CGPoint(x: 21, y: 21), CGPoint(x: 32, y: 32), CGPoint(x: 32, y: 42),
                          CGPoint(x: 42, y: 32), CGPoint(x: 32, y: 48)] {
                XCTAssertFalse(regions.contains(point), "ignition, nozzle, readout, event and alias remain controls")
            }
            XCTAssertFalse(regions.contains(CGPoint(x: CGFloat.nan, y: 32)))
            view.isHidden = true
            XCTAssertFalse(regions.contains(CGPoint(x: 18, y: 32)))
            view.isHidden = false
            view.dispose()
            XCTAssertFalse(regions.contains(CGPoint(x: 18, y: 32)), "a retained registration cannot revive a retired raster")
        }
        skin.bodyPolygon = [CGPoint(x: 8, y: 8), CGPoint(x: 56, y: 8), CGPoint(x: 56, y: 56), CGPoint(x: 8, y: 56)]
        skin.palette["body"] = DockInk(0.5, 0.5, 0.5)
        let vector = DockInstrumentView(frame: .zero)
        try vector.applyOfficial(skin: skin, rows: [], renderer: renderer, scale: 1, locale: "en")
        XCTAssertNotNil(vector.registeredHullPath)
        XCTAssertTrue(try XCTUnwrap(vector.registeredDragRegions(excluding: [])).contains(CGPoint(x: 12, y: 12)))
        vector.dispose()
    }
}
