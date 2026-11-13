// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanWire
import WebKit
import QuartzCore

public enum CockpitWindowFailure: String { case pageAPIUnavailable, messageRejected, javascriptFailed, navigationFailed, provisionalNavigationFailed, contentTerminated, clearDeadline, deadlineReceiptTimeout, visibilityReceiptTimeout, appearanceWaitTimeout, deadlineConvergence, localEncoding, deliveryBacklog
  /// G3-95: the bundled cockpit could not serve a file it admitted earlier (removed or changed since). A reinstall problem.
  case bundleResource }

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

/// How an open enters. CKP-SHELL-33 (D186/D188, replaces D88's grow): from the menu bar icon the launch rack's
/// visible part extends first and the attached cockpit then comes out from under the menu bar; every other entry (the
/// widget ignition, a shortcut, a menu item) keeps the plain fade, with the rack simply there when attached.
public enum CockpitEntrance: Equatable, Sendable { case fade, fromIcon }

/// D88: where the one-time detach / put-back hint points, in screen coordinates.
public struct CockpitAttachmentHintAnchor: Equatable {
  public let attached: Bool
  public let frame: CGRect
  public let sharing: NSWindow.SharingType
  public let collection: NSWindow.CollectionBehavior
}

/// D88: the cockpit's own right-click menu target. WebKit's menu (Reload and the rest) is never shown.
@MainActor final class CockpitMenuTarget: NSObject {
  var fire: (() -> Void)?
  /// Never named `perform(_:)`: NSObject's `performSelector:` is also `perform(_:)` in Swift, `#selector` resolved to
  /// it, and AppKit then sent the menu item itself as the selector (unrecognized-selector crash on Detach / Put back).
  @objc(cockpitAttachmentItemChosen:) func attachmentItemChosen(_ sender: Any?) { fire?() }
  static let action = #selector(CockpitMenuTarget.attachmentItemChosen(_:))
}

public enum CockpitBridgeDiagnostic: String {
  case rejectedMessage = "cockpit.bridge.message-rejected"
}

final class BundleScheme: NSObject, WKURLSchemeHandler {
  let bundle: VerifiedCockpitBundle
  let observed: ((String) -> Void)?
  /// Called on the main thread when a request for a bundled file failed.
  var failed: (() -> Void)?
  init(_ bundle: VerifiedCockpitBundle, observed: ((String) -> Void)? = nil) { self.bundle = bundle; self.observed = observed }
  func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
    do {
      let result = try CockpitSchemeResponse.load(request: task.request, bundle: bundle)
      if let url = task.request.url { observed?(String(url.path.dropFirst())) }
      task.didReceive(result.response)
      task.didReceive(result.data)
      task.didFinish()
    } catch { task.didFailWithError(CockpitBundleError.integrity); failed?() }
  }
  func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {}
}

@MainActor private final class MessageProxy: NSObject, WKScriptMessageHandler {
  weak var owner: CockpitWindowController?
  func userContentController(
    _ controller: WKUserContentController, didReceive message: WKScriptMessage
  ) { owner?.receive(message) }
}

