// SPDX-License-Identifier: MIT
import AppKit
import WebKit

@MainActor private final class FieldWindow: NSPanel {
  override var canBecomeKey: Bool { true }
}
@MainActor private final class FieldMessageProxy: NSObject, WKScriptMessageHandler {
  weak var owner: CockpitFieldPanel?
  func userContentController(
    _ controller: WKUserContentController, didReceive message: WKScriptMessage
  ) { owner?.receive(message.body) }
}

/// The enlarged launch field: its own borderless panel and web view, because the cockpit window is 620 pt
/// wide. Nothing exists until it opens, and closing destroys the page, which releases its WebGL context.
/// Closes on ×, Esc, a click outside (the panel loses key) or `idleSeconds` without interaction.
@MainActor public final class CockpitFieldPanel: NSObject, NSWindowDelegate {
  /// D49: the field opens from the cockpit, which sits above `.floating`, so it opens above the cockpit.
  public static let level = CockpitWindowController.aboveCockpitLevel
  public static let defaultIdleSeconds: TimeInterval = 180
  private let bundle: VerifiedCockpitBundle
  private let idleSeconds: TimeInterval
  private var window: NSPanel?
  private var webView: WKWebView?
  private var proxy: FieldMessageProxy?
  private var payload: String?
  private var idle: Timer?
  /// The frosted card's blur: a transparent web view cannot blur the desktop with CSS, so the panel blurs behind the
  /// window where the page says its card is. Under Reduce Transparency AppKit draws it solid.
  private var cardBlur: NSVisualEffectView?
  /// Where the card's blur sits in the panel's content view, for tests.
  var cardBlurFrame: NSRect? { cardBlur?.isHidden == false ? cardBlur?.frame : nil }
  public var onClosed: (() -> Void)?
  public private(set) var isOpen = false
  public init(bundle: VerifiedCockpitBundle, idleSeconds: TimeInterval = CockpitFieldPanel.defaultIdleSeconds) {
    self.bundle = bundle; self.idleSeconds = idleSeconds
  }

  /// The composition's bounds on a screen's visible frame (prototype floating-frame.js fieldFrame): 90% of the width
  /// within 960–1440 pt and 80% of the height within 600–900 pt, at least 16 pt from every edge, centred.
  nonisolated public static func frame(in visible: NSRect) -> NSRect {
    let width = min(visible.width - 32, min(1440, max(960, (visible.width * 0.9).rounded())))
    let height = min(visible.height - 32, min(900, max(600, (visible.height * 0.8).rounded())))
    return NSRect(x: visible.minX + (visible.width - width) / 2, y: visible.minY + (visible.height - height) / 2, width: width, height: height)
  }
  /// The page's card rect (CSS px from the top left, which are points at page zoom 1) in a bottom-left content view.
  nonisolated public static func cardFrame(x: Double, y: Double, width: Double, height: Double, in bounds: NSRect) -> NSRect {
    NSRect(x: x, y: bounds.height - y - height, width: width, height: height).intersection(bounds)
  }
  /// `payload` is the JSON the page's `show` takes: public model data and presentation only.
  public func open(payload: String, near anchor: NSRect?) {
    guard !isOpen else { window?.makeKeyAndOrderFront(nil); return }
    isOpen = true; self.payload = payload
    let config = WKWebViewConfiguration()
    config.websiteDataStore = .nonPersistent()
    config.setURLSchemeHandler(BundleScheme(bundle), forURLScheme: "modelplan-cockpit")
    let proxy = FieldMessageProxy(); proxy.owner = self; self.proxy = proxy
    config.userContentController.add(proxy, name: "field")
    let screen = anchor.flatMap { rect in NSScreen.screens.first { $0.frame.intersects(rect) } } ?? NSScreen.main
    let frame = Self.frame(in: screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1024, height: 768))
    let panel = FieldWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
    // Task 91 round 5: a transparent composition on the desktop; the page draws a frosted card and the feathered scene.
    panel.isReleasedWhenClosed = false; panel.level = Self.level; panel.hasShadow = false
    panel.isOpaque = false; panel.backgroundColor = .clear
    panel.appearance = NSAppearance(named: .darkAqua); panel.delegate = self
    let view = WKWebView(frame: NSRect(origin: .zero, size: frame.size), configuration: config)
    view.autoresizingMask = [.width, .height]; view.allowsBackForwardNavigationGestures = false
    let blur = NSVisualEffectView(frame: .zero)
    blur.material = .hudWindow; blur.blendingMode = .behindWindow; blur.state = .active; blur.isHidden = true
    blur.wantsLayer = true; blur.layer?.masksToBounds = true
    let root = NSView(frame: NSRect(origin: .zero, size: frame.size))
    root.autoresizingMask = [.width, .height]
    root.addSubview(blur); root.addSubview(view)
    panel.contentView = root; cardBlur = blur
    window = panel; webView = view
    view.load(URLRequest(url: URL(string: "modelplan-cockpit://bundle/field.html")!))
    panel.makeKeyAndOrderFront(nil)
    renewIdle()
  }
  public func close() {
    guard isOpen else { return }
    isOpen = false; payload = nil
    idle?.invalidate(); idle = nil
    webView?.evaluateJavaScript("window.modelPlanField?.dispose()", completionHandler: nil)
    webView?.configuration.userContentController.removeScriptMessageHandler(forName: "field")
    webView?.stopLoading(); webView?.removeFromSuperview(); webView = nil
    cardBlur?.removeFromSuperview(); cardBlur = nil
    window?.delegate = nil; window?.orderOut(nil); window = nil; proxy = nil
    onClosed?()
  }
  public func windowDidResignKey(_ notification: Notification) { close() }

  private func renewIdle() {
    idle?.invalidate()
    idle = Timer.scheduledTimer(withTimeInterval: idleSeconds, repeats: false) { [weak self] _ in
      Task { @MainActor in self?.close() }
    }
  }
  /// The page reports only these fixed events; anything else is ignored.
  func receive(_ body: Any) {
    guard isOpen, let raw = body as? String, let data = raw.data(using: .utf8),
          let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let type = message["type"] as? String else { return }
    switch type {
    case "loaded": deliver()
    case "activity": renewIdle()
    case "card": placeCard(message)
    case "close", "failed": close()
    default: break
    }
  }
  private func placeCard(_ message: [String: Any]) {
    guard let cardBlur, let bounds = cardBlur.superview?.bounds else { return }
    let number = { (key: String) in (message[key] as? NSNumber)?.doubleValue }
    guard let x = number("x"), let y = number("y"), let width = number("width"), let height = number("height"),
          width > 0, height > 0, width <= 4096, height <= 4096 else { return }
    let rect = Self.cardFrame(x: x, y: y, width: width, height: height, in: bounds)
    guard !rect.isEmpty else { cardBlur.isHidden = true; return }
    cardBlur.frame = rect; cardBlur.layer?.cornerRadius = CGFloat(min(24, max(0, number("radius") ?? 12)))
    cardBlur.isHidden = false
  }
  private func deliver() {
    guard let payload, let encoded = try? JSONEncoder().encode(payload),
          let literal = String(data: encoded, encoding: .utf8) else { close(); return }
    webView?.evaluateJavaScript("window.modelPlanField?.show(\(literal))", completionHandler: nil)
  }
}
