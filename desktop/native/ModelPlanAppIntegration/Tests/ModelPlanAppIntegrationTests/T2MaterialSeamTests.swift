// SPDX-License-Identifier: MIT
import XCTest
import AppKit
import ModelPlanDock

@MainActor final class T2MaterialSeamTests: XCTestCase {
    private func skin() throws -> DockInstrumentSkin {
        let value: [String: Any] = [
            "schemaVersion": 1, "bounds": [[0,0],[8,8]],
            "bodyPolygon": [[0,0],[8,0],[8,8],[0,8]], "fixedLayers": [], "stations": [],
            "palette": ["body": ["r":0,"g":0,"b":0,"a":1]],
            "text": ["size":11,"weight":400], "aliasText": ["size":10,"weight":400]
        ]
        return try JSONDecoder().decode(DockInstrumentSkin.self, from: JSONSerialization.data(withJSONObject: value))
    }
    private func store(_ root: URL) throws -> DockArtworkStore {
        try DockArtworkStore(root: root, manifest: DockResourceManifest(files: [:]))
    }
    private func image(width: Int = 8) throws -> CGImage {
        let context = try XCTUnwrap(CGContext(data:nil,width:width,height:8,bitsPerComponent:8,
            bytesPerRow:width*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,
            bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(colorSpace:CGColorSpace(name:CGColorSpace.sRGB)!,
            components:[0.25,0.5,0.75,1])!)
        context.fill(CGRect(x:0,y:0,width:width,height:8))
        return try XCTUnwrap(context.makeImage())
    }
    func testStaticMaterialReachesRenderedAndRetainedBackground() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        var calls = 0
        let renderer = DockInstrumentRenderer(resources:try store(root),material:{ [self] skin, scale in
            calls += 1; XCTAssertEqual(skin.bounds.size, CGSize(width:8,height:8)); XCTAssertEqual(scale,1)
            return try image()
        })
        let result = try renderer.render(skin:skin(),readings:[:],scale:1)
        XCTAssertEqual(calls,1)
        for image in [result.image,result.backgroundImage] {
            // Read the renderer's declared sRGB RGBA8 pixels directly. AppKit's
            // colorAt/NSColor conversion may change numeric channels even when
            // both CGImages contain identical bytes.
            XCTAssertEqual(image.bitsPerComponent,8); XCTAssertEqual(image.bitsPerPixel,32)
            let pixels = try XCTUnwrap(image.dataProvider?.data) as Data
            let offset = 4 * image.bytesPerRow + 4 * 4
            let expected = [64,128,191,255]
            for channel in 0..<4 {
                XCTAssertEqual(Double(pixels[offset+channel]),Double(expected[channel]),accuracy:2)
            }
        }
    }
    func testWrongSizedOrFailedMaterialRefusesRender() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let wrong = DockInstrumentRenderer(resources:try store(root),material:{ [self] _,_ in try image(width:7) })
        XCTAssertThrowsError(try wrong.render(skin:skin(),readings:[:],scale:1))
        enum Refusal: Error { case refused }
        let failed = DockInstrumentRenderer(resources:try store(root),material:{ _,_ in throw Refusal.refused })
        XCTAssertThrowsError(try failed.render(skin:skin(),readings:[:],scale:1))
    }
}
