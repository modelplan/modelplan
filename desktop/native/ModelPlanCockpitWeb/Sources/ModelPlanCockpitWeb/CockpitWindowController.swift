// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanWire
import WebKit
import QuartzCore

public enum CockpitWindowFailure: String { case pageAPIUnavailable, messageRejected, javascriptFailed, navigationFailed, provisionalNavigationFailed, contentTerminated, clearDeadline, localEncoding }

// WebKit's module CORS fetch requires NSHTTPURLResponse header fields, even
// for a custom scheme. Only public, hash-pinned static files use this response;
// private DTOs never have a scheme route. No credentialed CORS is enabled.
enum CockpitSchemeResponse {
  /// The production scheme and no-window checks share this verified asset path.
  static func load(request: URLRequest, bundle: VerifiedCockpitBundle) throws
    -> (response: HTTPURLResponse, data: Data)
  {
    guard let url = request.url, url.scheme == "modelplan-cockpit", url.host == "bundle",
      url.user == nil, url.password == nil, url.port == nil, request.httpMethod == "GET"
    else { throw CockpitBundleError.unsafePath }
    let data = try bundle.resource(path: String(url.path.dropFirst()))
    let mime = [
      "html": "text/html", "js": "text/javascript", "css": "text/css",
      "json": "application/json", "png": "image/png", "svg": "image/svg+xml",
      "woff2": "font/woff2", "woff": "font/woff", "txt": "text/plain", "md": "text/plain",
    ][url.pathExtension] ?? "application/octet-stream"
    return (make(url: url, mime: mime, bytes: data.count), data)
  }
  static func make(url: URL, mime: String, bytes: Int) -> HTTPURLResponse {
    HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: [
      "Content-Type": mime + (mime.hasPrefix("text/") ? "; charset=utf-8" : ""),
      "Content-Length": String(bytes), "Access-Control-Allow-Origin": "*",
      "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff",
    ])!
  }
}

private final class BundleScheme: NSObject, WKURLSchemeHandler {
  let bundle: VerifiedCockpitBundle
  let observed: ((String) -> Void)?
  init(_ bundle: VerifiedCockpitBundle, observed: ((String) -> Void)? = nil) { self.bundle = bundle; self.observed = observed }
  func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
    do {
      let result = try CockpitSchemeResponse.load(request: task.request, bundle: bundle)
      if let url = task.request.url { observed?(String(url.path.dropFirst())) }
      task.didReceive(result.response)
      task.didReceive(result.data)
      task.didFinish()
    } catch { task.didFailWithError(CockpitBundleError.integrity) }
  }
  func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {}
}

@MainActor private final class MessageProxy: NSObject, WKScriptMessageHandler {
  weak var owner: CockpitWindowController?
  func userContentController(
    _ controller: WKUserContentController, didReceive message: WKScriptMessage
  ) { owner?.receive(message) }
}

