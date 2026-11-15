// SPDX-License-Identifier: MIT
import Foundation
import XCTest
@testable import ModelPlanShell

/// Spec 5.6: status-item preflight, the settled display re-verify and the opt-in hang watchdog, all on fake time.
@MainActor final class StatusItemRobustnessTests: XCTestCase {
    private func defaults() -> UserDefaults {
        let suite = "modelplan.status-item-placement." + UUID().uuidString
        let value = UserDefaults(suiteName: suite)!
        addTeardownBlock { value.removePersistentDomain(forName: suite) }
        return value
    }

    // MARK: preflight

    func testPreflightKeepsAbsentAndValidPositions() {
        let store = defaults(), key = StatusItemPlacement.key(autosaveName: "mp")
        XCTAssertEqual(key, "NSStatusItem Preferred Position mp")
        XCTAssertFalse(StatusItemPlacement.clearImplausiblePosition(autosaveName: "mp", defaults: store, screenWidths: [1470]))
        for valid in [400.0, 1470 + 512] {
            store.set(valid, forKey: key)
            XCTAssertFalse(StatusItemPlacement.clearImplausiblePosition(autosaveName: "mp", defaults: store, screenWidths: [1470]))
            XCTAssertEqual(store.double(forKey: key), valid, "a dragged position is never touched")
        }
    }

    func testPreflightClearsImplausiblePositionsOnly() {
        let store = defaults(), key = StatusItemPlacement.key(autosaveName: "mp")
        let values: [Any] = [-5.0, 0.0, Double.nan, Double.infinity, "left", 1470.0 + 512 + 1, 99_999.0]
        for value in values {
            store.set(value, forKey: key)
            store.set(42.0, forKey: StatusItemPlacement.key(autosaveName: "other"))
            store.set("keep", forKey: "NSStatusItem Visible mp")
            XCTAssertTrue(StatusItemPlacement.clearImplausiblePosition(autosaveName: "mp", defaults: store, screenWidths: [1470, 1200]), "\(value)")
            XCTAssertNil(store.object(forKey: key))
            XCTAssertEqual(store.double(forKey: StatusItemPlacement.key(autosaveName: "other")), 42, "another item's key stays")
            XCTAssertEqual(store.string(forKey: "NSStatusItem Visible mp"), "keep", "only the position key is removed")
        }
    }

    func testPreflightWithoutScreensAppliesOnlyTheNonPositiveRule() {
        let store = defaults(), key = StatusItemPlacement.key(autosaveName: "mp")
        store.set(99_999.0, forKey: key)
        XCTAssertFalse(StatusItemPlacement.clearImplausiblePosition(autosaveName: "mp", defaults: store, screenWidths: []))
        store.set(-1.0, forKey: key)
        XCTAssertTrue(StatusItemPlacement.clearImplausiblePosition(autosaveName: "mp", defaults: store, screenWidths: []))
    }

    // MARK: display re-verify

    private final class FakeClock {
        var now: UInt64 = 0
        var timers: [(id: Int, at: UInt64, fire: @MainActor () -> Void)] = []
        private var next = 0
        @MainActor func schedule(_ delay: UInt64, _ fire: @escaping @MainActor () -> Void) -> () -> Void {
            next += 1; let id = next
            timers.append((id, now + delay, fire))
            return { [weak self] in self?.timers.removeAll { $0.id == id } }
        }
        @MainActor func advance(to time: UInt64) {
            while let due = timers.filter({ $0.at <= time }).min(by: { $0.at < $1.at }) {
                timers.removeAll { $0.id == due.id }
                now = due.at; due.fire()
            }
            now = time
        }
    }

    func testDisplayRecheckRunsOnceAfterTheLastChangeThenOnceMore() {
        let clock = FakeClock()
        var settled = 0, followUps = 0
        let recheck = DisplayChangeRecheck(schedule: clock.schedule, settled: { settled += 1 }, followUp: { followUps += 1 })
        for step in 0..<3 { clock.advance(to: UInt64(step) * 100); recheck.displaysChanged() }
        clock.advance(to: 200 + 749)
        XCTAssertEqual(settled, 0, "nothing before 750 ms after the last change")
        clock.advance(to: 200 + 750)
        XCTAssertEqual(settled, 1); XCTAssertEqual(followUps, 0)
        clock.advance(to: 200 + 750 + 1_999)
        XCTAssertEqual(followUps, 0)
        clock.advance(to: 200 + 750 + 2_000)
        XCTAssertEqual(followUps, 1)
        clock.advance(to: 60_000)
        XCTAssertEqual(settled, 1); XCTAssertEqual(followUps, 1, "exactly one follow-up")
        XCTAssertFalse(recheck.isPending)
    }

