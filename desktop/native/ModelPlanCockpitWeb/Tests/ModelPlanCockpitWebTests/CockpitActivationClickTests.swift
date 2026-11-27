// SPDX-License-Identifier: MIT
import AppKit
import Foundation
import WebKit
import XCTest

@testable import ModelPlanCockpitWeb

/// Owner 11-19 (#1062): the enlarged field must not open from the click that only activates the cockpit. The cockpit is an
/// activating borderless NSPanel (not .nonactivatingPanel), so AppKit asks the web view `acceptsFirstMouse(for:)` when
/// the window is not key; inside the porthole band the answer is no, and the click only brings the cockpit forward.
/// Below the band (faders, keys, tabs) nothing changes. The window test needs a display (GUI leg); mac-compile and that
/// leg are the proof.
@MainActor final class CockpitActivationClickTests: XCTestCase {
  private let screen = CockpitScreen(frame: CGRect(x: 0, y: 0, width: 1512, height: 982), visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 949))

  /// The band is the canvas above the closed slab: 228 page px (the one layout, D444), times the scale.
  func testThePortholeBandIsTheCanvasAboveTheClosedSlab() throws {
    let icon = CGRect(x: 1100, y: 949, width: 28, height: 24)
    let layout = try XCTUnwrap(CockpitShellLayout.fit(usable: screen.visibleFrame, anchor: icon, shutterClosed: false, screenWidth: screen.frame.width))
    XCTAssertEqual(layout.portholeActivationBand, (228 * layout.scale).rounded(.down))
    XCTAssertGreaterThan(layout.portholeActivationBand, 0)
  }

  private static func webView(in view: NSView?) -> CockpitWebView? {
    guard let view else { return nil }
    if let web = view as? CockpitWebView { return web }
    for child in view.subviews { if let web = webView(in: child) { return web } }
    return nil
  }
  private func bundle() throws -> VerifiedCockpitBundle {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("cockpit-activation-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: root) }
    let html = Data("<!doctype html><title>synthetic</title>".utf8); try html.write(to: root.appendingPathComponent("index.html"))
    let manifest = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "edition": "community", "interfaceOnly": true, "files": ["index.html": VerifiedCockpitBundle.digest(html)]])
    try manifest.write(to: root.appendingPathComponent("bundle-manifest.json"))
    return try VerifiedCockpitBundle(root: root, manifestSHA256: VerifiedCockpitBundle.digest(manifest))
  }

  /// A mouse-down on the porthole of a cockpit window that is not key is not delivered to the page; one on the faders is
  /// left to WebKit as before.
  func testAnActivationClickOnThePortholeIsNotDeliveredToThePage() throws {
    guard NSScreen.main != nil else { throw XCTSkip("needs a display") }
    _ = NSApplication.shared
    let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic", generation: 1)
    let page = CockpitWindowController(bundle: try bundle(), context: context, appearance: .init(theme: .night, locale: .en, profile: .full))
    let screen = self.screen
    page.screens = { [screen] }
    defer { page.discard() }
    page.open()
    let window = try XCTUnwrap(page.window)
    let web = try XCTUnwrap(Self.webView(in: window.contentView))
    web.navigationDelegate = nil
    window.resignKey()
    func press(fromTop y: CGFloat) -> NSEvent? {
      let inView = CGPoint(x: web.bounds.midX, y: web.isFlipped ? y : web.bounds.height - y)
      return NSEvent.mouseEvent(with: .leftMouseDown, location: web.convert(inView, to: nil), modifierFlags: [], timestamp: 0,
                                windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)
    }
    XCTAssertFalse(web.acceptsFirstMouse(for: press(fromTop: 60)), "the porthole: the first click only activates the cockpit")
    let declines = try XCTUnwrap(web.declinesActivationClick)
    XCTAssertTrue(declines(CGPoint(x: 10, y: 60)))
    XCTAssertFalse(declines(CGPoint(x: 10, y: web.bounds.height - 40)), "the faders and keys keep their first click")
  }
}
