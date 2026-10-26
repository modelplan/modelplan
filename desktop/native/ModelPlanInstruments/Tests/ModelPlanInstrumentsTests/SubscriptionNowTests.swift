// SPDX-License-Identifier: MIT
import AppKit
import CoreText
import XCTest
@testable import ModelPlanInstruments

private enum SubFixture {
    static let now=Fixtures.now
    static func usage(_ period:UsageSummaryPeriod = .days7,detail:UsageTokenDetail? = .init(input:20,output:100,cacheRead:80,cacheWrite:1000),
                      attribution:UsageAttribution = .verifiedSubscription,recording:Bool = true,evidence:InstrumentEvidence = .init(),requests:Double = 5)->SubscriptionUsageInput {
        .init(period:period,detail:detail,generation:[.init(eligibleRequests:requests,eligibleOutputTokens:100,generationMilliseconds:1000,basis:"synthetic"),
            .init(eligibleRequests:5,eligibleOutputTokens:100,generationMilliseconds:10000,basis:"synthetic")],recording:recording,attribution:attribution,evidence:evidence)
    }
    static func input(_ id:String = "a",windows:[InstrumentQuota] = [],reserve:ReservePresentation? = nil,credits:CreditPresentation? = nil,
                      usage:[SubscriptionUsageInput]? = nil,evidence:InstrumentEvidence = .init())->SubscriptionNowInput {
        .init(id:id,header:.init(name:"Synthetic "+id,plan:"Example tier",glyphID:nil,evidence:.init()),windows:windows,sourceLabel:"Synthetic reader",evidence:evidence,
            reserve:reserve,credits:credits,usage:usage ?? [self.usage(),self.usage(.days30,detail:.init(input:200,output:300,cacheRead:0,cacheWrite:4000))])
    }
    static func snapshot(_ inputs:[SubscriptionNowInput],scope:InstrumentScope = .subscription("a"),now:Date = now,language:InstrumentLanguage = .english)->SubscriptionNowSnapshot {
        .init(inputs:inputs,scope:scope,now:now,language:language)
    }
    static func row(_ snapshot:SubscriptionNowSnapshot,_ suffix:String,days:String = "7")->SubscriptionNowRow {
        snapshot.display(daysKey:days).rows.first{$0.id.hasSuffix(suffix)}!
    }
}
final class SubscriptionNowTests:XCTestCase {
    func testF03WindowsPreserveMonthlyZeroUnknownAndPassedReset() {
        let now=SubFixture.now
        let windows=[InstrumentQuota(id:"monthly",period:.monthly,remaining:0,resetsAt:now.addingTimeInterval(3600)),
            .init(id:"unknown",period:.other("Extra"),scope:"Synthetic model",remaining:nil),
            .init(id:"passed",period:.weekly,remaining:90,resetsAt:now)]
        let snapshot=SubFixture.snapshot([SubFixture.input(windows:windows)])
        XCTAssertTrue(snapshot.valid)
        XCTAssertEqual(SubFixture.row(snapshot,"window.monthly").level,.critical)
        XCTAssertTrue(SubFixture.row(snapshot,"window.monthly").value.contains("0%"))
        XCTAssertEqual(SubFixture.row(snapshot,"window.monthly").quota?.segments,0)
        XCTAssertNil(SubFixture.row(snapshot,"window.unknown").quota?.segments)
        XCTAssertTrue(SubFixture.row(snapshot,"window.monthly").value.contains("resets in 1h"))
        XCTAssertTrue(SubFixture.row(snapshot,"window.unknown").title.contains("Synthetic model"))
        XCTAssertTrue(SubFixture.row(snapshot,"window.unknown").value.contains("--"))
        XCTAssertEqual(SubFixture.row(snapshot,"window.passed").level,.unknown)
        XCTAssertFalse(SubFixture.row(snapshot,"window.passed").value.contains("90%"))
        XCTAssertFalse(SubFixture.row(snapshot,"window.passed").value.contains("100%"))
        let stale=SubFixture.snapshot([SubFixture.input(windows:windows,evidence:.init(freshness:.stale))])
        XCTAssertFalse(SubFixture.row(stale,"window.monthly").value.contains("0%"))
    }
    func testClockUpdateExpiresSameReadingAndDoesNotInventSourceTTL() {
        let now=SubFixture.now,evidence=InstrumentEvidence(observedAt:now.addingTimeInterval(-360),validUntil:now.addingTimeInterval(10))
        let input=SubFixture.input(windows:[.init(id:"w",period:.fiveHours,remaining:50,resetsAt:now.addingTimeInterval(100))],evidence:evidence)
        let initial=SubFixture.snapshot([input]),expired=SubFixture.snapshot([input],now:now.addingTimeInterval(20))
        XCTAssertTrue(SubFixture.row(initial,"source").value.contains("6m ago"))
        XCTAssertTrue(SubFixture.row(initial,"window.w").value.contains("50%"))
        XCTAssertFalse(SubFixture.row(expired,"window.w").value.contains("50%"))
        XCTAssertTrue(SubFixture.row(expired,"source").value.contains("Reading unavailable"))
    }
    func testF08ResetCountsZeroOneTwoSixAndFourExpiryOverflow() {
        for count in [0,1,2,6] {
            let allowances=(0..<count).map { i in ResetAllowance(count:1,expiresAt:SubFixture.now.addingTimeInterval(Double(i+1)*24*3600)) }
            let reserve=ReservePresentation(allowances:allowances,credits:nil,drawingCredits:false,now:SubFixture.now)
            let row=SubFixture.row(SubFixture.snapshot([SubFixture.input(reserve:reserve)]),"reserve")
            XCTAssertTrue(row.value.hasPrefix("\(count) "))
            XCTAssertEqual(row.value.contains("+2"),count==6)
            XCTAssertEqual(row.help.body.components(separatedBy:"expire ").count-1,count)
            XCTAssertFalse(row.value.contains("cards"))
        }
        let unreadable=ReservePresentation(allowances:nil,credits:nil,drawingCredits:false,now:SubFixture.now)
        XCTAssertTrue(SubFixture.row(SubFixture.snapshot([SubFixture.input(reserve:unreadable)]),"reserve").value.contains("-- resets"))
    }
    func testExpiredAllowancesAnd48HourBoundary() {
        let now=SubFixture.now
        for (seconds,level) in [(48.0*3600,QuotaLevel.amber),(48.0*3600+1,.unknown)] {
            let reserve=ReservePresentation(allowances:[.init(count:1,expiresAt:now.addingTimeInterval(seconds))],credits:nil,drawingCredits:false,now:now)
            XCTAssertEqual(SubFixture.row(SubFixture.snapshot([SubFixture.input(reserve:reserve)]),"reserve").level,level)
        }
        let reserve=ReservePresentation(allowances:[.init(count:2,expiresAt:now.addingTimeInterval(10))],credits:nil,drawingCredits:false,now:now)
        let expired=SubFixture.row(SubFixture.snapshot([SubFixture.input(reserve:reserve)],now:now.addingTimeInterval(10)),"reserve")
        XCTAssertEqual(expired.value,"0 resets");XCTAssertEqual(expired.level,.unknown)
    }
    func testCreditsAreBalanceOnlyWithUnknownDrawingAndReadingAge() {
        for balance in [Double?.none,0,1234.5] {
            let credits=CreditPresentation(balance:balance,drawingCredits:nil,evidence:.init(observedAt:SubFixture.now.addingTimeInterval(-120)),now:SubFixture.now,
                historyStatus:"must not render as a credit history",historyUnavailableReason:"synthetic")
            let row=SubFixture.row(SubFixture.snapshot([SubFixture.input(credits:credits)]),"credits")
            XCTAssertTrue(row.value.hasPrefix(balance == nil ? "--":balance == 0 ? "0":"1,234.5"))
            XCTAssertTrue(row.value.contains("2m ago"));XCTAssertTrue(row.value.contains("Credit use --"))
            XCTAssertNil(row.quota);XCTAssertFalse(row.value.contains("limit"));XCTAssertFalse(row.value.contains("history"))
        }
        let credits=CreditPresentation(balance:0,drawingCredits:true,evidence:.init(validUntil:SubFixture.now),now:SubFixture.now.addingTimeInterval(-1))
        XCTAssertTrue(SubFixture.row(SubFixture.snapshot([SubFixture.input(credits:credits)]),"credits").value.hasPrefix("--"))
        XCTAssertEqual(SubscriptionNowSnapshot.number(0.00001),"0.00001")
    }
    func testF09StatisticsStayInTheirPeriodAndUseEligibleSums() {
        let snapshot=SubFixture.snapshot([SubFixture.input()])
        XCTAssertEqual(SubFixture.row(snapshot,"usage.7.input").value,"20")
        XCTAssertEqual(SubFixture.row(snapshot,"usage.7.cache.hit").value,"80%")
        XCTAssertEqual(SubFixture.row(snapshot,"usage.7.speed").value,"18 t/s")
        XCTAssertTrue(SubFixture.row(snapshot,"usage.7.cache.hit").help.body.contains("cache write is not counted again"))
        XCTAssertEqual(SubFixture.row(snapshot,"usage.30.input",days:"30").value,"200")
        XCTAssertEqual(SubFixture.row(snapshot,"usage.30.cache.hit",days:"30").value,"0%")
        let only30=SubFixture.snapshot([SubFixture.input(usage:[SubFixture.usage(.days30)])])
        XCTAssertEqual(SubFixture.row(only30,"usage.7.input").value,"--")
        let zero=SubFixture.snapshot([SubFixture.input(usage:[SubFixture.usage(detail:.init(input:0,output:0,cacheRead:0,cacheWrite:1000))])])
        XCTAssertEqual(SubFixture.row(zero,"usage.7.input").value,"0");XCTAssertEqual(SubFixture.row(zero,"usage.7.cache.hit").value,"--")
    }
    func testSourceWideUnrecordedStaleAndDuplicateStatisticsAreWithheld() {
        for usage in [SubFixture.usage(attribution:.sourceWideCurrentBinding),SubFixture.usage(attribution:.unattributed),
                      SubFixture.usage(evidence:.init(freshness:.stale))] {
            let snapshot=SubFixture.snapshot([SubFixture.input(usage:[usage])])
            XCTAssertEqual(SubFixture.row(snapshot,"usage.7.input").value,"--")
            XCTAssertEqual(SubFixture.row(snapshot,"usage.7.speed").value,"--")
        }
        let stopped=SubFixture.snapshot([SubFixture.input(usage:[SubFixture.usage(recording:false)])])
        XCTAssertEqual(SubFixture.row(stopped,"usage.7.speed").value,"--")
        XCTAssertEqual(SubFixture.row(stopped,"usage.7.input").value,"20")
        let duplicate=SubFixture.snapshot([SubFixture.input(usage:[SubFixture.usage(),SubFixture.usage()])])
        XCTAssertEqual(SubFixture.row(duplicate,"usage.7.input").value,"--")
        let shared=SubFixture.snapshot([SubFixture.input("a",usage:[SubFixture.usage(attribution:.sourceWideCurrentBinding)]),
            SubFixture.input("b",usage:[SubFixture.usage(attribution:.sourceWideCurrentBinding)])],scope:.all)
        XCTAssertTrue(shared.accounts.allSatisfy{$0.usage[0].rows.dropFirst().allSatisfy{$0.value=="--"}})
    }
    func testInsufficientOrIncompatibleGenerationNeverBorrowsAnotherRate() {
        for generation:[GenerationSums] in [
            [.init(eligibleRequests:4,eligibleOutputTokens:100,generationMilliseconds:1000,basis:"synthetic")],
            [.init(eligibleRequests:5,eligibleOutputTokens:100,generationMilliseconds:1000,basis:"a"),.init(eligibleRequests:5,eligibleOutputTokens:100,generationMilliseconds:1000,basis:"b")]
        ] {
            let usage=SubscriptionUsageInput(period:.days7,detail:.init(input:20,output:100,cacheRead:80,cacheWrite:1000),generation:generation,recording:true,attribution:.verifiedSubscription)
            let snapshot=SubFixture.snapshot([SubFixture.input(usage:[usage,SubFixture.usage(.days30)])])
            XCTAssertEqual(SubFixture.row(snapshot,"usage.7.speed").value,"--")
            XCTAssertEqual(SubFixture.row(snapshot,"usage.7.input").value,"20")
        }
        let reserve=ReservePresentation(allowances:[.init(count:2,expiresAt:SubFixture.now.addingTimeInterval(3600))],credits:nil,drawingCredits:false,now:SubFixture.now)
        let credits=CreditPresentation(balance:0,drawingCredits:false,evidence:.init(),now:SubFixture.now)
        let all=SubFixture.snapshot([SubFixture.input(reserve:reserve,credits:credits)],scope:.all)
        XCTAssertTrue(all.accounts[0].summary.value.contains("2 resets"));XCTAssertTrue(all.accounts[0].summary.value.contains("Credits 0"))
    }
    func testFooterAllUnknownScopeAndInvalidInputStayExplicit() throws {
        XCTAssertFalse(SubFixture.snapshot([SubFixture.input()]).accounts[0].rows.contains{$0.quota != nil})
        let all=SubFixture.snapshot([SubFixture.input()],scope:.all)
        XCTAssertTrue(all.pageContent().options.allSatisfy{$0==nil})
        let single=SubFixture.snapshot([SubFixture.input()]);var c=MainScreenController(location:.init(.subscriptions),scope:single.scope)
        try c.update(inputs:[],selection:nil,publication:nil,publicationUsable:false,pages:[single.pageContent()])
        XCTAssertTrue(c.chooseOption(id:"subscription.tab",value:"history").isEmpty)
        XCTAssertEqual(c.chooseOption(id:"subscription.usage",value:"30"),[.optionSelected(page:.subscriptions,id:"subscription.usage",value:"30")])
        XCTAssertEqual(MainScreenPresentation(controller:c,language:.english,compact:false).subscription?.days,30)
        let stopped=SubFixture.snapshot([SubFixture.input(usage:[SubFixture.usage(recording:false)])])
        XCTAssertEqual(SubFixture.row(stopped,"usage.7.speed").value,"--")
        XCTAssertEqual(SubFixture.row(stopped,"usage.7.input").value,"20")
        let duplicate=SubFixture.snapshot([SubFixture.input(),SubFixture.input()])
        XCTAssertThrowsError(try c.update(inputs:[],selection:nil,publication:nil,publicationUsable:false,pages:[duplicate.pageContent()]))
        XCTAssertTrue(SubFixture.snapshot([SubFixture.input()],scope:.subscription("missing")).display(daysKey:nil).rows.isEmpty)
    }
}
@MainActor final class SubscriptionNowViewTests:XCTestCase {
    private func update(_ view:MainScreenView,_ snapshot:SubscriptionNowSnapshot)throws {
        try view.update(inputs:[],selection:nil,publication:nil,publicationUsable:false,language:snapshot.language,compact:false,scope:snapshot.scope,pages:[snapshot.pageContent()])
    }
    private func setup(_ snapshot:SubscriptionNowSnapshot,provider:(any MainScreenRecipeProvider)? = nil)throws->MainScreenView {
        let view=MainScreenView(recipeProvider:provider);view.onHelpChange={_,_ in};view.selectPage(.init(.subscriptions));try update(view,snapshot);return view
    }
    func testNativeListScrollAndScopeIntentUseStableAccountControls() async throws {
        let snapshot=SubFixture.snapshot((0..<13).map{SubFixture.input("s\($0)")},scope:.all),view=try setup(snapshot)
        let window=NSWindow(contentRect:view.frame,styleMask:[],backing:.buffered,defer:false);window.contentView=view
        let last=try XCTUnwrap(view.control(for:"subscription.s12.select"));var effects:[MainScreenIntent]=[];view.onIntents={effects+=$0}
        XCTAssertTrue(window.makeFirstResponder(last));XCTAssertGreaterThan(view.listScrollView!.contentView.bounds.minY,0)
        XCTAssertTrue(last.accessibilityPerformPress());XCTAssertEqual(effects,[.subscriptionScopeSelected("s12")])
        XCTAssertEqual(view.controller.navigation.scope,.all)
        try update(view,SubFixture.snapshot([SubFixture.input("s12")],scope:.subscription("s12")))
        XCTAssertFalse(last.accessibilityPerformPress());XCTAssertFalse(last.becomeFirstResponder())
        XCTAssertEqual(view.listScrollView?.contentView.bounds.minY,0)
        view.dispose();window.contentView=nil
    }
    func testReorderingRetainsAndRevealsFocusedAccountByID() async throws {
        let inputs=(0..<13).map{SubFixture.input("s\($0)")},view=try setup(SubFixture.snapshot(inputs,scope:.all))
        let window=NSWindow(contentRect:view.frame,styleMask:[],backing:.buffered,defer:false);window.contentView=view
        var anchor:CGRect?;view.onHelpChange={_,rect in anchor=rect}
        let control=view.control(for:"subscription.s0.select")!
        XCTAssertTrue(window.makeFirstResponder(control))
        try update(view,SubFixture.snapshot(inputs.reversed(),scope:.all))
        XCTAssertTrue(window.firstResponder === control);XCTAssertTrue(view.control(for:"subscription.s0.select") === control)
        XCTAssertGreaterThan(view.listScrollView!.contentView.bounds.minY,0)
        XCTAssertTrue(control.becomeFirstResponder())
        XCTAssertTrue(view.recipe!.list!.viewport.contains(try XCTUnwrap(anchor)))
        view.dispose();window.contentView=nil
    }
    func testPeriodSelectionRetiresOldReadoutsAndUpdatesFullSharedHelp() async throws {
        let view=try setup(SubFixture.snapshot([SubFixture.input()])),window=NSWindow(contentRect:view.frame,styleMask:[],backing:.buffered,defer:false)
        window.contentView=view;var help:HelpExplanation?;view.onHelpChange={help=$0;_=$1}
        let old=try XCTUnwrap(view.control(for:"subscription.a.usage.7.input"))
        XCTAssertTrue(window.makeFirstResponder(old));XCTAssertEqual(help?.accessibleDescription,old.accessibilityHelp());XCTAssertNil(old.toolTip)
        XCTAssertTrue(view.control(for:"screen.footer.1")!.accessibilityPerformPress())
        XCTAssertFalse(old.becomeFirstResponder());XCTAssertNil(view.control(for:"subscription.a.usage.7.input"))
        let current=try XCTUnwrap(view.control(for:"subscription.a.usage.30.input"));XCTAssertEqual(current.accessibilityValue() as? String,"200")
        XCTAssertNil(current.toolTip)
        for scale in [1,2] {XCTAssertEqual(try view.rasterImage(scale:scale).width,600*scale)}
        view.dispose();window.contentView=nil
    }
    func testKeyboardTraversesAndRevealsLongDocumentAndTeardownRetiresIt() async throws {
        let view=try setup(SubFixture.snapshot([SubFixture.input()])),window=NSWindow(contentRect:view.frame,styleMask:[],backing:.buffered,defer:false)
        window.contentView=view
        let first=view.control(for:"subscription.a.header")!;XCTAssertTrue(window.makeFirstResponder(first))
        func key(_ code:UInt16)->NSEvent {NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:[],timestamp:0,windowNumber:window.windowNumber,context:nil,characters:"",charactersIgnoringModifiers:"",isARepeat:false,keyCode:code)!}
        first.keyDown(with:key(125));XCTAssertTrue(window.firstResponder === view.control(for:"subscription.a.source"))
        (window.firstResponder as! NSControl).keyDown(with:key(119))
        XCTAssertTrue(window.firstResponder === view.control(for:"subscription.a.usage.7.speed"));XCTAssertGreaterThan(view.listScrollView!.contentView.bounds.minY,0)
        (window.firstResponder as! NSControl).keyDown(with:key(115));XCTAssertTrue(window.firstResponder === first)
        view.closeForCockpit();XCTAssertNil(view.listScrollView);XCTAssertFalse(first.becomeFirstResponder())
        window.contentView=nil;view.dispose()
    }
    func testUnchangedSnapshotKeepsScrollAndRasterCounts() async throws {
        let snapshot=SubFixture.snapshot([SubFixture.input()]),view=try setup(snapshot)
        let window=NSWindow(contentRect:view.frame,styleMask:[],backing:.buffered,defer:false);window.contentView=view
        XCTAssertTrue(window.makeFirstResponder(view.control(for:"subscription.a.usage.7.speed")))
        let origin=view.listScrollView!.contentView.bounds.origin,renders=view.surfaceRenders,displays=view.displayRequests
        for _ in 0..<100 {try update(view,snapshot)}
        XCTAssertEqual(view.surfaceRenders,renders);XCTAssertEqual(view.displayRequests,displays)
        XCTAssertEqual(view.listScrollView!.contentView.bounds.origin,origin)
        view.dispose();window.contentView=nil
    }
    func testOffscreenResourceFailureIsAtomicAndCanRetry() async throws {
        let provider=BadListResourceProvider(),view=try setup(SubFixture.snapshot([SubFixture.input()]),provider:provider)
        let before=view.presentation,renders=view.surfaceRenders
        provider.fail=true
        XCTAssertThrowsError(try update(view,SubFixture.snapshot([SubFixture.input("b")],scope:.subscription("b"))))
        XCTAssertEqual(view.presentation,before);XCTAssertEqual(view.surfaceRenders,renders)
        XCTAssertNotNil(view.control(for:"subscription.a.header"));XCTAssertNil(view.control(for:"subscription.b.header"))
        provider.fail=false;try update(view,SubFixture.snapshot([SubFixture.input("b")],scope:.subscription("b")))
        XCTAssertNotNil(view.control(for:"subscription.b.header"));view.dispose()
    }
    func testLocaleChangeRequiresMatchingLocalizedSnapshot() async throws {
        let english=SubFixture.snapshot([SubFixture.input()]),view=try setup(english),before=view.presentation
        XCTAssertThrowsError(try view.update(inputs:[],selection:nil,publication:nil,publicationUsable:false,language:.chinese,compact:false,
            scope:english.scope,pages:[english.pageContent()]))
        XCTAssertEqual(view.presentation,before)
        try update(view,SubFixture.snapshot([SubFixture.input()],language:.chinese))
        XCTAssertTrue(view.control(for:"subscription.a.source")!.accessibilityLabel()!.contains("读取来源与时间"))
        XCTAssertTrue(view.control(for:"subscription.a.usage.7.basis")!.accessibilityLabel()!.contains("7日用量"))
        view.dispose()
    }
    func testViewAndScrollObserverAreReleasedWithoutExplicitDispose() async throws {
        weak var weakView:MainScreenView?
        try autoreleasepool {var view:MainScreenView?=try setup(SubFixture.snapshot([SubFixture.input()]));weakView=view;view=nil}
        XCTAssertNil(weakView)
    }
}
@MainActor private final class BadListResourceProvider:MainScreenRecipeProvider {
    let neutral=NeutralMainScreenRecipe();var fail=false
    func minimumSize(for p:MainScreenPresentation)->CGSize {neutral.minimumSize(for:p)}
    func recipe(for p:MainScreenPresentation,size:CGSize)throws->MainScreenRecipe {
        let r=try neutral.recipe(for:p,size:size);guard fail,let list=r.list,!list.rows.isEmpty else{return r}
        var rows=list.rows;let row=rows.removeLast();rows.append(.init(height:row.height,commands:row.commands+[.image(resourceID:"missing-offscreen",rect:CGRect(x:0,y:0,width:1,height:1),opacity:1)],region:row.region))
        return .init(size:r.size,commands:r.commands,regions:r.regions,chart:r.chart,focusInk:r.focusInk,list:.init(identity:list.identity,viewport:list.viewport,rows:rows))
    }
    func font(_ r:EngineFontRequest)throws->CTFont {try neutral.font(r)}
    func image(_ id:String)throws->CGImage {throw EngineTableError.missingResource(id)}
}
