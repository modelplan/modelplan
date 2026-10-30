import ModelPlanEngineClient
// SPDX-License-Identifier: MIT
import XCTest

@testable import ModelPlanCockpitWeb

final class ActualClientTests: XCTestCase {
  @MainActor func testPublishedCLIQueryAndClearThroughActualClientConstructor() async throws {
    guard let binary = ProcessInfo.processInfo.environment["MODELPLAN_U11_TEST_CLI"] else {
      throw XCTSkip("Supply the pinned project CLI; synthetic only")
    }
    let home = FileManager.default.temporaryDirectory.appendingPathComponent(
      "u11-engine-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }
    let environment = [
      "HOME": home.path, "TMPDIR": home.path, "PATH": "/usr/bin:/bin", "LANG": "en_US.UTF-8",
    ]
    let initProcess = Process()
    initProcess.executableURL = URL(fileURLWithPath: binary)
    initProcess.arguments = ["consent", "init", "--json"]
    initProcess.environment = environment
    initProcess.standardInput = FileHandle.nullDevice
    initProcess.standardOutput = FileHandle.nullDevice
    initProcess.standardError = FileHandle.nullDevice
    try initProcess.run()
    for _ in 0..<300 {
      if !initProcess.isRunning { break }
      try await Task.sleep(for: .milliseconds(10))
    }
    if initProcess.isRunning {
      initProcess.terminate()
      XCTFail("synthetic init timed out")
      return
    }
    XCTAssertEqual(initProcess.terminationStatus, 0)
    var page: PageProbe?
    let coordinator = EngineCockpitCoordinator {
      let p = PageProbe($0)
      page = p
      return p
    }
    let client = coordinator.makeClient(
      configuration: .init(
        executableURL: URL(fileURLWithPath: binary), applicationVersion: "synthetic-u11-test",
        allowedEnvironment: environment, offline: true, readOnly: true))
    _ = try await client.start()
    coordinator.open()
    for _ in 0..<500 {
      if page?.displays == 1 { break }
      try await Task.sleep(for: .milliseconds(10))
    }
    XCTAssertEqual(
      page?.displays, 1,
      "Actual cockpit/query must reach the same page through the ordered event consumer")
    XCTAssertTrue(page?.privateVisible == true)
    await coordinator.shutdown()
    XCTAssertTrue(page?.state.disposed == true)
    XCTAssertFalse(page?.privateVisible == true)
  }
}
