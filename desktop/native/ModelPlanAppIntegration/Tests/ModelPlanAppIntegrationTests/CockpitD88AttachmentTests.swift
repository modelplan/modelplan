// SPDX-License-Identifier: MIT
import AppKit
import WebKit
import XCTest
@testable import ModelPlanCockpitWeb

/// D88 (owner, 2026-11-09): the cockpit belongs to the menu bar icon by default. Attached: a drag of the title
/// strip also detaches, an outside click closes it, and an open from the icon grows out of the icon and
/// shrinks back on close. Detached: an outside click keeps it, and the put-back key (or a drop near the icon)
/// puts it back. The real panel and controller on the real screen, placed under a menu-bar-sized anchor; the
/// page is a synthetic document, so the strip keys' messages are covered by the bridge contract and the page
/// tests, and here the controller receives the intents they map to. Window server: GUI leg.
@MainActor final class CockpitD88AttachmentTests: XCTestCase {
  private struct Fixture {
    let page: CockpitWindowController, session: CockpitShellSession, icon: CGRect, usable: CGRect
    var home: CGRect? { CockpitShellLayout.fit(usable: usable, anchor: icon, shutterClosed: false)?.frame }
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
    return Fixture(page: page, session: session, icon: icon, usable: usable)
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

  /// Attached: centred under the icon, the right-click menu is the app's own (Detach, never Reload), the key
  /// anchors the one-time hint, and a click outside closes it the way a menu closes.
  func testD88AttachedOffersDetachAndAnOutsideClickClosesIt() throws {
    let fixture = try make(reduceMotion: true)
    defer { fixture.page.discard() }
    let window = try openPage(fixture, entrance: .fade)
    let home = try XCTUnwrap(fixture.home)
    XCTAssertTrue(fixture.page.isAttached)
    XCTAssertEqual(window.frame, home)
    XCTAssertEqual(window.frame.midX, min(max(fixture.icon.midX, fixture.usable.minX + home.width / 2), fixture.usable.maxX - home.width / 2), accuracy: 0.5,
                   "centred under the icon")
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

  /// Detached by the key: an outside click keeps the window, and the put-back key returns it under the icon.
  /// The one right-click item does the same.
  func testD88DetachKeyThenPutBackKey() throws {
    let fixture = try make(reduceMotion: true)
    defer { fixture.page.discard() }
    let window = try openPage(fixture, entrance: .fade)
    let start = window.frame, home = try XCTUnwrap(fixture.home)
    fixture.page.setAttached(false) // the detach key's intent
    XCTAssertFalse(fixture.page.isAttached)
    XCTAssertEqual(window.frame, start, "detaching keeps the window where it is")
    XCTAssertEqual(titles(fixture.page), ["Put back"])
    window.setFrame(start.offsetBy(dx: 0, dy: -100), display: true)
    fixture.page.outsidePress(outside(fixture), eventType: .leftMouseDown)
    XCTAssertNotNil(fixture.page.window, "a detached cockpit stays open on an outside click")
    fixture.page.setAttached(true) // the put-back key's intent
    XCTAssertTrue(fixture.page.isAttached, "the put-back key re-attaches")
    XCTAssertEqual(window.frame, home, "back under the icon")
    XCTAssertEqual(titles(fixture.page), ["Detach"])
    fixture.page.contextMenu()?.performActionForItem(at: 0)
    XCTAssertFalse(fixture.page.isAttached, "the menu item detaches")
    fixture.page.contextMenu()?.performActionForItem(at: 0)
    XCTAssertTrue(fixture.page.isAttached, "and puts back")
    XCTAssertEqual(failures, [])
  }

  /// An open from the icon starts at the icon and settles under it; the close shrinks back into it.
  func testD88IconOpenGrowsOutOfTheIconAndCloseShrinksBack() async throws {
    let fixture = try make(reduceMotion: false)
    defer { fixture.page.discard() }
    var changes = 0
    fixture.page.onShellChanged = { changes += 1 }
    let window = try openPage(fixture, entrance: .growFromIcon)
    let home = try XCTUnwrap(fixture.home)
    XCTAssertEqual(fixture.session.nextEntrance, .fade, "the entrance is consumed by its open")
    XCTAssertLessThan(window.frame.width, home.width, "it starts at the icon")
    XCTAssertNil(fixture.page.attachmentHintAnchor, "no hint while it grows")
    XCTAssertEqual(changes, 0)
    try await Task.sleep(for: .milliseconds(600))
    XCTAssertEqual(window.frame, home, "it settles under the icon")
    XCTAssertEqual(changes, 1, "the settled open is reported once, for the hint")
    XCTAssertNotNil(fixture.page.attachmentHintAnchor)
    fixture.page.requestClose()
    try await Task.sleep(for: .milliseconds(100))
    XCTAssertLessThan(fixture.page.window?.frame.width ?? 0, home.width, "the close shrinks back into the icon")
    try await Task.sleep(for: .milliseconds(400))
    XCTAssertNil(fixture.page.window)
    XCTAssertEqual(failures, [])
  }

  /// Reduce Motion opens at once at full size, and the widget ignition keeps its own fade instead of the grow.
  func testD88GrowIsSkippedUnderReduceMotionAndForTheIgnition() async throws {
    let reduced = try make(reduceMotion: true)
    defer { reduced.page.discard() }
    let still = try openPage(reduced, entrance: .growFromIcon)
    XCTAssertEqual(still.frame, try XCTUnwrap(reduced.home), "Reduce Motion: no grow")
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
    XCTAssertEqual(ignition.page.window?.frame ?? home, home, "and its close does not shrink into the icon")

    let icon = reduced.icon
    XCTAssertNil(CockpitWindowController.entranceStart(.growFromIcon, reduceMotion: true, detached: false, icon: icon))
    XCTAssertNil(CockpitWindowController.entranceStart(.fade, reduceMotion: false, detached: false, icon: icon))
    XCTAssertNil(CockpitWindowController.entranceStart(.growFromIcon, reduceMotion: false, detached: true, icon: icon))
    XCTAssertNil(CockpitWindowController.entranceStart(.growFromIcon, reduceMotion: false, detached: false, icon: nil))
    XCTAssertEqual(CockpitWindowController.entranceStart(.growFromIcon, reduceMotion: false, detached: false, icon: icon), icon)
  }

  /// G3-55 stays: WebKit's own items never show; with the app's menu a right-click shows only its item.
  func testD88RightClickMenuIsTheAppsOwnWithoutReload() throws {
    let view = CockpitWebView(frame: .zero, configuration: WKWebViewConfiguration())
    view.contextMenuProvider = {
      let menu = NSMenu(); menu.addItem(withTitle: "Detach", action: nil, keyEquivalent: ""); return menu
    }
    let event = try XCTUnwrap(NSEvent.mouseEvent(with: .rightMouseDown, location: .zero, modifierFlags: [], timestamp: 0,
      windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
    XCTAssertEqual(view.menu(for: event)?.items.map(\.title), ["Detach"])
    let webKit = NSMenu()
    for title in ["Reload", "Back", "Inspect Element"] { webKit.addItem(withTitle: title, action: nil, keyEquivalent: "") }
    view.willOpenMenu(webKit, with: event)
    XCTAssertEqual(webKit.items.map(\.title), ["Detach"], "only the app's item, never Reload")
  }
}
