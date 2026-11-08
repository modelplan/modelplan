// SPDX-License-Identifier: MIT
#if MODELPLAN_TEST_ONLY_SPI
import AppKit
import Foundation
import WebKit
import XCTest
import ModelPlanWire
@testable import ModelPlanCockpitWeb

/// G3-55: no WebKit default menu (Reload) on any cockpit-hosted web view, and a reload or navigation
/// never takes the bridge down. No window, page load or system event is created.
@MainActor final class CockpitContextMenuAndReloadTests: XCTestCase {
  private final class FakeFrame: WKFrameInfo {
    private let main: Bool
    init(main: Bool) { self.main = main; super.init() }
    override var isMainFrame: Bool { main }
  }
  private final class FakeAction: WKNavigationAction {
    private let url: URL, kind: WKNavigationType, main: Bool
    init(url: URL, kind: WKNavigationType, main: Bool = true) { self.url = url; self.kind = kind; self.main = main; super.init() }
    override var request: URLRequest { URLRequest(url: url) }
    override var navigationType: WKNavigationType { kind }
    override var targetFrame: WKFrameInfo? { FakeFrame(main: main) }
  }
  private func page() throws -> CockpitWindowController {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("cockpit-menu-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: root) }
    let html = Data("synthetic".utf8); try html.write(to: root.appendingPathComponent("index.html"))
    let manifest = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "edition": "community", "interfaceOnly": true, "files": ["index.html": VerifiedCockpitBundle.digest(html)]])
    try manifest.write(to: root.appendingPathComponent("bundle-manifest.json"))
    let bundle = try VerifiedCockpitBundle(root: root, manifestSHA256: VerifiedCockpitBundle.digest(manifest))
    let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic", generation: 1)
    return CockpitWindowController(bundle: bundle, context: context, appearance: .init(theme: .night, locale: .en, profile: .full))
  }
  private func decide(_ page: CockpitWindowController, _ action: WKNavigationAction) -> WKNavigationActionPolicy {
    var result: WKNavigationActionPolicy?
    page.webView(CockpitWebView(frame: .zero, configuration: WKWebViewConfiguration()), decidePolicyFor: action) { result = $0 }
    return result ?? .cancel
  }

  func testCockpitWebViewShowsNoDefaultContextMenu() throws {
    let view = CockpitWebView(frame: .zero, configuration: WKWebViewConfiguration())
    let event = try XCTUnwrap(NSEvent.mouseEvent(with: .rightMouseDown, location: .zero, modifierFlags: [], timestamp: 0,
      windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
    XCTAssertNil(view.menu(for: event))
    let menu = NSMenu()
    for title in ["Reload", "Back", "Inspect Element"] { menu.addItem(withTitle: title, action: nil, keyEquivalent: "") }
    view.willOpenMenu(menu, with: event)
    XCTAssertEqual(menu.items.count, 0, "No WebKit item, in particular Reload, survives")
    XCTAssertFalse(menu.items.contains { $0.title == "Reload" })
  }

  func testPolicyAllowsOnlyTheFirstMainFrameLoad() {
    let url = URL(string: "modelplan-cockpit://bundle/index.html?pageId=x")!
    XCTAssertTrue(CockpitNavigationPolicy.allows(isMainFrame: true, url: url, pageURL: url, type: .other, alreadyLoaded: false))
    XCTAssertFalse(CockpitNavigationPolicy.allows(isMainFrame: true, url: url, pageURL: url, type: .reload, alreadyLoaded: false))
    XCTAssertFalse(CockpitNavigationPolicy.allows(isMainFrame: true, url: url, pageURL: url, type: .backForward, alreadyLoaded: false))
    XCTAssertFalse(CockpitNavigationPolicy.allows(isMainFrame: true, url: url, pageURL: url, type: .other, alreadyLoaded: true))
    XCTAssertFalse(CockpitNavigationPolicy.allows(isMainFrame: false, url: url, pageURL: url, type: .other, alreadyLoaded: false))
    XCTAssertFalse(CockpitNavigationPolicy.allows(isMainFrame: true, url: URL(string: "https://example.com/")!, pageURL: url, type: .other, alreadyLoaded: false))
  }

  func testReloadAndNavigationLeaveTheBridgeAliveAndRaiseNoFailure() throws {
    let page = try page()
    page.onFailure = { XCTFail("A reload or navigation must not fail the page: \($0)") }
    let shell = CockpitShellState(closed: false, attached: true, forcedClosed: false, tier: .tall)
    _ = try page.bridge.load(.init(theme: .night, locale: .en, profile: .full), shell: shell)
    XCTAssertEqual(decide(page, FakeAction(url: page.pageURL, kind: .other)), .allow)
    XCTAssertEqual(decide(page, FakeAction(url: page.pageURL, kind: .reload)), .cancel)
    XCTAssertEqual(decide(page, FakeAction(url: page.pageURL, kind: .other)), .cancel)
    XCTAssertEqual(decide(page, FakeAction(url: page.pageURL, kind: .backForward)), .cancel)
    XCTAssertEqual(decide(page, FakeAction(url: URL(string: "https://example.com/")!, kind: .linkActivated)), .cancel)
    // The bridge is untouched: it still refuses a second load itself and was not discarded.
    XCTAssertThrowsError(try page.bridge.load(.init(theme: .night, locale: .en, profile: .full), shell: shell))
  }
}
#endif
