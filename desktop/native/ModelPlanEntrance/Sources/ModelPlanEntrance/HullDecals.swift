// SPDX-License-Identifier: MIT
// CKP-ENT-13 (owner D174/D176/D179, 2026-11-12): the official rocket's hull in three layers, a tileable base
// metal, a small reusable decal kit placed from one table, and the code-drawn seams and ring bands. This file is
// the Foundation-only part: the placement table and the kit's file set. The images ship only in the reserved
// official-visuals pack (desktop/official-visuals/rocket-3d); the scene draws them (`HullPanels` in
// ModelPlanEntranceScene). Community builds have no kit and keep the code-drawn hull.
import Foundation

/// The decal kinds the official kit ships. D176 named eight; the owner dropped the capsule tags (D179), which
/// took the stencil label and the rivet strip with them, and no lower-body rivets are placed, so six ship.
public enum HullDecalKind: String, CaseIterable, Sendable {
    case door, hatch, vent, plate, slot, panel
}

/// One decal on the hull, in the scene's hull frame: azimuth 0 faces the window, positive toward +x (screen right
/// from the front); heights in metres above the rocket origin; sizes along the hull surface.
public struct HullDecalPlacement: Equatable, Sendable {
    /// The D174/D176 map number (11, 12, 16 ... U1, U2).
    public let id: String
    public let kind: HullDecalKind
    public let height: Double
    public let azimuth: Double
    /// Width around the hull and height along it, in metres. The decal's opaque part fills this box.
    public let width: Double
    public let tall: Double
    /// Mirrored left-right (the L hatch 12).
    public let mirrored: Bool
    /// D176 camera tier: "A" close (full decals), "B" mid (a few large items).
    public let tier: String

    public init(_ id: String, _ kind: HullDecalKind, height: Double, azimuth: Double, width: Double, tall: Double,
                mirrored: Bool = false, tier: String = "A") {
        self.id = id
        self.kind = kind
        self.height = height
        self.azimuth = azimuth
        self.width = width
        self.tall = tall
        self.mirrored = mirrored
        self.tier = tier
    }
}

public enum HullDecals {
    /// The placement table (`entr-d176-table.cjs`, from the approved D174 map; owner D176 cut the lower body from 17
    /// items to 7 and D179 dropped the capsule tags C1-C8). Centre, azimuth and height are the table's; the size
    /// keeps each decal's own proportions at the table's height (its opaque part), so nothing is stretched:
    /// - 12, the L hatch: the table's 0.20 x 0.72 m box would squeeze the L to 0.6 of its width; it is 0.27 x 0.60 m
    ///   at the same centre, clear of door 11.
    /// - U2, the handle box on the upper door: the cover plate (closed border) at the table's 0.09 x 0.12 m, rather
    ///   than a slice of the long stencil panel.
    public static let placements: [HullDecalPlacement] = [
        // Tier A, lower body (front +-45 degrees, read clearly in the opening shot).
        .init("6", .slot, height: 5.12, azimuth: 30, width: 0.61, tall: 0.07),
        .init("11", .door, height: 2.55, azimuth: -1.3, width: 0.27, tall: 1.21),
        .init("12", .hatch, height: 2.31, azimuth: -16.3, width: 0.27, tall: 0.60, mirrored: true),
        .init("16", .vent, height: 1.05, azimuth: -27.6, width: 0.16, tall: 0.64),
        .init("17", .vent, height: 1.09, azimuth: 23.5, width: 0.17, tall: 0.66),
        .init("18", .plate, height: 1.03, azimuth: -1.3, width: 0.29, tall: 0.36),
        .init("19", .panel, height: 1.2, azimuth: -40, width: 0.085, tall: 0.75),
        // Tier B, upper body (pass-5 side still): the tall door and its handle box.
        .init("U1", .door, height: 8.47, azimuth: 0, width: 0.37, tall: 1.65, tier: "B"),
        .init("U2", .plate, height: 8.75, azimuth: 0, width: 0.09, tall: 0.12, tier: "B"),
    ]

    /// Nothing on the back half (D176 tier C: base metal and seams only beyond +-90 degrees).
    public static let frontHalfLimit = 90.0

    /// The stencil panel's lettering region in the decal's opaque box (unit coordinates, top left origin). Dark
    /// stencil ink reads as a hole on the night metal, so at night it is drawn as light paint (CKP-ENT-13 note).
    public static let stencilInk = (x: 0.22, y: 0.34, width: 0.56, height: 0.30)

    /// The hull radius the table's widths are measured on (the file's sections).
    public static func radius(atHeight y: Double) -> Double {
        if y >= 6.57 { return 0.894 }
        if y >= 5.2 { return 1.152 + (0.896 - 1.152) * (y - 5.2) / (6.57 - 5.2) }
        if y >= 1.89 { return 1.17 }
        return 1.2
    }

    /// Half the decal's angular width in degrees.
    public static func halfSpanDegrees(_ p: HullDecalPlacement) -> Double {
        p.width / 2 / radius(atHeight: p.height) * 180 / .pi
    }
}

/// The official hull kit's files (verified URLs from the pack): the base metal per theme with its roughness, and
/// the decals with albedo (greyscale + alpha, 128 = the base colour), normal (OpenGL, +Y up) and roughness maps.
/// One decal set serves both themes.
public struct RocketHullKit: Equatable, Sendable {
    public struct Decal: Equatable, Sendable {
        public var albedo: URL, normal: URL, roughness: URL
        public init(albedo: URL, normal: URL, roughness: URL) {
            self.albedo = albedo
            self.normal = normal
            self.roughness = roughness
        }
    }

    public var metalNight: URL, metalDay: URL, metalRoughness: URL
    public var decals: [HullDecalKind: Decal]

    public init(metalNight: URL, metalDay: URL, metalRoughness: URL, decals: [HullDecalKind: Decal]) {
        self.metalNight = metalNight
        self.metalDay = metalDay
        self.metalRoughness = metalRoughness
        self.decals = decals
    }

    /// The base metal for a theme (day is the same texture, lightened).
    public func metal(for theme: EntranceTheme) -> URL { theme == .day ? metalDay : metalNight }

    /// The pack's file names (`rocket-hull-metal-*.png`, `rocket-hull-decal-<kind>-*.png`).
    public static let metalNames = (night: "rocket-hull-metal-night.png", day: "rocket-hull-metal-day.png",
                                    roughness: "rocket-hull-metal-roughness.png")
    public static func decalNames(_ kind: HullDecalKind) -> (albedo: String, normal: String, roughness: String) {
        let stem = "rocket-hull-decal-\(kind.rawValue)"
        return ("\(stem)-albedo.png", "\(stem)-normal.png", "\(stem)-roughness.png")
    }
    /// Every file of a complete kit.
    public static var fileNames: [String] {
        [metalNames.night, metalNames.day, metalNames.roughness]
            + HullDecalKind.allCases.flatMap { k -> [String] in let n = decalNames(k); return [n.albedo, n.normal, n.roughness] }
    }
}
