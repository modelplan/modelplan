// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanCockpitWeb

/// Recovery contract (G3-96, G3-116), the pure policies: exact slow / unresponsive boundaries on the monotonic clock,
/// hidden and sleep time excluded, the rolling rebuild budget and what each failure, refusal and probe reply means.
final class CockpitRecoveryPolicyTests: XCTestCase {
  // MARK: page responsiveness

  private func shownHealth() -> CockpitPageHealth {
    var health = CockpitPageHealth(); health.resume(); return health
  }

  func testUnresponsiveNeedsThirtyActiveSecondsAndTwoUnansweredProbes() {
    var health = shownHealth()
    XCTAssertEqual(health.verdict(at: 0), .responsive, "Nothing waits: responsive")
    XCTAssertTrue(health.expect(at: 10_000))
    XCTAssertFalse(health.expect(at: 12_000), "A wait already running keeps its start")
    XCTAssertEqual(health.waitingSince, 10_000)
    health.probeUnanswered(); health.probeUnanswered()
    XCTAssertEqual(health.verdict(at: 39_999), .waiting, "29.999 s with two unanswered probes is still only slow")
    XCTAssertEqual(health.verdict(at: 40_000), .unresponsive, "30 s with two unanswered probes is unresponsive")
    var oneProbe = shownHealth()
    oneProbe.expect(at: 0); oneProbe.probeUnanswered()
    XCTAssertEqual(oneProbe.verdict(at: 3_600_000), .waiting, "No finite wait alone proves anything: two probes must go unanswered")
  }

  func testAnyAnswerEndsTheWait() {
    var health = shownHealth()
    health.expect(at: 0); health.probeUnanswered(); health.probeUnanswered()
    health.answered()
    XCTAssertFalse(health.isWaiting)
    XCTAssertEqual(health.unansweredProbes, 0)
    XCTAssertEqual(health.verdict(at: 1_000_000), .responsive)
    health.probeUnanswered()
    XCTAssertEqual(health.unansweredProbes, 0, "A probe outliving an answered wait counts for nothing")
  }

  func testHiddenTimeIsNotAccountedAndShowingAgainGrantsFreshGrace() {
    var health = CockpitPageHealth()
    XCTAssertTrue(health.paused, "A page starts hidden (prewarm)")
    XCTAssertFalse(health.expect(at: 0), "A hidden page starts no wait")
    health.resume()
    health.expect(at: 1_000); health.probeUnanswered(); health.probeUnanswered()
    health.pause()
    XCTAssertFalse(health.isWaiting, "Hiding drops the wait")
    health.resume()
    XCTAssertFalse(health.isWaiting, "Shown again: a fresh grace period")
    health.expect(at: 500_000); health.probeUnanswered(); health.probeUnanswered()
    XCTAssertEqual(health.verdict(at: 529_999), .waiting, "30 s count from the new wait, not from before the hide")
    XCTAssertEqual(health.verdict(at: 530_000), .unresponsive)
    health.resume()
    XCTAssertTrue(health.isWaiting, "A page that stays shown keeps its wait (resume is only for hidden pages)")
  }

  func testWakeGrantsGraceSoASleepNeverCountsAgainstThePage() {
    var health = shownHealth()
    // The monotonic clock does not advance while the Mac sleeps; a wait that spanned the sleep starts over on wake.
    health.expect(at: 5_000); health.probeUnanswered(); health.probeUnanswered()
    health.grantGrace()
    XCTAssertFalse(health.isWaiting)
    XCTAssertFalse(health.paused, "Wake does not hide the page")
    health.expect(at: 25_000)
    health.probeUnanswered(); health.probeUnanswered()
    XCTAssertEqual(health.verdict(at: 54_999), .waiting)
    XCTAssertEqual(health.verdict(at: 55_000), .unresponsive)
  }

  func testAClockThatSeemsToRunBackwardsNeverUnderflows() {
    var health = shownHealth()
    health.expect(at: 10_000); health.probeUnanswered(); health.probeUnanswered()
    XCTAssertEqual(health.waited(at: 9_000), 0)
    XCTAssertEqual(health.verdict(at: 9_000), .waiting)
  }

