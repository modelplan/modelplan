// SPDX-License-Identifier: MIT
#if canImport(Darwin)
import XCTest
@testable import ModelPlanResources

/// macrevb-1096-3: a saved-Off launch builds the reader and must not read CPU ticks; only an admitted read does.
final class SystemResourceReaderTests: XCTestCase {
    func testConstructionReadsNoTicksAndTheFirstAdmittedReadPrimesThem() throws {
        var calls = 0
        var ticks: [[UInt32]] = [[100, 50, 850, 0], [100, 50, 850, 0]]
        let reader = SystemResourceReader(tickSource: { calls += 1; return ticks })
        XCTAssertEqual(calls, 0, "saved Off: building the reader reads no CPU ticks")
        XCTAssertEqual(reader.tickReads, 0)

        let first = try XCTUnwrap(reader.read(uptime: 0, unixMs: 0))
        XCTAssertEqual(calls, 1, "one tick read per admitted sample")
        XCTAssertEqual(first.cpuUser, 10, accuracy: 0.001, "the first read counts since boot")
        XCTAssertEqual(first.cpuSystem, 5, accuracy: 0.001)

        ticks = [[130, 60, 910, 0], [130, 60, 910, 0]]
        let second = try XCTUnwrap(reader.read(uptime: 10, unixMs: 10_000))
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(second.cpuUser, 30, accuracy: 0.001, "later reads count since the previous read")
        XCTAssertEqual(second.cpuSystem, 10, accuracy: 0.001)
    }

    /// D407: the network row's rates are bytes per second since the previous read; the first read only primes them.
    func testNetworkRatesAreBytesPerSecondSinceThePreviousRead() throws {
        var totals: (in: UInt64, out: UInt64)? = (1_000_000, 50_000)
        let reader = SystemResourceReader(tickSource: { [[1, 1, 1, 0]] }, networkSource: { totals })
        let first = try XCTUnwrap(reader.read(uptime: 100, unixMs: 0))
        XCTAssertNil(first.netIn, "no rate on the first read"); XCTAssertNil(first.netOut)
        totals = (13_000_000, 910_000)
        let second = try XCTUnwrap(reader.read(uptime: 110, unixMs: 10_000))
        XCTAssertEqual(second.netIn, 1_200_000); XCTAssertEqual(second.netOut, 86_000)
        totals = (12_000_000, 920_000)
        XCTAssertNil(try XCTUnwrap(reader.read(uptime: 120, unixMs: 20_000)).netIn, "a counter that went down gives no rate")
        totals = nil
        XCTAssertNil(try XCTUnwrap(reader.read(uptime: 130, unixMs: 30_000)).netOut, "unreadable counters give no rate")
    }

    /// macrevb-1225-5: a counter decrease (an interface went away) is a reset: no rate for that tick, and the next
    /// tick measures from the lowered totals, so the series resumes at once instead of staying blank.
    func testNetworkRatesResumeTheTickAfterACounterReset() throws {
        var totals: (in: UInt64, out: UInt64)? = (5_000_000, 500_000)
        let reader = SystemResourceReader(tickSource: { [[1, 1, 1, 0]] }, networkSource: { totals })
        _ = try XCTUnwrap(reader.read(uptime: 100, unixMs: 0))
        totals = (6_000_000, 600_000)
        XCTAssertEqual(try XCTUnwrap(reader.read(uptime: 110, unixMs: 10_000)).netIn, 100_000)
        totals = (2_000_000, 200_000)
        let reset = try XCTUnwrap(reader.read(uptime: 120, unixMs: 20_000))
        XCTAssertNil(reset.netIn); XCTAssertNil(reset.netOut)
        totals = (3_000_000, 300_000)
        let after = try XCTUnwrap(reader.read(uptime: 130, unixMs: 30_000))
        XCTAssertEqual(after.netIn, 100_000, "the tick after a reset measures from the lowered totals"); XCTAssertEqual(after.netOut, 10_000)
    }

    func testTheSystemReaderReadsNetworkTotalsWithoutAChildProcess() throws {
        let reader = SystemResourceReader()
        _ = reader.read(uptime: ProcessInfo.processInfo.systemUptime, unixMs: 0)
        let next = try XCTUnwrap(reader.read(uptime: ProcessInfo.processInfo.systemUptime + 1, unixMs: 1000))
        XCTAssertNotNil(next.netIn, "NET_RT_IFLIST2 is readable on macOS"); XCTAssertNotNil(next.netOut)
    }

    @MainActor func testSavedOffSamplerNeverReadsTicks() {
        var calls = 0
        let reader = SystemResourceReader(tickSource: { calls += 1; return [[1, 1, 1, 0]] })
        var armed = 0
        let sampler = ResourceSampler(reader: reader, clock: { 0 }, scheduler: { _, _, _ in armed += 1; return ResourceTimerHandle {} })
        sampler.setVisibility(.init(pluginEnabled: false, columnShown: false, widgetShown: true, columnSetting: 5))
        XCTAssertEqual(armed, 0, "plugin off: no timer")
        XCTAssertEqual(calls, 0, "plugin off at launch: zero tick calls")
    }
}
#endif
