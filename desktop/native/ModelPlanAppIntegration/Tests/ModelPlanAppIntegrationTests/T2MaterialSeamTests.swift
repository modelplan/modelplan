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
        context.setFillColor(CGColor(red:0.25,green:0.5,blue:0.75,alpha:1))
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
            let color = try XCTUnwrap(NSBitmapImageRep(cgImage:image).colorAt(x:4,y:4)?.usingColorSpace(.deviceRGB))
            XCTAssertEqual(color.redComponent,0.25,accuracy:2.0/255)
            XCTAssertEqual(color.greenComponent,0.5,accuracy:2.0/255)
            XCTAssertEqual(color.blueComponent,0.75,accuracy:2.0/255)
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
