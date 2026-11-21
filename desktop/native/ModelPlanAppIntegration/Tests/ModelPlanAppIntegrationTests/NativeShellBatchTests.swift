// SPDX-License-Identifier: MIT
import AppKit
import WebKit
import XCTest
import ModelPlanShell
@testable import ModelPlanCockpitWeb
@testable import ModelPlanAppIntegration

/// Native-shell spec items 1, 3 and 4 on the real cockpit controller and panel (window server: GUI leg). The page is
/// a synthetic document, as in CockpitD88AttachmentTests.
@MainActor final class NativeShellBatchTests: XCTestCase {
  private struct Fixture { let page: CockpitWindowController, icon: CGRect, usable: CGRect }
  @MainActor private final class FakeWindow: PulsePresenceWindow {
    var isVisible = false, isMiniaturized = false
    func close() { isVisible = false }
  }

  private func bundle() throws -> VerifiedCockpitBundle {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("native-shell-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: root) }
    let html = Data("synthetic".utf8); try html.write(to: root.appendingPathComponent("index.html"))
    let manifest = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "edition": "community", "interfaceOnly": true, "files": ["index.html": VerifiedCockpitBundle.digest(html)]])
    try manifest.write(to: root.appendingPathComponent("bundle-manifest.json"))
    return try VerifiedCockpitBundle(root: root, manifestSHA256: VerifiedCockpitBundle.digest(manifest))
  }
  private func open(signals: CockpitSystemSignalSource? = nil, beforeOpen: ((CockpitWindowController) -> Void)? = nil) throws -> Fixture {
    _ = NSApplication.shared
    guard let screen = NSScreen.main else { throw XCTSkip("needs a display") }
    let usable = screen.visibleFrame
    let icon = CGRect(x: usable.midX - 14, y: usable.maxY, width: 28, height: max(1, screen.frame.maxY - usable.maxY))
    let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic", generation: 1)
    let page = CockpitWindowController(bundle: try bundle(), context: context,
      appearance: .init(theme: .night, locale: .en, profile: .full, reduceMotion: true),
      shellSession: CockpitShellSession(), anchor: { icon }, systemSignals: signals)
    addTeardownBlock { @MainActor in page.discard() }
    beforeOpen?(page)
    page.open()
    (page.window?.contentView?.subviews.first as? WKWebView)?.navigationDelegate = nil
    return Fixture(page: page, icon: icon, usable: usable)
  }
  private func traits(_ page: CockpitWindowController) throws -> (NSWindow.Level, NSWindow.CollectionBehavior, Bool) {
    let window = try XCTUnwrap(page.window)
    return (window.level, window.collectionBehavior, page.dismissal.isArmed)
  }
  private var attachedTraits: (NSWindow.Level, NSWindow.CollectionBehavior, Bool) {
    (CockpitWindowController.panelLevel, CockpitWindowController.collectionBehavior(detached: false), true)
  }
  private var detachedTraits: (NSWindow.Level, NSWindow.CollectionBehavior, Bool) { (.normal, [], false) }
  private func assertTraits(_ page: CockpitWindowController, _ expected: (NSWindow.Level, NSWindow.CollectionBehavior, Bool),
                            _ message: String, line: UInt = #line) throws {
    let value = try traits(page)
    XCTAssertTrue(value.0 == expected.0 && value.1 == expected.1 && value.2 == expected.2,
                  "\(message): level, collection behaviour and dismissal arming move together (got \(value))", line: line)
  }

  /// Spec 3.6: level, behaviour and arming follow every attach and detach transition together.
  func testPresentationTraitsFollowEveryAttachmentTransition() throws {
    let f = try open()
    try assertTraits(f.page, attachedTraits, "attached after open")
    let start = try XCTUnwrap(f.page.window).frame
    let grab = CGPoint(x: start.minX + 120, y: start.maxY - 16)
    f.page.titleDrag(.began, point: grab)
    f.page.titleDrag(.moved, point: CGPoint(x: grab.x - 150, y: grab.y - 60))
    try assertTraits(f.page, detachedTraits, "detached by the drag")
    f.page.titleDrag(.cancelled, point: .zero)
    try assertTraits(f.page, attachedTraits, "a cancelled drag restores the attached traits")
    f.page.setAttached(false)
    try assertTraits(f.page, detachedTraits, "the detach key")
    f.page.setAttached(true)
    try assertTraits(f.page, attachedTraits, "put back")
    if let anchor = f.page.attachmentHintAnchor {
      XCTAssertEqual(anchor.collection, try XCTUnwrap(f.page.window).collectionBehavior, "hints copy the cockpit's behaviour")
    }
  }

  /// Spec 1.6: an outside press closes the attached cockpit once; not during a title drag; again after a cancel; a
  /// right press on the icon (the status menu) does not close it.
  func testOutsidePressGoesThroughTheFunnel() throws {
    let f = try open()
    let outside = CGPoint(x: f.usable.minX + 2, y: f.usable.minY + 2)
    let start = try XCTUnwrap(f.page.window).frame
    f.page.titleDrag(.began, point: CGPoint(x: start.minX + 120, y: start.maxY - 16))
    f.page.outsidePress(outside, eventType: .leftMouseDown)
    XCTAssertNotNil(f.page.window, "a press during a title drag does not close it")
    f.page.titleDrag(.cancelled, point: .zero)
    f.page.outsidePress(CGPoint(x: f.icon.midX, y: f.icon.midY), eventType: .rightMouseDown)
    XCTAssertNotNil(f.page.window, "a right press on the icon opens the status menu over the cockpit")
    XCTAssertEqual(f.page.dismissal.request(.appResigned), .closed, "after the cancel the funnel closes again")
    XCTAssertNil(f.page.window, "closed at once with Reduce Motion")
    XCTAssertEqual(f.page.dismissal.request(.outsidePress), .ignored, "one close per show")
  }

  /// Spec 1.7 d (D244): a press on the widget while the attached cockpit is open is decided at its release. A carry
  /// (ring or body, moved past the widget's 5 pt threshold) keeps the cockpit open, also through the carry's own key
  /// change; a click on the widget closes it, at the release. Before, the press closed it at mouse-down, before any
  /// carry could begin.
  func testAWidgetCarryKeepsTheAttachedCockpitOpen() throws {
    let f = try open()
    let widget = CGRect(x: f.usable.minX + 40, y: f.usable.minY + 40, width: 160, height: 60)
    XCTAssertFalse(try XCTUnwrap(f.page.window).frame.intersects(widget), "fixture: the widget is outside the cockpit")
    f.page.widgetFrame = { widget }
    let press = CGPoint(x: widget.midX, y: widget.midY)
    f.page.outsidePress(press, eventType: .leftMouseDown)
    XCTAssertNotNil(f.page.window, "a press on the widget does not close the cockpit at mouse-down")
    XCTAssertEqual(f.page.dismissal.request(.keyResigned), .suppressed(.drag), "the carry's key change does not close it")
    f.page.widgetPointer(.leftMouseDragged, at: CGPoint(x: press.x + 60, y: press.y + 20))
    f.page.widgetPointer(.leftMouseDragged, at: press)
    f.page.widgetPointer(.leftMouseUp, at: press)
    XCTAssertNotNil(f.page.window, "a carry, even one dropped back where it started, keeps the cockpit open")
    f.page.outsidePress(press, eventType: .leftMouseDown)
    f.page.widgetPointer(.leftMouseDragged, at: CGPoint(x: press.x + 3, y: press.y))
    f.page.widgetPointer(.leftMouseUp, at: CGPoint(x: press.x + 3, y: press.y))
    XCTAssertNil(f.page.window, "a click on the widget (within the threshold) closes it at the release, as any outside press")
  }

  /// macrevd-1114-1: a press delivered to another app is never a widget press, even with the cursor inside the widget.
  func testAnExternalPressInsideTheWidgetRectangleClosesOnce() throws {
    let f = try open()
    let widget = CGRect(x: f.usable.minX + 40, y: f.usable.minY + 40, width: 160, height: 60)
    f.page.widgetFrame = { widget }
    f.page.outsidePress(CGPoint(x: widget.midX, y: widget.midY), eventType: .leftMouseDown, external: true)
    XCTAssertNil(f.page.window, "an external click closes the cockpit once, with no widget hold")
  }

  /// The widget press hold never outlives the show: a release that never arrives cannot keep a later show open.
  func testALostWidgetReleaseDoesNotHoldTheNextShow() throws {
    let f = try open()
    let widget = CGRect(x: f.usable.minX + 40, y: f.usable.minY + 40, width: 160, height: 60)
    f.page.widgetFrame = { widget }
    f.page.outsidePress(CGPoint(x: widget.midX, y: widget.midY), eventType: .leftMouseDown)
    f.page.setAttached(false); f.page.setAttached(true)
    XCTAssertEqual(f.page.dismissal.request(.outsidePress), .closed, "the put back re-arms without the old press's hold")
  }

  /// Spec 1.3: while one of our menus is tracked nothing closes the attached cockpit.
  func testMenuTrackingHoldsTheCockpitOpen() throws {
    let f = try open()
    let menu = NSMenu()
    NotificationCenter.default.post(name: NSMenu.didBeginTrackingNotification, object: menu)
    XCTAssertEqual(f.page.dismissal.request(.outsidePress), .suppressed(.menuTracking))
    NotificationCenter.default.post(name: NSMenu.didEndTrackingNotification, object: menu)
    XCTAssertEqual(f.page.dismissal.request(.outsidePress), .closed)
  }

  /// Spec 2.6: with the app's source injected the page reacts to its signals and registers no wake/display observer
  /// of its own; discarding cancels the subscription.
  func testInjectedSystemSignalsDriveThePage() throws {
    var handler: (@MainActor (CockpitSystemSignal) -> Void)?
    var cancels = 0
    let f = try open(signals: { h in handler = h; return { cancels += 1 } })
    XCTAssertNotNil(handler, "the page subscribed at build")
    let window = try XCTUnwrap(f.page.window)
    let laidOut = window.frame
    window.setFrame(laidOut.offsetBy(dx: -40, dy: 0), display: false)
    handler?(.displaysChanged)
    XCTAssertEqual(window.frame, laidOut, "a display change lays the attached cockpit out again at once")
    window.setFrame(laidOut.offsetBy(dx: -40, dy: 0), display: false)
    handler?(.displaysSettled)
    XCTAssertEqual(window.frame, laidOut, "and once more on settled frames")
    handler?(.wake); handler?(.unlock); handler?(.clockChanged)
    f.page.discard()
    XCTAssertEqual(cancels, 1)
  }

  /// Spec 4.6: one presence for Settings and the detached cockpit. The attached cockpit never counts; closing
  /// Settings while detached keeps the Dock icon (the old Settings-only presence dropped it); a put back returns to
  /// accessory and the cockpit then ignores the resulting resign-active.
  func testOnePresenceForSettingsAndTheDetachedCockpit() throws {
    let f = try open()
    var clock: UInt64 = 10_000
    f.page.dismissalClock = { clock }
    var policy: NSApplication.ActivationPolicy = .accessory, log: [NSApplication.ActivationPolicy] = [], activations = 0
    let presence = PulseDockPresence(currentPolicy: { policy }, setPolicy: { value in
      f.page.suppressDismissal(.policyChange, forMilliseconds: EngineDockMenuApplication.policyChangeHoldMilliseconds)
      policy = value; log.append(value)
    }, activate: { activations += 1 })
    let cockpit = DetachedCockpitPresence(page: f.page), settings = FakeWindow()
    presence.track(cockpit); presence.track(settings)
    f.page.onPresenceChanged = { presence.apply(activateIfRegular: $0) }
    presence.apply()
    XCTAssertEqual(log, [], "an attached cockpit is a popover, not a window in the Dock")
    f.page.setAttached(false)
    XCTAssertEqual(log, [.regular]); XCTAssertEqual(activations, 1, "a user detach brings the app forward")
    settings.isVisible = true; presence.apply()
    XCTAssertEqual(log, [.regular], "Settings while detached: no flip")
    presence.apply(closing: settings); settings.isVisible = false
    XCTAssertEqual(log, [.regular], "closing Settings keeps the icon for the detached cockpit")
    f.page.setAttached(true)
    XCTAssertEqual(log, [.regular, .accessory], "put back: the icon goes")
    clock += EngineDockMenuApplication.policyChangeHoldMilliseconds - 1
    XCTAssertEqual(f.page.dismissal.request(.appResigned), .suppressed(.policyChange), "the flip's own resign does not close it")
    XCTAssertNotNil(f.page.window)
    clock += 1
    XCTAssertEqual(f.page.dismissal.request(.appResigned), .closed, "after 250 ms a resign closes it again")
  }

  /// B6 (owner 11-21): a menu-bar app shows no Dock icon beside the attached cockpit. The icon follows the one
  /// presence (Pulse DockPresence: while Settings or a detached cockpit is open). Fails before: an attached open never
  /// re-read the presence, so a policy left regular by a window that went away without telling it stayed regular.
  func testAnAttachedOpenDropsAStaleDockIcon() throws {
    var policy: NSApplication.ActivationPolicy = .accessory, activations = 0
    let presence = PulseDockPresence(currentPolicy: { policy }, setPolicy: { policy = $0 }, activate: { activations += 1 })
    let settings = FakeWindow(); presence.track(settings)
    settings.isVisible = true; presence.apply()
    XCTAssertEqual(policy, .regular, "Settings open: the Dock icon (Pulse)")
    settings.isVisible = false // it left the screen without a close notification: the presence was not told
    XCTAssertEqual(policy, .regular, "stale")
    var adapter: DetachedCockpitPresence?
    let f = try open(beforeOpen: { page in
      adapter = DetachedCockpitPresence(page: page); presence.track(adapter!)
      page.onPresenceChanged = { presence.apply(activateIfRegular: $0) }
    })
    defer { withExtendedLifetime(adapter) {} }
    XCTAssertTrue(f.page.isAttached)
    XCTAssertEqual(policy, .accessory, "the attached cockpit opens with no Dock icon")
    XCTAssertEqual(activations, 0, "an attached open never activates the app through the presence")
    // Settings really open: the attached open keeps the icon (Pulse shows it while Settings is on screen).
    settings.isVisible = true; presence.apply()
    f.page.requestClose()
    let g = try open(beforeOpen: { page in page.onPresenceChanged = { presence.apply(activateIfRegular: $0) } })
    XCTAssertTrue(g.page.isAttached)
    XCTAssertEqual(policy, .regular)
  }
}
