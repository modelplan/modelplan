// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanCockpitWeb

/// Native-shell spec item 1.6: the one dismissal decision, on an injected clock.
@MainActor final class DismissalFunnelTests: XCTestCase {
  private var clock: UInt64 = 0
  private var closes: [DismissReason] = []
  private var live: DismissalSuppression = []
  private func funnel() -> DismissalFunnel {
    DismissalFunnel(now: { [unowned self] in self.clock }, live: { [unowned self] in self.live },
                    close: { [unowned self] in self.closes.append($0) })
  }

  func testOneCloseForEachShowAndNothingWhileNotArmed() {
    let value = funnel()
    XCTAssertEqual(value.request(.outsidePress), .ignored, "not shown yet")
    value.rearm()
    XCTAssertEqual(value.request(.outsidePress), .closed)
    XCTAssertEqual(value.request(.outsidePress), .ignored, "the second monitor for the same click is a no-op")
    XCTAssertEqual(value.request(.appResigned), .ignored)
    XCTAssertEqual(closes, [.outsidePress])
    value.rearm(); value.disarm()
    XCTAssertEqual(value.request(.keyResigned), .ignored, "a detach disarms")
  }

  func testEverySuppressionDropsPointerResignAndKeyButEscapeOnlyForModalOrMenu() {
    let value = funnel()
    let all: [DismissalSuppression] = [.drag, .modal, .menuTracking, .policyChange, .opening, .ownedChild]
    for suppression in all {
      value.rearm()
      let hold = value.hold(suppression)
      for reason in [DismissReason.outsidePress, .appResigned, .keyResigned] {
        XCTAssertEqual(value.request(reason), .suppressed(suppression), "\(suppression) drops \(reason)")
      }
      let escape = value.request(.escape)
      if suppression == .modal || suppression == .menuTracking {
        XCTAssertEqual(escape, .suppressed(suppression))
        hold.release()
        XCTAssertEqual(value.request(.escape), .closed)
      } else {
        XCTAssertEqual(escape, .closed, "\(suppression) does not hold Esc back")
        hold.release()
      }
    }
    XCTAssertTrue(closes.allSatisfy { $0 == .escape })
    XCTAssertEqual(closes.count, all.count)
  }

  func testLiveSuppressionIsReadAtRequestTime() {
    let value = funnel()
    value.rearm()
    live = .drag
    XCTAssertEqual(value.request(.outsidePress), .suppressed(.drag))
    live = []
    XCTAssertEqual(value.request(.outsidePress), .closed, "after the drag is cancelled a press closes again")
  }

  func testTimedHoldExpiresExactlyOnTheInjectedClock() {
    let value = funnel()
    value.rearm()
    clock = 1_000
    value.hold(.policyChange, forMilliseconds: 250)
    clock = 1_249
    XCTAssertEqual(value.request(.appResigned), .suppressed(.policyChange))
    clock = 1_250
    XCTAssertEqual(value.request(.appResigned), .closed)
  }

  func testRearmClearsHoldsAndReleaseIsIdempotent() {
    let value = funnel()
    value.rearm()
    let leaked = value.hold(.drag)
    value.rearm()
    XCTAssertEqual(value.activeSuppression, [], "a leaked hold does not survive the next show")
    leaked.release(); leaked.release()
    XCTAssertTrue(leaked.isReleased)
    let a = value.hold(.drag), b = value.hold(.drag)
    a.release(); a.release()
    XCTAssertEqual(value.request(.outsidePress), .suppressed(.drag), "the other holder still holds")
    b.release()
    XCTAssertEqual(value.request(.outsidePress), .closed)
  }

  func testACloseThatRequestsAgainIsIgnored() {
    var inner: DismissalFunnel.Outcome?
    var value: DismissalFunnel!
    value = DismissalFunnel(now: { 0 }, close: { _ in inner = value.request(.outsidePress) })
    value.rearm()
    XCTAssertEqual(value.request(.appResigned), .closed)
    XCTAssertEqual(inner, .ignored)
  }

  /// Spec item 3.6: the pure collection behaviour.
  func testCollectionBehaviourIsExactForEachAttachment() {
    XCTAssertEqual(CockpitWindowController.collectionBehavior(detached: false), [.moveToActiveSpace, .fullScreenAuxiliary, .ignoresCycle])
    XCTAssertEqual(CockpitWindowController.collectionBehavior(detached: true), [])
    for detached in [false, true] {
      XCTAssertFalse(CockpitWindowController.collectionBehavior(detached: detached).contains(.canJoinAllSpaces))
    }
  }
}
