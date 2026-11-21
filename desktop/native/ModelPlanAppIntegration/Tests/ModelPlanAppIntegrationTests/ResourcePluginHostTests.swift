// SPDX-License-Identifier: MIT
import XCTest
import ModelPlanResources
import ModelPlanSettings
@testable import ModelPlanAppIntegration

/// D324 in the app: what the user sees decides the cadence (column = its setting, widget = 10 s, neither = 60 s,
/// off = none), and the page receives the samples in the shape resource-plugin.ts accepts.
@MainActor final class ResourcePluginHostTests: XCTestCase {
    private final class Reader: ResourceReader {
        var reads: [TimeInterval] = []
        func read(uptime: TimeInterval, unixMs: Int64) -> ResourceSample? {
            reads.append(uptime)
            let g: UInt64 = 1 << 30
            return ResourceSample(unixMs: 1_795_000_000_000 + Int64(uptime * 1000), uptime: uptime, cpuUser: 16.5, cpuSystem: 5.5, load: 2.4,
                                  memTotal: 32 * g, memApp: 9 * g, memWired: 4 * g, memCompressed: g, memCached: 12 * g, memFree: 6 * g,
                                  swapUsed: 0, pressure: .normal, diskTotal: 494 * g, diskFree: 120 * g)
        }
    }
    private final class Timers {
        var now: TimeInterval = 0
        var pending: [(id: Int, deadline: TimeInterval, fire: @MainActor () -> Void)] = []
        var next = 0
        @MainActor func run(until end: TimeInterval) {
            while let p = pending.min(by: { $0.deadline < $1.deadline }), p.deadline <= end {
                pending.removeAll { $0.id == p.id }; now = max(now, p.deadline); p.fire()
            }
            now = end
        }
    }
    private var timers = Timers()
    private var reader = Reader()
    private func host() -> ResourcePluginHost {
        let timers = self.timers
        let sampler = ResourceSampler(reader: reader, clock: { timers.now }, scheduler: { delay, _, fire in
            timers.next += 1; let id = timers.next
            timers.pending.append((id, timers.now + delay, fire))
            return ResourceTimerHandle { timers.pending.removeAll { $0.id == id } }
        })
        return ResourcePluginHost(sampler: sampler)
    }
    private func preferences(enabled: Bool = true, interval: Int = 5) -> CockpitPluginPreferences {
        var p = CockpitPluginPreferences()
        XCTAssertTrue(p.apply(.setEnabled("resources", enabled)))
        if interval != 5 { XCTAssertTrue(p.apply(.setSetting("resources", "intervalSeconds", interval))) }
        return p
    }
    private func gaps(since start: Int) -> [TimeInterval] {
        let r = Array(reader.reads[start...]); return zip(r.dropFirst(), r).map { $0 - $1 }
    }

    func testVisibilityTransitionsChangeTheCadence() {
        let host = host()
        host.apply(preferences())
        timers.run(until: 180)
        XCTAssertEqual(reader.reads, [0, 60, 120, 180], "nothing visible: every 60 s")
        host.setWidgetShown(true)
        var mark = reader.reads.count
        timers.run(until: 240)
        XCTAssertEqual(Set(gaps(since: mark - 1)), [10], "widget shown: every 10 s")
        host.pageRunning(["resources"])
        mark = reader.reads.count
        timers.run(until: 300)
        XCTAssertEqual(Set(gaps(since: mark - 1)), [5], "column on the shown page: the setting, 5 s")
        host.apply(preferences(interval: 2))
        mark = reader.reads.count
        timers.run(until: 320)
        XCTAssertEqual(Set(gaps(since: mark - 1)), [2], "the 2 s setting")
        host.pageRunning(["placeholder"])
        mark = reader.reads.count
        timers.run(until: 400)
        XCTAssertEqual(Set(gaps(since: mark - 1)), [10], "another plugin's column does not count: widget 10 s")
        host.setWidgetShown(false); host.pageRunning([])
        mark = reader.reads.count
        timers.run(until: 700)
        XCTAssertEqual(Set(gaps(since: mark - 1)), [60], "back to 60 s")
    }

    func testDisablingStopsSampling() {
        let host = host()
        host.apply(preferences())
        host.pageRunning(["resources"]); host.setWidgetShown(true)
        timers.run(until: 20)
        XCTAssertEqual(reader.reads, [0, 5, 10, 15, 20])
        host.apply(preferences(enabled: false))
        XCTAssertFalse(host.visibility.pluginEnabled)
        XCTAssertTrue(timers.pending.isEmpty, "no timer armed")
        timers.run(until: 3_600)
        XCTAssertEqual(reader.reads.count, 5, "off: no sample, whatever is visible")
        XCTAssertTrue(host.sampler.history.samples.isEmpty, "history dropped")
    }

    func testPageGetsTheWholeWindowWhenTheColumnStartsThenOnlyNewSamples() throws {
        let host = host()
        var sent: [(String, [String: Any])] = []
        host.sendData = { sent.append(($0, $1)) }
        host.apply(preferences()); host.setWidgetShown(true)
        timers.run(until: 30)
        XCTAssertTrue(sent.isEmpty, "no column: nothing to the page")
        host.pageRunning(["resources"])
        let first = try XCTUnwrap(sent.last)
        XCTAssertEqual(first.0, "resources")
        XCTAssertEqual(Set(first.1.keys), ["samples"])
        let samples = try XCTUnwrap(first.1["samples"] as? [[String: Any]])
        XCTAssertEqual(samples.count, 4, "the ten-minute window so far: 0, 10, 20, 30 s")
        XCTAssertEqual(Set(samples[0].keys), ["t", "cpuUser", "cpuSystem", "load", "memTotal", "memApp", "memWired", "memCompressed",
                                              "memCached", "memFree", "swapUsed", "pressure", "diskTotal", "diskFree"])
        XCTAssertEqual(samples[0]["t"] as? Int, 1_795_000_000_000)
        XCTAssertEqual(samples[0]["pressure"] as? String, "normal")
        XCTAssertTrue(JSONSerialization.isValidJSONObject(first.1))
        timers.run(until: 35)
        let next = try XCTUnwrap(sent.last?.1["samples"] as? [[String: Any]])
        XCTAssertEqual(next.count, 1, "then only the newer sample")
        XCTAssertEqual(next[0]["t"] as? Int, 1_795_000_035_000)
        let count = sent.count
        host.pageRunning([])
        timers.run(until: 100)
        XCTAssertEqual(sent.count, count, "the column stopped: nothing more is sent")
    }
}
