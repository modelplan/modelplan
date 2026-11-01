// SPDX-License-Identifier: MIT
import Foundation

/// Window geometry only. The web page remains the sole cockpit renderer.
public struct CockpitShellLayout: Equatable, Sendable {
    public let profile: CockpitAppearance.Profile
    public let shutterClosed: Bool
    public let forcedClosed: Bool
    public let scale: CGFloat
    public let rootHeight: CGFloat
    public let frame: CGRect
    public static func fit(usable: CGRect, anchor: CGRect, shutterClosed: Bool) -> Self? {
        guard usable.width.isFinite, usable.height.isFinite, usable.width > 0, usable.height > 40,
              usable.origin.x.isFinite, usable.origin.y.isFinite,
              anchor.origin.x.isFinite, anchor.origin.y.isFinite else { return nil }
        let profile: CockpitAppearance.Profile = usable.height - 66 >= 890 ? .full : .compact
        let closed = shutterClosed || usable.height - 66 < 640
        let height: CGFloat = profile == .full ? (closed ? 691 : 877) : (closed ? 609 : 627)
        let top = min(usable.maxY, anchor.minY) - 6
        let available = top - usable.minY
        guard available > 0 else { return nil }
        let scale = min(1, usable.width / 636, available / (height + 34))
        let size = CGSize(width: 636 * scale, height: (height + 34) * scale)
        let x = max(usable.minX, min(anchor.midX - size.width / 2, usable.maxX - size.width))
        return Self(profile: profile, shutterClosed: closed, forcedClosed: usable.height - 66 < 640, scale: scale, rootHeight: height,
                    frame: CGRect(x: x, y: top - size.height, width: size.width, height: size.height))
    }
    public func clamping(origin: CGPoint, usable: CGRect) -> CGRect {
        CGRect(x: max(usable.minX, min(origin.x, usable.maxX - frame.width)),
               y: max(usable.minY, min(origin.y, usable.maxY - frame.height)),
               width: frame.width, height: frame.height)
    }
}

/// Retained by the console owner, never by the discarded WebKit page.
@MainActor public final class CockpitShellSession {
    public var detached = false
    public var shutterClosed = false
    private var origins: [(String, CGPoint)] = []
    public init() {}
    public func origin(for arrangement: String) -> CGPoint? { origins.first { $0.0 == arrangement }?.1 }
    public func remember(_ origin: CGPoint, arrangement: String) {
        origins.removeAll { $0.0 == arrangement }; origins.append((arrangement, origin))
        if origins.count > 8 { origins.removeFirst() }
    }
}
