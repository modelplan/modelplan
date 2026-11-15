// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanEngineClient

final class DeclaredCapabilityTests: XCTestCase {
    /// The server attaches `rows.Account.Today` only when the client declares `accountTodayV1`; without it the
    /// widget and cockpit today row stayed at "-- · -- t/s" in every build (build 14c bad case).
    func testHandshakeDeclaresAccountTodayV1() {
        XCTAssertTrue(ProcessEngineClient.declaredCapabilities(withCredentials: false).contains("accountTodayV1"))
        XCTAssertTrue(ProcessEngineClient.declaredCapabilities(withCredentials: true).contains("accountTodayV1"))
    }

    func testCredentialsAreDeclaredOnlyWithACredentialAgent() {
        XCTAssertFalse(ProcessEngineClient.declaredCapabilities(withCredentials: false).contains("credentials"))
        XCTAssertTrue(ProcessEngineClient.declaredCapabilities(withCredentials: true).contains("credentials"))
    }

    func testDeclaredCapabilitiesHaveNoDuplicates() {
        let list = ProcessEngineClient.declaredCapabilities(withCredentials: true)
        XCTAssertEqual(list.count, Set(list).count)
    }
}
