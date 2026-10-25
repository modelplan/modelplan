// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanInstruments

final class P03ReviewRegressionTests: XCTestCase {
    let now = Fixtures.now

    func testZeroAllowancesRequireTrustedEvidenceBeforeFiltering() {
        let evidence = [InstrumentEvidence(), .init(freshness: .stale), .init(freshness: .unavailable),
                        .init(freshness: .unknown), .init(validUntil: now), .init(observedAt: now.addingTimeInterval(1)),
                        .init(validUntil: now.addingTimeInterval(1))]
        for reading in evidence {
            for expiry in [nil, now.addingTimeInterval(-1), now, now.addingTimeInterval(3600)] {
                let value = reserve([.init(count: 0, expiresAt: expiry, evidence: reading)])
                XCTAssertEqual(value.resets, reading.usable(at: now) ? 0 : nil, "\(reading.freshness), \(String(describing: expiry))")
                XCTAssertFalse(value.expiryWarning)
            }
        }
        XCTAssertNil(reserve(nil).resets)
        XCTAssertEqual(reserve([]).resets, 0)
    }

    func testUntrustedZeroOrExpiredEntriesCannotMakeMixedTotalKnown() {
        let trusted = ResetAllowance(count: 2, expiresAt: now.addingTimeInterval(3600))
        for reading in [InstrumentEvidence(freshness: .stale), .init(freshness: .unavailable), .init(validUntil: now)] {
            for entry in [ResetAllowance(count: 0, expiresAt: nil, evidence: reading),
                          .init(count: 0, expiresAt: now, evidence: reading),
                          .init(count: 3, expiresAt: now.addingTimeInterval(-1), evidence: reading)] {
                XCTAssertNil(reserve([trusted, entry]).resets)
                XCTAssertNil(reserve([entry, trusted]).resets)
                XCTAssertNil(reserve([entry]).resets)
            }
        }
    }

    func testTrustedZeroAndNaturalExpiryRemainKnownWithoutLosingActiveCounts() {
        let valid = InstrumentEvidence(validUntil: now.addingTimeInterval(60))
        let zero = ResetAllowance(count: 0, expiresAt: now.addingTimeInterval(3600), evidence: valid)
        let expired = ResetAllowance(count: 3, expiresAt: now, evidence: valid)
        let active = ResetAllowance(count: 2, expiresAt: now.addingTimeInterval(3600), evidence: valid)
        XCTAssertEqual(reserve([zero, expired]).resets, 0)
        XCTAssertEqual(reserve([zero, expired]).allowances?.count, 0)
        XCTAssertFalse(reserve([zero, expired]).expiryWarning)
        XCTAssertEqual(reserve([zero, expired, active]).resets, 2)
        XCTAssertEqual(reserve([zero, expired, active]).nearestExpiry, active.expiresAt)
        XCTAssertTrue(reserve([zero, expired, active]).expiryWarning)
    }

    func testPersonalSourcesSurvivePublicationAndSelectionChanges() {
        let p1 = SelectionPublication(publicationID: "p1", selectionRevision: "r1")
        let p2 = SelectionPublication(publicationID: "p2", selectionRevision: "r2")
        let revision = SelectionPublication(publicationID: "p1", selectionRevision: "r2")
        let original = selection(p1, ids: ["a"])
        let updates: [(InjectedModelSelection?, SelectionPublication?)] = [
            (selection(p2, ids: ["b"]), p2), (selection(revision, ids: ["b"]), revision),
            (nil, nil), (nil, p1), (original, nil), (original, p2),
            (.init(publication: p1, scope: .all, orderedModelIDs: [], unavailableReason: "unavailable"), p1),
            (selection(p1, ids: []), p1),
        ]
        let routes: [(MainScreenSource, MainScreenContent)] = [
            (.record("s"), .session("s")), (.alertLamp, .alerts), (.noticeOverflow, .alerts),
            (.recordOverflow, .page(.init(.destinations, destinationsMode: .timeline, timelineRange: .days7))),
        ]
        for (source, content) in routes {
            for (selected, publication) in updates {
                var state = MainScreenNavigation(location: .init(.subscriptions))
                state.reconcile(selection: original, publication: p1)
                state.activate(content, from: source)
                let view = state.sourced, location = state.location
                state.reconcile(selection: selected, publication: publication)
                XCTAssertEqual(state.sourced, view, "\(source), \(String(describing: publication))")
                XCTAssertEqual(state.location, location)
                XCTAssertNotEqual(state.selectedModelID, "a")
                state.back()
                XCTAssertNil(state.sourced); XCTAssertEqual(state.location.page, .subscriptions)
            }
        }
    }

    func testPublicationDependentRecommendationAndTrialStillClose() {
        let p1 = SelectionPublication(publicationID: "p1", selectionRevision: "r1")
        let p2 = SelectionPublication(publicationID: "p2", selectionRevision: "r2")
        let routes: [(MainScreenSource, MainScreenContent)] = [
            (.hud, .page(.init(.effort))), (.fader("a"), .comparison(modelID: "a", trial: .init("max"))),
        ]
        for (source, content) in routes {
            for update in [(selection(p2, ids: ["b"]), Optional(p2)), (nil, nil), (nil, Optional(p1))] {
                var state = MainScreenNavigation(location: .init(.subscriptions))
                state.reconcile(selection: selection(p1, ids: ["a"]), publication: p1)
                state.activate(content, from: source)
                state.reconcile(selection: update.0, publication: update.1)
                XCTAssertNil(state.sourced); XCTAssertNil(state.trial)
                XCTAssertEqual(state.location.page, .subscriptions)
            }
        }
    }

    func testTimelineReturnContextSurvivesPublicUnavailable() {
        let base = MainScreenLocation(.destinations, destinationsMode: .projects, timelineRange: .days7, projectPeriod: .days30)
        let p1 = SelectionPublication(publicationID: "p1", selectionRevision: "r1")
        var state = MainScreenNavigation(location: base)
        state.reconcile(selection: selection(p1, ids: ["a"]), publication: p1)
        let target = MainScreenContent.page(.init(.destinations, destinationsMode: .timeline))
        state.activate(target, from: .recordOverflow)
        state.reconcile(selection: nil, publication: nil)
        XCTAssertEqual(state.sourced?.returnTo, base); XCTAssertEqual(state.sourced?.content, target)
        state.activate(target, from: .recordOverflow)
        XCTAssertNil(state.sourced); XCTAssertEqual(state.location, base)
    }

    private func selection(_ publication: SelectionPublication, ids: [String]) -> InjectedModelSelection {
        .init(publication: publication, scope: .all, orderedModelIDs: ids, selectedModelID: ids.first)
    }
    private func reserve(_ entries: [ResetAllowance]?) -> ReservePresentation {
        .init(allowances: entries, credits: nil, drawingCredits: false, now: now)
    }
}
