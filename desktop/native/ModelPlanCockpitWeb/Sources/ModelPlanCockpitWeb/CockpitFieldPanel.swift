// SPDX-License-Identifier: MIT
import AppKit
import WebKit

@MainActor private final class FieldWindow: NSPanel {
  override var canBecomeKey: Bool { true }
  /// G3-80: the panel's frame is already placed by the field's own rule on the display chosen for it. AppKit's constraint
  /// judged it against another screen and pulled a field placed on another display down to y = 0 (hosted CI run
  /// 43021491370), so the panel keeps the frame it was given.
  override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}
/// WP-22 (D298): the plain dim over the whole display under the field. It never takes key, so a press on it leaves the
/// field key until the field closes.
@MainActor final class FieldDimWindow: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
  override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}
/// The dim's surface: any press on it is a press outside the field's rectangle.
@MainActor final class FieldDimView: NSView {
  var pressed: (() -> Void)?
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
  override func mouseDown(with event: NSEvent) { pressed?() }
  override func rightMouseDown(with event: NSEvent) { pressed?() }
  override func otherMouseDown(with event: NSEvent) { pressed?() }
}
@MainActor private final class FieldMessageProxy: NSObject, WKScriptMessageHandler {
  weak var owner: CockpitFieldPanel?
  func userContentController(
    _ controller: WKUserContentController, didReceive message: WKScriptMessage
  ) { owner?.receive(message.body) }
}

