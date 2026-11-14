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
    XCTAssertNotEqual(home.frame.size, away.frame.size, "the two displays need different layouts")
    let from = CGPoint(x: window.frame.minX + 60, y: window.frame.maxY - 30)
    page.titleDrag(.began, point: from)
    page.titleDrag(.moved, point: CGPoint(x: from.x + 40, y: from.y))
    page.titleDrag(.moved, point: CGPoint(x: 2800, y: 900))
    page.titleDrag(.ended, point: CGPoint(x: 2800, y: 900))
    XCTAssertFalse(page.isAttached)
    XCTAssertEqual(page.verificationLayout?.frame.size, away.frame.size, "dropped on the tall display, laid out for it")
    page.setAttached(true) // the put-back key's intent, with motion
    XCTAssertTrue(page.isAttached)
    XCTAssertEqual(page.verificationLayout?.profile, home.profile, "the icon's display's profile")
    XCTAssertEqual(page.verificationLayout?.frame, home.frame)
    XCTAssertEqual(page.verificationWebView?.pageZoom ?? 0, home.scale, accuracy: 0.0001, "and its zoom")
    XCTAssertEqual(page.verificationDragRegion?.frame, home.scaledTitleDragFrame, "and its drag strip")
    try await Task.sleep(for: .milliseconds(500))
    XCTAssertEqual(window.frame, home.frame, "the window settles under the icon")
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
