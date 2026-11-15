// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanWire
@testable import ModelPlanCockpitWeb

/// G3-86 (14c device run, C-01): about 68 s after a good open the cockpit ended with `localEncoding` at
/// the refused-submission branch of `send` (device log `send(...):534`). The ordered delivery queue was full:
/// whole-state messages (appearance, shell) and superseded triggers kept their slots until they reached the
/// front. These tests drive the real queue, bridge and controller.
@MainActor final class CockpitDeliveryBacklogTests: XCTestCase {
  // MARK: queue

  func testNewerWholeStateMessageReplacesQueuedOlderOneAtTheBack() {
    var delivered: [String] = [], completions: [(CockpitDeliveryResult) -> Void] = []
    let queue = CockpitOrderedDelivery<String>(deliver: { raw, done in delivered.append(raw); completions.append(done) })
    XCTAssertTrue(queue.submit("held", isCurrent: { true }, completed: { _ in }))
    XCTAssertTrue(queue.submit("shell-1", coalesce: "shell", isCurrent: { true }, completed: { _ in }))
    XCTAssertTrue(queue.submit("display", isCurrent: { true }, completed: { _ in }))
    XCTAssertTrue(queue.submit("shell-2", coalesce: "shell", isCurrent: { true }, completed: { _ in }))
    XCTAssertEqual(queue.outstanding, 3)
    completions[0](.accepted); completions[1](.accepted)
    XCTAssertEqual(delivered, ["held", "display", "shell-2"], "The newer shell goes last, so host sequence order holds")
  }

  func testFullQueueDropsSupersededWorkBeforeRefusing() {
    var current = Set<Int>()
    let queue = CockpitOrderedDelivery<Int>(capacity: 4, deliver: { _, _ in })
    for n in 0..<40 {
      current = [n]
      XCTAssertTrue(queue.submit(n, isCurrent: { [n] in current.contains(n) || n == 0 }, completed: { _ in }),
                    "Superseded triggers must not fill the queue (message \(n))")
    }
    XCTAssertLessThanOrEqual(queue.outstanding, 4)
    // Only work that is still current can fill it.
    let bounded = CockpitOrderedDelivery<Int>(capacity: 2, deliver: { _, _ in })
    XCTAssertTrue(bounded.submit(1, isCurrent: { true }, completed: { _ in }))
    XCTAssertTrue(bounded.submit(2, isCurrent: { true }, completed: { _ in }))
    XCTAssertFalse(bounded.submit(3, isCurrent: { true }, completed: { _ in }))
  }

  // MARK: encoding

  /// Reads the fixture with NaN and infinities where the wire has optional numbers (a quota percent and a
  /// credit balance), as a reader dividing by a zero window would produce if it ever reached the host.
  static func nonFiniteFixture() throws -> WireCockpitData {
    let url = try XCTUnwrap(Bundle.module.url(forResource: "cockpit", withExtension: "json", subdirectory: "Fixtures"))
    var text = try String(contentsOf: url, encoding: .utf8)
    XCTAssertTrue(text.contains("\"remainingPercent\": 42.5") && text.contains("\"balance\": 42.5"))
    text = text.replacingOccurrences(of: "\"remainingPercent\": 42.5", with: "\"remainingPercent\": \"NaN\"")
      .replacingOccurrences(of: "\"balance\": 42.5", with: "\"balance\": \"Infinity\"")
    let decoder = JSONDecoder()
    decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
    return try decoder.decode(WireCockpitData.self, from: Data(text.utf8))
  }

