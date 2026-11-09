// SPDX-License-Identifier: MIT
import AppKit
import WebKit

/// G3-55: the app owns every pixel of the cockpit, so WebKit's default context menu (Reload, Back,
/// Inspect Element and the rest) is never shown. Every cockpit-hosted WKWebView is this class.
/// D88: a right-click shows the app's own menu when the host supplies one (the cockpit's detach / put back);
/// without one there is no menu at all.
@MainActor
final class CockpitWebView: WKWebView {
  var contextMenuProvider: (() -> NSMenu?)?
  override func menu(for event: NSEvent) -> NSMenu? { contextMenuProvider?() }
  override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
    // Whatever WebKit put in, only the app's own items remain.
    menu.removeAllItems()
    guard let own = contextMenuProvider?() else { return }
    for item in own.items { own.removeItem(item); menu.addItem(item) }
  }
  override func rightMouseDown(with event: NSEvent) {
    guard let menu = contextMenuProvider?() else { super.rightMouseDown(with: event); return }
    NSMenu.popUpContextMenu(menu, with: event, for: self)
  }
  override func mouseDown(with event: NSEvent) {
    // Control-click is a right-click on macOS; it gets the same app menu.
    if event.modifierFlags.contains(.control), let menu = contextMenuProvider?() {
      NSMenu.popUpContextMenu(menu, with: event, for: self); return
    }
    super.mouseDown(with: event)
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
