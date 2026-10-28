// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCore

final class DetectionReportTests: XCTestCase {
    func testUnknownPresenceIsNotNotDetected() throws {
        let report = try parse(#"{"schemaVersion":1,"catalogueRevision":7,"tools":[{"providerId":"synthetic","detected":false,"status":"unknown","beta":true,"signals":[{"value":"ignored-extension"}]}]}"#)
        XCTAssertEqual(report.catalogueRevision, 7)
        XCTAssertEqual(report.tools.first?.detected, false)
        XCTAssertEqual(report.tools.first?.status, "unknown")
        XCTAssertEqual(report.tools.first?.beta, true)
    }

    func testMissingPresenceAndFutureStatusStayUnknownEvidence() throws {
        let report = try parse(#"{"schemaVersion":1,"tools":[{"providerId":"synthetic","status":"future-status"}]}"#)
        XCTAssertNil(report.tools.first?.detected)
        XCTAssertNil(report.tools.first?.beta)
        XCTAssertEqual(report.tools.first?.status, "future-status")
    }

    func testUnsupportedSchemaAndDuplicateIdentitiesAreRejected() {
        XCTAssertThrowsError(try parse(#"{"schemaVersion":2,"tools":[]}"#)) {
            XCTAssertEqual($0 as? FeedError, .unsupportedSchema)
        }
        XCTAssertThrowsError(try parse(#"{"schemaVersion":1,"tools":[{"providerId":"synthetic"},{"providerId":"synthetic"}]}"#)) {
            XCTAssertEqual($0 as? FeedError, .invalidIdentity)
        }
    }

    func testUnloadedOrOversizedReportIsNotAnEmptyDetectionSuccess() {
        XCTAssertThrowsError(try parse(#"{"schemaVersion":1}"#))
        XCTAssertThrowsError(try FeedDecoder.detection(Data(repeating: 32, count: FeedDecoder.maximumBytes + 1))) {
            XCTAssertEqual($0 as? FeedError, .tooLarge)
        }
    }

    private func parse(_ json: String) throws -> DetectionReport {
        try FeedDecoder.detection(Data(json.utf8))
    }
}
