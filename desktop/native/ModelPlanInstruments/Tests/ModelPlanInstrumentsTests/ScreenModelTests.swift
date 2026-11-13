// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanInstruments

final class ScreenModelTests: XCTestCase {
    let now = Fixtures.now
    let calendar = Fixtures.calendar()

    func testEvidenceVerdictsAndDeadlinesNeverInventFreshness() {
        XCTAssertTrue(InstrumentEvidence().usable(at: now)) // Already-validated adapter input.
        for state in [InstrumentFreshness.stale, .unknown, .unavailable] {
            XCTAssertFalse(InstrumentEvidence(freshness: state).usable(at: now))
        }
        XCTAssertFalse(InstrumentEvidence(validUntil: now).usable(at: now))
        XCTAssertFalse(InstrumentEvidence(observedAt: now.addingTimeInterval(1)).usable(at: now))
        XCTAssertTrue(InstrumentEvidence(observedAt: now, validUntil: now.addingTimeInterval(1)).usable(at: now))
    }

    func testStackAndSplitShareOrderedStableIDsAndKeepUnknownSegments() {
        let day = calendar.startOfDay(for: now)
        let rows = [InstrumentUsageBucket(subscriptionID: "b", at: day, tokens: 0), .init(subscriptionID: "a", at: day, tokens: 20)]
        for mode in [UsageChartMode.stacked, .split] {
            let chart = UsageChart(rows: rows, subscriptionIDs: ["b", "a", "missing", "b"], range: .days7, now: now, calendar: calendar, mode: mode)
            let bucket = chart.buckets.last!
            XCTAssertEqual(chart.subscriptionIDs, ["b", "a", "missing"])
            XCTAssertEqual(bucket.segments.map(\.subscriptionID), chart.subscriptionIDs)
            XCTAssertEqual(bucket.segments.map(\.tokens), [0, 20, nil])
            XCTAssertNil(bucket.total); XCTAssertEqual(bucket.recordedTotal, 20); XCTAssertTrue(bucket.partial)
        }
    }

    func testUsageRetainsEvidenceWithoutTreatingCurrentBindingAsHistoricalOwnership() {
        let day = calendar.startOfDay(for: now), evidence = InstrumentEvidence(source: "shared", observedAt: now)
        let row = InstrumentUsageBucket(subscriptionID: "a", at: day, tokens: 42,
                                        attribution: .sourceWideCurrentBinding, evidence: evidence, timeBasis: .turnStartLocalDay)
        let chart = UsageChart(rows: [row], subscriptionIDs: ["a"], range: .days7, now: now, calendar: calendar)
        XCTAssertNil(chart.buckets.last?.total)
        let fact = chart.buckets.last?.evidenceBySubscription["a"]?.first
        XCTAssertEqual(fact?.attribution, .sourceWideCurrentBinding)
        XCTAssertEqual(fact?.evidence.source, "shared"); XCTAssertEqual(fact?.tokens, 42)
        XCTAssertEqual(InstrumentBinding.sources(for: "a", bindings: [.init(subscriptionID: "a", sources: ["shared"])]), ["shared"])
        // That current link did not turn the source-wide 42 into account usage.
        XCTAssertNil(chart.buckets.last?.perSubscription["a"]!)
    }

    func testWrongTimeBasisAndExpiredUsageStayUnknown() {
        let day = calendar.startOfDay(for: now)
        let daily = InstrumentUsageBucket(subscriptionID: "a", at: day, tokens: 25, timeBasis: .turnStartLocalDay)
        XCTAssertNil(UsageChart(rows: [daily], subscriptionIDs: ["a"], range: .hours24, now: now, calendar: calendar).buckets.first?.total)
        let hourly = InstrumentUsageBucket(subscriptionID: "a", at: day, tokens: 25, timeBasis: .completionHour)
        XCTAssertNil(UsageChart(rows: [hourly], subscriptionIDs: ["a"], range: .days7, now: now, calendar: calendar).buckets.last?.total)
        let old = InstrumentUsageBucket(subscriptionID: "a", at: day, tokens: 25, evidence: .init(validUntil: now))
        XCTAssertNil(UsageChart(rows: [old], subscriptionIDs: ["a"], range: .days7, now: now, calendar: calendar).buckets.last?.total)
    }

