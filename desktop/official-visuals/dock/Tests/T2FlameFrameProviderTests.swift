// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import ModelPlanPrimitives
import XCTest
@testable import ModelPlanOfficialDock

@MainActor final class T2FlameFrameProviderTests: XCTestCase {
    private func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private func png(_ side: Int) throws -> Data {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = try XCTUnwrap(CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1)); context.fill(CGRect(x: 2, y: 2, width: 5, height: 5))
        let image = try XCTUnwrap(context.makeImage()), out = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(out, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil); XCTAssertTrue(CGImageDestinationFinalize(destination))
        return out as Data
    }
    func testVerifiedFrameAndRefusalAfterTampering() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let name = "flame-normal-36pt-1x-1mag-pose0.png", original = try png(36)
        let url = root.appendingPathComponent(name); try original.write(to: url)
        let manifest = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "files": [name: ["path": name, "sha256": digest(original), "bytes": original.count]]], options: [.sortedKeys])
        let provider = try T2FlameFrameProvider(root: root, manifestData: manifest, expectedSHA256: digest(manifest))
        let request = EffectFrameRequest(profile: RenderProfile(scale: 1), points: 36, variant: "normal")
        let context = try XCTUnwrap(CGContext(data: nil, width: 36, height: 36, bitsPerComponent: 8, bytesPerRow: 144, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        XCTAssertNoThrow(try provider.draw(pose: 0, request: request, in: context))
        XCTAssertThrowsError(try provider.draw(pose: 1, request: request, in: context))
        XCTAssertThrowsError(try T2FlameFrameProvider(root: root, manifestData: manifest, expectedSHA256: String(repeating: "0", count: 64)))
        var changed = original; changed[changed.count - 1] ^= 1; try changed.write(to: url)
        XCTAssertThrowsError(try provider.draw(pose: 0, request: request, in: context))
    }
}
