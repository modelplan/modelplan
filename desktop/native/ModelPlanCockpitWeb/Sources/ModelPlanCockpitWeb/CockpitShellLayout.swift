// SPDX-License-Identifier: MIT
import Foundation

/// Settings "Cockpit size" (owner D51, D60, D66). The cockpit is drawn at this size, the study layout scaled as one
/// page; on a screen too short for it, smaller, down to the readable floor. Auto is the default. D66, amended by the
/// owner 11-18 (G3-132): Auto is judged on the SET of connected displays, not the display the cockpit is on: 85 % when
/// any of them is laptop-width (up to 1512 pt), 100 % only when all are wider. Every choice, Auto or a fixed %, is then
/// capped by the smallest connected display (`CockpitSizeBasis`), so the size is the same on every display.
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

/// G3-132 (owner, 11-18): one cockpit size on every display. Of all connected displays: the smallest visible height
/// and visible width (the cap: the largest scale at which the full cockpit fits the smallest display, D51 floor and short
/// version as before) and the smallest full width (Auto: laptop-width if any display is). It depends only on the set of
/// displays, so it never changes while the cockpit is dragged between them; it changes when the setting changes or a
/// display is added or removed (the controller reads it at each layout; a relayout follows
/// `NSApplication.didChangeScreenParametersNotification`).
public struct CockpitSizeBasis: Equatable, Sendable {
    public let visibleHeight: CGFloat, visibleWidth: CGFloat, screenWidth: CGFloat
    public init(visibleHeight: CGFloat, visibleWidth: CGFloat, screenWidth: CGFloat) {
        self.visibleHeight = visibleHeight; self.visibleWidth = visibleWidth; self.screenWidth = screenWidth
    }
    /// The basis of a set of displays; nil without a usable display.
    public init?(screens: [CockpitScreen]) {
        let usable = screens.filter { $0.visibleFrame.width > 0 && $0.visibleFrame.height > 0 && $0.frame.width > 0 }
        guard let height = usable.map(\.visibleFrame.height).min(), let width = usable.map(\.visibleFrame.width).min(),
              let full = usable.map(\.frame.width).min(), height.isFinite, width.isFinite, full.isFinite else { return nil }
        self.init(visibleHeight: height, visibleWidth: width, screenWidth: full)
    }
}

