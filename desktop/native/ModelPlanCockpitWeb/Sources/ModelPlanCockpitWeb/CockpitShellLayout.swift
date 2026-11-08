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
        guard !usable.isNull, !usable.isInfinite, usable.width.isFinite, usable.height.isFinite, usable.width > 0, usable.height > 40,
              usable.origin.x.isFinite, usable.origin.y.isFinite,
              anchor.origin.x.isFinite, anchor.origin.y.isFinite else { return nil }
        // CKP-SHELL-07 states the steps as `viewport - 66`, where the study's viewport still includes
        // its 26 px menu bar. `usable` already excludes the menu bar, so only the top gap and base
        // reserve come off here, and a step is taken exactly when its real root fits.
        let room = usable.height - 6 - 34
        let profile: CockpitAppearance.Profile = room >= 877 ? .full : .compact
        let forcedClosed = room < 627
        let closed = shutterClosed || forcedClosed
        let height: CGFloat = profile == .full ? (closed ? 691 : 877) : (closed ? 609 : 627)
        let top = min(usable.maxY, anchor.minY) - 6
        let available = top - usable.minY
        guard available > 0 else { return nil }
        let scale = min(1, usable.width / 636, available / (height + 34))
        let size = CGSize(width: 636 * scale, height: (height + 34) * scale)
        let x = attachedX(anchor: anchor, width: size.width, scale: scale, usable: usable)
        return Self(profile: profile, shutterClosed: closed, forcedClosed: forcedClosed, scale: scale, rootHeight: height,
                    frame: CGRect(x: x, y: top - size.height, width: size.width, height: size.height))
    }
    /// G3-46: with no visible menu bar icon, open at the top-right of the screen, directly below the menu bar.
    public static func hiddenIconAnchor(usable: CGRect) -> CGRect {
        CGRect(x: usable.maxX, y: usable.maxY, width: 0, height: 0)
    }
    /// G3-46 (owner D53): like other menu bar tools, the cockpit's visible left edge lines up with the menu
    /// bar icon's left edge. The 636 px raster has an 8 px transparent margin around the 620 px shell. When
    /// that would run past the right edge it shifts left just enough to stay on the screen.
    public static func attachedX(anchor: CGRect, width: CGFloat, scale: CGFloat, usable: CGRect) -> CGFloat {
        max(usable.minX, min(anchor.minX - 8 * scale, usable.maxX - width))
    }
    /// G3-43 / CKP-SHELL-04: the free left of the title strip, window-local with Y up. It stops short of
    /// the shutter so buttons keep their own input. Strip tops are the page's, shared with the study.
    public var titleDragFrame: CGRect {
        let stripTop: CGFloat = shutterClosed ? 45 : (profile == .full ? 225 : 57)
        return CGRect(x: 24, y: rootHeight + 34 - stripTop - 29, width: 216, height: 32)
    }
    public func shellState(attached: Bool, scope: String = "all") -> CockpitShellState {
        .init(closed: shutterClosed, attached: attached, forcedClosed: forcedClosed,
              tier: profile == .full ? .tall : .compact, scope: scope)
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
