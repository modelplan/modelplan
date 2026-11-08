// SPDX-License-Identifier: MIT
import Foundation

/// Settings "Cockpit size" (owner D51, D60, D66). The cockpit is drawn at this size, the study layout scaled as one
/// page; on a screen too short for it, smaller, down to the readable floor. Auto is the default (D66): 85 % on
/// laptop-width screens, 100 % on wider ones, judged on the screen the cockpit opens on (the menu bar icon's).
public enum CockpitSize: String, CaseIterable, Sendable {
    case automatic, percent80 = "80", percent85 = "85", percent90 = "90", percent100 = "100"
    public static let standard = CockpitSize.automatic
    /// D66: screens up to this width (13-14 inch laptops, e.g. MacBook Air 1440/1470, MacBook Pro 14 at 1512) get 85 %
    /// under Auto; wider screens (15 inch and up, external displays) get 100 %.
    public static let automaticLaptopScreenWidth: CGFloat = 1512
    public static let automaticLaptopScale: CGFloat = 0.85
    public func scale(screenWidth: CGFloat) -> CGFloat {
        switch self {
        case .automatic: return screenWidth <= Self.automaticLaptopScreenWidth ? Self.automaticLaptopScale : 1
        case .percent80: return 0.8; case .percent85: return 0.85; case .percent90: return 0.9; case .percent100: return 1
        }
    }
}

/// Window geometry only. The web page remains the sole cockpit renderer.
public struct CockpitShellLayout: Equatable, Sendable {
    /// The base reserve under the root holds the base bells and their flames (owner D51: always shown),
    /// so every fit is computed on the root plus this reserve, never on the root alone.
    public static let baseReserve: CGFloat = 34
    public static let width: CGFloat = 636
    /// CKP-SHELL-07 (owner D51): below this scale the full cockpit's smallest labels (8 CSS px) would
    /// fall under 6 pt and its 10 px readings under 7.5 pt; only then does the short version show.
    public static let minimumFullScale: CGFloat = 0.75
    public let profile: CockpitAppearance.Profile
    public let shutterClosed: Bool
    public let forcedClosed: Bool
    /// Uniform page zoom: the page lays out at 636 CSS px and WebKit renders it at this scale, so text
    /// is rasterized at its final size and hit testing stays in page coordinates.
    public let scale: CGFloat
    public let rootHeight: CGFloat
    public let frame: CGRect
    /// The chosen size did not fit this screen, so the cockpit is drawn smaller.
    public let sizeFellBack: Bool
    /// `screenWidth` is the full width of the screen the cockpit opens on; it defaults to the usable width.
    public static func fit(usable: CGRect, anchor: CGRect, shutterClosed: Bool, size: CockpitSize = .standard, screenWidth: CGFloat? = nil) -> Self? {
        guard !usable.isNull, !usable.isInfinite, usable.width.isFinite, usable.height.isFinite, usable.width > 0, usable.height > 40,
              usable.origin.x.isFinite, usable.origin.y.isFinite,
              anchor.origin.x.isFinite, anchor.origin.y.isFinite else { return nil }
        // `usable` already excludes the menu bar; the top gap is 6 pt below the menu bar icon.
        let top = min(usable.maxY, anchor.minY) - 6
        let available = top - usable.minY
        guard available > 0 else { return nil }
        // The chosen size, or less when the screen is too short or narrow for it.
        let chosen = size.scale(screenWidth: screenWidth ?? usable.width)
        func fitting(_ root: CGFloat) -> CGFloat { min(chosen, usable.width / Self.width, available / (root + Self.baseReserve)) }
        var profile = CockpitAppearance.Profile.full, forcedClosed = false
        var scale = fitting(877)
        if scale < Self.minimumFullScale {
            // The short version, as before D51: open when its root fits, otherwise forced closed.
            profile = .compact
            forcedClosed = usable.height - 6 - Self.baseReserve < 627
            scale = fitting(forcedClosed ? 609 : 627)
        }
        let fellBack = scale < chosen
        let closed = shutterClosed || forcedClosed
        let height: CGFloat = profile == .full ? (closed ? 691 : 877) : (closed ? 609 : 627)
        // The scale follows the open root, so closing the shutter never resizes the strip or the canopy.
        let canvas = CGSize(width: Self.width * scale, height: (height + Self.baseReserve) * scale)
        let x = max(usable.minX, min(anchor.midX - canvas.width / 2, usable.maxX - canvas.width))
        return Self(profile: profile, shutterClosed: closed, forcedClosed: forcedClosed, scale: scale, rootHeight: height,
                    frame: CGRect(x: x, y: top - canvas.height, width: canvas.width, height: canvas.height), sizeFellBack: fellBack)
    }
    /// The page canvas in CSS px: the root plus the base reserve.
    public var pageSize: CGSize { .init(width: Self.width, height: rootHeight + Self.baseReserve) }
    /// G3-43 / CKP-SHELL-04: the free left of the title strip in page px with Y up; the window uses
    /// `scaledTitleDragFrame`. It stops short of the shutter so buttons keep their own input. Strip tops are the page's, shared with the study.
    public var titleDragFrame: CGRect {
        let stripTop: CGFloat = shutterClosed ? 45 : (profile == .full ? 225 : 57)
        return CGRect(x: 24, y: rootHeight + 34 - stripTop - 29, width: 216, height: 32)
    }
    public var scaledTitleDragFrame: CGRect { titleDragFrame.applying(.init(scaleX: scale, y: scale)) }
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
