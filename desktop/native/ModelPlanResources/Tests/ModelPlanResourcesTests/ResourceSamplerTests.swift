// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanResources

final class ResourceHistoryAndFeedTests: XCTestCase {
    func testTenMinuteRingBufferInMemory() {
        var history = ResourceHistory()
        for t in stride(from: 0.0, through: 900, by: 2) { history.append(sample(at: t)) }
        XCTAssertEqual(history.samples.first?.uptime, 302, "only the last ten minutes are kept")
        XCTAssertEqual(history.samples.last?.uptime, 900)
        XCTAssertLessThanOrEqual(history.samples.count, ResourceHistory.capacity)
        XCTAssertEqual(history.peakCPU, 22, accuracy: 0.001)
        // An older or repeated sample (clock went backwards) is refused.
        history.append(sample(at: 899))
        XCTAssertEqual(history.samples.last?.uptime, 900)
        history.removeAll()
        XCTAssertTrue(history.samples.isEmpty)
    }

    func testPagePayloadMatchesThePagesStrictShape() throws {
        let payload = ResourcePagePayload.data([sample(at: 0, pressure: .warn, swap: 2.1)])
        let samples = try XCTUnwrap(payload["samples"] as? [[String: Any]])
        XCTAssertEqual(Set(payload.keys), ["samples"])
        // desktop/cockpit/src/resource-plugin.ts KEYS.
        XCTAssertEqual(Set(samples[0].keys), ["t", "cpuUser", "cpuSystem", "load", "memTotal", "memApp", "memWired", "memCompressed",
                                              "memCached", "memFree", "swapUsed", "pressure", "diskTotal", "diskFree"])
        XCTAssertEqual(samples[0]["pressure"] as? String, "warn")
        XCTAssertEqual(samples[0]["memTotal"] as? Int, Int(32 * GB))
        XCTAssertEqual(samples[0]["cpuUser"] as? Double, 19)
        XCTAssertTrue(JSONSerialization.isValidJSONObject(payload))
        // D407: the network rates go as a pair, only when the reader has them.
        var withNetwork = sample(at: 0); withNetwork.netIn = 1_200_000; withNetwork.netOut = 86_000
        let row = try XCTUnwrap((ResourcePagePayload.data([withNetwork])["samples"] as? [[String: Any]])?.first)
        XCTAssertEqual(row["netIn"] as? Int, 1_200_000); XCTAssertEqual(row["netOut"] as? Int, 86_000)
        XCTAssertEqual(row.count, 16)
        var half = sample(at: 0); half.netIn = 5
        XCTAssertNil((ResourcePagePayload.data([half])["samples"] as? [[String: Any]])?.first?["netIn"], "never half a pair")
    }

    func testFeedSendsTheHistoryOnStartThenOnlyNewSamples() {
        var history = ResourceHistory(), feed = ResourcePageFeed()
        for t in stride(from: 0.0, through: 598, by: 2) { history.append(sample(at: t)) }
        XCTAssertNil(feed.next(history, running: false), "nothing while the column is not running")
        let first = feed.next(history, running: true)
        XCTAssertEqual(first?.count, 300, "the whole ten minutes on start (the page takes at most \(ResourcePageFeed.maximumPerReading))")
        XCTAssertNil(feed.next(history, running: true), "nothing new")
        history.append(sample(at: 600))
        XCTAssertEqual(feed.next(history, running: true)?.map(\.uptime), [600])
        _ = feed.next(history, running: false)
        XCTAssertEqual(feed.next(history, running: true)?.count, 300, "reopened: the whole window again")
    }
}

final class ResourceSamplerTests: XCTestCase {
    @MainActor func testSamplesFeedTheHistoryAndTheFaceRedrawsOnlyOnChange() {
        let timers = ManualTimers(), reader = CountingReader()
        let sampler = ResourceSampler(reader: reader, clock: timers.clock, scheduler: timers.scheduler, reduceMotion: { true })
        var faces: [ResourceFace] = [], samples = 0
        sampler.onSample = { _ in samples += 1 }
        sampler.onRedraw = { faces.append($0) }
        sampler.setVisibility(ResourceVisibility(pluginEnabled: true, columnShown: false, widgetShown: true, columnSetting: 5))
        timers.run(until: 50)
        XCTAssertEqual(samples, 6)
        XCTAssertEqual(faces.count, 1, "the same reading six times draws once")
        XCTAssertEqual(faces.first?.animates, false, "Reduce Motion is honoured")
        XCTAssertEqual(sampler.history.samples.count, 6)
        XCTAssertEqual(sampler.face?.shown.text(.chinese), "内存 47%")
        sampler.setVisibility(ResourceVisibility(pluginEnabled: false, columnShown: false, widgetShown: true, columnSetting: 5))
        XCTAssertTrue(sampler.history.samples.isEmpty, "turning the plugin off drops the in-memory history")
        XCTAssertNil(sampler.face)
        sampler.stop()
    }

