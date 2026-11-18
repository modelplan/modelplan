// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanWire
import WebKit
import QuartzCore

/// Why a page ended. Recovery contract (G3-96, G3-116): only these end a page. A late receipt, a refused update, a
/// JavaScript exception or a full delivery queue never does; the page then keeps what it shows, the reading is marked
/// delayed and the page is probed (`CockpitPageHealth`). `recovery` says what each asks of the host.
public enum CockpitWindowFailure: String {
  /// The page's bridge is gone (it unloaded itself, or a call found no bridge).
  case pageAPIUnavailable
  /// The page refused its load message.
  case messageRejected
  /// The load call itself failed (the page module did not import).
  case javascriptFailed
  case navigationFailed, provisionalNavigationFailed, contentTerminated
  /// A privacy clear was not acknowledged in time: the page is disposed instead.
  case clearDeadline
  /// A privacy clear was refused, or could not be built: the page is disposed instead.
  case clearRejected
  /// The load message could not be built.
  case localEncoding
  /// G3-95: the bundled cockpit could not serve a file it admitted earlier (removed or changed since). A reinstall problem.
  case bundleResource
  /// The page speaks another contract version than this host.
  case unsupportedPageContract
  /// 30 active seconds without any answer, with at least two unanswered probes (`CockpitPageHealth`).
  case unresponsive
}

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

