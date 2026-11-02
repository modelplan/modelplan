// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanSettings

final class FirstRunLayoutMetricsTests: XCTestCase {
    func testContentWidthFitsSmallAndLargeViewports() {
        XCTAssertEqual(FirstRunLayoutMetrics.contentWidth(viewportWidth: 480), 424)
        XCTAssertEqual(FirstRunLayoutMetrics.contentWidth(viewportWidth: 626), 570)
        XCTAssertEqual(FirstRunLayoutMetrics.contentWidth(viewportWidth: 980), 570)
        XCTAssertEqual(FirstRunLayoutMetrics.contentWidth(viewportWidth: 1400), 570)
    }
    func testPathologicalWidthsNeverProduceNegativeOrNonFiniteContent() {
        for width: CGFloat in [0, 10, -1, .infinity, .nan] {
            let value = FirstRunLayoutMetrics.contentWidth(viewportWidth: width)
            XCTAssertTrue(value.isFinite); XCTAssertGreaterThanOrEqual(value, 0)
        }
    }
}