  func testMonotonicClockAndMillisecondConversion() {
    let first = CockpitMonotonicClock.nowMs(), second = CockpitMonotonicClock.nowMs()
    XCTAssertGreaterThan(first, 0); XCTAssertGreaterThanOrEqual(second, first)
    XCTAssertEqual(CockpitScheduling.milliseconds(.seconds(4)), 4_000)
    XCTAssertEqual(CockpitScheduling.milliseconds(.milliseconds(700)), 700)
    XCTAssertEqual(CockpitScheduling.milliseconds(.seconds(-1)), 0)
  }

  // MARK: rebuild budget

  func testTwoRebuildsPerRollingTenMinutesThenCooldownProbes() {
    var budget = CockpitRebuildBudget()
    XCTAssertEqual(budget.pageFailed(at: 0), .rebuild(afterMs: 1_000, attempt: 1))
    XCTAssertEqual(budget.pageFailed(at: 10_000), .rebuild(afterMs: 4_000, attempt: 2))
    XCTAssertTrue(budget.exhausted)
    XCTAssertEqual(budget.pageFailed(at: 20_000), .cooldown(probeAfterMs: 60_000))
    XCTAssertEqual(budget.pageFailed(at: 80_000), .cooldown(probeAfterMs: 60_000), "Each failed probe waits out another cooldown")
    XCTAssertEqual(budget.pageFailed(at: 599_999), .cooldown(probeAfterMs: 60_000), "Both rebuilds are still inside the window")
    XCTAssertEqual(budget.pageFailed(at: 600_000), .rebuild(afterMs: 4_000, attempt: 2),
                   "The first rebuild left the rolling window; the second is still in it")
    XCTAssertEqual(budget.attempts, [10_000, 600_000])
  }

  func testTenThousandFailuresNeverScheduleMoreThanTwoRebuildsInTheRollingWindow() {
    var budget = CockpitRebuildBudget()
    var now: UInt64 = 0
    var scheduled = 0, cooldowns = 0
    // This oracle records returned rebuild decisions; it never reads `budget.attempts`.
    var observedRebuildTimes: [UInt64] = []
    for _ in 0..<10_000 {
      switch budget.pageFailed(at: now) {
      case .rebuild(let delay, let attempt):
        XCTAssertEqual(delay, attempt == 1 ? 1_000 : 4_000, "Rebuild delays stay on the approved schedule")
        XCTAssertTrue((1...2).contains(attempt))
        scheduled += 1; observedRebuildTimes.append(now)
      case .cooldown(let probeAfter):
        XCTAssertEqual(probeAfter, 60_000, "An exhausted window waits before its automatic probe")
        cooldowns += 1
      }
      observedRebuildTimes.removeAll { $0 > now || now - $0 >= 600_000 }
      XCTAssertLessThanOrEqual(observedRebuildTimes.count, 2,
                               "The test's independent timeline permits at most two rebuilds per rolling ten minutes")
      now += 1_000
    }
    XCTAssertGreaterThan(scheduled, 2, "The rolling budget recovers after old attempts expire")
    XCTAssertGreaterThan(cooldowns, 0, "A full rolling window must actually return cooldown")
  }

  func testOnlySustainedVerifiedHealthResetsTheBudget() {
    for (healthy, expected) in [(119_999 as UInt64, CockpitRebuildBudget.Decision.cooldown(probeAfterMs: 60_000)),
                                (120_000, .rebuild(afterMs: 1_000, attempt: 1))] {
      var budget = CockpitRebuildBudget()
      _ = budget.pageFailed(at: 0); _ = budget.pageFailed(at: 5_000)
      budget.rendered(at: 10_000)
      budget.rendered(at: 50_000) // later renders do not move the start of health
      XCTAssertEqual(budget.pageFailed(at: 10_000 + healthy), expected, "healthy for \(healthy) ms")
    }
    var budget = CockpitRebuildBudget()
    _ = budget.pageFailed(at: 0); _ = budget.pageFailed(at: 5_000)
    XCTAssertEqual(budget.pageFailed(at: 500_000), .cooldown(probeAfterMs: 60_000),
                   "Time alone without a verified render resets nothing")
  }

  // MARK: classification

  func testOnlyDeadPagesAreRebuiltPrivacyDisposesAndDamageAsksForRepair() {
    let expected: [CockpitWindowFailure: CockpitWindowFailure.Recovery] = [
      .contentTerminated: .rebuild, .unresponsive: .rebuild, .pageAPIUnavailable: .rebuild, .navigationFailed: .rebuild,
      .provisionalNavigationFailed: .rebuild, .messageRejected: .rebuild, .javascriptFailed: .rebuild, .localEncoding: .rebuild,
      .clearDeadline: .privacy, .clearRejected: .privacy, .bundleResource: .repair, .unsupportedPageContract: .repair,
    ]
    for (failure, recovery) in expected { XCTAssertEqual(failure.recovery, recovery, failure.rawValue) }
  }

