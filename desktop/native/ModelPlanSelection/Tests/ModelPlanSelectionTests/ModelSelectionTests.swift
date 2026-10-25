// SPDX-License-Identifier: MIT
import Foundation
import XCTest
@testable import ModelPlanSelection

let referenceTime = Date(timeIntervalSince1970: 1_700_000_000)
func model(_ id: String, developer: String? = "dev", lineage: String? = nil, status: String? = "current",
           selected: Bool? = true, placement: PublishedPlacement = .unspecified,
           exclusion: PublishedExclusion? = nil) -> SelectionModel {
    SelectionModel(id: id, developerID: developer, lineageID: lineage ?? "line-" + id,
        lineageStatus: status, defaultSelected: selected, exclusion: exclusion, placement: placement)
}
func use(_ id: String, age: TimeInterval, subscription: String = "s") -> SelectionUsage {
    .init(modelID: id, subscriptionID: subscription, usedAt: referenceTime.addingTimeInterval(-age))
}
func selection(_ models: [SelectionModel], picks: [PublishedPick] = [], usage: [SelectionUsage] = [],
               scope: SelectionScope = .all, subscriptions: [SelectionSubscription]? = nil) -> SharedModelSelection {
    ModelSelection.select(.init(scope: scope,
        publication: .init(publicationID: "synthetic", selectionRevision: "published-selection", models: models, picks: picks),
        subscriptions: subscriptions ?? [.init(id: "s", availability: .available, offeredModelIDs: Set(models.map(\.id)))],
        usage: usage, now: referenceTime))
}

