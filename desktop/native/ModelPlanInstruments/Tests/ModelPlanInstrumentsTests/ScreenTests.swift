// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanInstruments

final class ScreenTests: XCTestCase {
    let now = Fixtures.now
    let calendar = Fixtures.calendar()

    func testF09WeightedRateIsRatioOfSumsWithFiveSampleFloor() {
        let a = GenerationSums(eligibleRequests: 3, eligibleOutputTokens: 600, generationMilliseconds: 10000, basis: "today")
        let b = GenerationSums(eligibleRequests: 2, eligibleOutputTokens: 200, generationMilliseconds: 1000, basis: "today")
        XCTAssertEqual(GenerationSums.weightedTPS([a, b], recording: true)!, 800.0 / 11, accuracy: 1e-10)
        XCTAssertNil(GenerationSums.weightedTPS([a], recording: true))
        XCTAssertNil(GenerationSums.weightedTPS([a, b], recording: false))
        let incompatible = GenerationSums(eligibleRequests: 5, eligibleOutputTokens: 600, generationMilliseconds: 10000, basis: "recent7d")
        XCTAssertNil(GenerationSums.weightedTPS([a, incompatible], recording: true))
        let stats = SubscriptionStatistics(today: [], recent7: [incompatible], recent30: [], recording: true)
        XCTAssertNil(stats.todayTPS); XCTAssertEqual(stats.recent7TPS, 60)
        let missing = GenerationSums(eligibleRequests: 0, eligibleOutputTokens: nil, generationMilliseconds: 0, basis: "today")
        XCTAssertNil(GenerationSums.weightedTPS([a, b, missing], recording: true))
    }

    func testF05AmbiguousSourceHistoryIsNotDuplicated() {
        let bindings = [InstrumentBinding(subscriptionID: "a", sources: ["claude"]), .init(subscriptionID: "b", sources: ["claude"])]
        XCTAssertTrue(InstrumentBinding.sources(for: "a", bindings: bindings).isEmpty)
        XCTAssertTrue(InstrumentBinding.sources(for: "b", bindings: bindings).isEmpty)
        XCTAssertEqual(InstrumentBinding.sources(for: "a", bindings: [bindings[0]]), ["claude"])
        XCTAssertTrue(InstrumentBinding.sources(for: "missing", bindings: bindings).isEmpty)
    }

    func testF09KnownZeroMissingHoursAndPartialTotals() {
        let day = calendar.startOfDay(for: now)
        let chart = UsageChart(rows: [.init(subscriptionID: "a", at: day, tokens: 0)], subscriptionIDs: ["a", "b"], range: .hours24, now: now, calendar: calendar)
        XCTAssertEqual(chart.buckets.count, 24)
        XCTAssertEqual(chart.buckets[0].perSubscription["a"]!, 0)
        XCTAssertNil(chart.buckets[0].perSubscription["b"]!)
        XCTAssertNil(chart.buckets[0].total); XCTAssertNil(chart.buckets[1].total)
        let zero = UsageChart(rows: [.init(subscriptionID: "a", at: day, tokens: 0)], subscriptionIDs: ["a"], range: .hours24, now: now, calendar: calendar)
        XCTAssertEqual(zero.buckets[0].total, 0)
        XCTAssertEqual(UsageChart(rows: [], subscriptionIDs: ["a"], range: .days7, now: now, calendar: calendar).buckets.count, 7)
        XCTAssertEqual(UsageChart(rows: [], subscriptionIDs: ["a"], range: .days30, now: now, calendar: calendar).buckets.count, 30)
    }

