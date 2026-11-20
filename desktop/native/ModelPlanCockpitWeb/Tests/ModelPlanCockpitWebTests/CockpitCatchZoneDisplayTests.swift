// SPDX-License-Identifier: MIT
#if MODELPLAN_TEST_ONLY_SPI
import AppKit
import Foundation
import XCTest
@testable import ModelPlanCockpitWeb

/// Post-merge sample 11-11 (#845 finding 3): after a drop on another display, the put back must still mean the icon's
/// display. CKP-SHELL-33 (D178/D187) removed the grey snap guide: the catch zone around home (40 pt) is the only cue, by
/// the rack reaching down, and it acts on the release. The real controller through the strip's drag entry, two displays
/// through the `screens` seam. Window server: GUI leg.
@MainActor final class CockpitCatchZoneDisplayTests: XCTestCase {
  private func bundle() throws -> VerifiedCockpitBundle {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("cockpit-snap-guide-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: root) }
    let html = Data("<!doctype html><title>synthetic</title>".utf8)
    try html.write(to: root.appendingPathComponent("index.html"))
    let manifest = try JSONSerialization.data(withJSONObject: [
      "schemaVersion": 1, "edition": "community", "interfaceOnly": true,
      "files": ["index.html": VerifiedCockpitBundle.digest(html)],
    ])
    try manifest.write(to: root.appendingPathComponent("bundle-manifest.json"))
    return try VerifiedCockpitBundle(root: root, manifestSHA256: VerifiedCockpitBundle.digest(manifest))
  }

  func testTheCatchZoneAndThePutBackUseTheSameDisplayAfterACrossDisplayDrop() throws {
    _ = NSApplication.shared
    let short = CockpitScreen(frame: CGRect(x: 0, y: 0, width: 1280, height: 720), visibleFrame: CGRect(x: 0, y: 0, width: 1280, height: 695))
    let tall = CockpitScreen(frame: CGRect(x: 1280, y: 0, width: 2560, height: 1440), visibleFrame: CGRect(x: 1280, y: 0, width: 2560, height: 1415))
    let icon = CGRect(x: 1100, y: 695, width: 28, height: 24)
    let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic", generation: 1)
    let page = CockpitWindowController(bundle: try bundle(), context: context,
      appearance: .init(theme: .night, locale: .en, profile: .full, reduceMotion: true), anchor: { icon })
    let displays = [short, tall]
    page.screens = { displays }
    page.prewarm()
    page.verificationWebView?.navigationDelegate = nil // the headless synthetic load must not discard the window
    defer { page.discard() }
    let window = try XCTUnwrap(page.window)
    let home = try XCTUnwrap(CockpitShellLayout.fit(usable: short.visibleFrame, anchor: icon, shutterClosed: false, screenWidth: short.frame.width))
    let away = try XCTUnwrap(CockpitShellLayout.fit(usable: tall.visibleFrame, anchor: CockpitShellLayout.hiddenIconAnchor(usable: tall.visibleFrame),
                                                   shutterClosed: false, screenWidth: tall.frame.width))
    XCTAssertGreaterThan(hypot(home.frame.minX - away.frame.minX, home.frame.minY - away.frame.minY), 200, "two distinct attached places")

    // First drag: off the icon's display onto the tall one, and drop.
    let from = CGPoint(x: window.frame.minX + 60, y: window.frame.maxY - 30)
    page.titleDrag(.began, point: from)
    page.titleDrag(.moved, point: CGPoint(x: from.x + 40, y: from.y))
    page.titleDrag(.moved, point: CGPoint(x: 2800, y: 900))
    page.titleDrag(.ended, point: CGPoint(x: 2800, y: 900))
    XCTAssertFalse(page.isAttached)

    // Second drag: onto the tall display's own attached place.
    let start = window.frame
    let grab = CGPoint(x: start.minX + 60, y: start.maxY - 30)
    let target = CGPoint(x: grab.x + away.frame.minX - start.minX, y: grab.y + away.frame.minY - start.minY)
    page.titleDrag(.began, point: grab)
    page.titleDrag(.moved, point: target)
    XCTAssertEqual(window.frame.origin, away.frame.origin, "the drag reached the tall display's attached place")
    XCTAssertFalse(page.inCatchZone(window.frame), "the tall display's attached place is not home")
    XCTAssertEqual(page.verificationRack.target, 0, "so the rack does not reach for it")
    XCTAssertFalse(page.verificationRack.ignited)
    page.titleDrag(.ended, point: target)
    XCTAssertFalse(page.isAttached, "a release outside the catch zone keeps the cockpit detached where it was dropped")
    XCTAssertTrue(tall.visibleFrame.contains(window.frame), "it stays on the tall display")
  }
}
#endif
