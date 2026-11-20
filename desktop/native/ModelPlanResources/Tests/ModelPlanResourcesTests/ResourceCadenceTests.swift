// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanResources

/// D324 sampling cadence: cockpit visible with the column on the current page = the column setting (2 / 5 / 10 s,
/// default 5); widget shown = 10 s; neither visible = 60 s; plugin disabled = no sampling at all.
final class ResourceCadenceTests: XCTestCase {
    private func visibility(enabled: Bool = true, column: Bool = false, widget: Bool = false, setting: Int = 5) -> ResourceVisibility {
        ResourceVisibility(pluginEnabled: enabled, columnShown: column, widgetShown: widget, columnSetting: setting)
    }

    func testCadenceTable() {
        XCTAssertNil(ResourceCadence.interval(visibility(enabled: false)))
        XCTAssertNil(ResourceCadence.interval(visibility(enabled: false, column: true, widget: true)), "disabled wins over everything")
        XCTAssertEqual(ResourceCadence.interval(visibility(column: true, setting: 2)), 2)
        XCTAssertEqual(ResourceCadence.interval(visibility(column: true, setting: 5)), 5)
        XCTAssertEqual(ResourceCadence.interval(visibility(column: true, setting: 10)), 10)
        XCTAssertEqual(ResourceCadence.interval(visibility(column: true, widget: true, setting: 2)), 2, "the column's cadence wins while it is shown")
        XCTAssertEqual(ResourceCadence.interval(visibility(widget: true)), 10)
        XCTAssertEqual(ResourceCadence.interval(visibility()), 60)
        // Other saved values snap to the nearest choice; a tie takes the slower one.
        XCTAssertEqual(ResourceCadence.columnInterval(1), 2)
        XCTAssertEqual(ResourceCadence.columnInterval(3), 2)
        XCTAssertEqual(ResourceCadence.columnInterval(7), 5)
        XCTAssertEqual(ResourceCadence.columnInterval(8), 10)
        XCTAssertEqual(ResourceCadence.columnInterval(30), 10)
        XCTAssertEqual(ResourceCadence.columnInterval(-4), 2)
        // Coalescing tolerance: 10 % of the interval, never below 0.2 s.
        XCTAssertEqual(ResourceCadence.tolerance(60), 6)
        XCTAssertEqual(ResourceCadence.tolerance(2), 0.2, accuracy: 1e-9)
    }

    func testScheduleAdmitsOnlyOnCadence() {
        var schedule = ResourceSchedule()
        XCTAssertNil(schedule.update(visibility(enabled: false), now: 0))
        XCTAssertFalse(schedule.admit(now: 0), "disabled: never")
        XCTAssertEqual(schedule.update(visibility(), now: 0), 0, "first sample right away")
        XCTAssertTrue(schedule.admit(now: 0))
        XCTAssertFalse(schedule.admit(now: 30), "hidden: not before 60 s")
        XCTAssertFalse(schedule.admit(now: 59.9))
        XCTAssertTrue(schedule.admit(now: 60))
        XCTAssertEqual(schedule.update(visibility(column: true), now: 62), 3, "the column shows: next at last + 5 s")
        XCTAssertEqual(schedule.update(visibility(column: true), now: 70), 0, "overdue: right away")
        XCTAssertNil(schedule.update(visibility(enabled: false, column: true), now: 70))
        XCTAssertFalse(schedule.admit(now: 1_000))
    }

    @MainActor func testSamplerNeverSamplesWhileDisabled() {
        let timers = ManualTimers(), reader = CountingReader()
        let sampler = ResourceSampler(reader: reader, clock: timers.clock, scheduler: timers.scheduler)
        sampler.setVisibility(visibility(enabled: false, column: true, widget: true))
        timers.run(until: 3_600)
        XCTAssertEqual(reader.reads, [], "a disabled plugin is never sampled")
        XCTAssertEqual(timers.armed, 0, "and no timer is armed")
        sampler.setVisibility(visibility())
        timers.run(until: 3_725)
        XCTAssertEqual(reader.reads, [3_600, 3_660, 3_720])
        sampler.setVisibility(visibility(enabled: false))
        timers.run(until: 10_000)
        XCTAssertEqual(reader.reads.count, 3, "turned off: no further sample")
        XCTAssertEqual(timers.armed, 0)
        sampler.stop()
    }

