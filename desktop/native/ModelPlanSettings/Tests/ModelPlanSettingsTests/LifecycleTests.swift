// SPDX-License-Identifier: MIT
import Foundation
import XCTest
@testable import ModelPlanSettings

final class LifecycleTests: XCTestCase {
    // F15/F20 fixed clock, independent of machine locale/time zone.
    let now = ISO8601DateFormatter().date(from: "2026-10-20T21:05:00Z")!
    private func notice(_ kind: NotificationKind = .forecast, episode: String = "episode-a", restored: Bool = false) -> SettingsNotice {
        .init(kind: kind, subscriptionID: "synthetic-sub", episodeID: episode, beganAt: now.addingTimeInterval(-10),
              expiresAt: now.addingTimeInterval(60), projectName: "Synthetic Project", restored: restored)
    }
    func testNotificationPermissionOnlyAfterOptInAndLateResultsCannotReenable() throws {
        var p = SettingsPreferences(), policy = NotificationPolicy()
        XCTAssertNil(policy.delivery(for: notice(), preferences: p, now: now))
        guard case .requestAuthorization(let token) = policy.userSetOptIn(true, preferences: &p) else { return XCTFail() }
        XCTAssertEqual(policy.userSetOptIn(true, preferences: &p), .none)
        policy.receivedAuthorization(.authorized, request: UUID())
        XCTAssertEqual(policy.authorization, .notDetermined)
        _ = policy.userSetOptIn(false, preferences: &p)
        policy.receivedAuthorization(.authorized, request: token)
        XCTAssertEqual(policy.authorization, .notDetermined); XCTAssertFalse(p.notifications.optedIn)
        guard case .requestAuthorization(let second) = policy.userSetOptIn(true, preferences: &p) else { return XCTFail() }
        policy.receivedAuthorization(.denied, request: second)
        _ = policy.userSetOptIn(false, preferences: &p)
        XCTAssertEqual(policy.userSetOptIn(true, preferences: &p), .none) // Never loops on denied permission.
        XCTAssertNil(policy.delivery(for: notice(), preferences: p, now: now))
    }
    func testEveryKindOptOutSemanticDedupAndRestartLedger() throws {
        var p = SettingsPreferences(); p.notifications.optedIn = true
        var policy = NotificationPolicy(authorization: .authorized)
        for kind in NotificationKind.allCases {
            let event = notice(kind)
            XCTAssertNotNil(policy.delivery(for: event, preferences: p, now: now))
            policy.recordDelivered(event, preferences: p, now: now)
            XCTAssertNil(policy.delivery(for: event, preferences: p, now: now.addingTimeInterval(5)))
        }
        XCTAssertEqual(policy.ledger.count, 5)
        let encoded = try JSONEncoder().encode(policy.ledger)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("Synthetic Project"))
        let ledger = try JSONDecoder().decode(NotificationLedger.self, from: encoded)
        var restarted = NotificationPolicy(authorization: .authorized, ledger: ledger)
        XCTAssertNil(restarted.delivery(for: notice(), preferences: p, now: now))
        XCTAssertNotNil(restarted.delivery(for: notice(episode: "recurrence-b"), preferences: p, now: now))
        p.notifications.kinds.remove(.stale)
        restarted.recordDelivered(notice(.stale, episode: "new"), preferences: p, now: now)
        XCTAssertEqual(restarted.ledger.count, 5)
        XCTAssertNil(restarted.delivery(for: notice(.stale, episode: "new"), preferences: p, now: now))
    }
    func testLedgerCapacitySuppressesRatherThanEvictingLiveEpisodes() throws {
        let entries: [[String: Any]] = (0..<4096).map { index in
            ["key": ["kind": "forecast", "subscriptionID": "synthetic-sub", "episodeID": "seen-\(index)"],
             "expiresAt": now.addingTimeInterval(60).timeIntervalSinceReferenceDate]
        }
        let data = try JSONSerialization.data(withJSONObject: ["entries": entries])
        let ledger = try JSONDecoder().decode(NotificationLedger.self, from: data)
        var p = SettingsPreferences(); p.notifications.optedIn = true
        var policy = NotificationPolicy(authorization: .authorized, ledger: ledger)
        XCTAssertNil(policy.delivery(for: notice(), preferences: p, now: now))
        let later = now.addingTimeInterval(61)
        let next = SettingsNotice(kind: .reset, subscriptionID: "synthetic-sub", episodeID: "next",
                                  beganAt: later, expiresAt: later.addingTimeInterval(60))
        XCTAssertNotNil(policy.delivery(for: next, preferences: p, now: later))
        policy.recordDelivered(next, preferences: p, now: later); XCTAssertEqual(policy.ledger.count, 1)
    }
    func testExpiredWakeRestoredFutureUnknownAndHiddenNames() {
        var p = SettingsPreferences(); p.notifications.optedIn = true; p.showProjectNames = false
        let policy = NotificationPolicy(authorization: .provisional)
        XCTAssertEqual(policy.delivery(for: notice(), preferences: p, now: now)?.projectName, nil)
        XCTAssertNotNil(policy.delivery(for: notice(), preferences: p, now: now))
        XCTAssertNil(policy.delivery(for: notice(), preferences: p, now: now.addingTimeInterval(60)))
        XCTAssertNil(policy.delivery(for: notice(restored: true), preferences: p, now: now))
        XCTAssertNil(policy.delivery(for: notice(), preferences: p, now: now.addingTimeInterval(-20)))
        XCTAssertNil(policy.delivery(for: notice(), preferences: p, now: .init(timeIntervalSince1970: .nan)))
        let unknown = SettingsNotice(kind: .reset, subscriptionID: "", episodeID: "", beganAt: now, expiresAt: now.addingTimeInterval(10))
        XCTAssertNil(policy.delivery(for: unknown, preferences: p, now: now))
        XCTAssertNil(NotificationPolicy(authorization: .unavailable).delivery(for: notice(), preferences: p, now: now))
    }
    func testOnboardingThreeStepsBackReplayAndNoProjectConsentStep() throws {
        var state = OnboardingState(definition: .provisional)
        XCTAssertEqual(OnboardingStep.allCases.count, 3); XCTAssertEqual(state.step, .welcome)
        state.back(in: .provisional); XCTAssertEqual(state.step, .welcome)
        state.demonstrateTrial(in: .provisional); XCTAssertTrue(state.trialDemonstrated)
        state.next(in: .provisional); XCTAssertEqual(state.step, .detectedSubscriptions)
        state.back(in: .provisional); XCTAssertEqual(state.step, .welcome)
        state.next(in: .provisional); state.next(in: .provisional); XCTAssertEqual(state.step, .dockLocation)
        state.recordLesson(.hold, holdAvailable: false, in: .provisional); XCTAssertNil(state.lesson)
        state.recordLesson(.quick, holdAvailable: false, in: .provisional); XCTAssertEqual(state.lesson, .quick)
        let restored = try JSONDecoder().decode(OnboardingState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(restored, state)
        state.next(in: .provisional); XCTAssertTrue(state.completed); state.back(in: .provisional); XCTAssertEqual(state.step, .dockLocation)
        state.replay(in: .provisional); XCTAssertEqual(state, OnboardingState(definition: .provisional))
        let invalid = Data("{\"step\":1,\"completed\":true,\"trialDemonstrated\":false}".utf8)
        let decoded = try JSONDecoder().decode(OnboardingState.self, from: invalid)
        XCTAssertFalse(decoded.isValid)
    }
    func testLessonQuickOnlyAndOptional800msHoldAreSeparateFromProduct() {
        var quick = TutorialGesture()
        XCTAssertTrue(quick.press(at: 0)); XCTAssertNil(quick.advance(at: 2)); XCTAssertEqual(quick.release(at: 2), .quick)
        var hold = TutorialGesture(holdAvailable: true)
        XCTAssertFalse(hold.press(at: 0, repeated: true)); XCTAssertTrue(hold.press(at: 0))
        XCTAssertFalse(hold.press(at: 0.1)); XCTAssertNil(hold.advance(at: 0.799))
        XCTAssertEqual(hold.advance(at: 0.8), .hold); XCTAssertNil(hold.release(at: 0.9))
        XCTAssertTrue(hold.press(at: 1)); XCTAssertEqual(hold.release(at: 1.1), .quick)
        XCTAssertTrue(hold.press(at: 2)); hold.cancel(); XCTAssertNil(hold.advance(at: 3)); XCTAssertNil(hold.release(at: 3))
        XCTAssertFalse(hold.press(at: .nan)); XCTAssertFalse(hold.press(at: 2))
    }
}