    func testAllSourceTotalsCountOnceAndNeverBecomeTwoSubscriptions() {
        let source = SourceTokenTotal(source: "shared", tokens: 100, evidence: .init(source: "shared", observedAt: now))
        let month = SourceTokenTotal(source: "shared", tokens: 900, evidence: .init(source: "shared"), period: .days30)
        let columns = [Fixtures.column("a", tokens: nil), Fixtures.column("b", tokens: nil)]
        let all = OverviewPresentation(columns: columns, daily: [], hourly: [], notices: [], scope: .all,
                                       range: .days7, coverageStart: nil, now: now, calendar: calendar,
                                       reportedTodaySources: [source], reportedThirtyDaySources: [month])
        XCTAssertEqual(all.todayTokens, 100); XCTAssertEqual(all.thirtyDayTokens, 900)
        XCTAssertNil(all.chart.buckets.last?.total)
        let single = OverviewPresentation(columns: columns, daily: [], hourly: [], notices: [], scope: .subscription("a"),
                                          range: .days7, coverageStart: nil, now: now, calendar: calendar,
                                          reportedTodaySources: [source], reportedThirtyDaySources: [month])
        XCTAssertNil(single.todayTokens); XCTAssertNil(single.thirtyDayTokens); XCTAssertNil(single.reportedTodaySources)
        XCTAssertNil(SourceTokenTotal.total([source, source], now: now))
        XCTAssertNil(SourceTokenTotal.total([month], now: now))
        XCTAssertNil(SourceTokenTotal.total([], now: now))
        let partial = SourceTokenTotal(source: "s", tokens: 0, evidence: .init(), period: .days30, coverageStart: now, coverageComplete: false)
        XCTAssertEqual(partial.coverageComplete, false); XCTAssertEqual(partial.coverageStart, now)
        XCTAssertNil(source.coverageComplete)
    }

    func testOverviewFiltersExpiredAndStaleNoticesWithStableSeverityTies() {
        let notices: [InstrumentNotice] = [
            .init(id: "amber1", subscriptionID: "a", severity: .amber, text: "First", expiresAt: nil),
            .init(id: "blue", subscriptionID: "a", severity: .information, text: "Info", expiresAt: nil),
            .init(id: "expired", subscriptionID: "a", severity: .critical, text: "Old", expiresAt: now),
            .init(id: "stale", subscriptionID: "a", severity: .critical, text: "Stale", expiresAt: nil, evidence: .init(freshness: .stale)),
            .init(id: "amber2", subscriptionID: "a", severity: .amber, text: "Second", expiresAt: now.addingTimeInterval(1)),
        ]
        let staleColumn = EngineColumn(id: "a", quotas: .init(windows: [], now: now), todayTokens: 9, todayGenerationTPS: nil,
                                       evidence: .init(freshness: .stale))
        let page = OverviewPresentation(columns: [staleColumn], daily: [], hourly: [], notices: notices, scope: .all,
                                        range: .days7, coverageStart: nil, now: now, calendar: calendar)
        XCTAssertEqual(page.notices.map(\.id), ["amber1", "amber2", "blue"]); XCTAssertNil(page.todayTokens)
    }

    func testHeatmapRetains371DaysAndExposes182SlotsWithoutFutureData() {
        let today = calendar.startOfDay(for: now)
        let rows = (0..<400).map { i in
            InstrumentUsageBucket(subscriptionID: "a", at: calendar.date(byAdding: .day, value: -i, to: today)!, tokens: Double(i))
        }
        let map = UsageHeatmap(rows: rows, subscriptionIDs: ["a"], coverageStart: rows.last?.at, now: now, calendar: calendar)
        XCTAssertEqual(map.retainedRows.count, 371); XCTAssertEqual(map.grid.count, 182)
        XCTAssertEqual(map.grid.compactMap { $0 }.count, map.cells.count)
        XCTAssertTrue(map.cells.allSatisfy { $0.day <= now && $0.column < 26 && $0.row < 7 })
        XCTAssertEqual(Set(map.cells.compactMap(\.intensity)), Set(0...4))
        XCTAssertNil(map.coverageDescription(language: .chinese, calendar: calendar))
    }

