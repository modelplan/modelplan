// SPDX-License-Identifier: MIT
import AppKit
import Foundation
import WebKit
import XCTest

@testable import ModelPlanCockpitWeb

/// D204 v3 (G3-94, relates to G3-79): the ignition toggles an attached cockpit and brings a detached one to the
/// front. Here on the real controller: an open brings an already shown cockpit in front, the visibility rule, the
/// display an attached open uses on two displays, and the ignition's mouse-down no longer closing the attached cockpit
/// as an outside click (the root cause of G3-94: that close was followed by the mouse-up's open). Tests that need a
/// window skip without a display (window server: GUI leg).
@MainActor final class CockpitIgnitionVisibilityTests: XCTestCase {
  /// A: the built-in display with the menu bar and the status item. B: a larger display to its right.
  private let a = CockpitScreen(frame: CGRect(x: 0, y: 0, width: 1512, height: 982), visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 949))
  private let b = CockpitScreen(frame: CGRect(x: 1512, y: 0, width: 2560, height: 1440), visibleFrame: CGRect(x: 1512, y: 0, width: 2560, height: 1415))
  private let icon = CGRect(x: 1100, y: 949, width: 28, height: 24)
  private let pressOnB = CGPoint(x: 3990, y: 700)

  private func bundle() throws -> VerifiedCockpitBundle {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("cockpit-ign-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: root) }
    let html = Data("<!doctype html><title>synthetic</title>".utf8); try html.write(to: root.appendingPathComponent("index.html"))
    let manifest = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "edition": "community", "interfaceOnly": true, "files": ["index.html": VerifiedCockpitBundle.digest(html)]])
    try manifest.write(to: root.appendingPathComponent("bundle-manifest.json"))
    return try VerifiedCockpitBundle(root: root, manifestSHA256: VerifiedCockpitBundle.digest(manifest))
  }
  private func page(session: CockpitShellSession? = nil, click: CGPoint?) throws -> CockpitWindowController {
    _ = NSApplication.shared
    let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic", generation: 1)
    let icon = self.icon
    let page = CockpitWindowController(bundle: try bundle(), context: context, appearance: .init(theme: .night, locale: .en, profile: .full),
                                       shellSession: session ?? CockpitShellSession(), anchor: { icon }, openPoint: { click })
    let displays = [a, b]
    page.screens = { displays }
    return page
  }

  /// The synthetic document is not the cockpit page; its load must not reach the controller.
  private func detachSyntheticLoad(_ page: CockpitWindowController) {
    (page.window?.contentView?.subviews.first as? WKWebView)?.navigationDelegate = nil
  }

  // MARK: visibility

  /// Visible only when ordered in, not minimised, on the active Space, not fully covered and the app not hidden.
  /// Partly covered keeps the occlusion state's `.visible`, so it counts as visible.
  func testVisibilityRule() {
    let seen = CockpitUserVisibility(onScreen: true, miniaturized: false, onActiveSpace: true, occluded: false, appHidden: false)
    XCTAssertTrue(seen.visible, "open and visible (also when partly covered)")
    var value = seen; value.onScreen = false
    XCTAssertFalse(value.visible, "closed")
    value = seen; value.occluded = true
    XCTAssertFalse(value.visible, "fully covered by other windows")
    value = seen; value.onActiveSpace = false
    XCTAssertFalse(value.visible, "on another Space")
    value = seen; value.miniaturized = true
    XCTAssertFalse(value.visible, "minimised")
    value = seen; value.appHidden = true
    XCTAssertFalse(value.visible, "app hidden")
  }

  /// A page that was never opened, and one that is closing, is not visible; an open one is.
  func testControllerVisibilityFollowsOpenAndClose() throws {
    guard NSScreen.main != nil else { throw XCTSkip("needs a display") }
    _ = NSApplication.shared
    let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic", generation: 1)
    let page = CockpitWindowController(bundle: try bundle(), context: context,
      appearance: .init(theme: .night, locale: .en, profile: .full, reduceMotion: false))
    defer { page.discard() }
    XCTAssertFalse(page.isVisibleToUser, "never opened")
    page.prewarm(); detachSyntheticLoad(page)
    XCTAssertFalse(page.isVisibleToUser, "a prewarmed page is not shown")
    page.open()
    XCTAssertTrue(page.isVisibleToUser, "opened in front of the user")
    page.requestClose()
    XCTAssertNotNil(page.window, "still fading")
    XCTAssertFalse(page.isVisibleToUser, "a closing cockpit is not visible")
  }

  /// Detached and covered by another window, an open (the ignition's press) brings it in front of that window and
  /// keeps it at its place; nothing closes.
  func testOpenBringsADetachedCoveredCockpitToTheFront() throws {
    guard NSScreen.main != nil else { throw XCTSkip("needs a display") }
    _ = NSApplication.shared
    let session = CockpitShellSession()
    let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic", generation: 1)
    let page = CockpitWindowController(bundle: try bundle(), context: context,
      appearance: .init(theme: .night, locale: .en, profile: .full, reduceMotion: true), shellSession: session)
    defer { page.discard() }
    page.open(); detachSyntheticLoad(page)
    let window = try XCTUnwrap(page.window)
    session.detached = true
    let place = window.frame
    let cover = NSPanel(contentRect: place.insetBy(dx: -20, dy: -20), styleMask: [.borderless], backing: .buffered, defer: false)
    cover.level = window.level; cover.isReleasedWhenClosed = false; cover.hidesOnDeactivate = false
    cover.orderFront(nil)
    defer { cover.close() }
    // The window server's on-screen list is front to back.
    func order() -> Bool? {
      let list = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? [])
        .compactMap { $0[kCGWindowNumber as String] as? Int }
      guard let cockpit = list.firstIndex(of: window.windowNumber), let other = list.firstIndex(of: cover.windowNumber) else { return nil }
      return cockpit < other
    }
    // Hosted runners without a logged-in window server session list no on-screen windows; the order is then unknowable.
    guard order() != nil else { throw XCTSkip("the window server lists no on-screen windows here (GUI session needed)") }
    XCTAssertEqual(order(), false, "the other window covers the cockpit")
    page.open()
    XCTAssertEqual(order(), true, "the cockpit is in front again")
    XCTAssertNotNil(page.window, "and still open")
    XCTAssertEqual(window.frame, place, "at the same place")
  }

  // MARK: G3-94 root cause

  /// The ignition's mouse-down reached the attached cockpit's press monitor as an outside click and closed it; the
  /// button's action on mouse-up then opened it again. A press on the ignition is now left to the ignition.
  func testIgnitionPressIsNotAnOutsideClick() throws {
    guard let screen = NSScreen.main else { throw XCTSkip("needs a display") }
    _ = NSApplication.shared
    let usable = screen.visibleFrame
    let menuIcon = CGRect(x: usable.midX - 14, y: usable.maxY, width: 28, height: max(1, screen.frame.maxY - usable.maxY))
    let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic", generation: 1)
    let page = CockpitWindowController(bundle: try bundle(), context: context,
      appearance: .init(theme: .night, locale: .en, profile: .full, reduceMotion: true), anchor: { menuIcon })
    defer { page.discard() }
    page.open(); detachSyntheticLoad(page)
    XCTAssertTrue(page.isAttached)
    let cockpit = try XCTUnwrap(page.window).frame
    let ignition = CGRect(x: usable.minX + 8, y: usable.minY + 8, width: 29, height: 29)
    XCTAssertFalse(cockpit.intersects(ignition), "the widget's ignition is outside the cockpit")
    page.ignitionFrame = { ignition }
    page.localPress(in: nil, at: CGPoint(x: ignition.midX, y: ignition.midY), eventType: .leftMouseDown)
    XCTAssertNotNil(page.window, "the ignition's mouse-down leaves the cockpit to the ignition's action")
    XCTAssertTrue(page.isVisibleToUser)
    page.localPress(in: nil, at: CGPoint(x: ignition.maxX + 40, y: ignition.midY), eventType: .leftMouseDown)
    XCTAssertNil(page.window, "a press elsewhere outside still closes the attached cockpit")
  }

  // MARK: two displays

  /// G3-128 (owner, build 15; supersedes D204's "display pressed on"): attached, the cockpit belongs to the status
  /// item's display, whichever display the ignition was pressed on. No icon: the display at the origin (the menu bar's).
  func testAttachedScreenIsTheStatusItemsDisplay() {
    XCTAssertEqual(CockpitScreenSelection.attachedScreen(anchor: icon, screens: [a, b]), a)
    XCTAssertEqual(CockpitScreenSelection.attachedScreen(anchor: icon, screens: [b, a]), a, "not the main (key) display")
    let iconOnB = CGRect(x: 3660, y: 1415, width: 28, height: 25)
    XCTAssertEqual(CockpitScreenSelection.attachedScreen(anchor: iconOnB, screens: [a, b]), b, "the status item moved to B: B")
    XCTAssertEqual(CockpitScreenSelection.attachedScreen(anchor: nil, screens: [b, a]), a,
                   "no icon: the display at the origin carries the menu bar")
  }

  /// G3-128 (a): the ignition pressed on B opens the attached cockpit under the status item on A, and the rack hangs
  /// from that real icon.
  func testAttachedOpenFromTheSecondDisplayGoesUnderTheStatusItem() throws {
    let page = try page(click: pressOnB)
    let (usable, anchor) = try XCTUnwrap(page.environment())
    XCTAssertEqual(usable, a.visibleFrame, "the status item's display, not the display pressed on")
    XCTAssertEqual(anchor, icon, "under the real status item")
    let placement = try XCTUnwrap(page.placement())
    XCTAssertTrue(a.visibleFrame.contains(placement.frame))
    let attached = try XCTUnwrap(CockpitShellLayout.fit(usable: a.visibleFrame, anchor: icon, shutterClosed: false, screenWidth: a.frame.width))
    XCTAssertEqual(placement.frame, attached.frame, "the same place the icon's own click opens at")
    XCTAssertEqual(page.rackIcon(), icon, "the rack hangs from the status item")
  }

  /// Detached: its own display (the remembered place), wherever the ignition was pressed.
  func testDetachedOpenStaysOnItsOwnDisplay() throws {
    let session = CockpitShellSession()
    let page = try page(session: session, click: pressOnB)
    session.detached = true
    let origin = CGPoint(x: 200, y: 0)
    session.remember(origin, arrangement: page.arrangement)
    let (usable, _) = try XCTUnwrap(page.environment())
    XCTAssertEqual(usable, a.visibleFrame)
    XCTAssertEqual(try XCTUnwrap(page.placement()).frame.origin, origin, "at its last position")
  }
}
