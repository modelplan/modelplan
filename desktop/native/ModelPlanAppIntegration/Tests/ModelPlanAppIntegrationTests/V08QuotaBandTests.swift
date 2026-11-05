// SPDX-License-Identifier: MIT
import XCTest
import ModelPlanDock

final class V08QuotaBandTests: XCTestCase {
    func testV08RemainingQuotaBandsAtBothThresholds() throws {
        let cases: [(Double, DockQuotaStatus, DockQuotaStatus)] = [
            (100, .normal, .normal), (41, .normal, .normal),
            (40, .warning, .warning), (26, .warning, .warning),
            (25, .critical, .warning), (10, .critical, .critical), (0, .critical, .critical)
        ]
        for (remaining, threshold25, threshold10) in cases {
            let window = DockQuotaWindowInput(id: "synthetic", period: .fiveHour, label: "5h", remainingPercent: remaining, resetsAt: nil, durationSeconds: nil)
            var input = DockInstrumentInput(id: "synthetic", name: "Synthetic", windows: [window])
            input.dataState = .fresh
            for (threshold, expected) in [(25.0, threshold25), (10.0, threshold10)] {
                let reading = try DockInstrumentProjection.evaluate(input, now: Date(timeIntervalSince1970: 0), redBelow: threshold)
                XCTAssertEqual(reading.status, expected, "remaining=\(remaining), threshold=\(threshold)")
                XCTAssertEqual(reading.outer?.status, expected)
            }
        }
    }
}
