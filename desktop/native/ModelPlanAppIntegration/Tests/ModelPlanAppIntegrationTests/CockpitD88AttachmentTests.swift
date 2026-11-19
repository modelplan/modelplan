// SPDX-License-Identifier: MIT
import AppKit
import WebKit
import XCTest
@testable import ModelPlanCockpitWeb

/// D88 (owner, 2026-11-09): the cockpit belongs to the menu bar icon by default. Attached: a drag of the title
/// strip also detaches and an outside click closes it; an open from the icon is the launch rack's (CKP-SHELL-33,
/// covered in CockpitLaunchRackEntryTests). Detached: an outside click keeps it, and the put-back key (or a drop near
/// the icon) puts it back. The real panel and controller on the real screen, placed under a menu-bar-sized anchor; the
/// page is a synthetic document, so the strip keys' messages are covered by the bridge contract and the page
/// tests, and here the controller receives the intents they map to. Window server: GUI leg.
@MainActor final class CockpitD88AttachmentTests: XCTestCase {
  private struct Fixture {
    let page: CockpitWindowController, session: CockpitShellSession, icon: CGRect, usable: CGRect, screenWidth: CGFloat
    /// The controller's own fit (Auto size judged on the full screen width); whole points, as the window server keeps them.
    var home: CGRect? { CockpitShellLayout.fit(usable: usable, anchor: icon, shutterClosed: false, screenWidth: screenWidth)?.frame }
  }
  private var failures: [CockpitWindowFailure] = []