/// No prewarm: construction creates state only; open() creates the sole web view.
/// Each close discards the page. Production contains no private WebKit selectors.
@MainActor
public final class CockpitWindowController: NSWindowController, NSWindowDelegate,
  WKNavigationDelegate, WKUIDelegate
{
  private let bundle: VerifiedCockpitBundle
  private var appearance: CockpitAppearance
  private let shellSession: CockpitShellSession
  private let anchor: () -> CGRect?
  private var layout: CockpitShellLayout?
  private var scope = "all"
  private var outsideMonitor: Any?, localMonitor: Any?
  private var closeTask: Task<Void, Never>?
  private var dragStart: (point: CGPoint, frame: CGRect, detached: Bool)?
  private var dragRegion: CockpitTitleDrag?
  private var snapGuide: NSPanel?
  public let bridge: CockpitBridgeState
  private var web: WKWebView?
  private let proxy = MessageProxy()
  private var observers: [NSObjectProtocol] = []
  private var lastVisibility: CockpitVisibility?
  private var clearWaiter: CheckedContinuation<Void, Never>?
  private var deadline: Task<Void, Never>?
  private var ending = false
  public var onReady: (() -> Void)?
  public var onIntent: ((CockpitIntent) -> Void)?
  public var onRendered: (() -> Void)?
  public var onClosed: (() -> Void)?
  public var onFailure: ((CockpitWindowFailure) -> Void)?
  #if MODELPLAN_TEST_ONLY_SPI
    public var verificationWebView: WKWebView? { web }
    public var verificationCloseStarted: ((TimeInterval) -> Void)?
    public var verificationDidDiscard: (() -> Void)?
    public var verificationOutsidePress: ((NSEvent.EventType,Bool)->Void)?
    public var verificationCloseOrigin: ((String)->Void)?
    public var verificationPlacement: (usable: CGRect, anchor: CGRect)? {
      didSet { applyLayout() }
    }
    public var verificationShellState: CockpitShellState? { currentShell }
    public var verificationRootHeight: CGFloat? { layout?.rootHeight }
    public var verificationDidOpen: ((WKWebView, NSWindow) -> Void)?
    public var verificationResource: ((String) -> Void)?
    public var configureVerification: ((WKWebViewConfiguration) -> Void)?
  #endif
  public var queryTicket: CockpitQueryTicket? { bridge.queryTicket }
  private var pageURL: URL {
    URL(string: "modelplan-cockpit://bundle/index.html?pageId=\(bridge.pageID.uuidString)")!
  }

  public init(
    bundle: VerifiedCockpitBundle, context: CockpitEngineContext, appearance: CockpitAppearance,
    shellSession: CockpitShellSession? = nil, anchor: @escaping () -> CGRect? = { nil }
  ) {
    self.bundle = bundle
    self.shellSession = shellSession ?? CockpitShellSession()
    self.anchor = anchor
    self.appearance = appearance
    self.bridge = CockpitBridgeState(context: context)
    super.init(window: nil)
  }
  required init?(coder: NSCoder) { nil }
  public func open() {
    closeTask?.cancel(); closeTask = nil
    guard web == nil, !bridge.disposed else {
      window?.alphaValue = 1
      window?.makeKeyAndOrderFront(nil)
      return
    }
    let config = WKWebViewConfiguration()
    config.websiteDataStore = .nonPersistent()
    #if MODELPLAN_TEST_ONLY_SPI
    config.setURLSchemeHandler(BundleScheme(bundle, observed: verificationResource), forURLScheme: "modelplan-cockpit")
    #else
    config.setURLSchemeHandler(BundleScheme(bundle), forURLScheme: "modelplan-cockpit")
    #endif
    proxy.owner = self
    config.userContentController.add(proxy, name: "cockpit")
    #if MODELPLAN_TEST_ONLY_SPI
      configureVerification?(config)
    #endif
    let view = WKWebView(frame: .zero, configuration: config)
    // The initial v2 load applies appearance and shell before a page can paint.
    view.isHidden = true
    view.navigationDelegate = self
    view.uiDelegate = self
    view.allowsBackForwardNavigationGestures = false
    let panel = CockpitPanel(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
    panel.isOpaque = false; panel.backgroundColor = .clear
    panel.hasShadow = false; panel.level = .floating; panel.hidesOnDeactivate = false
    panel.appearance = NSAppearance(named: .darkAqua)
    panel.title = "ModelPlan"
    panel.isReleasedWhenClosed = false
    panel.delegate = self
    let root = NSView(frame: .zero)
    root.addSubview(view)
    let drag = CockpitTitleDrag(frame: .zero)
    drag.event = { [weak self] phase, point in self?.titleDrag(phase, point: point) }
    root.addSubview(drag); dragRegion = drag
    panel.contentView = root
    self.window = panel
    web = view
    let center = NotificationCenter.default
    for name in [
      NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification,
      NSWindow.didChangeOcclusionStateNotification, NSWindow.didMiniaturizeNotification,
      NSWindow.didDeminiaturizeNotification,
    ] {
      observers.append(
        center.addObserver(forName: name, object: panel, queue: .main) { [weak self] _ in
          Task { @MainActor in self?.visibilityChanged() }
        })
    }
    for name in [
      NSApplication.didHideNotification, NSApplication.didUnhideNotification,
      NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification,
    ] {
      observers.append(
        center.addObserver(forName: name, object: NSApplication.shared, queue: .main) {
          [weak self] _ in Task { @MainActor in self?.visibilityChanged() }
        })
    }
    applyLayout()
    installOutsideMonitors()
    observers.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
      Task { @MainActor in self?.cancelDrag(); self?.applyLayout() }
    })
    view.load(URLRequest(url: pageURL))
    panel.alphaValue = appearance.reduceMotion ? 1 : 0
    panel.makeKeyAndOrderFront(nil)
    if !appearance.reduceMotion {
      NSAnimationContext.runAnimationGroup { context in context.duration = 0.18; panel.animator().alphaValue = 1 }
    }
    #if MODELPLAN_TEST_ONLY_SPI
      verificationDidOpen?(view, panel)
    #endif
  }
  public func display(_ data: WireCockpitData, ticket: CockpitQueryTicket) {
    do { send(try bridge.display(data, ticket: ticket)) } catch { fail() }
  }
  /// Hide synchronously before yielding; acknowledge only after clear receipt
  /// or complete view disposal. An unknown floor remains blocked after receipt.
  public func clearPrivateViews(adopting context: CockpitEngineContext? = nil) async {
    web?.isHidden = true
    scope = "all"
    guard web != nil, bridge.ready, clearWaiter == nil else {
      discard()
      return
    }
    do {
      let message = try bridge.clear(adopting: context)
      await withCheckedContinuation { continuation in
        clearWaiter = continuation
        deadline = Task { @MainActor [weak self] in
          do { try await Task.sleep(for: .seconds(2)) } catch { return }
          self?.fail(.clearDeadline)
        }
        send(message, clear: true)
      }
    } catch { fail() }
  }
  private func send(_ raw: String, clear: Bool = false, bootstrap: Bool = false) {
    guard let web else {
      fail()
      return
    }
    // JSON is an argument, never interpolated into executable JavaScript.
    let body =
      clear
      ? "if(!window.modelPlanCockpit)return 'missing';return window.modelPlanCockpit.clear(raw)===true?'accepted':'rejected'"
      : "if(!window.modelPlanCockpit)return 'missing';return window.modelPlanCockpit.receive(raw)===true?'accepted':'rejected'"
    // Navigation completion need not mean the module graph has evaluated.
    // Await the exact pinned entry module once; no polling or idle timer.
    let code = (bootstrap ? "await import('modelplan-cockpit://bundle/src/main.js');" : "") + body
    web.callAsyncJavaScript(code, arguments: ["raw": raw], in: nil, in: .page) {
      [weak self] result in
      Task { @MainActor in
        switch result {
        case .success(let accepted):
          if accepted as? String == "missing" { self?.fail(.pageAPIUnavailable) }
          else if accepted as? String != "accepted" { self?.fail(.messageRejected) }
        case .failure: self?.fail(.javascriptFailed)
        }
      }
    }
  }
  fileprivate func receive(_ message: WKScriptMessage) {
    guard message.webView === web, message.frameInfo.isMainFrame,
      message.frameInfo.securityOrigin.protocol == "modelplan-cockpit",
      message.frameInfo.securityOrigin.host == "bundle", message.frameInfo.securityOrigin.port == 0,
      message.frameInfo.request.url == pageURL, web?.url == pageURL,
      let raw = message.body as? String
    else { return }
    do {
      let receipt = try bridge.accept(
        raw, source: .init(mainFrame: true, origin: "modelplan-cockpit://bundle"))
      switch receipt {
      case .ready:
        web?.isHidden = false
        publishAppearance()
        visibilityChanged()
        onReady?()
      case .cleared:
        deadline?.cancel()
        deadline = nil
        let waiter = clearWaiter
        clearWaiter = nil
        if bridge.queryTicket != nil {
          web?.isHidden = false
          publishAppearance()
          lastVisibility = nil
          visibilityChanged()
        }
        waiter?.resume()
      case .action(let intent):
        switch intent {
        case .detach: setAttached(false)
        case .putBack: setAttached(true)
        case .shutterToggle:
          if layout?.forcedClosed != true { shellSession.shutterClosed.toggle(); applyLayout() }
        case .close: closeAnimated()
        default: onIntent?(intent)
        }
      case .rendered: onRendered?()
      }
    } catch CockpitBridgeError.unsupportedPageContract { fail(.pageAPIUnavailable) }
      catch { /* Reject without logging private message bodies. */ }
  }
  private func visibilityChanged() {
    guard let window, bridge.queryTicket != nil else { return }
    let value = CockpitVisibility(
      visible: window.isVisible && !window.isMiniaturized && !NSApp.isHidden,
      occluded: !window.occlusionState.contains(.visible), key: window.isKeyWindow && NSApp.isActive
    )
    guard value != lastVisibility else { return }
    lastVisibility = value
    do { send(try bridge.setVisibility(value)) } catch { fail() }
  }
  public func webView(
    _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
  ) {
    decisionHandler(
      navigationAction.targetFrame?.isMainFrame == true && navigationAction.request.url == pageURL
        ? .allow : .cancel)
  }
  public func webView(
    _ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
    for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures
  ) -> WKWebView? { nil }
  public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    guard webView.url == pageURL else {
      fail()
      return
    }
    guard let shell = currentShell else { fail(); return }
    do { send(try bridge.load(appearance, shell: shell), bootstrap: true) } catch { fail() }
  }
  public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { fail(.contentTerminated) }
  public func webView(
    _ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error
  ) { fail(.navigationFailed) }
  public func webView(
    _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
    withError error: Error
  ) { fail(.provisionalNavigationFailed) }
  public func windowWillClose(_ notification: Notification) { discard() }
  public func windowDidResignKey(_ notification: Notification) { cancelDrag() }
  public func updateScope(_ key:String) {
    guard key != scope, CockpitMemberScopes.isValidKey(key) else { return }
    scope=key; publishAppearance()
  }
  public func updateAppearance(_ value: CockpitAppearance) {
    appearance = CockpitAppearance(theme: .night, locale: value.locale, profile: appearance.profile,
      reduceMotion: value.reduceMotion, reduceTransparency: value.reduceTransparency, shutterClosed: appearance.shutterClosed, detached: shellSession.detached)
    if value.reduceMotion {
      if closeTask != nil { discard(); return }
      window?.alphaValue = 1
    }
    publishAppearance()
  }
  private var currentShell: CockpitShellState? { layout?.shellState(attached: !shellSession.detached, scope: scope) }
  private func publishAppearance() {
    guard bridge.ready, !bridge.blocked, !ending else { return }
    do {
      send(try bridge.setAppearance(appearance))
      guard let shell = currentShell else { fail(); return }
      send(try bridge.setShell(shell))
      lastVisibility = nil; visibilityChanged()
    } catch { fail() }
  }
  private var arrangement: String {
    NSScreen.screens.map { NSStringFromRect($0.frame) }.sorted().joined(separator: ";")
  }
  private func environment() -> (CGRect, CGRect)? {
    #if MODELPLAN_TEST_ONLY_SPI
    if let verificationPlacement { return (verificationPlacement.usable, verificationPlacement.anchor) }
    #endif
    let requested = anchor()
    guard let screen = NSScreen.screens.first(where: { screen in requested.map { screen.frame.intersects($0) } ?? false }) ?? NSScreen.main else { return nil }
    let icon = requested ?? CGRect(x: screen.visibleFrame.midX, y: screen.visibleFrame.maxY, width: 0, height: 0)
    return (screen.visibleFrame, icon)
  }
  private func applyLayout() {
    guard let window, let (usable, icon) = environment(),
          let fit = CockpitShellLayout.fit(usable: usable, anchor: icon, shutterClosed: shellSession.shutterClosed) else { return }
    layout = fit
    appearance = .init(theme: .night, locale: appearance.locale, profile: fit.profile,
      reduceMotion: appearance.reduceMotion, reduceTransparency: appearance.reduceTransparency, shutterClosed: fit.shutterClosed, detached: shellSession.detached)
    let frame = shellSession.detached ? fit.clamping(origin: shellSession.origin(for: arrangement) ?? window.frame.origin, usable: usable) : fit.frame
    window.setFrame(frame, display: true)
    window.contentView?.setBoundsSize(.init(width: 636, height: fit.rootHeight + 34))
    web?.frame = .init(x: 0, y: 0, width: 636, height: fit.rootHeight + 34)
    dragRegion?.frame = .init(x: 64, y: fit.rootHeight + 2, width: 390, height: 28)
    publishAppearance()
  }
  private func setAttached(_ attached: Bool) {
    guard let window, shellSession.detached == attached else { return }
    if !attached {
      shellSession.detached = true; shellSession.remember(window.frame.origin, arrangement: arrangement)
    } else {
      shellSession.detached = false
      guard let (usable, icon) = environment(), let fit = CockpitShellLayout.fit(usable: usable, anchor: icon, shutterClosed: shellSession.shutterClosed) else { return }
      if appearance.reduceMotion { applyLayout() }
      else {
        NSAnimationContext.runAnimationGroup { context in
          context.duration = 0.25; context.timingFunction = CAMediaTimingFunction(name: .easeOut)
          window.animator().setFrame(fit.frame, display: true)
        }
      }
    }
    updateAppearance(appearance)
  }
  private func titleDrag(_ phase: CockpitTitleDrag.Phase, point: CGPoint) {
    guard let window else { return }
    switch phase {
    case .began: dragStart = (point, window.frame, shellSession.detached)
    case .moved:
      guard let start = dragStart else { return }
      let dx = point.x - start.point.x, dy = point.y - start.point.y
      guard shellSession.detached || hypot(dx, dy) * window.backingScaleFactor > 12 else { return }
      let newlyDetached = !shellSession.detached
      shellSession.detached = true
      if newlyDetached { updateAppearance(appearance) }
      if let (usable, _) = environment(), let layout {
        window.setFrame(layout.clamping(origin: .init(x: start.frame.minX + dx, y: start.frame.minY + dy), usable: usable), display: true)
      }
      if let home = layout?.frame {
        let ready = hypot(window.frame.minX - home.minX, window.frame.minY - home.minY) * window.backingScaleFactor <= 40
        showSnapGuide(home, ready: ready)
      }
    case .ended:
      snapGuide?.orderOut(nil)
      guard dragStart != nil else { return }; dragStart = nil
      guard shellSession.detached else { return }
      if let (_, _) = environment(), let home = layout?.frame,
         hypot(window.frame.minX - home.minX, window.frame.minY - home.minY) * window.backingScaleFactor <= 40 {
        setAttached(true)
      } else { shellSession.remember(window.frame.origin, arrangement: arrangement) }
    case .cancelled: cancelDrag()
    }
  }
  private func showSnapGuide(_ frame: CGRect, ready: Bool) {
    guard let window else { return }
    if snapGuide == nil {
      let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
      panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
      panel.ignoresMouseEvents = true; panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
      let view = NSView(frame: .init(origin: .zero, size: frame.size)); view.wantsLayer = true
      view.layer = CAShapeLayer(); panel.contentView = view; panel.level = .floating; snapGuide = panel
    }
    snapGuide?.setFrame(frame, display: false)
    if let shape = snapGuide?.contentView?.layer as? CAShapeLayer {
      shape.path = CGPath(rect: CGRect(origin: .zero, size: frame.size).insetBy(dx: 1, dy: 1), transform: nil)
      shape.strokeColor = NSColor.gray.cgColor; shape.fillColor = NSColor.clear.cgColor
      shape.lineWidth = 1; shape.lineDashPattern = ready ? nil : [6, 4]
    }
    snapGuide?.order(.below, relativeTo: window.windowNumber)
  }
  private func cancelDrag() {
    snapGuide?.orderOut(nil)
    guard let start = dragStart else { return }; dragStart = nil
    shellSession.detached = start.detached; window?.setFrame(start.frame, display: true)
    updateAppearance(appearance)
  }
  private func installOutsideMonitors() {
    let events: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
    outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] event in
      let type=event.type
      Task { @MainActor in self?.outsidePress(NSEvent.mouseLocation,eventType:type) }
    }
    localMonitor = NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
      MainActor.assumeIsolated {
        let point = event.window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation
        self?.outsidePress(point,eventType:event.type)
      }
      return event
    }
  }
  private func outsidePress(_ point: CGPoint,eventType:NSEvent.EventType) {
    guard !shellSession.detached, let window, !window.frame.contains(point) else { return }
    // The owned tray completes one toggle on mouse-up. Its mouse-down is not
    // a competing outside dismissal, including with Reduce Motion/long holds.
    let isTray=anchor()?.contains(point) == true
    #if MODELPLAN_TEST_ONLY_SPI
    verificationOutsidePress?(eventType,isTray)
    #endif
    if eventType == .leftMouseDown, isTray { return }
    #if MODELPLAN_TEST_ONLY_SPI
    verificationCloseOrigin?("outside")
    #endif
    closeAnimated()
  }
  public func requestClose() {
    #if MODELPLAN_TEST_ONLY_SPI
    verificationCloseOrigin?("requested")
    #endif
    closeAnimated()
  }
  public func closeAnimated() {
    guard !ending, closeTask == nil else { return }
    #if MODELPLAN_TEST_ONLY_SPI
    verificationCloseStarted?(appearance.reduceMotion ? 0 : 0.12)
    #endif
    guard !appearance.reduceMotion, let window else { discard(); return }
    NSAnimationContext.runAnimationGroup { context in context.duration = 0.12; window.animator().alphaValue = 0 }
    closeTask = Task { @MainActor [weak self] in
      do { try await Task.sleep(for: .milliseconds(120)) } catch { return }
      self?.discard()
    }
  }
  private func fail(_ failure: CockpitWindowFailure = .localEncoding) {
    guard !ending else { return }
    onFailure?(failure)
    discard()
  }
  public func discard() {
    guard !ending else { return }
    ending = true
    #if MODELPLAN_TEST_ONLY_SPI
    verificationDidDiscard?()
    #endif
    closeTask?.cancel(); closeTask = nil; cancelDrag()
    if shellSession.detached, let window { shellSession.remember(window.frame.origin, arrangement: arrangement) }
    if let outsideMonitor { NSEvent.removeMonitor(outsideMonitor) }; outsideMonitor = nil
    if let localMonitor { NSEvent.removeMonitor(localMonitor) }; localMonitor = nil
    dragRegion?.event = nil; dragRegion = nil
    snapGuide?.close(); snapGuide = nil
    if let raw = bridge.unload(), let web {
      web.callAsyncJavaScript(
        "window.modelPlanCockpit?.receive(raw)", arguments: ["raw": raw], in: nil, in: .page,
        completionHandler: nil)
    }
    deadline?.cancel()
    deadline = nil
    let waiter = clearWaiter
    clearWaiter = nil
    observers.forEach(NotificationCenter.default.removeObserver)
    observers.removeAll()
    web?.configuration.userContentController.removeScriptMessageHandler(forName: "cockpit")
    web?.navigationDelegate = nil
    web?.uiDelegate = nil
    web?.stopLoading()
    window?.delegate = nil
    window?.contentView = nil
    window?.close()
    window = nil
    web = nil
    proxy.owner = nil
    waiter?.resume()
    onClosed?()
  }
}

@MainActor private final class CockpitPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
}
@MainActor private final class CockpitTitleDrag: NSView {
  enum Phase { case began, moved, ended, cancelled }
  var event: ((Phase, CGPoint) -> Void)?
  override var acceptsFirstResponder: Bool { true }
  private func point(_ event: NSEvent) -> CGPoint { window?.convertPoint(toScreen: event.locationInWindow) ?? .zero }
  override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self); self.event?(.began, point(event)) }
  override func mouseDragged(with event: NSEvent) { self.event?(.moved, point(event)) }
  override func mouseUp(with event: NSEvent) { self.event?(.ended, point(event)) }
  override func cancelOperation(_ sender: Any?) { event?(.cancelled, .zero) }
  override func keyDown(with event: NSEvent) { if event.keyCode == 53 { self.event?(.cancelled, .zero) } else { super.keyDown(with: event) } }
}
