// SPDX-License-Identifier: MIT
import AppKit
import Foundation
import WebKit
import XCTest
@testable import ModelPlanCockpitWeb

/// CKP-SHELL-24 (close is a 0.12 s non-blocking fade with no return effect), CKP-SHELL-18 (the cockpit content is
/// a WKWebView of the bundled page and nothing else is drawn natively inside the window) and DOCK-3.1-26 (an
/// ignition short press opens with the plain 0.18 s fade, not the icon grow). Real controller; the tests that
/// need a window skip without a display (window server: GUI leg). The page is a synthetic document. Tests that read a
/// `verification*` hook of the controller are in the SPI extension at the bottom, which compiles only with
/// MODELPLAN_TEST_ONLY_SPI; everything else runs in the default lane.
@MainActor final class CockpitCloseFadeAndHostTests: XCTestCase {
  private func bundle() throws -> VerifiedCockpitBundle {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("cockpit-close-fade-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: root) }
    let html = Data("synthetic".utf8); try html.write(to: root.appendingPathComponent("index.html"))
    let manifest = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "edition": "community", "interfaceOnly": true, "files": ["index.html": VerifiedCockpitBundle.digest(html)]])
    try manifest.write(to: root.appendingPathComponent("bundle-manifest.json"))
    return try VerifiedCockpitBundle(root: root, manifestSHA256: VerifiedCockpitBundle.digest(manifest))
  }
  private func make(reduceMotion: Bool, session: CockpitShellSession? = nil, anchor: Bool = false) throws -> CockpitWindowController {
    _ = NSApplication.shared
    let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic", generation: 1)
    let page = CockpitWindowController(bundle: try bundle(), context: context,
      appearance: .init(theme: .night, locale: .en, profile: .full, reduceMotion: reduceMotion),
      shellSession: session ?? CockpitShellSession(), anchor: { anchor ? Self.iconFrame() : nil })
    page.onFailure = { XCTFail("Unexpected cockpit failure: \($0)") }
    addTeardownBlock { @MainActor in page.discard() }
    return page
  }
  /// A status item's frame in the menu bar, as the D88 tests place it; nil without a display.
  private static func iconFrame() -> CGRect? {
    guard let screen = NSScreen.main else { return nil }
    let usable = screen.visibleFrame
    return CGRect(x: usable.midX - 14, y: usable.maxY, width: 28, height: max(1, screen.frame.maxY - usable.maxY))
  }
  /// An open on a real window; the synthetic document is not the cockpit page, so its load must not reach the controller.
  private func openOnScreen(_ page: CockpitWindowController) throws -> NSWindow {
    guard NSScreen.main != nil else { throw XCTSkip("needs a display") }
    page.open()
    let window = try XCTUnwrap(page.window)
    (window.contentView?.subviews.first as? WKWebView)?.navigationDelegate = nil
    return window
  }
  // MARK: CKP-SHELL-24

  /// On a real window the close returns at once, leaves the window taking input while it fades, asking twice is
  /// harmless, and the discard follows by itself. Uses no verification hook.
  func testCloseOnAWindowReturnsAtOnceKeepsInputAndEndsByItself() async throws {
    let session = CockpitShellSession(); session.nextEntrance = .fade
    let page = try make(reduceMotion: false, session: session, anchor: true)
    let window = try openOnScreen(page)
    let frameBefore = window.frame

    page.closeAnimated()
    XCTAssertNotNil(page.window, "closeAnimated returns before the fade ends")
    XCTAssertFalse(window.ignoresMouseEvents, "input is not blocked while the window fades")
    page.closeAnimated()
    XCTAssertEqual(window.frame, frameBefore, "the fade moves and resizes nothing")
    let gone = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in page.window == nil }, object: nil)
    await fulfillment(of: [gone], timeout: 3)
    XCTAssertNil(page.window, "the fade ends by discarding the page")
  }

  // MARK: CKP-SHELL-18

  /// The window's content is the bundled page in one web view, the only content view besides the invisible title
  /// drag strip. The page comes from the custom bundle scheme, never from a file or the network.
  func testCockpitContentIsAWKWebViewOfTheBundledPage() throws {
    let page = try make(reduceMotion: true)
    XCTAssertEqual(page.pageURL.scheme, "modelplan-cockpit")
    XCTAssertEqual(page.pageURL.host, "bundle")
    XCTAssertEqual(page.pageURL.path, "/index.html")
    let window = try openOnScreen(page)
    let root = try XCTUnwrap(window.contentView)
    let kinds = root.subviews.map { String(describing: type(of: $0)) }
    XCTAssertEqual(kinds, ["CockpitWebView", "CockpitTitleDrag"], "only the page and the drag strip live in the window")
    let web = try XCTUnwrap(root.subviews.first as? WKWebView)
    XCTAssertNotNil(web.configuration.urlSchemeHandler(forURLScheme: "modelplan-cockpit"))
    XCTAssertNil(web.configuration.urlSchemeHandler(forURLScheme: "file"))
    XCTAssertEqual(root.subviews.filter { $0 is WKWebView }.count, 1)
  }

  // MARK: DOCK-3.1-26

  /// The open fade constant, and an ignition open with Reduce Motion shows the window at full opacity at once.
  func testOpenFadeConstantAndReduceMotionOpensInstantly() throws {
    XCTAssertEqual(CockpitWindowController.openFade, 0.18)
    let session = CockpitShellSession(); session.nextEntrance = .fade
    let calm = try make(reduceMotion: true, session: session, anchor: true)
    let calmWindow = try openOnScreen(calm)
    XCTAssertEqual(calmWindow.alphaValue, 1, "Reduce Motion: no fade")
  }
}

