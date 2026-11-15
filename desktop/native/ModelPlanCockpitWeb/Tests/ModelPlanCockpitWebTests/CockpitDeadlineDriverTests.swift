// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanCockpitWeb

@MainActor final class CockpitDeadlineDriverTests: XCTestCase {
  func testVisibilityMustBeConfirmedAndLateConfirmationCannotRevive() {
    var fence = CockpitVisibilityFence()
    let first = fence.begin(visible: true)
    XCTAssertTrue(fence.isCurrent(first)); XCTAssertFalse(fence.isConfirmedVisible)
    let hidden = fence.begin(visible: false)
    XCTAssertFalse(fence.confirm(first))
    XCTAssertTrue(fence.isPending(hidden)); XCTAssertFalse(fence.confirm(hidden))
    XCTAssertFalse(fence.isPending(hidden))
    let shown = fence.begin(visible: true)
    XCTAssertTrue(fence.confirm(shown)); XCTAssertTrue(fence.isConfirmedVisible)
    XCTAssertFalse(fence.confirm(shown))
    let stale = fence.begin(visible: true)
    fence.invalidate(); XCTAssertFalse(fence.confirm(stale))
  }
  func testMissingReceiptTimesOutButCancelledOldReceiptCannotFire() {
    var callbacks: [@MainActor () -> Void] = [], delays: [UInt64] = [], failures: [UUID] = []
    let watchdog = CockpitDeadlineReceiptWatchdog(arm: { delay, fire in
      delays.append(delay); callbacks.append(fire); return {}
    }, timedOut: { failures.append($0) })
    let old=UUID(), current=UUID()
    watchdog.wait(for:old); watchdog.cancel(); watchdog.wait(for:current)
    XCTAssertEqual(delays,[2_000,2_000]);callbacks[0]();XCTAssertTrue(failures.isEmpty)
    callbacks[1]();XCTAssertEqual(failures,[current]);callbacks[1]()
    XCTAssertEqual(failures,[current],"A timeout must fail at most once")
  }
  func testAppearanceStaysDirtyUntilConfirmedAndNeverLeaksPastInvalidation() {
    var gate = CockpitAppearanceGate()
    XCTAssertTrue(gate.request(visible: true, displayPending: false))
    XCTAssertTrue(gate.isDeferred)
    let old = gate.version
    XCTAssertTrue(gate.retry(visible: true, displayPending: false), "A skipped queued send remains eligible")
    XCTAssertTrue(gate.request(visible: true, displayPending: false))
    XCTAssertFalse(gate.acknowledge(old), "An old accepted callback cannot retire newer appearance")
    XCTAssertTrue(gate.isDeferred)
    XCTAssertTrue(gate.acknowledge(gate.version)); XCTAssertFalse(gate.isDeferred)
    XCTAssertFalse(gate.retry(visible: true, displayPending: false))
    XCTAssertFalse(gate.request(visible: true, displayPending: true))
    gate.invalidate(); XCTAssertFalse(gate.retry(visible: true, displayPending: false))
  }
  func testVisibleDeadlineAndStaleCallbackAreFenced() {
    var now: UInt64 = 1_000, callbacks: [@MainActor () -> Void] = [], reasons: [CockpitDeadlineReason] = []
    let driver = CockpitDeadlineDriver(now: { now }, arm: { _, fire in
      callbacks.append(fire); return {}
    }, onExhausted: { XCTFail("Unexpected deadline convergence failure") }, tick: { reasons.append($0) })
    driver.show(); XCTAssertEqual(reasons, [.show]); XCTAssertTrue(driver.isVisible)
    driver.accept(deadline: 1_500); XCTAssertEqual(callbacks.count, 1)
    driver.accept(deadline: 2_000); XCTAssertEqual(callbacks.count, 2)
    now = 1_500; callbacks[0](); XCTAssertEqual(reasons, [.show])
    now = 2_000; callbacks[1](); XCTAssertEqual(reasons, [.show, .deadline])
    driver.accept(deadline: 2_000); driver.accept(deadline: 1_999)
    XCTAssertEqual(callbacks.count, 2, "Already due reports must not spin")
  }
  func testLaterDeadlineAlreadyDueStillTicksOnceWithoutRepeatingOlderDeadlines() throws {
    var now: UInt64 = 999, callbacks: [@MainActor () -> Void] = [], delays: [UInt64] = []
    var reasons: [CockpitDeadlineReason] = [], window: String? = "current", reset: String? = "announced"
    let driver = CockpitDeadlineDriver(now: { now }, arm: { delay, fire in
      delays.append(delay); callbacks.append(fire); return {}
    }, onExhausted: { XCTFail("Unexpected deadline convergence failure") }, tick: { reason in
      reasons.append(reason)
      if reason == .deadline {
        if now >= 1_000 { window = nil }
        if now >= 1_001 { reset = nil }
      }
    })
    driver.show(); driver.accept(deadline: 1_000)
    now = 1_000; try XCTUnwrap(callbacks.first)()
    XCTAssertNil(window); XCTAssertEqual(reset, "announced")
    now = 1_002; driver.accept(deadline: 1_001)
    XCTAssertEqual(delays, [1, 0], "A distinct later deadline can already be due")
    try XCTUnwrap(callbacks.last)()
    XCTAssertNil(reset); XCTAssertEqual(reasons, [.show, .deadline, .deadline])
    driver.accept(deadline: 1_001); driver.accept(deadline: 1_000); driver.accept(deadline: 999)
    XCTAssertEqual(callbacks.count, 2, "Equal and earlier deadlines cannot spin")
    callbacks[1](); XCTAssertEqual(reasons, [.show, .deadline, .deadline], "A stale callback cannot fire twice")
  }
  func testBackwardClockCreatesBoundedNewClockEpoch() throws {
    var now: UInt64 = 999, callbacks: [@MainActor () -> Void] = [], reasons: [CockpitDeadlineReason] = []
    let driver = CockpitDeadlineDriver(now: { now }, arm: { _, fire in callbacks.append(fire); return {} }, onExhausted: { XCTFail("Unexpected deadline convergence failure") }, tick: { reasons.append($0) })
    driver.show(); driver.accept(deadline: 1_000)
    now = 1_000; try XCTUnwrap(callbacks.first)()
    driver.notify(.clockChange); driver.accept(deadline: 1_000)
    XCTAssertEqual(callbacks.count, 1, "A same-time notification cannot re-arm an already delivered deadline")
    now = 900; driver.accept(deadline: 1_000)
    XCTAssertEqual(callbacks.count, 1, "A page report alone cannot reset the watermark")
    driver.notify(.clockChange); driver.accept(deadline: 1_000)
    XCTAssertEqual(callbacks.count, 2, "A real backwards clock change may make the deadline future again")
    now = 1_000; try XCTUnwrap(callbacks.last)()
    driver.accept(deadline: 1_000)
    XCTAssertEqual(callbacks.count, 2, "The new clock epoch remains bounded")
    XCTAssertEqual(reasons, [.show, .deadline, .clockChange, .clockChange, .deadline])
  }
  func testDeadlineWatermarkAndCallbacksDoNotCrossGenerationOrHide() throws {
    var now: UInt64 = 10, callbacks: [@MainActor () -> Void] = [], reasons: [CockpitDeadlineReason] = []
    let driver = CockpitDeadlineDriver(now: { now }, arm: { _, fire in callbacks.append(fire); return {} }, onExhausted: { XCTFail("Unexpected deadline convergence failure") }, tick: { reasons.append($0) })
    driver.show(); driver.accept(deadline: 20)
    driver.invalidate() // The caller adopts a new generation.
    driver.accept(deadline: 30); let old = callbacks[0]
    now = 20; old(); XCTAssertEqual(reasons, [.show])
    driver.hide(); now = 30; callbacks[1](); XCTAssertEqual(reasons, [.show])
    driver.show(); driver.accept(deadline: 30); try XCTUnwrap(callbacks.last)()
    XCTAssertEqual(reasons, [.show, .show, .deadline])
    driver.retire(); callbacks.last?(); XCTAssertEqual(reasons, [.show, .show, .deadline])
  }
  /// Recovery contract: a stream of already-due deadlines is a slow page, not a broken one. After the bound it is
  /// throttled to one tick per `throttledDelay` (reported once) instead of retiring the driver and failing the page; a
  /// deadline in the future ends the throttle.
  func testStrictlyIncreasingAlreadyDueStreamIsThrottledWithoutDroppingEarlierAdvances() {
    var callbacks: [@MainActor () -> Void] = [], delays: [UInt64] = [], reasons: [CockpitDeadlineReason] = [], exhausted = 0
    var now: UInt64 = 10_000
    let driver = CockpitDeadlineDriver(now: { now }, arm: { delay, fire in delays.append(delay); callbacks.append(fire); return {} }, onExhausted: { exhausted += 1 }, tick: { reasons.append($0) })
    driver.show()
    for value in 1...CockpitDeadlineDriver.maximumImmediateAdvances {
      driver.accept(deadline: UInt64(value))
      XCTAssertEqual(callbacks.count, value)
      callbacks[value - 1]()
    }
    XCTAssertEqual(reasons.filter { $0 == .deadline }.count, CockpitDeadlineDriver.maximumImmediateAdvances)
    XCTAssertEqual(delays, Array(repeating: 0, count: CockpitDeadlineDriver.maximumImmediateAdvances))
    driver.accept(deadline: UInt64(CockpitDeadlineDriver.maximumImmediateAdvances + 1))
    XCTAssertEqual(exhausted, 1, "The change to a throttled stream is reported")
    XCTAssertEqual(delays.last, CockpitDeadlineDriver.throttledDelay)
    callbacks.last?()
    XCTAssertEqual(reasons.filter { $0 == .deadline }.count, CockpitDeadlineDriver.maximumImmediateAdvances + 1, "The throttled deadline still ticks")
    driver.accept(deadline: UInt64(CockpitDeadlineDriver.maximumImmediateAdvances + 2))
    XCTAssertEqual(exhausted, 1, "Reported once while it stays throttled")
    XCTAssertEqual(delays.last, CockpitDeadlineDriver.throttledDelay)
    callbacks.last?()
    driver.accept(deadline: now + 5_000)
    XCTAssertEqual(delays.last, 5_000, "A deadline in the future is scheduled normally")
    now += 5_000; callbacks.last?()
    now += 10_000
    driver.accept(deadline: now - 1)
    XCTAssertEqual(delays.last, 0, "After a future deadline the throttle is over")
    XCTAssertEqual(exhausted, 1)
  }
  /// macrev2-981-7: while throttled, reports that keep arriving do not postpone the tick: the next one is due one
  /// second after the last delivered tick, not one second after the latest report.
  func testThrottledStreamKeepsOneTickPerSecondUnderContinuousReports() {
    var callbacks: [@MainActor () -> Void] = [], delays: [UInt64] = [], ticks = 0
    var now: UInt64 = 10_000
    let driver = CockpitDeadlineDriver(now: { now }, arm: { delay, fire in delays.append(delay); callbacks.append(fire); return {} }, onExhausted: {}, tick: { if $0 == .deadline { ticks += 1 } })
    driver.show()
    for value in 1...CockpitDeadlineDriver.maximumImmediateAdvances { driver.accept(deadline: UInt64(value)); callbacks[value - 1]() }
    var next = UInt64(CockpitDeadlineDriver.maximumImmediateAdvances + 1)
    driver.accept(deadline: next)
    XCTAssertEqual(delays.last, 1_000, "Throttled: one second after the last tick at 10 000")
    now = 10_600; next += 1; driver.accept(deadline: next)
    XCTAssertEqual(delays.last, 400, "A newer report keeps the tick due at 11 000")
    now = 10_900; next += 1; driver.accept(deadline: next)
    XCTAssertEqual(delays.last, 100)
    now = 11_000; callbacks.last?()
    XCTAssertEqual(ticks, CockpitDeadlineDriver.maximumImmediateAdvances + 1, "It ticks on time despite the reports")
    now = 11_200; next += 1; driver.accept(deadline: next)
    XCTAssertEqual(delays.last, 800, "and the next one is due at 12 000")
  }
  func testCancelledImmediateReportsDoNotConsumeConvergenceBudget() {
    var callbacks: [@MainActor () -> Void] = [], exhausted = 0, ticks = 0
    let driver = CockpitDeadlineDriver(now: { 10_000 }, arm: { _, fire in callbacks.append(fire); return {} }, onExhausted: { exhausted += 1 }, tick: { reason in if reason == .deadline { ticks += 1 } })
    driver.show()
    for value in 1...100 { driver.accept(deadline: UInt64(value)) }
    XCTAssertEqual(exhausted, 0, "Cancelled reports are not delivered ticks")
    XCTAssertEqual(callbacks.count, 100)
    for callback in callbacks.dropLast() { callback() }
    XCTAssertEqual(ticks, 0, "Retired callbacks cannot consume the budget")
    callbacks.last?(); XCTAssertEqual(ticks, 1)
  }
  func testWakeUnlockClockShowAndTeardown() {
    var callbacks: [@MainActor () -> Void] = [], reasons: [CockpitDeadlineReason] = []
    let driver = CockpitDeadlineDriver(now: { 100 }, arm: { _, fire in callbacks.append(fire); return {} }, onExhausted: { XCTFail("Unexpected deadline convergence failure") }, tick: { reasons.append($0) })
    driver.show(); driver.accept(deadline: 200)
    driver.notify(.wake); driver.notify(.unlock); driver.notify(.clockChange)
    XCTAssertEqual(reasons, [.show, .wake, .unlock, .clockChange])
    driver.hide(); callbacks[0](); driver.notify(.wake)
    XCTAssertEqual(reasons, [.show, .wake, .unlock, .clockChange])
    driver.show(); XCTAssertEqual(reasons.last, .show)
    driver.accept(deadline: 250); let stale = callbacks.last!
    driver.retire(); stale(); driver.show(); driver.notify(.clockChange)
    XCTAssertEqual(reasons.last, .show, "Retired pages must never emit")
  }
  func testLongDeadlineRearmsOneTimerWithoutEarlyTick() {
    var now: UInt64 = 0, callbacks: [@MainActor () -> Void] = [], delays: [UInt64] = [], reasons: [CockpitDeadlineReason] = []
    let driver = CockpitDeadlineDriver(now: { now }, arm: { delay, fire in delays.append(delay); callbacks.append(fire); return {} }, onExhausted: { XCTFail("Unexpected deadline convergence failure") }, tick: { reasons.append($0) })
    driver.show(); driver.accept(deadline: 100_000_000)
    XCTAssertEqual(delays, [86_400_000])
    now = 86_400_000; callbacks[0](); callbacks[0]()
    XCTAssertEqual(delays, [86_400_000, 13_600_000]); XCTAssertEqual(reasons, [.show])
    now = 100_000_000; callbacks[1]()
    XCTAssertEqual(reasons, [.show, .deadline])
  }
}
