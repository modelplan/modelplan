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
  /// CKP-PORT-13 (D63): the page names public model IDs; native builds the only address it may open.
  func testFleetAddressIsBuiltFromPublicIDsOnly() {
    XCTAssertEqual(CockpitFieldPanel.fleetURL(models: ["sol-6.1", "auto:anthropic:ccb37fec2677f068"])?.absoluteString,
                   "https://modelplan.ai/?focus=sol-6.1,auto:anthropic:ccb37fec2677f068")
    XCTAssertNil(CockpitFieldPanel.fleetURL(models: []))
    XCTAssertNil(CockpitFieldPanel.fleetURL(models: Array(repeating: "m", count: 11)), "the field flies ten at most")
    for bad in ["a b", "a/b", "a?b", "a&focus=x", "https://evil.example", String(repeating: "x", count: 97), ""] {
      XCTAssertNil(CockpitFieldPanel.fleetURL(models: ["ok", bad]), bad)
    }
  }
  @MainActor func testTheWebsiteMessageOpensTheFleetAddressAndNothingElse() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("field-website-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let panel = CockpitFieldPanel(bundle: try bundle(root))
    var opened: [URL] = []
    panel.onWebsite = { opened.append($0) }
    panel.receive(#"{"type":"website","models":["a"]}"#)
    XCTAssertTrue(opened.isEmpty, "A closed panel opens nothing")
    panel.open(payload: "{}", near: nil)
    panel.receive(#"{"type":"website","models":["sol-6.1","glm"]}"#)
    panel.receive(#"{"type":"website","models":["a b"]}"#)
    panel.receive(#"{"type":"website","url":"https://evil.example"}"#)
    XCTAssertEqual(opened.map(\.absoluteString), ["https://modelplan.ai/?focus=sol-6.1,glm"])
    panel.close()
  }
  /// CKP-PORT-11 (D63, task 91 round 5): the composition's bounds follow the prototype's fieldFrame.
  func testCompositionBoundsFollowThePrototypeFrame() {
    XCTAssertEqual(CockpitFieldPanel.frame(in: NSRect(x: 0, y: 0, width: 1470, height: 919)),
                   NSRect(x: 73.5, y: 92, width: 1323, height: 735), "a 14-inch laptop: 90% wide, 80% high")
    XCTAssertEqual(CockpitFieldPanel.frame(in: NSRect(x: 0, y: 0, width: 1024, height: 743)),
                   NSRect(x: 32, y: 71.5, width: 960, height: 600), "the 960 x 600 floor")
    XCTAssertEqual(CockpitFieldPanel.frame(in: NSRect(x: 0, y: 0, width: 900, height: 600)),
                   NSRect(x: 16, y: 16, width: 868, height: 568), "16 pt from every edge on a tiny screen")
    XCTAssertEqual(CockpitFieldPanel.frame(in: NSRect(x: 2000, y: 25, width: 2560, height: 1415)).size,
                   NSSize(width: 1440, height: 900))
  }
  /// CKP-PORT-11 in the native panel: the frosted card blurs the desktop. A transparent web view cannot do that with
  /// CSS, so the page reports its card and the panel puts a behind-window blur exactly there; junk is ignored.
  @MainActor func testTheFrostedCardBlursTheDesktopWhereThePageSaysItIs() throws {
    XCTAssertEqual(CockpitFieldPanel.cardFrame(x: 0, y: 35.5, width: 430, height: 664, in: NSRect(x: 0, y: 0, width: 1323, height: 735)),
                   NSRect(x: 0, y: 35.5, width: 430, height: 664), "top-left page coordinates become bottom-left points")
    XCTAssertEqual(CockpitFieldPanel.cardFrame(x: 0, y: 20, width: 430, height: 600, in: NSRect(x: 0, y: 0, width: 960, height: 700)),
                   NSRect(x: 0, y: 80, width: 430, height: 600))
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("field-card-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let panel = CockpitFieldPanel(bundle: try bundle(root))
    panel.open(payload: "{}", near: nil)
    defer { panel.close() }
    XCTAssertNil(panel.cardBlurFrame, "no blur before the page has laid out its card")
    panel.receive(#"{"type":"card","x":"left","y":0,"width":430,"height":664}"#)
    XCTAssertNil(panel.cardBlurFrame, "a malformed rect is ignored")
    panel.receive(#"{"type":"card","x":0,"y":20,"width":430,"height":500,"radius":12}"#)
    let frame = try XCTUnwrap(panel.cardBlurFrame)
    XCTAssertEqual(frame.size, NSSize(width: 430, height: 500))
    XCTAssertEqual(frame.minX, 0)
  }
  /// D63 (review of #734): a field opened while Low Power Mode is already on is quiet from the start, whatever the
  /// payload said: right after `show` the page gets `power(true)`.
  @MainActor func testAFieldOpenedInLowPowerModeIsQuietFromTheStart() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("field-power-open-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let center = NotificationCenter()
    let panel = CockpitFieldPanel(bundle: try bundle(root), lowPower: { true }, notifications: center)
    var scripts: [String] = []
    panel.scriptSink = { scripts.append($0) }
    XCTAssertTrue(panel.isLowPower)
    panel.open(payload: #"{"lowPower":false}"#, near: nil)
    defer { panel.close() }
    panel.receive(#"{"type":"loaded"}"#)
    XCTAssertEqual(scripts.count, 2)
    XCTAssertTrue(scripts[0].hasPrefix("window.modelPlanField?.show("))
    XCTAssertEqual(scripts[1], "window.modelPlanField?.power(true)")
    center.post(name: .NSProcessInfoPowerStateDidChange, object: nil)
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    XCTAssertEqual(scripts.count, 2, "still on, nothing more")
  }
}
