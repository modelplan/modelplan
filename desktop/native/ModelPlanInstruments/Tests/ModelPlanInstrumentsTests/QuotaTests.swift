// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanInstruments

final class QuotaTests: XCTestCase {
    let now = Fixtures.now

    func testF03MonthlyOnlyHasTwoBlankCellsInBothLanguages() {
        let rows = QuotaRows(windows: [Fixtures.quota("cursor", .monthly, 45)], now: now)
        XCTAssertNil(rows.fiveHours); XCTAssertNil(rows.weekly)
        XCTAssertEqual(rows.tightestOther?.period, .monthly)
        for language in [InstrumentLanguage.chinese, .english] {
            let format = InstrumentFormat(language)
            XCTAssertEqual(format.rowName(.other), language == .chinese ? "其他" : "Other")
            XCTAssertEqual(format.period(rows.tightestOther!.period), language == .chinese ? "月" : "mo")
        }
    }

    func testF03ExistingUnknownIsNotBlankOrZero() {
        let rows = QuotaRows(windows: [Fixtures.quota("five", .fiveHours, nil)], now: now)
        XCTAssertNotNil(rows.fiveHours); XCTAssertNil(rows.weekly)
        XCTAssertNil(rows.fiveHours?.remaining); XCTAssertNil(rows.fiveHours?.litSegments)
        XCTAssertEqual(InstrumentFormat(.chinese).percent(rows.fiveHours?.remaining), "--")
    }

    func testF02ThresholdsAndTenSegments() {
        for (value, level, lit) in [(0.0, QuotaLevel.critical, 0), (0.1, .critical, 1), (15, .critical, 2),
                                     (16, .amber, 2), (40, .amber, 4), (41, .healthy, 4), (100, .healthy, 10)] {
            let cell = QuotaCell(Fixtures.quota("q", .fiveHours, value), now: now)
            XCTAssertEqual(cell.level, level); XCTAssertEqual(cell.litSegments, lit)
        }
        for invalid in [-1.0, 101, .nan, .infinity] {
            XCTAssertNil(QuotaCell(Fixtures.quota("q", .weekly, invalid), now: now).remaining)
        }
    }

    func testF03OtherKeepsPeriodScopeAndStableTightestOverflow() {
        let rows = QuotaRows(windows: [Fixtures.quota("month", .monthly, 70), Fixtures.quota("5h", .fiveHours, 80),
                                      Fixtures.quota("scope", .weekly, 10, scope: "Model A"), Fixtures.quota("unknown", .daily, nil),
                                      Fixtures.quota("week", .weekly, 30), Fixtures.quota("duplicate5h", .fiveHours, 10)], now: now)
        XCTAssertEqual(rows.fiveHours?.id, "5h"); XCTAssertEqual(rows.weekly?.id, "week")
        XCTAssertEqual(rows.other.map(\.id), ["scope", "duplicate5h", "month", "unknown"])
        XCTAssertEqual(rows.tightestOther?.scope, "Model A"); XCTAssertEqual(rows.otherOverflow, 3)
    }

    func testF03PassedResetInvalidatesReadingWithoutRefill() {
        let input = InstrumentQuota(id: "q", period: .weekly, remaining: 75, resetsAt: now, durationMinutes: 10080)
        let cell = QuotaCell(input, now: now)
        XCTAssertNil(cell.remaining); XCTAssertNil(cell.resetsAt); XCTAssertEqual(cell.timeDots, 0)
        let stale = InstrumentQuota(id: "q", period: .weekly, remaining: 75, resetsAt: now.addingTimeInterval(600), readable: false)
        XCTAssertNil(QuotaCell(stale, now: now).remaining); XCTAssertNil(QuotaCell(stale, now: now).timeFraction)
    }

    func testF03TimeDotsUseExactDurationNotQuotaOrNominalMonth() {
        let unknown = InstrumentQuota(id: "q", period: .monthly, remaining: 10, resetsAt: now.addingTimeInterval(600))
        XCTAssertNil(QuotaCell(unknown, now: now).timeDots)
        let known = InstrumentQuota(id: "q", period: .monthly, remaining: 10, resetsAt: now.addingTimeInterval(600), durationMinutes: 20)
        XCTAssertEqual(QuotaCell(known, now: now).timeDots, 5)
    }

