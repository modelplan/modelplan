// SPDX-License-Identifier: MIT
// Which rocket the entrance draws (owner D109, 2026-11-09). The official edition passes the brand rocket from
// the reserved official-visuals pack (desktop/official-visuals/rocket-3d, LicenseRef-ModelPlan-Visuals-1.0);
// community and self-builds never reference that pack and always get the neutral stand-in.
import Foundation

public enum RocketModelSource: Equatable, Sendable {
    /// Plain procedural shapes with the official model's outer dimensions (MIT).
    case neutralStandIn
    /// The brand rocket: one shared model, one USDZ per approved finish, plus its measured geometry.
    case official(night: URL, day: URL, geometry: RocketGeometry)

    /// What a build without the official pack uses.
    public static let communityDefault = RocketModelSource.neutralStandIn

    public var geometry: RocketGeometry {
        switch self {
        case .neutralStandIn: return .neutralStandIn
        case .official(_, _, let geometry): return geometry
        }
    }

    /// The model file for a theme; nil for the stand-in (built in code).
    public func modelURL(for theme: EntranceTheme) -> URL? {
        switch self {
        case .neutralStandIn: return nil
        case .official(let night, let day, _): return theme == .night ? night : day
        }
    }
}

extension RocketGeometry {
    /// Decodes the official pack's `rocket-geometry.json` (height, skirt radius, window anchor, glass vertices).
    public static func decodePack(_ data: Data) throws -> RocketGeometry {
        struct Pack: Decodable {
            let height: Double, skirtRadius: Double, windowAnchorY: Double, glassVertices: [[Double]]
        }
        let pack = try JSONDecoder().decode(Pack.self, from: data)
        return RocketGeometry(height: pack.height, skirtRadius: pack.skirtRadius,
                              glassVertices: pack.glassVertices.map { EntranceVector($0[0], $0[1], $0[2]) },
                              windowAnchorY: pack.windowAnchorY)
    }
}

/// Optional look images that come with the official model (owner D142, generated under D116): a tileable
/// brushed-metal detail for the hull and the cockpit seen through the front window. Each is a URL to a verified
/// file of the official pack, or nil; the entrance scene draws its own code fallbacks for anything missing.
public struct RocketLookImages: Equatable, Sendable {
    /// Greyscale, tileable brushed-steel detail (1024 x 1024), tiled about every half metre on the hull.
    public var brushedDetail: URL?
    /// The dim cockpit interior shown behind the front window, per theme (day falls back to night).
    public var cockpitInteriorNight: URL?
    public var cockpitInteriorDay: URL?
    /// CKP-ENT-13 (D179): the hull kit (base metal + decals). When present it replaces `brushedDetail` and the
    /// code-drawn hull detail; the seams and ring bands stay code-drawn.
    public var hullKit: RocketHullKit?

    public init(brushedDetail: URL? = nil, cockpitInteriorNight: URL? = nil, cockpitInteriorDay: URL? = nil,
                hullKit: RocketHullKit? = nil) {
        self.brushedDetail = brushedDetail
        self.cockpitInteriorNight = cockpitInteriorNight
        self.cockpitInteriorDay = cockpitInteriorDay
        self.hullKit = hullKit
    }

    /// No images: every look element is code-drawn.
    public static let none = RocketLookImages()

    public func cockpitInterior(for theme: EntranceTheme) -> URL? {
        theme == .day ? (cockpitInteriorDay ?? cockpitInteriorNight) : cockpitInteriorNight
    }
}
