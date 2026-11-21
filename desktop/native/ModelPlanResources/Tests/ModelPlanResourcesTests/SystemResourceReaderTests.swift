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
