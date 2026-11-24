// SPDX-License-Identifier: MIT
import AppKit

/// One display as the cockpit and the launch field see it, in global screen coordinates (bottom-left origin).
/// A plain value so placement can be tested with any arrangement of displays.
public struct CockpitScreen: Equatable, Sendable {
  public let frame: CGRect
  public let visibleFrame: CGRect
  /// D378: the x (global) of the camera housing's right edge on a display with a notch, nil without one.
  public let notchRightEdge: CGFloat?
  public init(frame: CGRect, visibleFrame: CGRect, notchRightEdge: CGFloat? = nil) {
    self.frame = frame; self.visibleFrame = visibleFrame; self.notchRightEdge = notchRightEdge
  }
  /// D378: the notch's right edge from the system: the unobscured top-right area ends there. Measured from the screen's
  /// right edge by that area's width, so it does not depend on which coordinate space AppKit reports the area in.
  @MainActor public static func notchRightEdge(_ screen: NSScreen) -> CGFloat? {
    guard screen.safeAreaInsets.top > 0, let right = screen.auxiliaryTopRightArea, right.width > 0, right.width < screen.frame.width else { return nil }
    return screen.frame.maxX - right.width
  }
}

/// Build 14c (G3-79, G3-80) and build 15 (G3-128): which display the cockpit and the launch field use. Attached, it is
/// always the menu bar icon's display; a detached open goes to the screen the user clicked on, a drag follows the
/// pointer to any display, and a remembered position is replayed only while it is still on some display.
public enum CockpitScreenSelection {
  /// The system's displays, the main one (the key window's) first so it is the fallback.
  @MainActor public static func system() -> [CockpitScreen] {
    let main = NSScreen.main
    let ordered = (main.map { [$0] } ?? []) + NSScreen.screens.filter { $0 != main }
    return ordered.map { CockpitScreen(frame: $0.frame, visibleFrame: $0.visibleFrame, notchRightEdge: CockpitScreen.notchRightEdge($0)) }
  }
  /// The display under `point`. Edges count (the pointer can rest on a display's top or right edge), and the first
  /// display listed wins where two touch.
  public static func containing(_ point: CGPoint, in screens: [CockpitScreen]) -> CockpitScreen? {
    guard point.x.isFinite, point.y.isFinite else { return nil }
    return screens.first { $0.frame.minX <= point.x && point.x <= $0.frame.maxX && $0.frame.minY <= point.y && point.y <= $0.frame.maxY }
  }
  /// The display that shows most of `rect`, or nil when it is on none.
  public static func overlapping(_ rect: CGRect, in screens: [CockpitScreen]) -> CockpitScreen? {
    guard !rect.isNull, !rect.isInfinite else { return nil }
    let probe = rect.isEmpty ? CGRect(origin: rect.origin, size: CGSize(width: 1, height: 1)) : rect
    var best: (CockpitScreen, CGFloat)?
    for screen in screens {
      let shared = screen.frame.intersection(probe)
      guard !shared.isNull, !shared.isEmpty else { continue }
      let area = shared.width * shared.height
      if area > (best?.1 ?? 0) { best = (screen, area) }
    }
    return best?.0
  }
  /// Where a detached open goes: the display the user clicked on (`point`), else the menu bar icon's display, else the first.
  public static func openScreen(point: CGPoint?, anchor: CGRect?, screens: [CockpitScreen]) -> CockpitScreen? {
    if let point, let screen = containing(point, in: screens) { return screen }
    if let anchor, let screen = overlapping(anchor, in: screens) { return screen }
    return screens.first
  }
  /// G3-128 (owner, build 15; supersedes D204's "display pressed on"): where an attached cockpit, its launch rack and a
  /// put back go: always the display of the menu bar status item (the screen of the status item button's window, which
  /// `anchor` is measured in), whatever opened it. The widget's ignition on another display, a stale click point or the
  /// display a detached cockpit was dragged to never moves home. Without a visible icon (G3-46/D378: hidden or squeezed
  /// off by a full menu bar) it is the display at the global origin, which carries the menu bar, else the first.
  /// Reference: CodexBar and Pulse anchor their status item's panel to the status item button, so on several displays
  /// it always drops from the menu bar that holds the item.
  public static func attachedScreen(anchor: CGRect?, screens: [CockpitScreen]) -> CockpitScreen? {
    if let anchor, let screen = overlapping(anchor, in: screens) { return screen }
    return screens.first { $0.frame.origin == .zero } ?? screens.first
  }
  /// `rect` moved just enough to lie inside `usable` (its left and bottom edges win when it is larger).
  /// `bottomOverhang` lets the bottom edge go that far below `usable` (the top edge rule is unchanged).
  public static func clamp(_ rect: CGRect, into usable: CGRect, bottomOverhang: CGFloat = 0) -> CGRect {
    let floor = usable.minY - max(0, bottomOverhang)
    return CGRect(x: max(usable.minX, min(rect.minX, usable.maxX - rect.width)),
           y: max(floor, min(rect.minY, usable.maxY - rect.height)),
           width: rect.width, height: rect.height)
  }
  /// A remembered window origin replayed: kept (clamped into its display's visible frame) only while a window of
  /// `size` there still overlaps some display's visible frame; nil when that display is gone or has moved away.
  public static func replayFrame(origin: CGPoint, size: CGSize, screens: [CockpitScreen], bottomOverhang: CGFloat = 0) -> CGRect? {
    guard origin.x.isFinite, origin.y.isFinite, size.width > 0, size.height > 0 else { return nil }
    let rect = CGRect(origin: origin, size: size)
    let visible = screens.filter { !$0.visibleFrame.intersection(rect).isEmpty }
    guard let screen = overlapping(rect, in: visible) ?? visible.first else { return nil }
    return clamp(rect, into: screen.visibleFrame, bottomOverhang: bottomOverhang)
  }
  /// A drag of a window that started at `start`: it moves with the pointer and stays inside the visible frame of the
  /// display under the pointer, so it can be taken to any display. `inset` keeps a margin from that frame's edges.
  /// `bottomOverhang` (G3-159): the transparent strip under the visible body (the base bells' flame reserve) may hang
  /// below the display's bottom edge, so the body itself, not the window, reaches it.
  public static func dragFrame(start: CGRect, from: CGPoint, to pointer: CGPoint, screens: [CockpitScreen],
                               fallback: CGRect?, inset: CGFloat = 0, bottomOverhang: CGFloat = 0) -> CGRect {
    let moved = start.offsetBy(dx: pointer.x - from.x, dy: pointer.y - from.y)
    guard let usable = containing(pointer, in: screens)?.visibleFrame ?? overlapping(moved, in: screens)?.visibleFrame ?? fallback
    else { return moved }
    let inner = usable.insetBy(dx: inset, dy: inset)
    return clamp(moved, into: inner.isEmpty ? usable : inner, bottomOverhang: bottomOverhang)
  }
}
