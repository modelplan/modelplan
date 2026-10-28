// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCore

final class ReaderMetadataTests: XCTestCase {
    func testAbsentReaderMetadataStaysUnknown() throws {
        let source = try decode(SourceStatus.self, #"{"source":"synthetic","status":"missing"}"#)
        let account = try decode(QuotaAccount.self, #"{"source":"synthetic"}"#)
        let connection = try decode(ConnectionStatus.self, #"{"id":"synthetic"}"#)
        XCTAssertNil(source.beta)
        XCTAssertNil(account.beta)
        XCTAssertNil(account.sharedPool)
        XCTAssertNil(connection.quotaAccess)
    }

    func testReportedBetaAndQuotaAdmissionAreRetained() throws {
        let source = try decode(SourceStatus.self, #"{"source":"synthetic","status":"off","beta":true}"#)
        let account = try decode(QuotaAccount.self, #"{"source":"synthetic","beta":false,"sharedPool":{"kind":"x-subscription","status":"unverified","additive":false}}"#)
        let connection = try decode(ConnectionStatus.self, #"{"id":"synthetic","quotaAccess":{"provider":"synthetic","backend":"native","blocked":"reader-consent-or-privacy","accessClass":"saved-login","futureField":true}}"#)
        XCTAssertEqual(source.beta, true)
        XCTAssertEqual(account.beta, false)
        XCTAssertEqual(account.sharedPool?.kind, "x-subscription")
        XCTAssertEqual(account.sharedPool?.status, "unverified")
        XCTAssertEqual(account.sharedPool?.additive, false)
        XCTAssertEqual(connection.quotaAccess?.provider, "synthetic")
        XCTAssertEqual(connection.quotaAccess?.backend, "native")
        XCTAssertEqual(connection.quotaAccess?.blocked, "reader-consent-or-privacy")
        XCTAssertEqual(connection.quotaAccess?.accessClass, "saved-login")
    }

    func testUnknownAdmissionCodeIsEvidenceWithoutInventingAuthorization() throws {
        let connection = try decode(ConnectionStatus.self, #"{"id":"synthetic","quotaAccess":{"blocked":"future-code"}}"#)
        XCTAssertEqual(connection.quotaAccess?.blocked, "future-code")
        XCTAssertNil(connection.quotaAccess?.provider)
        XCTAssertNil(connection.quotaAccess?.backend)
        XCTAssertNil(connection.quotaAccess?.accessClass)
        XCTAssertNil(connection.authorization)
    }

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }
}
