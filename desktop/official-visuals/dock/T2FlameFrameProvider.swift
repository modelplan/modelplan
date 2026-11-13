// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
// Copyright (c) 2026 ModelPlan. All rights reserved.
import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import ModelPlanPrimitives

/// Loads only captured prototype frames. The shared pool owns all decoded images.
@MainActor public final class T2FlameFrameProvider: EffectFrameProvider {
    public enum Failure: Error { case manifest, request, missing, changed, invalidImage }
    private struct Record: Decodable { let path: String; let sha256: String; let bytes: Int }
    private struct Manifest: Decodable { let schemaVersion: Int; let files: [String: Record] }
    public let identifier = "org.modelplan.dock.t2.prototype-flame"
    public let revision: String
    private let root: URL
    private let files: [String: Record]

    /// The capture manifest is pinned independently of mutable resource lookup.
    public static func bundled() throws -> T2FlameFrameProvider {
        let root = try T2BundledArtwork.rootURL().appendingPathComponent("Flame", isDirectory: true)
        let manifest = try Data(contentsOf: root.appendingPathComponent("flame-manifest.json"))
        return try T2FlameFrameProvider(root: root, manifestData: manifest,
            expectedSHA256: "647fdb4bd778f8b9c5544219dc4959c779f8b8368fa41b0905d4b650508cf76c")
    }

    /// The composition pins the manifest digest alongside the shipped assets.
    public init(root: URL, manifestData: Data, expectedSHA256: String) throws {
        let digest = Self.hash(manifestData)
        guard expectedSHA256.count == 64, digest == expectedSHA256 else { throw Failure.manifest }
        let manifest = try JSONDecoder().decode(Manifest.self, from: manifestData)
        guard manifest.schemaVersion == 1, !manifest.files.isEmpty, manifest.files.count <= 512 else { throw Failure.manifest }
        self.root = root.standardizedFileURL.resolvingSymlinksInPath()
        self.files = manifest.files
        self.revision = digest
    }

    public func draw(pose: Int, request: EffectFrameRequest, in context: CGContext) throws {
        guard (0..<9).contains(pose), [36, 44, 52].contains(request.points),
              (1...2).contains(request.profile.scale),
              ["normal", "warning", "critical"].contains(request.variant),
              let side = request.pixelSide else { throw Failure.request }
        let magnification: String
        switch request.magnification {
        case 1: magnification = "1"
        case 1.15: magnification = "1.15"
        case 1.5: magnification = "1.5"
        default: throw Failure.request
        }
        let name = "flame-\(request.variant)-\(request.points)pt-\(request.profile.scale)x-\(magnification)mag-pose\(pose).png"
        guard let record = files[name], record.path == name, (1...16_777_216).contains(record.bytes),
              record.sha256.count == 64 else { throw Failure.missing }
        let url = root.appendingPathComponent(record.path).standardizedFileURL.resolvingSymlinksInPath()
        guard url.path.hasPrefix(root.path + "/") else { throw Failure.manifest }
        let metadata = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard metadata.isRegularFile == true, metadata.fileSize == record.bytes else { throw Failure.changed }
        let bytes = try Data(contentsOf: url)
        guard bytes.count == record.bytes, Self.hash(bytes) == record.sha256 else { throw Failure.changed }
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(bytes as CFData, options),
              CGImageSourceGetType(source) as String? == "public.png",
              let image = CGImageSourceCreateImageAtIndex(source, 0, options),
              image.width == side, image.height == side,
              context.width == side, context.height == side else { throw Failure.invalidImage }
        context.saveGState(); defer { context.restoreGState() }
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
    }
    private static func hash(_ value: Data) -> String {
        SHA256.hash(data: value).map { String(format: "%02x", $0) }.joined()
    }
}
