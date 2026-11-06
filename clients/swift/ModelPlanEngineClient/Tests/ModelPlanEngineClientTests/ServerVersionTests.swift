// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanEngineClient

final class ServerVersionTests: XCTestCase {
    func testVersionFloorFailsClosedAndComparesAllComponents() {
        for value in ["0.5.52", "0.5.53", "0.6.0", "1.0.0", "0.5.52+build.1"] {
            XCTAssertTrue(meetsMinimumServerVersion(value, minimum: "0.5.52"), value)
        }
        for value in ["", "0.5.49", "0.5.51", "0.4.999", "0.5", "0.5.52-dev", "0.5.52+", "0.5.52+a..b", "0.5.52+.", "0.5.52+a.", "00.5.52", "0.5.18446744073709551616", "unknown"] {
            XCTAssertFalse(meetsMinimumServerVersion(value, minimum: "0.5.52"), value)
        }
        XCTAssertFalse(meetsMinimumServerVersion("1.0.0", minimum: "invalid"))
    }
}
