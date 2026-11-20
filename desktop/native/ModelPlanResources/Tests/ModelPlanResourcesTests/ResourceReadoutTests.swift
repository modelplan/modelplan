// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanResources

/// D327 widget readout: "内存 47%" normally; "CPU 96%" once CPU has stayed ≥ 70 % for 20 s; red from 90 %; back to memory
/// after CPU has stayed below 60 % for 30 s. The memory number follows macOS memory pressure, never its percentage.
final class ResourceReadoutTests: XCTestCase {
    func testMemoryByDefaultWithBothLanguages() {
        var readout = ResourceReadout()
        let shown = readout.step(sample(at: 0))
        XCTAssertEqual(shown, ResourceShown(key: .memory, percent: 47, tone: .normal))
        XCTAssertEqual(shown.text(.chinese), "内存 47%")
        XCTAssertEqual(shown.text(.english), "Memory 47%")
    }

    func testSwitchesToCPUAfterTwentySecondsAtOrAboveSeventy() {
        var readout = ResourceReadout()
        XCTAssertEqual(readout.step(cpu(75, at: 0)).key, .memory)
        XCTAssertEqual(readout.step(cpu(75, at: 10)).key, .memory, "10 s is not enough")
        let shown = readout.step(cpu(75, at: 20))
        XCTAssertEqual(shown, ResourceShown(key: .cpu, percent: 75, tone: .warning))
        XCTAssertEqual(shown.text(.chinese), "CPU 75%")
    }

    func testADipBelowSeventyRestartsTheTwentySeconds() {
        var readout = ResourceReadout()
        for (value, t) in [(75.0, 0.0), (65, 10), (75, 20), (75, 30)] { XCTAssertEqual(readout.step(cpu(value, at: t)).key, .memory, "at \(t)") }
        XCTAssertEqual(readout.step(cpu(70, at: 40)).key, .cpu, "exactly 70 counts; 20 s since the restart at 20 s")
    }

    func testOneLateSampleSpanningTheWindowCounts() {
        // Nothing visible: samples are 60 s apart; two high samples in a row are 60 s ≥ 20 s.
        var readout = ResourceReadout()
        XCTAssertEqual(readout.step(cpu(80, at: 0)).key, .memory)
        XCTAssertEqual(readout.step(cpu(80, at: 60)).key, .cpu)
    }

    func testRedFromNinety() {
        var readout = ResourceReadout()
        _ = readout.step(cpu(96, at: 0)); _ = readout.step(cpu(96, at: 10))
        XCTAssertEqual(readout.step(cpu(96, at: 20)), ResourceShown(key: .cpu, percent: 96, tone: .critical))
        XCTAssertEqual(readout.step(cpu(89, at: 30)).tone, .warning)
        XCTAssertEqual(readout.step(cpu(90, at: 40)).tone, .critical)
    }

    func testReturnsToMemoryAfterThirtySecondsBelowSixty() {
        var readout = ResourceReadout()
        for t in stride(from: 0.0, through: 20, by: 10) { _ = readout.step(cpu(96, at: t)) }
        XCTAssertEqual(readout.key, .cpu)
        // 60–70 % neither switches back nor counts toward the return (hysteresis).
        XCTAssertEqual(readout.step(cpu(65, at: 30)).key, .cpu)
        XCTAssertEqual(readout.step(cpu(55, at: 40)).key, .cpu)
        XCTAssertEqual(readout.step(cpu(65, at: 50)).key, .cpu, "a sample at or above 60 % restarts the 30 s")
        XCTAssertEqual(readout.step(cpu(55, at: 60)).key, .cpu)
        XCTAssertEqual(readout.step(cpu(40, at: 70)).key, .cpu)
        XCTAssertEqual(readout.step(cpu(59, at: 80)).key, .cpu, "20 s below 60 %")
        let back = readout.step(cpu(30, at: 90))
        XCTAssertEqual(back.key, .memory, "30 s below 60 %")
        XCTAssertEqual(back.text(.chinese), "内存 47%")
        // And it takes another full 20 s at ≥ 70 % to switch again.
        XCTAssertEqual(readout.step(cpu(80, at: 100)).key, .memory)
        XCTAssertEqual(readout.step(cpu(80, at: 110)).key, .memory)
        XCTAssertEqual(readout.step(cpu(80, at: 120)).key, .cpu)
    }

    func testMemoryToneFollowsPressureNotPercentage() {
        var readout = ResourceReadout()
        let full = sample(at: 0, used: (20.4, 5.2, 4.6), cached: 1.2)
        XCTAssertEqual(readout.step(full), ResourceShown(key: .memory, percent: 94, tone: .normal), "94 % at normal pressure stays white")
        XCTAssertEqual(readout.step(sample(at: 10, pressure: .warn)).tone, .warning)
        XCTAssertEqual(readout.step(sample(at: 20, pressure: .critical)).tone, .critical)
    }

    func testRingFaceNeverCarriesAColour() {
        // D236/D327: the ring is always the plugin colour; only the readout has a tone.
        var readout = ResourceReadout()
        let face = ResourceFace(sample: cpu(96, at: 0, pressure: .critical), shown: readout.step(cpu(96, at: 0, pressure: .critical)), reduceMotion: false)
        XCTAssertEqual(face.memoryUsed, 15.1 / 32, accuracy: 0.001)
        XCTAssertEqual(face.memoryCached, 12.8 / 32, accuracy: 0.001)
        XCTAssertEqual(face.cpu, 0.96, accuracy: 0.001)
        XCTAssertEqual(face.shown.tone, .critical)
        XCTAssertTrue(face.animates)
        XCTAssertFalse(ResourceFace(sample: sample(), shown: readout.step(sample(at: 10)), reduceMotion: true).animates, "Reduce Motion: no ring animation")
    }

    func testRedrawOnlyOnAtLeastOnePercentChange() {
        var gate = ResourceRedrawGate()
        var readout = ResourceReadout()
        let face = { (s: ResourceSample) in ResourceFace(sample: s, shown: readout.step(s), reduceMotion: false) }
        XCTAssertTrue(gate.admit(face(sample(at: 0))), "the first face draws")
        XCTAssertFalse(gate.admit(face(sample(at: 10, cpuUser: 19.6))), "CPU +0.6 point: no redraw")
        XCTAssertFalse(gate.admit(face(sample(at: 20, cpuUser: 19.9))), "+0.9 point since the last drawn face: no redraw")
        XCTAssertTrue(gate.admit(face(sample(at: 30, cpuUser: 20.0))), "+1 point: redraw")
        XCTAssertTrue(gate.admit(face(sample(at: 40, cpuUser: 20.0, pressure: .warn))), "a tone change always redraws")
        XCTAssertFalse(gate.admit(face(sample(at: 50, cpuUser: 20.0, pressure: .warn, used: (9.25, 4.5, 1.4)))), "memory +0.16 point, readout still 47 %: no redraw")
        XCTAssertTrue(gate.admit(face(sample(at: 60, cpuUser: 20.0, pressure: .warn, used: (9.6, 4.5, 1.4)))), "memory +1.25 points: redraw")
    }
}
