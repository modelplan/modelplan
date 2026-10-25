// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanSelection

final class PublicDefaultsTests: XCTestCase {
    func publication(_ models: [SelectionModel], picks: [PublishedPick] = []) -> SelectionPublication {
        .init(publicationID: "public-directory", selectionRevision: nil, models: models, picks: picks)
    }
    func testNoPersonalDataNoRevisionAndMissingLineageStillPermitExplicitPublicDefaults() {
        let missingLineage = SelectionModel(id: "explicit", developerID: nil, lineageID: nil,
            lineageStatus: "current", defaultSelected: true)
        let p = publication([missingLineage, model("known")])
        for scope in [SelectionScope.all, .subscription("no-personal-record")] {
            let result = ModelSelection.publicDefaults(publication: p, scope: scope)
            XCTAssertEqual(result.orderedIDs, ["explicit", "known"])
            XCTAssertEqual(result.scope, scope)
            XCTAssertEqual(result.publicationID, p.publicationID)
            XCTAssertNil(result.selectionRevision)
            XCTAssertEqual(result.models[0].model, missingLineage)
            XCTAssertNil(result.models[0].model.lineageID)
            XCTAssertTrue(result.models.allSatisfy { $0.origin == .publishedDefaultFallback })
            XCTAssertTrue(result.issues.contains { $0.modelID == "explicit" && $0.reason == .unknownLineageID })
        }
    }
    func testFallbackKeepsPublicationOrderWithoutPicksRoundRobinOrLineageWinnerInference() {
        let p = publication([model("a1", developer: "a", lineage: "same"),
                             model("a2", developer: "a", lineage: "same"), model("b1", developer: "b")],
                            picks: [.init(modelID: "b1", kind: .strongest)])
        let result = ModelSelection.publicDefaults(publication: p, scope: .all)
        XCTAssertEqual(result.orderedIDs, ["a1", "a2", "b1"])
        XCTAssertTrue(result.models.allSatisfy { $0.origin == .publishedDefaultFallback })
    }
    func testPreviewOlderUnknownAndNonDefaultFlagsCannotEnterThePublicDirectory() {
        let p = publication([model("preview", status: "preview"), model("older", status: "older"),
            model("retired", status: "retired"), model("legacy", exclusion: .legacy),
            model("false", selected: false), model("unknown-default", selected: nil),
            model("unknown-status", status: nil), model("bad-status", status: "supported"), model("valid")])
        let result = ModelSelection.publicDefaults(publication: p, scope: .all)
        XCTAssertEqual(result.orderedIDs, ["valid"])
        XCTAssertTrue(result.issues.contains { $0.reason == .unknownGlobalDefault })
        XCTAssertTrue(result.issues.contains { $0.reason == .unknownLineageStatus })
    }
    func testDuplicatesDeduplicateAndConflictingIDsAbstainInsteadOfChoosingEligibleVariant() {
        let same = model("same")
        for conflict in [[model("conflict"), model("conflict", status: "older", selected: false)],
                         [model("conflict", status: "older", selected: false), model("conflict")]] {
            let result = ModelSelection.publicDefaults(publication: publication([same, same] + conflict + [model("")]), scope: .all)
            XCTAssertEqual(result.orderedIDs, ["same"])
            XCTAssertTrue(result.issues.contains { $0.modelID == "conflict" && $0.reason == .conflictingModelID })
            XCTAssertTrue(result.issues.contains { $0.reason == .invalidModelID })
        }
    }
    func testTenSixThreeCapsAndEmptyDirectoryContainOnlyPublishedIDs() {
        let models = (0..<13).map { model("m\($0)") }
        let result = ModelSelection.publicDefaults(publication: publication(models), scope: .all)
        XCTAssertEqual(result.orderedIDs, models.map(\.id))
        XCTAssertEqual(result.fieldIDs, Array(models.prefix(10).map(\.id)))
        XCTAssertEqual(result.chartIDs, Array(result.fieldIDs.prefix(6)))
        XCTAssertEqual(result.rowIDs, Array(result.chartIDs.prefix(3)))
        let empty = ModelSelection.publicDefaults(publication: publication([]), scope: .all)
        XCTAssertEqual(empty.orderedIDs, [])
        XCTAssertNil(empty.selectionRevision)
    }
    func testFallbackDoesNotRelaxOrdinarySelectionLineageOrAvailabilityProtection() {
        let m = SelectionModel(id: "explicit", developerID: "dev", lineageID: nil, lineageStatus: "current", defaultSelected: true)
        let p = publication([m])
        XCTAssertEqual(ModelSelection.publicDefaults(publication: p, scope: .all).orderedIDs, ["explicit"])
        let ordinary = ModelSelection.select(.init(scope: .all, publication: p,
            subscriptions: [.init(id: "s", availability: .available, offeredModelIDs: ["explicit"])], usage: [], now: referenceTime))
        XCTAssertEqual(ordinary.orderedIDs, [])
        XCTAssertTrue(ordinary.issues.contains { $0.reason == .unknownLineageID })
        let absent = ModelSelection.select(.init(scope: .all, publication: nil, subscriptions: [], usage: [], now: referenceTime))
        XCTAssertEqual(absent.orderedIDs, [])
        XCTAssertEqual(absent.issues.map(\.reason), [.publicationUnavailable])
    }
}
