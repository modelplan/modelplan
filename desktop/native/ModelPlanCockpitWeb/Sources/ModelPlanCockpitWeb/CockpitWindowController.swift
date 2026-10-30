// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanWire
import WebKit

public enum CockpitWindowFailure: String { case pageAPIUnavailable, messageRejected, javascriptFailed, navigationFailed, provisionalNavigationFailed, contentTerminated, clearDeadline, localEncoding }

// WebKit's module CORS fetch requires NSHTTPURLResponse header fields, even
// for a custom scheme. Only public, hash-pinned static files use this response;
// private DTOs never have a scheme route. No credentialed CORS is enabled.
enum CockpitSchemeResponse {
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
      guard let url = task.request.url, url.scheme == "modelplan-cockpit", url.host == "bundle",
        url.user == nil, url.password == nil, url.port == nil,
        task.request.httpMethod == "GET"
      else { throw CockpitBundleError.unsafePath }
      let path = String(url.path.dropFirst())
      let data = try bundle.resource(path: path)
      observed?(path)
      let mime =
        [
          "html": "text/html", "js": "text/javascript", "css": "text/css",
          "json": "application/json", "png": "image/png", "woff2": "font/woff2",
          "woff": "font/woff", "txt": "text/plain", "md": "text/plain",
        ][url.pathExtension] ?? "application/octet-stream"
      task.didReceive(CockpitSchemeResponse.make(url: url, mime: mime, bytes: data.count))
      task.didReceive(data)
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
  private let appearance: CockpitAppearance
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
    public var verificationDidOpen: ((WKWebView, NSWindow) -> Void)?
    public var verificationResource: ((String) -> Void)?
    public var configureVerification: ((WKWebViewConfiguration) -> Void)?
  #endif
  public var queryTicket: CockpitQueryTicket? { bridge.queryTicket }
  private var pageURL: URL {
    URL(string: "modelplan-cockpit://bundle/index.html?pageId=\(bridge.pageID.uuidString)")!
  }

  public init(
    bundle: VerifiedCockpitBundle, context: CockpitEngineContext, appearance: CockpitAppearance
  ) {
    self.bundle = bundle
    self.appearance = appearance
    self.bridge = CockpitBridgeState(context: context)
    super.init(window: nil)
  }
  required init?(coder: NSCoder) { nil }
  public func open() {
    guard web == nil, !bridge.disposed else {
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
    view.navigationDelegate = self
    view.uiDelegate = self
    view.allowsBackForwardNavigationGestures = false
    let panel = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 636, height: appearance.profile == .full ? 890 : 640),
      styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
    panel.title = "ModelPlan"
    panel.isReleasedWhenClosed = false
    panel.delegate = self
    panel.contentView = view
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
    view.load(URLRequest(url: pageURL))
    panel.center()
    panel.makeKeyAndOrderFront(nil)
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
  private func send(_ raw: String, clear: Bool = false) {
    guard let web else {
      fail()
      return
    }
    // JSON is an argument, never interpolated into executable JavaScript.
    let code =
      clear
      ? "if(!window.modelPlanCockpit)return 'missing';return window.modelPlanCockpit.clear(raw)===true?'accepted':'rejected'"
      : "if(!window.modelPlanCockpit)return 'missing';return window.modelPlanCockpit.receive(raw)===true?'accepted':'rejected'"
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
        visibilityChanged()
        onReady?()
      case .cleared:
        deadline?.cancel()
        deadline = nil
        let waiter = clearWaiter
        clearWaiter = nil
        if bridge.queryTicket != nil {
          web?.isHidden = false
          lastVisibility = nil
          visibilityChanged()
        }
        waiter?.resume()
      case .action(let intent): onIntent?(intent)
      case .rendered: onRendered?()
      }
    } catch { /* Reject without logging private message bodies. */  }
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
    do { send(try bridge.load(appearance)) } catch { fail() }
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
  private func fail(_ failure: CockpitWindowFailure = .localEncoding) {
    onFailure?(failure)
    discard()
  }
  public func discard() {
    guard !ending else { return }
    ending = true
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