    func testHeatmapPerSubscriptionCoverageAndPartialTooltipFacts() {
        let today = calendar.startOfDay(for: now), yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))!
        let rows = [InstrumentUsageBucket(subscriptionID: "a", at: yesterday, tokens: 10), .init(subscriptionID: "b", at: yesterday, tokens: 500),
                    .init(subscriptionID: "a", at: today, tokens: 0), .init(subscriptionID: "b", at: today, tokens: 20)]
        let map = UsageHeatmap(rows: rows, subscriptionIDs: ["a", "b"], coverageStart: nil, now: now, calendar: calendar,
                              coverageBySubscription: ["a": yesterday, "b": today])
        let previous = map.cells.first { $0.day == yesterday }!
        XCTAssertEqual(previous.total, 10); XCTAssertNil(previous.completeTotal); XCTAssertTrue(previous.partial)
        XCTAssertEqual(previous.perSubscription["a"]!, 10); XCTAssertNil(previous.perSubscription["b"]!)
        XCTAssertEqual(map.cells.last?.completeTotal, 20)
        XCTAssertEqual(map.coverageStart, yesterday); XCTAssertTrue(map.shortCoverage)
        XCTAssertEqual(map.coverageDescription(language: .english, calendar: calendar), "Recorded since 2026-10-19")
        let unknown = UsageHeatmap(rows: [], subscriptionIDs: ["a", "b"], coverageStart: nil, now: now, calendar: calendar,
                                  coverageBySubscription: ["a": yesterday])
        XCTAssertNil(unknown.coverageStart); XCTAssertNil(unknown.coverageDescription(language: .english, calendar: calendar))
        let future = UsageHeatmap(rows: rows, subscriptionIDs: ["a"], coverageStart: now.addingTimeInterval(86400), now: now, calendar: calendar)
        XCTAssertNil(future.coverageStart); XCTAssertNil(future.coverageDescription(language: .english, calendar: calendar))
    }

    func testDSTOffsetHoursKeepDistinctFactsAndFutureBucketsAreUnknown() {
        let time = Fixtures.instant("2026-11-01T09:30:00Z")
        let a = Fixtures.instant("2026-11-01T08:00:00Z"), b = Fixtures.instant("2026-11-01T09:00:00Z")
        let rows = [InstrumentUsageBucket(subscriptionID: "a", at: a, tokens: 10, timeBasis: .completionHour),
                    .init(subscriptionID: "a", at: b, tokens: 0, timeBasis: .completionHour)]
        let chart = UsageChart(rows: rows, subscriptionIDs: ["a"], range: .hours24, now: time, calendar: calendar)
        XCTAssertEqual(chart.buckets.count, 25)
        XCTAssertEqual(chart.buckets.first { $0.start == a }?.total, 10)
        XCTAssertEqual(chart.buckets.first { $0.start == b }?.total, 0)
        XCTAssertTrue(chart.buckets.filter { $0.start > time }.allSatisfy { $0.total == nil })
    }

    func testCreditsOnlyBalanceReadTimeAndReportedDrawingState() {
        for balance in [nil, 0, 200] as [Double?] {
            let credits = CreditPresentation(balance: balance, drawingCredits: nil, evidence: .init(source: "s", observedAt: now), now: now,
                                             historyStatus: "unavailable", historyUnavailableReason: "no-supported-local-source")
            XCTAssertEqual(credits.balance, balance); XCTAssertEqual(credits.observedAt, now)
            XCTAssertNil(credits.drawingCredits); XCTAssertEqual(credits.historyStatus, "unavailable")
            XCTAssertEqual(credits.historyUnavailableReason, "no-supported-local-source")
        }
        for drawing in [false, true] {
            XCTAssertEqual(CreditPresentation(balance: 0, drawingCredits: drawing, evidence: .init(), now: now).drawingCredits, drawing)
        }
        let expired = CreditPresentation(balance: 50, drawingCredits: true, evidence: .init(validUntil: now), now: now)
        XCTAssertNil(expired.balance); XCTAssertNil(expired.drawingCredits)
    }

    func testReserveFullEntriesAndExactExpiryBoundaries() {
        for count in [0, 1, 2, 6] {
            let entries = (0..<count).map { ResetAllowance(count: 1, expiresAt: now.addingTimeInterval(Double($0 + 30) * 3600), kind: "reset", source: "reported") }
            let reserve = ReservePresentation(allowances: entries, credits: nil, drawingCredits: false, now: now)
            XCTAssertEqual(reserve.resets, count); XCTAssertEqual(reserve.allowances?.count, count)
            XCTAssertEqual(reserve.expiryOverflow, max(0, count - 4))
        }
        func reserve(_ seconds: Double) -> ReservePresentation {
            .init(allowances: [.init(count: 1, expiresAt: now.addingTimeInterval(seconds))], credits: nil, drawingCredits: false, now: now)
        }
        XCTAssertFalse(reserve(0).expiryWarning); XCTAssertEqual(reserve(0).resets, 0)
        XCTAssertTrue(reserve(48 * 3600).expiryWarning); XCTAssertFalse(reserve(48 * 3600 + 1).expiryWarning)
        let stale = ReservePresentation(allowances: [.init(count: 6, expiresAt: nil, evidence: .init(freshness: .stale))], credits: nil, drawingCredits: false, now: now)
        XCTAssertNil(stale.resets)
    }

    func testHistoryProvenanceAndDropDoNotInventRedemptionOrTimestamp() {
        let drop = InstrumentCycle(id: "drop", endedAt: nil, used: 10, provenance: .unknown, breakdown: [], hadDrop: true)
        XCTAssertEqual(drop.provenance, .unknown); XCTAssertNil(drop.endedAt); XCTAssertTrue(drop.hadDrop!)
        let origins: [ResetProvenance] = [.natural, .publicAnnouncement, .confirmedAwaitingReading, .resetAllowance, .correction, .unknown]
        let cycles = origins.enumerated().map { InstrumentCycle(id: "\($0.offset)", endedAt: nil, used: 0, provenance: $0.element, breakdown: [], hadDrop: false) }
        XCTAssertEqual(cycles.map(\.provenance), origins)
        let page = subscription(cycles: [drop] + cycles)
        XCTAssertEqual(page.cycles.first?.hadDrop, true); XCTAssertNil(page.cycles.first?.endedAt)
        XCTAssertEqual(page.cycles.first?.provenance, .unknown)
    }

    func testSubscriptionHeaderUsageAndHistoryAreNotTokenQuotaEstimates() {
        let header = SubscriptionHeader(name: "Synthetic plan", plan: "Tier", glyphID: nil, evidence: .init(source: "reported", observedAt: now.addingTimeInterval(-360)))
        let detail = UsageTokenDetail(input: 20, output: 100, cacheRead: 80, cacheWrite: 1000)
        let page = subscription(header: header, detail: detail)
        XCTAssertEqual(page.header?.name, "Synthetic plan"); XCTAssertEqual(page.sourceAge, "6m前")
        XCTAssertEqual(page.usageDetail?.cacheHitRatio, 0.8)
        XCTAssertNil(page.windows.fiveHours); XCTAssertTrue(page.windows.other.isEmpty)
        XCTAssertNil(UsageTokenDetail(input: nil, output: 100, cacheRead: 80, cacheWrite: 1).cacheHitRatio)
        XCTAssertNil(UsageTokenDetail(input: 0, output: 0, cacheRead: 0, cacheWrite: 1).cacheHitRatio)
    }

    func testUnattributedHistoryIsSourceWideAndSubscriptionNumbersAreWithheld() {
        let sums = GenerationSums(eligibleRequests: 5, eligibleOutputTokens: 100, generationMilliseconds: 2000, basis: "reported")
        let stats = SubscriptionStatistics(today: [sums], recent7: [sums], recent30: [sums], recording: true)
        let page = subscription(attributed: false, statistics: stats)
        XCTAssertNil(page.statistics.todayTPS); XCTAssertNil(page.statistics.recent7TPS)
        XCTAssertEqual(page.sourceWideStatistics?.todayTPS, 50)
        XCTAssertTrue(page.cycles.isEmpty); XCTAssertNil(page.peak); XCTAssertNil(page.usageDetail)
    }

    func testTenCycleRetentionWithUnknownDatesAndSuppliedPeakOnly() {
        let cycles = (0..<15).map { InstrumentCycle(id: "\($0)", endedAt: nil, used: Double($0), provenance: .unknown, breakdown: []) }
        let page = subscription(cycles: cycles)
        XCTAssertEqual(page.cycles.map(\.id), (0..<10).map(String.init)); XCTAssertNil(page.peak)
        let supplied = PeakBand(from: now, until: now.addingTimeInterval(3600))!
        XCTAssertEqual(subscription(peak: supplied).peak?.until, supplied.until)
        let expiredEvidence = InstrumentCycle(id: "stale", endedAt: now, used: 100, provenance: .unknown, breakdown: [], evidence: .init(freshness: .stale))
        XCTAssertTrue(subscription(cycles: [expiredEvidence]).cycles.isEmpty)
    }

    private func subscription(attributed: Bool = true, cycles: [InstrumentCycle] = [], header: SubscriptionHeader? = nil,
                              detail: UsageTokenDetail? = nil, peak: PeakBand? = nil, statistics: SubscriptionStatistics? = nil) -> SubscriptionPresentation {
        .init(id: "a", windows: .init(windows: [], now: now), reserve: nil, credits: nil,
              statistics: statistics ?? .unavailable, cycles: cycles, peak: peak, observedAt: nil,
              historyAttributed: attributed, now: now, language: .chinese, header: header, usageDetail: detail)
    }
}
