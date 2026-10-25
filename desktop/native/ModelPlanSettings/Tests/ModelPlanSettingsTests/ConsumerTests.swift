// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanDock
@testable import ModelPlanSettings

final class ConsumerTests: XCTestCase {
    func testF20RuntimeAccessibilityAndAppearanceWithoutMutatingPreference() {
        var p = SettingsPreferences(), e = SettingsEnvironment()
        e.darkAppearance = true; e.reduceMotion = true; e.reduceTransparency = true
        var effective = EffectiveSettings(p, environment: e)
        XCTAssertTrue(effective.darkAppearance); XCTAssertTrue(effective.reduceMotion); XCTAssertTrue(effective.reduceTransparency)
        XCTAssertEqual(effective.magnification, .none); XCTAssertEqual(effective.opening, .quick)
        e.darkAppearance = false; e.reduceMotion = false; e.reduceTransparency = false
        effective = .init(p, environment: e)
        XCTAssertFalse(effective.darkAppearance); XCTAssertFalse(effective.reduceMotion); XCTAssertFalse(effective.reduceTransparency)
        p.theme = .night; p.motion = .on; p.transparency = .on
        effective = .init(p, environment: e)
        XCTAssertTrue(effective.darkAppearance); XCTAssertTrue(effective.reduceMotion); XCTAssertTrue(effective.reduceTransparency)
        XCTAssertEqual(p.theme, .night)
    }
    func testOpeningCapabilityGateAndProductTiming() {
        var p = SettingsPreferences(), e = SettingsEnvironment(); e.macOSMajor = 26
        XCTAssertEqual(EffectiveSettings(p, environment: e).opening, .quick)
        e.entranceAccepted = true
        XCTAssertEqual(EffectiveSettings(p, environment: e).ignitionSeconds!, 0.95, accuracy: 0.0001)
        for beat in [150, 200, 250] {
            p.beatMilliseconds = beat
            XCTAssertEqual(EffectiveSettings(p, environment: e).ignitionSeconds!, 0.2 + 3 * Double(beat) / 1000, accuracy: 0.0001)
        }
        e.macOSMajor = 14; XCTAssertNil(EffectiveSettings(p, environment: e).ignitionSeconds)
        e.macOSMajor = 26; p.opening = .quick; XCTAssertNil(EffectiveSettings(p, environment: e).ignitionSeconds)
    }
    func testPreferencesDriveRealDockReducers() throws {
        var p = SettingsPreferences(), e = SettingsEnvironment()
        p.revealMilliseconds = 300
        var effective = EffectiveSettings(p, environment: e)
        var reducer = DockVisibilityState(policy: effective.visibilityPolicy), input = DockPresence()
        input.pointer = .wake
        _ = try reducer.step(effective.applying(to: input), at: 0)
        XCTAssertEqual(try reducer.step(effective.applying(to: input), at: 0.15).state, .sliver)
        XCTAssertEqual(try reducer.step(effective.applying(to: input), at: 0.3).state, .expanded)
        e.fullscreen = true; effective = .init(p, environment: e)
        XCTAssertFalse(effective.dockAllowed)
        XCTAssertEqual(try reducer.step(effective.applying(to: input), at: 0.4).state, .suppressed(.fullscreen))
        p.showOverFullscreen = true; p.autoHide = false; effective = .init(p, environment: e)
        XCTAssertEqual(try reducer.step(effective.applying(to: input), at: 0.5).state, .expanded)
        p.showDock = false; effective = .init(p, environment: e)
        XCTAssertEqual(try reducer.step(effective.applying(to: input), at: 0.6).state, .suppressed(.userHidden))
    }
    func testSharedOrderHiddenRestoreAndReconnect() throws {
        var p = SettingsPreferences()
        try p.subscriptions.move("b", to: 0, in: ["a", "b", "c"]); p.subscriptions.hiddenIDs = ["b"]
        XCTAssertEqual(try p.presentedSubscriptionIDs(["a", "b", "c"]), ["a", "c"])
        XCTAssertEqual(try p.presentedSubscriptionIDs(["a", "c"], includingHidden: true), ["a", "c"])
        XCTAssertEqual(try p.presentedSubscriptionIDs(["a", "b", "c", "d"], includingHidden: true), ["b", "a", "c", "d"])
        p.subscriptions.hiddenIDs = []; XCTAssertEqual(try p.presentedSubscriptionIDs(["a", "b", "c"]), ["b", "a", "c"])
        p.subscriptions.resetOrder(); XCTAssertEqual(try p.presentedSubscriptionIDs(["a", "b", "c"]), ["a", "b", "c"])
    }
    func testAliasCompositionAndCancellation() throws {
        var p = SettingsPreferences(); p.subscriptionSettings["a"] = .init(alias: "Original", percentagePin: .week)
        var draft = AliasDraft(subscriptionID: "a", committed: "Original")
        draft.input("工", composing: true); XCTAssertThrowsError(try draft.commit(to: &p))
        XCTAssertEqual(p.subscriptionSettings["a"]?.alias, "Original")
        // Appearance/language re-projection never modifies the independent draft.
        p.language = .english; _ = EffectiveSettings(p, environment: .init()); XCTAssertTrue(draft.composing)
        draft.input(" 工作 ", composing: false); try draft.commit(to: &p)
        XCTAssertEqual(p.subscriptionSettings["a"]?.alias, "工作"); XCTAssertEqual(p.subscriptionSettings["a"]?.percentagePin, .week)
        var cancelled = AliasDraft(subscriptionID: "a", committed: "工作"); cancelled.input("discard", composing: false)
        XCTAssertEqual(p.subscriptionSettings["a"]?.alias, "工作")
    }
    func testPinAndUsedReadoutWithoutChangingRemainingBasedThreshold() throws {
        let now = Date(timeIntervalSince1970: 1_792_530_300)
        let windows: [DockQuotaWindowInput] = [
            .init(id: "short", period: .fiveHour, label: "5h", remainingPercent: 10, resetsAt: now.addingTimeInterval(1800), durationSeconds: 18000),
            .init(id: "week", period: .week, label: "Week", remainingPercent: 60, resetsAt: now.addingTimeInterval(3600), durationSeconds: 604800),
        ]
        var input = DockInstrumentInput(id: "a", name: "Sample", windows: windows); input.dataState = .fresh
        var p = SettingsPreferences(); p.percentageMode = .used; p.subscriptionSettings["a"] = .init(alias: "Work", percentagePin: .week)
        var reading = try DockInstrumentProjection.evaluate(p.applying(to: input), now: now, redBelow: Double(p.redBelow))
        XCTAssertEqual(reading.selectedWindowID, "week"); XCTAssertEqual(reading.readout, "40%"); XCTAssertEqual(reading.alias, "Work")
        p.subscriptionSettings["a"]?.percentagePin = .auto
        reading = try DockInstrumentProjection.evaluate(p.applying(to: input), now: now, redBelow: Double(p.redBelow))
        XCTAssertEqual(reading.readout, "90%"); XCTAssertEqual(reading.status, .critical)
        p.subscriptionSettings["a"]?.percentagePin = .fiveHour
        XCTAssertEqual(p.applying(to: input).selectedWindowID, "short")
        input.windows = [windows[1]]; XCTAssertNil(p.applying(to: input).selectedWindowID)
    }
    func testShortcutPunctuationAndReservedSettingsChord() throws {
        var p = SettingsPreferences()
        p.openShortcut = .init("/", modifiers: [.command, .shift]); XCTAssertNoThrow(try p.validate())
        XCTAssertEqual(ShortcutPolicy().action(for: p.openShortcut, preferences: p, global: false), .openCockpit)
        p.openShortcut = .init(",", modifiers: [.command]); XCTAssertThrowsError(try p.validate())
    }
    func testDeniedGlobalShortcutStillWorksLocallyAndIMEIsProtected() {
        let p = SettingsPreferences(); var policy = ShortcutPolicy()
        for state in [ShortcutRegistration.notRequested, .conflict, .denied, .unavailable] {
            policy.openRegistration = state
            XCTAssertNil(policy.action(for: p.openShortcut, preferences: p, global: true))
            XCTAssertEqual(policy.action(for: p.openShortcut, preferences: p, global: false), .openCockpit)
        }
        policy.openRegistration = .registered
        XCTAssertEqual(policy.action(for: p.openShortcut, preferences: p, global: true), .openCockpit)
        XCTAssertNil(policy.action(for: p.openShortcut, preferences: p, global: false, editingText: true))
        XCTAssertNil(policy.action(for: p.openShortcut, preferences: p, global: false, composing: true))
        XCTAssertNil(policy.action(for: p.openShortcut, preferences: p, global: false, repeated: true))
        XCTAssertEqual(policy.action(for: p.dockShortcut, preferences: p, global: false), .toggleDock)
    }
}
