// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanInstruments
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor private final class TrialReceiver: InstrumentTrialHintReceiving {
    var hints: FirstUseHints
    var token: TrialHintRest?
    var begins = 0, cancels = 0
    var onBegin: (() -> Void)?, onCancel: (() -> Void)?
    init() throws {
        hints = FirstUseHints(preferences: .init(seen: Set(FirstUseHintKind.allCases.filter { $0 != .trial })))
        var context = HintContext(cockpitOpen: UUID()); context.captureReady = true
        try hints.updateContext(context, at: 0)
    }
    func beginTrialRest(on target: TrialHintTarget, at now: TimeInterval) -> Bool {
        begins += 1
        do { token = try hints.beginTrialRest(on: target, at: now) } catch { return false }
        onBegin?(); return token != nil
    }
    func cancelTrialRest(on target: TrialHintTarget, reason: TrialHintCancellation) {
        guard let token, token.target == target else { return }
        cancels += 1; hints.cancelTrialRest(token, reason: reason); self.token = nil; onCancel?()
    }
}

@MainActor final class InstrumentHintSourceRouterTests: XCTestCase {
    private func state(_ model: String = "a", x: CGFloat = 20, width: CGFloat = 100) -> InstrumentHintSourceSnapshot {
        .init(anchor: .init(modelID: model, regionID: "travel", travel: CGRect(x: 0, y: 0, width: width, height: 100)), pointer: CGPoint(x: x, y: 20))
    }
    private func enter(_ router: InstrumentHintSourceRouter, _ lease: InstrumentHintSourceLease,
                       _ value: InstrumentHintSourceSnapshot, at: Double = 0) {
        router.receive(.faderRestCandidate(anchor: value.anchor, pointer: value.pointer, at: at), from: lease)
    }
    func testRepeatedCandidateUsesExistingArbiterHalfSecondRestWithoutRestart() async throws {
        let receiver = try TrialReceiver(); var now = 0.0; let value = state()
        let router = InstrumentHintSourceRouter(receiver: receiver, uptime: { now })
        let lease = router.register(isLive: { true }) { value }; enter(router, lease, value)
        now = 0.4; enter(router, lease, value, at: now)
        XCTAssertEqual(receiver.begins, 1); XCTAssertEqual(receiver.token?.deadline, 0.5)
        XCTAssertNotNil(router.validatePendingRest())
        XCTAssertNil(try receiver.hints.nextOffer(placeable: [.trial], at: 0.49))
        let offer = try XCTUnwrap(receiver.hints.offerTrialRest(try XCTUnwrap(receiver.token), placeable: [.trial], at: 0.5))
        try receiver.hints.confirmShown(offer, at: 0.5); router.didConfirmShown(try XCTUnwrap(router.pendingTarget))
        XCTAssertTrue(receiver.hints.preferences.seen.contains(.trial)); XCTAssertNil(router.pendingTarget)
        router.receive(.cancelFaderRest(.leave, at: now), from: lease)
        XCTAssertNotNil(receiver.hints.visible)
    }
    func testOldGenerationRemovalCannotCancelReplacementRest() async throws {
        let receiver = try TrialReceiver(), router = InstrumentHintSourceRouter(receiver: receiver, uptime: { 0 })
        let id = UUID(), first = state(), replacement = state("b")
        let old = router.register(sourceID: id, isLive: { true }) { first }; enter(router, old, first)
        let current = router.register(sourceID: id, isLive: { true }) { replacement }; enter(router, current, replacement)
        let target = router.pendingTarget, cancellations = receiver.cancels
        router.receive(.cancelFaderRest(.removal, at: 0), from: old); enter(router, old, first)
        XCTAssertEqual(router.pendingTarget, target); XCTAssertEqual(receiver.cancels, cancellations)
        XCTAssertEqual(receiver.begins, 2)
    }
    func testLiveOtherSurfaceInputCancelsButItsLeaveDoesNot() async throws {
        let receiver = try TrialReceiver(), router = InstrumentHintSourceRouter(receiver: receiver, uptime: { 0 })
        let value = state(), otherValue = state("b")
        let active = router.register(isLive: { true }) { value }, other = router.register(isLive: { true }) { otherValue }
        enter(router, active, value)
        router.receive(.cancelFaderRest(.leave, at: 0), from: other); XCTAssertNotNil(router.pendingTarget)
        router.receive(.cancelFaderRest(.keyboard, at: 0), from: other)
        XCTAssertNil(router.pendingTarget); XCTAssertNil(receiver.hints.trialRest)
        XCTAssertFalse(receiver.hints.preferences.seen.contains(.trial))
    }
    func testInactiveButRegisteredSurfaceCannotCancelAnotherLiveSurface() async throws {
        let receiver = try TrialReceiver(), router = InstrumentHintSourceRouter(receiver: receiver, uptime: { 0 })
        let value = state(); var otherLive = true
        let active = router.register(isLive: { true }) { value }
        let other = router.register(isLive: { otherLive }) { value }
        enter(router, active, value); otherLive = false
        router.receive(.cancelFaderRest(.focusLoss, at: 0), from: other)
        XCTAssertNotNil(router.pendingTarget); XCTAssertEqual(receiver.cancels, 0)
    }
    func testRetiredOtherSurfaceCannotCancelCurrentRest() async throws {
        let receiver = try TrialReceiver(), router = InstrumentHintSourceRouter(receiver: receiver, uptime: { 0 })
        let value = state(); let current = router.register(isLive: { true }) { value }, retired = router.register(isLive: { true }) { value }
        router.remove(retired); enter(router, current, value)
        router.receive(.cancelFaderRest(.pointerDown, at: 0), from: retired)
        XCTAssertNotNil(router.pendingTarget); XCTAssertEqual(receiver.cancels, 0)
    }
    func testLiveAnchorChangeInvalidatesDeadlineWithoutSpendingFlag() async throws {
        let receiver = try TrialReceiver(), router = InstrumentHintSourceRouter(receiver: receiver, uptime: { 0 })
        var value = state(); let lease = router.register(isLive: { true }) { value }; enter(router, lease, value)
        value = state(width: 80)
        XCTAssertNil(router.validatePendingRest()); XCTAssertNil(receiver.hints.trialRest)
        XCTAssertFalse(receiver.hints.preferences.seen.contains(.trial)); XCTAssertFalse(receiver.hints.cockpitBudgetUsed)
    }
    func testLivePointerDriftInvalidatesDeadline() async throws {
        let receiver = try TrialReceiver(), router = InstrumentHintSourceRouter(receiver: receiver, uptime: { 0 })
        var value = state(); let lease = router.register(isLive: { true }) { value }; enter(router, lease, value)
        value = state(x: 21)
        XCTAssertNil(router.validatePendingRest()); XCTAssertEqual(receiver.cancels, 1)
    }
    func testMovementInsideTravelStartsFreshArbiterRest() async throws {
        let receiver = try TrialReceiver(); var now = 0.0, value = state()
        let router = InstrumentHintSourceRouter(receiver: receiver, uptime: { now }); let lease = router.register(isLive: { true }) { value }
        enter(router, lease, value); now = 0.3; value = state(x: 21); enter(router, lease, value, at: now)
        XCTAssertEqual(receiver.begins, 2); XCTAssertEqual(receiver.cancels, 1); XCTAssertEqual(receiver.token?.deadline, 0.8)
    }
    func testFutureInvalidClockAndInvalidGeometryNeverAdmit() async throws {
        let receiver = try TrialReceiver(); var now = 0.0, value = state()
        let router = InstrumentHintSourceRouter(receiver: receiver, uptime: { now }); let lease = router.register(isLive: { true }) { value }
        enter(router, lease, value, at: 1); now = .nan; enter(router, lease, value)
        now = 0; value = state(width: 0); enter(router, lease, value)
        XCTAssertEqual(receiver.begins, 0); XCTAssertNil(router.pendingTarget)
    }
    func testReentrantBeginRemovalCannotLeavePendingRest() async throws {
        let receiver = try TrialReceiver(), router = InstrumentHintSourceRouter(receiver: receiver, uptime: { 0 })
        let value = state(), lease = router.register(isLive: { true }) { value }
        receiver.onBegin = { router.remove(lease) }; enter(router, lease, value)
        XCTAssertNil(router.pendingTarget); XCTAssertNil(receiver.hints.trialRest)
    }
    func testReentrantCancellationKeepsNewerRest() async throws {
        let receiver = try TrialReceiver(), router = InstrumentHintSourceRouter(receiver: receiver, uptime: { 0 })
        var value = state(); let lease = router.register(isLive: { true }) { value }; enter(router, lease, value)
        let otherValue = state("b"); let other = router.register(isLive: { true }) { otherValue }
        receiver.onCancel = { enterOnce() }
        func enterOnce() { receiver.onCancel = nil; self.enter(router, other, otherValue) }
        value = state(x: 21); enter(router, lease, value)
        XCTAssertEqual(receiver.begins, 2); XCTAssertEqual(router.pendingTarget, receiver.token?.target)
        XCTAssertEqual(router.validatePendingRest()?.anchor.modelID, "b")
    }
    func testCancellationCalloutCannotAdmitSourceItMadeInactive() async throws {
        let receiver = try TrialReceiver(), router = InstrumentHintSourceRouter(receiver: receiver, uptime: { 0 })
        var value = state(), live = true
        let lease = router.register(isLive: { live }) { value }; enter(router, lease, value)
        value = state(x: 21); receiver.onCancel = { live = false }
        enter(router, lease, value)
        XCTAssertEqual(receiver.begins, 1); XCTAssertNil(router.pendingTarget)
        XCTAssertNil(receiver.hints.trialRest); XCTAssertFalse(receiver.hints.preferences.seen.contains(.trial))
    }
    func testCancellationCalloutCannotAdmitAnAnchorThatChangedDuringIt() async throws {
        let receiver = try TrialReceiver(), router = InstrumentHintSourceRouter(receiver: receiver, uptime: { 0 })
        var value = state(); let lease = router.register(isLive: { true }) { value }; enter(router, lease, value)
        value = state(x: 21)
        receiver.onCancel = { value = self.state(x: 22) }
        enter(router, lease, value)
        XCTAssertEqual(receiver.begins, 1); XCTAssertNil(router.pendingTarget)
        XCTAssertFalse(receiver.hints.preferences.seen.contains(.trial))
    }
    func testResolverReentrancyRetiresRestBeforeDeadline() async throws {
        let receiver = try TrialReceiver(), router = InstrumentHintSourceRouter(receiver: receiver, uptime: { 0 })
        let value = state(); var retire = false, lease: InstrumentHintSourceLease?
        lease = router.register(isLive: { true }) { if retire, let lease { router.remove(lease) }; return value }
        enter(router, try XCTUnwrap(lease), value); retire = true
        XCTAssertNil(router.validatePendingRest()); XCTAssertNil(receiver.hints.trialRest)
    }
    func testHostContextInvalidationAllowsSameStationarySourceToEnterAgain() async throws {
        let receiver = try TrialReceiver(), router = InstrumentHintSourceRouter(receiver: receiver, uptime: { 0 })
        let value = state(), lease = router.register(isLive: { true }) { value }
        enter(router, lease, value)
        var next = HintContext(cockpitOpen: UUID()); next.captureReady = true
        try receiver.hints.updateContext(next, at: 0)
        router.cancelPendingRest(reason: .focusLoss)
        enter(router, lease, value)
        XCTAssertEqual(receiver.begins, 2); XCTAssertNotNil(router.pendingTarget)
        XCTAssertEqual(router.pendingTarget, receiver.hints.trialRest?.target)
    }
    func testReceiverAdmissionDenialDoesNotLeaveRouterPending() async throws {
        let receiver = try TrialReceiver(); var context = receiver.hints.context; context.captureReady = false
        try receiver.hints.updateContext(context, at: 0)
        let router = InstrumentHintSourceRouter(receiver: receiver, uptime: { 0 }), value = state()
        let lease = router.register(isLive: { true }) { value }; enter(router, lease, value)
        XCTAssertNil(router.pendingTarget); XCTAssertNil(receiver.hints.trialRest)
    }
}
