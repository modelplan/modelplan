// SPDX-License-Identifier: MIT
import AppKit
import WebKit

/// G3-55: the app owns every pixel of the cockpit, so WebKit's default context menu (Reload, Back,
/// Inspect Element and the rest) is never shown. Every cockpit-hosted WKWebView is this class.
/// The only menu a right-click can show is the one the host supplies through `menuProvider`.
@MainActor
final class CockpitWebView: WKWebView {
  /// Builds the app's own context menu; nil (the default) means a right-click shows nothing.
  var menuProvider: (() -> NSMenu?)?
  /// The menu this view popped up itself; WebKit-made menus are anything else and are emptied.
  private weak var ownMenu: NSMenu?
  /// CKP-SHELL-25: the page's transparent body shows the clear panel behind it. A public `isOpaque` of false tells
  /// AppKit the view paints no backing of its own; the hosts still set `drawsBackground` false, which is what stops
  /// WebKit painting one.
  override var isOpaque: Bool { false }
  /// Owner 11-19 (#1062): an activation click (the first click on a window that is not key) is not delivered where this
  /// says so; it only brings the window forward. Given the point in view coordinates measured from the view's top.
  var declinesActivationClick: (@MainActor (CGPoint) -> Bool)?
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    if let event, let declines = declinesActivationClick {
      let p = convert(event.locationInWindow, from: nil)
      if declines(CGPoint(x: p.x, y: isFlipped ? p.y : bounds.height - p.y)) { return false }
    }
    return super.acceptsFirstMouse(for: event)
  }
  override func menu(for event: NSEvent) -> NSMenu? { nil }
  override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
    if menu !== ownMenu { menu.removeAllItems() }
  }
  /// macrev2-1104-3: asked with the click point (view coordinates from the top) whether the page handles this secondary
  /// click itself (a plugin key's Remove menu). Yes: the click goes to WebKit, whose own menu is still emptied above.
  /// No (or no answer provider): the app's menu shows, as before.
  var pageOwnsContextClick: (@MainActor (CGPoint, @escaping @MainActor (Bool) -> Void) -> Void)?
  /// The button-up of a secondary click whose owner is still being decided; replayed after the button-down.
  private var deciding = false, heldUp: NSEvent?
  override func rightMouseDown(with event: NSEvent) { routeContextClick(event, control: false) }
  override func rightMouseUp(with event: NSEvent) { if deciding { heldUp = event } else { super.rightMouseUp(with: event) } }
  override func mouseDown(with event: NSEvent) {
    if event.modifierFlags.contains(.control) { routeContextClick(event, control: true) } else { super.mouseDown(with: event) }
  }
  override func mouseUp(with event: NSEvent) { if deciding { heldUp = event } else { super.mouseUp(with: event) } }
  private func forwardDown(_ event: NSEvent, control: Bool) {
    if control { super.mouseDown(with: event) } else { super.rightMouseDown(with: event) }
  }
  private func forwardUp(_ event: NSEvent) {
    if event.type == .rightMouseUp { super.rightMouseUp(with: event) } else { super.mouseUp(with: event) }
  }
  private func routeContextClick(_ event: NSEvent, control: Bool) {
    guard let ask = pageOwnsContextClick, !deciding else { showContextMenu(event); return }
    let p = convert(event.locationInWindow, from: nil)
    deciding = true; heldUp = nil
    ask(CGPoint(x: p.x, y: isFlipped ? p.y : bounds.height - p.y)) { [weak self] page in
      guard let self, self.deciding else { return }
      self.deciding = false
      let up = self.heldUp; self.heldUp = nil
      if page {
        self.forwardDown(event, control: control)
        if let up { self.forwardUp(up) }
      } else { self.showContextMenu(event) }
    }
  }
  private func showContextMenu(_ event: NSEvent) {
    guard let menu = menuProvider?() else { return }
    ownMenu = menu
    NSMenu.popUpContextMenu(menu, with: event, for: self)
  }
}

/// G3-55: the cockpit page is loaded exactly once per web view. A reload, back/forward step or a
/// second load of the same URL is cancelled, so the page can never restart under a live bridge.
enum CockpitNavigationPolicy {
  static func allows(
    isMainFrame: Bool, url: URL?, pageURL: URL, type: WKNavigationType, alreadyLoaded: Bool
  ) -> Bool {
    isMainFrame && url == pageURL && !alreadyLoaded && type != .reload && type != .backForward
  }
}
