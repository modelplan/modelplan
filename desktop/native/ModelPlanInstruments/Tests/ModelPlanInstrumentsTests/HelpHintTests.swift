// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanInstruments

final class HelpHintTests: XCTestCase {
    func testExactlyFiveKnownFirstUseFlags() {
        XCTAssertEqual(FirstUseHint.allCases.map(\.rawValue), ["trial", "ignition", "pinned", "page", "cockpit"])
        XCTAssertEqual(FirstUseHintLedger.storageKey, "r7-help-hints-v1")
        var ledger = FirstUseHintLedger()
        for hint in FirstUseHint.allCases {
            XCTAssertFalse(ledger.hasSeen(hint)); ledger.mark(hint); XCTAssertTrue(ledger.hasSeen(hint))
        }
        ledger.reset()
        XCTAssertTrue(FirstUseHint.allCases.allSatisfy { !ledger.hasSeen($0) })
    }

    func testLedgerPersistsAndRestoresStrictTrueFlags() throws {
        let json = Data(#"{"trial":true,"ignition":false,"pinned":"true","page":1,"cockpit":true,"future":true}"#.utf8)
        let ledger = FirstUseHintLedger.restore(json)
        XCTAssertTrue(ledger.hasSeen(.trial)); XCTAssertTrue(ledger.hasSeen(.cockpit))
        for hint in [FirstUseHint.ignition, .pinned, .page] { XCTAssertFalse(ledger.hasSeen(hint)) }
        let encoded = try JSONEncoder().encode(ledger)
        XCTAssertEqual(try JSONDecoder().decode(FirstUseHintLedger.self, from: encoded), ledger)
        XCTAssertEqual(try JSONSerialization.jsonObject(with: encoded) as? [String: Bool], ["trial": true, "cockpit": true])
        var reset = ledger; reset.reset()
        XCTAssertEqual(try JSONSerialization.jsonObject(with: JSONEncoder().encode(reset)) as? [String: Bool], [:])
    }

    func testMissingAndCorruptLedgerDoNotConsumeHints() {
        for data in [nil, Data(), Data("null".utf8), Data("[]".utf8), Data("{broken".utf8)] {
            XCTAssertEqual(FirstUseHintLedger.restore(data), FirstUseHintLedger())
        }
    }

    func testDisplayedHintsMarkOnceAndPersistAcrossQueueRecreation() throws {
        var queue = HelpHintQueue()
        XCTAssertTrue(queue.enqueue(.init(.trial), at: 0))
        XCTAssertFalse(queue.ledger.hasSeen(.trial))
        XCTAssertEqual(queue.advance(at: 0, canPresent: { _ in true }), [.show(.init(.trial))])
        XCTAssertTrue(queue.ledger.hasSeen(.trial)); XCTAssertFalse(queue.enqueue(.init(.trial), at: 0.1))
        let restored = try JSONDecoder().decode(FirstUseHintLedger.self, from: JSONEncoder().encode(queue.ledger))
        var reopened = HelpHintQueue(ledger: restored)
        XCTAssertFalse(reopened.enqueue(.init(.trial), at: 100))
        XCTAssertTrue(reopened.enqueue(.init(.ignition), at: 100))
    }

    func testNoRoomOrInvisibleAnchorDoesNotMarkAndCanRetry() {
        var queue = HelpHintQueue()
        queue.enqueue(.init(.cockpit), at: 0)
        XCTAssertTrue(queue.advance(at: 0, canPresent: { _ in false }).isEmpty)
        XCTAssertNil(queue.active); XCTAssertFalse(queue.ledger.hasSeen(.cockpit))
        XCTAssertTrue(queue.enqueue(.init(.cockpit), at: 1))
        XCTAssertEqual(queue.advance(at: 1, canPresent: { _ in true }), [.show(.init(.cockpit))])
    }

    func testQueueSkipsIneligibleCandidateAndShowsOnlyOne() {
        var queue = HelpHintQueue()
        queue.enqueue(.init(.ignition), at: 0); queue.enqueue(.init(.cockpit), at: 0)
        XCTAssertEqual(queue.advance(at: 0, canPresent: { $0.hint == .cockpit }), [.show(.init(.cockpit))])
        XCTAssertFalse(queue.ledger.hasSeen(.ignition)); XCTAssertTrue(queue.ledger.hasSeen(.cockpit))
        XCTAssertTrue(queue.advance(at: 1, canPresent: { _ in true }).isEmpty)
    }

    func testUrgentPriorityDoesNotPreemptActiveHint() {
        var queue = HelpHintQueue()
        queue.enqueue(.init(.ignition), at: 0); queue.enqueue(.init(.cockpit), at: 0)
        queue.enqueue(.init(.trial), at: 0); queue.enqueue(.init(.pinned), at: 0)
        XCTAssertEqual(queue.pending.map(\.hint), [.pinned, .trial, .ignition, .cockpit])
        XCTAssertEqual(queue.advance(at: 0, canPresent: { _ in true }), [.show(.init(.pinned))])
        XCTAssertTrue(queue.advance(at: 1, canPresent: { _ in true }).isEmpty)
        XCTAssertEqual(queue.active?.request.hint, .pinned)
        XCTAssertFalse(queue.enqueue(.init(.trial), at: 1))
    }

    func testFiveSecondTimeoutAndTwoHundredMillisecondGap() {
        var queue = HelpHintQueue()
        queue.enqueue(.init(.trial), at: 0); queue.enqueue(.init(.cockpit), at: 0)
        _ = queue.advance(at: 0, canPresent: { _ in true })
        XCTAssertEqual(queue.active?.expiresAt, 5); XCTAssertEqual(queue.nextDeadline, 5)
        XCTAssertTrue(queue.advance(at: 4.999, canPresent: { _ in true }).isEmpty)
        XCTAssertEqual(queue.advance(at: 5, canPresent: { _ in true }), [.hide(.trial)])
        XCTAssertEqual(queue.nextDeadline, 5.2)
        XCTAssertTrue(queue.advance(at: 5.199, canPresent: { _ in true }).isEmpty)
        XCTAssertEqual(queue.advance(at: 5.2, canPresent: { _ in true }), [.show(.init(.cockpit))])
    }

    func testNextActionUsesSevenHundredFiftyMillisecondGap() {
        var queue = HelpHintQueue()
        queue.enqueue(.init(.cockpit), at: 0); queue.enqueue(.init(.ignition), at: 0)
        _ = queue.advance(at: 0, canPresent: { _ in true })
        XCTAssertEqual(queue.dismiss(at: 1), [.hide(.cockpit)])
        XCTAssertTrue(queue.advance(at: 1.749, canPresent: { _ in true }).isEmpty)
        XCTAssertEqual(queue.advance(at: 1.75, canPresent: { _ in true }), [.show(.init(.ignition))])
    }

    func testNewUrgentRequestBypassesCooldownButNormalRequestDoesNot() {
        var queue = HelpHintQueue()
        queue.enqueue(.init(.cockpit), at: 0); queue.enqueue(.init(.ignition), at: 0)
        _ = queue.advance(at: 0, canPresent: { _ in true }); _ = queue.dismiss(at: 1)
        queue.enqueue(.init(.page, pageNumber: 2), at: 1.1)
        XCTAssertTrue(queue.advance(at: 1.1, canPresent: { _ in true }).isEmpty)
        queue.enqueue(.init(.trial), at: 1.2)
        XCTAssertEqual(queue.advance(at: 1.2, canPresent: { _ in true }), [.show(.init(.trial))])
    }

    func testPageHintNeedsOneBasedNumberAndIsOnceAcrossPages() {
        var queue = HelpHintQueue()
        for page in [nil, -1, 0] { XCTAssertFalse(queue.enqueue(.init(.page, pageNumber: page), at: 0)) }
        XCTAssertTrue(queue.enqueue(.init(.page, pageNumber: 2), at: 0))
        XCTAssertFalse(queue.enqueue(.init(.page, pageNumber: 3), at: 0))
        _ = queue.advance(at: 0, canPresent: { _ in true }); _ = queue.dismiss(at: 1)
        XCTAssertFalse(queue.enqueue(.init(.page, pageNumber: 3), at: 1))
    }

    func testResetClearsFlagsCurrentPendingAndOldDeadlines() {
        var ledger = FirstUseHintLedger()
        FirstUseHint.allCases.forEach { ledger.mark($0) }
        var queue = HelpHintQueue(ledger: ledger)
        XCTAssertTrue(queue.reset().isEmpty)
        queue.enqueue(.init(.trial), at: 1); queue.enqueue(.init(.cockpit), at: 1)
        _ = queue.advance(at: 1, canPresent: { _ in true })
        XCTAssertEqual(queue.reset(), [.hide(.trial)])
        XCTAssertNil(queue.active); XCTAssertTrue(queue.pending.isEmpty)
        XCTAssertTrue(queue.advance(at: 100, canPresent: { _ in true }).isEmpty)
        for hint in FirstUseHint.allCases { XCTAssertFalse(queue.ledger.hasSeen(hint)) }
        queue.enqueue(.init(.trial), at: 100)
        XCTAssertEqual(queue.advance(at: 100, canPresent: { _ in true }), [.show(.init(.trial))])
    }

    func testPreferenceSynchronizationCancelsOldWorkAndUsesNewLedger() {
        var queue = HelpHintQueue()
        queue.enqueue(.init(.trial), at: 0); queue.enqueue(.init(.cockpit), at: 0)
        _ = queue.advance(at: 0, canPresent: { _ in true })
        var incoming = FirstUseHintLedger(); incoming.mark(.ignition)
        XCTAssertEqual(queue.synchronize(with: incoming), [.hide(.trial)])
        XCTAssertTrue(queue.pending.isEmpty); XCTAssertNil(queue.active)
        XCTAssertTrue(queue.ledger.hasSeen(.ignition)); XCTAssertFalse(queue.ledger.hasSeen(.trial))
        XCTAssertFalse(queue.enqueue(.init(.ignition), at: 1))
    }

    func testNonfiniteClocksDoNotMutateQueueAndReducedMotionOnlyChangesFade() {
        var queue = HelpHintQueue()
        XCTAssertFalse(queue.enqueue(.init(.trial), at: .nan))
        queue.enqueue(.init(.trial), at: 0); _ = queue.advance(at: 0, canPresent: { _ in true })
        XCTAssertTrue(queue.dismiss(at: .infinity).isEmpty)
        XCTAssertTrue(queue.advance(at: .nan, canPresent: { _ in true }).isEmpty)
        XCTAssertEqual(queue.active?.request.hint, .trial)
        XCTAssertEqual(HelpTiming.dismissalFade(reducedMotion: true), 0)
        XCTAssertEqual(HelpTiming.dismissalFade(reducedMotion: false), 0.18)
        XCTAssertEqual(HelpTiming.hintDuration, 5)
    }

    func testPointerDwellAndKeyboardImmediateExplanation() {
        var dwell = HelpDwell()
        dwell.enter("quota.a", keyboardFocus: false, at: 10)
        XCTAssertEqual(dwell.nextDeadline, 10.5)
        dwell.advance(at: 10.499); XCTAssertNil(dwell.visibleSourceID)
        dwell.advance(at: 10.5); XCTAssertEqual(dwell.visibleSourceID, "quota.a"); XCTAssertNil(dwell.nextDeadline)
        dwell.enter("effort.a", keyboardFocus: true, at: 11)
        XCTAssertEqual(dwell.visibleSourceID, "effort.a")
        dwell.leave(); dwell.advance(at: 100)
        XCTAssertNil(dwell.sourceID); XCTAssertNil(dwell.visibleSourceID)
    }

    func testRepeatedPointerTargetDoesNotRestartDwellAndNewTargetCancelsOldOne() {
        var dwell = HelpDwell()
        dwell.enter("a", keyboardFocus: false, at: 0)
        dwell.enter("a", keyboardFocus: false, at: 0.3)
        dwell.advance(at: 0.5); XCTAssertEqual(dwell.visibleSourceID, "a")
        dwell.enter("b", keyboardFocus: false, at: 1)
        XCTAssertNil(dwell.visibleSourceID)
        dwell.enter("c", keyboardFocus: false, at: 1.2)
        dwell.advance(at: 1.5); XCTAssertNil(dwell.visibleSourceID)
        dwell.advance(at: 1.7); XCTAssertEqual(dwell.visibleSourceID, "c")
    }
}
