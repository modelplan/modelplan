// SPDX-License-Identifier: MIT
import Foundation
import XCTest
@testable import ModelPlanSelection

final class WindowUsageTests: XCTestCase {
    func window(_ id: String, _ subscription: String = "s") -> SelectionWindowUsage {
        .init(modelID: id, subscriptionID: subscription)
    }
    func choose(_ models: [SelectionModel], windows: [SelectionWindowUsage], usage: [SelectionUsage] = [],
                scope: SelectionScope = .all, subscriptions: [SelectionSubscription]? = nil,
                now: Date = referenceTime) -> SharedModelSelection {
        ModelSelection.select(.init(scope: scope,
            publication: .init(publicationID: "synthetic", selectionRevision: "r", models: models, picks: []),
            subscriptions: subscriptions ?? [.init(id: "s", availability: .available, offeredModelIDs: Set(models.map(\.id)))],
            usage: usage, windowUsage: windows, now: now))
    }
    func testExistingInitializerDefaultsToNoWindowEvidence() {
        let input = SelectionInput(scope: .all, publication: nil, subscriptions: [], usage: [], now: referenceTime)
        XCTAssertEqual(input.windowUsage, [])
        XCTAssertEqual(ModelSelection.select(input).orderedIDs, [])
    }
    func testBothScopesRetainOlderWithoutInventingAnEventDate() {
        let models = [model("current"), model("older", status: "older", selected: false)]
        for scope in [SelectionScope.all, .subscription("s")] {
            for now in [referenceTime, referenceTime.addingTimeInterval(30 * 24 * 3600)] {
                // Each supplied tuple asserts a fresh verified summary at evaluation time, not a cached event.
                let result = choose(models, windows: [window("older")], scope: scope, now: now)
                XCTAssertEqual(result.orderedIDs, ["older", "current"])
                XCTAssertEqual(result.models[0].origin, .recentWindow)
                XCTAssertTrue(result.models[0].isOlder)
                XCTAssertEqual(result.models[0].model.defaultSelected, false)
            }
        }
    }
    func testExactEventsComeBeforeWindowMembersAndRetainTheirActualTimes() {
        let models = [model("window-first"), model("exact-old"), model("window-second"), model("exact-new")]
        let uses = [use("exact-old", age: 20), use("exact-new", age: 10)]
        let result = choose(models, windows: [window("window-second"), window("window-first"), window("exact-old")], usage: uses)
        XCTAssertEqual(Array(result.orderedIDs.prefix(3)), ["exact-new", "exact-old", "window-first"])
        XCTAssertEqual(result.models[0].origin, .recentUsage(referenceTime.addingTimeInterval(-10)))
        XCTAssertEqual(result.models[1].origin, .recentUsage(referenceTime.addingTimeInterval(-20)))
        XCTAssertEqual(result.models[2].origin, .recentWindow)
        XCTAssertEqual(result.models[3].origin, .developerRoundRobin)
    }
    func testThreeExactEventsExhaustTheUsedStageButWindowOlderRemainsEligible() {
        let models = [model("older", status: "older", selected: false), model("a"), model("b"), model("c")]
        let result = choose(models, windows: [window("older")], usage: [use("a", age: 1), use("b", age: 2), use("c", age: 3)])
        XCTAssertEqual(result.orderedIDs, ["a", "b", "c", "older"])
        XCTAssertEqual(result.models.last?.origin, .developerRoundRobin)
        XCTAssertTrue(result.models.last!.isOlder)
        XCTAssertFalse(result.models.contains { $0.origin == .recentWindow })
    }
    func testUntimedWindowOrderIsPublishedOrderRegardlessOfTupleOrderOrDuplicates() {
        let models = (0..<13).map { model("m\($0)", developer: "d\($0 % 3)") }
        let windows = models.reversed().map { window($0.id) }
        let result = choose(models, windows: windows + [window("m0"), window("m1")])
        XCTAssertEqual(result, choose(models, windows: Array(windows.reversed())))
        XCTAssertEqual(result.rowIDs, ["m0", "m1", "m2"])
        XCTAssertTrue(result.models.prefix(3).allSatisfy { $0.origin == .recentWindow })
        XCTAssertFalse(result.models.dropFirst(3).contains { $0.origin == .recentWindow })
        XCTAssertEqual(result.fieldIDs, Array(result.orderedIDs.prefix(10)))
        XCTAssertEqual(result.chartIDs, Array(result.fieldIDs.prefix(6)))
        XCTAssertEqual(Set(result.orderedIDs).count, 13)
    }
    func testUnknownOutOfScopeAndUnofferedTuplesDoNotProveTheExceptionOrRemoveDefaults() {
        let models = [model("base"), model("older", status: "older", selected: false)]
        let subscriptions: [SelectionSubscription] = [
            .init(id: "a", availability: .available, offeredModelIDs: ["base", "older", "unpublished"]),
            .init(id: "b", availability: .available, offeredModelIDs: ["base"])]
        let invalid = [window("older", "unknown"), window("older", "b"), window("unpublished", "a")]
        let result = choose(models, windows: invalid, scope: .subscription("a"), subscriptions: subscriptions)
        XCTAssertEqual(result.orderedIDs, ["base"])
        XCTAssertEqual(result.models[0].origin, .developerRoundRobin)
        XCTAssertTrue(result.issues.contains { $0.reason == .modelNotPublished })
        let bothOffer: [SelectionSubscription] = [subscriptions[0], .init(id: "b", availability: .available, offeredModelIDs: ["older"])]
        XCTAssertEqual(choose(models, windows: [window("older", "b")], subscriptions: bothOffer).orderedIDs, ["older", "base"])
        XCTAssertEqual(choose(models, windows: [window("older", "b")], scope: .subscription("a"), subscriptions: bothOffer).orderedIDs, ["base"])
    }
    func testUnavailableUnknownOrMissingOfferingsCannotSupplyWindowUse() {
        let models = [model("base"), model("older", status: "older", selected: false)]
        for unavailable in [SelectionSubscription(id: "b", availability: .unavailable, offeredModelIDs: ["older"]),
                            .init(id: "b", availability: .unknown, offeredModelIDs: ["older"]),
                            .init(id: "b", availability: .available, offeredModelIDs: nil),
                            .init(id: "b", availability: .available, offeredModelIDs: [])] {
            let subscriptions = [SelectionSubscription(id: "s", availability: .available, offeredModelIDs: ["base", "older"]), unavailable]
            XCTAssertEqual(choose(models, windows: [window("older", "b")], subscriptions: subscriptions).orderedIDs, ["base"])
        }
    }
    func testWindowEvidenceDoesNotOverridePublishedEligibilityOrGuessUnknownLineage() {
        let unknown = SelectionModel(id: "unknown", developerID: "dev", lineageID: nil, lineageStatus: nil, defaultSelected: true)
        let models = [model("false", selected: false), model("nil", selected: nil), unknown,
                      model("preview", status: "preview"), model("retired", status: "retired"),
                      model("legacy", exclusion: .legacy), model("base")]
        let windows = models.map { window($0.id) }
        XCTAssertEqual(choose(models, windows: windows).orderedIDs, ["base"])
        let single = choose(models, windows: windows, scope: .subscription("s"))
        XCTAssertEqual(single.orderedIDs, ["false", "nil", "base"])
        XCTAssertEqual(single.models[0].model.defaultSelected, false)
        XCTAssertNil(single.models[1].model.defaultSelected)
    }
    func testExpiredExactTimeAndVerifiedWindowMembershipRemainDifferentKindsOfEvidence() {
        let models = [model("base"), model("older", status: "older", selected: false)]
        let expired = use("older", age: ModelSelection.recentUseInterval + 1)
        XCTAssertEqual(choose(models, windows: [], usage: [expired]).orderedIDs, ["base"])
        let result = choose(models, windows: [window("older")], usage: [expired])
        XCTAssertEqual(result.orderedIDs, ["older", "base"])
        XCTAssertEqual(result.models[0].origin, .recentWindow)
    }
}
