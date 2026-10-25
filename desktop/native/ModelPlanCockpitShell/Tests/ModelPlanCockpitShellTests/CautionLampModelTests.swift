// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanCockpitShell

final class CautionLampModelTests: XCTestCase {
    private let start = ContinuousClock().now
    private let amber = CautionLampModel.Condition(id: "subscription/window/low/episode-1", severity: .amber)
    private let red = CautionLampModel.Condition(id: "subscription/window/low/episode-1", severity: .red)
    private let second = CautionLampModel.Condition(id: "other/window/forecast/episode-1", severity: .amber)

    private func time(_ seconds: Double) -> ContinuousClock.Instant { start.advanced(by: .seconds(seconds)) }
    private func assertState(_ model: inout CautionLampModel, at seconds: Double,
                             mode: CautionLampModel.Mode, severity: CautionLampModel.Severity?,
                             deadline: Double? = nil, file: StaticString = #filePath, line: UInt = #line) {
        let p = model.presentation(now: time(seconds))
        XCTAssertEqual(p.mode, mode, file: file, line: line)
        XCTAssertEqual(p.severity, severity, file: file, line: line)
        XCTAssertEqual(p.isLit, severity != nil, file: file, line: line)
        XCTAssertEqual(p.deadline, deadline.map(time), file: file, line: line)
        XCTAssertEqual(p.remainingBlink, deadline.map { Duration.seconds($0 - seconds) } ?? .zero, file: file, line: line)
        if mode != .blinking { XCTAssertNil(p.blinkStartedAt, file: file, line: line) }
    }

    func testOffNewEpisodeAndExactTenSecondTimeoutWithoutAcknowledgement() {
        var model = CautionLampModel(now: start)
        assertState(&model, at: 0, mode: .off, severity: nil)
        XCTAssertNil(model.press(now: start))
        model.update([amber], now: start)
        assertState(&model, at: 0, mode: .blinking, severity: .amber, deadline: 10)
        XCTAssertEqual(model.presentation(now: time(0)).blinkStartedAt, start)
        XCTAssertEqual(CautionLampModel.Presentation.blinkPeriod, .seconds(1))
        assertState(&model, at: 9.5, mode: .blinking, severity: .amber, deadline: 10)
        assertState(&model, at: 10, mode: .steadyUnacknowledged, severity: .amber)
        model.update([amber], now: time(60))
        assertState(&model, at: 60, mode: .steadyUnacknowledged, severity: .amber)
        XCTAssertEqual(model.press(now: time(60)), .openAlerts)
        assertState(&model, at: 60, mode: .acknowledged, severity: .amber)
    }

    func testPressAcknowledgesEveryActiveEpisodeAndEmitsNavigationIntent() {
        var model = CautionLampModel(now: start)
        model.update([amber, second], now: start)
        XCTAssertEqual(model.press(now: time(2)), .openAlerts)
        assertState(&model, at: 2, mode: .acknowledged, severity: .amber)
        model.update([second, amber], now: time(3))
        assertState(&model, at: 3, mode: .acknowledged, severity: .amber)
        XCTAssertEqual(model.press(now: time(4)), .openAlerts)
        model.update([], now: time(5))
        assertState(&model, at: 5, mode: .off, severity: nil)
        XCTAssertNil(model.press(now: time(5)))
    }

    func testRepaintRefreshReorderingAndDuplicateConditionsDoNotRestartDeadline() {
        var model = CautionLampModel(now: start)
        model.update([amber, second], now: start)
        for seconds in [1.0, 3.0, 7.0, 9.5] {
            model.update([second, amber, amber], now: time(seconds))
            assertState(&model, at: seconds, mode: .blinking, severity: .amber, deadline: 10)
        }
        // There are no localized strings or numeric readouts in the identity contract.
        assertState(&model, at: 10, mode: .steadyUnacknowledged, severity: .amber)
    }

    func testWorseningReblinksAfterAcknowledgementAndAfterTimeout() {
        for acknowledge in [false, true] {
            var model = CautionLampModel(now: start)
            model.update([amber], now: start)
            if acknowledge { model.press(now: time(1)) }
            _ = model.presentation(now: time(10))
            model.update([red], now: time(12))
            assertState(&model, at: 12, mode: .blinking, severity: .red, deadline: 22)
            XCTAssertEqual(model.presentation(now: time(12)).blinkStartedAt, time(12))
        }
    }

