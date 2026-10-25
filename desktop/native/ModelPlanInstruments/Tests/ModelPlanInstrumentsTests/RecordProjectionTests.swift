// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanInstruments

final class RecordProjectionTests: XCTestCase {
    let now = Fixtures.now

    func testOwnConfigurationRateRejectsPeerModelEffortFastAndMissingIdentity() {
        let expected = SessionRateIdentity(sessionID: "a", modelID: "model", effort: "high", fast: false)
        let identities: [SessionRateIdentity?] = [
            nil, .init(sessionID: "other", modelID: "model", effort: "high", fast: false),
            .init(sessionID: "a", modelID: "other-model", effort: "high", fast: false),
            .init(sessionID: "a", modelID: "model", effort: "low", fast: false),
            .init(sessionID: "a", modelID: "model", effort: "high", fast: true), expected,
        ]
        for identity in identities {
            let rate = SessionRate(value: 58, lastAt: now, samples: 5, validSession60s: true, configuration: identity)
            let session = makeSession("a", rate: rate)
            XCTAssertEqual(strip([session]).lines[0].speed60s, identity == expected ? 58 : nil)
        }
    }

    func testSamplingFreshnessAndUnknownCurrentNeverBorrowAUsablePeer() {
        let identity = SessionRateIdentity(sessionID: "a", modelID: "model", effort: "high", fast: false)
        let badRates = [
            SessionRate(value: 9, lastAt: now, samples: 4, validSession60s: true, configuration: identity),
            .init(value: 9, lastAt: now.addingTimeInterval(-60), samples: 5, validSession60s: true, configuration: identity),
            .init(value: 9, lastAt: now.addingTimeInterval(1), samples: 5, validSession60s: true, configuration: identity),
            .init(value: 9, lastAt: now, samples: 5, minimumSamples: 6, validSession60s: true, configuration: identity),
            .init(value: 9, lastAt: now, samples: 5, validSession60s: false, configuration: identity),
        ]
        for rate in badRates {
            let page = strip([makeSession("a", rate: rate), Fixtures.session("peer")])
            XCTAssertNil(page.lines.first { $0.id == "a" }?.speed60s)
            XCTAssertEqual(page.lines.first { $0.id == "peer" }?.speed60s, 58)
        }
        let valid = SessionRate(value: 0, lastAt: now, samples: 5, validSession60s: true, configuration: identity)
        XCTAssertEqual(strip([makeSession("a", rate: valid)]).lines[0].speed60s, 0)
        XCTAssertNil(strip([makeSession("a", rate: valid, effort: nil)]).lines[0].speed60s)
        let expired = makeSession("a", rate: valid, evidence: .init(validUntil: now))
        XCTAssertFalse(strip([expired]).lines[0].working); XCTAssertNil(strip([expired]).lines[0].speed60s)
        XCTAssertEqual(strip([expired]).lines[0].activity, .unknown)
    }

    func testStableSessionTiesAndSixRunningOverflowDestination() {
        let sessions = (0..<6).reversed().map { Fixtures.session("s\($0)") }
        let compact = strip(sessions, height: 883.9), tall = strip(sessions, height: 884)
        XCTAssertEqual(compact.lines.map(\.id), ["s0", "s1", "s2"])
        XCTAssertEqual(compact.runningOverflow, 3); XCTAssertEqual(tall.runningOverflow, 1)
        XCTAssertEqual(tall.overflow, 1)
        XCTAssertEqual(tall.moreDestination, .page(.init(.destinations, destinationsMode: .timeline)))
        var navigation = MainScreenNavigation(location: .init(.effort), scope: .subscription("a"))
        navigation.activate(tall.moreDestination!, from: .recordOverflow)
        XCTAssertEqual(navigation.location.page, .destinations); XCTAssertEqual(navigation.location.destinationsMode, .timeline)
        XCTAssertEqual(navigation.scope, .subscription("a"))
        navigation.back(); XCTAssertEqual(navigation.location.page, .effort)
        XCTAssertNil(strip([]).moreDestination)
    }

    func testProjectRankingPeriodFreshnessAndPrivacyStayExplicit() {
        let projects = [InstrumentProject(id: "p", name: "Hidden project", subscriptionIDs: ["a", "b"], combinedTokens: 100),
                        .init(id: "q", name: "Another project", subscriptionIDs: ["a"], combinedTokens: 20)]
        func page(_ ranking: SuppliedProjectRanking?, scope: InstrumentScope = .subscription("a")) -> DestinationsPresentation {
            .init(ranking: ranking, expectedPeriod: .days7, sessions: [Fixtures.session("a", project: "Hidden project")], scope: scope,
                  timelineRange: .today, showProjectNames: false, now: now, calendar: Fixtures.calendar(), language: .english)
        }
        let ranking = SuppliedProjectRanking(period: .days7, projects: projects, evidence: .init())
        XCTAssertEqual(page(ranking).projects.map(\.id), ["p", "q"])
        XCTAssertEqual(page(ranking).projects.map(\.tokens), [nil, 20])
        XCTAssertTrue(page(ranking).projects.allSatisfy { $0.name == nil })
        XCTAssertTrue(page(ranking).timeline.allSatisfy { $0.projectName == nil })
        XCTAssertTrue(page(.init(period: .days30, projects: projects, evidence: .init())).projects.isEmpty)
        XCTAssertTrue(page(.init(period: .days7, projects: projects, evidence: .init(freshness: .stale))).projects.isEmpty)
        XCTAssertNotNil(page(nil).projectUnavailableReason)
        XCTAssertEqual(page(ranking, scope: .all).projects.map(\.tokens), [100, 20])
    }

    func testTimelineTodayAndSevenCalendarDaysAtExactBoundary() {
        let calendar = Fixtures.calendar(), today = Fixtures.calendar().startOfDay(for: now)
        let first = calendar.date(byAdding: .day, value: -6, to: today)!
        let sessions = [Fixtures.session("edge", running: false, endedAt: first),
                        Fixtures.session("old", running: false, endedAt: first.addingTimeInterval(-1)),
                        Fixtures.session("today", running: false, endedAt: today), Fixtures.session("live")]
        func page(_ range: TimelineRange) -> DestinationsPresentation {
            .init(projects: [], sessions: sessions, scope: .all, timelineRange: range, showProjectNames: true,
                  now: now, calendar: calendar, language: .english)
        }
        XCTAssertEqual(page(.days7).timeline.map(\.id), ["live", "today", "edge"])
        XCTAssertEqual(page(.today).timeline.map(\.id), ["live", "today"])
    }

    private func makeSession(_ id: String, rate: SessionRate?, effort: String? = "high", evidence: InstrumentEvidence = .init()) -> InstrumentSession {
        .init(id: id, subscriptionID: "a", tool: "Codex", model: "model", effort: effort, startedAt: now.addingTimeInterval(-10),
              endedAt: nil, lastAt: now, running: true, rate: rate, evidence: evidence)
    }
    private func strip(_ sessions: [InstrumentSession], height: Double = 890) -> RecordStripPresentation {
        .init(sessions: sessions, height: height, scope: .all, showProjectNames: false, now: now, language: .english)
    }
}