    /// Sample S18 (#1096 1096-clock-rollback): the Mac clock set back 30 minutes while the column runs at 5 s. The page
    /// orders and windows by the sample time, so the first sample after the rollback must be the newest, with the
    /// history still ordered and spaced by real elapsed time.
    @MainActor func testWallClockRollbackKeepsThePageTimeMonotonic() {
        final class WallReader: ResourceReader {
            var cpuUser: Double = 15
            func read(uptime: TimeInterval, unixMs: Int64) -> ResourceSample? {
                var s = sample(at: uptime, cpuUser: cpuUser, cpuSystem: 5); s.unixMs = unixMs; return s
            }
        }
        let timers = ManualTimers(), reader = WallReader()
        var wall: Int64 = 1_795_000_000_000
        let sampler = ResourceSampler(reader: reader, clock: timers.clock, scheduler: timers.scheduler,
                                      wallClock: { wall + Int64((timers.now * 1000).rounded()) })
        var delivered: [ResourceSample] = []
        sampler.onSample = { delivered.append($0) }
        sampler.setVisibility(ResourceVisibility(pluginEnabled: true, columnShown: true, widgetShown: false, columnSetting: 5))
        timers.run(until: 20)
        let before = delivered.count
        XCTAssertGreaterThan(before, 1)
        wall -= 30 * 60 * 1000 // the system clock moves back 30 minutes
        reader.cpuUser = 90
        timers.run(until: 40)
        let stamps = delivered.map(\.unixMs)
        XCTAssertGreaterThan(delivered.count, before)
        XCTAssertEqual(stamps, stamps.sorted(), "the page time never goes backward")
        XCTAssertEqual(Set(stamps).count, stamps.count)
        XCTAssertGreaterThan(delivered[before].unixMs, delivered[before - 1].unixMs, "the first post-rollback sample is the newest")
        XCTAssertEqual(delivered[before].unixMs - delivered[before - 1].unixMs,
                       Int64(((delivered[before].uptime - delivered[before - 1].uptime) * 1000).rounded()), "spaced by elapsed uptime")
        // The page payload carries the same order (ResourcePagePayload "t").
        let page = (ResourcePagePayload.data(delivered)["samples"] as? [[String: Any]])?.compactMap { $0["t"] as? Int } ?? []
        XCTAssertEqual(page, page.sorted())
        // Turned off and on: a fresh anchor from the wall clock as it is now.
        sampler.setVisibility(ResourceVisibility(pluginEnabled: false, columnShown: false, widgetShown: false, columnSetting: 5))
        sampler.setVisibility(ResourceVisibility(pluginEnabled: true, columnShown: true, widgetShown: false, columnSetting: 5))
        timers.run(until: 200)
        XCTAssertEqual(sampler.history.samples.first.map { $0.unixMs - Int64(($0.uptime * 1000).rounded()) }, wall)
        sampler.stop()
    }

    #if os(macOS)
    /// One real sample (host_processor_info, host_statistics64, sysctl, statfs) takes under 2 ms.
    @MainActor func testOneSystemSampleTakesUnderTwoMilliseconds() throws {
        let reader = SystemResourceReader()
        let first = try XCTUnwrap(reader.read(uptime: ProcessInfo.processInfo.systemUptime, unixMs: 1))
        XCTAssertGreaterThan(first.memTotal, 0)
        XCTAssertGreaterThan(first.diskTotal, 0)
        XCTAssertLessThanOrEqual(first.diskFree, first.diskTotal)
        XCTAssertTrue((0...100).contains(first.cpu))
        XCTAssertLessThanOrEqual(first.memoryUsed + first.memCached, first.memTotal + first.memTotal / 20)
        var times: [Double] = []
        for _ in 0..<50 {
            let start = DispatchTime.now().uptimeNanoseconds
            let next = reader.read(uptime: ProcessInfo.processInfo.systemUptime, unixMs: 2)
            times.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
            XCTAssertNotNil(next)
        }
        let median = HostedRunnerTiming.median(times)
        print(String(format: "RESOURCE-SAMPLE median=%.3f ms max=%.3f ms", median, times.max() ?? 0))
        HostedRunnerTiming.enforce("one resource sample (ms, median of 50)", measured: median, atMost: 2)
    }
    #endif
}
