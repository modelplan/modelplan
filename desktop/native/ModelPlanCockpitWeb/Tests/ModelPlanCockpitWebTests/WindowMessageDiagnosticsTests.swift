// SPDX-License-Identifier: MIT
import Foundation
import XCTest

@testable import ModelPlanCockpitWeb

final class WindowMessageDiagnosticsTests: XCTestCase {
  @MainActor func testRejectedReplyRecordsOnlyFixedDiagnosticAndValidReplyDoesNotIncrement()
    async throws
  {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "u11-rejection-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let html = Data("synthetic public page".utf8)
    try html.write(to: root.appendingPathComponent("index.html"))
    let manifest = try JSONSerialization.data(withJSONObject: [
      "schemaVersion": 1, "edition": "community", "interfaceOnly": true,
      "files": ["index.html": VerifiedCockpitBundle.digest(html)],
    ])
    try manifest.write(to: root.appendingPathComponent("bundle-manifest.json"))
    let bundle = try VerifiedCockpitBundle(
      root: root, manifestSHA256: VerifiedCockpitBundle.digest(manifest))
    let context = try CockpitEngineContext(
      sessionID: UUID(), storeEpoch: "synthetic", generation: 1)
    let controller = CockpitWindowController(
      bundle: bundle, context: context, appearance: .init(theme: .day, locale: .en, profile: .full))
    defer { controller.discard() }
    var diagnostics: [CockpitBridgeDiagnostic] = []
    controller.onBridgeDiagnostic = { diagnostics.append($0) }
    let source = CockpitMessageSource(mainFrame: true, origin: "modelplan-cockpit://bundle")
    XCTAssertNil(
      controller.acceptBridgeReply(
        "invalid synthetic payload must never enter diagnostics", source: source))
    XCTAssertEqual(controller.rejectedBridgeMessageCount, 1)
    XCTAssertEqual(diagnostics.map(\.rawValue), ["cockpit.bridge.message-rejected"])
    let load = try controller.bridge.load(.init(theme: .day, locale: .en, profile: .full))
    var reply = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(load.utf8)) as? [String: Any])
    reply["appearance"] = nil
    reply["type"] = "ready"
    reply["sequence"] = "1"
    let raw = String(decoding: try JSONSerialization.data(withJSONObject: reply), as: UTF8.self)
    XCTAssertEqual(controller.acceptBridgeReply(raw, source: source), .ready)
    XCTAssertEqual(controller.rejectedBridgeMessageCount, 1)
    XCTAssertNil(controller.acceptBridgeReply(raw, source: source))  // replay is a rejection too.
    XCTAssertEqual(controller.rejectedBridgeMessageCount, 2)
    XCTAssertEqual(diagnostics, [.rejectedMessage, .rejectedMessage])
  }
}