/// D204: whether the user can see the cockpit window, from the window's own facts.
public struct CockpitUserVisibility: Equatable, Sendable {
  public var onScreen: Bool, miniaturized: Bool, onActiveSpace: Bool, occluded: Bool, appHidden: Bool
  public init(onScreen: Bool, miniaturized: Bool, onActiveSpace: Bool, occluded: Bool, appHidden: Bool) {
    self.onScreen = onScreen; self.miniaturized = miniaturized; self.onActiveSpace = onActiveSpace
    self.occluded = occluded; self.appHidden = appHidden
  }
  /// Partly covered is visible; only a fully covered window (occlusion state without `.visible`) is not.
  public var visible: Bool { onScreen && !miniaturized && onActiveSpace && !occluded && !appHidden }
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
  /// D88: help and hint panels carry this identifier; a press on one is not an outside click.
  public static let helpOverlayIdentifier = NSUserInterfaceItemIdentifier("modelplan.help-overlay")
  /// The enlarged field's panel carries this identifier. It opens from the cockpit and is wider than it, so a press on
  /// it outside the cockpit's frame is not an outside click either (audit A-1: it closed both windows).
  public static let fieldWindowIdentifier = NSUserInterfaceItemIdentifier("modelplan.field")
  /// D88: the detach / put-back key, at the prototype strip position (Settings 460, this 502, Close 544).
  static let attachmentKeyX: CGFloat = 502, attachmentKeySize: CGFloat = 32
  private let bundle: VerifiedCockpitBundle
  private var appearance: CockpitAppearance
  private let shellSession: CockpitShellSession
  private let anchor: () -> CGRect?
  /// Build 14c (G3-79): the screen point an open came from (the widget's ignition click); nil opens on the icon's display.
  private let openPoint: () -> CGPoint?
  /// The displays placement and drags use; tests replace it with a fixed arrangement.
  var screens: @MainActor () -> [CockpitScreen] = { CockpitScreenSelection.system() }
  /// D204: whether each display has its own Spaces (and so its own menu bar); tests replace it.
  var separateSpaces: @MainActor () -> Bool = { NSScreen.screensHaveSeparateSpaces }
  /// D204 (G3-94): the widget ignition's frame on screen. A press on it is the ignition's own toggle, decided on
  /// mouse-up; its mouse-down is not an outside click that closes the attached cockpit first.
  public var ignitionFrame: (@MainActor () -> CGRect?)?
  /// D204: the occlusion state counts only once the window server has reported it since the last order-front;
  /// until then a freshly ordered-in window is not mistaken for a covered one.
  private var occlusionReported = false
  private var layout: CockpitShellLayout?
  private var scope = "all"
  private var outsideMonitor: Any?, localMonitor: Any?
  private var closeTask: Task<Void, Never>?
  private var dragStart: (point: CGPoint, frame: CGRect, detached: Bool)?
  private var dragRegion: CockpitTitleDrag?
  /// CKP-SHELL-33: the drag has been outside the catch zone since it tore off, and the rack is now reaching for it.
  private var dragArmed = false, dragCatching = false
  /// CKP-SHELL-33: this open came from the menu bar icon, so an attached close reverses the rack-first open.
  private var openedFromIcon = false
  /// True while the open's entrance runs; the hint anchor waits for its end.
  private var entering = false
  /// CKP-SHELL-33: the launch rack under the attached cockpit, and its motion (see the Launch rack section).
  private lazy var rack = CockpitLaunchRack(art: CockpitRackArt.load(bundle))
  private var rackExtension: CGFloat = 0, rackTarget: CGFloat = 0
  private var rackPace: TimeInterval = CockpitLaunchRackTiming.fullTravel
  private var rackTimer: Timer?
  private var rackClock: TimeInterval = 0
  private var rackSettledWaiters: [@MainActor () -> Void] = []
  private struct Motion { let start: TimeInterval; let duration: TimeInterval; let step: @MainActor (CGFloat) -> Void; let done: @MainActor () -> Void }
  private var motion: Motion?
  /// The nozzles are lit (the page's amber bell glow).
  private var ignited = false
  /// The rack stays hidden inside the attached frame while the open's slide or the close runs.
  private var rackHidesInHome = false
  private let menuTarget = CockpitMenuTarget()
  public let bridge: CockpitBridgeState
  private var web: WKWebView?
  /// G3-55: set by the first main-frame navigation of this web view; later ones (Reload) are cancelled.
  private var pageLoadStarted = false
  /// The app's own right-click menu for the page. Nil shows nothing; WebKit's menu never appears.
  public var contextMenuProvider: (() -> NSMenu?)?
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
          else {
            // "rejected:<code>": the page's fixed code path for the refusal, never message content.
            let code = (accepted as? String).flatMap { $0.hasPrefix("rejected:") ? String($0.dropFirst(9)) : nil } ?? "unknown"
            self?.lastRejectCode = String(code.filter { $0.isLetter || $0.isNumber || $0 == "." }.prefix(40))
            complete(.rejected)
          }
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
  /// Page-side code path of the last rejected host message (bridge.ts `lastReject`).
  private var lastRejectCode = "none"
  private var tickRetries = 0
  private static let maxTickRetries = 3
  /// A tick the page refuses only because its own visibility has not caught up (document still hidden, no
  /// display yet) carries no state: the page learns the real state from the visibility message and its own
  /// events. Retry it shortly instead of discarding the page. Any other rejection stays a failure.
  private func retryRejectedTick(_ reason: CockpitDeadlineReason) -> Bool {
    guard lastRejectCode.hasPrefix("tick."), lastRejectCode != "tick.view", tickRetries < Self.maxTickRetries else { return false }
    tickRetries += 1
    receiptWatchdog.cancel()
    CockpitFailureLog.record("page-resync tick retry=\(tickRetries) code=\(lastRejectCode)")
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(120))
      guard let self, !self.ending else { return }
      self.sendFreshnessTick(reason)
    }
    return true
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
      send(raw, isCurrent: { [weak self] in self?.bridge.isCurrentDeadlineTrigger(id) == true },
           onAccepted: { [weak self] in self?.tickRetries = 0 },
           onRejected: { [weak self] in self?.retryRejectedTick(reason) ?? false },
           dropped: { [weak self] in
        guard let self else { return }
        if self.receiptWatchdog.currentID == id { self.receiptWatchdog.cancel() }
        self.backlog.tick = reason
      })
    } catch { fail(error: error) }
  }
  private var lastVisibility: CockpitVisibility?
  private var openedAt: TimeInterval?
  private var clearWaiter: CheckedContinuation<Void, Never>?
  private var deadline: Task<Void, Never>?
  private var ending = false
  public var onReady: (() -> Void)?
  /// D88: the attachment, or the settled open, changed. Fired after a detach, a put back, a drop and the
  /// end of the entrance, never on every step of a drag.
  public var onShellChanged: (() -> Void)?
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
    /// G3-86: the next this many submissions are refused as a full delivery queue refuses them.
    var verificationRefuseSubmissions = 0
    /// Actions are admitted only from the key window (`CockpitVisibility.active`), so a window that is shown for
    /// an action test must be key; pass `key: false` for a shown-but-inactive window.
    func verificationConfirmVisible(key: Bool = true) throws {
      _ = try bridge.setVisibility(.init(visible: true, occluded: false, key: key))
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
    /// "rack", "fade" or "instant" for each first show; "rack", "fade" or "instant" for each close (CKP-SHELL-33).
    public var verificationEntrance: ((String)->Void)?
    public var verificationContextMenu: NSMenu? { contextMenu() }
    public var verificationPlacement: (usable: CGRect, anchor: CGRect)? {
      didSet { applyLayout() }
    }
    public var verificationShellState: CockpitShellState? { currentShell }
    public var verificationRootHeight: CGFloat? { layout?.rootHeight }
    public var verificationLayout: CockpitShellLayout? { layout }
    public var verificationDragRegion: NSView? { dragRegion }
    /// CKP-SHELL-33: the launch rack as last drawn (extension 0-1, where it is heading, its panel when on screen),
    /// whether the nozzles are lit, and whether a motion (open, landing, flight) is running.
    public var verificationRack: (ext: CGFloat, target: CGFloat, panel: CGRect?, ignited: Bool, moving: Bool) {
      (rackExtension, rackTarget, rack.panel?.isVisible == true ? rack.panel?.frame : nil, ignited, motion != nil)
    }
    /// Every ignition change sent to the page, in order.
    public var verificationIgnition: ((Bool) -> Void)?
    /// The landing a key detach chose (D187).
    public var verificationLanding: ((CockpitDetachLanding.Plan) -> Void)?
    public var verificationDidOpen: ((WKWebView, NSWindow) -> Void)?
    public var verificationResource: ((String) -> Void)?
    public var configureVerification: ((WKWebViewConfiguration) -> Void)?
  #endif
  public var queryTicket: CockpitQueryTicket? { bridge.queryTicket }
  var pageURL: URL {
    URL(string: "modelplan-cockpit://bundle/index.html?pageId=\(bridge.pageID.uuidString)")!
  }

  public init(
    bundle: VerifiedCockpitBundle, context: CockpitEngineContext, appearance: CockpitAppearance,
    shellSession: CockpitShellSession? = nil, anchor: @escaping () -> CGRect? = { nil },
    openPoint: @escaping () -> CGPoint? = { nil }
  ) {
    self.bundle = bundle
    self.shellSession = shellSession ?? CockpitShellSession()
    self.anchor = anchor
    self.openPoint = openPoint
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
    let wasVisible = isVisibleToUser
    let wasClosing = closeTask != nil
    closeTask?.cancel(); closeTask = nil
    if openedAt == nil { openedAt = ProcessInfo.processInfo.systemUptime }
    if web == nil, !bridge.disposed, !ending { build() }
    guard let panel = window else { return }
    guard shown else {
      shown = true; awaitingShown = true; rendersSinceOpen = 0
      let entrance = shellSession.nextEntrance; shellSession.nextEntrance = .fade
      endWarmPaint(painted: false)
      applyLayout()
      installOutsideMonitors()
      let target = panel.frame
      let rackFirst = Self.opensRackFirst(entrance, reduceMotion: appearance.reduceMotion, detached: shellSession.detached, icon: rackIcon())
      openedFromIcon = entrance == .fromIcon
      occlusionReported = false
      if rackFirst {
        // CKP-SHELL-33 (D186/D188): the page is prepared from the click (ordered in at alpha 0, so it loads, takes its
        // visibility and asks for data) while the rack's visible part extends; then the cockpit comes out from under the
        // menu bar with whatever it has (the last reply until the fresh one lands), never waiting for data.
        entering = true; rackHidesInHome = true
        panel.alphaValue = 0
        panel.setFrame(target.offsetBy(dx: 0, dy: CockpitLaunchRackTiming.openRise), display: false)
        panel.makeKeyAndOrderFront(nil)
        rackExtension = 0; rackTarget = 0
        runMotion(CockpitLaunchRackTiming.rackOpen, step: { [weak self] t in
          guard let self else { return }
          self.rackExtension = t / 3; self.rackTarget = self.rackExtension
        }, done: { [weak self] in
          guard let self, self.window != nil else { return }
          self.runMotion(CockpitLaunchRackTiming.cockpitOpen, step: { [weak self] t in
            guard let self, let panel = self.window, let home = self.layout?.frame else { return }
            let eased = 1 - pow(1 - t, 3)
            self.rackExtension = 1.0 / 3 + 2.0 / 3 * t; self.rackTarget = self.rackExtension
            panel.alphaValue = min(1, t * 2.2)
            panel.setFrame(home.offsetBy(dx: 0, dy: CockpitLaunchRackTiming.openRise * (1 - eased)), display: true)
          }, done: { [weak self] in
            guard let self, let panel = self.window else { return }
            self.entering = false; self.rackHidesInHome = false
            self.rackExtension = 1; self.rackTarget = 1
            panel.alphaValue = 1
            if let frame = self.layout?.frame { panel.setFrame(frame, display: true) }
            self.onShellChanged?()
          })
        })
      } else {
        // The rack is simply there when the attached cockpit hangs under the icon.
        rackExtension = rackIcon() != nil && !shellSession.detached ? 1 : 0; rackTarget = rackExtension
        refreshRack()
        panel.alphaValue = appearance.reduceMotion ? 1 : 0
        panel.makeKeyAndOrderFront(nil)
        if !appearance.reduceMotion {
          NSAnimationContext.runAnimationGroup { context in context.duration = Self.openFade; panel.animator().alphaValue = 1 }
        }
      }
      #if MODELPLAN_TEST_ONLY_SPI
        verificationEntrance?(rackFirst ? "rack" : appearance.reduceMotion ? "instant" : "fade")
      #endif
      if !rackFirst { onShellChanged?() }
      lastVisibility = nil; visibilityChanged()
      #if MODELPLAN_TEST_ONLY_SPI
        if let web { verificationDidOpen?(web, panel) }
      #endif
      return
    }
    // A second open during the rack-first entrance lets it finish.
    if entering, !wasClosing { panel.makeKeyAndOrderFront(nil); return }
    if wasClosing {
      // Re-opened during the close: stop the running close motion or fade (a zero-length group replaces it) and
      // present at the layout frame with the rack out, instead of leaving the window where the close had taken it.
      entering = false; rackHidesInHome = false; motion = nil
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0
        panel.animator().alphaValue = 1
        panel.animator().setFrame(panel.frame, display: false)
      }
      rackExtension = rackIcon() != nil && !shellSession.detached ? 1 : 0; rackTarget = rackExtension
      applyLayout()
    }
    // D204: an open brings the cockpit in front (a detached one where it is); an unseen attached one is laid out again.
    if !wasVisible, !wasClosing, !shellSession.detached { applyLayout() }
    panel.alphaValue = 1
    bringToFront(panel)
    lastVisibility = nil; visibilityChanged()
  }
  /// D204: whether the user can see the cockpit: shown and not closing, ordered in, not minimised, on the active Space
  /// and not fully covered (a partly covered window is visible), with the app not hidden. An open of an attached
  /// cockpit the user cannot see lays it out again under the icon of the display asked on before it comes in front.
  public var isVisibleToUser: Bool {
    guard shown, !ending, closeTask == nil, let window else { return false }
    return CockpitUserVisibility(onScreen: window.isVisible, miniaturized: window.isMiniaturized, onActiveSpace: window.isOnActiveSpace,
      occluded: occlusionReported && !window.occlusionState.contains(.visible), appHidden: NSApp.isHidden).visible
  }
  /// D204: off the Dock if minimised, and onto the current Space without switching the user to the window's own Space.
  private func bringToFront(_ panel: NSWindow) {
    if panel.isMiniaturized { panel.deminiaturize(nil) }
    occlusionReported = false
    let behavior = panel.collectionBehavior
    if !panel.isOnActiveSpace, !behavior.contains(.canJoinAllSpaces) {
      // Ordered in with this behaviour the window moves to the active Space; the old behaviour is restored after.
      panel.collectionBehavior = behavior.union(.moveToActiveSpace)
      panel.makeKeyAndOrderFront(nil)
      panel.collectionBehavior = behavior
    } else { panel.makeKeyAndOrderFront(nil) }
  }
  private func build() {
    if openedAt == nil { openedAt = ProcessInfo.processInfo.systemUptime }
    let config = WKWebViewConfiguration()
    config.websiteDataStore = .nonPersistent()
    #if MODELPLAN_TEST_ONLY_SPI
    let scheme = BundleScheme(bundle, observed: verificationResource)
    #else
    let scheme = BundleScheme(bundle)
    #endif
    // WebKit calls the handler on the main thread, and before the navigation failure that follows it, so the cause is
    // the bundle's, not a generic navigation failure (G3-95).
    scheme.failed = { [weak self] in MainActor.assumeIsolated { self?.fail(.bundleResource) } }
    config.setURLSchemeHandler(scheme, forURLScheme: "modelplan-cockpit")
    proxy.owner = self
    config.userContentController.add(proxy, name: "cockpit")
    #if MODELPLAN_TEST_ONLY_SPI
      configureVerification?(config)
    #endif
    let view = CockpitWebView(frame: .zero, configuration: config)
    view.menuProvider = { [weak self] in self?.contextMenu() }
    menuTarget.fire = { [weak self] in self?.toggleAttachment() }
    // Owner review 11-08 / CKP-SHELL-25: only the hull and canopy are drawn; the web view paints no backing of its
    // own, so the clear panel shows the desktop around the transparent page. `CockpitWebView.isOpaque` being false is
    // not enough: WKWebView on macOS still paints its opaque backing unless `drawsBackground` is false (hosted
    // macos-15 U11 showed opaque corners without it), and AppKit has no public equivalent.
    view.setValue(false, forKey: "drawsBackground")
    view.underPageBackgroundColor = .clear
    pageLoadStarted = false
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
    drag.contextMenu = { [weak view] event in view?.rightMouseDown(with: event) }
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
    observers.append(center.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: panel, queue: .main) { [weak self] _ in
      Task { @MainActor in self?.occlusionReported = true }
    })
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
      let dropped = bridge.lastNonFinitePaths
      for path in dropped.prefix(8) { CockpitFailureLog.record("display-non-finite path=\(path) count=\(dropped.count)") }
      guard let id = bridge.currentDisplayRequest else { throw CockpitBridgeError.unavailable }
      if bridge.awaitsDisplayReceipt(id) { renderWatchdog.wait(for: id) }
      send(raw, isCurrent: { [weak self] in self?.bridge.isCurrentDisplay(id) == true }, dropped: { [weak self] in
        guard let self else { return }
        if self.renderWatchdog.currentID == id { self.renderWatchdog.cancel() }
        if self.receiptWatchdog.currentID == id { self.receiptWatchdog.cancel() }
        self.bridge.abandonDisplay(id)
        self.backlog.display = true
      })
    } catch { fail(error: error) }
  }
  /// Hide synchronously before yielding; acknowledge only after clear receipt
  /// or complete view disposal. An unknown floor remains blocked after receipt.
  public func clearPrivateViews(adopting context: CockpitEngineContext? = nil) async {
    freshnessDriver.hide(); freshnessDriver.invalidate(); bridge.cancelDeadlineReports(); visibilityFence.invalidate()
    orderedDelivery.invalidate(); refreshAfterHiddenDisplay = false; appearanceGate.invalidate(); appearanceWatchdog.cancel()
    receiptWatchdog.cancel(); renderWatchdog.cancel(); backlog = BacklogResync()
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
    } catch { fail(error: error) }
  }
  /// G3-86: what a skipped update needs once the queue moves again. The page keeps showing its last state.
  private struct BacklogResync { var display = false, visibility = false, appearance = false; var tick: CockpitDeadlineReason? }
  private var backlog = BacklogResync()
  /// Consecutive messages the ordered queue refused, reset by any accepted delivery.
  private var deliveryRefusals = 0
  static let maximumDeliveryRefusals = 8
  /// `onRejected` runs when the page refused a delivered message; returning true means the caller recovers
  /// (a retry), false ends the page as `messageRejected`. `dropped` runs when the ordered queue refuses the
  /// message before delivery: the caller undoes its wait and marks what to resend.
  private func send(_ raw: String, clear: Bool = false, bootstrap: Bool = false, coalesce: String? = nil,
                    isCurrent: (() -> Bool)? = nil, onAccepted: (() -> Void)? = nil,
                    onRejected: (() -> Bool)? = nil, dropped: (() -> Void)? = nil) {
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
      ? "if(!window.modelPlanCockpit)return 'missing';return window.modelPlanCockpit.clear(raw)===true?'accepted':'rejected:'+String((typeof window.modelPlanCockpit.reject==='function'?window.modelPlanCockpit.reject():null)||'none')"
      : "if(!window.modelPlanCockpit)return 'missing';return window.modelPlanCockpit.receive(raw)===true?'accepted':'rejected:'+String((typeof window.modelPlanCockpit.reject==='function'?window.modelPlanCockpit.reject():null)||'none')"
    let code = (bootstrap ? "await import('modelplan-cockpit://bundle/src/main.js');" : "") + body
    #if MODELPLAN_TEST_ONLY_SPI
    let refused = verificationRefuseSubmissions > 0
    if refused { verificationRefuseSubmissions -= 1 }
    #else
    let refused = false
    #endif
    var submitted = false
    if !refused { submitted = orderedDelivery.submit(OutboundMessage(code: code, raw: raw), coalesce: coalesce, isCurrent: { [weak self, weak web] in
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
      case .accepted: self.deliveryRefusals = 0; onAccepted?(); self.resyncAfterBacklog()
      case .missing: self.fail(.pageAPIUnavailable)
      case .rejected:
        CockpitFailureLog.record("page-reject code=\(self.lastRejectCode)")
        if onRejected?() != true { self.fail(.messageRejected) }
      case .failed: self.fail(.javascriptFailed)
      }
    }) }
    guard !submitted else { return }
    // G3-86 (14c C-01): a full queue used to end the cockpit as `localEncoding` after about a minute open.
    // One refused update is skipped and resent when the queue moves; only a queue that stays stuck ends the page.
    deliveryRefusals += 1
    CockpitFailureLog.record("delivery-skipped type=\(Self.messageType(raw)) outstanding=\(orderedDelivery.outstanding) "
      + "consecutive=\(deliveryRefusals)")
    guard deliveryRefusals < Self.maximumDeliveryRefusals else { fail(.deliveryBacklog); return }
    dropped?()
  }
  private static func errorDetail(_ error: Error) -> String {
    let name = CockpitFailureLog.errorName(error)
    guard let encoding = error as? EncodingError, case .invalidValue(_, let context) = encoding else { return name }
    return name + ".path=" + context.codingPath.map(\.stringValue).joined(separator: ".")
  }
  private static func messageType(_ raw: String) -> String {
    guard let object = try? JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any],
      let type = object["type"] as? String, type.utf8.count <= 32, type.allSatisfy({ $0.isLetter }) else { return "unknown" }
    return type
  }
  /// Resends what a refused update left stale, once the queue has room again.
  private func resyncAfterBacklog() {
    guard !ending, orderedDelivery.outstanding < 8 else { return }
    let pending = backlog
    guard pending.display || pending.visibility || pending.appearance || pending.tick != nil else { return }
    backlog = BacklogResync()
    CockpitFailureLog.record("delivery-resync display=\(pending.display) visibility=\(pending.visibility) "
      + "appearance=\(pending.appearance) tick=\(pending.tick?.rawValue ?? "none")")
    if pending.visibility { lastVisibility = nil; visibilityChanged() }
    if pending.appearance, !ending { publishAppearance() }
    if let reason = pending.tick, !ending { sendFreshnessTick(reason) }
    if pending.display, !ending { onReady?() }
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
          toggleShutter()
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
    refreshAfterHiddenDisplay = refreshAfterHiddenDisplay || bridge.hasPendingDisplay || backlog.display
    backlog = BacklogResync()
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
      }, dropped: { [weak self] in
        guard let self else { return }
        self.visibilityTimeout?.cancel(); self.visibilityTimeout = nil
        self.backlog.visibility = true
      })
    } catch { fail(error: error) }
  }
  public func webView(
    _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
  ) {
    let allowed = CockpitNavigationPolicy.allows(
      isMainFrame: navigationAction.targetFrame?.isMainFrame == true, url: navigationAction.request.url,
      pageURL: pageURL, type: navigationAction.navigationType, alreadyLoaded: pageLoadStarted)
    if allowed { pageLoadStarted = true }
    decisionHandler(allowed ? .allow : .cancel)
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
    do { send(try bridge.load(appearance, shell: shell), bootstrap: true) } catch { fail(error: error) }
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
  /// macrev2-845-1: a detached cockpit that lands on another display without a drag (the system moved it) is fitted
  /// to that display, as a drop is.
  public func windowDidChangeScreen(_ notification: Notification) {
    guard let window, shown, shellSession.detached, dragStart == nil, !entering, motion == nil, closeTask == nil, !ending else { return }
    fitToDropDisplay(window)
  }
  /// The detached cockpit's current place becomes its remembered origin, and the layout (zoom, profile, forced shutter)
  /// is fitted to the display that origin is on, so the whole cockpit is inside that display's visible frame.
  private func fitToDropDisplay(_ window: NSWindow) {
    shellSession.remember(window.frame.origin, arrangement: arrangement)
    applyLayout()
    shellSession.remember(window.frame.origin, arrangement: arrangement)
  }
  /// The cockpit window's frame while it is on screen (the field opens on its display), else nil.
  public var cockpitFrame: CGRect? {
    guard let window, window.isVisible, !ending else { return nil }
    return window.frame
  }
  /// D88: the grow and shrink animate the frame; the content keeps its 636 pt bounds so it scales with it.
  public func windowDidResize(_ notification: Notification) {
    guard let layout, let content = window?.contentView else { return }
    // Scaled layouts (CKP-SHELL-07): the settled canvas is the scaled frame, not the 636-pt page.
    let size = layout.frame.size
    if content.bounds.size != size { content.setBoundsSize(size) }
  }
  public func setAckedCautions(_ ids:[String]) { bridge.ackedCautions = ids }
  public func updateScope(_ key:String) {
    guard key != scope, CockpitMemberScopes.isValidKey(key) else { return }
    scope=key; publishAppearance()
  }
  public func updateAppearance(_ value: CockpitAppearance) {
    let resized = value.size != appearance.size
    appearance = CockpitAppearance(theme: CockpitDayPolicy.resolve(value.theme), locale: value.locale, profile: appearance.profile,
      reduceMotion: value.reduceMotion, reduceTransparency: value.reduceTransparency, shutterClosed: appearance.shutterClosed, detached: shellSession.detached, redBelow: value.redBelow, showProjectNames: value.showProjectNames, showUsedPercent: value.showUsedPercent, size: value.size)
    if value.reduceMotion {
      if closeTask != nil { discard(); return }
      // Audit A-6: only a shown cockpit goes to full opacity; a prewarmed page (warm-painting at alpha 0) stays hidden.
      if shown { window?.alphaValue = 1 }
    }
    // Settings "Cockpit size" applies live to an open cockpit; the relayout publishes the appearance.
    if resized, window != nil { applyLayout() } else { publishAppearance() }
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
        }, dropped: { [weak self] in
          guard let self else { return }
          if self.receiptWatchdog.currentID == id { self.receiptWatchdog.cancel() }
          self.backlog.appearance = true
        })
      } else {
        // A newer untriggered appearance or shell carries the whole state, so it replaces a queued older one.
        send(raw, coalesce: "appearance", onAccepted: { [weak self] in
          guard let self else { return }
          if self.appearanceGate.acknowledge(appearanceVersion) { self.appearanceWatchdog.cancel() }
        }, dropped: { [weak self] in self?.backlog.appearance = true })
      }
      guard let shell = currentShell else { fail(); return }
      send(try bridge.setShell(shell), coalesce: "shell", dropped: { [weak self] in self?.backlog.appearance = true })
      visibilityChanged()
    } catch { fail(error: error) }
  }
  var arrangement: String {
    screens().map { NSStringFromRect($0.frame) }.sorted().joined(separator: ";")
  }
  /// Where a detached cockpit was: the origin remembered for this arrangement, else the laid-out window's own.
  private var detachedOrigin: CGPoint? {
    if let remembered = shellSession.origin(for: arrangement) { return remembered }
    guard let window, !window.frame.isEmpty else { return nil }
    return window.frame.origin
  }
  /// The usable frame and icon rect the layout is fitted to. Build 14c (G3-79): a detached cockpit stays on the
  /// display its remembered origin is on while that is still a display; otherwise the open goes to the display the
  /// user clicked on (the widget's), and only without a click to the menu bar icon's display. The icon rect is the
  /// real icon only on its own display; elsewhere the cockpit opens at that display's top right, as with no icon.
  func environment() -> (CGRect, CGRect)? {
    #if MODELPLAN_TEST_ONLY_SPI
    if let verificationPlacement { return (verificationPlacement.usable, verificationPlacement.anchor) }
    #endif
    let displays = self.screens(), requested = anchor()
    var remembered: CockpitScreen?
    if shellSession.detached, let origin = detachedOrigin,
       let replayed = CockpitScreenSelection.replayFrame(origin: origin, size: layout?.frame.size ?? CGSize(width: 1, height: 1), screens: displays) {
      remembered = CockpitScreenSelection.overlapping(replayed, in: displays)
    }
    // D204: an attached open follows the menu bar the user can see (`attachedScreen`); a detached one, the click's display.
    let asked = shellSession.detached
      ? CockpitScreenSelection.openScreen(point: openPoint(), anchor: requested, screens: displays)
      : CockpitScreenSelection.attachedScreen(point: openPoint(), anchor: requested, screens: displays, separateSpaces: separateSpaces())
    guard let screen = remembered ?? asked else { return nil }
    let onScreen = shellSession.detached
      ? requested.flatMap { screen.frame.intersects($0) ? $0 : nil }
      : CockpitScreenSelection.icon(requested, on: screen, screens: displays)
    let icon = onScreen ?? CockpitShellLayout.hiddenIconAnchor(usable: screen.visibleFrame)
    return (screen.visibleFrame, icon)
  }
  /// Where Put back takes the cockpit: the attached fit on the display an attached open uses. The catch zone, the
  /// rack and the put back all use this one frame; a detached layout's own frame can be another display's
  /// (post-merge sample 11-11: after a drop on another display the put back must still go home).
  func attachedHome() -> CGRect? { attachedFit()?.fit.frame }
  /// The attached fit, the usable frame and the icon rect it was fitted to (`compact` forces the short version).
  func attachedFit(compact: Bool = false) -> (fit: CockpitShellLayout, usable: CGRect, icon: CGRect)? {
    let detached = shellSession.detached
    shellSession.detached = false; defer { shellSession.detached = detached }
    guard let (usable, icon) = environment(),
          let fit = CockpitShellLayout.fit(usable: usable, anchor: icon, shutterClosed: shellSession.shutterClosed, size: appearance.size,
                                           screenWidth: screenWidth(usable), forceCompact: compact) else { return nil }
    return (fit, usable, icon)
  }
  /// CKP-SHELL-33: the menu bar icon the rack hangs from, only while it is a real icon on the attached cockpit's display.
  func rackIcon() -> CGRect? {
    guard let (_, _, icon) = attachedFit(), let requested = anchor(), icon == requested, icon.width > 0, icon.height > 0,
          [icon.minX, icon.minY, icon.width, icon.height].allSatisfy(\.isFinite) else { return nil }
    return icon
  }
  /// D66: Auto judges the full width of the screen the cockpit opens on, whatever the Dock takes.
  private func screenWidth(_ usable: CGRect) -> CGFloat {
    screens().first { $0.visibleFrame == usable }?.frame.width ?? usable.width
  }
  /// The fit and the window frame an open or a relayout uses. Build 14c (G3-79): a detached cockpit's remembered
  /// origin is replayed only while it is still on some display; otherwise the cockpit takes its attached place on
  /// the display `environment()` chose (the click's).
  func placement() -> (fit: CockpitShellLayout, frame: CGRect)? {
    guard let (usable, icon) = environment(),
          let fit = CockpitShellLayout.fit(usable: usable, anchor: icon, shutterClosed: shellSession.shutterClosed, size: appearance.size, screenWidth: screenWidth(usable),
                                           forceCompact: shellSession.detached && shellSession.compactWhileDetached) else { return nil }
    guard shellSession.detached else { return (fit, fit.frame) }
    #if MODELPLAN_TEST_ONLY_SPI
    if verificationPlacement != nil { return (fit, fit.clamping(origin: detachedOrigin ?? fit.frame.origin, usable: usable)) }
    #endif
    let replayed = detachedOrigin.flatMap { CockpitScreenSelection.replayFrame(origin: $0, size: fit.frame.size, screens: screens()) }
    return (fit, replayed ?? fit.frame)
  }
  private func applyLayout(animated: Bool = false) {
    // D88: a closing cockpit keeps its close animation. A relayout then (a screen-parameter change, a resize from
    // Settings) set the frame back to the layout frame and cut the shrink into the icon; a re-open cancels the close
    // first and lays out again.
    guard closeTask == nil, let window, let (fit, frame) = placement() else { return }
    layout = fit
    appearance = .init(theme: CockpitDayPolicy.resolve(appearance.theme), locale: appearance.locale, profile: fit.profile,
      reduceMotion: appearance.reduceMotion, reduceTransparency: appearance.reduceTransparency, shutterClosed: fit.shutterClosed, detached: shellSession.detached, redBelow: appearance.redBelow, showProjectNames: appearance.showProjectNames, showUsedPercent: appearance.showUsedPercent, size: appearance.size)
    if animated {
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.25; context.timingFunction = CAMediaTimingFunction(name: .easeOut)
        window.animator().setFrame(frame, display: true)
      }
    } else { window.setFrame(frame, display: true) }
    // CKP-SHELL-07 (owner D51): a scaled cockpit is the same page at a uniform WebKit page zoom, not a
    // scaled bitmap, so text is drawn at its final size and the page hit-tests its own controls.
    let bounds = CGRect(origin: .zero, size: frame.size)
    window.contentView?.setBoundsSize(bounds.size)
    web?.frame = bounds
    web?.pageZoom = fit.scale
    dragRegion?.frame = fit.scaledTitleDragFrame
    publishAppearance()
    if motion == nil { refreshRack() }
  }
  /// Context menu "Reset position": a dragged-out cockpit goes back under the menu bar icon.
  public func resetPosition() { setAttached(true) }
  /// Context menu "Help…": shows the page's Option help map (Esc or a click dismisses it). The page shows
  /// it only while it is the key window, so a cockpit that is not key is made key first and the page is
  /// given a moment to learn it.
  public func showHelpMap() {
    guard bridge.ready, web != nil, let window else { return }
    if window.isKeyWindow { dispatchHelpMap(); return }
    window.makeKeyAndOrderFront(nil)
    Task { @MainActor [weak self] in
      for _ in 0..<10 where self?.window?.isKeyWindow != true { try? await Task.sleep(for: .milliseconds(30)) }
      try? await Task.sleep(for: .milliseconds(150)) // visibility reaches the page by message
      self?.dispatchHelpMap()
    }
  }
  private func dispatchHelpMap() {
    guard !ending, bridge.ready, let web else { return }
    web.callAsyncJavaScript("window.dispatchEvent(new KeyboardEvent('keydown',{key:'Alt'}))", arguments: [:], in: nil, in: .page, completionHandler: nil)
  }
  func toggleShutter() {
    if layout?.forcedClosed != true { shellSession.shutterClosed.toggle(); applyLayout() }
  }
  public var isAttached: Bool { !shellSession.detached }
  /// The detach key (attached) or the put-back key (detached) in the same strip slot, and the right-click item.
  /// CKP-SHELL-33 (D181/D187): a detach burns the nozzles briefly and moves the cockpit out of the catch zone to the
  /// first spot fully on screen while the rack retracts into the icon; a put back lights the nozzles at the press, flies
  /// home, the rack extends and catches it, and the nozzles go out once it is latched.
  func setAttached(_ attached: Bool) {
    guard let window, shellSession.detached == attached else { return }
    finishEntrance()
    if !attached { keyDetach(window) } else { keyPutBack(window) }
  }
  private func keyDetach(_ window: NSWindow) {
    let home = window.frame
    let current = attachedFit()
    let compact = current.flatMap { $0.fit.profile == .full ? attachedFit(compact: true)?.fit.frame : nil }
    let visible = current?.usable ?? window.screen?.visibleFrame ?? home
    let plan = CockpitDetachLanding.plan(home: home, compactHome: compact, visible: visible)
    #if MODELPLAN_TEST_ONLY_SPI
    verificationLanding?(plan)
    #endif
    shellSession.detached = true
    if plan.compact, let compact {
      // D187: no room for the full cockpit; it switches to the short version at home, then moves.
      shellSession.compactWhileDetached = true
      shellSession.remember(compact.origin, arrangement: arrangement)
      applyLayout()
    }
    shellSession.remember(plan.frame.origin, arrangement: arrangement)
    updateAppearance(appearance)
    guard !appearance.reduceMotion else {
      window.setFrame(plan.frame, display: true)
      rackExtension = 0; rackTarget = 0; refreshRack()
      onShellChanged?(); return
    }
    let start = window.frame
    ignite(true)
    retractRack()
    runMotion(CockpitLaunchRackTiming.keyDetachBurn, step: { [weak self] t in
      let e = CockpitRackMast.easeInOut(t)
      self?.window?.setFrame(Self.lerp(start, plan.frame, e), display: true)
    }, done: { [weak self] in
      guard let self else { return }
      self.window?.setFrame(plan.frame, display: true)
      self.ignite(false)
      self.onShellChanged?()
    })
  }
  private func keyPutBack(_ window: NSWindow) {
    shellSession.compactWhileDetached = false
    guard let home = attachedHome() else { return }
    if window.frame.size != home.size || layout?.frame.size != home.size {
      // Audit A-3: the put back commits the attached layout (profile, zoom, drag strip) at once, at the attached size
      // where the cockpit is now (top edge kept); only the window frame then flies home.
      let start = CGRect(x: window.frame.minX, y: window.frame.maxY - home.height, width: home.width, height: home.height)
      shellSession.detached = false; applyLayout(); shellSession.detached = true
      window.setFrame(start, display: true)
      shellSession.remember(start.origin, arrangement: arrangement)
      updateAppearance(appearance)
    }
    guard !appearance.reduceMotion else { latch(); return }
    ignite(true); flying = true
    let p0 = window.frame.origin, d = home.origin, zone = CockpitLaunchRackTiming.catchZone
    let distance = hypot(p0.x - d.x, p0.y - d.y)
    if distance < zone {
      extendRack()
      runMotion(max(0.01, 0.36 * Double(distance / zone)), step: { [weak self] t in
        let e = 1 - pow(1 - t, 3)
        self?.window?.setFrameOrigin(CGPoint(x: p0.x + (d.x - p0.x) * e, y: p0.y + (d.y - p0.y) * e))
      }, done: { [weak self] in self?.window?.setFrame(home, display: true); self?.whenRackSettled { self?.latch() } })
      return
    }
    // One continuous flight whose last part runs straight up the rack: the control point sits under home. The rack
    // starts to extend once the cockpit is inside the catch zone.
    let c = CGPoint(x: d.x, y: min(d.y - zone, p0.y))
    let length = hypot(c.x - p0.x, c.y - p0.y) + hypot(d.x - c.x, d.y - c.y)
    runMotion(CockpitLaunchRackTiming.flight(length: length), step: { [weak self] t in
      guard let self else { return }
      let k = 1 - pow(1 - t, 3), u = 1 - k
      let x = u * u * p0.x + 2 * u * k * c.x + k * k * d.x, y = u * u * p0.y + 2 * u * k * c.y + k * k * d.y
      self.window?.setFrameOrigin(CGPoint(x: x, y: min(d.y, y)))
      if hypot(x - d.x, min(d.y, y) - d.y) < zone, self.rackTarget != 1 { self.extendRack() }
    }, done: { [weak self] in
      guard let self else { return }
      self.window?.setFrame(home, display: true)
      self.extendRack()
      self.whenRackSettled { [weak self] in self?.latch() }
    })
  }
  /// The cockpit is caught: attached again under the icon, nozzles out.
  private func latch() {
    flying = false
    shellSession.detached = false; shellSession.compactWhileDetached = false
    rackExtension = rackIcon() != nil ? 1 : 0; rackTarget = rackExtension
    ignite(false)
    guard placement() != nil else { return }
    applyLayout()
    updateAppearance(appearance)
    onShellChanged?()
  }
  private func toggleAttachment() { setAttached(shellSession.detached) }
  /// D88: the app's own right-click menu: one item that detaches or puts back. No Reload.
  func contextMenu() -> NSMenu? {
    guard window != nil, !ending, closeTask == nil else { return nil }
    let zh = appearance.locale == .zhCN, detached = shellSession.detached
    // The host's menu (Settings, Reset Position, size, Help) with the detach / put-back item on top.
    let menu = contextMenuProvider?() ?? NSMenu(); menu.autoenablesItems = false
    let item = NSMenuItem(title: detached ? (zh ? "放回" : "Put back") : (zh ? "分离" : "Detach"),
                          action: CockpitMenuTarget.action, keyEquivalent: "")
    item.target = menuTarget; item.identifier = NSUserInterfaceItemIdentifier("cockpit.attachment")
    if !menu.items.isEmpty { menu.insertItem(.separator(), at: 0) }
    menu.insertItem(item, at: 0)
    return menu
  }
  /// D88: the detach / put-back key on screen, once the open has settled and no drag is moving the window.
  public var attachmentHintAnchor: CockpitAttachmentHintAnchor? {
    guard let window, shown, !ending, !entering, motion == nil, closeTask == nil, dragStart == nil, window.isVisible,
          window.alphaValue > 0, let layout, let content = window.contentView else { return nil }
    let height = layout.rootHeight + 34, size = Self.attachmentKeySize
    // The page lays out in CSS px and renders at `layout.scale`, top-anchored in the whole-point window.
    let local = layout.windowRect(page: CGRect(x: Self.attachmentKeyX, y: height - size - 2, width: size, height: size))
    let frame = window.convertToScreen(content.convert(local, to: nil))
    guard !frame.isNull, !frame.isInfinite, frame.width > 0, frame.height > 0,
          [frame.minX, frame.minY, frame.width, frame.height].allSatisfy(\.isFinite) else { return nil }
    return .init(attached: !shellSession.detached, frame: frame, sharing: window.sharingType, collection: window.collectionBehavior)
  }
  /// CKP-SHELL-33 (D186): only an attached open from the icon, with motion and a real icon to hang the rack from,
  /// extends the rack first.
  nonisolated static func opensRackFirst(_ entrance: CockpitEntrance, reduceMotion: Bool, detached: Bool, icon: CGRect?) -> Bool {
    entrance == .fromIcon && !reduceMotion && !detached && icon != nil
  }
  func titleDrag(_ phase: CockpitTitleDrag.Phase, point: CGPoint) {
    guard let window else { return }
    switch phase {
    case .began:
      // A drag during the entrance or a landing starts from the settled frame.
      finishEntrance()
      if motion != nil { return }
      dragStart = (point, window.frame, shellSession.detached)
      dragArmed = false; dragCatching = false
    case .moved:
      guard let start = dragStart else { return }
      let dx = point.x - start.point.x, dy = point.y - start.point.y
      guard shellSession.detached || hypot(dx, dy) * window.backingScaleFactor > 12 else { return }
      let newlyDetached = !shellSession.detached
      shellSession.detached = true
      if newlyDetached {
        // Tear-off (CKP-SHELL-33): the rack retracts straight up into the icon.
        shellSession.compactWhileDetached = false
        updateAppearance(appearance); retractRack()
      }
      // Build 14c (G3-79): the window stays inside the display under the pointer, so it can go to any display.
      window.setFrame(dragFrame(start: start.frame, from: start.point, to: point), display: true)
      // D178/D187: no snap guide. Inside the catch zone, once the drag has been outside it, the rack extends to meet the
      // cockpit and the nozzles light; leaving the zone retracts it and puts them out.
      let inZone = inCatchZone(window.frame)
      if !inZone { dragArmed = true }
      let catching = inZone && dragArmed
      if catching != dragCatching {
        dragCatching = catching
        if catching { extendRack(); ignite(true) } else { retractRack(); ignite(false) }
      }
      refreshRack()
    case .ended:
      restorePageFocus()
      guard dragStart != nil else { return }; dragStart = nil
      guard shellSession.detached else { return }
      if inCatchZone(window.frame), let home = attachedHome() {
        // The catch zone acts on the release only: straight home along the rack, then latched.
        dragCatching = false
        guard !appearance.reduceMotion else { latch(); return }
        let start = window.frame
        extendRack(); ignite(true); flying = true
        runMotion(CockpitLaunchRackTiming.rideHome, step: { [weak self] t in
          let e = 1 - pow(1 - t, 3)
          let frame = Self.lerp(start, home, e)
          self?.window?.setFrameOrigin(CGPoint(x: frame.minX, y: min(home.minY, frame.minY)))
        }, done: { [weak self] in
          self?.window?.setFrame(home, display: true)
          self?.whenRackSettled { [weak self] in self?.latch() }
        })
      } else {
        if dragCatching { dragCatching = false; retractRack(); ignite(false) }
        // macrev2-845-1: a drop on a shorter display refits there; the drag kept the old size, which can overhang it.
        fitToDropDisplay(window); onShellChanged?()
      }
    case .cancelled: cancelDrag(); restorePageFocus()
    }
  }
  /// D181: within 40 pt of the attached place (its top-left corner), measured on the release.
  func inCatchZone(_ frame: CGRect) -> Bool {
    guard let home = attachedHome() else { return false }
    return hypot(frame.minX - home.minX, frame.maxY - home.maxY) <= CockpitLaunchRackTiming.catchZone
  }
  /// Audit A-4: the strip takes first responder on mouse-down; once the drag ends or is cancelled the page gets the
  /// keyboard back (Esc and the page's keys), as the field panel does after its own drag.
  private func restorePageFocus() {
    guard let window, let web, let drag = dragRegion, window.firstResponder === drag else { return }
    window.makeFirstResponder(web)
  }
  /// A drag's frame: on the display under the pointer (the test placement's usable frame under the SPI seam).
  func dragFrame(start: CGRect, from: CGPoint, to point: CGPoint) -> CGRect {
    #if MODELPLAN_TEST_ONLY_SPI
    if let verificationPlacement {
      return CockpitScreenSelection.dragFrame(start: start, from: from, to: point, screens: [], fallback: verificationPlacement.usable)
    }
    #endif
    return CockpitScreenSelection.dragFrame(start: start, from: from, to: point, screens: screens(), fallback: environment()?.0)
  }
  private func cancelDrag() {
    dragRegion?.resetDragState()
    guard let start = dragStart else { return }; dragStart = nil
    let changed = shellSession.detached != start.detached
    shellSession.detached = start.detached; window?.setFrame(start.frame, display: true)
    dragCatching = false; ignite(false)
    if start.detached { retractRack() } else if rackIcon() != nil { extendRack() }
    updateAppearance(appearance)
    if changed { onShellChanged?() }
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
        self?.localPress(in: event.window, at: point, eventType: event.type)
      }
      return event
    }
  }
  /// A press in one of this app's windows (the local monitor). D88: a press on a hint or help panel over the cockpit,
  /// or on the enlarged field it opened, does not close it.
  func localPress(in target: NSWindow?, at point: CGPoint, eventType: NSEvent.EventType) {
    if let id = target?.identifier, id == Self.helpOverlayIdentifier || id == Self.fieldWindowIdentifier { return }
    outsidePress(point, eventType: eventType)
  }
  func outsidePress(_ point: CGPoint,eventType:NSEvent.EventType) {
    guard !shellSession.detached, let window, !window.frame.contains(point) else { return }
    // The owned tray completes one toggle on mouse-up. Its mouse-down is not
    // a competing outside dismissal, including with Reduce Motion/long holds.
    let isTray=anchor()?.contains(point) == true
    #if MODELPLAN_TEST_ONLY_SPI
    verificationOutsidePress?(eventType,isTray)
    #endif
    // D204 (G3-94): nor is the ignition's. It closed the cockpit here and its mouse-up action opened it again.
    if eventType == .leftMouseDown, isTray || ignitionFrame?()?.contains(point) == true { return }
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
    // Audit A-2: the invalidation drops a display still queued behind an in-flight call. A re-open during the fade
    // confirms visibility on the same page, so it must ask for fresh data then, as a hidden page does.
    refreshAfterHiddenDisplay = refreshAfterHiddenDisplay || bridge.hasPendingDisplay
    orderedDelivery.invalidate(); appearanceGate.deferUntilVisible(); appearanceWatchdog.cancel()
    visibilityFence.invalidate(); visibilityTimeout?.cancel(); visibilityTimeout = nil
    receiptWatchdog.cancel(); renderWatchdog.cancel()
    // CKP-SHELL-33 (D186/D188): an attached cockpit opened from the icon reverses the open: it goes up under the menu
    // bar while the hidden rack shortens behind it, then the rack's visible part retracts into the icon.
    let reverse = openedFromIcon && !appearance.reduceMotion && !shellSession.detached && rackIcon() != nil && window != nil
    let reverseDuration = CockpitLaunchRackTiming.cockpitOpen + CockpitLaunchRackTiming.rackOpen
    #if MODELPLAN_TEST_ONLY_SPI
    verificationCloseStarted?(appearance.reduceMotion ? 0 : reverse ? reverseDuration : 0.12)
    verificationEntrance?(appearance.reduceMotion ? "instant" : reverse ? "rack" : "fade")
    #endif
    guard !appearance.reduceMotion, let window else { discard(); return }
    finishEntrance()
    let duration = reverse ? reverseDuration : 0.12
    if reverse, let home = layout?.frame {
      rackHidesInHome = true
      runMotion(CockpitLaunchRackTiming.cockpitOpen, step: { [weak self] t in
        guard let self, let window = self.window else { return }
        window.alphaValue = 1 - min(1, t * 1.2)
        window.setFrame(home.offsetBy(dx: 0, dy: CockpitLaunchRackTiming.openRise * t * t * t), display: true)
        self.rackExtension = 1 - 2.0 / 3 * t; self.rackTarget = self.rackExtension
      }, done: { [weak self] in
        guard let self else { return }
        self.window?.alphaValue = 0
        self.runMotion(CockpitLaunchRackTiming.rackOpen, step: { [weak self] t in
          guard let self else { return }
          self.rackExtension = (1 - t) / 3; self.rackTarget = self.rackExtension
        }, done: { [weak self] in self?.rackExtension = 0; self?.rackTarget = 0; self?.refreshRack() })
      })
    } else {
      NSAnimationContext.runAnimationGroup { context in
        context.duration = duration
        window.animator().alphaValue = 0
      }
    }
    closeTask = Task { @MainActor [weak self] in
      // The rack's last frame lands on the driver's next tick; a reversed close waits one more beat for it.
      do { try await Task.sleep(for: .milliseconds(Int(duration * 1_000) + (reverse ? 40 : 0))) } catch { return }
      self?.discard()
    }
  }
  // MARK: Launch rack (CKP-SHELL-33)

  /// One 60 Hz driver moves the rack toward its target at the full-travel pace and runs the current motion (open, close,
  /// landing, flight); it stops itself when both are done.
  private func runMotion(_ duration: TimeInterval, step: @escaping @MainActor (CGFloat) -> Void, done: @escaping @MainActor () -> Void) {
    motion = Motion(start: CACurrentMediaTime(), duration: max(0.001, duration), step: step, done: done)
    step(0); startRackTimer()
  }
  private func startRackTimer() {
    refreshRack()
    guard rackTimer == nil else { return }
    rackClock = CACurrentMediaTime()
    let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.rackTick() } }
    RunLoop.main.add(timer, forMode: .common)
    rackTimer = timer
  }
  private func rackTick() {
    let now = CACurrentMediaTime(), dt = now - rackClock
    rackClock = now
    if rackExtension != rackTarget {
      let step = CGFloat(dt / rackPace)
      rackExtension = rackExtension < rackTarget ? min(rackTarget, rackExtension + step) : max(rackTarget, rackExtension - step)
    }
    if let current = motion {
      let t = CGFloat(min(1, (now - current.start) / current.duration))
      current.step(t)
      if t >= 1, motion?.start == current.start { motion = nil; current.done() }
    }
    refreshRack()
    if rackExtension == rackTarget, !rackSettledWaiters.isEmpty {
      let waiters = rackSettledWaiters; rackSettledWaiters = []
      waiters.forEach { $0() }
    }
    if motion == nil, rackExtension == rackTarget, rackSettledWaiters.isEmpty { rackTimer?.invalidate(); rackTimer = nil }
  }
  private func extendRack() {
    guard rackIcon() != nil else { rackTarget = 0; return }
    rackPace = CockpitLaunchRackTiming.fullTravel; rackTarget = 1
    if appearance.reduceMotion { rackExtension = 1 }
    startRackTimer()
  }
  private func retractRack() {
    rackPace = CockpitLaunchRackTiming.fullTravel; rackTarget = 0
    if appearance.reduceMotion { rackExtension = 0 }
    startRackTimer()
  }
  private func whenRackSettled(_ body: @escaping @MainActor () -> Void) {
    if rackExtension == rackTarget { body(); return }
    rackSettledWaiters.append(body); startRackTimer()
  }
  /// A put back is flying (key, menu or a drag released in the catch zone) and latches at its end.
  private var flying = false
  /// Ends a running entrance, landing or flight at once, in its final state (a drag, a close or another key press).
  private func finishEntrance() {
    guard entering || motion != nil || flying || !rackSettledWaiters.isEmpty else { return }
    motion = nil; rackSettledWaiters = []
    if flying { flying = false; latch(); return }
    if entering {
      entering = false; rackHidesInHome = false
      window?.alphaValue = 1
      rackExtension = rackIcon() != nil && !shellSession.detached ? 1 : 0; rackTarget = rackExtension
      if !shellSession.detached, let frame = layout?.frame { window?.setFrame(frame, display: true) }
      refreshRack(); return
    }
    // A key detach's landing: it stays where it is now (a drag or the user may have moved it), rack in, nozzles out.
    rackExtension = 0; rackTarget = 0; ignite(false)
    if let window { shellSession.remember(window.frame.origin, arrangement: arrangement) }
    refreshRack()
  }
  private func stopRack() {
    motion = nil; rackSettledWaiters = []; flying = false
    rackTimer?.invalidate(); rackTimer = nil
    ignite(false)
    rack.close()
  }
  /// Places and draws the rack for the current state: hidden inside the cockpit below its shoulder line (the attached
  /// frame while the open or close runs), so nothing of it shows through the window (D175).
  private func refreshRack() {
    guard let window, !ending else { return }
    var hidden: CGRect?
    if let layout {
      let frame = rackHidesInHome ? layout.frame : window.frame
      let drop = CockpitShellLayout.shoulderDrop(layout.profile) * layout.scale
      hidden = CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: max(0, frame.height - drop))
    }
    // A prewarmed (never shown) page has no rack on screen.
    rack.update(icon: rackExtension > 0 && shown ? rackIcon() : nil, cockpit: window, hidden: hidden, extended: rackExtension,
                moving: rackExtension != rackTarget || motion != nil)
  }
  /// The nozzles: the page's amber glow on every base bell (D178/D186). Not under Reduce Motion.
  private func ignite(_ on: Bool) {
    let value = on && !appearance.reduceMotion
    guard value != ignited else { return }
    ignited = value
    #if MODELPLAN_TEST_ONLY_SPI
    verificationIgnition?(value)
    #endif
    guard bridge.ready, !bridge.blocked, !ending, let raw = try? bridge.setIgnition(value) else { return }
    // A page that cannot paint the glow keeps working; the glow is decoration.
    send(raw, onRejected: { true })
  }
  static func lerp(_ a: CGRect, _ b: CGRect, _ t: CGFloat) -> CGRect {
    CGRect(x: a.minX + (b.minX - a.minX) * t, y: a.minY + (b.minY - a.minY) * t,
           width: a.width + (b.width - a.width) * t, height: a.height + (b.height - a.height) * t)
  }

  /// `error` names what a local step threw (its case and, for encoding, the field path), never its text.
  private func fail(_ failure: CockpitWindowFailure = .localEncoding, error: Error? = nil,
                    at site: StaticString = #function, line: UInt = #line) {
    guard !ending else { return }
    let age = openedAt.map { Int((ProcessInfo.processInfo.systemUptime - $0) * 1_000) }
    let detail: String = error.map { "error=\(Self.errorDetail($0)) " } ?? ""
    CockpitFailureLog.record("page-failure failure=\(failure.rawValue) at=\(site):\(line) ageMs=\(age.map(String.init) ?? "none") "
      + detail + "ready=\(bridge.ready) visible=\(visibilityFence.isConfirmedVisible) rendered=\(freshnessHasRendered) "
      + "displayPending=\(bridge.hasPendingDisplay) occluded=\(lastVisibility?.occluded.description ?? "unknown") reject=\(lastRejectCode)")
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
    stopRack()
    if shellSession.detached, let window { shellSession.remember(window.frame.origin, arrangement: arrangement) }
    if let outsideMonitor { NSEvent.removeMonitor(outsideMonitor) }; outsideMonitor = nil
    if let localMonitor { NSEvent.removeMonitor(localMonitor) }; localMonitor = nil
    dragRegion?.event = nil; dragRegion = nil
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
/// The drag area of the expanded cockpit's top strip. Hovering it shows an open hand (closed while
/// dragging). D227 (owner 2026-11-12, G3-99): it draws nothing, no grip dots, on hover or while dragging.
@MainActor final class CockpitTitleDrag: NSView {
  enum Phase { case began, moved, ended, cancelled }
  var event: ((Phase, CGPoint) -> Void)?
  /// Right-click on the strip reaches the web view's own context menu.
  var contextMenu: ((NSEvent) -> Void)?
  private(set) var isHovered = false
  private(set) var isDragging = false {
    didSet { if isDragging != oldValue { window?.invalidateCursorRects(for: self) } }
  }
  /// What the pointer shows over the strip: an open hand, a closed hand while dragging.
  func resetDragState() { isDragging = false }
  var currentCursor: NSCursor { isDragging ? .closedHand : .openHand }
  override var acceptsFirstResponder: Bool { true }
  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    trackingAreas.forEach(removeTrackingArea)
    addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))
  }
  override func resetCursorRects() { addCursorRect(bounds, cursor: currentCursor) }
  override func mouseEntered(with event: NSEvent) { isHovered = true }
  override func mouseExited(with event: NSEvent) { isHovered = false }
  private func point(_ event: NSEvent) -> CGPoint { window?.convertPoint(toScreen: event.locationInWindow) ?? .zero }
  override func mouseDown(with event: NSEvent) {
    window?.makeFirstResponder(self); isDragging = true; currentCursor.set(); self.event?(.began, point(event))
  }
  override func mouseDragged(with event: NSEvent) { self.event?(.moved, point(event)) }
  override func mouseUp(with event: NSEvent) {
    isDragging = false; currentCursor.set(); self.event?(.ended, point(event))
  }
  override func rightMouseDown(with event: NSEvent) { contextMenu?(event) }
  override func cancelOperation(_ sender: Any?) { isDragging = false; event?(.cancelled, .zero) }
  override func keyDown(with event: NSEvent) {
    if event.keyCode == 53 { isDragging = false; self.event?(.cancelled, .zero) } else { super.keyDown(with: event) }
  }
}