/// The enlarged launch field (WP-22, owner D298; was D63/task 91): one transparent, borderless panel rectangle centred
/// on the cockpit's display, sized 88% of that display's visible frame within 820×560–1600×1000 pt, over a plain dim
/// (#0B0F1A at 0.52, no blur) that covers the whole display. The page inside hosts the reserved launch-field component
/// (window mode), which draws the window, its menu and keys and the 3D field; its own dim is off, since this one lies
/// under the rectangle too.
/// Nothing exists until it opens, and closing destroys the page, which releases its WebGL context and resets a tried
/// effort. It closes on a press on the dim (outside the rectangle; the whole rectangle counts as inside), on the page's
/// × and Esc (the component's onClose), when the panel loses key, and after `idleSeconds` without interaction.
/// Low Power Mode (spike 11-08, D63): the page cannot read it, so the payload carries `lowPower` and every change while
/// open is sent to the page's `power`. Increase Contrast and Reduce Motion follow macOS live through the page's `options`.
@MainActor public final class CockpitFieldPanel: NSObject, NSWindowDelegate {
  /// D49: the field opens from the cockpit, which sits above `.floating`, so it opens above the cockpit.
  public static let level = CockpitWindowController.aboveCockpitLevel
  nonisolated public static let defaultIdleSeconds: TimeInterval = 180
  /// D298: the dim outside the field, #0B0F1A (sRGB 11, 15, 26) at alpha 0.52, no blur.
  public static let dimColor = NSColor(srgbRed: 11 / 255, green: 15 / 255, blue: 26 / 255, alpha: 0.52)
  /// Why the field closed: the component's "esc" and "key", "outside" for a press on the dim, then the panel's own.
  public enum CloseReason: String, Sendable { case esc, key, outside, resign, idle, failed, host }
  private let bundle: VerifiedCockpitBundle
  private let idleSeconds: TimeInterval
  private var window: NSPanel?
  private var dim: FieldDimWindow?
  private var webView: WKWebView?
  private var proxy: FieldMessageProxy?
  private var payload: String?
  private var idle: Timer?
  private let lowPower: @MainActor () -> Bool
  private let notifications: NotificationCenter
  private let workspaceNotifications: NotificationCenter
  private var powerObserver: NSObjectProtocol?
  private var accessibilityObserver: NSObjectProtocol?
  private var sentLowPower: Bool?
  private var sentOptions: String?
  private var pageLoaded = false
  /// Test seam: where the panel's scripts go; the page's web view when nil.
  var scriptSink: ((String) -> Void)?
  private var screenObserver: NSObjectProtocol?
  /// The displays placement uses; tests replace it with a fixed arrangement.
  public var screens: @MainActor () -> [CockpitScreen] = { CockpitScreenSelection.system() }
  /// macOS Increase Contrast and Reduce Motion, read when the page loads and on every accessibility change.
  public var accessibility: @MainActor () -> (contrast: Bool, reduceMotion: Bool) = {
    (NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast, NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
  }
  /// Opens a website address the page asked for, once `siteURL` allowed it (the default browser).
  public var openURL: @MainActor (URL) -> Void = { NSWorkspace.shared.open($0) }
  /// The open panel's window frame (nil when closed).
  public var windowFrame: NSRect? { window?.frame }
  public var onClosed: (@MainActor () -> Void)?
  /// WP-22 (macrevb-1062-3): a rocket chosen in the field (its public model id) or the choice cleared (nil). Only the id
  /// crosses; a tried effort stays in the field.
  public var onSelect: (@MainActor (String?) -> Void)?
  /// Test seams (CKP-SHELL-19 field budget, WP-22): every page event's type, the page's web view, the panel, the dim
  /// and the last close's reason.
  var onPageEvent: ((String) -> Void)?
  var verificationWebView: WKWebView? { webView }
  var verificationWindow: NSWindow? { window }
  var verificationDimWindow: NSWindow? { dim }
  private(set) var lastCloseReason: CloseReason?
  public private(set) var isOpen = false
  public init(
    bundle: VerifiedCockpitBundle, idleSeconds: TimeInterval = CockpitFieldPanel.defaultIdleSeconds,
    lowPower: @escaping @MainActor () -> Bool = { ProcessInfo.processInfo.isLowPowerModeEnabled },
    notifications: NotificationCenter = .default,
    workspaceNotifications: NotificationCenter = NSWorkspace.shared.notificationCenter
  ) {
    self.bundle = bundle; self.idleSeconds = idleSeconds; self.lowPower = lowPower; self.notifications = notifications
    self.workspaceNotifications = workspaceNotifications
  }
  /// The current Low Power Mode state, for the payload `open` takes.
  public var isLowPower: Bool { lowPower() }

  /// D298 container: 88% of the display's visible frame (the screen minus the menu bar and the Dock), clamped to
  /// 820–1600 pt wide and 560–1000 pt high and never larger than the visible frame, centred. The origin is on whole
  /// points: the window server rounds a borderless panel's fractional origin outward, which grew a field by 1 pt
  /// (Mac compile of b4b7180b).
  nonisolated public static func frame(in visible: NSRect) -> NSRect {
    let width = min(visible.width, min(1600, max(820, (visible.width * 0.88).rounded())))
    let height = min(visible.height, min(1000, max(560, (visible.height * 0.88).rounded())))
    let x = max(visible.minX, (visible.minX + (visible.width - width) / 2).rounded(.down))
    let y = max(visible.minY, (visible.minY + (visible.height - height) / 2).rounded(.down))
    return NSRect(x: x, y: y, width: width, height: height)
  }
  /// WP-22: the only website addresses the field may open (component 1.1.0 onOpenSite). Anything else is refused: an
  /// unknown target (compare is not offered yet), extra parameters, or a model slug outside ^[a-z0-9.-]+$.
  nonisolated public static func siteURL(target: Any?, params: Any?) -> URL? {
    guard let target = target as? String else { return nil }
    let fields: [String: Any]
    if params == nil || params is NSNull { fields = [:] } else if let given = params as? [String: Any] { fields = given } else { return nil }
    switch (target, fields.count) {
    case ("fleet", 0): return URL(string: "https://modelplan.ai/")
    case ("methodology", 0): return URL(string: "https://modelplan.ai/methodology")
    case ("effort", 0): return URL(string: "https://modelplan.ai/effort")
    case ("effort", 1):
      guard let slug = fields["m"] as? String, (1...128).contains(slug.utf8.count),
        slug.utf8.allSatisfy({ (48...57).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 46 })
      else { return nil }
      return URL(string: "https://modelplan.ai/models/" + slug)
    default: return nil
    }
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
    isOpen = true; self.payload = payload; lastCloseReason = nil
    let config = WKWebViewConfiguration()
    config.websiteDataStore = .nonPersistent()
    config.setURLSchemeHandler(BundleScheme(bundle), forURLScheme: "modelplan-cockpit")
    let proxy = FieldMessageProxy(); proxy.owner = self; self.proxy = proxy
    config.userContentController.add(proxy, name: "field")
    let screen = CockpitScreenSelection.openScreen(point: point, anchor: anchor, screens: screens())
    let screenFrame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1024, height: 768)
    let frame = Self.frame(in: screen?.visibleFrame ?? screenFrame)
    // The dim: one borderless, non-activating window under the panel over the whole display (menu bar and Dock too).
    let shade = FieldDimWindow(contentRect: screenFrame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    shade.isReleasedWhenClosed = false; shade.level = Self.level; shade.hasShadow = false
    shade.isOpaque = false; shade.backgroundColor = Self.dimColor
    // A press on the dim closes the field, not the cockpit under it (CockpitWindowController.isOwnedChild).
    shade.identifier = CockpitWindowController.fieldWindowIdentifier
    let surface = FieldDimView(frame: NSRect(origin: .zero, size: screenFrame.size))
    surface.autoresizingMask = [.width, .height]
    surface.pressed = { [weak self] in self?.close(.outside) }
    shade.contentView = surface
    let panel = FieldWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
    panel.isReleasedWhenClosed = false; panel.level = Self.level; panel.hasShadow = false
    panel.identifier = CockpitWindowController.fieldWindowIdentifier // a press on it never closes the cockpit under it
    panel.isOpaque = false; panel.backgroundColor = .clear
    panel.appearance = NSAppearance(named: .darkAqua); panel.delegate = self
    let view = CockpitWebView(frame: NSRect(origin: .zero, size: frame.size), configuration: config)
    view.autoresizingMask = [.width, .height]; view.allowsBackForwardNavigationGestures = false
    // The panel is clear, so the web view paints no backing of its own either (as the cockpit shell does): the dim
    // below shows through the rectangle wherever the component draws nothing.
    view.setValue(false, forKey: "drawsBackground")
    view.underPageBackgroundColor = .clear
    panel.contentView = view
    window = panel; dim = shade; webView = view
    view.load(URLRequest(url: URL(string: "modelplan-cockpit://bundle/field.html")!))
    shade.orderFront(nil)
    panel.makeKeyAndOrderFront(nil)
    // Esc belongs to the component (clear search, leave the fly-in, then onClose("esc")), so the page has the keys.
    panel.makeFirstResponder(view)
    screenObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
    ) { [weak self] _ in Task { @MainActor in self?.refit() } }
    renewIdle()
    // Nothing sent yet: after `show` the page always gets the state of that moment, so a field opened in Low Power
    // Mode is quiet even if the payload said otherwise (or was built before the change).
    sentLowPower = nil; sentOptions = nil; pageLoaded = false
    powerObserver = notifications.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) {
      [weak self] _ in MainActor.assumeIsolated { self?.powerChanged() }
    }
    accessibilityObserver = workspaceNotifications.addObserver(
      forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
    ) { [weak self] _ in MainActor.assumeIsolated { self?.optionsChanged() } }
  }
  public func close() { close(.host) }
  func close(_ reason: CloseReason) {
    guard isOpen else { return }
    isOpen = false; payload = nil; lastCloseReason = reason
    idle?.invalidate(); idle = nil
    if let powerObserver { notifications.removeObserver(powerObserver) }
    if let accessibilityObserver { workspaceNotifications.removeObserver(accessibilityObserver) }
    powerObserver = nil; accessibilityObserver = nil; sentLowPower = nil; sentOptions = nil; pageLoaded = false
    webView?.evaluateJavaScript("window.modelPlanField?.dispose()", completionHandler: nil)
    webView?.configuration.userContentController.removeScriptMessageHandler(forName: "field")
    webView?.stopLoading(); webView?.removeFromSuperview(); webView = nil
    if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }; screenObserver = nil
    window?.delegate = nil; window?.orderOut(nil); window = nil; proxy = nil
    (dim?.contentView as? FieldDimView)?.pressed = nil; dim?.orderOut(nil); dim = nil
    onClosed?()
  }
  public func windowDidResignKey(_ notification: Notification) { close(.resign) }
  /// G3-80: moved onto another display: the size rule follows that display.
  public func windowDidChangeScreen(_ notification: Notification) { refit() }
  /// The size rule, centred on the display that shows most of the field (the first display when it is on none); the
  /// dim covers that display.
  func refit() {
    guard isOpen, let window else { return }
    let displays = screens()
    guard let screen = CockpitScreenSelection.overlapping(window.frame, in: displays) ?? displays.first else { return }
    let target = Self.frame(in: screen.visibleFrame)
    if target != window.frame { window.setFrame(target, display: true) }
    if let dim, dim.frame != screen.frame { dim.setFrame(screen.frame, display: true) }
  }

  private func renewIdle() {
    idle?.invalidate()
    idle = Timer.scheduledTimer(withTimeInterval: idleSeconds, repeats: false) { [weak self] _ in
      Task { @MainActor in self?.close(.idle) }
    }
  }
  /// The page reports only these fixed events; anything else is ignored.
  func receive(_ body: Any) {
    guard isOpen, let raw = body as? String, let data = raw.data(using: .utf8),
          let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let type = message["type"] as? String else { return }
    onPageEvent?(type)
    switch type {
    case "loaded": pageLoaded = true; deliver()
    case "activity": renewIdle()
    case "close": close(message["reason"] as? String == "esc" ? .esc : .key)
    case "failed": close(.failed)
    case "select":
      renewIdle()
      if message["model"] is NSNull { onSelect?(nil) }
      else if let id = message["model"] as? String, CockpitBridgeState.isPublicModelID(id) { onSelect?(id) }
    case "openSite":
      renewIdle()
      if let url = Self.siteURL(target: message["target"], params: message["params"]) { openURL(url) }
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
  /// Sends the page macOS Increase Contrast and Reduce Motion (the component's setOptions), once per change.
  func optionsChanged() {
    guard isOpen, pageLoaded else { return }
    let now = accessibility()
    let options = #"{"contrast":\#(now.contrast),"reduceMotion":\#(now.reduceMotion)}"#
    guard options != sentOptions, let encoded = try? JSONEncoder().encode(options),
          let literal = String(data: encoded, encoding: .utf8) else { return }
    sentOptions = options
    run("window.modelPlanField?.options(\(literal))")
  }
  private func run(_ script: String) {
    if let scriptSink { scriptSink(script) } else { webView?.evaluateJavaScript(script, completionHandler: nil) }
  }
  private func deliver() {
    guard let payload, let encoded = try? JSONEncoder().encode(payload),
          let literal = String(data: encoded, encoding: .utf8) else { close(.failed); return }
    run("window.modelPlanField?.show(\(literal))")
    powerChanged()
    optionsChanged()
  }
}
