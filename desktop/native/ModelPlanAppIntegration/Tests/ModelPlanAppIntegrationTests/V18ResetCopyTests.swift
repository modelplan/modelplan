// SPDX-License-Identifier: MIT
import XCTest
import ModelPlanDock
@testable import ModelPlanAppIntegration

final class V18ResetCopyTests: XCTestCase {
    func testV18RelativeResetCopyInBothLanguages() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let cases: [(TimeInterval, String, String)] = [
            (134 * 60, "resets in 2h 14m", "2 小时 14 分后重置"),
            (45 * 60, "resets in 45m", "45 分后重置"),
            ((3 * 24 + 5) * 3600, "resets in 3d 5h", "3 天 5 小时后重置")
        ]
        for (interval, english, chinese) in cases {
            let window = DockQuotaWindowInput(id: "synthetic", period: .fiveHour, label: "5h", remainingPercent: 50, resetsAt: now.addingTimeInterval(interval), durationSeconds: nil)
            let input = DockInstrumentInput(id: "synthetic", name: "Synthetic", windows: [window])
            let row = DockContentRow(input: input, reason: "", nextStep: "")
            XCTAssertEqual(row.resetDetails(at: now, english: true)["synthetic"], english)
            XCTAssertEqual(row.resetDetails(at: now, english: false)["synthetic"], chinese)
        }
    }
}