  private func bundle() throws -> VerifiedCockpitBundle {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("cockpit-d88-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: root) }
    let html = Data("synthetic".utf8); try html.write(to: root.appendingPathComponent("index.html"))
    let manifest = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "edition": "community", "interfaceOnly": true, "files": ["index.html": VerifiedCockpitBundle.digest(html)]])
    try manifest.write(to: root.appendingPathComponent("bundle-manifest.json"))
    return try VerifiedCockpitBundle(root: root, manifestSHA256: VerifiedCockpitBundle.digest(manifest))
  }
  private func make(reduceMotion: Bool) throws -> Fixture {
    _ = NSApplication.shared
    guard let screen = NSScreen.main else { throw XCTSkip("needs a display") }
    let usable = screen.visibleFrame
    // A status item's frame: in the menu bar, above the usable area.
    let icon = CGRect(x: usable.midX - 14, y: usable.maxY, width: 28, height: max(1, screen.frame.maxY - usable.maxY))
    let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic", generation: 1)
    let session = CockpitShellSession()
    let page = CockpitWindowController(bundle: try bundle(), context: context,
      appearance: .init(theme: .night, locale: .en, profile: .full, reduceMotion: reduceMotion),
      shellSession: session, anchor: { icon })
    page.onFailure = { [weak self] in self?.failures.append($0) }
    return Fixture(page: page, session: session, icon: icon, usable: usable, screenWidth: screen.frame.width)
  }
  /// Opens the way the console does: the entrance is set on the shared shell session just before open().
  private func openPage(_ fixture: Fixture, entrance: CockpitEntrance) throws -> NSWindow {
    fixture.session.nextEntrance = entrance
    fixture.page.open()
    let window = try XCTUnwrap(fixture.page.window)
    // The synthetic document is not the cockpit page; its own load must not reach the controller.
    (window.contentView?.subviews.first as? WKWebView)?.navigationDelegate = nil
    return window
  }
  private func titles(_ page: CockpitWindowController) -> [String] { page.contextMenu()?.items.map(\.title) ?? [] }
  private func outside(_ fixture: Fixture) -> CGPoint { .init(x: fixture.usable.minX + 2, y: fixture.usable.minY + 2) }

  /// Attached: under the icon (its left shoulder, CKP-SHELL-33), the right-click menu is the app's own (Detach, never Reload), the key
  /// anchors the one-time hint, and a click outside closes it the way a menu closes.
  func testD88AttachedOffersDetachAndAnOutsideClickClosesIt() throws {
    let fixture = try make(reduceMotion: true)
    defer { fixture.page.discard() }
    let window = try openPage(fixture, entrance: .fade)
    let home = try XCTUnwrap(fixture.home)
    XCTAssertTrue(fixture.page.isAttached)
    XCTAssertEqual(window.frame, home)
    XCTAssertEqual(titles(fixture.page), ["Detach"])
    let anchor = try XCTUnwrap(fixture.page.attachmentHintAnchor, "the detach key anchors the one-time hint")
    XCTAssertTrue(anchor.attached); XCTAssertTrue(window.frame.contains(anchor.frame))
    fixture.page.outsidePress(outside(fixture), eventType: .leftMouseDown)
    XCTAssertNil(fixture.page.window, "an outside click closes the attached cockpit (at once with Reduce Motion)")
    XCTAssertEqual(failures, [])
  }

  /// A drag of the title strip detaches: the window follows the pointer, and the drop reports the detach once.
  func testD88DraggingTheTitleStripDetaches() throws {
    let fixture = try make(reduceMotion: true)
    defer { fixture.page.discard() }
    let window = try openPage(fixture, entrance: .fade)
    let start = window.frame
    var changes = 0
    fixture.page.onShellChanged = { changes += 1 }
    // Sideways, where the screen has room, so the clamp to the usable area does not move it.
    let dx: CGFloat = start.minX - fixture.usable.minX > 150 ? -150 : 150
    let grab = CGPoint(x: start.minX + 120, y: start.maxY - 16)
    let to = CGPoint(x: grab.x + dx, y: grab.y)
    fixture.page.titleDrag(.began, point: grab)
    fixture.page.titleDrag(.moved, point: to)
    XCTAssertFalse(fixture.page.isAttached, "the drag detaches")
    XCTAssertEqual(window.frame.minX, start.minX + dx, accuracy: 0.5, "the window follows the pointer")
    XCTAssertEqual(changes, 0, "no shell change on each drag step")
    fixture.page.titleDrag(.ended, point: to)
    XCTAssertFalse(fixture.page.isAttached)
    XCTAssertEqual(changes, 1, "the drop reports the detach once")
    XCTAssertEqual(titles(fixture.page), ["Put back"])
    XCTAssertEqual(fixture.page.attachmentHintAnchor?.attached, false, "the put-back key anchors its hint")
    XCTAssertEqual(failures, [])
  }

  /// Detached by the key: it moves out of the catch zone to a place fully on screen (D187), an outside click keeps the
  /// window, and the put-back key returns it under the icon. The one right-click item does the same.
  func testD88DetachKeyThenPutBackKey() throws {
    let fixture = try make(reduceMotion: true)
    defer { fixture.page.discard() }
    let window = try openPage(fixture, entrance: .fade)
    let start = window.frame, home = try XCTUnwrap(fixture.home)
    fixture.page.setAttached(false) // the detach key's intent
    XCTAssertFalse(fixture.page.isAttached)
    XCTAssertGreaterThan(hypot(window.frame.minX - start.minX, window.frame.maxY - start.maxY), 40, "out of the catch zone")
    XCTAssertTrue(fixture.usable.contains(window.frame), "fully on screen")
    XCTAssertEqual(titles(fixture.page), ["Put back"])
    window.setFrame(start.offsetBy(dx: 0, dy: -100), display: true)
    fixture.page.outsidePress(outside(fixture), eventType: .leftMouseDown)
    XCTAssertNotNil(fixture.page.window, "a detached cockpit stays open on an outside click")
    fixture.page.setAttached(true) // the put-back key's intent
    XCTAssertTrue(fixture.page.isAttached, "the put-back key re-attaches")
    XCTAssertEqual(window.frame, home, "back under the icon")
    XCTAssertEqual(titles(fixture.page), ["Detach"])
    // CI 11-10: the item's action resolved to NSObject's performSelector: and AppKit sent the item as a selector.
    let detach = try XCTUnwrap(fixture.page.contextMenu())
    XCTAssertEqual(detach.items.first?.action.map(NSStringFromSelector), "cockpitAttachmentItemChosen:")
    detach.performActionForItem(at: 0)
    XCTAssertFalse(fixture.page.isAttached, "the menu item detaches")
    let putBack = try XCTUnwrap(fixture.page.contextMenu())
    putBack.performActionForItem(at: 0)
    XCTAssertTrue(fixture.page.isAttached, "and puts back")
    XCTAssertEqual(failures, [])
  }

  /// A re-open during the rack's reverse close must stop it and present at the layout frame, not where the close took it.
  func testD88ReopenDuringTheShrinkPresentsAtTheLayoutFrame() async throws {
    let fixture = try make(reduceMotion: false)
    defer { fixture.page.discard() }
    let window = try openPage(fixture, entrance: .fromIcon)
    let home = try XCTUnwrap(fixture.home)
    try await Task.sleep(for: .milliseconds(800))
    fixture.page.requestClose()
    try await Task.sleep(for: .milliseconds(80))
    fixture.page.open()
    try await Task.sleep(for: .milliseconds(400))
    XCTAssertEqual(fixture.page.window?.frame, home, "it presents at the layout frame")
    XCTAssertEqual(window.alphaValue, 1)
    XCTAssertEqual(failures, [])
  }

  /// Reduce Motion opens at once at full size, and the widget ignition keeps its own fade instead of the rack-first open.
  func testD88GrowIsSkippedUnderReduceMotionAndForTheIgnition() async throws {
    let reduced = try make(reduceMotion: true)
    defer { reduced.page.discard() }
    let still = try openPage(reduced, entrance: .fromIcon)
    XCTAssertEqual(still.frame, try XCTUnwrap(reduced.home), "Reduce Motion: no rack-first open")
    XCTAssertEqual(still.alphaValue, 1, "and no fade")
    reduced.page.requestClose()
    XCTAssertNil(reduced.page.window, "and the close is instant")

    let ignition = try make(reduceMotion: false)
    defer { ignition.page.discard() }
    let faded = try openPage(ignition, entrance: .fade)
    let home = try XCTUnwrap(ignition.home)
    XCTAssertEqual(faded.frame, home, "the ignition entrance never starts at the icon")
    ignition.page.requestClose()
    try await Task.sleep(for: .milliseconds(60))
    XCTAssertEqual(ignition.page.window?.frame ?? home, home, "and its close does not move it under the menu bar")
  }

  /// G3-55 stays: WebKit's own items never show, and the app's menu (with Detach / Put back on top) comes from the controller.
  func testD88RightClickMenuIsTheAppsOwnWithoutReload() throws {
    let view = CockpitWebView(frame: .zero, configuration: WKWebViewConfiguration())
    let event = try XCTUnwrap(NSEvent.mouseEvent(with: .rightMouseDown, location: .zero, modifierFlags: [], timestamp: 0,
      windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
    XCTAssertNil(view.menu(for: event), "the view never hands WebKit a menu of its own")
    let webKit = NSMenu()
    for title in ["Reload", "Back", "Inspect Element"] { webKit.addItem(withTitle: title, action: nil, keyEquivalent: "") }
    view.willOpenMenu(webKit, with: event)
    XCTAssertEqual(webKit.items.map(\.title), [], "no Reload or other WebKit item")
  }
}
