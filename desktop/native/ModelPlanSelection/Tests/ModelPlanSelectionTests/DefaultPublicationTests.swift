// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanSelection

final class DefaultPublicationTests: XCTestCase {
    func publication(_ models: [SelectionModel], id: String = "p", revision: String? = "r",
                     picks: [PublishedPick] = []) -> SelectionPublication {
        .init(publicationID: id, selectionRevision: revision, models: models, picks: picks)
    }
    func input(_ ranked: SelectionPublication?, scope: SelectionScope = .all,
               usage: [SelectionUsage] = [], windows: [SelectionWindowUsage] = []) -> SelectionInput {
        .init(scope: scope, publication: ranked,
              subscriptions: [.init(id: "s", availability: .available, offeredModelIDs: ["a", "b"])],
              usage: usage, windowUsage: windows, now: referenceTime)
    }
    func testMatchingOriginalDeclarationRestoresDefaultIdentityRemovedFromRankedProjection() {
        let a = model("a"), b = SelectionModel(id: "b", developerID: "dev", lineageID: nil,
            lineageStatus: "current", defaultSelected: true)
        let value = input(publication([a]))
        XCTAssertEqual(ModelSelection.selectPublicFleet(value).orderedIDs, ["a"])
        let result = ModelSelection.selectPublicFleet(value, defaultPublication: publication([a, b]))
        XCTAssertEqual(result.orderedIDs, ["a", "b"])
        XCTAssertEqual(result.models[1].origin, .publishedDefaultFallback)
        XCTAssertEqual(result.models[1].model, b)
        XCTAssertNil(result.models[1].model.lineageID)
        XCTAssertEqual(result.selectionRevision, "r")
    }
    func testContextQuarantineCannotBeRestoredAsAPickMainstayOrExactUsage() {
        let ranked = publication([model("a"), model("b", exclusion: .legacy)], picks: [.init(modelID: "b", kind: .strongest)])
        let value = input(ranked, usage: [use("b", age: 1)])
        XCTAssertEqual(ModelSelection.select(value).orderedIDs, ["a"])
        let result = ModelSelection.selectPublicFleet(value, defaultPublication: publication([model("a"), model("b")]))
        XCTAssertEqual(result.orderedIDs, ["a", "b"])
        XCTAssertEqual(result.models[1].origin, .publishedDefaultFallback)
        XCTAssertEqual(ModelSelection.select(value).orderedIDs, ["a"])
    }
    func testDifferentPublicationOrRevisionCannotLeakSupplementaryIdentityOrDiagnostics() {
        let value = SelectionInput(scope: .all, publication: publication([model("a")]),
            subscriptions: [.init(id: "s", availability: .available, offeredModelIDs: ["a"])], usage: [], now: referenceTime)
        let baseline = ModelSelection.selectPublicFleet(value)
        let b = SelectionModel(id: "b", developerID: "dev", lineageID: nil, lineageStatus: "current", defaultSelected: true)
        for original in [publication([model("a"), b], id: "other"),
                         publication([model("a"), b], revision: "other"),
                         publication([model("a"), b], revision: nil)] {
            let result = ModelSelection.selectPublicFleet(value, defaultPublication: original)
            XCTAssertEqual(result, baseline)
            XCTAssertFalse(result.issues.contains { $0.modelID == "b" })
        }
    }
    func testGenuinelyConflictingOriginalIDAlsoQuarantinesRankedOlderVariant() {
        let a = model("a"), olderB = model("b", status: "older", selected: false)
        let value = input(publication([a, olderB]), windows: [.init(modelID: "b", subscriptionID: "s")])
        XCTAssertEqual(ModelSelection.select(value).orderedIDs, ["b", "a"])
        let original = publication([a, model("b"), olderB])
        let result = ModelSelection.selectPublicFleet(value, defaultPublication: original)
        XCTAssertEqual(result.orderedIDs, ["a"])
        XCTAssertEqual(result.issues.filter { $0.modelID == "b" && $0.reason == .conflictingModelID }.count, 1)
    }
    func testMatchingAbsentRevisionPreservesAbsenceButOriginalCannotReplaceMissingInputPublication() {
        let value = input(publication([model("a")], revision: nil))
        let original = publication([model("a"), model("b")], revision: nil)
        let result = ModelSelection.selectPublicFleet(value, defaultPublication: original)
        XCTAssertEqual(result.orderedIDs, ["a", "b"])
        XCTAssertNil(result.selectionRevision)
        let unavailable = input(nil)
        XCTAssertEqual(ModelSelection.selectPublicFleet(unavailable, defaultPublication: original), ModelSelection.select(unavailable))
    }
    func testSingleRemainsOrdinaryEvenWhenOriginalIdentityMatches() {
        let value = input(publication([model("a")]), scope: .subscription("s"))
        let original = publication([model("a"), model("b")])
        XCTAssertEqual(ModelSelection.selectPublicFleet(value, defaultPublication: original), ModelSelection.select(value))
    }
}
