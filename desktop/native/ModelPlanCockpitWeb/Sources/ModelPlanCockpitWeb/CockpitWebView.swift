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
  override func menu(for event: NSEvent) -> NSMenu? { nil }
  override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
    if menu !== ownMenu { menu.removeAllItems() }
  }
  override func rightMouseDown(with event: NSEvent) { showContextMenu(event) }
  override func mouseDown(with event: NSEvent) {
    if event.modifierFlags.contains(.control) { showContextMenu(event) } else { super.mouseDown(with: event) }
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
