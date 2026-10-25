// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanInstruments

final class RecordTests: XCTestCase {
    let now = Fixtures.now

    func testF12ThreeFiveLinesRunningFirstAndOverflow() {
        let sessions = [Fixtures.session("done", running: false, endedAt: now.addingTimeInterval(-360))] + (0..<6).map { Fixtures.session("run\($0)") }
        for (height, count) in [(640.0, 3), (883.9, 3), (884, 5), (890, 5)] {
            let strip = RecordStripPresentation(sessions: sessions, height: height, scope: .all, showProjectNames: true, now: now, language: .chinese)
            XCTAssertEqual(strip.lines.count, count); XCTAssertEqual(strip.overflow, 7 - count)
            XCTAssertTrue(strip.lines.allSatisfy(\.working)); XCTAssertEqual(strip.lines.first?.speed60s, 58)
        }
        let done = RecordStripPresentation(sessions: [sessions[0]], height: 890, scope: .all, showProjectNames: true, now: now, language: .chinese)
        XCTAssertEqual(done.lines[0].age, "6m前"); XCTAssertEqual(done.lines[0].tool, "Claude")
    }

    func testF03OwnRateOnlyAndFreshnessBoundaries() {
        let sessions = [Fixtures.session("known"), Fixtures.session("unknown", rate: nil), Fixtures.session("expiredRate", lastAt: now.addingTimeInterval(-60)), Fixtures.session("expiredSession", lastAt: now.addingTimeInterval(-300))]
        let strip = RecordStripPresentation(sessions: sessions, height: 890, scope: .all, showProjectNames: true, now: now, language: .english)
        XCTAssertEqual(strip.lines.first { $0.id == "known" }?.speed60s, 58)
        for id in ["unknown", "expiredRate", "expiredSession"] { XCTAssertNil(strip.lines.first { $0.id == id }?.speed60s) }
        XCTAssertFalse(strip.lines.first { $0.id == "expiredSession" }!.working)
        XCTAssertNil(SessionRate(value: 30, lastAt: now, samples: 4, validSession60s: true).reading(now: now))
        XCTAssertNil(SessionRate(value: 30, lastAt: now, samples: 5, validSession60s: false).reading(now: now))
        XCTAssertNil(SessionRate(value: 30, lastAt: now.addingTimeInterval(1), samples: 5, validSession60s: true).reading(now: now))
        XCTAssertEqual(SessionRate(value: 0, lastAt: now, samples: 5, validSession60s: true).reading(now: now), 0)
    }

    func testF12ScopeAndNamesOffEveryProjection() {
        let sessions = [Fixtures.session("a", project: "Secret project"), Fixtures.session("b", sub: "b"), Fixtures.session("unattributed", sub: nil)]
        let strip = RecordStripPresentation(sessions: sessions, height: 890, scope: .subscription("a"), showProjectNames: false, now: now, language: .chinese)
        XCTAssertEqual(strip.lines.map(\.id), ["a"]); XCTAssertNil(strip.lines[0].projectName)
        let projects = [InstrumentProject(id: "p", name: "Secret project", subscriptionIDs: ["a", "b"], combinedTokens: 100)]
        let page = DestinationsPresentation(projects: projects, sessions: sessions, scope: .subscription("a"), timelineRange: .today,
                                             showProjectNames: false, now: now, calendar: Fixtures.calendar(), language: .chinese)
        XCTAssertNil(page.projects[0].name); XCTAssertNil(page.projects[0].tokens)
        XCTAssertTrue(page.timeline.allSatisfy { $0.projectName == nil })
        XCTAssertEqual(page.timeline.map(\.id), ["a"])
    }

    func testF12TimelineRangeAndScopedProjectTotals() {
        let projects = [InstrumentProject(id: "combined", name: "P", subscriptionIDs: ["a", "b"], combinedTokens: 100, tokensBySubscription: ["a": 40]),
                        .init(id: "unique", name: "Q", subscriptionIDs: ["a"], combinedTokens: 60)]
        let sessions = [Fixtures.session("live"), Fixtures.session("yesterday", running: false, endedAt: now.addingTimeInterval(-86400)),
                        Fixtures.session("old", running: false, endedAt: now.addingTimeInterval(-8 * 86400))]
        func page(_ range: TimelineRange) -> DestinationsPresentation {
            .init(projects: projects, sessions: sessions, scope: .subscription("a"), timelineRange: range,
                  showProjectNames: true, now: now, calendar: Fixtures.calendar(), language: .english)
        }
        XCTAssertEqual(page(.today).timeline.map(\.id), ["live"])
        XCTAssertEqual(page(.days7).timeline.map(\.id), ["live", "yesterday"])
        XCTAssertEqual(page(.days7).projects.map(\.tokens), [40, 60])
    }
}