/// Window geometry only. The web page remains the sole cockpit renderer.
public struct CockpitShellLayout: Equatable, Sendable {
    /// The base reserve under the root holds the base bells and their flames (owner D51: always shown),
    /// so every fit is computed on the root plus this reserve, never on the root alone.
    public static let baseReserve: CGFloat = 46
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
    /// G3-108: the page always lays out on the open root's canvas (905 / 635 plus the base reserve), open or closed, and
    /// the web view keeps that canvas, bottom-anchored in the window. The closed page draws its slab right above the
    /// strip, so the body (strip, panels, base) is at the same page position in both states and never moves in the web
    /// view when the shutter toggles; only the window's top edge (detached) or the whole window (attached) moves.
    public let canvasRootHeight: CGFloat
    /// The web view's height in points: the scaled open canvas, on a whole point.
    public let canvasHeight: CGFloat
    public let frame: CGRect
    /// The chosen size did not fit this screen, so the cockpit is drawn smaller.
    public let sizeFellBack: Bool
    /// CKP-SHELL-33 (owner D175/D178): the attached cockpit hangs this far below the menu bar; only the launch rack
    /// shows in the gap.
    public static let menuBarGap: CGFloat = 10
    /// The gap the size tier (full / short / forced closed) is judged with: the pre-rack 6 pt, so the 10 pt gap comes out
    /// of free space (a slightly smaller scale) and never changes which tier a screen gets (D51 thresholds unchanged).
    static let tierGap: CGFloat = 6
    /// CKP-SHELL-33 (D158): the menu bar icon sits above the cockpit's LEFT canopy shoulder. The shoulder's x in page
    /// px (636 px canvas, 8 px margin), measured on the accepted rack demo's hull art (v7/v8: 40 pt and 16 pt of the
    /// 480 pt-wide 620 px shell, full and short versions).
    public static func shoulderX(_ profile: CockpitAppearance.Profile) -> CGFloat { profile == .full ? 60 : 29 }
    /// How far below the window top the hull/canopy edge is at the shoulder, in page px (same measurement). The rack
    /// is visible above this line only; nothing of it is drawn below it inside the cockpit's frame (D175: nothing
    /// shows through the window).
    /// Closed (shutter closed or forced closed): the window's top edge IS the slab's top edge (G3-108 cuts the porthole
    /// band above it), so the hull edge at the shoulder is 0 px below the top; the open hull's 32 px / 6 px would let
    /// the rack hang that far into empty space until the cockpit covers it.
    public static func shoulderDrop(_ profile: CockpitAppearance.Profile, closed: Bool) -> CGFloat {
        closed ? 0 : (profile == .full ? 32 : 6)
    }
    /// `screenWidth` is the full width of the screen the cockpit opens on; it defaults to the usable width.
    /// `forceCompact` (CKP-SHELL-33 key-detach landing, D187): the short version even where the full one fits.
    /// `basis` (G3-132): the size basis of all connected displays; without it, this display alone (as before G3-132).
    public static func fit(usable: CGRect, anchor: CGRect, shutterClosed: Bool, size: CockpitSize = .standard, screenWidth: CGFloat? = nil,
                           forceCompact: Bool = false, basis: CockpitSizeBasis? = nil) -> Self? {
        guard !usable.isNull, !usable.isInfinite, usable.width.isFinite, usable.height.isFinite, usable.width > 0, usable.height > 40,
              usable.origin.x.isFinite, usable.origin.y.isFinite,
              anchor.origin.x.isFinite, anchor.origin.y.isFinite else { return nil }
        // `usable` already excludes the menu bar; the top gap is 10 pt below the menu bar (D178), on a whole point.
        let top = (min(usable.maxY, anchor.minY) - Self.menuBarGap).rounded(.down)
        let available = top - usable.minY
        guard available > 0 else { return nil }
        // G3-132: with a `basis`, Auto is judged on the set of displays and the room is the smallest display's, so every
        // display gets the same size. This display's own room stays a bound (it is never smaller than the basis).
        let tierAvailable = (min(usable.maxY, anchor.minY) - Self.tierGap).rounded(.down) - usable.minY
        let room = basis.map { min(available, ($0.visibleHeight - Self.menuBarGap).rounded(.down)) } ?? available
        let tierRoom = basis.map { min(tierAvailable, ($0.visibleHeight - Self.tierGap).rounded(.down)) } ?? tierAvailable
        let narrowest = basis.map { min(usable.width, $0.visibleWidth) } ?? usable.width
        let shortest = basis.map { min(usable.height, $0.visibleHeight) } ?? usable.height
        // The chosen size, or less when the (smallest) display is too short or narrow for it.
        let chosen = size.scale(screenWidth: basis?.screenWidth ?? screenWidth ?? usable.width)
        func fitting(_ root: CGFloat, _ room: CGFloat) -> CGFloat { min(chosen, narrowest / Self.width, room / (root + Self.baseReserve)) }
        var profile = CockpitAppearance.Profile.full, forcedClosed = false
        var scale = fitting(905, room)
        if fitting(905, tierRoom) < Self.minimumFullScale || forceCompact {
            // The short version, as before D51: open when its root fits, otherwise forced closed.
            profile = .compact
            forcedClosed = shortest - Self.tierGap - Self.baseReserve < 635
            scale = fitting(forcedClosed ? 609 : 635, room)
        }
        let fellBack = scale < chosen
        let closed = shutterClosed || forcedClosed
        let height: CGFloat = profile == .full ? (closed ? 691 : 905) : (closed ? 609 : 635)
        let openRoot: CGFloat = profile == .full ? 905 : 635
        // The scale follows the open root, so closing the shutter never resizes the strip or the canopy (CKP-SHELL-07:
        // "Closing the shutter keeps the open scale").
        // The window server places borderless panels on whole points, so the frame is pixel-aligned here and the
        // controller, its content bounds and every expectation agree with the real window. Rounding up keeps the scaled
        // page inside the web view: the page is top-anchored in it, so the < 1 pt of slack is transparent space under
        // the base reserve.
        let canvasHeight = Self.wholePoints((openRoot + Self.baseReserve) * scale)
        // G3-108: closed, the window leaves out the porthole band above the slab (strip top - 25 px: the 16 px slab and
        // its 9 px gutter), rounded down so the slab is never cut; the web view keeps the open canvas, bottom-anchored.
        let porthole = closed ? Self.portholeBand(profile: profile, scale: scale) : 0
        let canvas = CGSize(width: min(Self.wholePoints(Self.width * scale), usable.width.rounded(.down)),
                            height: min(canvasHeight - porthole, available.rounded(.down)))
        let x = max(usable.minX.rounded(.up), min(attachedX(anchor: anchor, width: canvas.width, scale: scale, usable: usable, profile: profile).rounded(),
                                                  (usable.maxX - canvas.width).rounded(.down)))
        return Self(profile: profile, shutterClosed: closed, forcedClosed: forcedClosed, scale: scale, rootHeight: height,
                    canvasRootHeight: openRoot, canvasHeight: canvasHeight,
                    frame: CGRect(x: x, y: top - canvas.height, width: canvas.width, height: canvas.height), sizeFellBack: fellBack)
    }
    /// The strip's top in the page canvas (the open root's; the closed page keeps the strip there too, G3-108).
    static func stripTop(_ profile: CockpitAppearance.Profile) -> CGFloat { profile == .full ? 253 : 65 }
    /// Owner 11-19 (#1062): the porthole band at the top of the web view (the page is top-anchored in it, open or closed):
    /// the canvas above the closed slab. An activation click there only brings the cockpit forward, so it never opens the
    /// enlarged field; below it (faders, keys, tabs) the first click still acts.
    public var portholeActivationBand: CGFloat { Self.portholeBand(profile: profile, scale: scale) }
    /// G3-108: the closed slab (16 px) and the gutter under it (9 px) stand directly above the strip.
    public static let closedSlabBand: CGFloat = 25
    /// G3-108: the points the closed window leaves out above the slab (0 when open). Attached, the window keeps its
    /// top edge and the body rises by this much; detached, the body stays and the top edge comes down by this much.
    public var portholeHeight: CGFloat { canvasHeight - frame.height }
    /// The smallest whole point count that holds `length`; float noise (913/939 * 939) never adds a point.
    static func wholePoints(_ length: CGFloat) -> CGFloat { (length - 1e-6).rounded(.up) }
    /// D378 (owner, 11-21; replaces G3-46's top-right corner for an icon that is not visible): with the status item
    /// hidden or squeezed off, the cockpit anchors just below the RIGHT edge of the notch (the camera housing), and the
    /// rack hangs from the menu bar's edge there, its left side on the notch's edge. Without a notch the same place a
    /// notch edge would be: `nominalNotchHalfWidth` right of the menu bar's centre. The rect has the rack's width and
    /// the menu bar's height, like a status item there.
    public static let nominalNotchHalfWidth: CGFloat = 100
    public static func menuBarEdgeAnchor(screen: CockpitScreen) -> CGRect {
        let usable = screen.visibleFrame
        let edge = (screen.notchRightEdge ?? screen.frame.midX + nominalNotchHalfWidth).rounded()
        return CGRect(x: edge, y: usable.maxY, width: CockpitDockingBoom.nominalWidth, height: max(1, screen.frame.maxY - usable.maxY))
    }
    /// G3-46: the top-right of a display that is not the status item's own (a detached open there), below the menu bar.
    public static func hiddenIconAnchor(usable: CGRect) -> CGRect {
        CGRect(x: usable.maxX, y: usable.maxY, width: 0, height: 0)
    }
    /// CKP-SHELL-33 (D158, supersedes D88's centring): the menu bar icon sits above the cockpit's left canopy shoulder.
    /// Near a screen edge it shifts just enough to stay on the screen.
    public static func attachedX(anchor: CGRect, width: CGFloat, scale: CGFloat, usable: CGRect,
                                 profile: CockpitAppearance.Profile = .full) -> CGFloat {
        max(usable.minX, min(anchor.midX - shoulderX(profile) * scale, usable.maxX - width))
    }
    /// The shoulder point in screen coordinates for this layout's frame: where the rack meets the cockpit.
    public var shoulder: CGPoint {
        CGPoint(x: frame.minX + Self.shoulderX(profile) * scale, y: frame.maxY - rackMaskDrop)
    }
    /// How far below the window top the launch rack's mask line is, in points, for a settled window.
    public var rackMaskDrop: CGFloat { rackMaskDrop(windowHeight: frame.height) }
    /// The mask line for a window of `windowHeight`: the shutter animation resizes the attached window between the closed
    /// height (slab at the top edge, line 0) and the open height (line at the hull's shoulder), so the line follows the
    /// window's own height and moves with the slab, driven by the shutter's frame animation (no separate timer).
    public func rackMaskDrop(windowHeight: CGFloat) -> CGFloat {
        let open = Self.shoulderDrop(profile, closed: false) * scale
        let band = Self.portholeBand(profile: profile, scale: scale)
        guard band > 0 else { return Self.shoulderDrop(profile, closed: shutterClosed) * scale }
        let closedHeight = canvasHeight - band
        return open * min(1, max(0, (windowHeight - closedHeight) / band))
    }
    /// The porthole band the closed window leaves out above the slab (G3-108), in points.
    static func portholeBand(profile: CockpitAppearance.Profile, scale: CGFloat) -> CGFloat {
        ((stripTop(profile) - closedSlabBand) * scale).rounded(.down)
    }
    /// The page canvas in CSS px: the open root plus the base reserve, open or closed (G3-108).
    public var pageSize: CGSize { .init(width: Self.width, height: canvasRootHeight + Self.baseReserve) }
    /// The web view's frame in the window: the open canvas, bottom-anchored, so the body keeps its place in the window
    /// whatever the window's height (G3-108).
    public var webFrame: CGRect { CGRect(x: 0, y: 0, width: frame.width, height: canvasHeight) }
    /// G3-43 / CKP-SHELL-04: the free left of the title strip in page px with Y up; the window uses
    /// `scaledTitleDragFrame`. It stops short of ALERT (page x 214, WP-10) so buttons keep their own input. G3-108: the closed page
    /// keeps the strip at its open place on the canvas (253 tall, 65 compact). Pinned on the page by b13-hull-taper.spec.mjs.
    public var titleDragFrame: CGRect {
        CGRect(x: 24, y: pageSize.height - Self.stripTop(profile) - 29, width: 190, height: 32)
    }
    public var scaledTitleDragFrame: CGRect { windowRect(page: titleDragFrame) }
    /// A page rect (CSS px, Y up from the canvas bottom) in window points: scaled, then lifted by the slack the
    /// whole-point web view leaves under the top-anchored page. The web view stands on the window's bottom edge.
    public func windowRect(page rect: CGRect) -> CGRect {
        rect.applying(.init(scaleX: scale, y: scale)).offsetBy(dx: 0, dy: canvasHeight - pageSize.height * scale)
    }

