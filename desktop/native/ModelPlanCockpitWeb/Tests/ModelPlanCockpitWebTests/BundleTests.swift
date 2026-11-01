// SPDX-License-Identifier: MIT
import XCTest

@testable import ModelPlanCockpitWeb

final class BundleTests: XCTestCase {
  func testCustomSchemeModuleResponseHasCORSMIMEAndNoCredentialRoute() throws {
    let response = CockpitSchemeResponse.make(url: URL(string: "modelplan-cockpit://bundle/src/main.js")!, mime: "text/javascript", bytes: 17)
    XCTAssertEqual(response.statusCode, 200)
    XCTAssertEqual(response.mimeType, "text/javascript")
    XCTAssertEqual(response.value(forHTTPHeaderField: "Access-Control-Allow-Origin"), "*")
    XCTAssertNil(response.value(forHTTPHeaderField: "Access-Control-Allow-Credentials"))
    XCTAssertEqual(response.value(forHTTPHeaderField: "Cache-Control"), "no-store")
  }

  func root() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
      "cockpit-bundle-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: url) }
    return url
  }
  func manifest(_ root: URL, edition: String = "community", files: [String: String]? = nil) throws
    -> String
  {
    let data = Data("<html>synthetic</html>".utf8)
    try data.write(to: root.appendingPathComponent("index.html"))
    let json = try JSONSerialization.data(withJSONObject: [
      "schemaVersion": 1, "edition": edition, "interfaceOnly": true,
      "files": files ?? ["index.html": VerifiedCockpitBundle.digest(data)],
    ])
    try json.write(to: root.appendingPathComponent("bundle-manifest.json"))
    return VerifiedCockpitBundle.digest(json)
  }
  func testPinnedBundleServesButRefusesPostValidationMutation() throws {
    let dir = try root()
    let pin = try manifest(dir)
    let bundle = try VerifiedCockpitBundle(root: dir, manifestSHA256: pin)
    XCTAssertFalse(try bundle.resource(path: "index.html").isEmpty)
    XCTAssertThrowsError(try bundle.resource(path: "../index.html"))
    try Data("changed".utf8).write(to: dir.appendingPathComponent("index.html"))
    XCTAssertThrowsError(try bundle.resource(path: "index.html"))
  }
  func testWrongPinUnlistedFileAndOfficialAreRejected() throws {
    let dir = try root()
    let pin = try manifest(dir)
    XCTAssertThrowsError(
      try VerifiedCockpitBundle(root: dir, manifestSHA256: String(repeating: "0", count: 64)))
    try Data().write(to: dir.appendingPathComponent("extra.js"))
    XCTAssertThrowsError(try VerifiedCockpitBundle(root: dir, manifestSHA256: pin))
    try FileManager.default.removeItem(at: dir.appendingPathComponent("extra.js"))
    let official = try manifest(dir, edition: "official")
    XCTAssertThrowsError(try VerifiedCockpitBundle(root: dir, manifestSHA256: official))
    XCTAssertNoThrow(
      try VerifiedCockpitBundle(root: dir, manifestSHA256: official, allowOfficial: true))
  }
  func testSymlinkAndTraversalAreRejectedIncludingAtServeTime() throws {
    let dir = try root()
    let pin = try manifest(dir)
    let bundle = try VerifiedCockpitBundle(root: dir, manifestSHA256: pin)
    try FileManager.default.moveItem(
      at: dir.appendingPathComponent("index.html"), to: dir.appendingPathComponent("hidden"))
    try FileManager.default.createSymbolicLink(
      atPath: dir.appendingPathComponent("index.html").path, withDestinationPath: "hidden")
    XCTAssertThrowsError(try bundle.resource(path: "index.html"))
    XCTAssertThrowsError(try VerifiedCockpitBundle(root: dir, manifestSHA256: pin))
    for path in ["/absolute", "a//b", "a/../b", "a/./b", "a\\b", ""] {
      XCTAssertFalse(VerifiedCockpitBundle.safe(path))
    }
  }
}