final class ModelSelectionTests: XCTestCase {
    func testOneFourSevenAndThirteenSubscriptionsHaveIdenticalTenSixThreePrefixes() {
        for count in [1, 4, 7, 13] {
            let models = (0..<(count * 2)).map { model("m\($0)", developer: "dev\($0 % 3)") }
            let subscriptions = (0..<count).map { n in
                SelectionSubscription(id: "s\(n)", availability: .available, offeredModelIDs: ["m\(n * 2)", "m\(n * 2 + 1)"])
            }
            let result = selection(models, subscriptions: subscriptions)
            XCTAssertEqual(result.orderedIDs.count, count * 2)
            XCTAssertEqual(Set(result.orderedIDs).count, count * 2)
            XCTAssertEqual(result.fieldIDs, Array(result.orderedIDs.prefix(10)))
            XCTAssertEqual(result.chartIDs, Array(result.fieldIDs.prefix(6)))
            XCTAssertEqual(result.rowIDs, Array(result.chartIDs.prefix(3)))
            for subscription in subscriptions {
                let scoped = selection(models, scope: .subscription(subscription.id), subscriptions: subscriptions)
                XCTAssertEqual(Set(scoped.orderedIDs), subscription.offeredModelIDs ?? [])
                XCTAssertEqual(scoped.rowIDs, scoped.orderedIDs)
            }
        }
    }
    func testOrderUsesRecentThreeThenPublishedPicksThenRoundRobinThenPublishedTail() {
        let models = [model("a1", developer: "a"), model("a2", developer: "a"),
                      model("b1", developer: "b"), model("b2", developer: "b"),
                      model("c1", developer: "c"), model("c2", developer: "c"), model("d1", developer: "d"),
                      model("tail1", placement: .dominated), model("tail2", placement: .pricierTwin)]
        let result = selection(models, picks: [.init(modelID: "b1", kind: .cheapest),
            .init(modelID: "a1", kind: .bestValue), .init(modelID: "c2", kind: .strongest)],
            usage: [use("d1", age: 4), use("b2", age: 3), use("c1", age: 1), use("a2", age: 2)])
        XCTAssertEqual(result.orderedIDs, ["c1", "a2", "b2", "c2", "a1", "b1", "d1", "tail1", "tail2"])
        XCTAssertEqual(result.models[3].origin, .publishedPick(.strongest))
        XCTAssertEqual(result.models[4].origin, .publishedPick(.bestValue))
        XCTAssertEqual(result.models.last?.origin, .publishedTail)
    }
    func testRoundRobinPreservesPublishedDeveloperAndWithinDeveloperOrder() {
        let models = [model("a1", developer: "a"), model("b1", developer: "b"), model("c1", developer: "c"),
                      model("a2", developer: "a"), model("b2", developer: "b"), model("c2", developer: "c"), model("a3", developer: "a")]
        XCTAssertEqual(selection(models).orderedIDs, ["a1", "b1", "c1", "a2", "b2", "c2", "a3"])
        XCTAssertEqual(selection(models, picks: [.init(modelID: "a1", kind: .strongest)]).orderedIDs,
                       ["a1", "a2", "b1", "c1", "a3", "b2", "c2"])
    }
    func testRecentUsageWinsFirstStageEvenWhenPublishedDominatedAndPicksNeverInventModels() {
        let models = [model("regular"), model("tail", placement: .dominated)]
        let result = selection(models, picks: [.init(modelID: "missing", kind: .strongest),
            .init(modelID: "tail", kind: .cheapest)], usage: [use("tail", age: 1)])
        XCTAssertEqual(result.orderedIDs, ["tail", "regular"])
        XCTAssertEqual(result.models[0].origin, .recentUsage(referenceTime.addingTimeInterval(-1)))
        XCTAssertEqual(selection(models, picks: [.init(modelID: "tail", kind: .strongest)]).orderedIDs, ["regular", "tail"])
    }
    func testUsageDedupAndTiesAreStableByPublicationRatherThanUsageArrayOrder() {
        let models = [model("z"), model("a"), model("b"), model("c")]
        let uses = [use("a", age: 5), use("z", age: 5), use("z", age: 20), use("b", age: 6), use("c", age: 7)]
        XCTAssertEqual(selection(models, usage: uses).orderedIDs, ["z", "a", "b", "c"])
        XCTAssertEqual(selection(models, usage: Array(uses.reversed())).orderedIDs, ["z", "a", "b", "c"])
    }
    func testSevenDaysIsInclusiveElapsedTimeWithFutureAndExpiredUsageExcluded() {
        let week = ModelSelection.recentUseInterval
        let models = [model("current", lineage: "line"), model("boundary", lineage: "line", status: "older", selected: false),
                      model("expired", status: "older", selected: false), model("future", status: "older", selected: false)]
        let result = selection(models, usage: [use("boundary", age: week), use("expired", age: week + 0.001), use("future", age: -0.001)])
        XCTAssertEqual(result.orderedIDs, ["boundary", "current"])
        XCTAssertTrue(result.models[0].isOlder)
        XCTAssertEqual(result.models[0].model.defaultSelected, false)
        XCTAssertTrue(result.issues.contains { $0.modelID == "expired" && $0.reason == .olderNotRecentlyUsed })
        XCTAssertTrue(result.issues.contains { $0.modelID == "future" && $0.reason == .invalidUsageTime })
    }
    func testAllAndSingleSubscriptionRetainRecentOlderAndDropExpiredWithTheSameBadge() {
        let models = [model("current", lineage: "line"), model("old", lineage: "line", status: "older", selected: false)]
        for scope in [SelectionScope.all, .subscription("s")] {
            let result = selection(models, usage: [use("old", age: 1)], scope: scope)
            XCTAssertEqual(result.orderedIDs, ["old", "current"])
            XCTAssertTrue(result.models[0].isOlder)
            XCTAssertEqual(result.models[0].model.defaultSelected, false)
            let boundary = selection(models, usage: [use("old", age: ModelSelection.recentUseInterval)], scope: scope)
            XCTAssertEqual(boundary.orderedIDs, ["old", "current"])
            let expired = selection(models, usage: [use("old", age: ModelSelection.recentUseInterval + 0.001)], scope: scope)
            XCTAssertEqual(expired.orderedIDs, ["current"])
        }
    }
    func testOlderExceptionNeedsActualUsageThroughAnAvailableSubscriptionInTheChosenScope() {
        let models = [model("current"), model("old", status: "older", selected: false)]
        let subscriptions: [SelectionSubscription] = [
            .init(id: "a", availability: .available, offeredModelIDs: ["current", "old"]),
            .init(id: "b", availability: .available, offeredModelIDs: ["old"]),
            .init(id: "off", availability: .unavailable, offeredModelIDs: ["old"])]
        let uses = [use("old", age: 1, subscription: "b"), use("old", age: 0, subscription: "off")]
        XCTAssertEqual(selection(models, usage: uses, subscriptions: subscriptions).orderedIDs, ["old", "current"])
        XCTAssertEqual(selection(models, usage: uses, scope: .subscription("a"), subscriptions: subscriptions).orderedIDs, ["current"])
        let scoped = selection(models, usage: uses, scope: .subscription("b"), subscriptions: subscriptions)
        XCTAssertEqual(scoped.orderedIDs, ["old"])
        XCTAssertTrue(scoped.models[0].isOlder)
    }
    func testKnownFalseIsNotRetirementAndUnknownIsNotTrue() {
        let models = [model("false", selected: false), model("unknown", selected: nil)]
        let global = selection(models, usage: [use("false", age: 1)])
        XCTAssertEqual(global.orderedIDs, [])
        XCTAssertTrue(global.issues.contains { $0.modelID == "false" && $0.reason == .notGlobalDefault })
        XCTAssertTrue(global.issues.contains { $0.modelID == "unknown" && $0.reason == .unknownGlobalDefault })
        XCTAssertFalse(global.issues.contains { $0.reason == .retired })
        let scoped = selection(models, scope: .subscription("s"))
        XCTAssertEqual(scoped.orderedIDs, ["false", "unknown"])
        XCTAssertEqual(scoped.models[0].model.defaultSelected, false)
        XCTAssertNil(scoped.models[1].model.defaultSelected)
    }
    func testPreviewRetiredAndExplicitLegacyNeverQualifyEvenWithRecentUseAndPicks() {
        let models = [model("preview", status: "preview"), model("retired", status: "retired"),
                      model("legacy", exclusion: .legacy), model("current")]
        let result = selection(models, picks: models.map { .init(modelID: $0.id, kind: .strongest) },
                               usage: models.map { use($0.id, age: 1) })
        XCTAssertEqual(result.orderedIDs, ["current"])
        XCTAssertTrue(result.issues.contains { $0.reason == .preview })
        XCTAssertTrue(result.issues.contains { $0.reason == .retired })
        XCTAssertTrue(result.issues.contains { $0.reason == .legacy })
    }
    func testMissingLineageCannotBeReconstructedFromPicksOrUnsupportedStatus() {
        let missing = SelectionModel(id: "x", developerID: "dev", lineageID: nil, lineageStatus: nil, defaultSelected: true)
        let result = selection([missing, model("y", status: "supported"), model("ok")],
                               picks: [.init(modelID: "x", kind: .strongest)], usage: [use("x", age: 1)])
        XCTAssertEqual(result.orderedIDs, ["ok"])
        XCTAssertTrue(result.issues.contains { $0.reason == .unknownLineageID })
        XCTAssertTrue(result.issues.contains { $0.reason == .unknownLineageStatus })
        XCTAssertTrue(result.issues.contains { $0.reason == .unsupportedLineageStatus })
    }
    func testDuplicateIDsAndAmbiguousCurrentLineagesAbstainWithoutVersionGuessing() {
        let repeated = model("same")
        XCTAssertEqual(selection([repeated, repeated]).orderedIDs, ["same"])
        let conflict = selection([repeated, model("same", status: "retired"), model("ok")])
        XCTAssertEqual(conflict.orderedIDs, ["ok"])
        XCTAssertTrue(conflict.issues.contains { $0.reason == .conflictingModelID })
        let ambiguous = selection([model("v1", lineage: "line"), model("v999", lineage: "line")])
        XCTAssertEqual(ambiguous.orderedIDs, [])
        XCTAssertEqual(ambiguous.issues.filter { $0.reason == .ambiguousCurrentLineage }.count, 2)
    }
    func testOnlyAvailableScopedAttributedUsageCounts() {
        let models = [model("a"), model("b")]
        let subscriptions: [SelectionSubscription] = [
            .init(id: "s", availability: .available, offeredModelIDs: ["a"]),
            .init(id: "other", availability: .available, offeredModelIDs: ["b"]),
            .init(id: "off", availability: .unavailable, offeredModelIDs: ["b"]),
            .init(id: "unknown", availability: .unknown, offeredModelIDs: ["b"])]
        let result = selection(models, usage: [use("b", age: 1, subscription: "other"), use("a", age: 1, subscription: "off")],
                               scope: .subscription("s"), subscriptions: subscriptions)
        XCTAssertEqual(result.orderedIDs, ["a"])
        XCTAssertEqual(result.models[0].origin, .developerRoundRobin)
    }
    func testUnknownOfferingsConflictingSubscriptionsAndUnknownScopeDoNotFallBackToAll() {
        let models = [model("a")]
        let unknown: [SelectionSubscription] = [.init(id: "s", availability: .available, offeredModelIDs: nil)]
        XCTAssertTrue(selection(models, subscriptions: unknown).orderedIDs.isEmpty)
        let conflicts: [SelectionSubscription] = [.init(id: "s", availability: .available, offeredModelIDs: ["a"]),
            .init(id: "s", availability: .unavailable, offeredModelIDs: ["a"])]
        XCTAssertTrue(selection(models, subscriptions: conflicts).issues.contains { $0.reason == .conflictingSubscriptionID })
        let result = selection(models, scope: .subscription("missing"))
        XCTAssertTrue(result.orderedIDs.isEmpty)
        XCTAssertTrue(result.issues.contains { $0.reason == .unknownScope })
    }
    func testKnownEmptyOfferingsAndInvalidModelIDsNeverInventACandidate() {
        XCTAssertTrue(selection([model("valid")], subscriptions: []).orderedIDs.isEmpty)
        let empty: [SelectionSubscription] = [.init(id: "s", availability: .available, offeredModelIDs: [])]
        let knownEmpty = selection([model("valid")], subscriptions: empty)
        XCTAssertTrue(knownEmpty.orderedIDs.isEmpty)
        XCTAssertFalse(knownEmpty.issues.contains { $0.reason == .offeringsUnknown })
        let invalid = selection([model("")])
        XCTAssertTrue(invalid.orderedIDs.isEmpty)
        XCTAssertTrue(invalid.issues.contains { $0.reason == .invalidModelID })
    }
    func testNoDataAndInvalidClockAbstain() {
        let none = ModelSelection.select(.init(scope: .all, publication: nil, subscriptions: [], usage: [], now: referenceTime))
        XCTAssertEqual(none.orderedIDs, [])
        XCTAssertEqual(none.issues.map(\.reason), [.publicationUnavailable])
        let invalid = ModelSelection.select(.init(scope: .all,
            publication: .init(publicationID: "p", selectionRevision: nil, models: [], picks: []), subscriptions: [], usage: [],
            now: Date(timeIntervalSinceReferenceDate: .nan)))
        XCTAssertEqual(invalid.issues.map(\.reason), [.invalidReferenceTime])
    }
    func testSelectionOfRanksFourThroughTenDoesNotReorderRowsAndScopeRecomputesOneSharedResult() {
        let models = (0..<13).map { model("m\($0)") }
        let result = selection(models)
        var state = ModelSelectionState(selection: result)
        for id in result.fieldIDs.dropFirst(3) {
            XCTAssertTrue(state.select(id))
            XCTAssertEqual(state.selectedID, id)
            XCTAssertEqual(state.selection.rowIDs, result.rowIDs)
            XCTAssertEqual(state.selection.orderedIDs, result.orderedIDs)
        }
        XCTAssertFalse(state.select("missing"))
        let narrow = selection(models, scope: .subscription("s"), subscriptions: [.init(id: "s", availability: .available, offeredModelIDs: ["m12"])])
        state.replace(narrow)
        XCTAssertNil(state.selectedID)
        XCTAssertEqual(state.selection.rowIDs, ["m12"])
        state.replace(result)
        XCTAssertEqual(state.selection.rowIDs, result.rowIDs)
    }
}
