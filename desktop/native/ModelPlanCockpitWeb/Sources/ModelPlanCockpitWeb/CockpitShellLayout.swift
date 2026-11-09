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
        // Whole points (G3-65): the window is rounded up to whole points below, so the scale fits the whole points the screen has.
        let room = CGSize(width: usable.width.rounded(.down), height: available.rounded(.down))
        func fitting(_ root: CGFloat) -> CGFloat { min(chosen, room.width / Self.width, room.height / (root + Self.baseReserve)) }
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
        let canvas = windowSize(scale: scale, rootHeight: height)
        let x = attachedX(anchor: anchor, width: canvas.width, scale: scale, usable: usable)
        return Self(profile: profile, shutterClosed: closed, forcedClosed: forcedClosed, scale: scale, rootHeight: height,
                    frame: CGRect(x: x, y: top - canvas.height, width: canvas.width, height: canvas.height), sizeFellBack: fellBack)
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
    /// G3-65: the window for a page canvas at `scale`, rounded UP to whole points. The hull's lower side walls are
    /// painted across the whole 636 CSS px canvas, edge to edge, with no transparent gutter. WebKit sizes a WKWebView's
    /// page in whole points, dropping the fraction, so a 636 x 0.85 = 540.6 pt window gave the page 540 pt = 635.3 CSS px;
    /// the 620 px shell, centred by `margin: 0 auto`, then lost the outer columns of both side walls. Rounding up gives
    /// the page at least 636 x (root + reserve) CSS px at every scale: 80 % is 509 pt, 85 % 541, 90 % 573, 100 % 636.
    public static func windowSize(scale: CGFloat, rootHeight: CGFloat) -> CGSize {
        func up(_ value: CGFloat) -> CGFloat { (value - 1e-6).rounded(.up) }
        return CGSize(width: up(width * scale), height: up((rootHeight + baseReserve) * scale))
    }
    /// The page canvas in CSS px: the root plus the base reserve.
    public var pageSize: CGSize { .init(width: Self.width, height: rootHeight + Self.baseReserve) }
    /// G3-65: what the page really lays out in, CSS px: the whole-point window divided by the page zoom.
    /// Never narrower or shorter than `pageSize`, so no painted hull pixel falls outside the window.
    public var pageViewport: CGSize { .init(width: frame.width / scale, height: frame.height / scale) }
    /// G3-43 / CKP-SHELL-04: the free left of the title strip in page px with Y up; the window uses
    /// `scaledTitleDragFrame`. It stops short of the shutter so buttons keep their own input. Strip tops are the page's, shared with the study.
    public var titleDragFrame: CGRect {
        let stripTop: CGFloat = shutterClosed ? 45 : (profile == .full ? 225 : 57)
        return CGRect(x: 24, y: rootHeight + 34 - stripTop - 29, width: 216, height: 32)
    }
    /// In window points, Y up. The page is laid out from the window's top edge, so the strip keeps its place below
    /// the top when the window is rounded up to whole points (G3-65).
    public var scaledTitleDragFrame: CGRect {
        titleDragFrame.applying(.init(scaleX: scale, y: scale)).offsetBy(dx: 0, dy: frame.height - pageSize.height * scale)
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
