// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
// Copyright (c) 2026 ModelPlan. All rights reserved.
import Foundation
import CryptoKit

public struct T2ArtworkRecord: Decodable, Sendable {
    public let path: String
    public let sha256: String
    public let bytes: Int
}

/// Original accepted layer bytes only; vendor marks have separate rights and
/// deliberately do not enter this reserved-visual resource pack.
public enum T2BundledArtwork {
    public enum Failure: Error { case missing, invalidManifest, outsideRoot, changedBytes }
    private struct Manifest: Decodable { let schemaVersion: Int; let files: [String: T2ArtworkRecord] }
    public static func rootURL() throws -> URL {
        guard let manifest = Bundle.module.url(forResource: "artwork", withExtension: "json") else { throw Failure.missing }
        let root = manifest.deletingLastPathComponent()
        return root.standardizedFileURL.resolvingSymlinksInPath()
    }
    public static func records() throws -> [String: T2ArtworkRecord] {
        let root = try rootURL()
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: root.appendingPathComponent("artwork.json")))
        guard manifest.schemaVersion == 1, manifest.files.count <= 128 else { throw Failure.invalidManifest }
        return manifest.files
    }
    public static func data(_ name: String) throws -> Data {
        guard let record = try records()[name], (1...16_777_216).contains(record.bytes), record.sha256.count == 64 else { throw Failure.missing }
        let pieces = record.path.split(separator: "/", omittingEmptySubsequences: false)
        guard !record.path.hasPrefix("/"), !pieces.contains(".."), !pieces.contains("") else { throw Failure.outsideRoot }
        let root = try rootURL(), url = root.appendingPathComponent(record.path).standardizedFileURL.resolvingSymlinksInPath()
        guard url.path.hasPrefix(root.path + "/") else { throw Failure.outsideRoot }
        let metadata = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard metadata.isRegularFile == true, metadata.fileSize == record.bytes else { throw Failure.changedBytes }
        let value = try Data(contentsOf: url)
        guard value.count == record.bytes,
              SHA256.hash(data: value).map({ String(format: "%02x", $0) }).joined() == record.sha256 else { throw Failure.changedBytes }
        return value
    }
}
