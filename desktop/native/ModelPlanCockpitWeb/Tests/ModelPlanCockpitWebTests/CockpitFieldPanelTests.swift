// SPDX-License-Identifier: MIT
import Foundation
import XCTest

@testable import ModelPlanCockpitWeb

/// The enlarged field's lifetime: nothing exists before open, and every close path destroys the page.
final class CockpitFieldPanelTests: XCTestCase {
  @MainActor private func bundle(_ root: URL) throws -> VerifiedCockpitBundle {
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let html = Data("<!doctype html><title>synthetic field</title>".utf8)
    try html.write(to: root.appendingPathComponent("field.html"))
    try html.write(to: root.appendingPathComponent("index.html"))
    let manifest = try JSONSerialization.data(withJSONObject: [
      "schemaVersion": 1, "edition": "community", "interfaceOnly": true,
      "files": ["field.html": VerifiedCockpitBundle.digest(html), "index.html": VerifiedCockpitBundle.digest(html)],
    ])
    try manifest.write(to: root.appendingPathComponent("bundle-manifest.json"))
    return try VerifiedCockpitBundle(root: root, manifestSHA256: VerifiedCockpitBundle.digest(manifest))
  }
  @MainActor func testIdleClosesThePanelOnceAndCloseIsIdempotent() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("field-panel-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let panel = CockpitFieldPanel(bundle: try bundle(root), idleSeconds: 0.05)
    var closed = 0
    panel.onClosed = { closed += 1 }
    XCTAssertFalse(panel.isOpen)
    panel.close()
    XCTAssertEqual(closed, 0, "Closing an unopened panel does nothing")
    panel.open(payload: "{}", near: nil)
    XCTAssertTrue(panel.isOpen)
    for _ in 0..<100 where panel.isOpen { try await Task.sleep(for: .milliseconds(20)) }
    XCTAssertFalse(panel.isOpen, "The idle timer closes the panel")
    XCTAssertEqual(closed, 1)
    panel.close()
    XCTAssertEqual(closed, 1)
    panel.open(payload: "{}", near: nil)
    XCTAssertTrue(panel.isOpen, "A closed panel can open again")
    panel.close()
    XCTAssertEqual(closed, 2)
  }
  /// Spike 11-08 / D63: native tells the page about Low Power Mode, which the page cannot read. Changes while open go
  /// to `power` once the page has loaded and only when the state changes; a closed panel stops listening.
  @MainActor func testLowPowerChangesReachTheOpenPageOnce() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("field-power-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    var low = false
    let center = NotificationCenter()
    let panel = CockpitFieldPanel(bundle: try bundle(root), lowPower: { low }, notifications: center)
    var scripts: [String] = []
    panel.scriptSink = { scripts.append($0) }
    let changed = {
      center.post(name: .NSProcessInfoPowerStateDidChange, object: nil)
      RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }
    XCTAssertFalse(panel.isLowPower)
    panel.open(payload: #"{"lowPower":false}"#, near: nil)
    low = true; changed()
    XCTAssertTrue(scripts.isEmpty, "Nothing reaches a page that has not loaded")
    panel.receive(#"{"type":"loaded"}"#)
    XCTAssertEqual(scripts.count, 2)
    XCTAssertTrue(scripts[0].hasPrefix("window.modelPlanField?.show("))
    XCTAssertEqual(scripts[1], "window.modelPlanField?.power(true)", "The change before load catches up after show")
    changed()
    XCTAssertEqual(scripts.count, 2, "No change, nothing sent")
    low = false; changed()
    XCTAssertEqual(scripts.last, "window.modelPlanField?.power(false)")
    panel.close()
    low = true; changed()
    XCTAssertEqual(scripts.count, 3, "A closed panel stops listening")
  }
}
