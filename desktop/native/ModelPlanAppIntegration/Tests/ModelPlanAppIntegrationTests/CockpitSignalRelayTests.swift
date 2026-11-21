// SPDX-License-Identifier: MIT
import XCTest
import ModelPlanShell
import ModelPlanCockpitWeb
@testable import ModelPlanAppIntegration

/// Native-shell spec item 2 (tail): the app's relay between the lifecycle's `SystemEvents` and every cockpit page.
@MainActor final class CockpitSignalRelayTests: XCTestCase {
  func testOneWakePerSystemWakeAndEveryOtherEdge() {
    var now: UInt64 = 10_000
    let relay = CockpitSignalRelay(now: { now })
    var received: [CockpitSystemSignal] = []
    let cancel = relay.subscribe { received.append($0) }
    relay.deliver(.wake); now += 400; relay.deliver(.screensWake)
    XCTAssertEqual(received, [.wake], "didWake and screensDidWake of one wake are one wake")
    now += CockpitSignalRelay.wakeCollapseMilliseconds
    relay.deliver(.screensWake)
    XCTAssertEqual(received, [.wake, .wake], "a later display-only wake is its own")
    relay.deliver(.unlock); relay.deliver(.clockChanged); relay.deliver(.timeZoneChanged)
    relay.deliver(.displaysChanged); relay.deliver(.displaysChanged); relay.deliver(.displaysSettled)
    XCTAssertEqual(received, [.wake, .wake, .unlock, .clockChanged, .clockChanged, .displaysChanged, .displaysChanged, .displaysSettled],
                   "nothing else is collapsed: each edge arrives once, in order")
    cancel(); cancel()
    relay.deliver(.unlock)
    XCTAssertEqual(received.count, 8, "an unsubscribed page gets nothing; unsubscribing twice is harmless")
    XCTAssertEqual(relay.subscriberCount, 0)
  }

  func testAPageThatUnsubscribesWhileASignalIsDeliveredDoesNotStopTheOthers() {
    let relay = CockpitSignalRelay(now: { 0 })
    var first = 0, second = 0
    var cancelFirst: (() -> Void)?
    cancelFirst = relay.subscribe { _ in first += 1; cancelFirst?() }
    _ = relay.subscribe { _ in second += 1 }
    relay.deliver(.unlock); relay.deliver(.unlock)
    XCTAssertEqual(first, 1); XCTAssertEqual(second, 2)
  }
}
