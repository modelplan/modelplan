// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanInstruments

private enum B18Fixture {
    static let pub=SelectionPublication(publicationID:"synthetic",selectionRevision:"r1")
    static func selection(_ ids:[String] = ["model"],scope:InstrumentScope = .all)->InjectedModelSelection {
        .init(publication:pub,scope:scope,orderedModelIDs:ids,selectedModelID:ids.first)
    }
    static func effort(scope:InstrumentScope = .all)->EffortPageSnapshot {
        .init(models:[Fixtures.model()],selection:selection(scope:scope),publication:pub,publicationUsable:true,scope:scope,language:.english)
    }
    static func destinations(showNames:Bool = true,scope:InstrumentScope = .all)->DestinationsPageSnapshot {
        let project=InstrumentProject(id:"opaque-project",name:"Private example",subscriptionIDs:["a","b"],combinedTokens:1000,tokensBySubscription:["a":20])
        let rankings=[SuppliedProjectRanking(period:.days7,projects:[project],evidence:.init()),.init(period:.days30,projects:[.init(id:"thirty",name:"30 day project",subscriptionIDs:["a"],combinedTokens:2000)],evidence:.init())]
        let run=(0..<6).map{Fixtures.session("s\($0)",lastAt:Fixtures.now.addingTimeInterval(-Double($0)),sub:"a")}
        let ended=Fixtures.session("done",running:false,lastAt:Fixtures.now.addingTimeInterval(-500),endedAt:Fixtures.now.addingTimeInterval(-500),sub:"a")
        return .init(rankings:rankings,sessions:run+[ended],scope:scope,showProjectNames:showNames,now:Fixtures.now,calendar:Fixtures.calendar(),language:.english)
    }
}
final class B18PageModelTests:XCTestCase {
    func testEffortUsesInjectedPublishedOrderAndNoLocalLegacySelector() {
        let newer=Fixtures.model(id:"new"),older=Fixtures.model(id:"old",older:true)
        let selected=B18Fixture.selection(["old","new"])
        let all=EffortPageSnapshot(models:[newer,older],selection:selected,publication:B18Fixture.pub,publicationUsable:true,scope:.all,language:.english)
        XCTAssertEqual(all.models.map(\.id),["old","new"]);XCTAssertEqual(all.models[0].badge,"older")
        let scope=InstrumentScope.subscription("a"),single=EffortPageSnapshot(models:[older,newer],selection:B18Fixture.selection(["new"],scope:scope),publication:B18Fixture.pub,publicationUsable:true,scope:scope,language:.english)
        XCTAssertEqual(single.models.map(\.id),["new"])
        // Any explicitly admitted actually-used older member is still decided by the ONE host selector.
        let explicit=EffortPageSnapshot(models:[older],selection:B18Fixture.selection(["old"],scope:scope),publication:B18Fixture.pub,publicationUsable:true,scope:scope,language:.english)
        XCTAssertEqual(explicit.models.map(\.id),["old"])
    }
    func testPublicationMismatchWithholdsScoresAndFallbackKeepsCatalogWithoutExactActions() {
        let other=SelectionPublication(publicationID:"other",selectionRevision:"r1")
        let bad=EffortPageSnapshot(models:[Fixtures.model()],selection:B18Fixture.selection(),publication:other,publicationUsable:true,scope:.all,language:.english)
        XCTAssertTrue(bad.models.isEmpty);XCTAssertFalse(bad.exact)
        let fallback=InjectedModelSelection(publication:B18Fixture.pub,scope:.all,orderedModelIDs:["model"],publicDefaultFallback:true,selectionNotice:"Public default")
        let page=EffortPageSnapshot(models:[Fixtures.model()],selection:fallback,publication:B18Fixture.pub,publicationUsable:false,scope:.all,language:.english)
        XCTAssertEqual(page.models.map(\.id),["model"]);XCTAssertFalse(page.exact)
        XCTAssertTrue(page.models[0].points.allSatisfy{$0.ability==nil && $0.cost==nil && $0.time==nil})
    }
    func testProjectPeriodsAttributionAndPrivacyDoNotDuplicateCombinedTotals() {
        let a=B18Fixture.destinations(showNames:false,scope:.subscription("a")),b=B18Fixture.destinations(scope:.subscription("b"))
        XCTAssertEqual(a.projects[0].rows[0].tokens,20);XCTAssertEqual(a.projects[0].rows[0].name,"Project")
        XCTAssertNil(b.projects[0].rows[0].tokens)
        XCTAssertEqual(a.projects[1].rows[0].tokens,2000)
        XCTAssertTrue(a.details.allSatisfy{$0.projectName==nil && !$0.help.body.contains("Example")})
    }
    func testRunningFirstOwnRateAndMissingEndedTimeStayHonest() {
        let p=B18Fixture.destinations()
        XCTAssertEqual(p.timelines[0].rows.count,7);XCTAssertTrue(p.timelines[0].rows.prefix(6).allSatisfy{$0.activity == .working})
        XCTAssertEqual(p.timelines[0].rows.last?.activity,.completed)
        let unknown=InstrumentSession(id:"unknown",subscriptionID:"a",tool:"Tool",model:"model",effort:nil,startedAt:nil,endedAt:nil,lastAt:Fixtures.now.addingTimeInterval(-400),running:true)
        let page=DestinationsPageSnapshot(rankings:[],sessions:[unknown],scope:.all,showProjectNames:false,now:Fixtures.now,calendar:Fixtures.calendar(),language:.english)
        let detail=page.details[0]
        XCTAssertNil(detail.startedAt);XCTAssertNil(detail.endedAt);XCTAssertNil(detail.speed60s)
        XCTAssertTrue(detail.timeLabel.contains("Last seen"));XCTAssertFalse(detail.timeLabel.contains("Ended"))
        XCTAssertTrue(page.projects.allSatisfy{$0.unavailable && $0.rows.isEmpty})
    }
    func testNativeLocationOptionsReturnFromTemporaryPageWithoutMutatingUnderlyingState() throws {
        let initial=MainScreenLocation(.destinations,destinationsMode:.projects,timelineRange:.today,projectPeriod:.days30)
        var c=MainScreenController(location:initial)
        try c.update(inputs:[],selection:nil,publication:nil,publicationUsable:false,pages:[B18Fixture.destinations().pageContent()])
        c.open(.page(.init(.destinations,destinationsMode:.timeline,timelineRange:.days7)),from:.recordOverflow)
        let p=MainScreenPresentation(controller:c,language:.english,compact:false)
        XCTAssertEqual(p.destinations?.location.destinationsMode,.timeline);XCTAssertEqual(p.destinations?.location.timelineRange,.days7)
        XCTAssertTrue(c.chooseOption(id:"destinations.days",value:"7").isEmpty)
        let effects=c.chooseOption(id:"destinations.time",value:"today")
        XCTAssertEqual(effects,[.locationChanged(c.navigation.location,temporary:true)])
        c.back();XCTAssertEqual(c.navigation.location,initial)
        c.chooseOption(id:"destinations.mode",value:"time");XCTAssertEqual(c.navigation.location.projectPeriod,.days30)
    }
    func testOldSessionDetailRetainsSuppliedDatesWithoutUsingLastSeenAsEnd() {
        let end=Fixtures.now.addingTimeInterval(-9*86400),session=Fixtures.session("old",running:false,lastAt:end,endedAt:end)
        let p=DestinationsPageSnapshot(rankings:[],sessions:[session],scope:.all,showProjectNames:false,now:Fixtures.now,calendar:Fixtures.calendar(),language:.english)
        XCTAssertTrue(p.timelines.allSatisfy{$0.rows.isEmpty});XCTAssertEqual(p.details[0].endedAt,end)
    }
}
@MainActor final class B18PageViewTests:XCTestCase {
    private func update(_ view:MainScreenView,pages:[MainScreenPageContent])throws {
        try view.update(inputs:[.init(model:Fixtures.model())],selection:B18Fixture.selection(),publication:B18Fixture.pub,publicationUsable:true,language:.english,compact:false,pages:pages)
    }
    func testEffortPointOpensOneComparisonAndKeepsRealSetting() async throws {
        let view=MainScreenView();view.onHelpChange={_,_ in};view.selectPage(.init(.effort))
        try update(view,pages:[B18Fixture.effort().pageContent()])
        XCTAssertTrue(view.control(for:"effort.model.max")!.accessibilityPerformPress())
        XCTAssertEqual(view.controller.trial?.configuration,.init("max"));XCTAssertEqual(view.controller.inputs[0].model.current,.init("high"))
        XCTAssertTrue(view.handleEscape());XCTAssertEqual(view.controller.navigation.location.page,.effort);view.dispose()
    }
    func testEffortLinksShareAxisGutterAndWebsiteActivationIsHostOnly() async throws {
        let view=MainScreenView();view.onHelpChange={_,_ in};view.selectPage(.init(.effort));try update(view,pages:[B18Fixture.effort().pageContent()])
        let links=view.recipe!.regions.filter{$0.id.hasPrefix("effort.link.")}
        XCTAssertEqual(links.count,2);XCTAssertEqual(links[0].rect.minY,links[1].rect.minY)
        var intents:[MainScreenIntent]=[];view.onIntents={intents+=$0}
        XCTAssertTrue(view.control(for:"effort.link.1")!.accessibilityPerformPress())
        XCTAssertEqual(intents,[.openWebsite(.methodology(comparison:false,language:.english))])
        XCTAssertNil(view.controller.trial);view.dispose()
    }
    func testLocalModelChoiceKeepsEffortWebsiteTargetAndRetiresPreviousLink() async throws {
        let model=Fixtures.model(),other=Fixtures.model(id:"other"),selection=B18Fixture.selection(["model","other"])
        let page=EffortPageSnapshot(models:[model,other],selection:selection,publication:B18Fixture.pub,publicationUsable:true,scope:.all,language:.english)
        let view=MainScreenView();view.onHelpChange={_,_ in};view.selectPage(.init(.effort))
        try view.update(inputs:[.init(model:model),.init(model:other)],selection:selection,publication:B18Fixture.pub,publicationUsable:true,language:.english,compact:false,pages:[page.pageContent()])
        let old=view.control(for:"effort.link.0")!
        XCTAssertTrue(view.control(for:"effort.other.max")!.accessibilityPerformPress());XCTAssertTrue(view.handleEscape())
        XCTAssertEqual(view.presentation?.effort?.links.first?.url,InstrumentWebsiteLink.compare(publicModelID:"other",language:.english).url)
        XCTAssertFalse(old.accessibilityPerformPress());view.dispose()
    }
    func testTimelineSessionDetailsAndReturnPreservePrivacyAndRange() async throws {
        let view=MainScreenView();view.onHelpChange={_,_ in}
        view.selectPage(.init(.destinations,destinationsMode:.timeline,timelineRange:.days7))
        let data=B18Fixture.destinations(showNames:false);try update(view,pages:[data.pageContent()])
        let old=view.control(for:"destination.session.s0")!
        XCTAssertTrue(old.accessibilityPerformPress());XCTAssertEqual(view.presentation?.session?.id,"s0")
        XCTAssertFalse(old.accessibilityPerformPress());XCTAssertNotNil(view.control(for:"session.detail.s0.tokens"))
        XCTAssertFalse(view.recipe!.list!.rows.contains{$0.region.label.contains("Example")})
        XCTAssertTrue(view.handleEscape());XCTAssertEqual(view.controller.navigation.location.timelineRange,.days7)
        XCTAssertEqual(view.controller.navigation.location.destinationsMode,.timeline);view.dispose()
    }
    func testUnchangedPagesReuseRasterAndNoNativeTitlePolicyIsBroadened() async throws {
        let view=MainScreenView();view.onHelpChange={_,_ in};view.selectPage(.init(.destinations,destinationsMode:.timeline))
        let pages=[B18Fixture.destinations(showNames:false).pageContent()],before:Int
        try update(view,pages:pages);before=view.surfaceRenders
        for _ in 0..<100 {try update(view,pages:pages)}
        XCTAssertEqual(view.surfaceRenders,before)
        XCTAssertNil(view.control(for:"destination.session.s0")!.toolTip);view.dispose()
    }
}
