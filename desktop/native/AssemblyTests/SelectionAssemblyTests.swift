// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCore
import ModelPlanSelection
import ModelPlanInstruments
@testable import ModelPlanAssembly

final class SelectionAssemblyTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    func joined(models: [[String: Any]], members: [[String: Any]] = [], revision: String? = "r",
                expiry: TimeInterval = 300, matches: Bool = true) throws -> JoinedSnapshot {
        var wire: [String: Any] = ["schemaVersion": 1, "publicationId": "p", "units": ["ability":"websiteAbility", "cost":"usdPerReferenceTask", "time":"taskTimeCrossModel"], "models": models,
            "lineups": [["developerId":"dev", "members":members]]]
        if let revision { wire["selectionRevision"] = revision }
        let pub = try JSONDecoder().decode(PublicPublication.self, from: JSONSerialization.data(withJSONObject: wire))
        let personal: [String: Any] = ["schemaVersion":1, "kind":"desktop", "generatedAt":ISO8601DateFormatter().string(from:now),
            "validUntil":ISO8601DateFormatter().string(from:now.addingTimeInterval(expiry)),
            "publication":["publicationId":matches ? "p":"other"],
            "subscriptions":[["subscriptionRef":"s", "sources":["codex"]]],
            "sessions":[["source":"codex", "model":["id":"x"], "observedAt":ISO8601DateFormatter().string(from:now)]]]
        let snapshot = try JSONDecoder().decode(PersonalSnapshot.self, from: JSONSerialization.data(withJSONObject: personal))
        var ledger = ExpiryLedger()
        return .make(personal:snapshot, presentation:.evaluate(snapshot, now:now, ledger:&ledger), publication:pub)
    }
    func model(_ id: String, status: String? = "current", selected: Bool? = true) -> [String: Any] {
        var row: [String: Any] = ["id":id, "developerId":"dev", "lineageId":"line-"+id]
        if let status { row["lineageStatus"] = status }
        if let selected { row["defaultSelected"] = selected }
        return row
    }
    func offering(_ ids: Set<String>?, freshness: InstrumentFreshness = .fresh) -> SubscriptionSelectionEvidence {
        .init(.init(id:"s", availability:.available, offeredModelIDs:ids), evidence:.init(observedAt:now, validUntil:now.addingTimeInterval(300), freshness:freshness))
    }
    func use(_ id: String, age: TimeInterval = 1, attribution: UsageAttribution = .verifiedSubscription) -> AttributedSelectionUsage {
        .init(.init(modelID:id, subscriptionID:"s", usedAt:now.addingTimeInterval(-age)), attribution:attribution,
              evidence:.init(observedAt:now, validUntil:now.addingTimeInterval(300)))
    }
    func testPublishedOrderIsInjectedOnceWithSameCapsAndStableHighlight() throws {
        let ids=(0..<13).map { "m"+String($0) };let source=try joined(models:ids.map { model($0) }, members:[["id":"m4", "tags":["strongest"]]])
        var assembly=SelectionAssembly()
        let r=assembly.evaluate(joined:source, scope:.all, subscriptions:[offering(Set(ids))], usage:[use("m7")], selectedID:"m12", now:now)
        XCTAssertEqual(Array(r.shared.orderedIDs.prefix(2)), ["m7","m4"])
        XCTAssertEqual(r.shared.fieldIDs.count,10);XCTAssertEqual(r.shared.chartIDs.count,6);XCTAssertEqual(r.shared.rowIDs.count,3)
        XCTAssertEqual(r.instruments?.orderedModelIDs,r.shared.orderedIDs);XCTAssertEqual(r.instruments?.selectedModelID,"m12")
        XCTAssertEqual(r.instruments?.recentUseAtByModel["m7"],now.addingTimeInterval(-1))
        XCTAssertNil(r.unavailableReason)
        let models = ids.map { InstrumentModel(id:$0, name:$0, efforts:[], recommended:nil, current:nil) }
        let page = EffortPagePresentation(models:models, selection:r.instruments, scope:.all,
            publication:.init(publicationID:"p",selectionRevision:"r"), publicationUsable:true)
        XCTAssertEqual(page.orderedModelIDs,r.shared.orderedIDs)
        XCTAssertEqual(page.selectedModelID,"m12");XCTAssertNil(page.unavailableReason)
    }
    func testRecentOlderSurvivesBothScopesWithoutPromotingFalseToRetirement() throws {
        let source=try joined(models:[model("old",status:"older",selected:false),model("new")]);var a=SelectionAssembly()
        for scope in [SelectionScope.all,.subscription("s")] {
            let r=a.evaluate(joined:source,scope:scope,subscriptions:[offering(["old","new"])],usage:[use("old")],now:now)
            XCTAssertEqual(r.shared.orderedIDs,["old","new"]);XCTAssertTrue(r.shared.models[0].isOlder)
            XCTAssertEqual(r.shared.models[0].model.defaultSelected,false);XCTAssertEqual(r.instruments?.orderedModelIDs,r.shared.orderedIDs)
        }
    }
    func testBindingsCurrentConfigurationAndMissingOfferingsDoNotInventSelectionOrUsage() throws {
        let source=try joined(models:[model("x"),model("old",status:"older")]);var a=SelectionAssembly()
        for subs in [[],[offering(nil)],[offering(["x"],freshness:.stale)]] {
            let r=a.evaluate(joined:source,scope:.all,subscriptions:subs,usage:[],now:now)
            XCTAssertTrue(r.shared.orderedIDs.isEmpty);XCTAssertNotNil(r.unavailableReason)
        }
        let r=a.evaluate(joined:source,scope:.all,subscriptions:[offering(["x","old"])],usage:[use("old",attribution:.sourceWideCurrentBinding)],now:now)
        XCTAssertEqual(r.shared.orderedIDs,["x"])
    }
    func testExpiryLatchesAcrossRetainedJoinAndClockRollback() throws {
        let source=try joined(models:[model("x")],expiry:10);var a=SelectionAssembly()
        let offer=SubscriptionSelectionEvidence(.init(id:"s",availability:.available,offeredModelIDs:["x"]),evidence:.init(observedAt:now))
        XCTAssertEqual(a.evaluate(joined:source,scope:.all,subscriptions:[offer],usage:[],now:now).shared.orderedIDs,["x"])
        for time in [now.addingTimeInterval(10),now] {
            let r=a.evaluate(joined:source,scope:.all,subscriptions:[offer],usage:[],now:time)
            XCTAssertTrue(r.shared.orderedIDs.isEmpty);XCTAssertNotNil(r.unavailableReason)
        }
    }
    func testJoinMismatchAndMissingRevisionCannotBecomeTrustedInstrumentSelection() throws {
        var a=SelectionAssembly()
        for source in [try joined(models:[model("x")],matches:false),try joined(models:[model("x")],revision:nil)] {
            let r=a.evaluate(joined:source,scope:.all,subscriptions:[offering(["x"])],usage:[],now:now)
            XCTAssertNotNil(r.unavailableReason)
            if let injected=r.instruments { XCTAssertNotNil(injected.unavailableReason) }
        }
    }
    func testNullableFlagsAreNotInferredFromCurrentNamesScoresOrPicks() throws {
        var row=model("x",status:nil,selected:nil);row["current"]=true;row["name"]="Newest";row["ability"]=100
        let source=try joined(models:[row],members:[["id":"x","tags":["strongest"]]]);var a=SelectionAssembly()
        let r=a.evaluate(joined:source,scope:.all,subscriptions:[offering(["x"])],usage:[use("x")],now:now)
        XCTAssertTrue(r.shared.orderedIDs.isEmpty);XCTAssertTrue(r.shared.issues.contains { $0.reason == .unknownLineageStatus })
    }
    func testExplicitDominanceAndConflictingContextsAreNotRecomputed() throws {
        let source=try joined(models:[model("tail"),model("regular"),model("ambiguous")],members:[
            ["id":"tail","tags":["strongest"],"dominatedBy":["id":"regular","kind":"equivalent"]],
            ["id":"ambiguous","dominatedBy":["id":"regular","kind":"weaker"]], ["id":"ambiguous"]]);var a=SelectionAssembly()
        let r=a.evaluate(joined:source,scope:.all,subscriptions:[offering(["tail","regular","ambiguous"])],usage:[],now:now)
        XCTAssertEqual(r.shared.orderedIDs,["regular","tail"]);XCTAssertEqual(r.shared.models.last?.model.placement,.pricierTwin)
        XCTAssertTrue(r.shared.issues.contains { $0.modelID == "ambiguous" && $0.reason == .conflictingModelID })
    }
}