    func testF19SpringAndFallDaysAndRepeatedHours() {
        for (date, expected) in [("2026-03-08T21:00:00Z", 23), ("2026-11-01T21:00:00Z", 25)] {
            let chart = UsageChart(rows: [], subscriptionIDs: ["a"], range: .hours24, now: Fixtures.instant(date), calendar: calendar)
            XCTAssertEqual(chart.buckets.count, expected)
        }
        let fall = Fixtures.instant("2026-11-01T21:00:00Z")
        let first = Fixtures.instant("2026-11-01T08:00:00Z"), second = Fixtures.instant("2026-11-01T09:00:00Z")
        let chart = UsageChart(rows: [.init(subscriptionID: "a", at: first, tokens: 10), .init(subscriptionID: "a", at: second, tokens: 20)], subscriptionIDs: ["a"], range: .hours24, now: fall, calendar: calendar)
        XCTAssertEqual(calendar.component(.hour, from: first), 1); XCTAssertEqual(calendar.component(.hour, from: second), 1)
        XCTAssertEqual(chart.buckets.first { $0.start == first }?.total, 10)
        XCTAssertEqual(chart.buckets.first { $0.start == second }?.total, 20)
        let quarter = UsageChart(rows: [], subscriptionIDs: [], range: .hours24, now: now, calendar: Fixtures.calendar("Asia/Kathmandu"))
        XCTAssertEqual(quarter.buckets[0].start, Fixtures.instant("2026-10-20T18:15:00Z"))
    }

    func testF10HeatmapBoundsCoverageNoInventedCellsAndFiveSteps() {
        let today = calendar.startOfDay(for: now)
        let rows = (0..<371).map { i in
            InstrumentUsageBucket(subscriptionID: "a", at: calendar.date(byAdding: .day, value: i - 370, to: today)!, tokens: Double(i))
        }
        let heat = UsageHeatmap(rows: rows, subscriptionIDs: ["a"], coverageStart: rows.first?.at, now: now, calendar: calendar)
        XCTAssertEqual(heat.cells.count, 177) // 25 completed weeks + Monday and Tuesday
        XCTAssertEqual(heat.cells.first?.row, 0); XCTAssertEqual(heat.cells.last?.column, 25)
        XCTAssertEqual(calendar.component(.weekday, from: heat.cells.first!.day), 2)
        XCTAssertFalse(heat.shortCoverage); XCTAssertEqual(heat.cells.last?.total, 370)
        let start = calendar.date(byAdding: .day, value: -3, to: today)!
        let short = UsageHeatmap(rows: rows, subscriptionIDs: ["a"], coverageStart: start, now: now, calendar: calendar)
        XCTAssertTrue(short.shortCoverage)
        XCTAssertEqual(short.cells.filter { $0.intensity != nil }.count, 4)
        XCTAssertTrue(short.cells.filter { $0.day < start }.allSatisfy { $0.intensity == nil })
        let levels = (0..<100).map { i in InstrumentUsageBucket(subscriptionID: "a", at: calendar.date(byAdding: .day, value: -i, to: today)!, tokens: Double(i)) }
        let all = UsageHeatmap(rows: levels, subscriptionIDs: ["a"], coverageStart: levels.last?.at, now: now, calendar: calendar)
        XCTAssertEqual(Set(all.cells.compactMap(\.intensity)), Set(0...4))
    }

    func testF19HeatmapUsesCalendarDaysAcrossDST() {
        let heat = UsageHeatmap(rows: [], subscriptionIDs: ["a"], coverageStart: nil, now: Fixtures.instant("2026-11-02T21:00:00Z"), calendar: calendar)
        XCTAssertTrue(heat.cells.allSatisfy { calendar.component(.hour, from: $0.day) == 0 })
        let nov1 = heat.cells.first { calendar.component(.month, from: $0.day) == 11 && calendar.component(.day, from: $0.day) == 1 }!
        let next = calendar.date(byAdding: .day, value: 1, to: nov1.day)!
        XCTAssertEqual(next.timeIntervalSince(nov1.day), 25 * 3600)
    }

