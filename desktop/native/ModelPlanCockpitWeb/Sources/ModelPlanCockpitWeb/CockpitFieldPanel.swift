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
/// Build 14c (G3-80): it opens on the display the user clicked on, moves by the strip above its card to any display,
/// and refits its size rule to the display it is on whenever it changes display or the displays change.
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
  /// G3-80: the drag strip just above the card (bare desktop in the page, so it takes no control's input).
  private var dragRegion: CockpitTitleDrag?
  private var dragStart: (point: CGPoint, frame: NSRect, moved: Bool)?
  private var screenObserver: NSObjectProtocol?
  /// The displays placement and drags use; tests replace it with a fixed arrangement.
  public var screens: @MainActor () -> [CockpitScreen] = { CockpitScreenSelection.system() }
  /// The open panel's window frame (nil when closed).
  public var windowFrame: NSRect? { window?.frame }
  /// The drag strip, for tests; nil until the page has laid out its card.
  var dragRegionFrame: NSRect? { dragRegion?.isHidden == false ? dragRegion?.frame : nil }
  /// Where the card's blur sits in the panel's content view, for tests.
  var cardBlurFrame: NSRect? { cardBlur?.isHidden == false ? cardBlur?.frame : nil }
  public var onClosed: (() -> Void)?
  /// Test seams (CKP-SHELL-19 field budget): every page event's type, the page's web view and the panel.
  var onPageEvent: ((String) -> Void)?
  var verificationWebView: WKWebView? { webView }
  var verificationWindow: NSWindow? { window }
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
  /// G3-80: the panel's window frame: the same size rule on `visible`, centred on `centre` (nil: the display's centre)
  /// as far as the 16 pt margins allow, so the field keeps its place when it is refitted on the display it was moved to.
  /// The origin is on whole points: the window server rounds a borderless panel's fractional origin outward, which
  /// made a 900 pt high field 901 pt (Mac compile of b4b7180b, a 1415 pt visible frame centres at y + 257.5).
  nonisolated public static func frame(in visible: NSRect, centredAt centre: CGPoint?) -> NSRect {
    let fitted = frame(in: visible)
    var placed = fitted
    if let centre, centre.x.isFinite, centre.y.isFinite {
      placed.origin = CGPoint(x: centre.x - fitted.width / 2, y: centre.y - fitted.height / 2)
    }
    let inner = visible.insetBy(dx: 16, dy: 16)
    return wholePoints(CockpitScreenSelection.clamp(placed, into: inner), inside: inner)
  }
  /// `rect` with its origin moved down/left onto whole points, or up/right when that would leave `inner`.
  nonisolated static func wholePoints(_ rect: NSRect, inside inner: NSRect) -> NSRect {
    var x = rect.minX.rounded(.down), y = rect.minY.rounded(.down)
    if x < inner.minX { x = inner.minX.rounded(.up) }
    if y < inner.minY { y = inner.minY.rounded(.up) }
    return NSRect(x: x, y: y, width: rect.width, height: rect.height)
  }
  /// G3-80: the drag strip in the content view: the bare band above the card, as wide as the card, at most 20 pt
  /// high. The × sits right of the card, so the strip never covers it. Empty when there is no room.
  nonisolated public static func dragStripFrame(card: NSRect, in bounds: NSRect) -> NSRect {
    let height = min(20, bounds.maxY - card.maxY)
    guard !card.isEmpty, height >= 8 else { return .zero }
    return NSRect(x: card.minX, y: card.maxY, width: card.width, height: height)
  }
  /// The page's card rect (CSS px from the top left, which are points at page zoom 1) in a bottom-left content view.
  nonisolated public static func cardFrame(x: Double, y: Double, width: Double, height: Double, in bounds: NSRect) -> NSRect {
    NSRect(x: x, y: bounds.height - y - height, width: width, height: height).intersection(bounds)
  }
  /// macrev2-845-2: the point that picks the field's display. A pointer open happens on the cockpit, so the pointer
  /// counts only while it is over the cockpit (one that spans two displays); a keyboard open (Enter or Space on the
  /// enlarge key) with the pointer resting elsewhere uses the cockpit's own display.
  nonisolated public static func openPoint(pointer: CGPoint?, cockpit: NSRect?) -> CGPoint? {
    guard let pointer, let cockpit, cockpit.contains(pointer) else { return nil }
    return pointer
  }
  /// G3-80: the normal entry from the cockpit: on the cockpit's display (the pointer's while it is over the cockpit),
  /// else on the display that shows most of `fallback` (the menu bar icon).
  public func open(payload: String, cockpit: NSRect?, pointer: CGPoint?, fallback: NSRect?) {
    open(payload: payload, near: cockpit ?? fallback, at: Self.openPoint(pointer: pointer, cockpit: cockpit))
  }
  /// `payload` is the JSON the page's `show` takes: public model data and presentation only.
  /// `point` is where the user clicked (the cockpit is on that display); without it the field opens on the display
  /// that shows most of `anchor`.
  public func open(payload: String, near anchor: NSRect?, at point: CGPoint? = nil) {
    guard !isOpen else { window?.makeKeyAndOrderFront(nil); return }
    isOpen = true; self.payload = payload
    let config = WKWebViewConfiguration()
    config.websiteDataStore = .nonPersistent()
    config.setURLSchemeHandler(BundleScheme(bundle), forURLScheme: "modelplan-cockpit")
    let proxy = FieldMessageProxy(); proxy.owner = self; self.proxy = proxy
    config.userContentController.add(proxy, name: "field")
    let screen = CockpitScreenSelection.openScreen(point: point, anchor: anchor, screens: screens())
    let frame = Self.frame(in: screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1024, height: 768), centredAt: nil)
    let panel = FieldWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
    // Task 91 round 5: a transparent composition on the desktop; the page draws a frosted card and the feathered scene.
    panel.isReleasedWhenClosed = false; panel.level = Self.level; panel.hasShadow = false
    panel.isOpaque = false; panel.backgroundColor = .clear
    panel.appearance = NSAppearance(named: .darkAqua); panel.delegate = self
    let view = CockpitWebView(frame: NSRect(origin: .zero, size: frame.size), configuration: config)
    view.autoresizingMask = [.width, .height]; view.allowsBackForwardNavigationGestures = false
    // The panel is clear, so the web view paints no backing of its own either (as the cockpit shell does); otherwise the page's
    // transparent body still sits on an opaque rectangle and the card's behind-window blur is covered.
    view.setValue(false, forKey: "drawsBackground")
    view.underPageBackgroundColor = .clear
    let blur = NSVisualEffectView(frame: .zero)
    blur.material = .hudWindow; blur.blendingMode = .behindWindow; blur.state = .active; blur.isHidden = true
    blur.wantsLayer = true; blur.layer?.masksToBounds = true
    let root = NSView(frame: NSRect(origin: .zero, size: frame.size))
    root.autoresizingMask = [.width, .height]
    let drag = CockpitTitleDrag(frame: .zero); drag.isHidden = true
    drag.event = { [weak self] phase, point in self?.drag(phase, point: point) }
    root.addSubview(blur); root.addSubview(view); root.addSubview(drag)
    panel.contentView = root; cardBlur = blur; dragRegion = drag
    window = panel; webView = view
    view.load(URLRequest(url: URL(string: "modelplan-cockpit://bundle/field.html")!))
    panel.makeKeyAndOrderFront(nil)
    screenObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
    ) { [weak self] _ in Task { @MainActor in self?.refit() } }
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
    dragRegion?.event = nil; dragRegion?.removeFromSuperview(); dragRegion = nil; dragStart = nil
    if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }; screenObserver = nil
    window?.delegate = nil; window?.orderOut(nil); window = nil; proxy = nil
    onClosed?()
  }
  public func windowDidResignKey(_ notification: Notification) { close() }
  /// G3-80: moved (or pushed) onto another display: the size rule follows that display.
  public func windowDidChangeScreen(_ notification: Notification) { refit() }
  /// The size rule on the display that shows most of the field (the first display when it is on none), keeping its
  /// centre where it is. Not while a drag is moving it; the drag's end refits.
  func refit() {
    guard isOpen, dragStart == nil, let window else { return }
    let displays = screens()
    guard let screen = CockpitScreenSelection.overlapping(window.frame, in: displays) ?? displays.first else { return }
    let target = Self.frame(in: screen.visibleFrame, centredAt: CGPoint(x: window.frame.midX, y: window.frame.midY))
    if target != window.frame { window.setFrame(target, display: true) }
  }
  /// The strip's drag: the field follows the pointer onto any display, 16 pt inside the display under the pointer.
  /// A press that never moves is a click on bare desktop, which closes the field as the page does.
  func drag(_ phase: CockpitTitleDrag.Phase, point: CGPoint) {
    guard isOpen, let window else { return }
    switch phase {
    case .began:
      dragStart = (point, window.frame, false); renewIdle()
    case .moved:
      guard var start = dragStart else { return }
      guard start.moved || hypot(point.x - start.point.x, point.y - start.point.y) >= 3 else { return }
      start.moved = true; dragStart = start
      // Pointer locations are fractional on Retina displays; whole points keep the panel's size exact.
      let moved = CockpitScreenSelection.dragFrame(start: start.frame, from: start.point, to: point, screens: screens(), fallback: nil, inset: 16)
      window.setFrame(NSRect(x: moved.minX.rounded(), y: moved.minY.rounded(), width: moved.width, height: moved.height), display: true)
    case .ended:
      guard let start = dragStart else { return }
      dragStart = nil
      guard start.moved else { close(); return }
      // The strip took first responder on its press; the page gets keys (Esc closes) again.
      if let webView { window.makeFirstResponder(webView) }
      refit(); renewIdle()
    case .cancelled:
      guard let start = dragStart else { return }
      dragStart = nil; window.setFrame(start.frame, display: true)
      if let webView { window.makeFirstResponder(webView) }
    }
  }

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
    onPageEvent?(type)
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
    let strip = Self.dragStripFrame(card: rect, in: bounds)
    dragRegion?.frame = strip; dragRegion?.isHidden = strip.isEmpty
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
