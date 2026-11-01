// SPDX-License-Identifier: MIT
import Foundation

/// Resource locations and metadata only. Canonical DockArtworkStore performs
/// path, byte-count and SHA checks before any image/font decode.
public enum DockThirdPartyResources {
    public enum Failure: Error { case missingManifest, invalidManifest }
    public static func rootURL() throws -> URL {
        let packaged = (Bundle.main.resourceURL?.appendingPathComponent("ModelPlanDockResources_ModelPlanDockResources.bundle")).flatMap { Bundle(url: $0) }
        if Bundle.main.bundleURL.pathExtension == "app", packaged == nil { throw Failure.missingManifest }
        let bundle = packaged ?? Bundle.module
        guard let manifest = bundle.url(forResource: "manifest", withExtension: "json") else { throw Failure.missingManifest }
        return manifest.deletingLastPathComponent()
    }
    /// Beta-only marks are excluded unless the distribution consumer explicitly
    /// opts into the approved beta policy. No runtime downloader is involved.
    public static func manifestData(allowBetaMarks: Bool) throws -> Data {
        let data = try Data(contentsOf: rootURL().appendingPathComponent("manifest.json"))
        guard var value = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              value["schemaVersion"] as? Int == 1,
              let files = value["files"] as? [String: [String: Any]], files.count <= 128 else { throw Failure.invalidManifest }
        value["files"] = files.filter { allowBetaMarks || ($0.value["betaOnly"] as? Bool != true) }
        return try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    }
}
