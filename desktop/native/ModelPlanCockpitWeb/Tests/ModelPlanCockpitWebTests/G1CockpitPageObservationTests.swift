// SPDX-License-Identifier: MIT
#if DEBUG
import Foundation
import XCTest
@testable import ModelPlanCockpitWeb

@MainActor final class G1CockpitPageObservationTests: XCTestCase {
  func testCoordinatorDoesNotInventAnUnopenedLivePage() {
    let coordinator = EngineCockpitCoordinator { _ in throw CockpitBridgeError.unavailable }
    XCTAssertNil(coordinator.g1LivePageForChecks)
  }
  func testUnopenedPageObservationAndAwaitedTeardownAreTruthful() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("g1-page-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let bytes = Data("synthetic public page".utf8)
    try bytes.write(to: root.appendingPathComponent("index.html"))
    let manifest = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "edition": "community", "interfaceOnly": true,
      "files": ["index.html": VerifiedCockpitBundle.digest(bytes)]])
    try manifest.write(to: root.appendingPathComponent("bundle-manifest.json"))
    let bundle = try VerifiedCockpitBundle(root: root, manifestSHA256: VerifiedCockpitBundle.digest(manifest))
    let page = CockpitWindowController(bundle: bundle, context: try .init(sessionID: UUID(), storeEpoch: "synthetic", generation: 1),
      appearance: .init(theme: .night, locale: .en, profile: .full))
    let absentDOM = try await page.g1PageGeometryForChecks()
    XCTAssertNil(absentDOM, "No page observation can be invented before a verified page exists")
    let before = page.g1PageStateForChecks
    XCTAssertFalse(before.hasPage); XCTAssertFalse(before.hasWindow); XCTAssertFalse(before.ready); XCTAssertFalse(before.disposed)
    await page.g1CloseAndWaitForTeardown()
    let after = page.g1PageStateForChecks
    XCTAssertFalse(after.hasPage); XCTAssertFalse(after.hasWindow); XCTAssertFalse(after.ready); XCTAssertTrue(after.disposed)
    await page.g1CloseAndWaitForTeardown()
    XCTAssertTrue(page.g1PageStateForChecks.disposed)
  }
}
#endif
