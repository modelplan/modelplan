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
/// - the click that opened the cockpit: the mouse-down's own screen point and where in the button it was pressed, which
///   names the copy the user actually clicked, even if AppKit later reports the item's window elsewhere.
/// While the click is current (same display arrangement), the anchor stays on the clicked display whatever the item's
/// width (see `resolve`). Without one, `placement` picks the display the user acted on and that display's copy, and
/// never a copy behind the notch (build 6, owner 11-27): AppKit reports such a copy as visible and on screen, and the
/// cockpit then opened just left of the notch on the built-in display. With no visible copy the anchor is nil (D378:
/// the notch fallback on the status item's display).
///
/// Reference: Pulse@7668384cbcf357bba7dee4af85b4052a59c6e35d Sources/Pulse/Panel/PanelPlacement.swift (placement is
/// re-derived from the current screen geometry on every placement, never from a frame cached for another arrangement).
struct StatusItemAnchor: Equatable {
    struct Display: Equatable {
        let frame: CGRect, visibleFrame: CGRect
        /// Build 6 (owner 11-27): the global x of the camera housing's right edge on a display with a notch, nil
        /// without one. The menu bar shows status items only right of it; a copy at or left of it is behind the notch.
        let notchRightEdge: CGFloat?
        init(frame: CGRect, visibleFrame: CGRect, notchRightEdge: CGFloat? = nil) {
            self.frame = frame; self.visibleFrame = visibleFrame; self.notchRightEdge = notchRightEdge
        }
        /// `NSScreen.screens` order: the first is the primary display (the one with the menu bar in the arrangement).
        @MainActor static func system() -> [Display] {
            NSScreen.screens.map { Display(frame: $0.frame, visibleFrame: $0.visibleFrame, notchRightEdge: notchRightEdge($0)) }
        }
        /// The unobscured top-right area ends at the notch; measured from the right edge by that area's width, so it
        /// does not depend on the coordinate space AppKit reports the area in (same rule as `CockpitScreen`, D378).
        @MainActor static func notchRightEdge(_ screen: NSScreen) -> CGFloat? {
            guard screen.safeAreaInsets.top > 0, let right = screen.auxiliaryTopRightArea, right.width > 0,
                  right.width < screen.frame.width else { return nil }
            return screen.frame.maxX - right.width
        }
    }
    /// The icon as the click saw it, in global screen coordinates.
    let rect: CGRect
    /// The press point on screen, from the mouse-down event itself (never the live cursor).
    let point: CGPoint
    /// The display arrangement at the press; another arrangement (a display added, removed, moved or woken with a new
    /// layout) makes the click stale.
    let displays: [CGRect]

    /// The click on the status button: `pointer` is the mouse-down's screen point and `local` the same event's point in
    /// the button's own coordinates, so the two describe one moment (macrev2-1251-2).
    static func click(pointer: CGPoint, local: CGPoint, buttonBounds: CGRect, flipped: Bool, displays: [Display]) -> StatusItemAnchor? {
        let values = [pointer.x, pointer.y, local.x, local.y, buttonBounds.width, buttonBounds.height]
        guard values.allSatisfy(\.isFinite), buttonBounds.width > 0, buttonBounds.height > 0 else { return nil }
        // A press reported just outside the button (its edge pixel) is taken at the nearest point inside it. Far outside,
        // the local point was converted through a window whose reported geometry is not the pressed copy's (parked or
        // another display's): only the screen point is trustworthy, so the rect is centred on it.
        let stale = local.x < buttonBounds.minX - 1 || local.x > buttonBounds.maxX + 1 || local.y < buttonBounds.minY - 1 || local.y > buttonBounds.maxY + 1
        let x = stale ? buttonBounds.midX : min(max(local.x, buttonBounds.minX), buttonBounds.maxX)
        let y = stale ? buttonBounds.midY : min(max(local.y, buttonBounds.minY), buttonBounds.maxY)
        let fromLeft = x - buttonBounds.minX
        let fromBottom = flipped ? buttonBounds.maxY - y : y - buttonBounds.minY
        let rect = CGRect(x: pointer.x - fromLeft, y: pointer.y - fromBottom, width: buttonBounds.width, height: buttonBounds.height)
        return StatusItemAnchor(rect: rect, point: pointer, displays: displays.map(\.frame))
    }

