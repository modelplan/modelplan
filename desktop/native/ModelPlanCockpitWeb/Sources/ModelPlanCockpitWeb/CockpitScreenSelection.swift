// SPDX-License-Identifier: MIT
import AppKit

/// One display as the cockpit and the launch field see it, in global screen coordinates (bottom-left origin).
/// A plain value so placement can be tested with any arrangement of displays.
public struct CockpitScreen: Equatable, Sendable {
  public let frame: CGRect
  public let visibleFrame: CGRect
  public init(frame: CGRect, visibleFrame: CGRect) { self.frame = frame; self.visibleFrame = visibleFrame }
}

/// Build 14c (G3-76, G3-77): which display the cockpit and the launch field use. The screen the user clicked on
/// wins over the menu bar icon's screen, a drag follows the pointer to any display, and a remembered position is
/// replayed only while it is still on some display.
public enum CockpitScreenSelection {
  /// The system's displays, the main one (the key window's) first so it is the fallback.
  @MainActor public static func system() -> [CockpitScreen] {
    let main = NSScreen.main
    let ordered = (main.map { [$0] } ?? []) + NSScreen.screens.filter { $0 != main }
    return ordered.map { CockpitScreen(frame: $0.frame, visibleFrame: $0.visibleFrame) }
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
  /// Where an open goes: the display the user clicked on (`point`), else the menu bar icon's display, else the first.
  public static func openScreen(point: CGPoint?, anchor: CGRect?, screens: [CockpitScreen]) -> CockpitScreen? {
    if let point, let screen = containing(point, in: screens) { return screen }
    if let anchor, let screen = overlapping(anchor, in: screens) { return screen }
    return screens.first
  }
  /// `rect` moved just enough to lie inside `usable` (its left and bottom edges win when it is larger).
  public static func clamp(_ rect: CGRect, into usable: CGRect) -> CGRect {
    CGRect(x: max(usable.minX, min(rect.minX, usable.maxX - rect.width)),
           y: max(usable.minY, min(rect.minY, usable.maxY - rect.height)),
           width: rect.width, height: rect.height)
  }
  /// A remembered window origin replayed: kept (clamped into its display's visible frame) only while a window of
  /// `size` there still overlaps some display's visible frame; nil when that display is gone or has moved away.
  public static func replayFrame(origin: CGPoint, size: CGSize, screens: [CockpitScreen]) -> CGRect? {
    guard origin.x.isFinite, origin.y.isFinite, size.width > 0, size.height > 0 else { return nil }
    let rect = CGRect(origin: origin, size: size)
    let visible = screens.filter { !$0.visibleFrame.intersection(rect).isEmpty }
    guard let screen = overlapping(rect, in: visible) ?? visible.first else { return nil }
    return clamp(rect, into: screen.visibleFrame)
  }
  /// A drag of a window that started at `start`: it moves with the pointer and stays inside the visible frame of the
  /// display under the pointer, so it can be taken to any display. `inset` keeps a margin from that frame's edges.
  public static func dragFrame(start: CGRect, from: CGPoint, to pointer: CGPoint, screens: [CockpitScreen],
                               fallback: CGRect?, inset: CGFloat = 0) -> CGRect {
    let moved = start.offsetBy(dx: pointer.x - from.x, dy: pointer.y - from.y)
    guard let usable = containing(pointer, in: screens)?.visibleFrame ?? overlapping(moved, in: screens)?.visibleFrame ?? fallback
    else { return moved }
    let inner = usable.insetBy(dx: inset, dy: inset)
    return clamp(moved, into: inner.isEmpty ? usable : inner)
  }
}
