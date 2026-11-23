// SPDX-License-Identifier: MIT
#if MODELPLAN_TEST_ONLY_SPI
import Foundation
import XCTest
import ModelPlanWire
@testable import ModelPlanCockpitWeb

/// Recovery step 3 (G3-96, G3-116): delivery and receipt rules on the real controller, bridge and ordered queue, with
/// fake delivery and one fake timeline for the monotonic clock, wall clock, receipt watchdogs, data deadlines and
/// probes. Continuous replacements, slow completions, every receipt order, deadline storms and a saturated queue
/// never rebuild the page; one display runs with at most one replacement waiting, and host sequence order holds.
@MainActor final class CockpitDeliveryFairnessTests: XCTestCase {
  private let source = CockpitMessageSource(mainFrame: true, origin: "modelplan-cockpit://bundle")
  private func reply(_ raw: String, type: String, sequence: Int, extra: [String: Any] = [:]) throws -> String {
    var value = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
    for key in ["data", "appearance", "shell", "theme", "locale", "reduceMotion", "reduceTransparency", "showProjectNames", "redBelow", "showUsedPercent", "showAllModels", "ackedCautions", "pinnedModels", "memberOrder", "hiddenMembers", "nowUnixMs", "reason", "visible", "occluded", "key", "profile", "attached", "forcedClosed", "tier", "scope", "range"] { value[key] = nil }
    value["type"] = type; value["sequence"] = String(sequence)
    if type == "ready" { value["appearanceVersion"] = 2; value["capabilities"] = ["appearanceUpdates", "shellState", "shellActions"] }
    for (key, field) in extra { value[key] = field }
    return String(decoding: try JSONSerialization.data(withJSONObject: value), as: UTF8.self)
  }
  private func fixture() throws -> WireCockpitData {
    let url = try XCTUnwrap(Bundle.module.url(forResource: "cockpit", withExtension: "json", subdirectory: "Fixtures"))
    return try JSONDecoder().decode(WireCockpitData.self, from: Data(contentsOf: url))
  }
  private func field(_ raw: String, _ key: String) -> String? {
    (try? JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])?[key] as? String
  }

  /// One timeline: `now` is both the monotonic and the wall clock; every timer (watchdogs, deadlines, probes) is due
  /// on it and fires only when the test advances.
  private final class Line {
    var sent: [(raw: String, complete: (CockpitDeliveryResult) -> Void)] = []
    var completed = 0
    var failures: [CockpitWindowFailure] = []
    var lines: [String] = []
    var now: UInt64 = 1_000
    var timers: [Int: (due: UInt64, fire: @MainActor () -> Void)] = [:]
    var nextID = 0
    var pageSequence = 3
    func arm(_ delay: UInt64, _ fire: @escaping @MainActor () -> Void) -> () -> Void {
      let id = nextID; nextID += 1
      timers[id] = (due: now + delay, fire: fire)
      return { [weak self] in self?.timers[id] = nil }
    }
    @MainActor func advance(to time: UInt64) {
      while let next = timers.filter({ $0.value.due <= time }).min(by: { ($0.value.due, $0.key) < ($1.value.due, $1.key) }) {
        timers[next.key] = nil; now = max(now, next.value.due); next.value.fire()
      }
      now = max(now, time)
    }
  }
  private func page(_ line: Line, probeAnswers: Bool = true) throws -> CockpitWindowController {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("cockpit-fairness-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: root) }
    let html = Data("synthetic".utf8); try html.write(to: root.appendingPathComponent("index.html"))
    let manifest = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "edition": "community", "interfaceOnly": true, "files": ["index.html": VerifiedCockpitBundle.digest(html)]])
    try manifest.write(to: root.appendingPathComponent("bundle-manifest.json"))
    let bundle = try VerifiedCockpitBundle(root: root, manifestSHA256: VerifiedCockpitBundle.digest(manifest))
    let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic", generation: 1)
    let page = CockpitWindowController(bundle: bundle, context: context, appearance: .init(theme: .night, locale: .en, profile: .full))
    page.verificationNoWindowClock = { line.now }
    page.verificationMonotonicClock = { line.now }
    page.verificationNoWindowArm = { delay, fire in line.arm(delay, fire) }
    page.verificationHealthArm = { delay, fire in line.arm(delay, fire) }
    page.verificationNoWindowDelivery = { raw, complete in line.sent.append((raw: raw, complete: complete)) }
    page.verificationProbe = { answer in if probeAnswers { answer("ready") } }
    page.onFailure = { line.failures.append($0) }
    CockpitFailureLog.verificationLine = { line.lines.append($0) }
    addTeardownBlock { @MainActor in CockpitFailureLog.verificationLine = nil }
    let shell = CockpitShellState(closed: false, attached: true, forcedClosed: false, tier: .tall)
    page.verificationNoWindowShell = shell
    let load = try page.bridge.load(.init(theme: .night, locale: .en, profile: .full), shell: shell)
    _ = try page.bridge.accept(reply(load, type: "ready", sequence: 1), source: source)
    try page.verificationConfirmVisible()
    page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket))
    XCTAssertEqual(line.sent.count, 1); complete(line, upTo: 1)
    page.verificationReceive(try reply(line.sent[0].raw, type: "rendered", sequence: 2), source: source)
    XCTAssertEqual(field(line.sent[1].raw, "type"), "tick"); complete(line, upTo: 2)
    page.verificationReceive(try reply(line.sent[1].raw, type: "nextDeadline", sequence: 3, extra: ["deadlineUnixMs": NSNull()]), source: source)
    XCTAssertEqual(line.failures, [])
    return page
  }
  /// Completes every delivered call up to `count` (calls delivered meanwhile are completed too, in order).
  private func complete(_ line: Line, upTo count: Int? = nil, _ result: CockpitDeliveryResult = .accepted) {
    while line.completed < min(count ?? Int.max, line.sent.count) {
      let index = line.completed; line.completed += 1
      line.sent[index].complete(result)
    }
  }
  private func assertAscendingSequence(_ line: Line, file: StaticString = #filePath, lineNumber: UInt = #line) {
    let sequences = line.sent.compactMap { field($0.raw, "sequence").flatMap(UInt64.init) }
    XCTAssertEqual(sequences.count, line.sent.count, file: file, line: lineNumber)
    XCTAssertEqual(sequences, sequences.sorted(), "Host sequence order holds in delivery order", file: file, line: lineNumber)
    XCTAssertEqual(Set(sequences).count, sequences.count, file: file, line: lineNumber)
  }
  private func assertNoRebuild(_ line: Line, _ page: CockpitWindowController, file: StaticString = #filePath, lineNumber: UInt = #line) {
    XCTAssertEqual(line.failures, [], file: file, line: lineNumber)
    XCTAssertFalse(page.bridge.disposed, file: file, line: lineNumber)
    XCTAssertFalse(line.lines.contains { $0.hasPrefix("page-failure") }, line.lines.joined(separator: "\n"), file: file, line: lineNumber)
  }

  /// One display runs and at most one replacement waits, however many replies arrive while it runs. Failing first:
  /// before step 3 every replacement held a queue slot until it reached the front.
  func testContinuousReplacementsKeepOneActiveDisplayAndOneWaitingReplacement() throws {
    let line = Line(); let page = try page(line)
    for _ in 0..<50 { page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket)) }
    XCTAssertEqual(page.verificationOutstanding, 2, "The active display and the latest replacement only")
    XCTAssertFalse(line.lines.contains { $0.hasPrefix("delivery-skipped") }, "Nothing was refused")
    let latest = try XCTUnwrap(page.bridge.currentDisplayRequest)
    complete(line, upTo: line.sent.count)
    XCTAssertEqual(field(try XCTUnwrap(line.sent.last).raw, "requestId"), latest.uuidString, "The next delivered display is the latest")
    XCTAssertEqual(line.sent.filter { field($0.raw, "type") == "display" }.count, 3, "Two displays reached the page for 51 replies")
    assertAscendingSequence(line); assertNoRebuild(line, page); page.discard()
  }

  /// Every call takes 2.5 s to complete and every render 3 s, with replies every second and an appearance change in the
  /// middle. The reading is delayed while renders lag, the page answers its probes, the appearance still goes out, and
  /// nothing is rebuilt over two minutes.
  func testCompletionsSlowerThanTwoSecondsNeverRebuildAndAppearanceStillGoesOut() throws {
    let line = Line(); let page = try page(line)
    var delayed: [Bool] = []
    page.onReadingDelayed = { delayed.append($0) }
    var inFlight: (index: Int, since: UInt64)?
    var rendering: [(raw: String, at: UInt64)] = []
    let start = line.now
    while line.now < start + 120_000 {
      if line.now == start + 30_000 { page.updateAppearance(.init(theme: .night, locale: .zhCN, profile: .full)) }
      page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket))
      for _ in 0..<10 {
        line.advance(to: line.now + 100)
        if inFlight == nil, line.completed < line.sent.count { inFlight = (line.completed, line.now) }
        if let call = inFlight, line.now - call.since >= 2_500 {
          inFlight = nil
          let raw = line.sent[call.index].raw
          complete(line, upTo: call.index + 1)
          if field(raw, "type") == "display" { rendering.append((raw, line.now)) }
        }
        while let first = rendering.first, line.now - first.at >= 3_000 {
          rendering.removeFirst()
          line.pageSequence += 1
          page.verificationReceive(try reply(first.raw, type: "rendered", sequence: line.pageSequence), source: source)
        }
      }
    }
    assertNoRebuild(line, page)
    XCTAssertTrue(delayed.contains(true), "Lagging renders delay the reading")
    let appearance = try XCTUnwrap(line.sent.first { field($0.raw, "type") == "appearance" }, "The appearance change reached the page")
    XCTAssertEqual(field(appearance.raw, "locale"), "zh-CN")
    XCTAssertLessThanOrEqual(page.verificationOutstanding, 4, "The queue stays short")
    assertAscendingSequence(line); page.discard()
  }

  /// Every order of the three answers to a display (WebKit's completion, the rendered receipt, the deadline report)
  /// keeps the page, clears the delay and admits the reported deadline.
  func testEveryReceiptOrderKeepsThePage() throws {
    enum Answer { case completion, rendered, deadline }
    let orders: [[Answer]] = [[.completion, .rendered, .deadline], [.completion, .deadline, .rendered], [.rendered, .completion, .deadline],
                              [.rendered, .deadline, .completion], [.deadline, .completion, .rendered], [.deadline, .rendered, .completion]]
    for order in orders {
      let line = Line(); let page = try page(line)
      var delayed: [Bool] = []
      page.onReadingDelayed = { delayed.append($0) }
      page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket))
      let display = try XCTUnwrap(line.sent.last); XCTAssertEqual(field(display.raw, "type"), "display")
      line.advance(to: line.now + 2_500) // late: the reading is delayed before any answer arrives
      XCTAssertEqual(delayed, [true], "\(order)")
      // The page emits rendered (4) before its deadline report (5); transport may deliver them in any order.
      for answer in order {
        switch answer {
        case .completion: complete(line, upTo: line.sent.firstIndex { $0.raw == display.raw }.map { $0 + 1 })
        case .rendered: page.verificationReceive(try reply(display.raw, type: "rendered", sequence: 4), source: source)
        case .deadline: page.verificationReceive(try reply(display.raw, type: "nextDeadline", sequence: 5, extra: ["deadlineUnixMs": String(line.now + 60_000)]), source: source)
        }
      }
      XCTAssertFalse(page.readingDelayed, "\(order): rendered clears the delay")
      XCTAssertTrue(line.timers.values.contains { $0.due == line.now + 60_000 }, "\(order): the reported deadline is scheduled")
      line.advance(to: line.now + 10_000)
      assertNoRebuild(line, page); page.discard()
    }
  }

  /// A storm of past deadlines for a minute: throttled to one tick a second after the bound, never a failure.
  func testDeadlineStormIsThrottledAndNeverRebuilds() throws {
    let line = Line(); let page = try page(line)
    var ticks = 0
    let start = line.now
    page.verificationFreshnessTick(.show) // the storm starts from a show tick
    while line.now < start + 60_000 {
      while line.completed < line.sent.count {
        let index = line.completed
        complete(line, upTo: index + 1)
        let raw = line.sent[index].raw
        if field(raw, "type") == "tick" {
          ticks += 1; line.pageSequence += 1
          // Every report names a deadline that has just passed (it expired in transit).
          page.verificationReceive(try reply(raw, type: "nextDeadline", sequence: line.pageSequence, extra: ["deadlineUnixMs": String(line.now - 1)]), source: source)
        }
      }
      line.advance(to: line.now + 10)
    }
    assertNoRebuild(line, page)
    XCTAssertTrue(line.lines.contains { $0.hasPrefix("deadline-throttled") })
    let bound = CockpitDeadlineDriver.maximumImmediateAdvances
    XCTAssertGreaterThanOrEqual(ticks, bound + 55, "It keeps ticking once a second")
    XCTAssertLessThanOrEqual(ticks, bound + 62, "but no faster")
    page.discard()
  }

  /// The page holds one call for a minute while replies, appearance changes, show ticks and visibility updates keep
  /// coming. Nothing is refused, the queue stays a handful of calls, and once the call completes the latest of each goes
  /// out in host sequence order. Zero rebuilds.
  func testASaturatingStreamBehindAStuckCallIsNeverRefusedOrRebuilt() throws {
    let line = Line(); let page = try page(line)
    page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket)) // held: never completed until the end
    let held = line.sent.count
    for n in 0..<600 {
      page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket))
      if n % 7 == 0 { page.updateAppearance(.init(theme: .night, locale: n % 14 == 0 ? .zhCN : .en, profile: .full)) }
      if n % 11 == 0 { page.verificationFreshnessTick(.wake) }
      line.advance(to: line.now + 100)
    }
    XCTAssertEqual(line.sent.count, held, "Nothing passes the stuck call")
    XCTAssertLessThanOrEqual(page.verificationOutstanding, 5, "One of each kind waits, at most")
    XCTAssertFalse(line.lines.contains { $0.hasPrefix("delivery-skipped") }, "Nothing was refused")
    assertNoRebuild(line, page)
    complete(line)
    XCTAssertTrue(line.sent.dropFirst(held).contains { field($0.raw, "type") == "display" })
    assertAscendingSequence(line); assertNoRebuild(line, page); page.discard()
  }
}
#endif
