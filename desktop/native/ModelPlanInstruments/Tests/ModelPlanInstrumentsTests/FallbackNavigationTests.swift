// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanInstruments

final class FallbackNavigationTests: XCTestCase {
    let publication = SelectionPublication(publicationID: "p", selectionRevision: "r")
    func testExactTrialClosesWhenSameIdentityBecomesCatalogueFallback() {
        let exact = InjectedModelSelection(publication: publication, scope: .all, orderedModelIDs: ["model"], selectedModelID: "model")
        let fallback = catalogue()
        var state = MainScreenNavigation(location: .init(.subscriptions))
        state.reconcile(selection: exact, publication: publication)
        state.activate(.comparison(modelID: "model", trial: .init("max")), from: .fader("model"))
        XCTAssertNotNil(state.trial)
        state.reconcile(selection: fallback, publication: publication)
        XCTAssertNil(state.trial); XCTAssertNil(state.sourced)
        XCTAssertEqual(state.location.page, .subscriptions)
        XCTAssertEqual(state.selectedModelID, "model")
        let page = EffortPagePresentation(models: [Fixtures.model()], selection: fallback, scope: .all,
                                          publication: publication, publicationUsable: false)
        XCTAssertEqual(page.models.map(\.id), ["model"]); XCTAssertTrue(page.publicDefaultFallback)
        XCTAssertEqual(page.selectionNotice, "Public defaults")
    }
    func testFallbackCataloguePageAndIndependentPersonalSourcesRemainOpen() {
        let exact = InjectedModelSelection(publication: publication, scope: .all, orderedModelIDs: ["model"], selectedModelID: "model")
        let routes: [(MainScreenSource, MainScreenContent)] = [
            (.hud, .page(.init(.effort))), (.record("s"), .session("s")), (.alertLamp, .alerts),
            (.recordOverflow, .page(.init(.destinations, destinationsMode: .timeline))),
        ]
        for (source, content) in routes {
            var state = MainScreenNavigation(location: .init(.overview))
            state.reconcile(selection: exact, publication: publication); state.activate(content, from: source)
            let before = state.sourced
            state.reconcile(selection: catalogue(), publication: publication)
            XCTAssertEqual(state.sourced, before)
            XCTAssertEqual(state.selectedModelID, "model")
        }
    }
    private func catalogue() -> InjectedModelSelection {
        .init(publication: publication, scope: .all, orderedModelIDs: ["model"], selectedModelID: "model",
              unavailableReason: "personal-unavailable", publicDefaultFallback: true, selectionNotice: "Public defaults")
    }
}