  func testNonFiniteNumbersAreSentAsNullWithTheirPaths() throws {
    let data = try Self.nonFiniteFixture()
    XCTAssertThrowsError(try JSONEncoder().encode(data), "Precondition: a plain encoder refuses NaN")
    let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "fixture-epoch", generation: 1)
    let state = CockpitBridgeState(context: context)
    let load = try state.load(.init(theme: .night, locale: .en, profile: .full),
                              shell: .init(closed: false, attached: true, forcedClosed: false, tier: .tall))
    var ready = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(load.utf8)) as? [String: Any])
    for key in ["appearance", "shell", "redBelow", "showUsedPercent", "showAllModels", "pinnedModels", "ackedCautions"] { ready[key] = nil }
    ready["type"] = "ready"; ready["sequence"] = "1"; ready["appearanceVersion"] = 2
    ready["capabilities"] = ["appearanceUpdates", "shellState", "shellActions"]
    let source = CockpitMessageSource(mainFrame: true, origin: "modelplan-cockpit://bundle")
    _ = try state.accept(String(decoding: try JSONSerialization.data(withJSONObject: ready), as: UTF8.self), source: source)
    let raw = try state.display(data, ticket: try XCTUnwrap(state.queryTicket))
    XCTAssertFalse(raw.contains("NaN") || raw.contains("Infinity") || raw.contains("nonfinite"))
    let paths = state.lastNonFinitePaths
    XCTAssertEqual(paths.count, 4, "two percents and two balances: \(paths)")
    // The fixture carries one set in the projection rows and one in the subscriptions.
    XCTAssertEqual(Set(paths), [
      "data.projection.rows[0].accounts[0].credits.balance",
      "data.projection.rows[0].accounts[0].windows[0].remainingPercent",
      "data.subscriptions[0].accounts[0].account.credits.balance",
      "data.subscriptions[0].accounts[0].account.windows[0].remainingPercent",
    ], "\(paths)")
    XCTAssertTrue(paths.contains { $0.hasSuffix(".credits.balance") })
    XCTAssertTrue(paths.contains { $0.hasSuffix(".remainingPercent") })
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
    let rows = try XCTUnwrap(((object["data"] as? [String: Any])?["projection"] as? [String: Any])?["rows"] as? [[String: Any]])
    let account = try XCTUnwrap((rows.first?["accounts"] as? [[String: Any]])?.first)
    XCTAssertTrue((account["credits"] as? [String: Any])?["balance"] is NSNull)
    // A finite snapshot leaves nothing behind.
    _ = try state.display(try JSONDecoder().decode(WireCockpitData.self, from: Data(contentsOf: XCTUnwrap(
      Bundle.module.url(forResource: "cockpit", withExtension: "json", subdirectory: "Fixtures")))), ticket: try XCTUnwrap(state.queryTicket))
    XCTAssertEqual(state.lastNonFinitePaths, [])
  }

  #if MODELPLAN_TEST_ONLY_SPI
  // MARK: controller

  private let source = CockpitMessageSource(mainFrame: true, origin: "modelplan-cockpit://bundle")
  private func reply(_ raw: String, type: String, sequence: Int, extra: [String: Any] = [:]) throws -> String {
    var value = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
    for key in ["data", "appearance", "shell", "theme", "locale", "reduceMotion", "reduceTransparency", "showProjectNames", "redBelow", "showUsedPercent", "showAllModels", "pinnedModels", "ackedCautions", "nowUnixMs", "reason"] { value[key] = nil }
    value["type"] = type; value["sequence"] = String(sequence)
    if type == "ready" { value["appearanceVersion"] = 2; value["capabilities"] = ["appearanceUpdates", "shellState", "shellActions"] }
    for (key, field) in extra { value[key] = field }
    return String(decoding: try JSONSerialization.data(withJSONObject: value), as: UTF8.self)
  }
  private func fixture() throws -> WireCockpitData {
    let url = try XCTUnwrap(Bundle.module.url(forResource: "cockpit", withExtension: "json", subdirectory: "Fixtures"))
    return try JSONDecoder().decode(WireCockpitData.self, from: Data(contentsOf: url))
  }
  private func type(_ raw: String) -> String? {
    (try? JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])?["type"] as? String
  }
  private struct Harness {
    let page: CockpitWindowController
    var sent: [(String, (CockpitDeliveryResult) -> Void)] { box.sent }
    let box: Box
    final class Box { var sent: [(String, (CockpitDeliveryResult) -> Void)] = []; var failures: [CockpitWindowFailure] = []; var lines: [String] = []; var ready = 0 }
  }
  /// A visible page that has rendered one display and answered the show tick, all deliveries completed.
  private func renderedPage() throws -> Harness {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("cockpit-backlog-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: root) }
    let html = Data("synthetic".utf8); try html.write(to: root.appendingPathComponent("index.html"))
    let manifest = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "edition": "community", "interfaceOnly": true, "files": ["index.html": VerifiedCockpitBundle.digest(html)]])
    try manifest.write(to: root.appendingPathComponent("bundle-manifest.json"))
    let bundle = try VerifiedCockpitBundle(root: root, manifestSHA256: VerifiedCockpitBundle.digest(manifest))
    let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic", generation: 1)
    let page = CockpitWindowController(bundle: bundle, context: context, appearance: .init(theme: .night, locale: .en, profile: .full))
    let box = Harness.Box()
    page.verificationNoWindowClock = { 1_000 }
    page.verificationNoWindowArm = { _, _ in {} }
    page.verificationNoWindowDelivery = { raw, complete in box.sent.append((raw, complete)) }
    page.onFailure = { box.failures.append($0) }
    page.onReady = { box.ready += 1 }
    CockpitFailureLog.verificationLine = { box.lines.append($0) }
    addTeardownBlock { @MainActor in CockpitFailureLog.verificationLine = nil }
    let shell = CockpitShellState(closed: false, attached: true, forcedClosed: false, tier: .tall)
    page.verificationNoWindowShell = shell
    let load = try page.bridge.load(.init(theme: .night, locale: .en, profile: .full), shell: shell)
    _ = try page.bridge.accept(reply(load, type: "ready", sequence: 1), source: source)
    try page.verificationConfirmVisible()
    page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket))
    XCTAssertEqual(box.sent.count, 1); box.sent[0].1(.accepted)
    page.verificationReceive(try reply(box.sent[0].0, type: "rendered", sequence: 2), source: source)
    XCTAssertEqual(box.sent.count, 2); XCTAssertEqual(type(box.sent[1].0), "tick")
    box.sent[1].1(.accepted)
    page.verificationReceive(try reply(box.sent[1].0, type: "nextDeadline", sequence: 3, extra: ["deadlineUnixMs": "5000"]), source: source)
    XCTAssertEqual(box.failures, [])
    return Harness(page: page, box: box)
  }

  /// The device failure: a burst of settings re-applies while one call is in flight queued an appearance and a
  /// shell per apply; the 17th apply overflowed the 32 slots and the page ended as `localEncoding`.
  func testAppearanceBurstWhileACallIsInFlightKeepsTheCockpit() throws {
    let h = try renderedPage()
    let locales: [CockpitAppearance.Locale] = [.zhCN, .en]
    for n in 0..<40 { h.page.updateAppearance(.init(theme: .night, locale: locales[n % 2], profile: .full)) }
    XCTAssertEqual(h.box.failures, [], "A burst of whole-state updates must not end the cockpit")
    XCTAssertFalse(h.box.lines.contains { $0.contains("page-failure") })
    XCTAssertEqual(h.sent.count, 3, "Only the first appearance is in flight")
    h.sent[2].1(.accepted)
    var index = 3
    while index < h.sent.count { h.sent[index].1(.accepted); index += 1 }
    let after = h.sent.dropFirst(3).map { type($0.0) ?? "?" }
    XCTAssertEqual(after, ["appearance", "shell"], "Superseded appearances and shells are skipped; the latest state is sent once")
    let last = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(h.sent[3].0.utf8)) as? [String: Any])
    XCTAssertEqual(last["locale"] as? String, CockpitAppearance.Locale.en.rawValue, "The last requested appearance wins")
    XCTAssertEqual(h.box.failures, [])
    h.page.discard()
  }

  func testOneRefusedDisplayIsSkippedAndRefreshedWhenTheQueueMoves() throws {
    let h = try renderedPage()
    h.page.verificationRefuseSubmissions = 1
    h.page.display(try fixture(), ticket: try XCTUnwrap(h.page.queryTicket))
    XCTAssertEqual(h.box.failures, [], "One refused update must not end the cockpit")
    XCTAssertEqual(h.sent.count, 2, "The refused display was not delivered")
    XCTAssertTrue(h.box.lines.contains { $0.hasPrefix("delivery-skipped type=display") }, "\(h.box.lines)")
    XCTAssertFalse(h.page.bridge.hasPendingDisplay, "No receipt is awaited for a display the page never got")
    XCTAssertEqual(h.box.ready, 0)
    // The next delivery that completes resends: the coordinator's onReady asks the engine again.
    h.page.updateAppearance(.init(theme: .night, locale: .zhCN, profile: .full))
    XCTAssertEqual(type(h.sent[2].0), "appearance")
    h.sent[2].1(.accepted)
    XCTAssertEqual(h.box.ready, 1, "The skipped display is refreshed once the queue moves")
    XCTAssertTrue(h.box.lines.contains { $0.hasPrefix("delivery-resync display=true") })
    XCTAssertEqual(type(h.sent[3].0), "shell"); h.sent[3].1(.accepted)
    // The coordinator answers onReady with a fresh display, which now reaches the page.
    h.page.display(try fixture(), ticket: try XCTUnwrap(h.page.queryTicket))
    XCTAssertEqual(h.sent.count, 5); XCTAssertEqual(type(h.sent[4].0), "display", "The refreshed display is delivered")
    h.sent[4].1(.accepted)
    XCTAssertEqual(h.box.failures, [])
    h.page.discard()
  }

  func testAQueueThatStaysStuckStillEndsThePageWithItsOwnFailure() throws {
    let h = try renderedPage()
    h.page.verificationRefuseSubmissions = CockpitWindowController.maximumDeliveryRefusals
    for _ in 0..<(CockpitWindowController.maximumDeliveryRefusals - 1) {
      h.page.display(try fixture(), ticket: try XCTUnwrap(h.page.queryTicket))
    }
    XCTAssertEqual(h.box.failures, [])
    h.page.display(try fixture(), ticket: try XCTUnwrap(h.page.queryTicket))
    XCTAssertEqual(h.box.failures, [.deliveryBacklog], "Repeated refusals end the page, named for what happened")
    XCTAssertTrue(h.box.lines.contains { $0.contains("page-failure failure=deliveryBacklog") })
    XCTAssertFalse(h.box.failures.contains(.localEncoding))
  }

  func testNonFiniteSnapshotKeepsTheCockpitAndLogsTheFieldPath() throws {
    let h = try renderedPage()
    h.page.display(try Self.nonFiniteFixture(), ticket: try XCTUnwrap(h.page.queryTicket))
    XCTAssertEqual(h.box.failures, [], "A NaN or infinite value must not end the cockpit as localEncoding")
    let display = try XCTUnwrap(h.sent.last)
    XCTAssertEqual(type(display.0), "display")
    XCTAssertFalse(display.0.contains("NaN") || display.0.contains("Infinity"))
    XCTAssertTrue(h.box.lines.contains { $0.hasPrefix("display-non-finite path=data.projection.rows[") }, "\(h.box.lines)")
    XCTAssertFalse(h.box.lines.contains { $0.contains("42.5") || $0.contains("NaN") }, "Paths only, never values")
    display.1(.accepted)
    XCTAssertEqual(h.box.failures, [])
    h.page.discard()
  }
  #endif
}
