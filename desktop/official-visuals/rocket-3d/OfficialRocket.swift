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
        "rocket-geometry.json": "f707387ffac7c59166d52a8f3a8fcbd21a6f977ad62d358fecc6e26c14350c2d",
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
    public static let lookFiles: [String: String] = [
        "rocket-brushed-steel-detail.png": "9ba43a1dd2d5adcc621db2e278e3115ce1c3db4dc310bc00e417872fabdc6643",
        "rocket-cockpit-interior-night.png": "72c1d59e6ce9ed512fd18009e287eaa95f4218a0bac47a69a96ab0070c152d71",
        // CKP-ENT-13 (owner D179, 2026-11-12): the hull kit, base metal and decals.
        "rocket-hull-decal-door-albedo.png": "ecb59e23efafad859e611b11fd6266a8acf805ec7cdc5a9f77f2f2e3b7ec0610",
        "rocket-hull-decal-door-normal.png": "95d2f167cb0427dc4968ffb95d435295eb371ae06ad688e9bff88a2b9b1eb8ec",
        "rocket-hull-decal-door-roughness.png": "7b4f2ebbdd2388b7bfb6f17f5b2dc731f6878a8cb352f04693cd12c2cbc794b0",
        "rocket-hull-decal-hatch-albedo.png": "9cea8d7a6dcbbb3c8a5108189fb04051ef045d169500e87609508ec5e5adb26a",
        "rocket-hull-decal-hatch-normal.png": "39d3a25aa61c678a5ec948058fb90f8036f1b33702f4ada1cfb4756d6183dbe6",
        "rocket-hull-decal-hatch-roughness.png": "5b13dc243c46fe86fbe67189941b16ea284ce5ad30300cde034b56e794ea084b",
        "rocket-hull-decal-panel-albedo.png": "b1eb1582c2fdbc29bcfd343184525a77e52a5607a0e952cddb92dd3606f7a04a",
        "rocket-hull-decal-panel-normal.png": "7154372d5d8d61b7ce428f8bfb94002cb82e47b932367d678cd96bd51f699411",
        "rocket-hull-decal-panel-roughness.png": "591f4cca49dfed4aa357511630fe72b2291b5a3c0aed3835276f06d91f32afd0",
        "rocket-hull-decal-plate-albedo.png": "b85ad3d65a6e76631b1582a6fe6339a57410c78dd436c84eb3d30e1e43a6d588",
        "rocket-hull-decal-plate-normal.png": "74caecce6013f1ca54a7307b23b11dd843e009b9bdc94d73fc683f6ae0531238",
        "rocket-hull-decal-plate-roughness.png": "f95f9caef5bd85af8ff7fa19e2bf4bfd05126380bfec32262ea32e623f35cb80",
        "rocket-hull-decal-slot-albedo.png": "5d9f36c6ae36aa0ab2fd91bf2f0d05190a4f3a41cae4e0a7d8c395d453bea708",
        "rocket-hull-decal-slot-normal.png": "94d7d5a62ba15a189992c303cb810b0022ae2808b4bdd0e3e3c678bc4d095fb1",
        "rocket-hull-decal-slot-roughness.png": "47fa705ab78cb501ebb34a0bc2f7afc6c2927551cd6242b1ae5f5ae4e0c2fc4e",
        "rocket-hull-decal-vent-albedo.png": "5a8b3c9b05fe839f8380797da30680dee23366f037b2fe9410d0d21bb6a779bd",
        "rocket-hull-decal-vent-normal.png": "9d435e5a93322e396ef69854212897436d9f786426185f27ee114ceff1611113",
        "rocket-hull-decal-vent-roughness.png": "8c1be54c6b7cf667e0a9ddd6071bad8b2dcd516aa4398aa0390ec11b5bf117b5",
        "rocket-hull-metal-day.png": "c98a6b97561f9bca651ff91ae48cfd43b6b827dd21cee430f289c073b3fcae5a",
        "rocket-hull-metal-night.png": "629f360aa02a79da2a8fbf5af10af82f11891d79d8608d009908d6016b0370e5",
        "rocket-hull-metal-roughness.png": "46f480cf196db9325c2261c9fdd5f8369d0e592da2e59a62e9e758c3a2ec34e3",
    ]
    static let brushedDetailName = "rocket-brushed-steel-detail.png"
    static let cockpitNightName = "rocket-cockpit-interior-night.png"
    static let cockpitDayName = "rocket-cockpit-interior-day.png"

    /// The look images present in the pack, verified; absent ones are nil.
    public static func lookImages() throws -> RocketLookImages {
        RocketLookImages(brushedDetail: try optional(brushedDetailName), cockpitInteriorNight: try optional(cockpitNightName),
                         cockpitInteriorDay: try optional(cockpitDayName), hullKit: try hullKit())
    }

    /// CKP-ENT-13: the hull kit, verified, or nil unless every one of its files is in the pack (a partial kit is
    /// never used; the entrance then draws the code hull).
    public static func hullKit() throws -> RocketHullKit? {
        var found: [String: URL] = [:]
        for name in RocketHullKit.fileNames {
            guard let url = try optional(name) else { return nil }
            found[name] = url
        }
        let metal = RocketHullKit.metalNames
        guard let night = found[metal.night], let day = found[metal.day], let rough = found[metal.roughness] else { return nil }
        var decals: [HullDecalKind: RocketHullKit.Decal] = [:]
        for kind in HullDecalKind.allCases {
            let n = RocketHullKit.decalNames(kind)
            guard let albedo = found[n.albedo], let normal = found[n.normal], let roughness = found[n.roughness] else { return nil }
            decals[kind] = .init(albedo: albedo, normal: normal, roughness: roughness)
        }
        return RocketHullKit(metalNight: night, metalDay: day, metalRoughness: rough, decals: decals)
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
