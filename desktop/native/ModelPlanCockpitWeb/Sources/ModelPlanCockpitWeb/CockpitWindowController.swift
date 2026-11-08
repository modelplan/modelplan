// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanWire
import WebKit
import QuartzCore

public enum CockpitWindowFailure: String { case pageAPIUnavailable, messageRejected, javascriptFailed, navigationFailed, provisionalNavigationFailed, contentTerminated, clearDeadline, deadlineReceiptTimeout, visibilityReceiptTimeout, appearanceWaitTimeout, deadlineConvergence, localEncoding }

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

public enum CockpitBridgeDiagnostic: String {
  case rejectedMessage = "cockpit.bridge.message-rejected"
}

final class BundleScheme: NSObject, WKURLSchemeHandler {
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

/// CKP-SHELL-20: construction creates state only. prewarm() builds the sole web view and loads the page in
/// a panel that is never ordered front, with no data, focus or outside-press monitor; open() shows it, or
/// builds it first. Each close discards the page. Production contains no private WebKit selectors.
@MainActor
public final class CockpitWindowController: NSWindowController, NSWindowDelegate,
  WKNavigationDelegate, WKUIDelegate
{
  /// DOCK-3.1-26: a short press opens with this fade.
  static let openFade: TimeInterval = 0.18
  /// D49: the widget stays at `.floating` while the cockpit is open, and the cockpit opens over it.
  /// A widget being dragged rises to `.statusBar`, above this.
  public static let panelLevel = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
  /// Windows the open cockpit brings up (the enlarged field, the Help overlay) sit above it.
  public static let aboveCockpitLevel = NSWindow.Level(rawValue: panelLevel.rawValue + 1)
  /// The drag snap guide shares the cockpit's level so it can be ordered just below the cockpit.
  public static let snapGuideLevel = panelLevel
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
  private var freshnessObservers: [(NotificationCenter, NSObjectProtocol)] = []
  private var freshnessHasRendered = false
  private var refreshAfterHiddenDisplay = false
  private var appearanceGate = CockpitAppearanceGate()
  private var pendingFreshnessReason: CockpitDeadlineReason?
  private struct OutboundMessage { let code: String, raw: String }
  private lazy var orderedDelivery = CockpitOrderedDelivery<OutboundMessage> { [weak self] message, complete in
    #if MODELPLAN_TEST_ONLY_SPI
    if let fake = self?.verificationNoWindowDelivery { fake(message.raw, complete); return }
    #endif
    guard let web = self?.web else { complete(.missing); return }
    web.callAsyncJavaScript(message.code, arguments: ["raw": message.raw], in: nil, in: .page) { result in
      Task { @MainActor in
        switch result {
        case .success(let accepted):
          if accepted as? String == "accepted" { complete(.accepted) }
          else if accepted as? String == "missing" { complete(.missing) }
          else { complete(.rejected) }
        case .failure: complete(.failed)
        }
      }
    }
  }
  private var visibilityTimeout: Task<Void, Never>?
  private var visibilityFence = CockpitVisibilityFence()
  private static func wallClockMilliseconds() -> UInt64 {
    let value = Date().timeIntervalSince1970 * 1_000
    guard value.isFinite, value > 0 else { return 0 }
    return UInt64(min(value.rounded(.down), 8_640_000_000_000_000))
  }
  private static func armTimer(_ delay: UInt64, _ fire: @escaping @MainActor () -> Void) -> () -> Void {
    let task = Task { @MainActor in
      do { try await Task.sleep(for: .milliseconds(Int64(delay))) } catch { return }
      guard !Task.isCancelled else { return }; fire()
    }
    return { task.cancel() }
  }
  private func deadlineNow() -> UInt64 {
    #if MODELPLAN_TEST_ONLY_SPI
    if let clock = verificationNoWindowClock { return clock() }
    #endif
    return Self.wallClockMilliseconds()
  }
  private func armDeadline(_ delay: UInt64, _ fire: @escaping @MainActor () -> Void) -> () -> Void {
    #if MODELPLAN_TEST_ONLY_SPI
    if let arm = verificationNoWindowArm { return arm(delay, fire) }
    #endif
    return Self.armTimer(delay, fire)
  }
  private lazy var freshnessDriver = CockpitDeadlineDriver(
    now: { [weak self] in self?.deadlineNow() ?? 0 }, arm: { [weak self] delay, fire in self?.armDeadline(delay, fire) ?? {} },
    onExhausted: { [weak self] in self?.fail(.deadlineConvergence) },
    tick: { [weak self] reason in self?.sendFreshnessTick(reason) })
  private lazy var receiptWatchdog = CockpitDeadlineReceiptWatchdog(
    arm: { [weak self] delay, fire in self?.armDeadline(delay, fire) ?? {} }, timedOut: { [weak self] id in
      guard let self, !self.ending, self.bridge.awaitsDeadlineReceipt(id) else { return }
      self.fail(.deadlineReceiptTimeout)
    })
  private lazy var renderWatchdog = CockpitDeadlineReceiptWatchdog(
    arm: { [weak self] delay, fire in self?.armDeadline(delay, fire) ?? {} }, timedOut: { [weak self] id in
      guard let self, !self.ending, self.bridge.awaitsDisplayReceipt(id) else { return }
      self.fail(.deadlineReceiptTimeout)
    })
  private lazy var appearanceWatchdog = CockpitDeadlineReceiptWatchdog(
    arm: { [weak self] delay, fire in self?.armDeadline(delay, fire) ?? {} }, timedOut: { [weak self] _ in
      guard let self, !self.ending, self.visibilityFence.isConfirmedVisible, self.appearanceGate.isDeferred else { return }
      self.fail(.appearanceWaitTimeout)
    })
  private func watchDeferredAppearance() {
    guard visibilityFence.isConfirmedVisible, appearanceGate.isDeferred, appearanceWatchdog.currentID == nil else { return }
    appearanceWatchdog.wait(for: UUID())
  }
  private func sendFreshnessTick(_ reason: CockpitDeadlineReason) {
    guard !ending, closeTask == nil else { return }
    // A newly opened page has no admitted data to re-evaluate yet. Do not send
    // a tick the page cannot consume; deliver the latest prompt after rendering.
    guard freshnessHasRendered else { pendingFreshnessReason = reason; return }
    pendingFreshnessReason = nil
    receiptWatchdog.cancel()
    do {
      let raw = try bridge.tick(nowUnixMs: deadlineNow(), reason: reason)
      guard let id = bridge.currentDeadlineTrigger else { throw CockpitBridgeError.unavailable }
      receiptWatchdog.wait(for: id)
      send(raw, isCurrent: { [weak self] in self?.bridge.isCurrentDeadlineTrigger(id) == true })
    } catch { fail() }
  }
  private var lastVisibility: CockpitVisibility?
  private var openedAt: TimeInterval?
  private var clearWaiter: CheckedContinuation<Void, Never>?
  private var deadline: Task<Void, Never>?
  private var ending = false
  public var onReady: (() -> Void)?
  public var onIntent: ((CockpitIntent) -> Void)?
  public var onRendered: (() -> Void)?
  public var onClosed: (() -> Void)?
  /// Once per open, when the page is first confirmed visible. It replaces the hidden-display refresh then.
  public var onShown: (() -> Void)?
  private var shown = false, awaitingShown = false
  /// The first visible paint of a WebKit process (its GPU and compositing start) took about 2.3 s on a
  /// hosted runner even with the page loaded. A prewarmed page pays it in the background: the empty page is
  /// ordered in at alpha 0, ignoring the mouse and never key, until two animation frames have painted, then
  /// ordered out.
  private var warmPainting = false
  /// G3-42: every new page pays part of this, not only the process's first. In the packaged walkthrough a
  /// page rebuilt after a close took 0.9 s from the click to its first visibility receipt and 1.3 s to data,
  /// and the hosted test once 2.5 s, against 0.1 s and 0.5 s for the warm-painted first page. So every hidden
  /// page is warm-painted. A warm paint that reaches its cap means this process does not paint at alpha 0,
  /// and then none is tried again, so an invisible panel is not ordered in for six seconds after each close.
  private static var warmPaintUnavailable = false
  private var warmPaintEnd: Task<Void, Never>?
  private var warmPaintStarted: TimeInterval?
  /// G3-42 timing: render receipts logged since the last open, the first two only.
  private var rendersSinceOpen = 2
  #if MODELPLAN_TEST_ONLY_SPI
  public var verificationWarmPainted: ((Bool) -> Void)?
  /// Holds back the receipt of a hidden visibility state, as a busy WebKit process at launch does.
  public var verificationHoldHiddenVisibilityReceipt = false
  #endif
  public var onFailure: ((CockpitWindowFailure) -> Void)?
  public var onBridgeDiagnostic: ((CockpitBridgeDiagnostic) -> Void)?
  public private(set) var rejectedBridgeMessageCount: UInt64 = 0
  #if MODELPLAN_TEST_ONLY_SPI
    var verificationNoWindowDelivery: ((String, @escaping (CockpitDeliveryResult) -> Void) -> Void)?
    var verificationNoWindowClock: (() -> UInt64)?
    var verificationNoWindowArm: CockpitDeadlineDriver.Arm?
    var verificationNoWindowShell: CockpitShellState?
    func verificationConfirmVisible() throws {
      _ = try bridge.setVisibility(.init(visible: true, occluded: false, key: false))
      let token = visibilityFence.begin(visible: true); _ = visibilityFence.confirm(token)
      freshnessDriver.show()
    }
    func verificationReceive(_ raw: String, source: CockpitMessageSource) { receiveRaw(raw, source: source) }
    func verificationHideWithoutWindow() throws {
      suspendForHiddenPage(); visibilityFence.invalidate()
      _ = try bridge.setVisibility(.init(visible: false, occluded: true, key: false))
    }
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
    public var verificationDragRegion: NSView? { dragRegion }
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
  public func prewarm() {
    guard web == nil, !bridge.disposed, !ending else { return }
    build()
  }
  public func open() {
    closeTask?.cancel(); closeTask = nil
    if openedAt == nil { openedAt = ProcessInfo.processInfo.systemUptime }
    if web == nil, !bridge.disposed, !ending { build() }
    guard let panel = window else { return }
    guard shown else {
      shown = true; awaitingShown = true; rendersSinceOpen = 0
      endWarmPaint(painted: false)
      applyLayout()
      installOutsideMonitors()
      panel.alphaValue = appearance.reduceMotion ? 1 : 0
      panel.makeKeyAndOrderFront(nil)
      if !appearance.reduceMotion {
        NSAnimationContext.runAnimationGroup { context in context.duration = Self.openFade; panel.animator().alphaValue = 1 }
      }
      lastVisibility = nil; visibilityChanged()
      #if MODELPLAN_TEST_ONLY_SPI
        if let web { verificationDidOpen?(web, panel) }
      #endif
      return
    }
    panel.alphaValue = 1
    panel.makeKeyAndOrderFront(nil)
    lastVisibility = nil; visibilityChanged()
  }
  private func build() {
    if openedAt == nil { openedAt = ProcessInfo.processInfo.systemUptime }
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
    // Owner review 11-08 / CKP-SHELL-25: only the hull and canopy are drawn; the web view paints no backing of its
    // own, so the clear panel shows the desktop around the transparent page.
    view.setValue(false, forKey: "drawsBackground")
    view.underPageBackgroundColor = .clear
    // The initial v2 load applies appearance and shell before a page can paint.
    view.isHidden = true
    view.navigationDelegate = self
    view.uiDelegate = self
    view.allowsBackForwardNavigationGestures = false
    let panel = CockpitPanel(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
    panel.isOpaque = false; panel.backgroundColor = .clear
    panel.hasShadow = false; panel.level = Self.panelLevel; panel.hidesOnDeactivate = false
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
    let workspaceCenter = NSWorkspace.shared.notificationCenter
    for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
      let observer = workspaceCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        Task { @MainActor in self?.freshnessDriver.notify(.wake) }
      }
      freshnessObservers.append((workspaceCenter, observer))
    }
    let distributed = DistributedNotificationCenter.default()
    let unlock = distributed.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
      Task { @MainActor in self?.freshnessDriver.notify(.unlock) }
    }
    freshnessObservers.append((distributed, unlock))
    let clock = center.addObserver(forName: Notification.Name.NSSystemClockDidChange, object: nil, queue: .main) { [weak self] _ in
      Task { @MainActor in self?.freshnessDriver.notify(.clockChange) }
    }
    freshnessObservers.append((center, clock))
    applyLayout()
    observers.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
      Task { @MainActor in self?.cancelDrag(); self?.applyLayout() }
    })
    panel.alphaValue = 0
    view.load(URLRequest(url: pageURL))
  }
  public func display(_ data: WireCockpitData, ticket: CockpitQueryTicket) {
    guard visibilityFence.isConfirmedVisible else {
      // Do not retain hidden snapshots; request fresh data after show is accepted.
      refreshAfterHiddenDisplay = true; return
    }
    receiptWatchdog.cancel(); renderWatchdog.cancel()
    // A pending replacement does not prove the displayed deadline is obsolete.
    // Keep its timer until a validated newer report actually replaces it.
    do {
      let raw = try bridge.display(data, ticket: ticket)
      guard let id = bridge.currentDisplayRequest else { throw CockpitBridgeError.unavailable }
      if bridge.awaitsDisplayReceipt(id) { renderWatchdog.wait(for: id) }
      send(raw, isCurrent: { [weak self] in self?.bridge.isCurrentDisplay(id) == true })
    } catch { fail() }
  }
  /// Hide synchronously before yielding; acknowledge only after clear receipt
  /// or complete view disposal. An unknown floor remains blocked after receipt.
  public func clearPrivateViews(adopting context: CockpitEngineContext? = nil) async {
    freshnessDriver.hide(); freshnessDriver.invalidate(); bridge.cancelDeadlineReports(); visibilityFence.invalidate()
    orderedDelivery.invalidate(); refreshAfterHiddenDisplay = false; appearanceGate.invalidate(); appearanceWatchdog.cancel()
    receiptWatchdog.cancel(); renderWatchdog.cancel()
    visibilityTimeout?.cancel(); visibilityTimeout = nil
    freshnessHasRendered = false; pendingFreshnessReason = nil
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
  private func send(_ raw: String, clear: Bool = false, bootstrap: Bool = false,
                    isCurrent: (() -> Bool)? = nil, onAccepted: (() -> Void)? = nil) {
    let web = self.web
    #if MODELPLAN_TEST_ONLY_SPI
    let noWindowTest = web == nil && verificationNoWindowDelivery != nil
    #else
    let noWindowTest = false
    #endif
    guard web != nil || noWindowTest else { fail(); return }
    let context = bridge.context, revision = bridge.viewRevision
    // JSON is an argument, never interpolated into executable JavaScript.
    let body = clear
      ? "if(!window.modelPlanCockpit)return 'missing';return window.modelPlanCockpit.clear(raw)===true?'accepted':'rejected'"
      : "if(!window.modelPlanCockpit)return 'missing';return window.modelPlanCockpit.receive(raw)===true?'accepted':'rejected'"
    let code = (bootstrap ? "await import('modelplan-cockpit://bundle/src/main.js');" : "") + body
    let submitted = orderedDelivery.submit(OutboundMessage(code: code, raw: raw), isCurrent: { [weak self, weak web] in
      guard let self else { return false }
      #if MODELPLAN_TEST_ONLY_SPI
      let targetMatches = noWindowTest ? (self.web == nil && self.verificationNoWindowDelivery != nil) : (web != nil && self.web === web)
      #else
      let targetMatches = web != nil && self.web === web
      #endif
      return targetMatches && !self.ending && self.bridge.context == context &&
        self.bridge.viewRevision == revision && (isCurrent?() ?? true)
    }, completed: { [weak self] result in
      guard let self else { return }
      switch result {
      case .accepted: onAccepted?()
      case .missing: self.fail(.pageAPIUnavailable)
      case .rejected: self.fail(.messageRejected)
      case .failed: self.fail(.javascriptFailed)
      }
    })
    if !submitted { fail(.localEncoding) }
  }
  fileprivate func receive(_ message: WKScriptMessage) {
    guard message.webView === web, message.frameInfo.isMainFrame,
      message.frameInfo.securityOrigin.protocol == "modelplan-cockpit",
      message.frameInfo.securityOrigin.host == "bundle", message.frameInfo.securityOrigin.port == 0,
      message.frameInfo.request.url == pageURL, web?.url == pageURL,
      let raw = message.body as? String
    else { recordRejectedBridgeMessage(); return }
    receiveRaw(raw, source: .init(mainFrame: true, origin: "modelplan-cockpit://bundle"))
  }
  private func receiveRaw(_ raw: String, source: CockpitMessageSource) {
    guard let receipt = acceptBridgeReply(raw, source: source) else { return }
      switch receipt {
      case .ready:
        web?.isHidden = false
        publishAppearance()
        visibilityChanged()
        onReady?()
        if !shown { warmPaint() }
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
      case .rendered:
        if let id = renderWatchdog.currentID, !bridge.awaitsDisplayReceipt(id) { renderWatchdog.cancel() }
        if let id = receiptWatchdog.currentID, !bridge.awaitsDeadlineReceipt(id) {
          receiptWatchdog.cancel()
        }
        freshnessHasRendered = true
        if shown, rendersSinceOpen < 2 {
          rendersSinceOpen += 1
          CockpitTimingLog.record("open rendered n=\(rendersSinceOpen) clickMs=\(CockpitTimingLog.sinceClick())")
        }
        if let buffered = bridge.takeBufferedDeadline() { freshnessDriver.accept(deadline: buffered.value) }
        else if let id = bridge.currentDeadlineTrigger, bridge.isCurrentDisplay(id) { receiptWatchdog.wait(for: id) }
        if let reason = pendingFreshnessReason { sendFreshnessTick(reason) }
        if appearanceGate.retry(visible: visibilityFence.isConfirmedVisible, displayPending: bridge.hasPendingDisplay) { publishAppearance() }
        onRendered?()
      case .deadlinePending(let id):
        if receiptWatchdog.currentID != id { receiptWatchdog.wait(for: id) }
      case .nextDeadline(let value):
        receiptWatchdog.cancel(); freshnessDriver.accept(deadline: value)
        if appearanceGate.retry(visible: visibilityFence.isConfirmedVisible, displayPending: bridge.hasPendingDisplay) { publishAppearance() }
      }
  }
  private func warmPaint() {
    guard !Self.warmPaintUnavailable, let panel = window, let web, !shown, !ending, !warmPainting else { return }
    warmPainting = true
    warmPaintStarted = CockpitTimingLog.now
    panel.ignoresMouseEvents = true
    panel.alphaValue = 0
    panel.orderFrontRegardless()
    warmPaintEnd = Task { @MainActor [weak self] in
      do { try await Task.sleep(for: .seconds(6)) } catch { return }
      self?.endWarmPaint(painted: false)
    }
    // Resolves after the page has painted twice; a page WebKit still treats as hidden never resolves.
    web.callAsyncJavaScript(
      "await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(()=>r(true))));return true",
      arguments: [:], in: nil, in: .defaultClient
    ) { [weak self] result in
      Task { @MainActor in
        guard let self, self.warmPainting else { return }
        if case .success = result { self.endWarmPaint(painted: true) } else { self.endWarmPaint(painted: false) }
      }
    }
  }
  private func endWarmPaint(painted: Bool) {
    warmPaintEnd?.cancel(); warmPaintEnd = nil
    guard warmPainting else { return }
    warmPainting = false
    // Capped while still hidden: this process does not paint at alpha 0 (see warmPaintUnavailable). A click
    // during the warm paint (painted false, shown) is not a cap.
    if !painted, !shown { Self.warmPaintUnavailable = true }
    CockpitTimingLog.record("prewarm warm-paint painted=\(painted) clicked=\(shown) ms=\(warmPaintStarted.map { CockpitTimingLog.ms(since: $0) } ?? -1)")
    #if MODELPLAN_TEST_ONLY_SPI
    verificationWarmPainted?(painted)
    #endif
    window?.ignoresMouseEvents = false
    guard !shown, !ending else { return }
    window?.orderOut(nil)
  }
  private func recordRejectedBridgeMessage() {
    if rejectedBridgeMessageCount < UInt64.max { rejectedBridgeMessageCount += 1 }
    onBridgeDiagnostic?(.rejectedMessage)
  }
  func acceptBridgeReply(_ raw: String, source: CockpitMessageSource) -> CockpitReceipt? {
    do { return try bridge.accept(raw, source: source) }
    catch CockpitBridgeError.unsupportedPageContract { recordRejectedBridgeMessage(); fail(.pageAPIUnavailable); return nil }
    catch { recordRejectedBridgeMessage(); return nil }
  }
  private func suspendForHiddenPage() {
    refreshAfterHiddenDisplay = refreshAfterHiddenDisplay || bridge.hasPendingDisplay
    appearanceGate.deferUntilVisible(); appearanceWatchdog.cancel(); orderedDelivery.invalidate()
    freshnessDriver.hide(); bridge.cancelDeadlineReports(); pendingFreshnessReason = nil
    receiptWatchdog.cancel(); renderWatchdog.cancel()

  }
  private func visibilityChanged() {
    // The alpha-0 warm paint is not a visible cockpit; the page keeps the hidden state it was given.
    guard !ending, !warmPainting, closeTask == nil, let window, bridge.queryTicket != nil else { return }
    let value = CockpitVisibility(
      visible: window.isVisible && !window.isMiniaturized && !NSApp.isHidden,
      occluded: !window.occlusionState.contains(.visible), key: window.isKeyWindow && NSApp.isActive
    )
    guard value != lastVisibility else { return }
    lastVisibility = value
    let visible = value.visible && !value.occluded
    let retainVisibleSchedule = visible && freshnessDriver.isVisible
    let token = visibilityFence.begin(visible: visible)
    if !visible { suspendForHiddenPage() }
    else if !retainVisibleSchedule {
      freshnessDriver.hide(); bridge.cancelDeadlineReports(); pendingFreshnessReason = nil
      receiptWatchdog.cancel(); renderWatchdog.cancel()
    }
    visibilityTimeout?.cancel()
    visibilityTimeout = Task { @MainActor [weak self] in
      do { try await Task.sleep(for: .seconds(2)) } catch { return }
      guard let self, !self.ending, self.visibilityFence.isPending(token) else { return }
      // G3-42: a page that has not been shown shows nothing, so a late hidden-state receipt is not a failure.
      // At launch the WebKit process can be busy past this deadline; failing here threw the prewarmed page
      // away and built another. The fence stays pending, and the open sends a new state with its own deadline.
      guard self.shown else { CockpitTimingLog.record("prewarm hidden-visibility-late"); return }
      self.fail(.visibilityReceiptTimeout)
    }
    do {
      send(try bridge.setVisibility(value), isCurrent: { [weak self] in self?.visibilityFence.isCurrent(token) == true }, onAccepted: { [weak self] in
        guard let self else { return }
        #if MODELPLAN_TEST_ONLY_SPI
        if self.verificationHoldHiddenVisibilityReceipt, !visible { return }
        #endif
        self.visibilityTimeout?.cancel(); self.visibilityTimeout = nil
        if self.visibilityFence.confirm(token) {
          if self.appearanceGate.retry(visible: true, displayPending: self.bridge.hasPendingDisplay) { self.publishAppearance() }
          else { self.watchDeferredAppearance() }
          if let id = self.bridge.currentDisplayRequest, self.bridge.awaitsDisplayReceipt(id) { self.renderWatchdog.wait(for: id) }
          self.freshnessDriver.show()
          if self.awaitingShown, let onShown = self.onShown {
            self.awaitingShown = false; self.refreshAfterHiddenDisplay = false; onShown()
          } else if self.refreshAfterHiddenDisplay { self.refreshAfterHiddenDisplay = false; self.onReady?() }
          self.awaitingShown = false
        }
      })
    } catch { fail() }
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
      reduceMotion: value.reduceMotion, reduceTransparency: value.reduceTransparency, shutterClosed: appearance.shutterClosed, detached: shellSession.detached, redBelow: value.redBelow, showProjectNames: value.showProjectNames)
    if value.reduceMotion {
      if closeTask != nil { discard(); return }
      window?.alphaValue = 1
    }
    publishAppearance()
  }
  private var currentShell: CockpitShellState? {
    #if MODELPLAN_TEST_ONLY_SPI
    if let shell = verificationNoWindowShell { return shell }
    #endif
    return layout?.shellState(attached: !shellSession.detached, scope: scope)
  }
  private func publishAppearance() {
    guard bridge.ready, !bridge.blocked, !ending else { return }
    let canSend = appearanceGate.request(visible: visibilityFence.isConfirmedVisible, displayPending: bridge.hasPendingDisplay)
    let appearanceVersion = appearanceGate.version
    watchDeferredAppearance()
    guard canSend else { return }
    do {
      let eligible = visibilityFence.isConfirmedVisible && freshnessHasRendered
      let raw = try bridge.setAppearance(appearance, deadlineEligible: eligible)
      if let id = bridge.currentAppearanceTrigger {
        // Keep the previously admitted deadline until this repaint reports a replacement.
        receiptWatchdog.wait(for: id)
        send(raw, isCurrent: { [weak self] in self?.bridge.isCurrentAppearance(id) == true }, onAccepted: { [weak self] in
          guard let self else { return }
          guard self.bridge.acknowledgeAppearance(id) else { self.fail(.messageRejected); return }
          if self.appearanceGate.acknowledge(appearanceVersion) { self.appearanceWatchdog.cancel() }
          if let buffered = self.bridge.takeBufferedDeadline() {
            self.receiptWatchdog.cancel(); self.freshnessDriver.accept(deadline: buffered.value)
          } else if self.receiptWatchdog.currentID != id { self.receiptWatchdog.wait(for: id) }
        })
      } else {
        send(raw, onAccepted: { [weak self] in
          guard let self else { return }
          if self.appearanceGate.acknowledge(appearanceVersion) { self.appearanceWatchdog.cancel() }
        })
      }
      guard let shell = currentShell else { fail(); return }
      send(try bridge.setShell(shell))
      visibilityChanged()
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
    let icon = requested ?? CockpitShellLayout.hiddenIconAnchor(usable: screen.visibleFrame)
    return (screen.visibleFrame, icon)
  }
  private func applyLayout() {
    guard let window, let (usable, icon) = environment(),
          let fit = CockpitShellLayout.fit(usable: usable, anchor: icon, shutterClosed: shellSession.shutterClosed) else { return }
    layout = fit
    appearance = .init(theme: .night, locale: appearance.locale, profile: fit.profile,
      reduceMotion: appearance.reduceMotion, reduceTransparency: appearance.reduceTransparency, shutterClosed: fit.shutterClosed, detached: shellSession.detached, redBelow: appearance.redBelow, showProjectNames: appearance.showProjectNames)
    let frame = shellSession.detached ? fit.clamping(origin: shellSession.origin(for: arrangement) ?? window.frame.origin, usable: usable) : fit.frame
    window.setFrame(frame, display: true)
    window.contentView?.setBoundsSize(.init(width: 636, height: fit.rootHeight + 34))
    web?.frame = .init(x: 0, y: 0, width: 636, height: fit.rootHeight + 34)
    dragRegion?.frame = fit.titleDragFrame
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
      view.layer = CAShapeLayer(); panel.contentView = view; panel.level = Self.snapGuideLevel; snapGuide = panel
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
    freshnessDriver.hide(); bridge.cancelDeadlineReports(); pendingFreshnessReason = nil
    orderedDelivery.invalidate(); refreshAfterHiddenDisplay = false; appearanceGate.deferUntilVisible(); appearanceWatchdog.cancel()
    visibilityFence.invalidate(); visibilityTimeout?.cancel(); visibilityTimeout = nil
    receiptWatchdog.cancel(); renderWatchdog.cancel()
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
  private func fail(_ failure: CockpitWindowFailure = .localEncoding, at site: StaticString = #function, line: UInt = #line) {
    guard !ending else { return }
    let age = openedAt.map { Int((ProcessInfo.processInfo.systemUptime - $0) * 1_000) }
    CockpitFailureLog.record("page-failure failure=\(failure.rawValue) at=\(site):\(line) ageMs=\(age.map(String.init) ?? "none") "
      + "ready=\(bridge.ready) visible=\(visibilityFence.isConfirmedVisible) rendered=\(freshnessHasRendered) "
      + "displayPending=\(bridge.hasPendingDisplay) occluded=\(lastVisibility?.occluded.description ?? "unknown")")
    onFailure?(failure)
    discard()
  }
  public func discard() {
    guard !ending else { return }
    ending = true
    warmPaintEnd?.cancel(); warmPaintEnd = nil; warmPainting = false
    freshnessDriver.retire(); bridge.cancelDeadlineReports(); pendingFreshnessReason = nil
    orderedDelivery.invalidate(); refreshAfterHiddenDisplay = false; appearanceGate.invalidate(); appearanceWatchdog.cancel()
    visibilityFence.invalidate(); visibilityTimeout?.cancel(); visibilityTimeout = nil
    receiptWatchdog.cancel(); renderWatchdog.cancel()
    freshnessObservers.forEach { center, token in center.removeObserver(token) }
    freshnessObservers.removeAll()
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