    func testANewChangeCancelsTheSettleAndTheFollowUp() {
        let clock = FakeClock()
        var settled = 0, followUps = 0
        let recheck = DisplayChangeRecheck(schedule: clock.schedule, settled: { settled += 1 }, followUp: { followUps += 1 })
        recheck.displaysChanged()
        clock.advance(to: 700); recheck.displaysChanged()   // resets the settle
        clock.advance(to: 1_449); XCTAssertEqual(settled, 0)
        clock.advance(to: 1_450); XCTAssertEqual(settled, 1)
        clock.advance(to: 2_000); recheck.displaysChanged()  // cancels the pending follow-up
        clock.advance(to: 2_750); XCTAssertEqual(settled, 2)
        XCTAssertEqual(followUps, 0)
        recheck.cancel()                                     // terminate
        clock.advance(to: 100_000)
        XCTAssertEqual(followUps, 0); XCTAssertEqual(settled, 2)
    }

    // MARK: hang watchdog

    func testDetectorReportsAHangWithItsLabelsAndSamplesOnceWithCooldown() {
        var detector = MainThreadHangDetector()
        detector.pingSent(at: 0)
        var actions: [MainThreadHangDetector.Action] = []
        var time: UInt64 = 0
        let labels = ["renderMenu", "renderMenu", "applyLayout", "a", "b", "c", "d", "e", "f", "g"]
        for (index, label) in labels.enumerated() {
            time = UInt64(index + 1) * 25
            actions += detector.observe(now: time, answered: false, activity: label)
        }
        XCTAssertTrue(actions.isEmpty, "no report and no sample while waiting under 2 s")
        actions += detector.observe(now: 2_000, answered: false, activity: nil)
        actions += detector.observe(now: 2_100, answered: false, activity: nil)
        XCTAssertEqual(actions, [.sample], "one sample per hang")
        let end = detector.observe(now: 2_400, answered: true, activity: nil)
        XCTAssertEqual(end, [.report(durationMs: 2_400, activity: ["renderMenu", "applyLayout", "a", "b", "c", "d", "e", "f"])],
                       "labels are deduplicated and capped at 8")
        // A second long hang inside the 5-minute cooldown reports but does not sample again.
        detector.pingSent(at: 10_000)
        XCTAssertEqual(detector.observe(now: 12_500, answered: false, activity: nil), [])
        XCTAssertEqual(detector.observe(now: 12_600, answered: true, activity: nil), [.report(durationMs: 2_600, activity: [])])
        detector.pingSent(at: 400_000)
        XCTAssertEqual(detector.observe(now: 402_000, answered: false, activity: nil), [.sample], "after the cooldown it samples again")
    }

    func testDetectorIgnoresAShortWait() {
        var detector = MainThreadHangDetector()
        detector.pingSent(at: 0)
        XCTAssertEqual(detector.observe(now: 25, answered: false, activity: "x"), [])
        XCTAssertEqual(detector.observe(now: 149, answered: true, activity: nil), [])
        XCTAssertFalse(detector.waiting)
    }

    func testWatchdogIsOffInTestsAndWithoutTheSwitch() {
        let store = defaults()
        XCTAssertFalse(MainThreadHangWatchdog.isEnabled(environment: [:], defaults: store, underTest: true))
        XCTAssertFalse(MainThreadHangWatchdog.isEnabled(environment: ["MODELPLAN_MAIN_THREAD_HANG_WATCHDOG": "1"], defaults: store, underTest: true),
                       "a test process never gets the thread")
        XCTAssertFalse(MainThreadHangWatchdog.isEnabled(environment: ["MODELPLAN_MAIN_THREAD_HANG_WATCHDOG": "1", "MODELPLAN_TESTING": "1"],
                                                        defaults: store, underTest: false))
        XCTAssertTrue(MainThreadHangWatchdog.isEnabled(environment: ["MODELPLAN_MAIN_THREAD_HANG_WATCHDOG": "1"], defaults: store, underTest: false))
        store.set(true, forKey: MainThreadHangWatchdog.defaultsKey)
        XCTAssertTrue(MainThreadHangWatchdog.isEnabled(environment: [:], defaults: store, underTest: false))
        // In this (test) process start does nothing and breadcrumbs stay no-ops.
        let watchdog = MainThreadHangWatchdog()
        watchdog.startIfEnabled(environment: ["MODELPLAN_MAIN_THREAD_HANG_WATCHDOG": "1"], defaults: store)
        XCTAssertFalse(watchdog.isRunning)
        MainThreadActivityBreadcrumb.push("renderMenu")
        XCTAssertNil(MainThreadActivityBreadcrumb.current())
        MainThreadActivityBreadcrumb.pop()
    }

    func testSamplePruningKeepsTheNewestTen() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("hang-samples-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        for index in 0..<13 {
            FileManager.default.createFile(atPath: directory.appendingPathComponent(String(format: "hang-sample-2026-11-14T00-00-%02dZ.txt", index)).path, contents: nil)
        }
        FileManager.default.createFile(atPath: directory.appendingPathComponent("other.txt").path, contents: nil)
        MainThreadHangWatchdog.pruneSamples(in: directory, keep: 10)
        let left = try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
        XCTAssertEqual(left.count, 11)
        XCTAssertTrue(left.contains("other.txt"))
        XCTAssertFalse(left.contains("hang-sample-2026-11-14T00-00-02Z.txt"), "the oldest are removed")
    }
}
