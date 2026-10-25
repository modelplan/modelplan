// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanCockpitShell

final class CautionNoticeTests: XCTestCase {
    let start = ContinuousClock.now
    func time(_ seconds: Double) -> ContinuousClock.Instant { start.advanced(by: .seconds(seconds)) }
    func id(_ episode: String = "episode", subscription: String = "subscription", window: String? = "5h") throws -> CautionEpisodeID {
        try .init(subscriptionID: subscription, windowID: window, eventKind: "quota-low", episodeID: episode)
    }
    func notice(_ level: CautionNoticeLevel, episode: String = "episode") throws -> CautionNotice {
        .init(episode: try id(episode), level: level)
    }
    func testStableSemanticIdentityDoesNotUseLabelsAndCannotCollideAtDelimiters() throws {
        let a = try CautionEpisodeID(subscriptionID: "a|b", windowID: "c", eventKind: "low", episodeID: "1")
        let b = try CautionEpisodeID(subscriptionID: "a", windowID: "b|c", eventKind: "low", episodeID: "1")
        XCTAssertNotEqual(a.conditionID, b.conditionID)
        var model = CautionLampModel(now: start)
        model.update(notices: [.init(episode: a, level: .amber)], now: start)
        model.press(now: time(1))
        model.update(notices: [.init(episode: b, level: .amber)], now: time(2))
        XCTAssertEqual(model.presentation(now: time(2)).mode, .blinking)
        XCTAssertEqual(model.presentation(now: time(2)).deadline, time(12))
        let rebuilt = try CautionEpisodeID(subscriptionID: "a", windowID: "b|c", eventKind: "low", episodeID: "1")
        model.update(notices: [.init(episode: rebuilt, level: .amber)], now: time(3))
        XCTAssertEqual(model.presentation(now: time(3)).deadline, time(12))
    }
    func testCanonicalUnicodeIdentityDoesNotCreateANewEpisodeOnReconstruction() throws {
        let first = try id(subscription: "caf\u{e9}")
        let rebuilt = try id(subscription: "cafe\u{301}")
        XCTAssertEqual(first, rebuilt)
        XCTAssertEqual(first.conditionID, rebuilt.conditionID)
        var model = CautionLampModel(now: start)
        model.update(notices: [.init(episode: first, level: .amber)], now: start)
        model.update(notices: [.init(episode: rebuilt, level: .amber)], now: time(3))
        XCTAssertEqual(model.presentation(now: time(3)).deadline, time(10))
    }
    func testBlueInformationCannotIgniteOrRenewAmberDeadline() throws {
        var model = CautionLampModel(now: start)
        model.update(notices: [try notice(.information)], now: start)
        XCTAssertEqual(model.presentation(now: start).mode, .off)
        XCTAssertNil(model.press(now: start))
        model.update(notices: [try notice(.amber)], now: time(1))
        model.update(notices: [try notice(.amber), try notice(.information, episode: "public-reset")], now: time(4))
        XCTAssertEqual(model.presentation(now: time(4)).deadline, time(11))
        model.update(notices: [try notice(.information)], now: time(5))
        XCTAssertEqual(model.presentation(now: time(5)).mode, .off)
    }
    func testSpecifiedEpisodeAckWorseningTimeoutClearAndRecurrenceSequence() throws {
        var model = CautionLampModel(now: start)
        model.update(notices: [try notice(.amber)], now: time(0))
        XCTAssertEqual(model.presentation(now: time(0)).deadline, time(10))
        XCTAssertEqual(model.press(now: time(3)), .openAlerts)
        XCTAssertEqual(model.presentation(now: time(3)).mode, .acknowledged)
        model.update(notices: [try notice(.red)], now: time(6))
        XCTAssertEqual(model.presentation(now: time(6)).deadline, time(16))
        XCTAssertEqual(model.presentation(now: time(16)).mode, .steadyUnacknowledged)
        model.update(notices: [], now: time(20))
        XCTAssertEqual(model.presentation(now: time(20)).mode, .off)
        model.update(notices: [try notice(.amber)], now: time(24))
        XCTAssertEqual(model.presentation(now: time(24)).deadline, time(34))
    }
    func testNewSameSeverityEpisodeReblinksFromBothAcknowledgedAndTimedOutModes() throws {
        for acknowledged in [false, true] {
            var model = CautionLampModel(now: start)
            model.update(notices: [try notice(.amber)], now: start)
            if acknowledged { model.press(now: time(2)) }
            _ = model.presentation(now: time(10))
            model.update(notices: [try notice(.amber), try notice(.amber, episode: "new")], now: time(12))
            XCTAssertEqual(model.presentation(now: time(12)).mode, .blinking)
            XCTAssertEqual(model.presentation(now: time(12)).deadline, time(22))
        }
    }
    func testReduceMotionSeverityAndAcknowledgementMatrix() throws {
        for reduced in [false, true] { for level in [CautionNoticeLevel.amber, .red] { for ack in [false, true] {
            var model = CautionLampModel(now: start, reduceMotion: reduced)
            model.update(notices: [try notice(level)], now: start)
            let initial = model.presentation(now: start)
            XCTAssertEqual(initial.mode, reduced ? .steadyUnacknowledged : .blinking)
            XCTAssertEqual(initial.deadline, reduced ? nil : time(10))
            if ack { XCTAssertEqual(model.press(now: time(2)), .openAlerts) }
            model.update(notices: [try notice(level)], now: time(10))
            XCTAssertEqual(model.presentation(now: time(10)).mode, ack ? .acknowledged : .steadyUnacknowledged)
            model.setReduceMotion(true, now: time(11)); model.setReduceMotion(false, now: time(12))
            XCTAssertEqual(model.presentation(now: time(12)).mode, ack ? .acknowledged : .steadyUnacknowledged)
            model.update(notices: [], now: time(13))
            XCTAssertEqual(model.presentation(now: time(13)).mode, .off)
        } } }
    }
    func testSleepRestoreAndRepeatedIdenticalInputDoNotResetContinuousDeadline() throws {
        var model = CautionLampModel(now: start)
        model.update(notices: [try notice(.red)], now: start)
        for seconds in [1.0, 3, 9] {
            model.update(notices: [try notice(.red)], now: time(seconds))
            XCTAssertEqual(model.presentation(now: time(seconds)).deadline, time(10))
        }
        XCTAssertEqual(model.presentation(now: time(24 * 3600)).mode, .steadyUnacknowledged)
        model.update(notices: [try notice(.red)], now: time(24 * 3600 + 1))
        XCTAssertEqual(model.presentation(now: time(24 * 3600 + 1)).mode, .steadyUnacknowledged)
        XCTAssertEqual(model.press(now: time(24 * 3600 + 2)), .openAlerts)
        XCTAssertEqual(model.presentation(now: time(24 * 3600 + 2)).mode, .acknowledged)
    }
    func testAbsentWindowIsStableAndInvalidIdentityIsRejected() throws {
        XCTAssertEqual(try id(window: nil).conditionID, try id(window: nil).conditionID)
        XCTAssertNotEqual(try id(window: nil).conditionID, try id(window: "5h").conditionID)
        XCTAssertThrowsError(try CautionEpisodeID(subscriptionID: "", windowID: nil, eventKind: "low", episodeID: "1"))
        XCTAssertThrowsError(try CautionEpisodeID(subscriptionID: "s", windowID: "", eventKind: "low", episodeID: "1"))
        XCTAssertThrowsError(try CautionEpisodeID(subscriptionID: "s", windowID: nil, eventKind: "low", episodeID: ""))
    }
}