/// Native-shell spec item 2: the system edges the cockpit reacts to, from the app's single `SystemEvents` source.
public enum CockpitSystemSignal: Equatable, Sendable {
  case wake, unlock, clockChanged
  /// Every display-parameter notification (relayout at once).
  case displaysChanged
  /// 750 ms after the last one (relayout on settled frames).
  case displaysSettled
}
/// Subscribes a handler and returns its cancel. CockpitWeb takes a closure, not a `ModelPlanShell` dependency.
public typealias CockpitSystemSignalSource = @MainActor (@escaping @MainActor (CockpitSystemSignal) -> Void) -> (() -> Void)

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
  /// G3-102 (build 14e): a detached cockpit is an ordinary window, so other apps can cover it; only the attached
  /// one (under the menu-bar icon, over the widget, D49) floats.
  public static func level(detached: Bool) -> NSWindow.Level { detached ? .normal : panelLevel }
  /// Native-shell spec item 3 (Maccy `FloatingPanel`, CodexBar `SettingsWindowStageBehavior`, Pulse panel): the attached
  /// cockpit opens on the active Space, over another app's full-screen Space, and stays out of Cmd-` and the window
  /// cycle. A detached one is an ordinary window (#908): the default behaviour. Never `.canJoinAllSpaces`, which
  /// excludes `.moveToActiveSpace`; always assigned whole, so a stale mask cannot survive.
  public static func collectionBehavior(detached: Bool) -> NSWindow.CollectionBehavior {
    detached ? [] : [.moveToActiveSpace, .fullScreenAuxiliary, .ignoresCycle]
  }
  /// Windows the open cockpit brings up (the enlarged field, the Help overlay) sit above it.
  public static let aboveCockpitLevel = NSWindow.Level(rawValue: panelLevel.rawValue + 1)
  /// G3-108 (owner, build 14e): the shutter reads as the porthole closing or opening, 250 ms, the same time as the
  /// page's own porthole motion (cockpit.css `cockpit-shutter`); Reduce Motion is instant (CKP-MOT-03).
  public static let shutterDuration: TimeInterval = 0.25
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
  /// Build 14c (G3-79): the screen point an open came from (the widget's ignition click). Only a detached open uses it;
  /// an attached cockpit always belongs to the menu bar icon's display (G3-128).
  private let openPoint: () -> CGPoint?
  /// The displays placement and drags use; tests replace it with a fixed arrangement.
  var screens: @MainActor () -> [CockpitScreen] = { CockpitScreenSelection.system() }
  /// D204 (G3-94): the widget ignition's frame on screen. A press on it is the ignition's own toggle, decided on
  /// mouse-up; its mouse-down is not an outside click that closes the attached cockpit first.
  public var ignitionFrame: (@MainActor () -> CGRect?)?
  /// D204: the occlusion state counts only once the window server has reported it since the last order-front;
  /// until then a freshly ordered-in window is not mistaken for a covered one.
  private var occlusionReported = false
  private var layout: CockpitShellLayout?
  private var scope = "all"
  private var outsideMonitor: Any?, localMonitor: Any?, switchMonitor: Any?
  private var closeTask: Task<Void, Never>?
  /// Walkthrough 11-17: a user put back keeps an active app active across the regular-to-accessory flip it causes.
  private var putBackActivation = CockpitPutBackActivation()
  /// G3-108: true while the shutter moves the window's bottom edge; the content then keeps the live window size, so
  /// nothing is rescaled (the D88 grow and shrink keep the layout size and scale with the frame).
  private(set) var shutterMoving = false
  /// G3-108: a later toggle's motion owns `shutterMoving`; an earlier motion's completion leaves it alone.
  private var shutterGeneration = 0
  /// G3-108: a detached close lowers the top edge once the page has closed its porthole.
  private var shutterTask: Task<Void, Never>? {
    didSet { if shutterTask == nil { (window as? CockpitPanel)?.pendingTopDrop = 0 } }
  }
  var shutterPending: Bool { shutterTask != nil }
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
  /// Spec item 2: the app's one wake/unlock/clock/display source; nil keeps this page's own observers.
  private let systemSignals: CockpitSystemSignalSource?
  private var cancelSystemSignals: (() -> Void)?
  /// Spec item 1: the one decision point for closing the attached cockpit. Armed only while attached and shown.
  public private(set) lazy var dismissal = DismissalFunnel(now: { [weak self] in self?.dismissalNow() ?? 0 }, live: { [weak self] in
    guard let self else { return [] }
    var live: DismissalSuppression = []
    if self.dragStart != nil { live.insert(.drag) }
    if self.entering { live.insert(.opening) }
    if NSApp.modalWindow != nil || self.window?.attachedSheet != nil { live.insert(.modal) }
    return live
  }, close: { [weak self] reason in
    guard let self else { return }
    #if MODELPLAN_TEST_ONLY_SPI
    self.verificationCloseOrigin?(reason == .outsidePress ? "outside" : reason.rawValue)
    #endif
    self.closeAnimated()
  })
  private var menuTrackingDepth = 0
  private var menuTrackingHold: DismissalHold?
  /// Spec item 4: the detached window appeared, went or was minimised. `true` when a user action caused it (the app
  /// may then be activated). The host turns this into the Dock icon / Cmd-Tab presence.
  public var onPresenceChanged: ((_ userInitiated: Bool) -> Void)?
  /// Spec item 4: the window counts for the Dock icon only while detached.
  public var detachedPresence: (visible: Bool, miniaturized: Bool) {
    guard let window, shellSession.detached, !ending, closeTask == nil else { return (false, false) }
    return (window.isVisible && !window.isMiniaturized, window.isMiniaturized)
  }
  /// Spec item 1: a suppression the host holds (a widget carry, an activation-policy flip).
  public func holdDismissal(_ suppression: DismissalSuppression) -> DismissalHold { dismissal.hold(suppression) }
  public func suppressDismissal(_ suppression: DismissalSuppression, forMilliseconds duration: UInt64) {
    dismissal.hold(suppression, forMilliseconds: duration)
  }
  /// Test seam: the funnel's clock in milliseconds (default: system uptime).
  var dismissalClock: (() -> UInt64)?
  private func dismissalNow() -> UInt64 {
    if let dismissalClock { return dismissalClock() }
    #if MODELPLAN_TEST_ONLY_SPI
    if let clock = verificationNoWindowClock { return clock() }
    #endif
    return DismissalFunnel.uptimeMilliseconds()
  }
  /// Spec items 1 and 3: level, collection behaviour and the dismissal arming follow the attachment together, so
  /// they never diverge (the #908 class of bug: one state split over several writes).
  private func applyPresentationTraits() {
    let detached = shellSession.detached
    if let window {
      let level = Self.level(detached: detached), behavior = Self.collectionBehavior(detached: detached)
      if window.level != level { window.level = level }
      if window.collectionBehavior != behavior { window.collectionBehavior = behavior }
    }
    if detached || !shown || ending || closeTask != nil { if dismissal.isArmed { dismissal.disarm() } }
    else if !dismissal.isArmed { dismissal.rearm() }
  }
  private var freshnessHasRendered = false
  private var refreshAfterHiddenDisplay = false
  private var appearanceGate = CockpitAppearanceGate()
  private var pendingFreshnessReason: CockpitDeadlineReason?
  private struct OutboundMessage { let code: String, raw: String }
  private lazy var orderedDelivery: CockpitOrderedDelivery<OutboundMessage> = CockpitOrderedDelivery<OutboundMessage>(
    answered: { [weak self] in self?.pageAnswered() }) { [weak self] message, complete in
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
  private var visibilityTimeout: CockpitTimerHandle?
  private var visibilityFence = CockpitVisibilityFence()
  private static func wallClockMilliseconds() -> UInt64 {
    let value = Date().timeIntervalSince1970 * 1_000
    guard value.isFinite, value > 0 else { return 0 }
    return UInt64(min(value.rounded(.down), 8_640_000_000_000_000))
  }
  /// A local step could not build an update (a stale ticket, a limit, an encoding error). The page keeps what it shows
  /// and the next update tries again; nothing here can prove the page dead (recovery contract).
  private func degrade(_ site: String, error: Error) {
    CockpitFailureLog.record("page-degraded at=\(site) error=\(Self.errorDetail(error)) ready=\(bridge.ready) "
      + "visible=\(visibilityFence.isConfirmedVisible) rendered=\(freshnessHasRendered) displayPending=\(bridge.hasPendingDisplay)")
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
    onExhausted: { CockpitFailureLog.record("deadline-throttled immediate=\(CockpitDeadlineDriver.maximumImmediateAdvances)") },
    tick: { [weak self] reason in self?.sendFreshnessTick(reason) })
  // Recovery contract: a receipt that is late is a slow page, not a dead one. The reading is marked delayed (the last
  // rendered data stays) and the page is probed; only `CockpitPageHealth` can end it as unresponsive.
  private lazy var receiptWatchdog = CockpitDeadlineReceiptWatchdog(
    arm: { [weak self] delay, fire in self?.armDeadline(delay, fire) ?? {} }, timedOut: { [weak self] id in
      guard let self, !self.ending, self.bridge.awaitsDeadlineReceipt(id) else { return }
      self.pageLate("deadlineReceipt")
    })
  /// macrevb-981-1: measured from the oldest display not yet rendered. A replacement does not restart it (only a
  /// rendered receipt, a hide or a refusal ends it), so a stream of replies cannot keep a silent page unprobed.
  private lazy var renderWatchdog = CockpitDeadlineReceiptWatchdog(
    arm: { [weak self] delay, fire in self?.armDeadline(delay, fire) ?? {} }, timedOut: { [weak self] _ in
      guard let self, !self.ending, let current = self.bridge.currentDisplayRequest,
            self.bridge.awaitsDisplayReceipt(current) else { return }
      self.pageLate("renderReceipt")
    })
  /// Replaces #959's progress extensions, their four-extension ceiling and its one-shot retry: a deferred appearance
  /// waits one period for the display receipt, then goes out anyway (correlated when the receipt has cleared, else
  /// behind the pending display without a deadline correlation). It never fails the page.
  private lazy var appearanceWatchdog: CockpitDeadlineReceiptWatchdog = CockpitDeadlineReceiptWatchdog(
    arm: { [weak self] delay, fire in self?.armDeadline(delay, fire) ?? {} }, timedOut: { [weak self] _ in
      guard let self, !self.ending, self.visibilityFence.isConfirmedVisible, self.appearanceGate.isDeferred,
            self.bridge.ready, !self.bridge.blocked else { return }
      if self.appearanceGate.retry(visible: true, displayPending: self.bridge.hasPendingDisplay) {
        CockpitFailureLog.record("page-resync appearance retry after wait")
        self.publishAppearance()
      } else {
        CockpitFailureLog.record("page-resync appearance applied behind pending display")
        self.publishAppearance(behindPendingDisplay: true)
      }
    })
  private func cancelAppearanceWait() { appearanceWatchdog.cancel() }
  private func watchDeferredAppearance() {
    guard visibilityFence.isConfirmedVisible, appearanceGate.isDeferred, appearanceWatchdog.currentID == nil else { return }
    appearanceWatchdog.wait(for: UUID())
  }
  // MARK: Recovery contract: page responsiveness (CockpitPageHealth)
  private var health = CockpitPageHealth()
  private var probeTimer: (() -> Void)?
  private var probeSerial: UInt64 = 0
  private var bootstrapCheck: (() -> Void)?
  /// The correlated probe (#990): reads this page's bridge state in the page's own world; a replaced page answers
  /// "mismatch" and a page whose JavaScript thread is stuck never answers.
  var probeScript: String { bridge.probeScript }
  private func monotonicNow() -> UInt64 {
    #if MODELPLAN_TEST_ONLY_SPI
    if let clock = verificationMonotonicClock { return clock() }
    #endif
    return CockpitMonotonicClock.nowMs()
  }
  /// Probe and bootstrap timers. A no-window test that injects no health arm runs without them.
  private func armHealth(_ delay: UInt64, _ fire: @escaping @MainActor () -> Void) -> () -> Void {
    #if MODELPLAN_TEST_ONLY_SPI
    if let arm = verificationHealthArm { return arm(delay, fire) }
    if verificationNoWindowDelivery != nil { return {} }
    #endif
    return Self.armTimer(delay, fire)
  }
  /// Something waited past its receipt window: the reading is delayed (the last rendered data stays) and the page is
  /// probed until it answers or proves unresponsive. Every late path comes here (macrev2-981-6).
  private func pageLate(_ cause: String) {
    guard !ending else { return }
    setReadingDelayed(true, cause: cause)
    let now = monotonicNow()
    if health.expect(at: now) {
      CockpitFailureLog.record("page-late cause=\(cause) ready=\(bridge.ready) displayPending=\(bridge.hasPendingDisplay) "
        + "outstanding=\(orderedDelivery.outstanding) reject=\(lastRejectCode)")
    }
    startProbing()
  }
  /// Any answer from this page: a receipt, a completed call or a probe reply.
  private func pageAnswered() {
    guard !ending else { return }
    if health.isWaiting {
      CockpitFailureLog.record("page-answered waitedMs=\(health.waited(at: monotonicNow())) unanswered=\(health.unansweredProbes)")
    }
    health.answered(); stopProbing()
    // macrevb-998-2: an answer proves the page alive, but a shown page that is still not ready stays watched; nothing
    // else would notice if it stopped answering before its ready receipt (no query ticket, no receipt watchdogs).
    if shown, !bridge.ready, !health.paused, bootstrapCheck == nil { armBootstrapCheck() }
  }
  private func startProbing() {
    guard !ending, probeTimer == nil, health.isWaiting else { return }
    sendProbe()
  }
  private func sendProbe() {
    probeSerial &+= 1
    let token = probeSerial
    // The timeout is armed first: a probe that answers at once cancels it through `pageAnswered`.
    probeTimer = armHealth(CockpitPageHealth.probeTimeoutMs) { [weak self] in
      guard let self, !self.ending, self.probeSerial == token else { return }
      self.probeTimer = nil
      let now = self.monotonicNow()
      self.health.probeUnanswered()
      if self.health.verdict(at: now) == .unresponsive {
        CockpitFailureLog.record("page-unresponsive waitedMs=\(self.health.waited(at: now)) unanswered=\(self.health.unansweredProbes)")
        self.fail(.unresponsive)
        return
      }
      if self.health.isWaiting { self.sendProbe() }
    }
    probePage { [weak self] reply in
      guard let self, !self.ending, self.probeSerial == token else { return }
      switch CockpitRecoveryPolicy.probeOutcome(reply, pageReady: self.bridge.ready) {
      case .answered: self.pageAnswered()
      case .pageGone: self.fail(.pageAPIUnavailable)
      case .unanswered: break // counted when its timeout passes
      }
    }
  }
  private func stopProbing() { probeSerial &+= 1; probeTimer?(); probeTimer = nil }
  private func pauseHealth() { health.pause(); stopProbing(); bootstrapCheck?(); bootstrapCheck = nil }
  private func probePage(_ reply: @escaping @MainActor (String?) -> Void) {
    #if MODELPLAN_TEST_ONLY_SPI
    if let probe = verificationProbe { probe(reply); return }
    #endif
    guard let web else { return }
    web.callAsyncJavaScript(probeScript, arguments: [:], in: nil, in: .page) { result in
      Task { @MainActor in
        if case .success(let value) = result { reply(value as? String) } else { reply(nil) }
      }
    }
  }
  /// A shown page that has not reported ready after the receipt window is probed like any late page.
  private func armBootstrapCheck() {
    bootstrapCheck?()
    bootstrapCheck = armHealth(CockpitPageHealth.delayedAfterMs) { [weak self] in
      guard let self, !self.ending else { return }
      self.bootstrapCheck = nil
      if !self.bridge.ready { self.pageLate("bootstrap") }
    }
  }
  /// Recovery contract: from 2 s without a receipt the reading is delayed; the last rendered data stays on screen.
  /// The page shows it with step 2 of the recovery design; the host tracks it here.
  public private(set) var readingDelayed = false
  public var onReadingDelayed: ((Bool) -> Void)?
  private func setReadingDelayed(_ value: Bool, cause: String) {
    guard readingDelayed != value else { return }
    readingDelayed = value
    CockpitFailureLog.record("reading-delayed=\(value) cause=\(cause)")
    onReadingDelayed?(value)
  }
  /// Page-side code path of the last rejected host message (bridge.ts `lastReject`).
  private var lastRejectCode = "none"
  /// The kind of the last refusal the page survived (recovery step 2b); step 4 reads it for data retries.
  public private(set) var lastRejectionKind: CockpitRecoveryPolicy.RejectionKind?
  private var tickRetries = 0
  private static let maxTickRetries = 3
  /// A tick the page refuses only because its own visibility has not caught up (document still hidden, no
  /// display yet) carries no state: the page learns the real state from the visibility message and its own
  /// events. Retry it shortly. Any other refusal leaves the page as it was (recovery contract): the next display,
  /// visibility or show tick brings it up to date.
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
      // Recovery step 3: a newer tick replaces a queued older one (only the latest trigger is current anyway).
      send(raw, coalesce: "tick", isCurrent: { [weak self] in self?.bridge.isCurrentDeadlineTrigger(id) == true },
           onAccepted: { [weak self] in self?.tickRetries = 0 },
           onRejected: { [weak self] in self?.retryRejectedTick(reason) ?? false },
           dropped: { [weak self] in
        guard let self else { return }
        if self.receiptWatchdog.currentID == id { self.receiptWatchdog.cancel() }
        self.backlog.tick = reason
      })
    } catch { degrade("tick", error: error) }
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
  /// Recovery contract: every accepted rendered receipt, for the coordinator (verified data on screen). Separate from
  /// `onRendered`, which verification and timing hooks own.
  public var onRenderVerified: (() -> Void)?
  public var onDisplayAbandoned: (() -> Void)?
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
    /// Recovery contract seams: the monotonic clock, the probe and bootstrap timers, and the probe itself.
    var verificationMonotonicClock: (() -> UInt64)?
    var verificationHealthArm: CockpitDeadlineDriver.Arm?
    var verificationProbe: ((@escaping @MainActor (String?) -> Void) -> Void)?
    var verificationHealth: CockpitPageHealth { health }
    func verificationWake() { grantHealthGrace(); freshnessDriver.notify(.wake) }
    /// The window facts `visibilityChanged` reads, for a no-window page; `shown` marks the page as opened.
    var verificationNoWindowVisibility: CockpitVisibility?
    /// The bridge.ts reject code a fake `.rejected` completion carries (the real path parses "rejected:<code>").
    var verificationRejectCode: String?
    /// A no-window page shown before it is ready, as open() shows a cold page: liveness runs and bootstrap is watched.
    func verificationShowUnready() { shown = true; health.resume(); if !bridge.ready { armBootstrapCheck() } }
    func verificationSetHostVisibility(_ value: CockpitVisibility) {
      shown = true; verificationNoWindowVisibility = value; visibilityChanged()
    }
    /// G3-86: the next this many submissions are refused as a full delivery queue refuses them.
    var verificationRefuseSubmissions = 0
    /// Calls admitted to the ordered delivery and not completed yet, the active one included.
    var verificationOutstanding: Int { orderedDelivery.outstanding }
    /// A data-deadline tick for the given reason, as the deadline driver or a wake would send it.
    func verificationFreshnessTick(_ reason: CockpitDeadlineReason) { sendFreshnessTick(reason) }
    /// Actions are admitted only from the key window (`CockpitVisibility.active`), so a window that is shown for
    /// an action test must be key; pass `key: false` for a shown-but-inactive window.
    func verificationConfirmVisible(key: Bool = true) throws {
      _ = try bridge.setVisibility(.init(visible: true, occluded: false, key: key))
      let token = visibilityFence.begin(visible: true); _ = visibilityFence.confirm(token)
      health.resume()
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
    /// Stands in for `NSApp.isActive` (and, with it, the panel's key state) and for `NSApp.activate()`.
    var verificationApplicationActive: (() -> Bool)?
    var verificationActivateApplication: (() -> Void)?
    /// Stands in for `NSApp.activationPolicy() == .regular`, which the host's presence flips.
    var verificationApplicationRegular: (() -> Bool)?
    /// Stands in for `NSEvent.modifierFlags.contains(.command)` at the latch.
    var verificationCommandHeld: (() -> Bool)?
    /// Whether a put-back recovery is armed.
    var verificationPutBackArmed: Bool { putBackActivation.armedUntil != nil }
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
    /// AppKit finished the animated destination layout; observing it never changes the animation or its frame.
    public var verificationLayoutAnimationCompleted: (() -> Void)?
    public var verificationDragRegion: NSView? { dragRegion }
    /// CKP-SHELL-33: the launch rack as last drawn (extension 0-1, where it is heading, its panel when on screen),
    /// whether the nozzles are lit, and whether a motion (open, landing, flight) is running.
    public var verificationRack: (ext: CGFloat, target: CGFloat, panel: CGRect?, ignited: Bool, moving: Bool) {
      (rackExtension, rackTarget, rack.panel?.isVisible == true ? rack.panel?.frame : nil, ignited, motion != nil)
    }
    /// The rack clipping rectangle in its flipped view coordinates.
    public var verificationRackMask: CGRect? { (rack.panel?.contentView as? CockpitRackView)?.maskedOut }
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
    openPoint: @escaping () -> CGPoint? = { nil }, systemSignals: CockpitSystemSignalSource? = nil
  ) {
    self.systemSignals = systemSignals
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
    // G3-102: a page built or warmed while the shared session had another attachment opens at the session's level.
    panel.level = Self.level(detached: shellSession.detached)
    panel.collectionBehavior = Self.collectionBehavior(detached: shellSession.detached)
    health.resume()
    guard shown else {
      shown = true; awaitingShown = true; rendersSinceOpen = 0
      if !bridge.ready { armBootstrapCheck() }
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
      applyPresentationTraits()
      if shellSession.detached { onPresenceChanged?(true) }
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
    applyPresentationTraits()
    if shellSession.detached { onPresenceChanged?(true) }
    lastVisibility = nil; visibilityChanged()
  }
  /// CKP-SHELL-33: true while the rack-first entrance of this open runs (the page is shown once the rack is out).
  public var entersWithRack: Bool { entering }
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
    panel.hasShadow = false; panel.level = Self.level(detached: shellSession.detached); panel.hidesOnDeactivate = false
    panel.collectionBehavior = Self.collectionBehavior(detached: shellSession.detached)
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
    // The shutter's frame animation resizes the attached window; the rack's mask line follows that height each step.
    observers.append(
      center.addObserver(forName: NSWindow.didResizeNotification, object: panel, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated { if let self, self.shutterMoving, self.motion == nil { self.refreshRack() } }
      })
    for name in [
      NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification,
      NSWindow.didChangeOcclusionStateNotification, NSWindow.didMiniaturizeNotification,
      NSWindow.didDeminiaturizeNotification,
    ] {
      observers.append(
        center.addObserver(forName: name, object: panel, queue: .main) { [weak self] _ in
          Task { @MainActor in
            self?.visibilityChanged()
            if name == NSWindow.didMiniaturizeNotification || name == NSWindow.didDeminiaturizeNotification { self?.onPresenceChanged?(false) }
          }
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
    // Spec item 1: Cmd-Tab away (or any app switch) closes the attached cockpit, as a menu-bar popover does.
    observers.append(center.addObserver(forName: NSApplication.didResignActiveNotification, object: NSApplication.shared, queue: .main) {
      [weak self] _ in MainActor.assumeIsolated {
        guard let self else { return }
        // Walkthrough 11-17: the resign the put back's own policy flip posts is answered by activating again, not a close.
        if self.reactivateAfterPutBack() { return }
        _ = self.dismissal.request(.appResigned)
      }
    })
    // Spec item 1: while one of our menus is tracked (the status menu, this context menu) nothing closes the cockpit.
    observers.append(center.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) { [weak self] _ in
      MainActor.assumeIsolated { self?.menuTracking(began: true) }
    })
    observers.append(center.addObserver(forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main) { [weak self] _ in
      MainActor.assumeIsolated { self?.menuTracking(began: false) }
    })
    if let systemSignals {
      cancelSystemSignals = systemSignals { [weak self] signal in self?.systemSignal(signal) }
      applyLayout()
    } else {
      installOwnSystemObservers(center: center)
    }
    panel.alphaValue = 0
    view.load(URLRequest(url: pageURL))
  }
  /// Spec item 2: one signal per OS edge from the app's source. The immediate display pass keeps the cockpit from
  /// hanging in the wrong place; the settled pass reads the final visible frame and icon position.
  func systemSignal(_ signal: CockpitSystemSignal) {
    guard !ending else { return }
    switch signal {
    // Recovery contract: a wait that spanned the sleep or the lock starts over.
    case .wake: grantHealthGrace(); freshnessDriver.notify(.wake)
    case .unlock: grantHealthGrace(); freshnessDriver.notify(.unlock)
    case .clockChanged: freshnessDriver.notify(.clockChange)
    case .displaysChanged: cancelDrag(); applyLayout()
    case .displaysSettled: if dragStart == nil { applyLayout() }
    }
  }
  private func menuTracking(began: Bool) {
    if began {
      menuTrackingDepth += 1
      if menuTrackingHold == nil || menuTrackingHold?.isReleased == true { menuTrackingHold = dismissal.hold(.menuTracking) }
    } else {
      menuTrackingDepth = max(0, menuTrackingDepth - 1)
      if menuTrackingDepth == 0 { menuTrackingHold?.release(); menuTrackingHold = nil }
    }
  }
  /// Without the app's source (prewarmed before the lifecycle started, tests): the page's own observers, as before.
  private func installOwnSystemObservers(center: NotificationCenter) {
    let workspaceCenter = NSWorkspace.shared.notificationCenter
    for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
      let observer = workspaceCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        Task { @MainActor in self?.grantHealthGrace(); self?.freshnessDriver.notify(.wake) }
      }
      freshnessObservers.append((workspaceCenter, observer))
    }
    let distributed = DistributedNotificationCenter.default()
    let unlock = distributed.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
      Task { @MainActor in self?.grantHealthGrace(); self?.freshnessDriver.notify(.unlock) }
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
  }
  public func display(_ data: WireCockpitData, ticket: CockpitQueryTicket) {
    guard visibilityFence.isConfirmedVisible else {
      // Do not retain hidden snapshots; request fresh data after show is accepted.
      refreshAfterHiddenDisplay = true; return
    }
    // A pending replacement does not prove the displayed deadline is obsolete.
    // Keep its timer until a validated newer report actually replaces it.
    receiptWatchdog.cancel()
    // The render wait keeps running across replacements (macrevb-981-1).
    if !bridge.hasPendingDisplay { renderWatchdog.cancel() }
    do {
      let raw = try bridge.display(data, ticket: ticket)
      let dropped = bridge.lastNonFinitePaths
      for path in dropped.prefix(8) { CockpitFailureLog.record("display-non-finite path=\(path) count=\(dropped.count)") }
      guard let id = bridge.currentDisplayRequest else { throw CockpitBridgeError.unavailable }
      if bridge.awaitsDisplayReceipt(id), renderWatchdog.currentID == nil { renderWatchdog.wait(for: id) }
      // Recovery step 3: one active display plus the latest replacement. A newer display replaces a queued older one
      // at the back of the queue, so a reply stream never fills it; host sequence order is kept (the newest message
      // carries the highest sequence).
      send(raw, coalesce: "display", isCurrent: { [weak self] in self?.bridge.isCurrentDisplay(id) == true }, onRejected: { [weak self] in
        // Recovery contract: a refused display leaves the last rendered data in place; no receipt is awaited for it.
        guard let self else { return false }
        if self.receiptWatchdog.currentID == id { self.receiptWatchdog.cancel() }
        let wasCurrent = self.bridge.isCurrentDisplay(id)
        self.bridge.abandonDisplay(id)
        if !self.bridge.hasPendingDisplay { self.renderWatchdog.cancel() }
        if wasCurrent { self.onDisplayAbandoned?() }
        if self.appearanceGate.retry(visible: self.visibilityFence.isConfirmedVisible, displayPending: self.bridge.hasPendingDisplay) { self.publishAppearance() }
        return false
      }, onFailed: { [weak self] in
        guard let self else { return }
        let wasCurrent = self.bridge.isCurrentDisplay(id)
        if self.receiptWatchdog.currentID == id { self.receiptWatchdog.cancel() }
        self.bridge.abandonDisplay(id)
        if !self.bridge.hasPendingDisplay { self.renderWatchdog.cancel() }
        if wasCurrent { self.onDisplayAbandoned?() }
      }, dropped: { [weak self] in
        guard let self else { return }
        let wasCurrent = self.bridge.isCurrentDisplay(id)
        if self.receiptWatchdog.currentID == id { self.receiptWatchdog.cancel() }
        self.bridge.abandonDisplay(id)
        if !self.bridge.hasPendingDisplay { self.renderWatchdog.cancel() }
        self.backlog.display = true
        if wasCurrent { self.onDisplayAbandoned?() }
      })
    } catch { degrade("display", error: error); onDisplayAbandoned?() }
  }
  /// Hide synchronously before yielding; acknowledge only after clear receipt
  /// or complete view disposal. An unknown floor remains blocked after receipt.
  public func clearPrivateViews(adopting context: CockpitEngineContext? = nil) async {
    freshnessDriver.hide(); freshnessDriver.invalidate(); bridge.cancelDeadlineReports(); visibilityFence.invalidate()
    orderedDelivery.invalidate(); refreshAfterHiddenDisplay = false; appearanceGate.invalidate(); cancelAppearanceWait()
    receiptWatchdog.cancel(); renderWatchdog.cancel(); backlog = BacklogResync()
    visibilityTimeout?.cancel(); visibilityTimeout = nil
    freshnessHasRendered = false; pendingFreshnessReason = nil
    pauseHealth(); setReadingDelayed(false, cause: "clear")
    web?.isHidden = true
    scope = "all"
    #if MODELPLAN_TEST_ONLY_SPI
    let hasPage = web != nil || verificationNoWindowDelivery != nil
    #else
    let hasPage = web != nil
    #endif
    guard hasPage, bridge.ready, clearWaiter == nil else {
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
    } catch { fail(.clearRejected, error: error) }
  }
  /// G3-86: what a skipped update needs once the queue moves again. The page keeps showing its last state.
  private struct BacklogResync { var display = false, visibility = false, appearance = false; var tick: CockpitDeadlineReason? }
  private var backlog = BacklogResync()
  /// Consecutive messages the ordered queue refused, reset by any accepted delivery (logged; never fatal).
  private var deliveryRefusals = 0
  /// `onRejected` runs when the page refused a delivered message; returning true means the caller recovers
  /// (a retry). Otherwise `pageRejected` classifies the refusal: only a refused load or clear, or a page that unloaded
  /// itself, ends the page. `dropped` runs when the ordered queue refuses the message before delivery: the caller
  /// undoes its wait and marks what to resend.
  private func send(_ raw: String, clear: Bool = false, bootstrap: Bool = false, coalesce: String? = nil,
                    isCurrent: (() -> Bool)? = nil, onAccepted: (() -> Void)? = nil,
                    onRejected: (() -> Bool)? = nil, onFailed: (() -> Void)? = nil, dropped: (() -> Void)? = nil) {
    let web = self.web
    #if MODELPLAN_TEST_ONLY_SPI
    let noWindowTest = web == nil && verificationNoWindowDelivery != nil
    #else
    let noWindowTest = false
    #endif
    guard web != nil || noWindowTest else { fail(.pageAPIUnavailable); return }
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
      case .missing: self.fail(clear ? .clearRejected : .pageAPIUnavailable) // macrevb-981-3: a clear that cannot reach the bridge is a privacy disposal
      case .rejected:
        #if MODELPLAN_TEST_ONLY_SPI
        if let code = self.verificationRejectCode { self.lastRejectCode = code }
        #endif
        // macrevb-998-4: every refusal is typed, including the tick refusals that are retried below.
        self.lastRejectionKind = CockpitRecoveryPolicy.rejectionKind(code: self.lastRejectCode)
        CockpitFailureLog.record("page-reject code=\(self.lastRejectCode) kind=\(self.lastRejectionKind?.rawValue ?? "none")")
        if onRejected?() != true { self.pageRejected(clear: clear, bootstrap: bootstrap) }
      case .failed:
        // The load call failing means the page module never ran. Any other call that threw was still answered by a
        // live page (a dead process reports its termination separately), so the page keeps what it shows.
        if bootstrap { self.fail(.javascriptFailed) }
        else if clear { self.fail(.clearRejected) }
        else { CockpitFailureLog.record("page-call-failed type=\(Self.messageType(raw)) kept=true"); onFailed?() }
      }
    }) }
    guard !submitted else { return }
    // G3-86 (14c C-01): a full queue used to end the cockpit as `localEncoding` after about a minute open. A refused
    // update is skipped and resent when the queue moves. Recovery contract: a queue that stays full is a page that is
    // not answering, which the probes decide; a count of refusals never ends the page.
    deliveryRefusals += 1
    CockpitFailureLog.record("delivery-skipped type=\(Self.messageType(raw)) outstanding=\(orderedDelivery.outstanding) "
      + "consecutive=\(deliveryRefusals)")
    dropped?()
    pageLate("deliveryBacklog")
  }
  /// Recovery contract: a refusal proves the page answered. It ends the page only when the page cannot go on: a
  /// refused load, a refused privacy clear, or a page that unloaded itself while refusing (bridge.ts).
  private func pageRejected(clear: Bool, bootstrap: Bool) {
    switch CockpitRecoveryPolicy.rejection(code: lastRejectCode, clear: clear, bootstrap: bootstrap) {
    case .privacy: fail(.clearRejected)
    case .pageGone: fail(bootstrap ? .messageRejected : .pageAPIUnavailable)
    case .kept:
      lastRejectionKind = CockpitRecoveryPolicy.rejectionKind(code: lastRejectCode)
      CockpitFailureLog.record("page-reject-kept kind=\(lastRejectionKind?.rawValue ?? "none") code=\(lastRejectCode) displayPending=\(bridge.hasPendingDisplay)")
    }
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
    // Recovery contract: any message from this page, even one the bridge refuses, proves it alive.
    pageAnswered()
    guard let receipt = acceptBridgeReply(raw, source: source) else { return }
      switch receipt {
      case .ready:
        bootstrapCheck?(); bootstrapCheck = nil
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
        setReadingDelayed(false, cause: "rendered")
        if !bridge.hasPendingDisplay { renderWatchdog.cancel() }
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
        onRenderVerified?()
      case .deadlinePending(let id):
        if receiptWatchdog.currentID != id { receiptWatchdog.wait(for: id) }
      case .nextDeadline(let value):
        if !bridge.hasPendingDisplay { setReadingDelayed(false, cause: "deadline") }
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
    catch CockpitBridgeError.unsupportedPageContract { recordRejectedBridgeMessage(); fail(.unsupportedPageContract); return nil }
    catch { recordRejectedBridgeMessage(); return nil }
  }
  private func suspendForHiddenPage() {
    refreshAfterHiddenDisplay = refreshAfterHiddenDisplay || bridge.hasPendingDisplay || backlog.display
    backlog = BacklogResync()
    appearanceGate.deferUntilVisible(); cancelAppearanceWait(); orderedDelivery.invalidate()
    freshnessDriver.hide(); bridge.cancelDeadlineReports(); pendingFreshnessReason = nil
    receiptWatchdog.cancel(); renderWatchdog.cancel()
    pauseHealth()
  }
  /// The Mac woke or the screen unlocked: a wait that spanned the sleep starts over.
  /// #981 sampling P2: a shown page that never reported ready is monitored again after the grace; nothing else would
  /// re-arm it (the receipt and visibility watchdogs need a ready page), so it would stay blank.
  private func grantHealthGrace() {
    health.grantGrace(); stopProbing()
    if shown, !ending, !bridge.ready, !health.paused { armBootstrapCheck() }
  }
  private func hostVisibility() -> CockpitVisibility? {
    #if MODELPLAN_TEST_ONLY_SPI
    if let value = verificationNoWindowVisibility { return value }
    #endif
    guard let window else { return nil }
    return CockpitVisibility(
      visible: window.isVisible && !window.isMiniaturized && !NSApp.isHidden,
      occluded: !window.occlusionState.contains(.visible), key: windowIsKey(window)
    )
  }
  /// The page's key fact: the panel is the key window of the active app.
  private func windowIsKey(_ window: NSWindow) -> Bool {
    #if MODELPLAN_TEST_ONLY_SPI
    // The test process is never the active app, so the window server never gives the panel key; the seam stands in for
    // both (the attached cockpit is the app's only window and is made key whenever it is ordered front).
    if let verificationApplicationActive { return window.isVisible && verificationApplicationActive() }
    #endif
    return window.isKeyWindow && NSApp.isActive
  }
  private var applicationIsActive: Bool {
    #if MODELPLAN_TEST_ONLY_SPI
    if let verificationApplicationActive { return verificationApplicationActive() }
    #endif
    return NSApp.isActive
  }
  private var applicationIsRegular: Bool {
    #if MODELPLAN_TEST_ONLY_SPI
    if let verificationApplicationRegular { return verificationApplicationRegular() }
    #endif
    return NSApp.activationPolicy() == .regular
  }
  private func activateApplication() {
    #if MODELPLAN_TEST_ONLY_SPI
    if let verificationActivateApplication { verificationActivateApplication(); return }
    #endif
    NSApp.activate()
  }
  /// G3-129 (owner, 11-18): a detached cockpit is a normal window (normal level, not always on top), but the one the
  /// user has just detached comes to the front and is key. Root cause of it dropping behind: the detach lowers the
  /// window from the panel level to `.normal` and flips the app from accessory to regular (spec item 4), and nothing
  /// then ordered it front or made it key. The flip's activation (PulseDockPresence) runs inside the flip, before the
  /// level change, and not at all when the app was already regular; macOS can also deactivate the app for the flip, as
  /// #1033 found for the reverse flip. A normal-level window of an inactive app sits under the front app's windows.
  /// Now the detach (key, menu, or a drag's drop) activates the app unless the user is switching away, orders the window
  /// front and makes it key, and answers a flip's later resign once, as a put back does (`CockpitPutBackActivation`).
  private func presentDetached(wasActive: Bool, wasRegular: Bool) {
    guard let window, shown, closeTask == nil, !ending, shellSession.detached else { return }
    putBackActivation.arm(wasActive: wasActive, leftRegular: wasRegular != applicationIsRegular, commandHeld: commandKeyHeld,
                          now: dismissalNow(), detached: true)
    if !applicationIsActive, !commandKeyHeld, !putBackActivation.userSwitching { activateApplication() }
    bringToFront(window)
    lastVisibility = nil; visibilityChanged()
  }
  /// Walkthrough 11-17: after a user put back, the presence flip to accessory deactivated the app and the first press
  /// on the page (its Close) was dropped. The app is activated again and the cockpit made key, once for that flip
  /// (macrevd-1033-1: armed only by a real flip, retired when the user switches away). G3-129: the same for a detach's
  /// flip to regular; the recovery acts only while the cockpit keeps the attachment it was armed for.
  @discardableResult private func reactivateAfterPutBack() -> Bool {
    let presentable = window?.isVisible == true && shown && closeTask == nil && !ending
      && shellSession.detached == putBackActivation.armedDetached
    guard putBackActivation.reactivates(isActive: applicationIsActive, presentable: presentable,
                                        now: dismissalNow()) else { return false }
    activateApplication()
    window?.makeKeyAndOrderFront(nil)
    visibilityChanged()
    return true
  }
  private func visibilityChanged() {
    // The alpha-0 warm paint is not a visible cockpit; the page keeps the hidden state it was given.
    guard !ending, !warmPainting, closeTask == nil, let value = hostVisibility() else { return }
    // #981 sampling P2: liveness follows the host's window facts before the page is ready too. A hidden unready page
    // accrues nothing; shown again, it gets a fresh grace period and its bootstrap is monitored again. Everything
    // that delivers to the page stays behind the query-ticket guard below.
    if !(value.visible && !value.occluded) { if !health.paused { pauseHealth() } }
    else {
      health.resume()
      if shown, !bridge.ready, bootstrapCheck == nil, !health.isWaiting { armBootstrapCheck() }
    }
    guard bridge.queryTicket != nil else { return }
    guard value != lastVisibility else { return }
    lastVisibility = value
    let visible = value.visible && !value.occluded
    let retainVisibleSchedule = visible && freshnessDriver.isVisible
    let token = visibilityFence.begin(visible: visible)
    // macrev2-981-4: the host's own facts resume liveness accounting with a fresh grace period. Waiting for the page to
    // accept the visibility would leave a page that stopped answering while covered paused, and never probed.
    if visible { health.resume() }
    if !visible { suspendForHiddenPage() }
    else if !retainVisibleSchedule {
      freshnessDriver.hide(); bridge.cancelDeadlineReports(); pendingFreshnessReason = nil
      receiptWatchdog.cancel(); renderWatchdog.cancel()
    }
    visibilityTimeout?.cancel()
    visibilityTimeout = CockpitTimerHandle(cancel: armHealth(CockpitPageHealth.delayedAfterMs) { [weak self] in
      guard let self, !self.ending, self.visibilityFence.isPending(token) else { return }
      // G3-42: a page that has not been shown shows nothing, so a late hidden-state receipt is not a failure.
      // At launch the WebKit process can be busy past this deadline; failing here threw the prewarmed page
      // away and built another. The fence stays pending, and the open sends a new state with its own deadline.
      guard self.shown else { CockpitTimingLog.record("prewarm hidden-visibility-late"); return }
      // Recovery contract: a shown page that has not taken its visibility yet is slow; the probes decide the rest.
      self.pageLate("visibilityReceipt")
    })
    do {
      // Recovery step 3: the latest visibility replaces a queued older one (only the current fence token counts).
      send(try bridge.setVisibility(value), coalesce: "visibility", isCurrent: { [weak self] in self?.visibilityFence.isCurrent(token) == true }, onAccepted: { [weak self] in
        guard let self else { return }
        #if MODELPLAN_TEST_ONLY_SPI
        if self.verificationHoldHiddenVisibilityReceipt, !visible { return }
        #endif
        self.visibilityTimeout?.cancel(); self.visibilityTimeout = nil
        if self.visibilityFence.confirm(token) {
          self.health.resume()
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
    } catch { degrade("visibility", error: error) }
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
      fail(.navigationFailed)
      return
    }
    guard let shell = currentShell else { fail(.localEncoding); return }
    do { send(try bridge.load(appearance, shell: shell), bootstrap: true) } catch { fail(.localEncoding, error: error) }
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
  public func windowDidResignKey(_ notification: Notification) {
    // Spec item 1: key moving to another of our windows closes the attached cockpit, as Maccy's panel does. Not when
    // the app is not active (an accessory app that was never activated: our own helper took key) and not for a panel
    // the cockpit owns (Help overlay, hint, the enlarged field).
    if NSApp.isActive, let window, window.isVisible, let key = NSApp.keyWindow, key !== window, !Self.isOwnedChild(key) {
      _ = dismissal.request(.keyResigned)
    }
    cancelDrag()
  }
  static func isOwnedChild(_ window: NSWindow?) -> Bool {
    guard let id = window?.identifier else { return false }
    return id == helpOverlayIdentifier || id == fieldWindowIdentifier
  }
  /// macrev2-845-1: a detached cockpit that lands on another display without a drag (the system moved it) is fitted
  /// to that display, as a drop is.
  public func windowDidChangeScreen(_ notification: Notification) {
    guard let window, shown, shellSession.detached, dragStart == nil, !entering, motion == nil, closeTask == nil, !ending else { return }
    fitToDropDisplay(window)
  }
  /// The detached cockpit's current place becomes its remembered origin and the layout is applied there. G3-132: the
  /// size is the same on every display (`sizeBasis`), so this only clamps the place inside the drop display's visible
  /// frame; it never shrinks or grows the cockpit.
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
    guard let layout, let window, let content = window.contentView else { return }
    // Scaled layouts (CKP-SHELL-07): the settled canvas is the scaled frame, not the 636-pt page. G3-108: while the
    // shutter moves the bottom edge the content follows the live frame, so the cockpit slides instead of stretching.
    let size = shutterMoving ? window.frame.size : layout.frame.size
    if content.bounds.size != size { content.setBoundsSize(size) }
  }
  public func setAckedCautions(_ ids:[String]) { bridge.ackedCautions = ids }
  public func setPinnedModels(_ ids:[String]) { bridge.pinnedModels = ids }
  public func updateScope(_ key:String) {
    guard key != scope, CockpitMemberScopes.isValidKey(key) else { return }
    scope=key; publishAppearance()
  }
  public func updateAppearance(_ value: CockpitAppearance) {
    let resized = value.size != appearance.size
    appearance = CockpitAppearance(theme: CockpitDayPolicy.resolve(value.theme), locale: value.locale, profile: appearance.profile,
      reduceMotion: value.reduceMotion, reduceTransparency: value.reduceTransparency, shutterClosed: appearance.shutterClosed, detached: shellSession.detached, redBelow: value.redBelow, showProjectNames: value.showProjectNames, showUsedPercent: value.showUsedPercent, showAllModels: value.showAllModels, size: value.size, memberOrder: value.memberOrder)
    applyPresentationTraits()
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
  /// `behindPendingDisplay` (glm-959-1): send while a display receipt is still pending, as an uncorrelated change
  /// that derives no deadline, so the pending display's own deadline correlation is untouched.
  private func publishAppearance(behindPendingDisplay: Bool = false) {
    guard bridge.ready, !bridge.blocked, !ending else { return }
    let requested = appearanceGate.request(visible: visibilityFence.isConfirmedVisible, displayPending: bridge.hasPendingDisplay)
    let canSend = requested || (behindPendingDisplay && visibilityFence.isConfirmedVisible)
    let appearanceVersion = appearanceGate.version
    watchDeferredAppearance()
    guard canSend else { return }
    do {
      let eligible = !behindPendingDisplay && visibilityFence.isConfirmedVisible && freshnessHasRendered
      let raw = try bridge.setAppearance(appearance, deadlineEligible: eligible)
      if !behindPendingDisplay, let id = bridge.currentAppearanceTrigger {
        // Keep the previously admitted deadline until this repaint reports a replacement.
        receiptWatchdog.wait(for: id)
        send(raw, isCurrent: { [weak self] in self?.bridge.isCurrentAppearance(id) == true }, onAccepted: { [weak self] in
          guard let self else { return }
          // The page took it, but visibility or the deadline basis moved meanwhile: the gate stays deferred and the
          // next rendered, deadline or visibility receipt sends the appearance again. Never a page failure.
          guard self.bridge.acknowledgeAppearance(id) else {
            CockpitFailureLog.record("page-resync appearance acknowledgement superseded"); return
          }
          if self.appearanceGate.acknowledge(appearanceVersion) { self.cancelAppearanceWait() }
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
          if self.appearanceGate.acknowledge(appearanceVersion) { self.cancelAppearanceWait() }
        }, dropped: { [weak self] in self?.backlog.appearance = true })
      }
      guard let shell = currentShell else { CockpitFailureLog.record("page-degraded at=shell layout=none"); return }
      send(try bridge.setShell(shell), coalesce: "shell", dropped: { [weak self] in self?.backlog.appearance = true })
      visibilityChanged()
    } catch { degrade("appearance", error: error) }
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
  /// The usable frame and icon rect the layout is fitted to. G3-128 (owner, build 15): attached (an open, the rack, the
  /// catch zone and a put back) it is always the menu bar icon's display, whatever opened it. Build 14c (G3-79): a
  /// detached cockpit stays on the display its remembered origin is on while that is still a display; otherwise a
  /// detached open goes to the display the user clicked on (the widget's), and only without a click to the icon's
  /// display. The icon rect is the real icon only on its own display; elsewhere the cockpit opens at that display's
  /// top right, as with no icon.
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
    // G3-128: attached, the status item's display; the click point (the widget's ignition, possibly on another display
    // and kept from an earlier open) only places a detached open.
    let asked = shellSession.detached
      ? CockpitScreenSelection.openScreen(point: openPoint(), anchor: requested, screens: displays)
      : CockpitScreenSelection.attachedScreen(anchor: requested, screens: displays)
    guard let screen = remembered ?? asked else { return nil }
    let icon = requested.flatMap { screen.frame.intersects($0) ? $0 : nil } ?? CockpitShellLayout.hiddenIconAnchor(usable: screen.visibleFrame)
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
                                           screenWidth: screenWidth(usable), forceCompact: compact, basis: sizeBasis()) else { return nil }
    return (fit, usable, icon)
  }
  /// CKP-SHELL-33: the menu bar icon the rack hangs from, only while it is a real icon on the attached cockpit's display.
  func rackIcon() -> CGRect? {
    guard let (_, _, icon) = attachedFit(), let requested = anchor(), icon == requested, icon.width > 0, icon.height > 0,
          [icon.minX, icon.minY, icon.width, icon.height].allSatisfy(\.isFinite) else { return nil }
    return icon
  }
  /// G3-132 (owner, 11-18): one cockpit size on every display, from the smallest connected display. It depends only on
  /// the displays, so a drag between them never resizes the cockpit; a configuration change relayouts (the
  /// `didChangeScreenParametersNotification` observer). The test placement seam fits its own usable frame alone.
  func sizeBasis() -> CockpitSizeBasis? {
    #if MODELPLAN_TEST_ONLY_SPI
    if verificationPlacement != nil { return nil }
    #endif
    return CockpitSizeBasis(screens: screens())
  }
  /// D66: Auto judges the full width of a display, whatever the Dock takes (G3-132: the smallest display's, `sizeBasis`).
  private func screenWidth(_ usable: CGRect) -> CGFloat {
    screens().first { $0.visibleFrame == usable }?.frame.width ?? usable.width
  }
  /// The fit and the window frame an open or a relayout uses. Build 14c (G3-79): a detached cockpit's remembered
  /// origin is replayed only while it is still on some display; otherwise the cockpit takes its attached place on
  /// the display `environment()` chose (attached: the icon's, G3-128; detached: the click's).
  func placement() -> (fit: CockpitShellLayout, frame: CGRect)? {
    guard let (usable, icon) = environment(),
          let fit = CockpitShellLayout.fit(usable: usable, anchor: icon, shutterClosed: shellSession.shutterClosed, size: appearance.size, screenWidth: screenWidth(usable),
                                           forceCompact: shellSession.detached && shellSession.compactWhileDetached, basis: sizeBasis()) else { return nil }
    guard shellSession.detached else { return (fit, fit.frame) }
    #if MODELPLAN_TEST_ONLY_SPI
    if verificationPlacement != nil { return (fit, fit.clamping(origin: detachedOrigin ?? fit.frame.origin, usable: usable)) }
    #endif
    let replayed = detachedOrigin.flatMap { CockpitScreenSelection.replayFrame(origin: $0, size: fit.frame.size, screens: screens()) }
    return (fit, replayed ?? fit.frame)
  }
  private func applyLayout(animated: Bool = false, shutter: Bool = false) {
    // D88: a closing cockpit keeps its close animation. A relayout then (a screen-parameter change, a resize from
    // Settings) set the frame back to the layout frame and cut the shrink into the icon; a re-open cancels the close
    // first and lays out again.
    guard closeTask == nil, let window, let (fit, frame) = placement() else { return }
    shutterTask?.cancel(); shutterTask = nil
    layout = fit
    appearance = .init(theme: CockpitDayPolicy.resolve(appearance.theme), locale: appearance.locale, profile: fit.profile,
      reduceMotion: appearance.reduceMotion, reduceTransparency: appearance.reduceTransparency, shutterClosed: fit.shutterClosed, detached: shellSession.detached, redBelow: appearance.redBelow, showProjectNames: appearance.showProjectNames, showUsedPercent: appearance.showUsedPercent, showAllModels: appearance.showAllModels, size: appearance.size, memberOrder: appearance.memberOrder)
    // G3-108: the web view keeps the open canvas on the window's bottom edge and the page keeps the body at one place on
    // it, open or closed. So the page's own relayout, whenever its message lands, never moves the body; only the window
    // frame does, and only where the owner wants it to (attached: the bottom edge, top pinned under the icon;
    // detached: the top edge, the body stays; with too little room above an open, the body comes down by the shortfall).
    let current = window.frame
    let bottomMoves = abs(current.minY - frame.minY) >= 0.5 || abs(current.minX - frame.minX) >= 0.5
    let motion = shutter && !appearance.reduceMotion && window.isVisible && !entering && current.width == frame.width
    var pending = false
    if motion && bottomMoves {
      shutterMoving = true; shutterGeneration += 1
      let generation = shutterGeneration
      NSAnimationContext.runAnimationGroup({ context in
        context.duration = Self.shutterDuration; context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        window.animator().setFrame(frame, display: true)
      }, completionHandler: { [weak self] in
        Task { @MainActor in
          guard let self, self.shutterMoving, self.shutterGeneration == generation else { return }
          self.shutterMoving = false
          if let size = self.layout?.frame.size { self.window?.contentView?.setBoundsSize(size) }
          if self.motion == nil { self.refreshRack() }
        }
      })
    } else if motion && frame.height < current.height {
      // Detached close: the page closes its porthole first (same duration), then the top edge comes down over the band
      // that is empty by then. Nothing below the band moves.
      pending = true
      shutterTask = Task { @MainActor [weak self] in
        do { try await Task.sleep(for: .milliseconds(Int(Self.shutterDuration * 1_000))) } catch { return }
        guard let self, self.closeTask == nil, !self.ending, let window = self.window else { return }
        self.shutterTask = nil
        // The bottom edge where it is now (a drag in the meantime keeps its place); only the top edge comes down.
        let settled = CGRect(origin: window.frame.origin, size: frame.size)
        window.setFrame(settled, display: true)
        window.contentView?.setBoundsSize(settled.size)
      }
      (window as? CockpitPanel)?.pendingTopDrop = current.height - frame.height
    } else if animated {
      shutterMoving = false
      NSAnimationContext.runAnimationGroup({ context in
        context.duration = 0.25; context.timingFunction = CAMediaTimingFunction(name: .easeOut)
        window.animator().setFrame(frame, display: true)
      }, completionHandler: {
        #if MODELPLAN_TEST_ONLY_SPI
        Task { @MainActor [weak self] in self?.verificationLayoutAnimationCompleted?() }
        #endif
      })
    } else { shutterMoving = false; window.setFrame(frame, display: true) }
    // CKP-SHELL-07 (owner D51): a scaled cockpit is the same page at a uniform WebKit page zoom, not a
    // scaled bitmap, so text is drawn at its final size and the page hit-tests its own controls.
    window.contentView?.setBoundsSize(shutterMoving || pending ? window.frame.size : frame.size)
    web?.frame = fit.webFrame
    web?.pageZoom = fit.scale
    dragRegion?.frame = fit.scaledTitleDragFrame
    publishAppearance()
    if self.motion == nil { refreshRack() }
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
  /// G3-108: a close or discard while a detached close still waits for the page's porthole finishes it at once: the
  /// top edge comes down, the body stays. Cancelling it left an open-sized window at the body's place, so the remembered
  /// origin described a window that did not fit there and the reopen was clamped down by the porthole band.
  private func settlePendingShutter() {
    guard let task = shutterTask else { return }
    task.cancel(); shutterTask = nil
    guard let window, let size = layout?.frame.size, window.frame.size != size else { return }
    window.setFrame(CGRect(origin: window.frame.origin, size: size), display: true)
    window.contentView?.setBoundsSize(size)
  }
  func toggleShutter() {
    guard layout?.forcedClosed != true else { return }
    // CKP-SHELL-33: a key detach's landing or a put back's flight ends first, in its final state (as another key press
    // ends it), so its 60 Hz driver never moves the window under the shutter's own motion.
    if !entering { finishEntrance() }
    // G3-108: detached, the body stays where it is now (a close after an open that had to come down keeps that place).
    if shellSession.detached, let window, !entering, dragStart == nil { shellSession.remember(window.frame.origin, arrangement: arrangement) }
    shellSession.shutterClosed.toggle(); applyLayout(shutter: true)
  }
  public var isAttached: Bool { !shellSession.detached }
  /// The detach key (attached) or the put-back key (detached) in the same strip slot, and the right-click item.
  /// CKP-SHELL-33 (D181/D187): a detach burns the nozzles briefly and moves the cockpit out of the catch zone to the
  /// first spot fully on screen while the rack retracts into the icon; a put back lights the nozzles at the press, the
  /// rack extends from the press while the cockpit flies home (G3-130), catches it, and the nozzles go out once it is
  /// latched.
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
    putBackActivation.beginPutBack() // G3-129: switch intent from before this detach does not count
    let wasActive = applicationIsActive, wasRegular = applicationIsRegular
    shellSession.detached = true
    onPresenceChanged?(true)
    if plan.compact, let compact {
      // D187: no room for the full cockpit; it switches to the short version at home, then moves.
      shellSession.compactWhileDetached = true
      shellSession.remember(compact.origin, arrangement: arrangement)
      applyLayout()
    }
    shellSession.remember(plan.frame.origin, arrangement: arrangement)
    updateAppearance(appearance)
    presentDetached(wasActive: wasActive, wasRegular: wasRegular)
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
    putBackActivation.beginPutBack()
    shellSession.compactWhileDetached = false
    // G3-102: with no fitting display the frame stays, but the level and the page's shell state still follow the session.
    guard let home = attachedHome() else { latch(); return }
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
    // G3-130 (owner, 11-18): the rack starts unfolding at the press, together with the flight, both at their normal
    // speeds. A long flight lands on a full rack; a short move lands while it is still coming down, and the rack carries
    // on from there to its attached end state (`whenRackSettled`, as the open does).
    let p0 = window.frame.origin, d = home.origin, zone = CockpitLaunchRackTiming.catchZone
    let distance = hypot(p0.x - d.x, p0.y - d.y)
    if distance < zone {
      let duration = max(0.01, 0.36 * Double(distance / zone))
      extendRack()
      runMotion(duration, step: { [weak self] t in
        self?.window?.setFrameOrigin(CockpitPutBackPath.straight(from: p0, to: d, at: t))
      }, done: { [weak self] in self?.window?.setFrame(home, display: true); self?.whenRackSettled { self?.latch() } })
      return
    }
    // One continuous flight whose last part runs straight up the rack: the control point sits under home. The rack
    // unfolds alongside it.
    let c = CockpitPutBackPath.control(from: p0, to: d, zone: zone)
    let length = hypot(c.x - p0.x, c.y - p0.y) + hypot(d.x - c.x, d.y - c.y)
    let duration = CockpitLaunchRackTiming.flight(length: length)
    extendRack()
    // macrev2-1038-1: no clamp to home's height; from below the curve never rises above home, and from above (a display
    // stacked above) it comes down past the control point and up the rack, starting exactly where the cockpit is.
    runMotion(duration, step: { [weak self] t in
      self?.window?.setFrameOrigin(CockpitPutBackPath.flight(from: p0, to: d, zone: zone, at: t))
    }, done: { [weak self] in
      guard let self else { return }
      self.window?.setFrame(home, display: true)
      self.whenRackSettled { [weak self] in self?.latch() }
    })
  }
  /// The cockpit is caught: attached again under the icon, nozzles out.
  private func latch() {
    flying = false
    shellSession.detached = false; shellSession.compactWhileDetached = false
    rackExtension = rackIcon() != nil ? 1 : 0; rackTarget = rackExtension
    ignite(false)
    if placement() != nil { applyLayout() }
    updateAppearance(appearance)
    onShellChanged?()
    // Spec item 4: the Dock icon follows the detached window; a put back can drop the app to accessory, which can
    // take key from the cockpit, so it is made key again (the funnel's policy hold keeps it from closing).
    // Walkthrough 11-17 (#977 regression): the flip also deactivates the app, at once or with a resign a moment later.
    // Every latch is a user put back (key, menu, drag release, or a press that ends the flight), so an app that was
    // active is activated again; making the window key alone left the page `key: false` and its first press dropped.
    // macrevd-1033-1: only a presence change that really left the regular policy arms it (Settings still open keeps
    // the app regular, and then a resign is the user's own switch). macrev2-1033-1: nor when Command is held now or the
    // user started a switch since the put back began (CockpitPutBackActivation's state machine).
    let wasActive = applicationIsActive, wasRegular = applicationIsRegular
    onPresenceChanged?(true)
    putBackActivation.arm(wasActive: wasActive, leftRegular: wasRegular && !applicationIsRegular, commandHeld: commandKeyHeld,
                          now: dismissalNow())
    if let window, window.isVisible, shown, closeTask == nil, !ending {
      if !reactivateAfterPutBack() { window.makeKeyAndOrderFront(nil) }
    }
    #if MODELPLAN_TEST_ONLY_SPI
    verificationLayoutAnimationCompleted?()
    #endif
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
    let height = layout.pageSize.height, size = Self.attachmentKeySize
    // The page lays out in CSS px and renders at `layout.scale`, top-anchored in the whole-point window.
    // G3-108: closed, the window leaves out the porthole band of the canvas; the anchor keeps to the window's top edge.
    let local = layout.windowRect(page: CGRect(x: Self.attachmentKeyX, y: height - size - 2, width: size, height: size))
      .offsetBy(dx: 0, dy: -layout.portholeHeight)
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
      putBackActivation.beginPutBack() // a drag may end in the catch zone
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
        // G3-130: the rack (extending since the cockpit entered the zone) carries on at its pace during the ride home.
        extendRack(); ignite(true); flying = true
        // macrev2-1038-1: straight from where it was released, above or below home, with no first-frame jump.
        runMotion(CockpitLaunchRackTiming.rideHome, step: { [weak self] t in
          self?.window?.setFrameOrigin(CockpitPutBackPath.straight(from: start.origin, to: home.origin, at: t))
        }, done: { [weak self] in
          self?.window?.setFrame(home, display: true)
          self?.whenRackSettled { [weak self] in self?.latch() }
        })
      } else {
        if dragCatching { dragCatching = false; retractRack(); ignite(false) }
        // macrev2-845-1: a drop on a shorter display refits there; the drag kept the old size, which can overhang it.
        fitToDropDisplay(window); onShellChanged?()
        // Spec item 4: applied once at the drop, never mid-drag (a policy flip changes the app menu and can drop key).
        let wasActive = applicationIsActive, wasRegular = applicationIsRegular
        onPresenceChanged?(true)
        presentDetached(wasActive: wasActive, wasRegular: wasRegular)
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
    if changed { onShellChanged?(); onPresenceChanged?(false) }
  }
  private func installOutsideMonitors() {
    let events: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
    // Event monitor handlers run on the main thread, so the switch intent is recorded before the handler returns.
    outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] event in
      let type=event.type
      MainActor.assumeIsolated { self?.globalPress(eventType: type) }
    }
    // macrevd-1033-1: the Command key going down while the app is active is the start of a Cmd-Tab (or a shortcut).
    switchMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
      if event.modifierFlags.contains(.command) { MainActor.assumeIsolated { self?.userSwitchesAway() } }
      return event
    }
    localMonitor = NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
      MainActor.assumeIsolated {
        let point = event.window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation
        self?.localPress(in: event.window, at: point, eventType: event.type)
      }
      return event
    }
  }
  /// macrevd-1033-1: a press in another app or the Command key: a resign after this is the user's own switch.
  func userSwitchesAway() { putBackActivation.userSwitchesAway() }
  /// A press in another app (the global monitor). macrev2-1033-1: the switch intent is recorded synchronously, before
  /// the resign that click causes can reach the observer; the outside-press decision follows on the main actor as before.
  func globalPress(eventType: NSEvent.EventType) {
    userSwitchesAway()
    Task { @MainActor [weak self] in self?.outsidePress(NSEvent.mouseLocation, eventType: eventType) }
  }
  private var commandKeyHeld: Bool {
    #if MODELPLAN_TEST_ONLY_SPI
    if let verificationCommandHeld { return verificationCommandHeld() }
    #endif
    return NSEvent.modifierFlags.contains(.command)
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
    // Spec item 1 (1.7 c): a right or other press on the icon opens the status menu; the cockpit stays while it is up.
    if isTray { return }
    _ = dismissal.request(.outsidePress)
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
    orderedDelivery.invalidate(); appearanceGate.deferUntilVisible(); cancelAppearanceWait()
    visibilityFence.invalidate(); visibilityTimeout?.cancel(); visibilityTimeout = nil
    receiptWatchdog.cancel(); renderWatchdog.cancel(); pauseHealth()
    settlePendingShutter(); shutterMoving = false
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
      let drop = layout.rackMaskDrop(windowHeight: frame.height)
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
  private func fail(_ failure: CockpitWindowFailure, error: Error? = nil,
                    at site: StaticString = #function, line: UInt = #line) {
    guard !ending else { return }
    let age = openedAt.map { Int((ProcessInfo.processInfo.systemUptime - $0) * 1_000) }
    let detail: String = error.map { "error=\(Self.errorDetail($0)) " } ?? ""
    CockpitFailureLog.record("page-failure failure=\(failure.rawValue) at=\(site):\(line) ageMs=\(age.map(String.init) ?? "none") "
      + detail + "ready=\(bridge.ready) visible=\(visibilityFence.isConfirmedVisible) rendered=\(freshnessHasRendered) "
      + "displayPending=\(bridge.hasPendingDisplay) occluded=\(lastVisibility?.occluded.description ?? "unknown") reject=\(lastRejectCode) "
      + "recovery=\(failure.recovery.rawValue)")
    onFailure?(failure)
    discard()
  }
  public func discard() {
    guard !ending else { return }
    // Spec item 1: a late monitor or observer event cannot start a close during teardown.
    dismissal.disarm(); menuTrackingHold = nil; menuTrackingDepth = 0
    cancelSystemSignals?(); cancelSystemSignals = nil
    ending = true
    warmPaintEnd?.cancel(); warmPaintEnd = nil; warmPainting = false
    freshnessDriver.retire(); bridge.cancelDeadlineReports(); pendingFreshnessReason = nil
    orderedDelivery.invalidate(); refreshAfterHiddenDisplay = false; appearanceGate.invalidate(); cancelAppearanceWait()
    visibilityFence.invalidate(); visibilityTimeout?.cancel(); visibilityTimeout = nil
    receiptWatchdog.cancel(); renderWatchdog.cancel(); pauseHealth()
    freshnessObservers.forEach { center, token in center.removeObserver(token) }
    freshnessObservers.removeAll()
    #if MODELPLAN_TEST_ONLY_SPI
    verificationDidDiscard?()
    #endif
    closeTask?.cancel(); closeTask = nil; cancelDrag(); putBackActivation.retire()
    stopRack()
    settlePendingShutter(); shutterMoving = false
    if shellSession.detached, let window { shellSession.remember(window.frame.origin, arrangement: arrangement) }
    if let outsideMonitor { NSEvent.removeMonitor(outsideMonitor) }; outsideMonitor = nil
    if let localMonitor { NSEvent.removeMonitor(localMonitor) }; localMonitor = nil
    if let switchMonitor { NSEvent.removeMonitor(switchMonitor) }; switchMonitor = nil
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
    onPresenceChanged?(false)
    onClosed?()
  }
}

@MainActor private final class CockpitPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
  /// G3-108: while a detached close waits for the page's porthole, the window is still open-sized but its top edge is
  /// about to come down by this much. A move in that wait (a drag, a programmatic origin) is judged as the closed
  /// cockpit: AppKit's constraint otherwise pulled the open-sized window down under the menu bar, so the body moved by
  /// up to the porthole band and the remembered origin (and the reopen) came back lower than where it was put.
  var pendingTopDrop: CGFloat = 0
  override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
    guard pendingTopDrop > 0, frameRect.height > pendingTopDrop else { return super.constrainFrameRect(frameRect, to: screen) }
    var closed = frameRect; closed.size.height -= pendingTopDrop
    return CGRect(origin: super.constrainFrameRect(closed, to: screen).origin, size: frameRect.size)
  }
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
