// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanWire
@testable import ModelPlanAppIntegration

final class EngineResetCardFactsTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2027-01-01T00:00:00Z")!
    private func timestamp(_ date: Date) throws -> WireTimestamp { try WireTimestamp(ISO8601DateFormatter().string(from: date)) }
    private func cards(_ expiries: [Date?], state: RowsResetCardState = .complete, count: Int? = nil, truncated: Bool = false) throws -> RowsResetCards {
        let items = try expiries.enumerated().map { index, expiry in
            try RowsResetCardItem(id: String(repeating: index == 0 ? "a" : "b", count: 64), expiresAt: expiry.map { try timestamp($0) })
        }
        let earliest = expiries.allSatisfy { $0 != nil } ? expiries.compactMap { $0 }.min() : nil
        return try RowsResetCards(state: state, count: count ?? expiries.count, earliestExpiresAt: earliest.map { try timestamp($0) },
                                  items: items, truncated: truncated,
                                  sources: [try RowsResetCardSource(source: .codexAccount, observedAt: timestamp(now.addingTimeInterval(-60)))])
    }
    func testAbsentAndPartialNeverBecomeZero() throws {
        let absent = EngineResetCardFacts.evaluate(nil, eligible: true, now: now, english: true)
        XCTAssertNil(absent.count); XCTAssertNil(absent.countText); XCTAssertNil(absent.warning)
        let partial = EngineResetCardFacts.evaluate(try cards([now.addingTimeInterval(3600)], state: .partial), eligible: true, now: now, english: true)
        XCTAssertNil(partial.count); XCTAssertNil(partial.countText); XCTAssertNil(partial.earliestExpiry)
        XCTAssertEqual(partial.warning, true)
        let rejected = EngineResetCardFacts.evaluate(try cards([]), eligible: false, now: now, english: true)
        XCTAssertNil(rejected.count)
    }
    func testZeroOneSeveralAndExpiry() throws {
        let zero = EngineResetCardFacts.evaluate(try cards([]), eligible: true, now: now, english: true)
        XCTAssertEqual(zero.count, 0); XCTAssertEqual(zero.countText, "↺0"); XCTAssertEqual(zero.warning, false)
        let one = EngineResetCardFacts.evaluate(try cards([now.addingTimeInterval(3600)]), eligible: true, now: now, english: true)
        XCTAssertEqual(one.countText, "↺1"); XCTAssertEqual(one.warning, true)
        XCTAssertEqual(one.expiryText, "expires in 0d 1h 0m")
        let pair = try cards([now.addingTimeInterval(3600), now.addingTimeInterval(72 * 3600)])
        let several = EngineResetCardFacts.evaluate(pair, eligible: true, now: now, english: false)
        XCTAssertEqual(several.countText, "↺2"); XCTAssertEqual(several.warning, true)
        XCTAssertEqual(several.expiryText, "0天1小时0分后到期")
        XCTAssertNotNil(several.nextChange)
        let after = EngineResetCardFacts.evaluate(pair, eligible: true, now: now.addingTimeInterval(3600), english: true)
        XCTAssertEqual(after.countText, "↺1"); XCTAssertEqual(after.warning, false)
    }
    func testUnknownExpiryDoesNotBecomeAnInventedDate() throws {
        let value = EngineResetCardFacts.evaluate(try cards([nil]), eligible: true, now: now, english: true)
        XCTAssertEqual(value.count, 1); XCTAssertNil(value.earliestExpiry); XCTAssertNil(value.expiryText); XCTAssertNil(value.warning)
    }
}