    /// Build 6 (owner 11-27, fourth report): where the press happened on screen, from the window server only. The
    /// event's window is AppKit's one status-item window, which can be another display's copy (the one behind the
    /// notch), so a point converted through it can land on the wrong display (#1251 round 2 assumed otherwise and was
    /// never checked on a device). The mouse-down's own window-server record (`CGEvent.unflippedLocation`, global and
    /// bottom-left like `NSEvent.mouseLocation`) is used, and the window server's cursor position at the click only when
    /// the event has none. The offset inside the button still comes from the event and is discarded by `click` when stale.
    @MainActor static func eventScreenPoint(_ event: NSEvent) -> CGPoint? {
        windowServerPoint(event: event.cgEvent?.unflippedLocation, cursor: NSEvent.mouseLocation)
    }
    static func windowServerPoint(event: CGPoint?, cursor: CGPoint) -> CGPoint? {
        if let event, event.x.isFinite, event.y.isFinite { return event }
        return cursor.x.isFinite && cursor.y.isFinite ? cursor : nil
    }

    /// The display whose menu bar band holds the centre of `rect` (not at its left edge), or nil while the rect is not
    /// placed in a menu bar.
    /// The band is the strip above the visible frame, at least `menuHeight` tall (a hidden menu bar leaves none).
    static func menuBarDisplay(of rect: CGRect, displays: [Display], menuHeight: CGFloat) -> Display? {
        let values = [rect.minX, rect.minY, rect.width, rect.height]
        guard values.allSatisfy(\.isFinite), rect.width > 0, rect.height > 0 else { return nil }
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        return displays.first { display in
            let height = bandHeight(display, menuHeight: menuHeight)
            let band = CGRect(x: display.frame.minX, y: display.frame.maxY - height, width: display.frame.width, height: height)
            // A parking frame sits at the display's left edge, where the app menus are; no status item starts there.
            return band.contains(centre) && rect.minX > display.frame.minX + 0.5
        }
    }
    private static func bandHeight(_ display: Display, menuHeight: CGFloat) -> CGFloat {
        max(display.frame.maxY - display.visibleFrame.maxY, menuHeight, 1)
    }

    /// Build 6 (owner 11-27): a copy whose centre is at or left of the notch's right edge is behind the notch (in the
    /// housing between `auxiliaryTopLeftArea` and `auxiliaryTopRightArea`, or squeezed further left): not visible, however
    /// `isVisible` and the occlusion state report its window.
    static func underNotch(_ rect: CGRect, on display: Display) -> Bool {
        guard let edge = display.notchRightEdge else { return false }
        return rect.midX < edge
    }

    /// A status-item rect AppKit reports, with whether its window is drawn (`isVisible` and a visible occlusion state).
    /// A click's rect counts as drawn: the user saw and pressed it.
    struct Known: Equatable {
        let rect: CGRect, drawn: Bool
        init(_ rect: CGRect, drawn: Bool = true) { self.rect = rect; self.drawn = drawn }
    }

