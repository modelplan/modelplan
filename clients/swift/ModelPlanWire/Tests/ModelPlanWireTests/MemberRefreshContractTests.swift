// SPDX-License-Identifier: MIT
import Foundation
import XCTest
@testable import ModelPlanWire

final class MemberRefreshContractTests: XCTestCase {
    func testMemberRequestPreservesVerifiedIdentityAndResultsDecode() throws {
        let member = try WireRefreshMember(rowId: "codex", route: .localLog, subscriptionRef: "0123456789abcdef")
        let request = try WireRefreshRequestParams(member: member)
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]
        let target = try XCTUnwrap(encoded?["member"] as? [String: Any])
        XCTAssertEqual(target["rowId"] as? String, "codex")
        XCTAssertEqual(target["subscriptionRef"] as? String, "0123456789abcdef")
        let started = try JSONDecoder().decode(WireMemberRefreshResult.self, from: Data(#"{"outcome":"started"}"#.utf8))
        XCTAssertEqual(started.outcome, .started)
        let deferred = try JSONDecoder().decode(WireMemberRefreshResult.self, from: Data(#"{"outcome":"deferred","notBefore":"2099-01-01T00:00:00Z","reason":"floor"}"#.utf8))
        XCTAssertEqual(deferred.outcome, .deferred)
        XCTAssertEqual(deferred.reason, .floor)
        let unknown = try JSONDecoder().decode(WireMemberRefreshResult.self, from: Data(#"{"outcome":"future"}"#.utf8))
        XCTAssertFalse(unknown.outcome.isKnown)
    }
}
