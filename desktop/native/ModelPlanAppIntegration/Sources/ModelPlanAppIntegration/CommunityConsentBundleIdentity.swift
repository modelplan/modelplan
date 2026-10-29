// SPDX-License-Identifier: MIT
import Foundation
import CryptoKit

/// Consistency with a reviewed release declaration, not standalone source provenance or reader consent.
/// The packager separately verifies upstream acquisition before assembling/signing the containing bundle.
public enum CommunityConsentBundleIdentity {
    public static let version = "0.5.46"
    public static let sourceSHA256ByArchitecture = [
        "arm64": "72c43fef8631399137ff9a651e984121fa19cbc77969f0a317c74c41b28f29e2",
        "x86_64": "a5c47042e925da522209d5192860cbf887af6b10fc3c8ff68c4aff1efba25f29",
    ]
    public static func isConsistent(helperVersion: String, sourceHelperSHA256: String,
                                    bundledHelperSHA256: String, resourceHelperSHA256: String,
                                    actualHelperSHA256: String) -> Bool {
        helperVersion == version && sourceSHA256ByArchitecture.values.contains(sourceHelperSHA256)
            && pinsMatch(bundledHelperSHA256, resourceHelperSHA256, actualHelperSHA256)
    }
    /// Fixed bounded app-owned reads only. Missing, old or inconsistent bundles remain unverified.
    /// BundledCLI independently checks the helper pin again when a command is actually requested.
    public static func matches(bundle: URL) -> Bool {
        do {
            let root = bundle.standardizedFileURL
            guard root.path == root.resolvingSymlinksInPath().path else { return false }
            let infoBytes = try read(root.appendingPathComponent("Contents/Info.plist"), limit: 65536)
            guard let info = try PropertyListSerialization.propertyList(from: infoBytes, format: nil) as? [String: Any],
                  let publicSource = info["ModelPlanPublicSource"] as? String, hex(publicSource, count: 40),
                  let release = info["ModelPlanHelperVersion"] as? String, release == version,
                  let bundled = info["ModelPlanBundledHelperSHA256"] as? String else { return false }
            let single = info["ModelPlanSourceHelperSHA256"]
            let universal = info["ModelPlanSourceHelperSHA256ByArchitecture"]
            if let source = single as? String {
                guard universal == nil, sourceSHA256ByArchitecture.values.contains(source) else { return false }
            } else {
                guard single == nil, let sources = universal as? [String: String], sources == sourceSHA256ByArchitecture else { return false }
            }
            let pinBytes = try read(root.appendingPathComponent("Contents/Resources/modelplan.sha256"), limit: 256)
            guard let text = String(data: pinBytes, encoding: .utf8) else { return false }
            let pin = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let helper = try read(root.appendingPathComponent("Contents/Helpers/modelplan"), limit: 128 * 1024 * 1024)
            let actual = SHA256.hash(data: helper).map { String(format: "%02x", $0) }.joined()
            return pinsMatch(bundled, pin, actual)
        } catch { return false }
    }
    private static func pinsMatch(_ bundled: String, _ resource: String, _ actual: String) -> Bool {
        hex(bundled, count: 64) && hex(resource, count: 64) && hex(actual, count: 64)
            && bundled == actual && resource == actual
    }
    private static func hex(_ value: String, count: Int) -> Bool {
        value.utf8.count == count && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
    private static func read(_ url: URL, limit: Int) throws -> Data {
        guard url.standardizedFileURL.path == url.resolvingSymlinksInPath().path else { throw IdentityError.invalid }
        let properties = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard properties.isRegularFile == true, properties.isSymbolicLink != true,
              let size = properties.fileSize, size > 0, size <= limit else { throw IdentityError.invalid }
        let bytes = try Data(contentsOf: url, options: .mappedIfSafe)
        guard bytes.count == size else { throw IdentityError.invalid }
        return bytes
    }
    private enum IdentityError: Error { case invalid }
}
