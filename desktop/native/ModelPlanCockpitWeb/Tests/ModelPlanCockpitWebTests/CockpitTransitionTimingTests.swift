// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanCockpitWeb

final class CockpitTransitionTimingTests: XCTestCase {
  func testMonotonicStagesIncludeRequestHopAndOnlyFirstRender() {
    var clock: TimeInterval = 10
    var timing = CockpitTransitionTiming(now: { clock })
    timing.beginOpen(requestedAt: 9.95)
    XCTAssertEqual(timing.openStage("request"), "open stage=request elapsedMs=50")
    clock = 10.1
    XCTAssertEqual(timing.openStage("window-visible"), "open stage=window-visible elapsedMs=150")
    clock = 10.2
    XCTAssertEqual(timing.openStage("page-rendered"), "open stage=page-rendered elapsedMs=250")
    XCTAssertNil(timing.openStage("page-rendered"))
    XCTAssertEqual(timing.beginClose(), "close stage=request elapsedMs=0")
    clock = 10.32
    XCTAssertEqual(timing.gone(), "close stage=gone elapsedMs=120")
    XCTAssertNil(timing.gone())
    timing.beginOpen()
    clock = 10.34
    XCTAssertEqual(timing.openStage("page-rendered"), "open stage=page-rendered elapsedMs=20")
  }
}
