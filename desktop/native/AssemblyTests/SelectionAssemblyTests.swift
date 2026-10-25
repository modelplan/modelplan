// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCore
import ModelPlanSelection
import ModelPlanInstruments
@testable import ModelPlanAssembly

final class SelectionAssemblyTests: XCTestCase {
    let now = Date(timeIntervalSince1970:1_700_000_000)
    func model(_ id:String,status:String?="current",selected:Bool?=true,sources:[String]=["codex"],lineage:Bool=true) -> [String:Any] {
        var m:[String:Any] = ["id":id,"developerId":"dev","name":id,
            "harnessIds":Dictionary(uniqueKeysWithValues:sources.map { ($0,["native-"+id]) })]
        if let status { m["lineageStatus"]=status };if let selected { m["defaultSelected"]=selected }
        if lineage { m["lineageId"]="line-"+id };return m
    }
    func publicationData(_ models:[[String:Any]],revision:String?="r",members:[[String:Any]]=[]) throws -> Data {
        var p:[String:Any] = ["schemaVersion":1,"publicationId":"p",
            "units":["ability":"websiteAbility","cost":"usdPerReferenceTask","time":"taskTimeCrossModel"],
            "models":models,"lineups":[["developerId":"dev","members":members]]]
        if let revision { p["selectionRevision"]=revision };return try JSONSerialization.data(withJSONObject:p)
    }
    func binding(_ id:String,_ source:String="codex") -> [String:Any] { ["subscriptionRef":id,"sources":[source]] }
    func session(_ model:String,owner:String?=nil,source:String="codex",tokens:Int=5) -> [String:Any] {
        var s:[String:Any] = ["ref":"session-"+model,"source":source,
            "lastAt":ISO8601DateFormatter().string(from:now.addingTimeInterval(-60)),
            "configs":[["model":model,"observedOutputTokens":tokens]]]
        if let owner { s["subscriptionRef"]=owner };return s
    }
    func feeds(_ models:[[String:Any]],bindings:[[String:Any]]?=nil,sessions:[[String:Any]]=[],
               personal:Bool=true,usable:Bool=true,revision:String?="r",expiry:TimeInterval=300,
               members:[[String:Any]]=[],lastGood:Bool=false) throws -> ModelSelectionFeeds {
        let pub=try FeedDecoder.publication(publicationData(models,revision:revision,members:members))
        var snapshot:PersonalSnapshot?
        if personal {
            let value:[String:Any] = ["schemaVersion":1,"kind":"modelplan.personal-snapshot",
                "generatedAt":ISO8601DateFormatter().string(from:now),
                "validUntil":ISO8601DateFormatter().string(from:now.addingTimeInterval(expiry)),
                "publication":["publicationId":"p"],"subscriptions":bindings ?? [binding("s")],
                "sessionRanking":["measure":"observed-output-tokens","recent7d":["top":sessions]]]
            snapshot=try FeedDecoder.personal(JSONSerialization.data(withJSONObject:value))
        }
        return .init(publication:pub,personal:snapshot,personalUsable:usable,publicIsLastGood:lastGood)
    }
    func testAllUsesPublicDefaultsWithoutEntitlementAndOnlyAddsRecentOlder() throws {
        let f=try feeds([model("default"),model("not-global",selected:false),model("old",status:"older",selected:false),model("preview",status:"preview")],
            sessions:[session("native-old",owner:"s"),session("native-not-global",owner:"s")])
        var a=SelectionAssembly();let r=a.evaluate(feeds:f,scope:.all,now:now)
        XCTAssertEqual(Set(r.shared.orderedIDs),["default","old"])
        XCTAssertTrue(r.shared.models.first { $0.id=="old" }?.isOlder == true)
        XCTAssertTrue(r.instruments?.recentUseAtByModel.isEmpty == true) // Window membership is not an exact model timestamp.
    }
    func testSingleUsesHarnessCompatibilityPlusActualUseAndLabelsNoEntitlement() throws {
        let f=try feeds([model("global",sources:["other"]),model("tool",selected:false),model("observed",selected:false,sources:[])],
            sessions:[session("observed",owner:"s")])
        var a=SelectionAssembly();let r=a.evaluate(feeds:f,scope:.subscription("s"),now:now)
        XCTAssertEqual(Set(r.shared.orderedIDs),["tool","observed"])
        XCTAssertEqual(r.modelAvailabilityNotes["tool"],"该工具可用")
        XCTAssertEqual(r.modelAvailabilityNotes["observed"],"实际用过")
        XCTAssertFalse(r.publicDefaultFallback);XCTAssertEqual(r.effortPage?.orderedModelIDs,r.shared.orderedIDs)
        XCTAssertEqual(r.effortPage?.modelAvailabilityNotes,r.modelAvailabilityNotes)
    }
    func testExplicitOwnershipWinsEvenWhenSourceHasTwoSubscriptions() throws {
        let f=try feeds([model("default"),model("old",status:"older",selected:false)],bindings:[binding("s"),binding("t")],sessions:[session("native-old",owner:"s")])
        var a=SelectionAssembly();let yes=a.evaluate(feeds:f,scope:.subscription("s"),now:now)
        XCTAssertTrue(yes.shared.orderedIDs.contains("old"));XCTAssertEqual(yes.sessionEvidence.first?.ownership,.explicitSubscription)
        let no=a.evaluate(feeds:f,scope:.subscription("t"),now:now);XCTAssertFalse(no.shared.orderedIDs.contains("old"))
        XCTAssertTrue(no.shared.orderedIDs.contains("default"))
    }
    func testUniqueSourceOwnershipIsMarkedAsFallbackNotExactOwnership() throws {
        let f=try feeds([model("default"),model("old",status:"older",selected:false)],sessions:[session("native-old")])
        var a=SelectionAssembly();let r=a.evaluate(feeds:f,scope:.all,now:now)
        XCTAssertTrue(r.shared.orderedIDs.contains("old"));XCTAssertEqual(r.sessionEvidence.first?.ownership,.uniqueSource)
        XCTAssertTrue(r.instruments?.recentUseAtByModel.isEmpty == true)
    }
    func testAmbiguityOnlyDisablesOlderExceptionAndPreservesToolChoices() throws {
        let f=try feeds([model("global",sources:["other"]),model("tool",selected:false),model("old",status:"older",selected:false)],
            bindings:[binding("s"),binding("t")],sessions:[session("native-old")])
        var a=SelectionAssembly();let r=a.evaluate(feeds:f,scope:.subscription("s"),now:now)
        XCTAssertEqual(r.shared.orderedIDs,["tool"]);XCTAssertFalse(r.publicDefaultFallback)
        XCTAssertTrue(r.sessionEvidence.isEmpty);XCTAssertEqual(r.modelAvailabilityNotes["tool"],"该工具可用")
    }
    func testMissingPersonalAndUnknownScopeUseVisiblePublicDefaults() throws {
        let f=try feeds([model("default"),model("hidden",selected:false)],personal:false)
        var a=SelectionAssembly()
        for scope in [SelectionScope.all,.subscription("unknown")] {
            let r=a.evaluate(feeds:f,scope:scope,now:now)
            XCTAssertEqual(r.shared.orderedIDs,["default"]);XCTAssertEqual(r.selectionNotice,"按公开默认")
            XCTAssertEqual(r.effortPage?.models.map(\.id),["default"])
            XCTAssertEqual(r.effortPage?.selectionNotice,"按公开默认")
        }
    }
    func testMissingRevisionUsesRealPublicIdentityAndDoesNotClearCatalog() throws {
        let f=try feeds([model("default",lineage:false)],personal:false,revision:nil)
        var a=SelectionAssembly();let r=a.evaluate(feeds:f,scope:.all,language:.english,now:now)
        XCTAssertEqual(r.shared.orderedIDs,["default"]);XCTAssertNil(r.instruments?.publication.selectionRevision)
        XCTAssertEqual(r.selectionNotice,"Public defaults");XCTAssertEqual(r.effortPage?.models.map(\.id),["default"])
    }
    func testExpiredPersonalCannotResurrectOlderUsageAfterClockRollbackButDefaultsStayVisible() throws {
        let f=try feeds([model("default"),model("old",status:"older",selected:false)],sessions:[session("native-old",owner:"s")],expiry:10)
        var a=SelectionAssembly();XCTAssertTrue(a.evaluate(feeds:f,scope:.all,now:now).shared.orderedIDs.contains("old"))
        for time in [now.addingTimeInterval(10),now] {
            let r=a.evaluate(feeds:f,scope:.all,now:time);XCTAssertEqual(r.shared.orderedIDs,["default"])
            XCTAssertEqual(r.selectionNotice,"按公开默认")
        }
    }
    func testUnknownAliasesAndZeroUseDoNotCreateOlderExceptions() throws {
        let f=try feeds([model("default"),model("old",status:"older",selected:false)],
            sessions:[session("unknown",owner:"s"),session("native-old",owner:"s",tokens:0)])
        var a=SelectionAssembly();let r=a.evaluate(feeds:f,scope:.all,now:now)
        XCTAssertEqual(r.shared.orderedIDs,["default"]);XCTAssertTrue(r.sessionEvidence.isEmpty)
    }
    func testNoPublicationHasExplicitMessageRatherThanInventedModelOrBlankPage() {
        var a=SelectionAssembly();let r=a.evaluate(feeds:.init(publication:nil,personal:nil,personalUsable:false),scope:.all,now:now)
        XCTAssertTrue(r.shared.orderedIDs.isEmpty);XCTAssertFalse(r.emptyStateMessage.isEmpty)
        XCTAssertEqual(r.selectionNotice,"按公开默认");XCTAssertNil(r.instruments)
    }
    func testPublishedFleetCapsAndHighlightShareOneOrder() throws {
        let ids=(0..<13).map { "m"+String($0) };let f=try feeds(ids.map { model($0) },personal:false)
        var a=SelectionAssembly();let r=a.evaluate(feeds:f,scope:.all,selectedID:"m12",now:now)
        XCTAssertEqual(r.shared.orderedIDs,ids);XCTAssertEqual(r.shared.fieldIDs,Array(ids.prefix(10)))
        XCTAssertEqual(r.shared.chartIDs,Array(ids.prefix(6)));XCTAssertEqual(r.shared.rowIDs,Array(ids.prefix(3)))
        XCTAssertEqual(r.instruments?.orderedModelIDs,ids);XCTAssertEqual(r.effortPage?.selectedModelID,"m12")
    }
    func testUnreadableDominanceStillCannotBePromotedByFallback() throws {
        let f=try feeds([model("bad"),model("default")],personal:false,
            members:[["id":"bad","tags":["strongest"],"dominatedBy":["id":"default","kind":"future"]]])
        var a=SelectionAssembly();let r=a.evaluate(feeds:f,scope:.all,now:now)
        XCTAssertEqual(r.shared.orderedIDs,["default"]);XCTAssertEqual(r.mappingIssues.first?.reason,.unsupportedDominance)
    }
    func testUnsupportedMetricUnitsKeepPublicDefaultIdentitiesWithoutNumbers() throws {
        var m=model("default");m["efforts"]=[["effort":"high","ability":99,"cost":4,"time":3]]
        var wire=try XCTUnwrap(JSONSerialization.jsonObject(with:publicationData([m])) as? [String:Any])
        wire["units"]=["ability":"future-units","cost":"usdPerReferenceTask","time":"taskTimeCrossModel"]
        let p=try FeedDecoder.publication(JSONSerialization.data(withJSONObject:wire))
        var a=SelectionAssembly();let r=a.evaluate(feeds:.init(publication:p,personal:nil,personalUsable:false),scope:.all,now:now)
        XCTAssertEqual(r.shared.orderedIDs,["default"]);XCTAssertEqual(r.selectionNotice,"按公开默认")
        XCTAssertNil(r.models.first?.efforts.first?.ability.value);XCTAssertNil(r.models.first?.efforts.first?.cost.value)
        XCTAssertEqual(r.effortPage?.models.map(\.id),["default"])
    }
    func testExplicitEvidenceUpgradesEarlierUniqueSourceFallbackForSameModel() throws {
        let f=try feeds([model("default"),model("old",status:"older",selected:false)],
            sessions:[session("native-old"),session("native-old",owner:"s")])
        var a=SelectionAssembly();let r=a.evaluate(feeds:f,scope:.all,now:now)
        XCTAssertEqual(r.sessionEvidence.count,1);XCTAssertEqual(r.sessionEvidence.first?.ownership,.explicitSubscription)
    }
    func testAllKeepsEveryExplicitDefaultWhenOnlySomeLineageMetadataIsMissing() throws {
        let f=try feeds([model("complete"),model("missing-lineage",lineage:false),model("old",status:"older",selected:false)],
            sessions:[session("native-old",owner:"s")])
        var a=SelectionAssembly();let r=a.evaluate(feeds:f,scope:.all,now:now)
        XCTAssertEqual(Set(r.shared.orderedIDs),["complete","missing-lineage","old"])
        XCTAssertEqual(Set(r.effortPage?.models.map(\.id) ?? []),Set(r.shared.orderedIDs))
    }
    func testKnownToolAndUseFactsSurviveMissingRevisionWithoutFabricatingOne() throws {
        let f=try feeds([model("tool"),model("used",sources:[]),model("old",status:"older",selected:false)],
            sessions:[session("used",owner:"s"),session("native-old",owner:"s")],revision:nil)
        var a=SelectionAssembly();let r=a.evaluate(feeds:f,scope:.subscription("s"),now:now)
        XCTAssertEqual(Set(r.shared.orderedIDs),["tool","used","old"])
        XCTAssertEqual(r.modelAvailabilityNotes["tool"],"该工具可用")
        XCTAssertEqual(r.modelAvailabilityNotes["used"],"实际用过")
        XCTAssertTrue(r.publicDefaultFallback);XCTAssertNil(r.instruments?.publication.selectionRevision)
        XCTAssertEqual(Set(r.effortPage?.models.map(\.id) ?? []),Set(r.shared.orderedIDs))
    }
    func testKnownLabelsRemainWhenDatedPublicFeedRequiresGlobalFallback() throws {
        let f=try feeds([model("tool"),model("used",sources:[])],sessions:[session("used",owner:"s")],lastGood:true)
        var a=SelectionAssembly();let r=a.evaluate(feeds:f,scope:.subscription("s"),now:now)
        XCTAssertEqual(r.selectionNotice,"按公开默认")
        XCTAssertEqual(r.modelAvailabilityNotes["tool"],"该工具可用")
        XCTAssertEqual(r.modelAvailabilityNotes["used"],"实际用过")
    }
    @MainActor func testRuntimeUsesPublicStoreEvenWhenPersonalReadIsUnavailable() async throws {
        let clock = SelectionClock(wall:now)
        let store = SnapshotStore(transport:PublicationOnlyTransport(data:try publicationData([model("default")])),
            time:clock,automaticTimers:false)
        let runtime = ModelSelectionRuntime(store:store,now:{ clock.wall })
        store.start()
        let deadline = ContinuousClock.now.advanced(by:.seconds(2))
        while !store.idle && ContinuousClock.now < deadline { await Task.yield() }
        XCTAssertTrue(store.idle);XCTAssertNil(store.view())
        let result = runtime.evaluate(scope:.all)
        XCTAssertEqual(result.shared.orderedIDs,["default"])
        XCTAssertEqual(result.selectionNotice,"按公开默认")
        XCTAssertEqual(result.effortPage?.models.map(\.id),["default"])
        await store.stopAndWait()
    }

}


@MainActor private final class SelectionClock: RefreshTimeSource {
    var wall: Date
    var elapsed: TimeInterval = 0
    init(wall:Date) { self.wall = wall }
}
private struct PublicationOnlyTransport: CLITransport {
    let data: Data
    func execute(_ command:CLICommand) async throws -> CommandResult {
        command == .desktop ? .init(exitCode:1,stdout:Data()) : .init(exitCode:0,stdout:data)
    }
}
