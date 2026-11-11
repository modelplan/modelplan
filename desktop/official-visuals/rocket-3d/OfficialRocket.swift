// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
// The brand rocket for the native entrance (owner D109, 2026-11-09): one shared model, one USDZ per approved
// finish (night graphite gunmetal, day satin aluminium), plus its measured geometry. Only the official edition
// links this package; the loader refuses unregistered names and altered bytes.
import CryptoKit
import Foundation
import ModelPlanEntrance

public enum OfficialRocket {
    public enum PackError: Error, Equatable { case missing(String), altered(String), unregistered(String) }

    /// Shipped files and their SHA-256 (also recorded in manifest.json and source-policy.json).
    public static let files: [String: String] = [
        "modelplan-rocket-night-lod1.usdz": "3c8a377280f9828729fe2fd867b8cdf91d91336de1a9ae2e4b0b32a25e7a3a5a",
        "modelplan-rocket-day-lod1.usdz": "2dcd806d6ddbfd0c654e95b219bda50208673b121cb91e9d0688d6d5e8a53c9e",
        "rocket-geometry.json": "ae0d124ac2ee2aa4088f3e254e38dfdd58af230254e3a04f20455b82da8c2f3d",
    ]

    /// The verified official source for the entrance.
    public static func source() throws -> RocketModelSource {
        let night = try verified("modelplan-rocket-night-lod1.usdz")
        let day = try verified("modelplan-rocket-day-lod1.usdz")
        let geometry = try RocketGeometry.decodePack(Data(contentsOf: verified("rocket-geometry.json")))
        return .official(night: night, day: day, geometry: geometry)
    }

    /// Optional look images (owner D142, generated under D116). They ship only once generated and approved; each
    /// then gets its SHA-256 here, in manifest.json and in source-policy.json. Until then the entrance draws its code
    /// fallbacks. A file in Resources without an entry here is refused, never used unverified.
    public static let lookFiles: [String: String] = [:]
    static let brushedDetailName = "rocket-brushed-steel-detail.png"
    static let cockpitNightName = "rocket-cockpit-interior-night.png"
    static let cockpitDayName = "rocket-cockpit-interior-day.png"

    /// The look images present in the pack, verified; absent ones are nil.
    public static func lookImages() throws -> RocketLookImages {
        RocketLookImages(brushedDetail: try optional(brushedDetailName), cockpitInteriorNight: try optional(cockpitNightName),
                         cockpitInteriorDay: try optional(cockpitDayName))
    }

    static func optional(_ name: String) throws -> URL? {
        guard let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Resources") else { return nil }
        guard let expected = lookFiles[name] else { throw PackError.unregistered(name) }
        try verify(url, expected: expected, name: name)
        return url
    }

    static func verified(_ name: String) throws -> URL {
        guard let expected = files[name],
              let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Resources")
        else { throw PackError.missing(name) }
        try verify(url, expected: expected, name: name)
        return url
    }

    static func verify(_ url: URL, expected: String, name: String) throws {
        let digest = SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
        guard digest == expected else { throw PackError.altered(name) }
    }
}
