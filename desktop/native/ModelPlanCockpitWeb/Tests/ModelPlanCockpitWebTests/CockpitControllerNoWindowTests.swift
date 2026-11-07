// SPDX-License-Identifier: MIT
#if MODELPLAN_TEST_ONLY_SPI
import AppKit
import Foundation
import XCTest
import ModelPlanWire
@testable import ModelPlanCockpitWeb

/// Uses the actual controller and bridge with fake delivery and scheduler; it
/// never calls open() or creates a WebView, window, panel or system event.
@MainActor final class CockpitControllerNoWindowTests: XCTestCase {
  private let source = CockpitMessageSource(mainFrame: true, origin: "modelplan-cockpit://bundle")
  private func reply(_ raw: String, type: String, sequence: Int, extra: [String: Any] = [:]) throws -> String {
    var value = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
    for key in ["data", "appearance", "shell", "theme", "locale", "reduceMotion", "reduceTransparency", "showProjectNames", "redBelow", "nowUnixMs", "reason"] { value[key] = nil }
    value["type"] = type; value["sequence"] = String(sequence)
    if type == "ready" { value["appearanceVersion"] = 2; value["capabilities"] = ["appearanceUpdates", "shellState", "shellActions"] }
    for (key, field) in extra { value[key] = field }
    return String(decoding: try JSONSerialization.data(withJSONObject: value), as: UTF8.self)
  }
  private func fixture() throws -> WireCockpitData {
    let url = try XCTUnwrap(Bundle.module.url(forResource: "cockpit", withExtension: "json", subdirectory: "Fixtures"))
    return try JSONDecoder().decode(WireCockpitData.self, from: Data(contentsOf: url))
  }
  private func page() throws -> CockpitWindowController {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("cockpit-no-window-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: root) }
    let html = Data("synthetic".utf8); try html.write(to: root.appendingPathComponent("index.html"))
    let manifest = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "edition": "community", "interfaceOnly": true, "files": ["index.html": VerifiedCockpitBundle.digest(html)]])
    try manifest.write(to: root.appendingPathComponent("bundle-manifest.json"))
    let bundle = try VerifiedCockpitBundle(root: root, manifestSHA256: VerifiedCockpitBundle.digest(manifest))
    let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic", generation: 1)
    return CockpitWindowController(bundle: bundle, context: context, appearance: .init(theme: .night, locale: .en, profile: .full))
  }
  private func prepare(_ page: CockpitWindowController) throws {
    let shell = CockpitShellState(closed: false, attached: true, forcedClosed: false, tier: .tall)
    page.verificationNoWindowShell = shell
    let load = try page.bridge.load(.init(theme: .night, locale: .en, profile: .full), shell: shell)
    _ = try page.bridge.accept(reply(load, type: "ready", sequence: 1), source: source)
    try page.verificationConfirmVisible()
  }
  func testDisplayCompletionBeforeRenderedDefersAppearanceForBothReceiptOrders() throws {
    for reportBeforeRendered in [true, false] {
      let page = try page(); var sent: [(String, (CockpitDeliveryResult) -> Void)] = []
      var arms: [UInt64] = []
      page.verificationNoWindowClock = { 1_000 }
      page.verificationNoWindowArm = { delay, _ in arms.append(delay); return {} }
      page.verificationNoWindowDelivery = { raw, complete in sent.append((raw, complete)) }
      page.onFailure = { failure in XCTFail("Unexpected no-window controller failure: \(failure)") }
      try prepare(page)
      page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket))
      XCTAssertEqual(sent.count, 1); let display = sent[0].0
      sent[0].1(.accepted) // WebKit completion arrives; rendered receipt is delayed.
      page.updateAppearance(.init(theme: .night, locale: .zhCN, profile: .full, redBelow: 15))
      XCTAssertEqual(sent.count, 1, "Appearance and shell must wait for current rendered receipt")
      if reportBeforeRendered {
        page.verificationReceive(try reply(display, type: "nextDeadline", sequence: 3, extra: ["deadlineUnixMs": "1500"]), source: source)
      }
      page.verificationReceive(try reply(display, type: "rendered", sequence: 2), source: source)
      XCTAssertGreaterThanOrEqual(sent.count, 2)
      if !reportBeforeRendered {
        page.verificationReceive(try reply(display, type: "nextDeadline", sequence: 3, extra: ["deadlineUnixMs": "1500"]), source: source)
      }
      sent[1].1(.accepted) // Pending show tick is superseded; queue can now send appearance.
      XCTAssertGreaterThanOrEqual(sent.count, 3)
      let appearance = sent[2].0
      let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(appearance.utf8)) as? [String: Any])
      XCTAssertEqual(object["type"] as? String, "appearance")
      XCTAssertEqual(object["redBelow"] as? Int, 15, "The controller must retain the committed threshold when it resends appearance")
      let report = try reply(appearance, type: "nextDeadline", sequence: 4, extra: ["deadlineUnixMs": "1500"])
      if reportBeforeRendered {
        page.verificationReceive(report, source: source); sent[2].1(.accepted)
      } else {
        sent[2].1(.accepted); page.verificationReceive(report, source: source)
      }
      XCTAssertTrue(arms.contains(500), "The correlated appearance deadline arms the fake scheduler")
      XCTAssertNil(page.window); page.discard()
    }
  }
  func testPendingReplacementKeepsPriorDeadlineUntilNewReport() throws {
    let page = try page(); var sent: [(String, (CockpitDeliveryResult) -> Void)] = []
    var now: UInt64 = 1_000, timers: [(UInt64, @MainActor () -> Void)] = []
    page.verificationNoWindowClock = { now }
    page.verificationNoWindowArm = { delay, fire in timers.append((delay, fire)); return {} }
    page.verificationNoWindowDelivery = { raw, complete in sent.append((raw, complete)) }
    page.onFailure = { failure in XCTFail("Unexpected no-window controller failure: \(failure)") }
    try prepare(page)
    page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket))
    let initial = try XCTUnwrap(sent.first).0; sent[0].1(.accepted)
    page.verificationReceive(try reply(initial, type: "rendered", sequence: 2), source: source)
    XCTAssertGreaterThanOrEqual(sent.count, 2)
    let showTick = sent[1].0; sent[1].1(.accepted)
    page.verificationReceive(try reply(showTick, type: "nextDeadline", sequence: 3, extra: ["deadlineUnixMs": "1500"]), source: source)
    let prior = try XCTUnwrap(timers.last(where: { $0.0 == 500 })).1
    page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket))
    XCTAssertGreaterThanOrEqual(sent.count, 3); let replacement = sent[2].0; sent[2].1(.accepted)
    page.updateAppearance(.init(theme: .night, locale: .zhCN, profile: .full))
    XCTAssertEqual(sent.count, 3)
    now = 1_500; prior()
    XCTAssertGreaterThanOrEqual(sent.count, 4, "The previously admitted deadline must still fire")
    let tick = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(sent[3].0.utf8)) as? [String: Any])
    XCTAssertEqual(tick["type"] as? String, "tick")
    page.verificationReceive(try reply(replacement, type: "rendered", sequence: 4), source: source)
    sent[3].1(.accepted)
    XCTAssertGreaterThanOrEqual(sent.count, 5)
    let appearance = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(sent[4].0.utf8)) as? [String: Any])
    XCTAssertEqual(appearance["type"] as? String, "appearance")
    XCTAssertNil(page.window); page.discard()
  }
  func testAppearanceInFlightDoesNotAssumePriorDeadlineIsInvalid() throws {
    let page = try page(); var sent: [(String, (CockpitDeliveryResult) -> Void)] = []
    var now: UInt64 = 1_000, timers: [(UInt64, @MainActor () -> Void)] = []
    page.verificationNoWindowClock = { now }
    page.verificationNoWindowArm = { delay, fire in timers.append((delay, fire)); return {} }
    page.verificationNoWindowDelivery = { raw, complete in sent.append((raw, complete)) }
    page.onFailure = { failure in XCTFail("Unexpected no-window controller failure: \(failure)") }
    try prepare(page)
    page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket))
    let display = try XCTUnwrap(sent.first).0; sent[0].1(.accepted)
    page.verificationReceive(try reply(display, type: "rendered", sequence: 2), source: source)
    let showTick = try XCTUnwrap(sent.dropFirst().first).0; sent[1].1(.accepted)
    page.verificationReceive(try reply(showTick, type: "nextDeadline", sequence: 3, extra: ["deadlineUnixMs": "1500"]), source: source)
    let prior = try XCTUnwrap(timers.last(where: { $0.0 == 500 })).1
    page.updateAppearance(.init(theme: .night, locale: .zhCN, profile: .full))
    XCTAssertGreaterThanOrEqual(sent.count, 3)
    now = 1_500; prior() // The appearance is still in flight.
    sent[2].1(.accepted) // Superseded appearance cannot retag its late callback.
    XCTAssertGreaterThanOrEqual(sent.count, 4)
    sent[3].1(.accepted) // The queued shell precedes the tick.
    XCTAssertGreaterThanOrEqual(sent.count, 5)
    let tick = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(sent[4].0.utf8)) as? [String: Any])
    XCTAssertEqual(tick["type"] as? String, "tick", "The previously admitted deadline remains live")
    XCTAssertNil(page.window); page.discard()
  }
  func testContinuousDisplayReplacementsCannotStarveDeferredAppearance() throws {
    let page = try page(); var sent: [(String, (CockpitDeliveryResult) -> Void)] = []
    var timers: [(UInt64, @MainActor () -> Void)] = [], failures: [CockpitWindowFailure] = []
    page.verificationNoWindowClock = { 1_000 }
    page.verificationNoWindowArm = { delay, fire in timers.append((delay, fire)); return {} }
    page.verificationNoWindowDelivery = { raw, complete in sent.append((raw, complete)) }
    page.onFailure = { failures.append($0) }
    try prepare(page)
    page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket))
    let count = timers.count
    page.updateAppearance(.init(theme: .night, locale: .zhCN, profile: .full))
    XCTAssertEqual(timers.count, count + 1, "The first deferred appearance starts a bounded wait")
    let appearanceTimeout = try XCTUnwrap(timers.last).1
    for _ in 0..<4 { page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket)) }
    XCTAssertEqual(sent.count, 1, "Replacement displays remain ordered behind the active send")
    appearanceTimeout()
    XCTAssertEqual(failures, [.appearanceWaitTimeout], "Continuous replacements must fail in bounded time")
    XCTAssertNil(page.window)
  }
  func testQueuedAppearanceSupersededByDeadlineIsResentAfterTick() throws {
    let page = try page(); var sent: [(String, (CockpitDeliveryResult) -> Void)] = []
    var now: UInt64 = 1_000, timers: [(UInt64, @MainActor () -> Void)] = []
    page.verificationNoWindowClock = { now }
    page.verificationNoWindowArm = { delay, fire in timers.append((delay, fire)); return {} }
    page.verificationNoWindowDelivery = { raw, complete in sent.append((raw, complete)) }
    page.onFailure = { failure in XCTFail("Unexpected no-window controller failure: \(failure)") }
    try prepare(page)
    page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket))
    let display = try XCTUnwrap(sent.first).0; sent[0].1(.accepted)
    page.verificationReceive(try reply(display, type: "rendered", sequence: 2), source: source)
    let showTick = sent[1].0; sent[1].1(.accepted)
    page.verificationReceive(try reply(showTick, type: "nextDeadline", sequence: 3, extra: ["deadlineUnixMs": "1500"]), source: source)
    let prior = try XCTUnwrap(timers.last(where: { $0.0 == 500 })).1
    page.updateAppearance(.init(theme: .night, locale: .en, profile: .full))
    sent[2].1(.accepted) // First appearance completes; its shell is now blocked.
    XCTAssertGreaterThanOrEqual(sent.count, 4)
    page.updateAppearance(.init(theme: .night, locale: .zhCN, profile: .full))
    now = 1_500; prior() // Tick supersedes the queued, not-yet-delivered appearance.
    sent[3].1(.accepted) // Release the previous shell; stale appearance is skipped.
    XCTAssertGreaterThanOrEqual(sent.count, 5)
    sent[4].1(.accepted) // Its already-queued shell still precedes the tick.
    XCTAssertGreaterThanOrEqual(sent.count, 6)
    let tick = sent[5].0; sent[5].1(.accepted)
    page.verificationReceive(try reply(tick, type: "nextDeadline", sequence: 4, extra: ["deadlineUnixMs": "2000"]), source: source)
    XCTAssertGreaterThanOrEqual(sent.count, 7, "Latest appearance must be retried after the correlated tick")
    let latest = sent[6].0
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(latest.utf8)) as? [String: Any])
    XCTAssertEqual(object["type"] as? String, "appearance"); XCTAssertEqual(object["locale"] as? String, "zh-CN")
    sent[6].1(.accepted)
    page.verificationReceive(try reply(latest, type: "nextDeadline", sequence: 5, extra: ["deadlineUnixMs": NSNull()]), source: source)
    XCTAssertNil(page.window); page.discard()
  }
  func testEarlyDisplayDeadlineThenActionBeforeRenderedDoesNotClosePage() throws {
    let page = try page(); var sent: [(String, (CockpitDeliveryResult) -> Void)] = []
    var failures: [CockpitWindowFailure] = [], intents: [CockpitIntent] = [], delays: [UInt64] = []
    page.verificationNoWindowClock = { 1_000 }
    page.verificationNoWindowArm = { delay, _ in delays.append(delay); return {} }
    page.verificationNoWindowDelivery = { raw, complete in sent.append((raw, complete)) }
    page.onFailure = { failures.append($0) }; page.onIntent = { intents.append($0) }
    try prepare(page)
    page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket))
    let previous = try XCTUnwrap(sent.first).0; sent[0].1(.accepted)
    page.verificationReceive(try reply(previous, type: "rendered", sequence: 2), source: source)
    let showTick = try XCTUnwrap(sent.dropFirst().first).0; sent[1].1(.accepted)
    page.verificationReceive(try reply(showTick, type: "nextDeadline", sequence: 3, extra: ["deadlineUnixMs": NSNull()]), source: source)
    page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket))
    XCTAssertGreaterThanOrEqual(sent.count, 3); let current = sent[2].0; sent[2].1(.accepted)
    page.verificationReceive(try reply(current, type: "nextDeadline", sequence: 5, extra: ["deadlineUnixMs": "1500"]), source: source)
    let action = try reply(current, type: "action", sequence: 6, extra: ["action": "scopeSelect", "key": "all", "requestId": UUID().uuidString])
    page.verificationReceive(action, source: source)
    page.verificationReceive(try reply(current, type: "rendered", sequence: 4), source: source)
    XCTAssertEqual(intents, [.scopeSelect("all")]); XCTAssertTrue(failures.isEmpty)
    XCTAssertTrue(delays.contains(500), "The valid delayed rendered receipt releases its deadline")
    XCTAssertFalse(page.bridge.disposed); XCTAssertNil(page.window); page.discard()
  }
  func testNonconvergingPastDeadlinesFailClosedWithoutWindow() throws {
    let page = try page(); var sent: [(String, (CockpitDeliveryResult) -> Void)] = []
    var timers: [(UInt64, @MainActor () -> Void)] = [], failures: [CockpitWindowFailure] = []
    page.verificationNoWindowClock = { 10_000 }
    page.verificationNoWindowArm = { delay, fire in timers.append((delay, fire)); return {} }
    page.verificationNoWindowDelivery = { raw, complete in sent.append((raw, complete)) }
    page.onFailure = { failures.append($0) }
    try prepare(page)
    page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket))
    let display = try XCTUnwrap(sent.first).0; sent[0].1(.accepted)
    page.verificationReceive(try reply(display, type: "rendered", sequence: 2), source: source)
    for value in 1...CockpitDeadlineDriver.maximumImmediateAdvances {
      let current = try XCTUnwrap(sent.last); current.1(.accepted)
      page.verificationReceive(try reply(current.0, type: "nextDeadline", sequence: value + 2, extra: ["deadlineUnixMs": String(value)]), source: source)
      let fire = try XCTUnwrap(timers.last(where: { $0.0 == 0 })).1
      fire()
      XCTAssertTrue(failures.isEmpty, "Every earlier advancing expiry must tick")
    }
    let last = try XCTUnwrap(sent.last); last.1(.accepted)
    page.verificationReceive(try reply(last.0, type: "nextDeadline", sequence: CockpitDeadlineDriver.maximumImmediateAdvances + 3, extra: ["deadlineUnixMs": String(CockpitDeadlineDriver.maximumImmediateAdvances + 1)]), source: source)
    XCTAssertEqual(failures, [.deadlineConvergence])
    XCTAssertTrue(page.bridge.disposed); XCTAssertNil(page.window)
  }
  func testDeferredAppearanceCannotCrossHideAndNewGeneration() throws {
    let page = try page(); var sent: [(String, (CockpitDeliveryResult) -> Void)] = []
    page.verificationNoWindowClock = { 1_000 }
    page.verificationNoWindowArm = { _, _ in return {} }
    page.verificationNoWindowDelivery = { raw, complete in sent.append((raw, complete)) }
    try prepare(page)
    page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket))
    let old = try XCTUnwrap(sent.first).0; sent[0].1(.accepted)
    page.updateAppearance(.init(theme: .night, locale: .zhCN, profile: .full))
    try page.verificationHideWithoutWindow()
    let next = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic-next", generation: 2)
    let clear = try page.bridge.clear(adopting: next)
    page.verificationReceive(try reply(clear, type: "cleared", sequence: 2), source: source)
    page.verificationReceive(try reply(old, type: "rendered", sequence: 3), source: source)
    XCTAssertEqual(sent.count, 1, "Old render acknowledgement cannot release deferred appearance")
    XCTAssertNil(page.window); page.discard()
  }
}
#endif