    /// One copy of the item per display: the first known rect placed on that display's menu bar (visible only when it is
    /// drawn and not behind the notch), else, on a display with no known rect at all, the rect projected from a source
    /// (status items are right-aligned, so every copy keeps the same distance from its display's right edge, at the
    /// item's current width). A source is a placed rect that is drawn or hidden only by the notch; an undrawn copy that
    /// is not behind the notch (occluded, full screen) is evidence of nothing, so with no source nothing is projected.
    struct Copy: Equatable { let display: Display; let rect: CGRect; let visible: Bool; let real: Bool }
    static func copies(known: [Known], itemWidth: CGFloat?, displays: [Display], menuHeight: CGFloat) -> [Copy] {
        let placed = known.compactMap { item in menuBarDisplay(of: item.rect, displays: displays, menuHeight: menuHeight).map { ($0, item) } }
        let sources = placed.filter { $0.1.drawn || underNotch($0.1.rect, on: $0.0) }
        let source = sources.first(where: { !underNotch($0.1.rect, on: $0.0) }) ?? sources.first
        let width = itemWidth.flatMap { $0.isFinite && $0 > 0 ? $0 : nil } ?? source?.1.rect.width ?? 0
        return displays.compactMap { display in
            if let real = placed.first(where: { $0.0 == display }) {
                return Copy(display: display, rect: real.1.rect, visible: real.1.drawn && !underNotch(real.1.rect, on: display), real: true)
            }
            guard let source, width > 0 else { return nil }
            let offset = source.0.frame.maxX - source.1.rect.maxX
            let band = bandHeight(display, menuHeight: menuHeight), height = min(source.1.rect.height, band)
            let rect = CGRect(x: display.frame.maxX - offset - width, y: display.frame.maxY - band / 2 - height / 2, width: width, height: height)
            guard menuBarDisplay(of: rect, displays: [display], menuHeight: menuHeight) != nil else { return nil }
            return Copy(display: display, rect: rect, visible: !underNotch(rect, on: display), real: false)
        }
    }

    /// Whether the item can be seen at all, one entry per status-item window plus one per display that has no window
    /// of its own (its copy projected, see `copies`). A window counts when it is drawn on some display and not behind
    /// the notch.
    static func copyVisibilities(windows: [(frame: CGRect, drawn: Bool)], itemWidth: CGFloat?, displays: [Display],
                                 menuHeight: CGFloat) -> [Bool] {
        var states = [Bool]()
        for window in windows {
            let onScreen = displays.contains { $0.frame.intersects(window.frame) }
            let placed = menuBarDisplay(of: window.frame, displays: displays, menuHeight: menuHeight)
            let notched = placed.map { underNotch(window.frame, on: $0) } ?? false
            states.append(window.drawn && onScreen && !notched)
        }
        let known = windows.map { Known($0.frame, drawn: $0.drawn) }
        for copy in copies(known: known, itemWidth: itemWidth, displays: displays, menuHeight: menuHeight) where !copy.real {
            states.append(copy.visible)
        }
        return states
    }

