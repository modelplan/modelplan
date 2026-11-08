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
}
