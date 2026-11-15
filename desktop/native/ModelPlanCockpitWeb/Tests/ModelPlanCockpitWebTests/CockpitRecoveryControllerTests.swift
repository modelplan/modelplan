// SPDX-License-Identifier: MIT
#if MODELPLAN_TEST_ONLY_SPI
import Foundation
import XCTest
import ModelPlanWire
@testable import ModelPlanCockpitWeb

/// Recovery contract (G3-96, G3-116) on the real controller and bridge, with fake delivery, an injected monotonic clock,
/// fake deadline and probe schedulers and a fake probe. No window, web view or sleep. A slow or refusing page keeps its
/// last rendered data and is probed; only 30 active seconds with two unanswered probes end it.
@MainActor final class CockpitRecoveryControllerTests: XCTestCase {
  private let source = CockpitMessageSource(mainFrame: true, origin: "modelplan-cockpit://bundle")
  private func reply(_ raw: String, type: String, sequence: Int, extra: [String: Any] = [:]) throws -> String {
    var value = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
    for key in ["data", "appearance", "shell", "theme", "locale", "reduceMotion", "reduceTransparency", "showProjectNames", "redBelow", "showUsedPercent", "showAllModels", "ackedCautions", "pinnedModels", "nowUnixMs", "reason"] { value[key] = nil }
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

  /// One page with every recovery seam injected. `deadlineTimers` are the receipt watchdogs and data deadlines (wall
  /// time); `healthTimers` are the probe timeouts (monotonic). Firing a timer is the test's own act.
  private final class Rig {
    var sent: [(String, (CockpitDeliveryResult) -> Void)] = []
    var failures: [CockpitWindowFailure] = []
    var lines: [String] = []
    var delayed: [Bool] = []
    var mono: UInt64 = 1_000
    var deadlineTimers: [(delay: UInt64, fire: @MainActor () -> Void)] = []
    var healthTimers: [Int: (due: UInt64, fire: @MainActor () -> Void)] = [:]
    var nextHealthTimer = 0
    var probes: [@MainActor (String?) -> Void] = []
    var rendersVerified = 0
    /// When set, receipt watchdogs and data deadlines run on the same monotonic timeline as the probes (fired by
    /// `advance`), instead of being collected for the test to fire by hand.
    var timedDeadlines = false
    /// Fires every probe timeout due at `time`, in order, moving the monotonic clock to each one's due time.
    @MainActor func advance(to time: UInt64) {
      while let next = healthTimers.filter({ $0.value.due <= time }).min(by: { ($0.value.due, $0.key) < ($1.value.due, $1.key) }) {
        healthTimers[next.key] = nil; mono = next.value.due; next.value.fire()
      }
      mono = time
    }
    /// The latest armed receipt watchdog (2 s) that has not been fired yet by the test.
    @MainActor func fireLatestReceiptWatchdog() throws {
      let timer = try XCTUnwrap(deadlineTimers.last { $0.delay == CockpitPageHealth.delayedAfterMs })
      timer.fire()
    }
  }
  private func page(_ rig: Rig) throws -> CockpitWindowController {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("cockpit-recovery-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: root) }
    let html = Data("synthetic".utf8); try html.write(to: root.appendingPathComponent("index.html"))
    let manifest = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "edition": "community", "interfaceOnly": true, "files": ["index.html": VerifiedCockpitBundle.digest(html)]])
    try manifest.write(to: root.appendingPathComponent("bundle-manifest.json"))
    let bundle = try VerifiedCockpitBundle(root: root, manifestSHA256: VerifiedCockpitBundle.digest(manifest))
    let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic", generation: 1)
    let page = CockpitWindowController(bundle: bundle, context: context, appearance: .init(theme: .night, locale: .en, profile: .full))
    page.verificationNoWindowClock = { 1_000 }
    page.verificationNoWindowArm = { delay, fire in
      guard rig.timedDeadlines else { rig.deadlineTimers.append((delay: delay, fire: fire)); return {} }
      let id = rig.nextHealthTimer; rig.nextHealthTimer += 1
      rig.healthTimers[id] = (due: rig.mono + delay, fire: fire)
      return { rig.healthTimers[id] = nil }
    }
    page.verificationNoWindowDelivery = { raw, complete in rig.sent.append((raw, complete)) }
    page.verificationMonotonicClock = { rig.mono }
    page.verificationHealthArm = { delay, fire in
      let id = rig.nextHealthTimer; rig.nextHealthTimer += 1
      rig.healthTimers[id] = (due: rig.mono + delay, fire: fire)
      return { rig.healthTimers[id] = nil }
    }
    page.verificationProbe = { answer in rig.probes.append(answer) }
    page.onFailure = { rig.failures.append($0) }
    page.onReadingDelayed = { rig.delayed.append($0) }
    page.onRenderVerified = { rig.rendersVerified += 1 }
    CockpitFailureLog.verificationLine = { rig.lines.append($0) }
    addTeardownBlock { @MainActor in CockpitFailureLog.verificationLine = nil }
    let shell = CockpitShellState(closed: false, attached: true, forcedClosed: false, tier: .tall)
    page.verificationNoWindowShell = shell
    let load = try page.bridge.load(.init(theme: .night, locale: .en, profile: .full), shell: shell)
    _ = try page.bridge.accept(reply(load, type: "ready", sequence: 1), source: source)
    try page.verificationConfirmVisible()
    return page
  }
  /// A visible page that rendered one display and answered its show tick.
  private func renderedPage(_ rig: Rig) throws -> CockpitWindowController {
    let page = try page(rig)
    page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket))
    XCTAssertEqual(rig.sent.count, 1); rig.sent[0].1(.accepted)
    page.verificationReceive(try reply(rig.sent[0].0, type: "rendered", sequence: 2), source: source)
    XCTAssertEqual(type(rig.sent[1].0), "tick"); rig.sent[1].1(.accepted)
    page.verificationReceive(try reply(rig.sent[1].0, type: "nextDeadline", sequence: 3, extra: ["deadlineUnixMs": NSNull()]), source: source)
    XCTAssertEqual(rig.failures, [])
    return page
  }

  /// The G3-116 shape: a busy page whose render receipt is late. It is slow, not dead: the reading is marked delayed,
  /// the page is probed, answers, and keeps its data; the next rendered receipt clears the delay.
  func testALateRenderReceiptMarksTheReadingDelayedAndAnAnsweringPageIsKept() throws {
    let rig = Rig(); let page = try renderedPage(rig)
    page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket))
    let display = try XCTUnwrap(rig.sent.last); XCTAssertEqual(type(display.0), "display")
    display.1(.accepted) // WebKit took the call; the rendered receipt is late.
    rig.mono = 3_000
    try rig.fireLatestReceiptWatchdog()
    XCTAssertTrue(page.readingDelayed, "From 2 s the reading is delayed")
    XCTAssertEqual(rig.delayed, [true])
    XCTAssertEqual(rig.probes.count, 1, "The late page is probed")
    XCTAssertTrue(page.verificationHealth.isWaiting)
    rig.probes[0]("ready")
    XCTAssertFalse(page.verificationHealth.isWaiting, "The probe answer proves the page alive")
    XCTAssertTrue(rig.healthTimers.isEmpty, "Its timeout is cancelled")
    rig.advance(to: 600_000)
    XCTAssertEqual(rig.failures, [], "A page that answers is never ended, however long its render takes")
    XCTAssertFalse(page.bridge.disposed)
    page.verificationReceive(try reply(display.0, type: "rendered", sequence: 4), source: source)
    XCTAssertFalse(page.readingDelayed); XCTAssertEqual(rig.delayed, [true, false])
    XCTAssertTrue(rig.lines.contains { $0.hasPrefix("page-late cause=renderReceipt") }, rig.lines.joined(separator: "\n"))
    XCTAssertFalse(rig.lines.contains { $0.hasPrefix("page-failure") })
    page.discard()
  }

  /// Exact boundary through the controller: waiting starts at the late receipt; the page ends only once 30 active
  /// seconds have passed with at least two unanswered probes, not a millisecond earlier.
  func testAPageThatNeverAnswersEndsAsUnresponsiveAtThirtyActiveSeconds() throws {
    let rig = Rig(); let page = try renderedPage(rig)
    page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket)) // never completes: the page is stuck
    rig.mono = 10_000
    try rig.fireLatestReceiptWatchdog()
    XCTAssertEqual(page.verificationHealth.waitingSince, 10_000)
    XCTAssertEqual(rig.probes.count, 1)
    rig.advance(to: 39_999)
    XCTAssertEqual(rig.failures, [], "29.999 active seconds is still only slow")
    XCTAssertGreaterThanOrEqual(page.verificationHealth.unansweredProbes, 2)
    XCTAssertGreaterThan(rig.probes.count, 2, "Probing goes on while the page stays silent")
    // The next probe timeout falls at 40 000 at the earliest (probes run back to back, 5 s each).
    rig.advance(to: 45_000)
    XCTAssertEqual(rig.failures, [.unresponsive])
    XCTAssertTrue(page.bridge.disposed)
    XCTAssertTrue(rig.lines.contains { $0.hasPrefix("page-unresponsive waitedMs=30000") }, rig.lines.joined(separator: "\n"))
    XCTAssertTrue(rig.lines.contains { $0.contains("page-failure failure=unresponsive") && $0.hasSuffix("recovery=rebuild") })
  }

  /// Late callbacks and cancellation: an answer through any delivery ends the wait, so an old probe's timeout or a late
  /// "missing" reply from it cannot end the page or count against a new wait.
  func testLateProbeCallbacksCannotEndThePageAfterItAnswered() throws {
    let rig = Rig(); let page = try renderedPage(rig)
    page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket))
    let display = try XCTUnwrap(rig.sent.last)
    rig.mono = 3_000; try rig.fireLatestReceiptWatchdog()
    let oldProbe = try XCTUnwrap(rig.probes.first)
    let oldTimeout = try XCTUnwrap(rig.healthTimers.first?.value.fire)
    display.1(.accepted) // the page completes the call: an answer
    XCTAssertFalse(page.verificationHealth.isWaiting)
    oldProbe("missing") // would mean a gone bridge, but it belongs to the finished wait
    oldTimeout()
    XCTAssertEqual(rig.failures, [])
    XCTAssertEqual(page.verificationHealth.unansweredProbes, 0)
    XCTAssertFalse(page.bridge.disposed); page.discard()
  }

  /// A probe that finds the loaded page's bridge gone (bridge.ts unloaded itself) ends the page at once.
  func testAProbeThatFindsTheBridgeGoneEndsTheLoadedPage() throws {
    let rig = Rig(); let page = try renderedPage(rig)
    page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket))
    rig.mono = 3_000; try rig.fireLatestReceiptWatchdog()
    try XCTUnwrap(rig.probes.first)("missing")
    XCTAssertEqual(rig.failures, [.pageAPIUnavailable])
  }

  /// Hidden time is not accounted and a page shown again gets a fresh grace period; a stale probe timeout after the
  /// hide cannot end it.
  func testHidingPausesTheWaitAndShowingAgainGrantsFreshGrace() throws {
    let rig = Rig(); let page = try renderedPage(rig)
    page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket))
    rig.mono = 3_000; try rig.fireLatestReceiptWatchdog()
    rig.advance(to: 25_000)
    let stale = try XCTUnwrap(rig.healthTimers.first?.value.fire)
    try page.verificationHideWithoutWindow()
    XCTAssertTrue(page.verificationHealth.paused); XCTAssertFalse(page.verificationHealth.isWaiting)
    XCTAssertTrue(rig.healthTimers.isEmpty, "Hiding cancels the probe timeout")
    stale(); rig.mono = 900_000
    XCTAssertEqual(rig.failures, [])
    try page.verificationConfirmVisible()
    XCTAssertFalse(page.verificationHealth.paused)
    XCTAssertFalse(page.verificationHealth.isWaiting, "Shown again: nothing carried over from before the hide")
    XCTAssertFalse(page.bridge.disposed); page.discard()
  }

  /// Sleep exclusion: the Mac sleeps mid-wait (the monotonic clock stands still) and wakes; the wait starts over.
  func testWakeGrantsGraceToAWaitThatSpannedTheSleep() throws {
    let rig = Rig(); let page = try renderedPage(rig)
    page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket))
    rig.mono = 3_000; try rig.fireLatestReceiptWatchdog()
    rig.advance(to: 30_000)
    XCTAssertGreaterThanOrEqual(page.verificationHealth.unansweredProbes, 2)
    page.verificationWake()
    XCTAssertFalse(page.verificationHealth.isWaiting)
    XCTAssertTrue(rig.healthTimers.isEmpty)
    rig.advance(to: 120_000)
    XCTAssertEqual(rig.failures, [], "No probe runs on after the wake, and nothing that waited before it counts")
    XCTAssertFalse(page.bridge.disposed); page.discard()
  }

  /// A refused display is a data problem, not a dead page: the page keeps its last rendered data, no receipt is awaited
  /// for the refused display (so an appearance is not held back), and the next good display renders.
  func testARefusedDisplayKeepsThePageAndReleasesItsReceipt() throws {
    let rig = Rig(); let page = try renderedPage(rig)
    page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket))
    XCTAssertTrue(page.bridge.hasPendingDisplay)
    try XCTUnwrap(rig.sent.last).1(.rejected)
    XCTAssertEqual(rig.failures, [])
    XCTAssertFalse(page.bridge.hasPendingDisplay, "No receipt is awaited for a refused display")
    XCTAssertTrue(rig.lines.contains { $0.hasPrefix("page-reject-kept code=") }, rig.lines.joined(separator: "\n"))
    page.updateAppearance(.init(theme: .night, locale: .zhCN, profile: .full))
    XCTAssertEqual(type(try XCTUnwrap(rig.sent.last).0), "appearance", "Nothing holds the appearance back")
    var index = rig.sent.count - 1
    while index < rig.sent.count { rig.sent[index].1(.accepted); index += 1 }
    page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket))
    let good = try XCTUnwrap(rig.sent.last); XCTAssertEqual(type(good.0), "display"); good.1(.accepted)
    page.verificationReceive(try reply(good.0, type: "rendered", sequence: 10), source: source)
    XCTAssertEqual(rig.failures, []); XCTAssertFalse(page.bridge.disposed); page.discard()
  }

  /// A call that threw inside a live page (not the load) keeps the page.
  func testAJavaScriptExceptionOutsideTheLoadKeepsThePage() throws {
    let rig = Rig(); let page = try renderedPage(rig)
    page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket))
    try XCTUnwrap(rig.sent.last).1(.failed)
    XCTAssertEqual(rig.failures, [])
    XCTAssertTrue(rig.lines.contains { $0 == "page-call-failed type=display kept=true" }, rig.lines.joined(separator: "\n"))
    XCTAssertFalse(page.bridge.disposed); page.discard()
  }

  /// G3-86 follow-up: a delivery queue that stays full no longer ends the page by a count of refusals. It is a page that
  /// is not answering, so it is probed; a page that then answers is kept.
  func testAFullQueueIsProbedInsteadOfCountedToDeath() throws {
    let rig = Rig(); let page = try renderedPage(rig)
    page.verificationRefuseSubmissions = 40
    for _ in 0..<40 { page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket)) }
    XCTAssertEqual(rig.failures, [], "No refusal count ends the page")
    XCTAssertTrue(page.readingDelayed, "A stuck queue delays the reading too (macrev2-981-6)")
    XCTAssertEqual(rig.probes.count, 1, "The stuck queue starts one probe, not one per refusal")
    rig.probes[0]("ready")
    XCTAssertFalse(page.verificationHealth.isWaiting)
    XCTAssertFalse(page.bridge.disposed); page.discard()
  }

  /// macrevb-981-1 / macrev2-981-2: replies every 900 ms, the first call never completing and no receipt ever coming.
  /// The render wait is measured from the oldest unrendered display, so the replacements cannot keep the silent page
  /// unprobed: it is delayed at 2 s and ends 30 active seconds later. An answering page under the same stream is kept.
  func testContinuousReplacementsCannotKeepASilentPageFromBeingProbed() throws {
    for answers in [false, true] {
      let rig = Rig(); let page = try renderedPage(rig)
      rig.timedDeadlines = true
      if answers { page.verificationProbe = { $0("ready") } }
      let start = rig.mono
      while rig.failures.isEmpty, rig.mono < start + 60_000 {
        page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket))
        rig.advance(to: rig.mono + 900)
      }
      XCTAssertTrue(page.readingDelayed, "answers=\(answers): the reading is delayed")
      XCTAssertEqual(rig.delayed.first, true)
      if answers {
        XCTAssertEqual(rig.failures, [], "An answering page is kept, however long its renders take")
        XCTAssertFalse(page.bridge.disposed); page.discard()
      } else {
        XCTAssertEqual(rig.failures, [.unresponsive], "The silent page is recovered despite the replacements")
        XCTAssertLessThanOrEqual(rig.mono - start, 2_000 + 30_000 + CockpitPageHealth.probeTimeoutMs + 900)
        XCTAssertGreaterThanOrEqual(rig.mono - start, 2_000 + 30_000)
      }
    }
  }

  /// macrev2-981-4: a page that stops answering while covered is probed once it is uncovered. The host's own window
  /// facts resume liveness accounting (a fresh grace period); the page's acknowledgement is not awaited for that, and
  /// the covered time does not count.
  func testUncoveringAPageThatStoppedAnsweringResumesProbing() throws {
    let rig = Rig(); let page = try renderedPage(rig)
    page.verificationSetHostVisibility(.init(visible: true, occluded: false, key: true))
    try XCTUnwrap(rig.sent.last).1(.accepted) // the page took this visibility
    page.verificationSetHostVisibility(.init(visible: true, occluded: true, key: false))
    XCTAssertTrue(page.verificationHealth.paused, "Covered: nothing is accounted")
    rig.mono += 3_600_000 // an hour covered; the page stops answering meanwhile (no call completes from here on)
    page.verificationSetHostVisibility(.init(visible: true, occluded: false, key: true))
    XCTAssertFalse(page.verificationHealth.paused, "Uncovered: accounting resumes from the window facts")
    XCTAssertFalse(page.verificationHealth.isWaiting, "with a fresh grace period")
    let uncovered = rig.mono
    rig.advance(to: uncovered + 2_000)
    XCTAssertTrue(page.readingDelayed, "The visibility receipt is late: the reading is delayed")
    XCTAssertEqual(page.verificationHealth.waitingSince, uncovered + 2_000)
    XCTAssertGreaterThanOrEqual(rig.probes.count, 1)
    rig.advance(to: uncovered + 31_999)
    XCTAssertEqual(rig.failures, [], "The hour covered does not count")
    rig.advance(to: uncovered + 2_000 + 30_000 + CockpitPageHealth.probeTimeoutMs)
    XCTAssertEqual(rig.failures, [.unresponsive])
  }

  /// macrevb-981-3: a privacy clear that cannot reach the bridge (no bridge, or a refusal) is a privacy disposal, not a
  /// dead page: it never spends the rebuild budget or brings the generic notice.
  func testAClearThatFindsNoBridgeIsAPrivacyDisposal() async throws {
    for result in [CockpitDeliveryResult.missing, .rejected, .failed] {
      let rig = Rig(); let page = try renderedPage(rig)
      let before = rig.sent.count
      let clearing = Task { @MainActor in await page.clearPrivateViews(adopting: nil) }
      for _ in 0..<1_000 where rig.sent.count == before { await Task.yield() }
      let clear = try XCTUnwrap(rig.sent.last)
      XCTAssertEqual(type(clear.0), "clear")
      clear.1(result)
      await clearing.value
      XCTAssertEqual(rig.failures, [.clearRejected], "\(result): disposed as a privacy barrier")
      XCTAssertEqual(rig.failures.first?.recovery, .privacy)
      XCTAssertTrue(page.bridge.disposed)
    }
  }

  /// macrevb-981-2: verified health is a rendered receipt, not a reply handed to the page.
  func testOnlyARenderedReceiptCountsAsVerifiedRender() throws {
    let rig = Rig(); let page = try renderedPage(rig)
    XCTAssertEqual(rig.rendersVerified, 1, "The first rendered receipt")
    page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket))
    let display = try XCTUnwrap(rig.sent.last); display.1(.accepted)
    XCTAssertEqual(rig.rendersVerified, 1, "A delivered display is not verified data on screen")
    page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket))
    try XCTUnwrap(rig.sent.last).1(.rejected)
    XCTAssertEqual(rig.rendersVerified, 1, "Nor is a refused one")
    let good = try XCTUnwrap(rig.sent.last)
    page.display(try fixture(), ticket: try XCTUnwrap(page.queryTicket))
    let latest = try XCTUnwrap(rig.sent.last); XCTAssertNotEqual(latest.0, good.0); latest.1(.accepted)
    page.verificationReceive(try reply(latest.0, type: "rendered", sequence: 9), source: source)
    XCTAssertEqual(rig.rendersVerified, 2)
    page.discard()
  }
}
#endif