    /// Where the attached cockpit opens: the display and the icon rect it hangs from (nil anchor: D378's fallback on
    /// `display`). Invariant (owner 11-27): the cockpit opens on the display the user acted on, and never hangs from a
    /// copy that is behind the notch or not drawn.
    /// - A current status-item click: the clicked display, anchored by `resolve`; when the item's current copy there is
    ///   undrawn or behind the notch, or the resolved rect is (a width change moved it), no anchor on that display.
    /// - An open from a point (`actedAt`: the widget's red button or its Open Cockpit action): that display's copy when
    ///   the menu bar shows it there.
    /// - Otherwise, or when that copy is hidden: the display of the last status-item click (same arrangement), then a
    ///   display without a notch (primary first), then any display that shows the copy.
    /// - No visible copy anywhere: no anchor, on the acted-on display, else the window's.
    struct Placement: Equatable { let display: Display?; let anchor: CGRect? }
    static func placement(window: Known?, copies others: [Known] = [], click: StatusItemAnchor?, actedAt: CGPoint?,
                          lastClick: StatusItemAnchor?, itemWidth: CGFloat?, displays: [Display], menuHeight: CGFloat) -> Placement {
        let reported = (window.map { [$0] } ?? []) + others
        if let click, let clicked = clickedDisplay(click, displays: displays, menuHeight: menuHeight) {
            let hiddenHere = Placement(display: clicked, anchor: nil)
            // The item's current copy on the clicked display, as AppKit reports it now.
            if let current = reported.first(where: { menuBarDisplay(of: $0.rect, displays: displays, menuHeight: menuHeight) == clicked }),
               !current.drawn || underNotch(current.rect, on: clicked) { return hiddenHere }
            guard let rect = resolve(window: window?.rect, click: click, itemWidth: itemWidth, displays: displays, menuHeight: menuHeight),
                  menuBarDisplay(of: rect, displays: displays, menuHeight: menuHeight) == clicked, !underNotch(rect, on: clicked),
                  !(window.map { $0.rect == rect && !$0.drawn } ?? false) else { return hiddenHere }
            return Placement(display: clicked, anchor: rect)
        }
        let lastDisplay = clickedDisplay(lastClick, displays: displays, menuHeight: menuHeight)
        let width = itemWidth.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        // The last click's rect, at the item's current width about its right edge, while some reported copy is drawn or
        // hidden only by the notch (with every copy occluded the click proves nothing about now).
        let evidence = reported.contains { item in
            menuBarDisplay(of: item.rect, displays: displays, menuHeight: menuHeight).map { item.drawn || underNotch(item.rect, on: $0) } ?? false
        }
        var lastRect: Known?
        if evidence, lastDisplay != nil, let last = lastClick {
            let w = width ?? last.rect.width
            lastRect = Known(CGRect(x: last.rect.maxX - w, y: last.rect.minY, width: w, height: last.rect.height))
        }
        let all = copies(known: reported + (lastRect.map { [$0] } ?? []), itemWidth: width, displays: displays, menuHeight: menuHeight)
        func shown(_ display: Display?) -> Placement? {
            guard let display, let copy = all.first(where: { $0.display == display && $0.visible }) else { return nil }
            return Placement(display: display, anchor: copy.rect)
        }
        var acted: Display?
        if let point = actedAt, point.x.isFinite, point.y.isFinite {
            acted = displays.first { $0.frame.minX <= point.x && point.x <= $0.frame.maxX && $0.frame.minY <= point.y && point.y <= $0.frame.maxY }
        }
        if let found = shown(acted) { return found }
        if let found = shown(lastDisplay) { return found }
        for display in displays where display.notchRightEdge == nil { if let found = shown(display) { return found } }
        for display in displays { if let found = shown(display) { return found } }
        return Placement(display: acted ?? window.flatMap { menuBarDisplay(of: $0.rect, displays: displays, menuHeight: menuHeight) }, anchor: nil)
    }

    /// The display the click was made on, while the display arrangement is the one it was made in. macrev2-1251-1:
    /// independent of the item's width, so a width change after the press never hands the cockpit to another copy.
    static func clickedDisplay(_ click: StatusItemAnchor?, displays: [Display], menuHeight: CGFloat) -> Display? {
        guard let click, click.displays == displays.map(\.frame) else { return nil }
        return menuBarDisplay(of: click.rect, displays: displays, menuHeight: menuHeight)
    }

    /// The anchor for this moment. `window` is the button's rect from its window (nil when there is none or it is not
    /// visible), `click` the press that opened the cockpit (nil for other entries), `itemWidth` the button's current width.
    ///
    /// With a current click the anchor is always on the clicked display: the window rect when it is placed there and
    /// either holds the click or carries a newer width (the item's current geometry on that display); otherwise the
    /// click's rect, resized to a changed width about its right edge (status items grow and shrink leftwards).
    static func resolve(window: CGRect?, click: StatusItemAnchor?, itemWidth: CGFloat?, displays: [Display],
                        menuHeight: CGFloat) -> CGRect? {
        let placedWindow = window.flatMap { rect in menuBarDisplay(of: rect, displays: displays, menuHeight: menuHeight).map { (rect, $0) } }
        guard let click, let clicked = clickedDisplay(click, displays: displays, menuHeight: menuHeight) else { return placedWindow?.0 }
        let width = itemWidth.flatMap { $0.isFinite && $0 > 0 ? $0 : nil } ?? click.rect.width
        let resized = abs(width - click.rect.width) >= 0.5
        if let placed = placedWindow, placed.1 == clicked {
            let rect = placed.0
            if resized || (rect.minX - 1 <= click.point.x && click.point.x <= rect.maxX + 1) { return rect }
        }
        guard resized else { return click.rect }
        return CGRect(x: click.rect.maxX - width, y: click.rect.minY, width: width, height: click.rect.height)
    }
}