    func testF04PagingRetainsOrderAndOffPageCaution() {
        for count in [0, 1, 2, 4, 6, 7, 10, 13] {
            let columns = (0..<count).map { Fixtures.column("s\($0)", caution: $0 == count - 1 ? .critical : .unknown) }
            let page = EnginePage(columns: columns, page: 999)
            XCTAssertEqual(page.pageCount, max(1, (count + 5) / 6))
            XCTAssertEqual(page.columns.compactMap { $0?.id }, Array(columns.suffix(count == 0 ? 0 : (count - 1) % 6 + 1)).map(\.id))
            if count > 0 { XCTAssertEqual(page.pageCautions.last, .critical) }
            if count == 1 || count == 2 { XCTAssertEqual(page.columns.count, 3) }
        }
        let first = EnginePage(columns: (0..<13).map { Fixtures.column("s\($0)", caution: $0 == 12 ? .critical : .unknown) }, page: 0)
        XCTAssertEqual(first.pageCautions, [.unknown, .unknown, .critical])
    }

    func testF08ReserveCountsExpiryOverflowCreditsAndFortyEightHourBoundary() {
        for count in [0, 1, 2, 6] {
            let allowances = (0..<count).map { ResetAllowance(count: 1, expiresAt: now.addingTimeInterval(Double(30 + $0) * 3600)) }
            let reserve = ReservePresentation(allowances: allowances, credits: 0, drawingCredits: true, now: now)
            XCTAssertEqual(reserve.resets, count); XCTAssertEqual(reserve.compactExpiries.count, min(4, count))
            XCTAssertEqual(reserve.expiryOverflow, max(0, count - 4)); XCTAssertEqual(reserve.credits, 0)
            XCTAssertEqual(reserve.expiryWarning, count > 0)
        }
        let at48 = ReservePresentation(allowances: [.init(count: 2, expiresAt: now.addingTimeInterval(48 * 3600))], credits: nil, drawingCredits: false, now: now)
        XCTAssertTrue(at48.expiryWarning); XCTAssertEqual(at48.resets, 2)
        XCTAssertNil(ReservePresentation(allowances: nil, credits: nil, drawingCredits: false, now: now).resets)
        XCTAssertNil(ReservePresentation(allowances: [.init(count: nil, expiresAt: nil)], credits: nil, drawingCredits: false, now: now).resets)
        let expired = ReservePresentation(allowances: [.init(count: 1, expiresAt: now)], credits: nil, drawingCredits: false, now: now)
        XCTAssertEqual(expired.resets, 0); XCTAssertFalse(expired.expiryWarning)
    }

    func testRelativeTimeAndGlossary() {
        let zh = InstrumentFormat(.chinese), en = InstrumentFormat(.english), date = now.addingTimeInterval(3 * 3600 + 18 * 60)
        XCTAssertEqual(zh.future(date, now: now), "3 小时 18 分后")
        XCTAssertEqual(en.future(date, now: now), "in 3h 18m")
        XCTAssertEqual(zh.reset(date, now: now), "3 小时 18 分后重置")
        XCTAssertEqual(zh.future(date, now: now, compact: true), "3h18")
        XCTAssertEqual(en.resets(count: 1, nearestExpiry: nil, now: now), "1 reset")
        XCTAssertEqual(en.resets(count: 2, nearestExpiry: now.addingTimeInterval(30 * 3600), now: now), "2 resets · expire in 1d 6h")
        XCTAssertEqual(zh.age(now.addingTimeInterval(-360), now: now), "6m前")
        XCTAssertEqual(en.age(now.addingTimeInterval(1), now: now), "--")
        XCTAssertEqual(en.duration(minutes: 59.9), "1h00")
        XCTAssertEqual(en.duration(minutes: 1439.9), "1d0h")
        XCTAssertEqual(en.duration(minutes: nil), "--")
    }
}
