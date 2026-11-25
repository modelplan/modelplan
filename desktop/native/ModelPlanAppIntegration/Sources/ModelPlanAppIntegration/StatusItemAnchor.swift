// SPDX-License-Identifier: MIT
import AppKit

/// Build 5 (owner 11-25, menu-bar binding): the rect the attached cockpit and its launch rack hang from.
///
/// The status item button's window is not a reliable source on its own. Before the menu bar has laid the item out
/// (first open, a length change from the automatic display, a display change) its window can sit at a parking frame,
/// for example x 0 in the menu bar band or below the screen. With several displays the item also has a copy on every
/// menu bar, and the one window AppKit hands back is the copy on whichever menu bar laid it out last. The old anchor
/// accepted any frame that merely touched a display, so the cockpit opened at the display's left edge with the rack at
/// its top-left corner, or under another display's copy of the item.
///
/// The anchor is therefore resolved from two facts:
/// - the window rect, accepted only when its centre is inside some display's menu bar band (the same placement rule as
///   the U6 frame sampler), and
/// - the click that opened the cockpit: the pointer's global location and where in the button it was pressed, which
///   names the copy the user actually clicked without asking the window where it is.
/// While the click is current (same display arrangement, same item width) and the window rect does not hold the click
/// point, the click wins. Otherwise the placed window rect is used, and with neither the anchor is nil (D378: the notch
/// fallback on the status item's display).
///
/// Reference: Pulse@7668384cbcf357bba7dee4af85b4052a59c6e35d Sources/Pulse/Panel/PanelPlacement.swift (placement is
/// re-derived from the current screen geometry on every placement, never from a frame cached for another arrangement).
struct StatusItemAnchor: Equatable {
    struct Display: Equatable {
        let frame: CGRect, visibleFrame: CGRect
        init(frame: CGRect, visibleFrame: CGRect) { self.frame = frame; self.visibleFrame = visibleFrame }
        @MainActor static func system() -> [Display] { NSScreen.screens.map { Display(frame: $0.frame, visibleFrame: $0.visibleFrame) } }
    }
    /// The icon as the click saw it, in global screen coordinates.
    let rect: CGRect
    /// The pointer at the press.
    let point: CGPoint
    /// The display arrangement at the press; another arrangement (a display added, removed, moved or woken with a new
    /// layout) makes the click stale.
    let displays: [CGRect]

    /// The click on the status button: `pointer` is the global pointer location, `local` the press in the button's own
    /// coordinates (independent of where AppKit says the button's window is).
    static func click(pointer: CGPoint, local: CGPoint, buttonBounds: CGRect, flipped: Bool, displays: [Display]) -> StatusItemAnchor? {
        let values = [pointer.x, pointer.y, local.x, local.y, buttonBounds.width, buttonBounds.height]
        guard values.allSatisfy(\.isFinite), buttonBounds.width > 0, buttonBounds.height > 0 else { return nil }
        // A press reported just outside the button (its edge pixel) is taken at the nearest point inside it.
        let x = min(max(local.x, buttonBounds.minX), buttonBounds.maxX), y = min(max(local.y, buttonBounds.minY), buttonBounds.maxY)
        let fromLeft = x - buttonBounds.minX
        let fromBottom = flipped ? buttonBounds.maxY - y : y - buttonBounds.minY
        let rect = CGRect(x: pointer.x - fromLeft, y: pointer.y - fromBottom, width: buttonBounds.width, height: buttonBounds.height)
        return StatusItemAnchor(rect: rect, point: pointer, displays: displays.map(\.frame))
    }

    /// The display whose menu bar band holds the centre of `rect` (not at its left edge), or nil while the rect is not
    /// placed in a menu bar.
    /// The band is the strip above the visible frame, at least `menuHeight` tall (a hidden menu bar leaves none).
    static func menuBarDisplay(of rect: CGRect, displays: [Display], menuHeight: CGFloat) -> Display? {
        let values = [rect.minX, rect.minY, rect.width, rect.height]
        guard values.allSatisfy(\.isFinite), rect.width > 0, rect.height > 0 else { return nil }
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        return displays.first { display in
            let height = max(display.frame.maxY - display.visibleFrame.maxY, menuHeight, 1)
            let band = CGRect(x: display.frame.minX, y: display.frame.maxY - height, width: display.frame.width, height: height)
            // A parking frame sits at the display's left edge, where the app menus are; no status item starts there.
            return band.contains(centre) && rect.minX > display.frame.minX + 0.5
        }
    }

    /// The anchor for this moment. `window` is the button's rect from its window (nil when there is none or it is not
    /// visible), `click` the press that opened the cockpit (nil for other entries), `itemWidth` the button's current width.
    static func resolve(window: CGRect?, click: StatusItemAnchor?, itemWidth: CGFloat?, displays: [Display],
                        menuHeight: CGFloat) -> CGRect? {
        let placedWindow = window.flatMap { rect in menuBarDisplay(of: rect, displays: displays, menuHeight: menuHeight).map { (rect, $0) } }
        let current = click.flatMap { click -> (StatusItemAnchor, Display)? in
            guard click.displays == displays.map(\.frame),
                  itemWidth.map({ abs($0 - click.rect.width) < 0.5 }) ?? true,
                  let display = menuBarDisplay(of: click.rect, displays: displays, menuHeight: menuHeight) else { return nil }
            return (click, display)
        }
        if let placed = placedWindow {
            guard let current else { return placed.0 }
            let rect = placed.0, point = current.0.point
            let holds = placed.1 == current.1 && rect.minX - 1 <= point.x && point.x <= rect.maxX + 1
            return holds ? rect : current.0.rect
        }
        return current?.0.rect
    }
}
