// SPDX-License-Identifier: MIT
import Foundation
import XCTest
@testable import ModelPlanSelection

final class PublicFleetTests: XCTestCase {
    func missing(_ id: String) -> SelectionModel {
        .init(id: id, developerID: "dev", lineageID: nil, lineageStatus: "current", defaultSelected: true)
    }
    func input(_ models: [SelectionModel], scope: SelectionScope = .all, usage: [SelectionUsage] = [],
               windows: [SelectionWindowUsage] = [], picks: [PublishedPick] = [],
               subscriptions: [SelectionSubscription]? = nil) -> SelectionInput {
        .init(scope: scope, publication: .init(publicationID: "p", selectionRevision: nil, models: models, picks: picks),
              subscriptions: subscriptions ?? [.init(id: "s", availability: .available, offeredModelIDs: Set(models.map(\.id)))],
              usage: usage, windowUsage: windows, now: referenceTime)
    }
    func testCompleteDefaultFleetSurvivesOneMissingLineageAndPartialNormalResult() {
        let value = input([model("a"), missing("b")])
        XCTAssertEqual(ModelSelection.select(value).orderedIDs, ["a"])
        let result = ModelSelection.selectPublicFleet(value)
        XCTAssertEqual(result.orderedIDs, ["a", "b"])
        XCTAssertEqual(result.models[0].origin, .developerRoundRobin)
        XCTAssertEqual(result.models[1].origin, .publishedDefaultFallback)
        XCTAssertNil(result.models[1].model.lineageID)
        XCTAssertNil(result.selectionRevision)
        XCTAssertEqual(result.issues.filter { $0.modelID == "b" && $0.reason == .unknownLineageID }.count, 1)
    }
    func testTwoSameLineageDefaultsAndThirdDefaultAreAllRetainedWithoutChoosingAWinner() {
        let value = input([model("first", lineage: "same"), model("second", lineage: "same"), model("third")])
        XCTAssertEqual(ModelSelection.select(value).orderedIDs, ["third"])
        let result = ModelSelection.selectPublicFleet(value)
        XCTAssertEqual(result.orderedIDs, ["third", "first", "second"])
        XCTAssertTrue(result.models.dropFirst().allSatisfy { $0.origin == .publishedDefaultFallback })
        XCTAssertEqual(result.issues.filter { $0.reason == .ambiguousCurrentLineage }.count, 2)
    }
    func testWindowOlderAndExactNormalOrderCoexistWithMissingMetadataDefaults() {
        let value = input([model("a"), missing("b"), model("c"), model("older", status: "older", selected: false)],
            usage: [use("c", age: 10)], windows: [.init(modelID: "older", subscriptionID: "s")],
            picks: [.init(modelID: "a", kind: .strongest)])
        let normal = ModelSelection.select(value)
        XCTAssertEqual(normal.orderedIDs, ["c", "older", "a"])
        let result = ModelSelection.selectPublicFleet(value)
        XCTAssertEqual(result.orderedIDs, ["c", "older", "a", "b"])
        XCTAssertEqual(Array(result.models.prefix(normal.models.count)), normal.models)
        XCTAssertEqual(result.models[1].origin, .recentWindow)
        XCTAssertTrue(result.models[1].isOlder)
    }
    func testCapsPublicationSupplementOrderStableDedupAndNoPersonalOfferingsRequiredForDefaults() {
        let models = (0..<13).map { $0.isMultiple(of: 2) ? model("m\($0)") : missing("m\($0)") }
        let value = input(models + [models[0], models[1]], subscriptions: [])
        let result = ModelSelection.selectPublicFleet(value)
        XCTAssertEqual(result.orderedIDs, models.map(\.id))
        XCTAssertEqual(result, ModelSelection.selectPublicFleet(value))
        XCTAssertEqual(Set(result.orderedIDs).count, 13)
        XCTAssertEqual(result.fieldIDs, Array(result.orderedIDs.prefix(10)))
        XCTAssertEqual(result.chartIDs, Array(result.fieldIDs.prefix(6)))
        XCTAssertEqual(result.rowIDs, Array(result.chartIDs.prefix(3)))
    }
    func testConflictingIDsAbstainAndIneligibleOlderOrNonDefaultsCannotBeAdded() {
        let value = input([model("valid"), model("conflict"), model("conflict", status: "older", selected: false),
            model("unused-old", status: "older", selected: false), model("false", selected: false),
            model("preview", status: "preview"), model("retired", status: "retired")])
        let result = ModelSelection.selectPublicFleet(value)
        XCTAssertEqual(result.orderedIDs, ["valid"])
        XCTAssertEqual(result.issues.filter { $0.modelID == "conflict" && $0.reason == .conflictingModelID }.count, 1)
    }
    func testSingleSubscriptionIsExactlyOrdinarySelectionIncludingItsDiagnosticsAndOrigins() {
        for scope in [SelectionScope.subscription("s"), .subscription("unknown")] {
            let value = input([model("a"), missing("b"), model("older", status: "older", selected: false)],
                              scope: scope, windows: [.init(modelID: "older", subscriptionID: "s")])
            XCTAssertEqual(ModelSelection.selectPublicFleet(value), ModelSelection.select(value))
        }
    }
    func testMissingRealPublicationStaysUnavailableAndEmptyPublicationStaysEmpty() {
        let none = SelectionInput(scope: .all, publication: nil, subscriptions: [], usage: [], now: referenceTime)
        XCTAssertEqual(ModelSelection.selectPublicFleet(none), ModelSelection.select(none))
        XCTAssertEqual(ModelSelection.selectPublicFleet(none).issues.map(\.reason), [.publicationUnavailable])
        XCTAssertEqual(ModelSelection.selectPublicFleet(input([])).orderedIDs, [])
    }
}