    func testNewEpisodeBlinksAlongsideAcknowledgedCondition() {
        var model = CautionLampModel(now: start)
        model.update([amber], now: start)
        model.press(now: time(1))
        model.update([amber, second], now: time(4))
        assertState(&model, at: 4, mode: .blinking, severity: .amber, deadline: 14)
        // When the new condition clears, the remaining acknowledged condition stays acknowledged.
        model.update([amber], now: time(5))
        assertState(&model, at: 5, mode: .acknowledged, severity: .amber)
    }

    func testSeverityReductionAndPartialClearKeepHighestRemainingSeverity() {
        var model = CautionLampModel(now: start)
        model.update([red, second], now: start)
        model.update([amber, second], now: time(2))
        assertState(&model, at: 2, mode: .blinking, severity: .amber, deadline: 10)
        model.update([second], now: time(4))
        assertState(&model, at: 4, mode: .blinking, severity: .amber, deadline: 10)
        assertState(&model, at: 10, mode: .steadyUnacknowledged, severity: .amber)
        model.update([red, second], now: time(12))
        model.update([red], now: time(13))
        assertState(&model, at: 13, mode: .blinking, severity: .red, deadline: 22)
    }

    func testClearThenRecurrenceDropsAcknowledgementEvenWhileOtherConditionsRemain() {
        var model = CautionLampModel(now: start)
        model.update([amber, second], now: start)
        model.press(now: time(1))
        model.update([second], now: time(2))
        assertState(&model, at: 2, mode: .acknowledged, severity: .amber)
        model.update([amber, second], now: time(3))
        assertState(&model, at: 3, mode: .blinking, severity: .amber, deadline: 13)
        model.update([], now: time(4))
        assertState(&model, at: 4, mode: .off, severity: nil)
        model.update([amber], now: time(5))
        assertState(&model, at: 5, mode: .blinking, severity: .amber, deadline: 15)
    }

    func testDuplicateIdentityAlwaysUsesWorstSeverityRegardlessOfInputOrder() {
        for conditions in [[amber, red], [red, amber]] {
            var model = CautionLampModel(now: start)
            model.update(conditions, now: start)
            assertState(&model, at: 0, mode: .blinking, severity: .red, deadline: 10)
            model.update(conditions.reversed(), now: time(2))
            assertState(&model, at: 2, mode: .blinking, severity: .red, deadline: 10)
        }
    }

    func testHideShowAndDelayedMenuCallbacksUseOriginalMonotonicDeadline() {
        var model = CautionLampModel(now: start)
        model.update([amber], now: start)
        // Render on reopening; no update/reinitialization creates a fresh caution.
        assertState(&model, at: 4, mode: .blinking, severity: .amber, deadline: 10)
        XCTAssertEqual(model.presentation(now: time(4)).blinkStartedAt, start)
        assertState(&model, at: 3600, mode: .steadyUnacknowledged, severity: .amber)
        model.update([amber], now: time(3601))
        assertState(&model, at: 3601, mode: .steadyUnacknowledged, severity: .amber)
    }

    func testOldDeadlineCallbackCannotEndNewerBlink() {
        var model = CautionLampModel(now: start)
        model.update([amber], now: start)
        model.update([red], now: time(8))
        assertState(&model, at: 10, mode: .blinking, severity: .red, deadline: 18)
        assertState(&model, at: 18, mode: .steadyUnacknowledged, severity: .red)
    }

    func testReduceMotionIsImmediatelySteadyAndDoesNotRestartOnPreferenceChange() {
        var model = CautionLampModel(now: start, reduceMotion: true)
        model.update([amber], now: start)
        assertState(&model, at: 0, mode: .steadyUnacknowledged, severity: .amber)
        model.setReduceMotion(false, now: time(1))
        assertState(&model, at: 1, mode: .steadyUnacknowledged, severity: .amber)
        model.update([red], now: time(2))
        assertState(&model, at: 2, mode: .blinking, severity: .red, deadline: 12)
        model.setReduceMotion(true, now: time(3))
        assertState(&model, at: 3, mode: .steadyUnacknowledged, severity: .red)
        model.setReduceMotion(false, now: time(4))
        assertState(&model, at: 4, mode: .steadyUnacknowledged, severity: .red)
        model.press(now: time(5))
        assertState(&model, at: 5, mode: .acknowledged, severity: .red)
    }
}