    func testF09OverviewScopeTotalsAndNoticePriority() {
        let notices = [
            InstrumentNotice(id: "info", subscriptionID: "a", severity: .information, text: "Info", expiresAt: nil),
            .init(id: "red", subscriptionID: "b", severity: .critical, text: "Critical", expiresAt: nil),
            .init(id: "old", subscriptionID: "a", severity: .critical, text: "Old", expiresAt: now),
            .init(id: "amber", subscriptionID: "a", severity: .amber, text: "Amber", expiresAt: nil),
        ]
        let all = OverviewPresentation(columns: [Fixtures.column("a", tokens: 0), Fixtures.column("b", tokens: nil)], daily: [], hourly: [], notices: notices, scope: .all, range: .days7, coverageStart: nil, now: now, calendar: calendar)
        XCTAssertEqual(all.notices.map(\.id), ["red", "amber", "info"])
        XCTAssertNil(all.todayTokens); XCTAssertNil(all.thirtyDayTokens)
        let scope = OverviewPresentation(columns: [Fixtures.column("a", tokens: 0), Fixtures.column("b", tokens: nil)], daily: [], hourly: [], notices: notices, scope: .subscription("a"), range: .hours24, coverageStart: nil, now: now, calendar: calendar)
        XCTAssertEqual(scope.todayTokens, 0); XCTAssertEqual(scope.chart.subscriptionIDs, ["a"])
        XCTAssertEqual(scope.notices.map(\.id), ["amber", "info"])
    }

    func testF08F11SubscriptionLimitsHistoryAndProvenance() {
        let cycles = (0..<12).map { InstrumentCycle(id: "\($0)", endedAt: nil, used: nil, provenance: .unknown, breakdown: []) }
        let statistics = SubscriptionStatistics(today: [], recent7: [], recent30: [], recording: true)
        let sub = SubscriptionPresentation(id: "a", windows: .init(windows: [], now: now), reserve: nil, credits: nil, statistics: statistics,
                                           cycles: cycles, peak: nil, observedAt: now.addingTimeInterval(-360), historyAttributed: true, now: now, language: .chinese)
        XCTAssertEqual(sub.cycles.map(\.id), (0..<10).map(String.init))
        XCTAssertNil(sub.cycles[0].endedAt); XCTAssertEqual(sub.cycles[0].provenance, .unknown)
        XCTAssertNil(sub.peak); XCTAssertEqual(sub.sourceAge, "6m前")
        let ambiguous = SubscriptionPresentation(id: "a", windows: sub.windows, reserve: nil, credits: nil, statistics: statistics,
                                                  cycles: cycles, peak: nil, observedAt: nil, historyAttributed: false, now: now, language: .english)
        XCTAssertTrue(ambiguous.cycles.isEmpty)
        let credits = CreditPresentation(balance: 0, drawingCredits: nil, evidence: .init(observedAt: now), now: now,
                                         historyStatus: "unavailable", historyUnavailableReason: "no-supported-local-source")
        XCTAssertEqual(credits.balance, 0); XCTAssertNil(credits.drawingCredits)
        XCTAssertEqual(credits.observedAt, now); XCTAssertEqual(credits.historyStatus, "unavailable")
    }

    func testF06F18EffortPageConsumesSharedOrderAndPublishedAvailability() {
        let models = [Fixtures.model(id: "z"), Fixtures.model(id: "old", older: true), Fixtures.model(id: "a")]
        let publication = SelectionPublication(publicationID: "p", selectionRevision: "r")
        let all = InjectedModelSelection(publication: publication, scope: .all, orderedModelIDs: ["z", "old", "a"])
        let single = InjectedModelSelection(publication: publication, scope: .subscription("s"), orderedModelIDs: ["a"])
        XCTAssertEqual(EffortPagePresentation(models: models, selection: all, scope: .all, publication: publication, publicationUsable: true).models.map(\.id), ["z", "old", "a"])
        XCTAssertEqual(EffortPagePresentation(models: models, selection: single, scope: .subscription("s"), publication: publication, publicationUsable: true).models.map(\.id), ["a"])
        XCTAssertTrue(EffortPagePresentation(models: models, selection: all, scope: .all, publication: publication, publicationUsable: false).models.isEmpty)
        XCTAssertEqual(MainScreenPage.allCases.map { $0.title(.chinese) }, ["总览", "订阅", "档位", "去向"])
    }
}