    public func shellState(attached: Bool, scope: String = "all", range: CockpitRange = .initial, refreshing: Bool = false) -> CockpitShellState {
        .init(closed: shutterClosed, attached: attached, forcedClosed: forcedClosed,
              tier: profile == .full ? .tall : .compact, scope: scope, range: range, refreshing: refreshing)
    }
    /// G3-159: the transparent base reserve (bells and flames) under the hull, in window points. A detached cockpit is
    /// kept on screen by its hull, so this strip may hang below the visible frame's bottom edge. AppKit places the
    /// panel on whole points. Round the allowed overhang down so the panel cannot round past the hull's bottom edge.
    public var hullBottomInset: CGFloat { (Self.baseReserve * scale).rounded(.down) }
    public func clamping(origin: CGPoint, usable: CGRect) -> CGRect {
        CockpitScreenSelection.clamp(CGRect(origin: origin, size: frame.size), into: usable,
                                     bottomOverhang: hullBottomInset)
    }
}

/// Retained by the console owner, never by the discarded WebKit page.
@MainActor public final class CockpitShellSession {
    public var detached = false
    public var shutterClosed = false
    /// CKP-SHELL-33 (D187): a key detach that found no room for the full cockpit switched to the short version; it
    /// stays short while detached and is cleared by a put back.
    public var compactWhileDetached = false
    /// Set by the console just before an open and consumed by it; the menu bar icon opens rack-first (CKP-SHELL-33).
    public var nextEntrance: CockpitEntrance = .fade
    private var origins: [(String, CGPoint)] = []
    public init() {}
    public func origin(for arrangement: String) -> CGPoint? { origins.first { $0.0 == arrangement }?.1 }
    public func remember(_ origin: CGPoint, arrangement: String) {
        origins.removeAll { $0.0 == arrangement }; origins.append((arrangement, origin))
        if origins.count > 8 { origins.removeFirst() }
    }
}
