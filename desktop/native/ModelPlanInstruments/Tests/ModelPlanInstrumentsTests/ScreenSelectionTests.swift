// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanInstruments

final class ScreenSelectionTests: XCTestCase {
    let publication = SelectionPublication(publicationID: "publication", selectionRevision: "selection-v1")

    func testCLIFlagsKeepFalseSeparateFromNullAndMissing() throws {
        let decode = { (json: String) in try JSONDecoder().decode(InstrumentLineage.self, from: Data(json.utf8)) }
        let negative = try decode(#"{"lineageId":null,"lineageStatus":null,"defaultSelected":false,"current":false}"#)
        XCTAssertNil(negative.lineageId); XCTAssertNil(negative.lineageStatus)
        XCTAssertEqual(negative.defaultSelected, false); XCTAssertEqual(negative.current, false)
        let unknown = try decode(#"{"lineageId":"line","defaultSelected":null}"#)
        XCTAssertEqual(unknown.lineageId, "line"); XCTAssertNil(unknown.defaultSelected); XCTAssertNil(unknown.current)
        XCTAssertEqual(try decode("{}"), InstrumentLineage())
        for status in ["current", "older", "preview", "retired", "future-status"] {
            XCTAssertEqual(try decode("{\"lineageStatus\":\"\(status)\"}").lineageStatus, status)
        }
    }

    func testInjectedOrderAndMetadataOverrideNamesAndScoresWithoutLocalRanking() {
        let models = [model("expensive", name: "Newest Current Model", status: "retired", selected: false),
                      model("preview", name: "Stable", status: "preview", selected: false),
                      model("cheap", name: "Old name", status: "current", selected: true),
                      model("used", name: "Used model", status: "current", selected: false)]
        let selection = InjectedModelSelection(publication: publication, scope: .all, orderedModelIDs: ["used", "cheap"], selectedModelID: "used")
        let page = page(models, selection)
        XCTAssertEqual(page.models.map(\.id), ["used", "cheap"])
        XCTAssertEqual(page.models.map { $0.lineage.defaultSelected }, [false, true])
        XCTAssertEqual(page.selectedModelID, "used")
        XCTAssertEqual(page.orderedModelIDs, selection.orderedModelIDs)
    }

    func testAllOlderBoundaryResultsAreConsumedWithoutASecondSevenDaySelector() {
        let old = model("old", name: "Old", status: "older", selected: false)
        let current = model("current", name: "Current", status: "current", selected: true)
        // M2 owns boundary policy. These are supplied results before/after its seven-day window,
        // not another eligibility function in the page layer.
        let before = InjectedModelSelection(publication: publication, scope: .all, orderedModelIDs: ["old", "current"])
        let after = InjectedModelSelection(publication: publication, scope: .all, orderedModelIDs: ["current"])
        XCTAssertEqual(page([current, old], before).models.map(\.id), ["old", "current"])
        XCTAssertEqual(page([current, old], before).models.first?.lineage.lineageStatus, "older")
        XCTAssertEqual(page([current, old], after).models.map(\.id), ["current"])
    }

    func testUnavailableSharedSelectionHasNoPageFallback() {
        let scope = InstrumentScope.subscription("a")
        let pending = InjectedModelSelection(publication: publication, scope: scope, orderedModelIDs: [],
                                             unavailableReason: "lineage-metadata-unavailable")
        let result = EffortPagePresentation(models: [Fixtures.model()], selection: pending, scope: scope, publication: publication, publicationUsable: true)
        XCTAssertTrue(result.models.isEmpty); XCTAssertEqual(result.unavailableReason, pending.unavailableReason)
    }

    func testSharedRecentOlderResultsInBothScopesAndSevenDayBoundary() {
        let older = model("older", name: "Version", status: "older", selected: false)
        let current = model("current", name: "Version 2", status: "current", selected: true)
        let unavailable = model("elsewhere", name: "Elsewhere", status: "older", selected: false)
        // Expected selector outputs are injected fixtures. M2 owns recent-use/time/scope checks.
        // Exact seven-day evidence is included; one second older is excluded in that shared result.
        let boundary = Fixtures.now.addingTimeInterval(-7 * 86400)
        let cases: [(Date, [String])] = [(boundary.addingTimeInterval(1), ["older", "current"]),
                                        (boundary, ["older", "current"]),
                                        (boundary.addingTimeInterval(-1), ["current"])]
        for scope in [InstrumentScope.all, .subscription("a")] {
            for (usedAt, ids) in cases {
                let selection = InjectedModelSelection(publication: publication, scope: scope, orderedModelIDs: ids,
                                                      recentUseAtByModel: ["older": usedAt, "elsewhere": Fixtures.now])
                let page = EffortPagePresentation(models: [unavailable, current, older], selection: selection, scope: scope,
                                                  publication: publication, publicationUsable: true)
                XCTAssertEqual(page.models.map(\.id), ids)
                XCTAssertFalse(page.models.contains { $0.id == "elsewhere" })
                XCTAssertEqual(page.models.first { $0.id == "older" }?.olderBadge(.chinese), ids.contains("older") ? "旧版" : nil)
                XCTAssertNil(page.models.first { $0.id == "current" }?.olderBadge(.english))
                XCTAssertEqual(page.recentUseAtByModel["older"], ids.contains("older") ? usedAt : nil)
                XCTAssertNil(page.recentUseAtByModel["elsewhere"])
            }
        }
        XCTAssertEqual(older.olderBadge(.english), "older")
        XCTAssertNil(model("retired", name: "Old", status: "retired", selected: false).olderBadge(.chinese))
    }

    func testMissingAndMismatchedPublicationOrRevisionWithholdScoredPage() {
        let models = [Fixtures.model()]
        let selection = InjectedModelSelection(publication: publication, scope: .all, orderedModelIDs: ["model"])
        for identity in [nil, SelectionPublication(publicationID: "different", selectionRevision: "selection-v1"),
                         .init(publicationID: "publication", selectionRevision: nil),
                         .init(publicationID: "publication", selectionRevision: ""),
                         .init(publicationID: "publication", selectionRevision: "selection-v2")] {
            XCTAssertTrue(EffortPagePresentation(models: models, selection: selection, scope: .all, publication: identity, publicationUsable: true).models.isEmpty)
        }
        XCTAssertTrue(EffortPagePresentation(models: models, selection: nil, scope: .all, publication: publication, publicationUsable: true).models.isEmpty)
        XCTAssertTrue(EffortPagePresentation(models: models, selection: selection, scope: .subscription("a"), publication: publication, publicationUsable: true).models.isEmpty)
        XCTAssertTrue(EffortPagePresentation(models: models, selection: selection, scope: .all, publication: publication, publicationUsable: false).models.isEmpty)
    }

    func testPartialPublicationPreservesMissingIDsWithoutNameFallbackOrDefaultPromotion() {
        let models = [model("present", name: "missing", status: nil, selected: nil)]
        let selection = InjectedModelSelection(publication: publication, scope: .all, orderedModelIDs: ["missing", "present"], selectedModelID: "missing")
        let result = page(models, selection)
        XCTAssertEqual(result.orderedModelIDs, ["missing", "present"])
        XCTAssertEqual(result.missingModelIDs, ["missing"]); XCTAssertEqual(result.models.map(\.id), ["present"])
        XCTAssertNil(result.selectedModelID); XCTAssertNil(result.models[0].lineage.current)
        XCTAssertNil(result.models[0].lineage.defaultSelected)
    }

    func testDuplicateIdentityIsAmbiguousButRepeatedSelectedIDIsNotDuplicated() {
        let model = Fixtures.model()
        let selection = InjectedModelSelection(publication: publication, scope: .all, orderedModelIDs: ["model", "model"])
        XCTAssertEqual(page([model], selection).models.count, 1)
        let ambiguous = page([model, model], selection)
        XCTAssertTrue(ambiguous.models.isEmpty); XCTAssertEqual(ambiguous.missingModelIDs, ["model"])
    }

    func testTenInjectedIDsStayFixedWhenEighthModelIsSelected() {
        let ids = (0..<10).map { "m\($0)" }
        let models = (0..<13).reversed().map { Fixtures.model(id: "m\($0)") }
        let selection = InjectedModelSelection(publication: publication, scope: .all, orderedModelIDs: ids)
        var navigation = MainScreenNavigation()
        navigation.reconcile(selection: selection, publication: publication)
        navigation.selectModel("m7", selection: selection, publication: publication)
        XCTAssertEqual(navigation.selectedModelID, "m7")
        XCTAssertEqual(page(models, selection).orderedModelIDs, ids)
        XCTAssertEqual(Array(page(models, selection).models.prefix(3).map(\.id)), ["m0", "m1", "m2"])
    }

    private func model(_ id: String, name: String, status: String?, selected: Bool?) -> InstrumentModel {
        .init(id: id, name: name, efforts: Fixtures.efforts, recommended: "medium", current: nil,
              lineage: .init(lineageId: "published-line", lineageStatus: status, defaultSelected: selected, current: nil))
    }
    private func page(_ models: [InstrumentModel], _ selection: InjectedModelSelection) -> EffortPagePresentation {
        .init(models: models, selection: selection, scope: .all, publication: publication, publicationUsable: true)
    }
}

final class MainScreenNavigationTests: XCTestCase {
    func testFiveSourcedViewsReturnToOriginalPageAndSameSourceToggles() {
        let base = MainScreenLocation(.destinations, destinationsMode: .projects, timelineRange: .days7, projectPeriod: .days30)
        let routes: [(MainScreenSource, MainScreenContent)] = [
            (.hud, .page(.init(.effort))), (.alertLamp, .alerts), (.record("s"), .session("s")),
            (.recordOverflow, .page(.init(.destinations, destinationsMode: .timeline))),
            (.fader("m"), .comparison(modelID: "m", trial: .init("high"))),
        ]
        for (source, content) in routes {
            var state = MainScreenNavigation(location: base)
            state.activate(content, from: source)
            XCTAssertEqual(state.sourced?.returnTo, base)
            state.activate(content, from: source)
            XCTAssertNil(state.sourced); XCTAssertNil(state.trial); XCTAssertEqual(state.location, base)
        }
    }

    func testReplacementRetainsOneReturnAndOneLocalTrial() {
        var state = MainScreenNavigation(location: .init(.subscriptions))
        let model = Fixtures.model(), real = model.current
        state.activate(.comparison(modelID: "model", trial: .init("max")), from: .fader("model"))
        XCTAssertNil(state.highlightedPage)
        state.updateTrial(.init("low"), modelID: "model"); XCTAssertEqual(state.trial?.effort, "low")
        state.activate(.session("s"), from: .record("s"))
        XCTAssertNil(state.trial); XCTAssertEqual(state.sourced?.source, .record("s"))
        state.back(); XCTAssertEqual(state.location.page, .subscriptions); XCTAssertNil(state.sourced)
        XCTAssertEqual(model.current, real)
    }

    func testDirectPageScopeAndCloseEndComparison() {
        var state = MainScreenNavigation()
        func open(_ state: inout MainScreenNavigation) { state.activate(.comparison(modelID: "m", trial: .init("max")), from: .fast("m")) }
        open(&state); state.selectPage(.init(.effort)); XCTAssertNil(state.trial)
        XCTAssertEqual(state.highlightedPage, .effort)
        open(&state); state.selectScope(.subscription("a")); XCTAssertNil(state.trial); XCTAssertEqual(state.scope, .subscription("a"))
        open(&state); state.close(); XCTAssertNil(state.trial); XCTAssertNil(state.sourced)
    }

    func testRevisionScopeOrRemovedModelCancelsStaleSelectionAndTrial() {
        let publication = SelectionPublication(publicationID: "p", selectionRevision: "1")
        let selection = InjectedModelSelection(publication: publication, scope: .all, orderedModelIDs: ["a", "b"], selectedModelID: "a")
        var state = MainScreenNavigation()
        state.reconcile(selection: selection, publication: publication)
        XCTAssertEqual(state.selectedModelID, "a")
        state.activate(.comparison(modelID: "b", trial: .init("high")), from: .fader("b"))
        let removed = InjectedModelSelection(publication: publication, scope: .all, orderedModelIDs: ["a"])
        state.reconcile(selection: removed, publication: publication); XCTAssertNil(state.trial)
        state.activate(.comparison(modelID: "a", trial: .init("high")), from: .fader("a"))
        state.reconcile(selection: selection, publication: .init(publicationID: "p", selectionRevision: "2"))
        XCTAssertNil(state.trial); XCTAssertNil(state.selectedModelID)
        state.selectScope(.subscription("x")); state.reconcile(selection: selection, publication: publication)
        XCTAssertNil(state.selectedModelID)
    }

    func testExplicitModelSelectionEndsTrialWithoutChoosingAnotherDefault() {
        let publication = SelectionPublication(publicationID: "p", selectionRevision: "r")
        let selection = InjectedModelSelection(publication: publication, scope: .all, orderedModelIDs: ["b", "a"])
        var state = MainScreenNavigation()
        state.reconcile(selection: selection, publication: publication); XCTAssertNil(state.selectedModelID)
        state.activate(.comparison(modelID: "a", trial: .init("max")), from: .fader("a"))
        state.selectModel("b", selection: selection, publication: publication)
        XCTAssertNil(state.trial); XCTAssertEqual(state.selectedModelID, "b")
    }
}