    /// Fails if a sample happens while disabled, or less than 60 s after the previous one while nothing is visible,
    /// over random visibility changes (with late, coalesced timer firings).
    @MainActor func testNeverFasterThanSixtySecondsWhenNothingIsVisible() {
        var generator = SystemRandomNumberGenerator()
        for round in 0..<20 {
            let timers = ManualTimers(), reader = CountingReader()
            timers.lateness = Double(round % 4) * 0.1
            let sampler = ResourceSampler(reader: reader, clock: timers.clock, scheduler: timers.scheduler)
            var state = visibility(), sampledUnder: [(TimeInterval, ResourceVisibility)] = []
            sampler.onSample = { s in sampledUnder.append((s.uptime, state)) }
            sampler.setVisibility(state)
            var t: TimeInterval = 0
            for _ in 0..<60 {
                t += Double.random(in: 0.5...90, using: &generator)
                timers.run(until: t)
                state = visibility(enabled: Int.random(in: 0..<5, using: &generator) != 0, column: Bool.random(using: &generator),
                                   widget: Bool.random(using: &generator), setting: [2, 5, 10, 7][Int.random(in: 0..<4, using: &generator)])
                sampler.setVisibility(state)
            }
            timers.run(until: t + 600)
            XCTAssertEqual(reader.reads.count, sampledUnder.count)
            for (i, (time, under)) in sampledUnder.enumerated() {
                XCTAssertTrue(under.pluginEnabled, "round \(round): sampled at \(time) while disabled")
                guard i > 0 else { continue }
                let gap = time - sampledUnder[i - 1].0
                if !under.columnShown && !under.widgetShown {
                    XCTAssertGreaterThanOrEqual(gap, 60 - 1e-9, "round \(round): \(gap) s gap while nothing is visible")
                }
                if let interval = ResourceCadence.interval(under) { XCTAssertGreaterThanOrEqual(gap, interval - 1e-9, "round \(round): faster than \(interval) s") }
            }
            sampler.stop()
        }
    }

    /// A zero delay always means the next read is admitted (11-20: 511.8 + 2 - 513.8 is 0 but 513.8 - 511.8 is just
    /// under 2 in floating point; the old pair armed a zero-delay timer that admit refused, forever).
    func testZeroDelayIsAlwaysAdmitted() {
        var schedule = ResourceSchedule()
        _ = schedule.update(visibility(column: true, setting: 2), now: 511.8)
        XCTAssertTrue(schedule.admit(now: 511.8))
        let due = 511.8 + 2.0
        XCTAssertEqual(schedule.delay(now: due), 0)
        XCTAssertTrue(schedule.admit(now: due), "delay 0 must be admitted")
        XCTAssertFalse(schedule.admit(now: due + 1.9))
        XCTAssertGreaterThan(schedule.delay(now: due + 1.9) ?? 0, 0)
    }

    @MainActor func testColumnAndWidgetCadencesAndCoalescedTolerance() {
        let timers = ManualTimers(), reader = CountingReader()
        let sampler = ResourceSampler(reader: reader, clock: timers.clock, scheduler: timers.scheduler)
        sampler.setVisibility(visibility(column: true, widget: true))
        timers.run(until: 20)
        XCTAssertEqual(reader.reads, [0, 5, 10, 15, 20])
        sampler.setVisibility(visibility(column: true, widget: true, setting: 2))
        timers.run(until: 26)
        XCTAssertEqual(reader.reads.suffix(3), [22, 24, 26])
        sampler.setVisibility(visibility(widget: true))
        timers.run(until: 60)
        XCTAssertEqual(reader.reads.suffix(3), [36, 46, 56])
        XCTAssertTrue(timers.tolerances.contains(1.0), "the widget's 10 s timer carries a 1 s tolerance")
        XCTAssertTrue(timers.tolerances.allSatisfy { $0 >= 0.2 })
        XCTAssertEqual(timers.armed, 1, "one timer at a time")
        sampler.stop()
        XCTAssertEqual(timers.armed, 0)
    }
}
