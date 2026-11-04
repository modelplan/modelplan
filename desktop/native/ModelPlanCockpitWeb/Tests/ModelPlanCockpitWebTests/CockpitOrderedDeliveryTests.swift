// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanCockpitWeb

@MainActor final class CockpitOrderedDeliveryTests: XCTestCase {
  func testAppearanceBeforeShellAndDisplayBeforeWake() {
    var delivered:[String]=[], completions:[(CockpitDeliveryResult)->Void]=[], accepted:[String]=[]
    let queue=CockpitOrderedDelivery<String>(deliver:{ raw, done in delivered.append(raw);completions.append(done) })
    XCTAssertTrue(queue.submit("appearance",isCurrent:{true},completed:{ _ in accepted.append("appearance") }))
    XCTAssertTrue(queue.submit("shell",isCurrent:{true},completed:{ _ in accepted.append("shell") }))
    XCTAssertEqual(delivered,["appearance"])
    completions[0](.accepted);XCTAssertEqual(delivered,["appearance","shell"])
    completions[1](.accepted);XCTAssertEqual(accepted,["appearance","shell"])
    XCTAssertTrue(queue.submit("display",isCurrent:{true},completed:{ _ in accepted.append("display") }))
    XCTAssertTrue(queue.submit("wake",isCurrent:{true},completed:{ _ in accepted.append("wake") }))
    XCTAssertEqual(delivered,["appearance","shell","display"])
    completions[2](.accepted);XCTAssertEqual(delivered.last,"wake")
  }
  func testCancellationAndNewPageFenceLateCallbacks() {
    var completions:[(CockpitDeliveryResult)->Void]=[], accepted:[String]=[]
    let queue=CockpitOrderedDelivery<String>(deliver:{ _, done in completions.append(done) })
    XCTAssertTrue(queue.submit("old",isCurrent:{true},completed:{ _ in accepted.append("old") }))
    queue.invalidate()
    XCTAssertTrue(queue.submit("new",isCurrent:{true},completed:{ _ in accepted.append("new") }))
    XCTAssertEqual(completions.count,1,"A new epoch must not overtake an in-flight old call")
    completions[0](.rejected);XCTAssertTrue(accepted.isEmpty)
    XCTAssertEqual(completions.count,2,"The new call starts only after the old one returns")
    completions[1](.accepted);XCTAssertEqual(accepted,["new"])
    completions[0](.failed);XCTAssertEqual(accepted,["new"])
  }
  func testClearCannotOvertakeAnInvalidatedInFlightDisplay() {
    var delivered:[String]=[], completions:[(CockpitDeliveryResult)->Void]=[]
    let queue=CockpitOrderedDelivery<String>(deliver:{ raw, done in delivered.append(raw);completions.append(done) })
    XCTAssertTrue(queue.submit("display",isCurrent:{true},completed:{ _ in XCTFail("Invalidated display completed") }))
    queue.invalidate()
    XCTAssertTrue(queue.submit("clear",isCurrent:{true},completed:{ _ in }))
    XCTAssertEqual(delivered,["display"])
    completions[0](.accepted)
    XCTAssertEqual(delivered,["display","clear"])
    completions[0](.accepted)
    XCTAssertEqual(delivered,["display","clear"],"Duplicate old callbacks cannot release the active clear")
    completions[1](.accepted)
  }
  func testSupersededQueuedWorkIsNotSentAndQueueIsBounded() {
    var delivered:[String]=[], completion:((CockpitDeliveryResult)->Void)?, valid=true
    let queue=CockpitOrderedDelivery<String>(capacity:2,deliver:{ raw, done in delivered.append(raw);completion=done })
    XCTAssertTrue(queue.submit("a",isCurrent:{true},completed:{ _ in }))
    XCTAssertTrue(queue.submit("b",isCurrent:{valid},completed:{ _ in XCTFail("Stale job completed") }))
    XCTAssertFalse(queue.submit("overflow",isCurrent:{true},completed:{ _ in }))
    valid=false;completion?(.accepted);XCTAssertEqual(delivered,["a"])
  }
}
