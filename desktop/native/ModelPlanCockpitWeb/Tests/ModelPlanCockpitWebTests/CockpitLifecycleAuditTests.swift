// SPDX-License-Identifier: MIT
#if MODELPLAN_TEST_ONLY_SPI
import AppKit
import Foundation
import WebKit
import XCTest
import ModelPlanWire
@testable import ModelPlanCockpitWeb

/// Audit A (cockpit window and page lifecycle, 11-11): the real controller and panel through their normal entries
/// (the local press monitor's handler, the strip's mouse events, the put-back key's intent, Settings, open and close).
/// The page is a synthetic document whose own load is detached; page replies arrive through the controller's
/// receive seam and outbound calls through its delivery seam. Window server: GUI leg.
@MainActor final class CockpitLifecycleAuditTests: XCTestCase {
  private let source = CockpitMessageSource(mainFrame: true, origin: "modelplan-cockpit://bundle")
  private var failures: [CockpitWindowFailure] = []

  private func bundle() throws -> VerifiedCockpitBundle {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("cockpit-audit-a-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: root) }
    let html = Data("<!doctype html><title>synthetic</title>".utf8)
    try html.write(to: root.appendingPathComponent("index.html"))
    try html.write(to: root.appendingPathComponent("field.html"))
    let manifest = try JSONSerialization.data(withJSONObject: [
      "schemaVersion": 1, "edition": "community", "interfaceOnly": true,
      "files": ["index.html": VerifiedCockpitBundle.digest(html), "field.html": VerifiedCockpitBundle.digest(html)],
    ])
    try manifest.write(to: root.appendingPathComponent("bundle-manifest.json"))
    return try VerifiedCockpitBundle(root: root, manifestSHA256: VerifiedCockpitBundle.digest(manifest))
  }
  private func page(_ bundle: VerifiedCockpitBundle, reduceMotion: Bool, icon: CGRect?, session: CockpitShellSession? = nil) throws -> CockpitWindowController {
    _ = NSApplication.shared
    let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic", generation: 1)
    let page = CockpitWindowController(bundle: bundle, context: context,
      appearance: .init(theme: .night, locale: .en, profile: .full, reduceMotion: reduceMotion), shellSession: session, anchor: { icon })
    page.onFailure = { [weak self] in self?.failures.append($0) }
    return page
  }
  /// A status item's frame on the main display's menu bar.
  private func menuBarIcon() throws -> CGRect {
    guard let screen = NSScreen.main else { throw XCTSkip("needs a display") }
    let usable = screen.visibleFrame
    return CGRect(x: usable.midX - 14, y: usable.maxY, width: 28, height: max(1, screen.frame.maxY - usable.maxY))
  }
  private func reply(_ raw: String, type: String, sequence: Int) throws -> String {
    var value = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
    for key in ["data", "appearance", "shell", "theme", "locale", "reduceMotion", "reduceTransparency", "showProjectNames", "redBelow", "showUsedPercent", "showAllModels", "pinnedModels", "ackedCautions", "nowUnixMs", "reason"] { value[key] = nil }
    value["type"] = type; value["sequence"] = String(sequence)
    if type == "ready" { value["appearanceVersion"] = 2; value["capabilities"] = ["appearanceUpdates", "shellState", "shellActions"] }
    return String(decoding: try JSONSerialization.data(withJSONObject: value), as: UTF8.self)
  }
  private func fixture() throws -> WireCockpitData {
    let url = try XCTUnwrap(Bundle.module.url(forResource: "cockpit", withExtension: "json", subdirectory: "Fixtures"))
    return try JSONDecoder().decode(WireCockpitData.self, from: Data(contentsOf: url))
  }
  /// The page's own load must not reach the controller; the test plays the page.
  private func detachSyntheticLoad(_ page: CockpitWindowController) { page.verificationWebView?.navigationDelegate = nil }
  private func readyReply(_ page: CockpitWindowController) throws {
    let shell = CockpitShellState(closed: false, attached: true, forcedClosed: false, tier: .tall)
    let load = try page.bridge.load(.init(theme: .night, locale: .en, profile: .full), shell: shell)
    page.verificationReceive(try reply(load, type: "ready", sequence: 1), source: source)
  }

  /// Post-merge 887: a bundle admitted earlier whose index.html is gone when the page loads fails as a bundle problem
  /// (`bundleResource`), not as a generic navigation failure, so the notice can ask for a reinstall.
  func testABundledFileThatDisappearsAfterAdmissionFailsAsABundleResource() async throws {
    guard NSScreen.main != nil else { throw XCTSkip("needs a display") }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("cockpit-bundle-gone-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: root) }
    let html = Data("<!doctype html><title>synthetic</title>".utf8)
    try html.write(to: root.appendingPathComponent("index.html"))
    let manifest = try JSONSerialization.data(withJSONObject: [
      "schemaVersion": 1, "edition": "community", "interfaceOnly": true, "files": ["index.html": VerifiedCockpitBundle.digest(html)],
    ])
    try manifest.write(to: root.appendingPathComponent("bundle-manifest.json"))
    let admitted = try VerifiedCockpitBundle(root: root, manifestSHA256: VerifiedCockpitBundle.digest(manifest))
    try FileManager.default.removeItem(at: root.appendingPathComponent("index.html"))
    let page = try page(admitted, reduceMotion: true, icon: nil)
    addTeardownBlock { @MainActor in page.discard() }
    page.open()
    for _ in 0..<500 where failures.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
    XCTAssertEqual(failures, [.bundleResource])
  }

  /// Finding 1 (P1): a press on the enlarged field, outside the smaller cockpit under it, reached the cockpit's
  /// local press monitor as an outside click and closed the cockpit (and, through the console, the field).
  func testAPressOnTheEnlargedFieldDoesNotCloseTheAttachedCockpit() throws {
    let icon = try menuBarIcon()
    let bundle = try bundle()
    let page = try page(bundle, reduceMotion: true, icon: icon)
    defer { page.discard() }
    page.open(); detachSyntheticLoad(page)
    XCTAssertTrue(page.isAttached)
    let cockpit = try XCTUnwrap(page.window).frame
    let field = CockpitFieldPanel(bundle: bundle)
    field.open(payload: "{}", near: cockpit)
    defer { field.close() }
    let fieldWindow = try XCTUnwrap(field.verificationWindow)
    XCTAssertEqual(fieldWindow.identifier, CockpitWindowController.fieldWindowIdentifier)
    let f = fieldWindow.frame
    let press = try XCTUnwrap([CGPoint(x: f.minX + 4, y: f.midY), CGPoint(x: f.maxX - 4, y: f.midY), CGPoint(x: f.minX + 4, y: f.minY + 4)]
      .first { !cockpit.contains($0) }, "the field is wider than the cockpit")
    page.localPress(in: fieldWindow, at: press, eventType: .leftMouseDown)
    XCTAssertNotNil(page.window, "a press on the field it opened keeps the attached cockpit")
    XCTAssertTrue(field.isOpen)
    page.localPress(in: nil, at: press, eventType: .leftMouseDown)
    XCTAssertNil(page.window, "a press on bare desktop still closes it (at once with Reduce Motion)")
    XCTAssertEqual(failures, [])
  }

  /// Finding 2 (P2): a close drops a display still queued behind an in-flight call. A re-open during the fade confirms
  /// visibility on the same, already-shown page; it must then ask for fresh data instead of waiting for the dropped one.
  func testReopeningDuringTheCloseFadeAsksForTheDisplayTheCloseDropped() async throws {
    let icon = try menuBarIcon()
    let page = try page(try bundle(), reduceMotion: false, icon: icon)
    defer { page.discard() }
    var sent: [(raw: String, complete: (CockpitDeliveryResult) -> Void)] = [], delivered = 0
    page.verificationNoWindowClock = { 1_000 }
    page.verificationNoWindowArm = { _, _ in {} }
    page.verificationNoWindowDelivery = { raw, complete in sent.append((raw, complete)) }
    func drain() { while delivered < sent.count { delivered += 1; sent[delivered - 1].complete(.accepted) } }
    var shown = 0
    page.onShown = { shown += 1 }
    page.open(); detachSyntheticLoad(page)
    let window = try XCTUnwrap(page.window)
    for _ in 0..<150 where !window.occlusionState.contains(.visible) { try await Task.sleep(for: .milliseconds(20)) }
    guard window.occlusionState.contains(.visible) else { throw XCTSkip("the window server reports the panel occluded") }
    try readyReply(page); drain()
    XCTAssertEqual(shown, 1, "the open is confirmed visible")
    var sequence = 1
    page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket)); let first = try XCTUnwrap(sent.last).raw; drain()
    sequence += 1; page.verificationReceive(try reply(first, type: "rendered", sequence: sequence), source: source); drain()
    // A display is in flight (its completion held back) and a newer one waits behind it.
    page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket))
    let held = sent.count - 1; delivered = sent.count
    page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket))
    XCTAssertEqual(sent.count, held + 1, "the newer display is queued, not delivered")
    var refreshes = 0
    page.onReady = { refreshes += 1 }
    page.requestClose()
    page.open() // during the fade
    sent[held].complete(.accepted) // the held call finishes; the visibility message follows it
    drain()
    XCTAssertEqual(refreshes, 1, "the re-open asks the engine again for the display the close dropped")
    XCTAssertNotNil(page.window)
    XCTAssertEqual(failures, [])
  }

  /// Finding 3 (P2): an animated put back from a taller display moved only the window frame; the page kept the tall
  /// display's profile, zoom and drag strip inside the short display's frame.
  func testAnAnimatedPutBackLaysOutForTheIconsDisplay() async throws {
    let short = CockpitScreen(frame: CGRect(x: 0, y: 0, width: 1280, height: 720), visibleFrame: CGRect(x: 0, y: 0, width: 1280, height: 695))
    let tall = CockpitScreen(frame: CGRect(x: 1280, y: 0, width: 2560, height: 1440), visibleFrame: CGRect(x: 1280, y: 0, width: 2560, height: 1415))
    let icon = CGRect(x: 1100, y: 695, width: 28, height: 24)
    let page = try page(try bundle(), reduceMotion: false, icon: icon)
    let displays = [short, tall]
    page.screens = { displays }
    page.prewarm(); detachSyntheticLoad(page) // the headless synthetic load fails (javascriptFailed) and discards the window otherwise
    defer { page.discard() }
    let window = try XCTUnwrap(page.window)
    let home = try XCTUnwrap(CockpitShellLayout.fit(usable: short.visibleFrame, anchor: icon, shutterClosed: false, screenWidth: short.frame.width))
    let away = try XCTUnwrap(CockpitShellLayout.fit(usable: tall.visibleFrame, anchor: CockpitShellLayout.hiddenIconAnchor(usable: tall.visibleFrame),
                                                   shutterClosed: false, screenWidth: tall.frame.width))
    XCTAssertNotEqual(home.frame.size, away.frame.size, "each display alone would get a different layout")
    let from = CGPoint(x: window.frame.minX + 60, y: window.frame.maxY - 30)
    page.titleDrag(.began, point: from)
    page.titleDrag(.moved, point: CGPoint(x: from.x + 40, y: from.y))
    page.titleDrag(.moved, point: CGPoint(x: 2800, y: 900))
    page.titleDrag(.ended, point: CGPoint(x: 2800, y: 900))
    XCTAssertFalse(page.isAttached)
    // G3-132 (owner, 11-18): one size on every display, the smallest's; the drop on the tall display keeps it.
    XCTAssertEqual(page.verificationLayout?.frame.size, home.frame.size, "dropped on the tall display, still the short display's size")
    XCTAssertEqual(page.verificationLayout?.profile, home.profile)
    XCTAssertTrue(tall.visibleFrame.contains(window.frame), "inside the tall display")
    let settled = expectation(description: "The rack flight completed and the cockpit latched")
    page.verificationLayoutAnimationCompleted = { settled.fulfill() }
    page.setAttached(true) // the put-back key starts the rack flight
    XCTAssertEqual(page.verificationLayout?.profile, home.profile, "the icon's display's profile, committed at the press")
    // G3-132: the drop kept the common size, so the press has no new layout to commit; the attached place (the layout's
    // origin) comes with the latch, below (macrevb-1038-4).
    XCTAssertEqual(page.verificationLayout?.frame.size, home.frame.size)
    XCTAssertEqual(page.verificationWebView?.pageZoom ?? 0, home.scale, accuracy: 0.0001, "and its zoom")
    XCTAssertEqual(page.verificationDragRegion?.frame, home.scaledTitleDragFrame, "and its drag strip")
    // Wait for the actual flight and rack latch; a fixed delay can observe an intermediate frame on a busy Mac.
    await fulfillment(of: [settled], timeout: 5)
    XCTAssertTrue(page.isAttached, "caught by the rack and latched")
    XCTAssertEqual(window.frame, home.frame, "the window settles under the icon")
    XCTAssertEqual(page.verificationLayout?.frame, home.frame, "and the layout is the attached one")
    XCTAssertEqual(window.contentView?.bounds.size, home.frame.size, "with the page canvas of that layout")
    XCTAssertEqual(failures, [])
  }

  /// G3-102 (build 14e): a detached cockpit stayed above every other app. Attached floats over the widget (D49);
  /// detached is a normal window; putting it back floats it again. Through the strip's drag entry and the put-back.
  func testADetachedCockpitIsANormalWindowAndAnAttachedOneFloats() throws {
    let page = try page(try bundle(), reduceMotion: true, icon: try menuBarIcon())
    page.prewarm(); detachSyntheticLoad(page)
    defer { page.discard() }
    let window = try XCTUnwrap(page.window)
    XCTAssertEqual(window.level, CockpitWindowController.panelLevel, "attached: above the widget")
    let from = CGPoint(x: window.frame.minX + 60, y: window.frame.maxY - 30)
    page.titleDrag(.began, point: from)
    page.titleDrag(.moved, point: CGPoint(x: from.x + 80, y: from.y - 300))
    page.titleDrag(.ended, point: CGPoint(x: from.x + 80, y: from.y - 300))
    XCTAssertFalse(page.isAttached)
    XCTAssertEqual(window.level, .normal, "detached: other apps can cover it")
    page.setAttached(true)
    XCTAssertEqual(window.level, CockpitWindowController.panelLevel, "put back: floats again")
  }

  /// The host as EngineDockMenuApplication and PulseDockPresence play it: regular while the detached cockpit (or
  /// Settings) is shown, accessory otherwise, a 250 ms policy hold on each flip, and the flip's resign. The test process
  /// is never the active app, so the activation, policy and key facts come through the controller's SPI seams.
  private final class PutBackHost {
    enum Resign { case immediate, later }
    var active = true, activations = 0, regular = false, settingsOpen = false, commandHeld = false
    var resign = Resign.later
    /// G3-129: when set, the flip to regular (a detach) deactivates the app too, at once or a moment later.
    var regularFlipResigns: Resign?
    /// The controller's injected clock (dismissal holds and the recovery window run on it); the test advances it.
    var now: UInt64 = 1_000
    var sent: [(raw: String, complete: (CockpitDeliveryResult) -> Void)] = [], delivered = 0
    var sequence = 1
    func drain() { while delivered < sent.count { delivered += 1; sent[delivered - 1].complete(.accepted) } }
    func lastKey() -> Bool? {
      for entry in sent.reversed() {
        let value = (try? JSONSerialization.jsonObject(with: Data(entry.raw.utf8))) as? [String: Any]
        if value?["type"] as? String == "visibility" { return value?["key"] as? Bool }
      }
      return nil
    }
    func resignActive() {
      active = false
      NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: NSApplication.shared)
    }
  }
  /// Opens the cockpit, tears it off with the strip drag and drops it away from the catch zone, and returns with the
  /// detached cockpit shown and the page ready; `press` sends the page's actions.
  private func detachedByDrag(_ app: PutBackHost, reduceMotion: Bool = true) async throws -> (page: CockpitWindowController, press: (String) throws -> Void) {
    let page = try page(try bundle(), reduceMotion: reduceMotion, icon: try menuBarIcon())
    addTeardownBlock { @MainActor in page.discard() }
    if app.settingsOpen { app.regular = true }
    page.verificationNoWindowClock = { app.now }
    page.verificationNoWindowArm = { _, _ in {} }
    page.verificationNoWindowDelivery = { raw, complete in app.sent.append((raw, complete)) }
    page.verificationApplicationActive = { app.active }
    page.verificationApplicationRegular = { app.regular }
    page.verificationCommandHeld = { app.commandHeld }
    page.verificationActivateApplication = { app.active = true; app.activations += 1 }
    page.onPresenceChanged = { [weak page] userInitiated in
      guard let page else { return }
      let wantsRegular = app.settingsOpen || (!page.isAttached && page.window?.isVisible == true)
      guard wantsRegular != app.regular else { return }
      app.regular = wantsRegular
      page.suppressDismissal(.policyChange, forMilliseconds: 250)
      if wantsRegular, app.regularFlipResigns == nil { if userInitiated { app.active = true }; return }
      switch wantsRegular ? app.regularFlipResigns ?? app.resign : app.resign {
      case .immediate: app.active = false; NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: NSApplication.shared)
      case .later: Task { @MainActor in app.resignActive() }
      }
    }
    page.open(); detachSyntheticLoad(page)
    let window = try XCTUnwrap(page.window)
    for _ in 0..<150 where !window.occlusionState.contains(.visible) { try await Task.sleep(for: .milliseconds(20)) }
    guard window.occlusionState.contains(.visible) else { throw XCTSkip("the window server reports the panel occluded") }
    let shell = CockpitShellState(closed: false, attached: true, forcedClosed: false, tier: .tall)
    let load = try page.bridge.load(.init(theme: .night, locale: .en, profile: .full), shell: shell)
    page.verificationReceive(try reply(load, type: "ready", sequence: app.sequence), source: source); app.drain()
    XCTAssertEqual(app.lastKey(), true, "opened: the page is key")
    let press: (String) throws -> Void = { [unowned self] action in
      app.sequence += 1
      var value = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(try self.reply(load, type: "action", sequence: app.sequence).utf8)) as? [String: Any])
      value["action"] = action; value["requestId"] = UUID().uuidString
      page.verificationReceive(String(decoding: try JSONSerialization.data(withJSONObject: value), as: UTF8.self), source: self.source)
    }
    let grab = CGPoint(x: window.frame.minX + 120, y: window.frame.maxY - 16)
    page.titleDrag(.began, point: grab)
    page.titleDrag(.moved, point: CGPoint(x: grab.x + 40, y: grab.y - 120))
    page.titleDrag(.moved, point: CGPoint(x: grab.x + 80, y: grab.y - 300))
    page.titleDrag(.ended, point: CGPoint(x: grab.x + 80, y: grab.y - 300))
    XCTAssertFalse(page.isAttached)
    XCTAssertTrue(app.regular, "detached: the app has its Dock icon")
    app.drain()
    return (page, press)
  }
  private func settle(_ app: PutBackHost, milliseconds: Int = 500) async throws {
    for _ in 0..<(milliseconds / 20) { try await Task.sleep(for: .milliseconds(20)); app.drain() }
  }

  /// G3-129 (owner, 11-18): a detached cockpit is a normal window, but just detached it comes to the front and is key,
  /// also when the flip to regular deactivates the app (at once, or with a resign a moment later). Before, nothing
  /// activated the app or ordered the window front after the level dropped to normal, so it sat behind the front app.
  /// Both entries: a strip drag's drop and the detach key, the latter with another normal window in front.
  func testAJustDetachedCockpitComesToTheFrontAndIsKey() async throws {
    for resign in [PutBackHost.Resign.immediate, .later] {
      let app = PutBackHost(); app.regularFlipResigns = resign
      let (page, press) = try await detachedByDrag(app)
      try await settle(app, milliseconds: 300)
      let window = try XCTUnwrap(page.window)
      XCTAssertEqual(window.level, .normal, "\(resign): detached, a normal window")
      XCTAssertTrue(app.active, "\(resign): the drop leaves the app active")
      XCTAssertEqual(app.activations, 1, "\(resign): one activation answers the flip")
      XCTAssertEqual(app.lastKey(), true, "\(resign): the page is key")

      // Put back, cover the cockpit's place with another normal window, then the detach key.
      try press("putBack"); try await settle(app, milliseconds: 300)
      XCTAssertTrue(page.isAttached)
      let cover = NSWindow(contentRect: window.frame.insetBy(dx: -40, dy: -40), styleMask: [.titled], backing: .buffered, defer: false)
      cover.isReleasedWhenClosed = false
      defer { cover.orderOut(nil) }
      cover.orderFront(nil)
      app.active = true; app.activations = 0
      page.setAttached(false)
      try await settle(app, milliseconds: 300)
      XCTAssertFalse(page.isAttached)
      XCTAssertEqual(window.level, .normal, "\(resign): the detach key gives a normal window too")
      XCTAssertEqual(app.activations, 1, "\(resign): the detach key's flip is answered once")
      XCTAssertEqual(app.lastKey(), true, "\(resign): and the page is key")
      // macrevb-1038-4: `orderedIndex` gave NSNotFound for the cockpit panel on the hosted Mac, so the front-to-back order comes from the window
      // server's list of this app's on-screen windows.
      let order = NSWindow.windowNumbers(options: [])?.map(\.intValue) ?? []
      let mine = try XCTUnwrap(order.firstIndex(of: window.windowNumber), "\(resign): the cockpit is on screen")
      let theirs = try XCTUnwrap(order.firstIndex(of: cover.windowNumber), "\(resign): the cover is on screen")
      XCTAssertLessThan(mine, theirs, "\(resign): in front of the other window")
      XCTAssertNotNil(page.window, "\(resign): nothing closed it")
    }
  }

  /// Walkthrough 11-17 (build b2b50b34, #977 regression): detach, drag the detached window, put it back with the page's
  /// key, then press the page's Close once. The put back flipped the app to accessory, macOS resigned it a moment later,
  /// the page was told `key: false` and the Close press was dropped.
  func testThePagesCloseWorksOnTheFirstPressAfterADragAndAPutBack() async throws {
    for resign in [PutBackHost.Resign.later, .immediate] {
      let app = PutBackHost(); app.resign = resign
      let (page, press) = try await detachedByDrag(app)
      let rejectedBefore = page.rejectedBridgeMessageCount
      try press("putBack"); app.drain()
      XCTAssertEqual(page.rejectedBridgeMessageCount, rejectedBefore, "\(resign): the put-back press is accepted")
      XCTAssertTrue(page.isAttached)
      XCTAssertFalse(app.regular, "attached: back to accessory")
      try await settle(app, milliseconds: 300)
      XCTAssertTrue(app.active, "\(resign): the put back leaves the app active")
      XCTAssertEqual(app.activations, 1, "\(resign): one activation answers the flip")
      XCTAssertEqual(app.lastKey(), true, "\(resign): the page is key again, so its next press counts")
      XCTAssertNotNil(page.window, "\(resign): the flip's resign did not close the attached cockpit")
      let rejected = page.rejectedBridgeMessageCount
      try press("close")
      XCTAssertEqual(page.rejectedBridgeMessageCount, rejected, "\(resign): the Close press is accepted")
      XCTAssertNil(page.window, "\(resign): the first Close press closes the cockpit")
    }
    XCTAssertEqual(failures, [])
  }

  /// macrevd-1033-1: with Settings open the put back changes no policy, so a resign right after it is the user's own
  /// switch: nothing activates the app again and the attached cockpit closes as on any app switch.
  func testAPutBackWithoutAPolicyFlipDoesNotFightAnAppSwitch() async throws {
    let app = PutBackHost(); app.settingsOpen = true
    let (page, press) = try await detachedByDrag(app)
    try press("putBack"); app.drain()
    XCTAssertTrue(page.isAttached)
    XCTAssertTrue(app.regular, "Settings keeps the app regular")
    app.resignActive() // Cmd-Tab within the window
    try await settle(app, milliseconds: 100)
    XCTAssertEqual(app.activations, 0, "no activation against the user's switch")
    XCTAssertNil(page.window, "the switch closes the attached cockpit")
    XCTAssertEqual(failures, [])
  }

  /// macrevd-1033-1: once the flip has been answered, a genuine switch inside the window is not fought; nor is one the
  /// user starts (the Command key of Cmd-Tab) before the flip's resign could arrive.
  func testAGenuineSwitchAfterThePutBackIsNotFought() async throws {
    let answered = PutBackHost(); answered.resign = .immediate
    let first = try await detachedByDrag(answered)
    try first.press("putBack"); answered.drain()
    XCTAssertEqual(answered.activations, 1, "the immediate deactivation is answered at the latch")
    try await settle(answered, milliseconds: 300)
    answered.now += 300 // past the host's 250 ms policy hold, inside the 500 ms recovery window
    answered.resignActive()
    try await settle(answered, milliseconds: 100)
    XCTAssertEqual(answered.activations, 1, "no second activation for the user's switch")
    XCTAssertNil(first.page.window, "the switch closes the attached cockpit")

    let switching = PutBackHost(); switching.resign = .later
    let second = try await detachedByDrag(switching)
    try second.press("putBack")
    second.page.userSwitchesAway() // the Command key goes down before the flip's resign arrives
    try await settle(switching, milliseconds: 100)
    XCTAssertEqual(switching.activations, 0, "the switch the user started is not fought")
    XCTAssertFalse(switching.active)
    XCTAssertEqual(failures, [])
  }

  /// macrev2-1033-1: switch intent seen before the latch is not overwritten by it. Command held when Put back is
  /// pressed (Tab then needs no new Command event), and Command pressed and released during the flight: the flip's
  /// delayed resign is then the user's switch, and nothing activates the app again.
  func testASwitchStartedBeforeTheLatchIsNotFought() async throws {
    let held = PutBackHost(); held.resign = .later
    let first = try await detachedByDrag(held)
    held.commandHeld = true; first.page.userSwitchesAway() // Command goes down and stays down
    try first.press("putBack")
    XCTAssertTrue(first.page.isAttached)
    XCTAssertFalse(first.page.verificationPutBackArmed, "Command held at the latch: nothing armed")
    try await settle(held, milliseconds: 100) // the resign arrives
    XCTAssertEqual(held.activations, 0, "Cmd-Tab with Command held is not fought")
    XCTAssertFalse(held.active)

    let flight = PutBackHost(); flight.resign = .later
    let second = try await detachedByDrag(flight, reduceMotion: false)
    let latched = expectation(description: "the put-back flight latched")
    second.page.verificationLayoutAnimationCompleted = { latched.fulfill() }
    try second.press("putBack") // the flight starts
    XCTAssertFalse(second.page.isAttached, "still flying")
    second.page.userSwitchesAway() // Command pressed during the flight, released before the latch
    await fulfillment(of: [latched], timeout: 5)
    XCTAssertTrue(second.page.isAttached)
    XCTAssertFalse(second.page.verificationPutBackArmed, "the switch seen during the flight keeps the latch from arming")
    try await settle(flight, milliseconds: 100)
    XCTAssertEqual(flight.activations, 0, "the resign after the flight is the user's switch")
    XCTAssertFalse(flight.active)
    XCTAssertEqual(failures, [])
  }

  /// macrev2-1033-1: a press in another app (the global monitor's handler) records the switch before it returns, so the
  /// resign that click causes is not answered as the policy flip's even when it arrives before any queued work runs.
  func testAnOutsideClicksResignBeforeQueuedWorkIsNotFought() async throws {
    let app = PutBackHost(); app.resign = .later
    let (page, press) = try await detachedByDrag(app)
    try press("putBack")
    XCTAssertTrue(page.verificationPutBackArmed, "the flip armed recovery; its resign has not arrived yet")
    page.globalPress(eventType: .leftMouseDown) // the user clicks another app
    app.resignActive() // that click's resign, delivered before yielding to any queued task
    XCTAssertEqual(app.activations, 0, "the outside click's switch is not fought")
    try await settle(app, milliseconds: 100)
    XCTAssertEqual(app.activations, 0, "nor by the flip's later resign")
    XCTAssertFalse(app.active)
    XCTAssertEqual(failures, [])
  }

  /// glm-908-1 (P2): closing a detached cockpit keeps the session detached; a reopen before the prewarm builds a
  /// cold page through `open()` alone (no appearance update). That page is a normal window too.
  func testAColdReopenOfADetachedSessionIsANormalWindow() throws {
    let session = CockpitShellSession(); session.detached = true
    let page = try page(try bundle(), reduceMotion: true, icon: try menuBarIcon(), session: session)
    defer { page.discard() }
    page.open(); detachSyntheticLoad(page)
    let window = try XCTUnwrap(page.window)
    XCTAssertFalse(page.isAttached)
    XCTAssertEqual(window.level, .normal, "a cold detached reopen does not float over other apps")
  }

  /// Finding 4 (P2): the strip takes first responder on mouse-down; after the drag ends or is cancelled the page has
  /// the keyboard again, so Esc reaches the page instead of the finished drag.
  func testTheKeyboardReturnsToThePageAfterATitleDrag() throws {
    let page = try page(try bundle(), reduceMotion: true, icon: try menuBarIcon())
    page.prewarm(); detachSyntheticLoad(page)
    defer { page.discard() }
    let window = try XCTUnwrap(page.window)
    let web = try XCTUnwrap(page.verificationWebView)
    web.isHidden = false // a ready page shows its web view
    let strip = try XCTUnwrap(page.verificationDragRegion as? CockpitTitleDrag)
    func mouse(_ type: NSEvent.EventType) throws -> NSEvent {
      try XCTUnwrap(NSEvent.mouseEvent(with: type, location: CGPoint(x: strip.frame.midX, y: strip.frame.midY), modifierFlags: [], timestamp: 0,
        windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
    }
    func pageHasKeyboard() -> Bool { (window.firstResponder as? NSView)?.isDescendant(of: web) == true }
    strip.mouseDown(with: try mouse(.leftMouseDown))
    XCTAssertTrue(window.firstResponder === strip, "the strip holds the keyboard while it drags")
    strip.mouseUp(with: try mouse(.leftMouseUp))
    XCTAssertTrue(pageHasKeyboard(), "a finished drag gives the keyboard back to the page")
    strip.mouseDown(with: try mouse(.leftMouseDown))
    let escape = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
      context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53))
    strip.keyDown(with: escape)
    XCTAssertTrue(pageHasKeyboard(), "a cancelled drag gives it back too")
    XCTAssertEqual(failures, [])
  }

  /// Finding 6 (P2): Reduce Motion from Settings set every cockpit window to full opacity, including a prewarmed page
  /// warm-painting at alpha 0 (ordered in, ignoring the mouse), which then showed without an open.
  func testReduceMotionKeepsAPrewarmedPageHidden() throws {
    let page = try page(try bundle(), reduceMotion: false, icon: try menuBarIcon())
    page.verificationNoWindowDelivery = { _, _ in } // the page's replies are not needed here
    page.prewarm(); detachSyntheticLoad(page)
    defer { page.discard() }
    let window = try XCTUnwrap(page.window)
    try readyReply(page) // a ready page that was never opened starts its warm paint
    page.updateAppearance(.init(theme: .night, locale: .en, profile: .full, reduceMotion: true))
    XCTAssertEqual(window.alphaValue, 0, "a page nobody opened stays invisible")
    page.open()
    XCTAssertEqual(page.window?.alphaValue, 1, "the open shows it at once under Reduce Motion")
    XCTAssertEqual(failures, [])
  }
}
#endif
