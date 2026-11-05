// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanField

final class FieldProtocolTests: XCTestCase {
    func testProjectionContainsOnlyAllowlistedPublicDataAndPreservesUnknowns() throws {
        let projection = try fixture()
        let data = try JSONEncoder().encode(projection)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("sentinel"))
        XCTAssertFalse(text.contains("basis"))
        XCTAssertEqual(projection.models[0].efforts[0].cost, 0.5)
        XCTAssertNil(projection.models[0].efforts[0].time)
        XCTAssertEqual(projection.models[0].recommended, "high")
    }
    func testInvalidViewportAndFiniteScaleAreRejected() {
        for args in [(0, 500, 1.0), (2048, 4097, 1), (800, 500, Double.nan), (800, 500, 0)] {
            XCTAssertThrowsError(try FieldViewport(width: args.0, height: args.1, scale: args.2, profile: .tall))
        }
    }
}
