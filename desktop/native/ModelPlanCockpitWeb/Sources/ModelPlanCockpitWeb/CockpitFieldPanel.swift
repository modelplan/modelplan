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
/// Low Power Mode (spike 11-08, D63): the page cannot read it, so the payload carries `lowPower` and every change while
/// open is sent to the page's `power`, which keeps the scene on demand with quiet motion.
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
  private let lowPower: @MainActor () -> Bool
  private let notifications: NotificationCenter
  private var powerObserver: NSObjectProtocol?
  private var sentLowPower: Bool?
  private var pageLoaded = false
  /// Test seam: where the panel's scripts go; the page's web view when nil.
  var scriptSink: ((String) -> Void)?
  public var onClosed: (() -> Void)?
  public private(set) var isOpen = false
  public init(
    bundle: VerifiedCockpitBundle, idleSeconds: TimeInterval = CockpitFieldPanel.defaultIdleSeconds,
    lowPower: @escaping @MainActor () -> Bool = { ProcessInfo.processInfo.isLowPowerModeEnabled },
    notifications: NotificationCenter = .default
  ) {
    self.bundle = bundle; self.idleSeconds = idleSeconds; self.lowPower = lowPower; self.notifications = notifications
  }
  /// The current Low Power Mode state, for the payload `open` takes.
  public var isLowPower: Bool { lowPower() }

  /// `payload` is the JSON the page's `show` takes: public model data and presentation only.
  public func open(payload: String, near anchor: NSRect?) {
    guard !isOpen else { window?.makeKeyAndOrderFront(nil); return }
    isOpen = true; self.payload = payload
    let config = WKWebViewConfiguration()
    config.websiteDataStore = .nonPersistent()
    config.setURLSchemeHandler(BundleScheme(bundle), forURLScheme: "modelplan-cockpit")
    let proxy = FieldMessageProxy(); proxy.owner = self; self.proxy = proxy
    config.userContentController.add(proxy, name: "field")
    let size = NSSize(width: 900, height: 640)
    let screen = anchor.flatMap { rect in NSScreen.screens.first { $0.frame.intersects(rect) } } ?? NSScreen.main
    let visible = screen?.visibleFrame ?? NSRect(origin: .zero, size: size)
    let origin = NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2)
    let panel = FieldWindow(contentRect: NSRect(origin: origin, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
    panel.isReleasedWhenClosed = false; panel.level = Self.level; panel.hasShadow = true
    panel.backgroundColor = .black; panel.appearance = NSAppearance(named: .darkAqua); panel.delegate = self
    let view = WKWebView(frame: NSRect(origin: .zero, size: size), configuration: config)
    view.autoresizingMask = [.width, .height]; view.allowsBackForwardNavigationGestures = false
    panel.contentView = view
    window = panel; webView = view
    view.load(URLRequest(url: URL(string: "modelplan-cockpit://bundle/field.html")!))
    panel.makeKeyAndOrderFront(nil)
    renewIdle()
    sentLowPower = lowPower(); pageLoaded = false  // the state the payload carries
    powerObserver = notifications.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) {
      [weak self] _ in MainActor.assumeIsolated { self?.powerChanged() }
    }
  }
  public func close() {
    guard isOpen else { return }
    isOpen = false; payload = nil
    idle?.invalidate(); idle = nil
    if let powerObserver { notifications.removeObserver(powerObserver) }
    powerObserver = nil; sentLowPower = nil; pageLoaded = false
    webView?.evaluateJavaScript("window.modelPlanField?.dispose()", completionHandler: nil)
    webView?.configuration.userContentController.removeScriptMessageHandler(forName: "field")
    webView?.stopLoading(); webView?.removeFromSuperview(); webView = nil
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
    case "loaded": pageLoaded = true; deliver()
    case "activity": renewIdle()
    case "close", "failed": close()
    default: break
    }
  }
  /// Sends the page a Low Power Mode change; the payload already carried the state at open. A change before the page
  /// has loaded waits for `deliver`, which catches up after `show`.
  func powerChanged() {
    guard isOpen, pageLoaded else { return }
    let now = lowPower()
    guard now != sentLowPower else { return }
    sentLowPower = now
    run("window.modelPlanField?.power(\(now ? "true" : "false"))")
  }
  private func run(_ script: String) {
    if let scriptSink { scriptSink(script) } else { webView?.evaluateJavaScript(script, completionHandler: nil) }
  }
  private func deliver() {
    guard let payload, let encoded = try? JSONEncoder().encode(payload),
          let literal = String(data: encoded, encoding: .utf8) else { close(); return }
    run("window.modelPlanField?.show(\(literal))")
    powerChanged()
  }
}
