// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanDock

/// Master spec §5.1 / C7 (D474): the Swift 48 h helper against the shared fixture the page helper also reads.
final class ReserveExpiryTests: XCTestCase {
    private struct Fixture: Decodable {
        struct Case: Decodable { let name: String; let expiresAt: String?; let soon: Bool }
        let hours: Double, now: String, cases: [Case]
    }
    func testSharedFixture() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../tests/shared/reserve-expiry.json").standardizedFileURL
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        XCTAssertEqual(fixture.hours, ReserveExpiry.soonHours)
        let parse = ISO8601DateFormatter()
        let now = try XCTUnwrap(parse.date(from: fixture.now))
        XCTAssertGreaterThanOrEqual(fixture.cases.count, 9)
        for c in fixture.cases {
            XCTAssertEqual(ReserveExpiry.soon(c.expiresAt.flatMap(parse.date(from:)), now: now), c.soon, c.name)
        }
    }
}