// MARK: SPI-only (read a `verification*` hook; run once the CockpitWeb lane passes -DMODELPLAN_TEST_ONLY_SPI)
#if MODELPLAN_TEST_ONLY_SPI
extension CockpitCloseFadeAndHostTests {
  /// The hook reports the fade length the close starts with, 0.12 s, and 0 under Reduce Motion. No window needed.
  func testCloseFadesIn120msAndIsNonBlocking() throws {
    let page = try make(reduceMotion: false)
    var reported: [TimeInterval] = [], entrances: [String] = []
    page.verificationCloseStarted = { reported.append($0) }
    page.verificationEntrance = { entrances.append($0) }
    page.closeAnimated()
    XCTAssertEqual(reported, [0.12], "the close fade is 0.12 s")
    XCTAssertEqual(entrances, ["fade"], "a plain fade: no shrink back into an icon (no return effect)")

    let calm = try make(reduceMotion: true)
    var calmReported: [TimeInterval] = [], calmEntrances: [String] = []
    calm.verificationCloseStarted = { calmReported.append($0) }
    calm.verificationEntrance = { calmEntrances.append($0) }
    calm.closeAnimated()
    XCTAssertEqual(calmReported, [0], "Reduce Motion closes with no fade")
    XCTAssertEqual(calmEntrances, ["instant"])
  }

  /// A second close request does not restart the fade, and an icon-anchored ignition open closes by fading.
  func testSecondCloseRequestDoesNotRestartTheFade() async throws {
    let session = CockpitShellSession(); session.nextEntrance = .fade
    let page = try make(reduceMotion: false, session: session, anchor: true)
    _ = try openOnScreen(page)
    var reported: [TimeInterval] = [], entrances: [String] = []
    page.verificationCloseStarted = { reported.append($0) }
    page.verificationEntrance = { entrances.append($0) }
    let discarded = expectation(description: "discarded")
    page.verificationDidDiscard = { discarded.fulfill() }
    page.closeAnimated(); page.closeAnimated()
    XCTAssertEqual(reported, [0.12], "a second request does not restart the fade")
    XCTAssertEqual(entrances, ["fade"], "opened by the ignition, so it closes by fading, never by shrinking")
    await fulfillment(of: [discarded], timeout: 3)
  }

  /// index.html is served from the bundle, and the one web view is the controller's page.
  func testBundledIndexIsServedAndTheWebViewIsTheControllersPage() async throws {
    let page = try make(reduceMotion: true)
    var requested: [String] = []
    let served = expectation(description: "index.html served from the bundle")
    page.verificationResource = { path in
      requested.append(path)
      if path == "index.html" { served.fulfill() }
    }
    let window = try openOnScreen(page)
    let web = try XCTUnwrap(window.contentView?.subviews.first as? WKWebView)
    XCTAssertTrue(web === page.verificationWebView, "the one web view is the controller's page")
    await fulfillment(of: [served], timeout: 10)
    XCTAssertTrue(requested.contains("index.html"), "the bundled page is what loads")
  }

  /// The ignition sets the plain fade entrance before open(): even with the menu bar icon anchor available, it
  /// opens in place with the open fade (grow is only for the icon), and Reduce Motion opens instantly.
  func testIgnitionShortPressOpensWithTheOpenFade() async throws {
    let session = CockpitShellSession(); session.nextEntrance = .fade // what the ignition press sets
    let page = try make(reduceMotion: false, session: session, anchor: true)
    var entrances: [String] = []
    page.verificationEntrance = { entrances.append($0) }
    let window = try openOnScreen(page)
    XCTAssertEqual(entrances, ["fade"], "the ignition opens with the fade, not the icon grow")
    XCTAssertEqual(session.nextEntrance, .fade)
    XCTAssertEqual(window.frame, page.verificationLayout?.frame, "it opens at its own place, not at the icon")
    let settled = NSPredicate { _, _ in window.alphaValue == 1 }
    let faded = XCTNSPredicateExpectation(predicate: settled, object: nil)
    await fulfillment(of: [faded], timeout: 3)

    let calmSession = CockpitShellSession(); calmSession.nextEntrance = .fade
    let calm = try make(reduceMotion: true, session: calmSession, anchor: true)
    var calmEntrances: [String] = []
    calm.verificationEntrance = { calmEntrances.append($0) }
    _ = try openOnScreen(calm)
    XCTAssertEqual(calmEntrances, ["instant"], "Reduce Motion: no fade")
  }
}
#endif
