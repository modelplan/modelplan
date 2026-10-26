// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanDock
@testable import ModelPlanSettings

final class B20ConsumerRegressionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func input(remaining: Double) -> DockInstrumentInput {
        var result = DockInstrumentInput(id: "sample", name: "Sample", windows: [
            .init(id: "short", period: .fiveHour, label: "5h", remainingPercent: remaining,
                  resetsAt: now.addingTimeInterval(1_800), durationSeconds: 18_000),
            .init(id: "weekly", period: .week, label: "Week", remainingPercent: 60,
                  resetsAt: now.addingTimeInterval(86_400), durationSeconds: 604_800),
        ])
        result.dataState = .fresh
        return result
    }

    func testRestartKeepsHiddenUsedReadoutAndRemainingBasedThresholdBoundary() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("modelplan-b20-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("preferences.json")
        let store = try SettingsStore(url: url)
        try await store.update {
            $0.percentageMode = .used
            $0.showPercentages = false
            $0.redBelow = 20
            $0.sliverAlert = false
            $0.subscriptionSettings["sample"] = .init(percentagePin: .fiveHour)
        }

        let restoredStore = try SettingsStore(url: url)
        let restored = await restoredStore.snapshot().preferences
        let effective = EffectiveSettings(restored, environment: .init())
        XCTAssertFalse(effective.showPercentages)
        XCTAssertFalse(effective.sliverAlert)
        XCTAssertEqual(SettingsDiagrams.inputs(restored, orderedIDs: ["sample"])[1],
                       .percentages(shown: false, eventDot: true))

        // Hiding numbers and choosing used quota must not invert or disable critical status.
        for (remaining, expectedText, expectedStatus) in [
            (19.0, "81%", DockQuotaStatus.critical),
            (20.0, "80%", .warning),
            (21.0, "79%", .warning),
        ] {
            let reading = try DockInstrumentProjection.evaluate(
                restored.applying(to: input(remaining: remaining)), now: now,
                redBelow: Double(effective.redBelow))
            XCTAssertEqual(reading.readout, expectedText)
            XCTAssertEqual(reading.status, expectedStatus)
            XCTAssertEqual(reading.selectedWindowID, "short")
        }
    }

    func testMissingPinnedPeriodFallsBackWithoutErasingPinThenReconnects() throws {
        var preferences = SettingsPreferences()
        preferences.percentageMode = .used
        preferences.subscriptionSettings["sample"] = .init(percentagePin: .week)
        let connected = input(remaining: 9)
        var disconnected = connected
        disconnected.windows.removeAll { $0.id == "weekly" }

        for (source, expectedID, expectedText, expectedStatus) in [
            (connected, "weekly", "40%", DockQuotaStatus.normal),
            (disconnected, "short", "91%", .critical),
            (connected, "weekly", "40%", .normal),
        ] {
            let reading = try DockInstrumentProjection.evaluate(preferences.applying(to: source), now: now)
            XCTAssertEqual(reading.selectedWindowID, expectedID)
            XCTAssertEqual(reading.readout, expectedText)
            XCTAssertEqual(reading.status, expectedStatus)
            XCTAssertEqual(preferences.subscriptionSettings["sample"]?.percentagePin, .week)
        }
        // A last-edited subscription disappearing must not leave its preview on another account's pin.
        preferences.subscriptionSettings["other"] = .init(percentagePin: .fiveHour)
        XCTAssertEqual(SettingsDiagrams.inputs(preferences, orderedIDs: ["other"],
                                              lastChangedSubscriptionID: "sample").last,
                       .quotaWindow(subscriptionID: "other", pin: .fiveHour))
    }

    func testRuntimeAccessibilityChangeEndsPlaybackAndPreservesForcedAppearanceChoices() throws {
        var preferences = SettingsPreferences()
        preferences.theme = .day
        preferences.size = .large
        preferences.transparency = .on
        var environment = SettingsEnvironment()
        environment.darkAppearance = true
        var playback = SettingsDiagramPlayback()
        try playback.trigger(at: 10, reduceMotion: false)
        XCTAssertEqual(try playback.progress(at: 10.1), 0.25, accuracy: 1e-9)

        environment.reduceMotion = true
        let reduced = EffectiveSettings(preferences, environment: environment)
        XCTAssertTrue(reduced.reduceMotion)
        playback.reduceMotionNow()
        XCTAssertEqual(try playback.progress(at: 10.1), 1)
        XCTAssertNil(playback.endsAt)
        XCTAssertFalse(reduced.darkAppearance)
        XCTAssertTrue(reduced.reduceTransparency)
        XCTAssertEqual(reduced.size, .large)

        environment.reduceMotion = false
        let resumed = EffectiveSettings(preferences, environment: environment)
        XCTAssertFalse(resumed.reduceMotion)
        XCTAssertTrue(resumed.reduceTransparency)
        XCTAssertEqual(resumed.size, .large)
        // Turning off the OS preference must not replay a completed illustration automatically.
        XCTAssertEqual(try playback.progress(at: 11), 1)
        XCTAssertNil(playback.startedAt)
        XCTAssertEqual(preferences.theme, .day)
        XCTAssertEqual(preferences.motion, .system)
        try playback.trigger(at: 12, reduceMotion: resumed.reduceMotion)
        XCTAssertEqual(try playback.progress(at: 12), 0)
        XCTAssertEqual(try playback.progress(at: 12.4), 1, accuracy: 1e-9)
    }
}
