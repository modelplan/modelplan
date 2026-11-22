// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanResources

/// D327 hover card: rows CPU · 内存 · 磁盘. The row matching the ring readout gets variant A (label and number at full ink,
/// the other rows' at secondary ink); a background tint only on problem rows (D371: a row whose status tone is amber or red,
/// from 80 % / 90 %, memory also by pressure). An amber or red number keeps its tone on every row, emphasised or not.
final class ResourceCardTests: XCTestCase {
    private func card(_ s: ResourceSample, key: ResourceReadoutKey, peak: Double = 61, language: ResourceLanguage = .chinese) -> ResourceCard {
        let shown = ResourceShown(key: key, percent: key == .cpu ? Int(s.cpu.rounded()) : Int(s.memoryPercent.rounded()), tone: .normal)
        return ResourceCard(sample: s, shown: shown, cpuPeak: peak, interval: 10, language: language)
    }

    func testOrderLabelsAndValues() {
        let c = card(sample(), key: .memory)
        XCTAssertEqual(c.rows.map(\.id), [.cpu, .memory, .disk])
        XCTAssertEqual(c.rows.map(\.label), ["CPU", "内存", "磁盘"])
        XCTAssertEqual(c.rows.map(\.percent), [22, 47, 76])
        XCTAssertEqual(c.rows.map(\.side), ["最高 61%", "15.1 / 32 GB", "剩 120 GB"])
        XCTAssertEqual(c.rows[1].cachedFill ?? 0, 12.8 / 32, accuracy: 0.001)
        XCTAssertEqual(c.rows.map(\.notch), [0.8, nil, 0.9], "lines: CPU at the amber 80 %, disk at the red 90 %")
        XCTAssertEqual(c.footer, "内存压力 正常", "D371 B4e: the cadence moved to the card header")
        XCTAssertEqual(c.cadence, "每 10 秒")
        XCTAssertEqual(c.screenLink, "在驾驶舱查看")
        XCTAssertEqual(card(sample(), key: .memory, language: .english).cadence, "every 10 s")
        XCTAssertEqual(card(sample(), key: .memory, language: .english).screenLink, "View in cockpit")
        XCTAssertEqual(card(sample(), key: .memory, language: .english).rows.map(\.label), ["CPU", "Memory", "Disk"])
    }

    func testVariantAFollowsTheRingReadout() {
        let normal = card(sample(), key: .memory)
        XCTAssertEqual(normal.rows.map(\.ink), [.secondary, .full, .secondary])
        XCTAssertEqual(normal.rows.map(\.tinted), [false, false, false], "emphasis never uses a background")
        let spike = card(sample(cpuUser: 71, cpuSystem: 25), key: .cpu, peak: 96)
        XCTAssertEqual(spike.rows.map(\.ink), [.full, .secondary, .secondary], "the emphasis moves with the readout")
        XCTAssertEqual(spike.rows.map(\.tinted), [true, false, false], "CPU 96 % is a problem row")
        XCTAssertEqual(spike.rows[0].tone, .critical)
        XCTAssertEqual(spike.rows[0].valueInk, .tone(.critical))
    }

    func testProblemRowsAreTintedWhetherOrNotTheyAreEmphasised() {
        let pressure = card(sample(pressure: .warn, swap: 2.1), key: .memory)
        XCTAssertEqual(pressure.rows.map(\.tinted), [false, true, false])
        XCTAssertEqual(pressure.rows[1].ink, .full)
        XCTAssertEqual(pressure.rows[1].valueInk, .tone(.warning))
        XCTAssertEqual(pressure.footer, "内存压力 偏高 · 交换 2.1 GB")
        // A full disk that is not the readout row: tinted, its label at secondary ink, its number still amber.
        let disk = card(sample(diskFree: 30), key: .memory)
        XCTAssertEqual(disk.rows[2].tinted, true)
        XCTAssertEqual(disk.rows[2].ink, .secondary)
        XCTAssertEqual(disk.rows[2].valueInk, .tone(.critical), "92 % disk is red (D371)")
        // A plain value on a secondary row is at secondary ink.
        XCTAssertEqual(disk.rows[0].valueInk, .secondary)
        XCTAssertEqual(disk.rows[1].valueInk, .full)
        // 79 % CPU and a disk just under 80 % are not problems; 80 % CPU is amber.
        let edge = card(sample(cpuUser: 60, cpuSystem: 19, diskFree: 105), key: .memory)
        XCTAssertEqual(edge.rows.map(\.tinted), [false, false, false])
        XCTAssertEqual(card(sample(cpuUser: 60, cpuSystem: 20), key: .memory).rows[0].tone, .warning)
        // The hysteresis state comes from the sampler's levels: 78 % after amber stays amber.
        let held = ResourceCard(sample: sample(cpuUser: 60, cpuSystem: 18), shown: ResourceShown(key: .memory, percent: 47, tone: .normal), cpuPeak: 80,
                                interval: 10, language: .chinese, levels: ResourceLevels(cpu: .warning, memory: .normal, disk: .normal))
        XCTAssertEqual(held.rows[0].tone, .warning)
    }
}
