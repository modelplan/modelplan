// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanField

final class FieldProtocolTests: XCTestCase {
    func testProjectionContainsOnlyAllowlistedPublicDataAndPreservesUnknowns() throws {
        let projection = try fixture().projection
        let data = try JSONEncoder().encode(projection)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("sentinel"))
        XCTAssertFalse(text.contains("basis"))
        XCTAssertEqual(projection.models[0].efforts[0].cost, 0.5)
        XCTAssertNil(projection.models[0].efforts[0].time)
        XCTAssertEqual(projection.models[0].recommended, "high")
    }
    func testStrictMessageVersionTypeGenerationAndUnknownFields() throws {
        let generation = UUID()
        let valid: [String: Any] = ["version":1, "generation":generation.uuidString, "type":"ready"]
        XCTAssertEqual(try FieldWebMessage.decode(JSONSerialization.data(withJSONObject: valid)).generation, generation)
        for (key, value) in [("version", 2 as Any), ("version", true as Any), ("type", "snapshot"),
                             ("generation", ""), ("project", "private"), ("requestId", UUID().uuidString)] {
            var changed = valid; changed[key] = value
            XCTAssertThrowsError(try FieldWebMessage.decode(JSONSerialization.data(withJSONObject: changed)))
        }
        XCTAssertThrowsError(try FieldWebMessage.decode(Data(repeating: 0, count: 64 * 1024 + 1)))
    }
    func testCaptureBarrierRequiresFullExactIdentityAndNoExtraNestedFields() throws {
        var state = FieldLifecycle(configuration: try fixture())
        let (generation, key) = startLive(&state, consumeCapture: false)
        let original = message(.captureResult, generation, request: key.requestId, key: key)
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try FieldWebMessage.decode(data), original)
        var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        var capture = object["captureKey"] as! [String: Any]
        capture["session"] = "private"; object["captureKey"] = capture
        XCTAssertThrowsError(try FieldWebMessage.decode(JSONSerialization.data(withJSONObject: object)))
    }
    func testInvalidViewportAndFiniteScaleAreRejected() {
        for args in [(0, 500, 1.0), (2048, 4097, 1), (800, 500, Double.nan), (800, 500, 0)] {
            XCTAssertThrowsError(try FieldViewport(width: args.0, height: args.1, scale: args.2, profile: .tall))
        }
    }
}
