// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanResources

/// D327 hover card: rows CPU · 内存 · 磁盘. The row matching the ring readout gets variant A (label and number at full ink,
/// the other rows' at secondary ink); a background tint only on problem rows (pressure high, CPU ≥ 70 %, disk ≥ 90 %).
/// An amber or red number keeps its tone on every row, emphasised or not.
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
        XCTAssertEqual(c.rows.map(\.notch), [0.7, nil, 0.9], "warning lines: CPU 70 %, disk 90 %")
        XCTAssertEqual(c.footer, "内存压力 正常 · 每 10 秒")
        XCTAssertEqual(card(sample(), key: .memory, language: .english).rows.map(\.label), ["CPU", "Memory", "Disk"])
    }

    func testVariantAFollowsTheRingReadout() {
        let normal = card(sample(), key: .memory)
        XCTAssertEqual(normal.rows.map(\.ink), [.secondary, .full, .secondary])
        XCTAssertEqual(normal.rows.map(\.tinted), [false, false, false], "emphasis never uses a background")
        let spike = card(sample(cpuUser: 71, cpuSystem: 25), key: .cpu, peak: 96)
        XCTAssertEqual(spike.rows.map(\.ink), [.full, .secondary, .secondary], "the emphasis moves with the readout")
        XCTAssertEqual(spike.rows.map(\.tinted), [true, false, false], "CPU ≥ 70 % is a problem row")
        XCTAssertEqual(spike.rows[0].tone, .critical)
        XCTAssertEqual(spike.rows[0].valueInk, .tone(.critical))
    }

    func testProblemRowsAreTintedWhetherOrNotTheyAreEmphasised() {
        let pressure = card(sample(pressure: .warn, swap: 2.1), key: .memory)
        XCTAssertEqual(pressure.rows.map(\.tinted), [false, true, false])
        XCTAssertEqual(pressure.rows[1].ink, .full)
        XCTAssertEqual(pressure.rows[1].valueInk, .tone(.warning))
        XCTAssertEqual(pressure.footer, "内存压力 偏高 · 交换 2.1 GB · 每 10 秒")
        // A full disk that is not the readout row: tinted, its label at secondary ink, its number still amber.
        let disk = card(sample(diskFree: 30), key: .memory)
        XCTAssertEqual(disk.rows[2].tinted, true)
        XCTAssertEqual(disk.rows[2].ink, .secondary)
        XCTAssertEqual(disk.rows[2].valueInk, .tone(.warning))
        // A plain value on a secondary row is at secondary ink.
        XCTAssertEqual(disk.rows[0].valueInk, .secondary)
        XCTAssertEqual(disk.rows[1].valueInk, .full)
        // 69 % CPU and 89 % disk are not problems.
        let edge = card(sample(cpuUser: 60, cpuSystem: 9, diskFree: 55), key: .memory)
        XCTAssertEqual(edge.rows.map(\.tinted), [false, false, false])
    }
}
