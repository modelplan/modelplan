// SPDX-License-Identifier: MIT
import AppKit
import WebKit

/// G3-55: the app owns every pixel of the cockpit, so WebKit's default context menu (Reload, Back,
/// Inspect Element and the rest) is never shown. Every cockpit-hosted WKWebView is this class.
@MainActor
final class CockpitWebView: WKWebView {
  override func menu(for event: NSEvent) -> NSMenu? { nil }
  override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) { menu.removeAllItems() }
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