  func testARefusalNeverMakesALivePageDead() {
    // Step 2b: since #990 bridge.ts refuses render, appearance, shell and tick exceptions without unloading.
    for code in ["data.schema", "data.rowDuplicate", "display.quarantined", "display.render", "appearance.view", "shell.view", "tick.view",
                 "tick.documentHidden", "tick.noDisplay", "recv.sequence", "display.notReady", "none"] {
      XCTAssertEqual(CockpitRecoveryPolicy.rejection(code: code, clear: false, bootstrap: false), .kept, code)
    }
    for code in ["load.view", "clear.retired", "recv.source"] {
      XCTAssertEqual(CockpitRecoveryPolicy.rejection(code: code, clear: false, bootstrap: false), .pageGone, "\(code) unloads the page")
    }
    XCTAssertEqual(CockpitRecoveryPolicy.rejection(code: "data.schema", clear: true, bootstrap: false), .privacy)
    XCTAssertEqual(CockpitRecoveryPolicy.rejection(code: "none", clear: false, bootstrap: true), .pageGone)
  }

  func testRejectionKinds() {
    let expected: [String: CockpitRecoveryPolicy.RejectionKind] = [
      "data.schema": .data, "data.rowAccounts": .data, "display.quarantined": .data,
      "display.render": .view, "appearance.view": .view, "shell.view": .view, "tick.view": .view,
      "recv.sequence": .state, "recv.context": .state, "tick.documentHidden": .state, "display.notReady": .state, "clear.barrier": .state,
      "msg.size": .message, "display.keys": .message, "none": .message,
      "load.view": .gone, "clear.retired": .gone, "recv.source": .gone,
    ]
    for (code, kind) in expected { XCTAssertEqual(CockpitRecoveryPolicy.rejectionKind(code: code), kind, code) }
  }

  /// #981 sampling P2: health ends with the page that earned it. A page that rendered, then closed, cannot hand its
  /// health to a replacement that fails before rendering; a closing page with sustained health resets at its close.
  func testAClosedPagesHealthDoesNotResetTheNextPagesBudget() {
    var budget = CockpitRebuildBudget()
    _ = budget.pageFailed(at: 0); _ = budget.pageFailed(at: 5_000)
    budget.rendered(at: 10_000)
    budget.pageRetired(at: 20_000) // closed after 10 s of health
    XCTAssertNil(budget.healthySince)
    XCTAssertEqual(budget.pageFailed(at: 150_000), .cooldown(probeAfterMs: 60_000),
                   "the replacement failed before rendering: the spent attempts stand")
    var earned = CockpitRebuildBudget()
    _ = earned.pageFailed(at: 0); _ = earned.pageFailed(at: 5_000)
    earned.rendered(at: 10_000)
    earned.pageRetired(at: 130_000) // closed after 120 s of verified health
    XCTAssertEqual(earned.attempts, [], "sustained health of the closing page resets the attempts")
    XCTAssertEqual(earned.pageFailed(at: 140_000), .rebuild(afterMs: 1_000, attempt: 1))
  }

  func testProbeReplies() {
    for state in ["ready", "hidden", "cleared", "loading"] {
      XCTAssertEqual(CockpitRecoveryPolicy.probeOutcome(state, pageReady: true), .answered, state)
    }
    XCTAssertEqual(CockpitRecoveryPolicy.probeOutcome("missing", pageReady: true), .pageGone)
    XCTAssertEqual(CockpitRecoveryPolicy.probeOutcome("unloaded", pageReady: true), .pageGone)
    XCTAssertEqual(CockpitRecoveryPolicy.probeOutcome("missing", pageReady: false), .unanswered, "Still loading: not an answer, not a death")
    XCTAssertEqual(CockpitRecoveryPolicy.probeOutcome(nil, pageReady: true), .unanswered)
    XCTAssertEqual(CockpitRecoveryPolicy.probeOutcome("something-else", pageReady: true), .unanswered)
    XCTAssertEqual(CockpitRecoveryPolicy.probeOutcome("mismatch", pageReady: true), .unanswered, "another page never answers for this one")
  }
}
