// SPDX-License-Identifier: MIT
import AppKit
import CoreText
import XCTest
@testable import ModelPlanInstruments

private enum OverviewFixture {
    static let calendar=Fixtures.calendar(),now=Fixtures.now
    static let identities:[OverviewSeriesIdentity]=[.init(id:"a",name:"Synthetic Alpha",shortName:"A"),.init(id:"b",name:"Synthetic Beta",shortName:"B"),.init(id:"c",name:"Synthetic Gamma",shortName:"C")]
    static func snapshot(values:[Double?] = [100,0,nil],notices:[InstrumentNotice] = [],scope:InstrumentScope = .all,
                         now:Date = now,calendar:Calendar = calendar,information:OverviewInformationRow? = nil) -> OverviewPageSnapshot {
        let day=calendar.startOfDay(for:now)
        let rows=(0..<30).flatMap { index in values.enumerated().map { i,value in
            InstrumentUsageBucket(subscriptionID:identities[i].id,at:calendar.date(byAdding:.day,value:-index,to:day)!,tokens:value)
        } }
        let hour=calendar.dateInterval(of:.hour,for:now)!.start
        let hourly=values.enumerated().map { i,value in InstrumentUsageBucket(subscriptionID:identities[i].id,at:hour,tokens:value,timeBasis:.completionHour) }
        return .init(columns:values.enumerated().map{Fixtures.column(identities[$0.offset].id,tokens:$0.element)},daily:rows,hourly:hourly,
            notices:notices,identities:identities,scope:scope,now:now,calendar:calendar,information:information)
    }
    static func notice(_ id:String,_ severity:NoticeSeverity = .amber,expires:Date? = nil,sub:String? = "a") -> InstrumentNotice {
        .init(id:id,subscriptionID:sub,severity:severity,text:"Synthetic notice "+id,expiresAt:expires)
    }
    static func display(_ s:OverviewPageSnapshot,range:String = "7",mode:String = "stack") -> OverviewPageDisplay {
        s.display(rangeKey:range,modeKey:mode,language:.english)
    }
}
final class OverviewPageTests:XCTestCase {
    func testF09ZeroUnknownAndPartialAreNeverCollapsedToZero() throws {
        let snapshot=OverviewFixture.snapshot(),p=OverviewFixture.display(snapshot)
        XCTAssertNil(snapshot.today);XCTAssertNil(snapshot.days30)
        XCTAssertEqual(p.todayText,"--");XCTAssertEqual(p.days30Text,"--")
        let bucket=try XCTUnwrap(p.chart.buckets.last)
        XCTAssertEqual(bucket.values.map(\.tokens),[100,0,nil]);XCTAssertNil(bucket.total);XCTAssertEqual(bucket.recordedTotal,100);XCTAssertTrue(bucket.partial)
        let explanation=p.explanation(bucket)
        XCTAssertTrue(explanation.body.contains("100 · partial"));XCTAssertTrue(explanation.body.contains("Synthetic Beta 0"));XCTAssertTrue(explanation.body.contains("Synthetic Gamma --"))
        let zero=OverviewFixture.display(OverviewFixture.snapshot(values:[0]))
        XCTAssertEqual(zero.todayText,"0");XCTAssertEqual(zero.days30Text,"0");XCTAssertEqual(zero.chart.buckets.last?.total,0)
        XCTAssertEqual(OverviewFixture.snapshot(values:[100,0]).days30,3000)
    }
    func testMissingReadingHasNoFakeBarAndNativeNoRecordExplanation() throws {
        let display=OverviewFixture.display(OverviewFixture.snapshot(values:[nil]))
        let geometry=try XCTUnwrap(OverviewChartGeometry(display:display,plot:CGRect(x:7,y:11,width:280,height:100)))
        XCTAssertTrue(geometry.bars.isEmpty);XCTAssertEqual(geometry.maximum,1)
        XCTAssertTrue(display.explanation(display.chart.buckets[0]).body.contains("No record"))
        XCTAssertEqual(geometry.buckets.count,7);XCTAssertTrue(geometry.buckets.allSatisfy{$0.hitRect.height==100})
    }
    func testF19DSTBucketsHaveDistinctAbsoluteIdentityAndOffsetLabels() throws {
        for (stamp,count) in [("2026-03-08T20:00:00Z",23),("2026-11-01T20:00:00Z",25)] {
            let display=OverviewFixture.display(OverviewFixture.snapshot(now:Fixtures.instant(stamp)),range:"24")
            XCTAssertEqual(display.chart.buckets.count,count)
            XCTAssertEqual(Set(display.chart.buckets.map(\.id)).count,count)
            XCTAssertTrue(display.chart.buckets.allSatisfy{$0.end.timeIntervalSince($0.start)==3600})
            if count==25 {
                let repeated=display.chart.buckets.filter{OverviewFixture.calendar.component(.hour,from:$0.start)==1}
                XCTAssertEqual(repeated.count,2)
                XCTAssertTrue(display.explanation(repeated[0]).body.contains("GMT-07:00"))
                XCTAssertTrue(display.explanation(repeated[1]).body.contains("GMT-08:00"))
            }
        }
        let cal=Fixtures.calendar("Asia/Kathmandu")
        let display=OverviewFixture.display(OverviewFixture.snapshot(calendar:cal),range:"24")
        XCTAssertEqual(cal.component(.minute,from:display.chart.buckets[0].start),0)
        XCTAssertTrue(display.explanation(display.chart.buckets[0]).body.contains("GMT+05:45"))
    }
    func testF19DailyRangesUseCalendarDaysAcrossDST() {
        let display=OverviewFixture.display(OverviewFixture.snapshot(now:Fixtures.instant("2026-11-03T20:00:00Z")),range:"7")
        XCTAssertEqual(display.chart.buckets.count,7)
        XCTAssertTrue(display.chart.buckets.contains{$0.end.timeIntervalSince($0.start)==25*3600})
        XCTAssertTrue(display.chart.buckets.allSatisfy{OverviewFixture.calendar.component(.hour,from:$0.start)==0})
    }
    func testGapsConsumeExactlyTwoPointsWithoutInflatingSmallData() throws {
        let display=OverviewFixture.display(OverviewFixture.snapshot(values:[100,0,1]))
        let plot=CGRect(x:10,y:20,width:280,height:104)
        let geometry=try XCTUnwrap(OverviewChartGeometry(display:display,plot:plot))
        let bars=geometry.bars.filter{$0.bucketID==display.chart.buckets[0].id}
        XCTAssertEqual(bars.count,2);XCTAssertEqual(bars[0].rect.minY-bars[1].rect.maxY,2,accuracy:1e-12)
        XCTAssertEqual(bars[0].rect.height,100.0/101*100,accuracy:1e-12)
        XCTAssertEqual(bars[1].rect.height,1.0/101*100,accuracy:1e-12)
        XCTAssertLessThan(bars[1].rect.height,1)
        XCTAssertTrue(geometry.bars.allSatisfy{plot.contains($0.rect)})
        let split=try XCTUnwrap(OverviewChartGeometry(display:OverviewFixture.display(display.snapshot,mode:"split"),plot:plot))
        let pair=split.bars.filter{$0.bucketID==display.chart.buckets[0].id}
        XCTAssertEqual(pair[0].rect.maxY,plot.maxY);XCTAssertEqual(pair[1].rect.maxY,plot.maxY)
        XCTAssertEqual(pair[1].rect.height,1.04,accuracy:1e-12)
        XCTAssertNil(OverviewChartGeometry(display:display,plot:CGRect(x:0,y:0,width:5,height:4)))
        XCTAssertNil(OverviewChartGeometry(display:display,plot:plot,stackGap:Double.nan))
    }
    func testStableIdentityAndPaletteSurviveScopeAndRangeChanges() {
        let all=OverviewFixture.snapshot(),single=OverviewFixture.snapshot(scope:.subscription("b"))
        XCTAssertEqual(single.series.map(\.id),["b"])
        XCTAssertEqual(all.paletteSlot(for:"b"),single.paletteSlot(for:"b"))
        let seven=OverviewFixture.display(all),thirty=OverviewFixture.display(all,range:"30")
        XCTAssertEqual(seven.chart.buckets.map(\.id),Array(thirty.chart.buckets.suffix(7)).map(\.id))
        XCTAssertEqual(single.today,0);XCTAssertEqual(single.days30,0)
    }
    func testNoticeExpiryOrderOverflowAndOfflineInformationYield() {
        let now=OverviewFixture.now
        let notices=[OverviewFixture.notice("info",.information),OverviewFixture.notice("critical",.critical),
            OverviewFixture.notice("amber1"),OverviewFixture.notice("expired",expires:now),OverviewFixture.notice("amber2")]
        let info=OverviewInformationRow(id:"version",text:"Offline supplied version",actionLabel:"Details")
        let display=OverviewFixture.display(OverviewFixture.snapshot(notices:notices,information:info))
        XCTAssertEqual(display.snapshot.notices.map(\.id),["critical","amber1","amber2","info"])
        let visible=display.visibleNotices(limit:3)
        XCTAssertEqual(visible.notices.map(\.id),["critical","amber1"]);XCTAssertEqual(visible.more,2);XCTAssertNil(visible.information)
        let fewer=OverviewFixture.display(OverviewFixture.snapshot(notices:Array(notices.prefix(2)),information:info)).visibleNotices(limit:3)
        XCTAssertEqual(fewer.information,info);XCTAssertEqual(fewer.notices.count,2);XCTAssertEqual(fewer.more,0)
        let scoped=OverviewFixture.snapshot(notices:notices,scope:.subscription("b"),information:info)
        XCTAssertTrue(scoped.notices.isEmpty)
    }
    func testFooterUsesRetainedRangesAndScopeMismatchIsRejectedAtomically() throws {
        let snapshot=OverviewFixture.snapshot(),page=snapshot.pageContent(language:.english)
        var controller=MainScreenController()
        try controller.update(inputs:[],selection:nil,publication:nil,publicationUsable:false,pages:[page])
        let before=MainScreenPresentation(controller:controller,language:.english,compact:false)
        XCTAssertEqual(before.overview?.chart.buckets.count,7);if case .option(let chart)=before.footer[0] {XCTAssertEqual(chart.id,"overview.chart");XCTAssertEqual(chart.selectedValue,"bars")} else {XCTFail("Missing chart choice")}
        XCTAssertEqual(controller.chooseOption(id:"overview.range",value:"24"),[.optionSelected(page:.overview,id:"overview.range",value:"24")])
        XCTAssertEqual(MainScreenPresentation(controller:controller,language:.english,compact:false).overview?.chart.buckets.count,24)
        controller.chooseOption(id:"overview.mode",value:"split")
        try controller.update(inputs:[],selection:nil,publication:nil,publicationUsable:false,pages:[page])
        let current=MainScreenPresentation(controller:controller,language:.english,compact:false)
        XCTAssertEqual(current.overview?.mode,.split)
        XCTAssertThrowsError(try controller.update(inputs:[],selection:nil,publication:nil,publicationUsable:false,scope:.subscription("b"),pages:[page]))
        XCTAssertEqual(MainScreenPresentation(controller:controller,language:.english,compact:false),current)
        controller.selectScope(.subscription("b"))
        XCTAssertNil(MainScreenPresentation(controller:controller,language:.english,compact:false).overview)
    }
}
@MainActor final class OverviewPageViewTests:XCTestCase {
    private func update(_ view:MainScreenView,_ snapshot:OverviewPageSnapshot) throws {
        try view.update(inputs:[],selection:nil,publication:nil,publicationUsable:false,language:.english,compact:false,pages:[snapshot.pageContent(language:.english)],
            sourcedBodies:[.init(.alerts,titleVariants:["Alerts"],lines:snapshot.notices.map(\.text))])
    }
    func testNativeFooterRebuildsChartsAndPreservesFixedPlotAndIdleBitmap() async throws {
        let view=MainScreenView(),snapshot=OverviewFixture.snapshot()
        try update(view,snapshot)
        let plot=view.recipe!.regions.filter{$0.focusGroup=="overview.buckets"}.map(\.rect).reduce(CGRect.null){$0.union($1)}
        let renders=view.surfaceRenders
        for _ in 0..<100 {try update(view,snapshot)}
        XCTAssertEqual(view.surfaceRenders,renders)
        XCTAssertTrue(view.control(for:"screen.footer.1")!.accessibilityPerformPress())
        XCTAssertEqual(view.presentation?.overview?.chart.buckets.count,30)
        let newPlot=view.recipe!.regions.filter{$0.focusGroup=="overview.buckets"}.map(\.rect).reduce(CGRect.null){$0.union($1)}
        XCTAssertEqual(plot.minX,newPlot.minX);XCTAssertEqual(plot.width,newPlot.width,accuracy:1e-9);XCTAssertEqual(plot.height,newPlot.height)
        XCTAssertTrue(view.control(for:"screen.footer.2")!.accessibilityPerformPress())
        XCTAssertEqual(view.presentation?.overview?.mode,.split)
        for scale in [1,2] {XCTAssertEqual(try view.rasterImage(scale:scale).width,600*scale)}
        view.dispose()
    }
    func testKeyboardBucketTraversalExposesSameFullAXHelpWithoutNativeTitleProducer() async throws {
        let view=MainScreenView();try update(view,OverviewFixture.snapshot())
        let window=NSWindow(contentRect:view.frame,styleMask:[],backing:.buffered,defer:false);window.contentView=view
        var shown:HelpExplanation?;view.onHelpChange={shown=$0;_=$1}
        let ids=view.recipe!.regions.filter{$0.focusGroup=="overview.buckets"}.map(\.id)
        let first=try XCTUnwrap(view.control(for:ids[0])),last=try XCTUnwrap(view.control(for:ids.last!))
        XCTAssertTrue(window.makeFirstResponder(first));XCTAssertEqual(shown?.accessibleDescription,first.accessibilityHelp());XCTAssertNil(first.toolTip)
        func key(_ code:UInt16)->NSEvent {NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:[],timestamp:0,windowNumber:window.windowNumber,context:nil,characters:"",charactersIgnoringModifiers:"",isARepeat:false,keyCode:code)!}
        first.keyDown(with:key(124));XCTAssertTrue(window.firstResponder===view.control(for:ids[1]))
        view.control(for:ids[1])!.keyDown(with:key(119));XCTAssertTrue(window.firstResponder===last)
        last.keyDown(with:key(115));XCTAssertTrue(window.firstResponder===first)
        XCTAssertTrue(first.accessibilityLabel()!.contains("Synthetic Gamma --"))
        view.selectPage(.init(.effort));XCTAssertFalse(first.becomeFirstResponder());XCTAssertNil(first.toolTip)
        view.dispose();window.contentView=nil
    }
    func testMoreReturnsThroughSingleSourceAndInformationOnlyEmitsHostIntent() async throws {
        let view=MainScreenView();view.onHelpChange={_,_ in}
        let info=OverviewInformationRow(id:"host-info",text:"Offline version supplied by host",actionLabel:"Details")
        try update(view,OverviewFixture.snapshot(information:info))
        var intents:[MainScreenIntent]=[];view.onIntents={intents+=$0}
        let old=try XCTUnwrap(view.control(for:"overview.information"))
        XCTAssertTrue(old.accessibilityPerformPress());XCTAssertEqual(intents,[.overviewInformationSelected("host-info")])
        let notices=(0..<5).map{OverviewFixture.notice(String($0))}
        try update(view,OverviewFixture.snapshot(notices:notices,information:info))
        XCTAssertFalse(old.accessibilityPerformPress());XCTAssertNil(view.control(for:"overview.information"))
        XCTAssertTrue(view.control(for:"overview.more")!.accessibilityPerformPress())
        XCTAssertEqual(view.controller.navigation.sourced?.content,.alerts);XCTAssertNil(view.presentation?.overview)
        XCTAssertEqual(view.presentation?.lines.count,5)
        XCTAssertTrue(view.handleEscape());XCTAssertNotNil(view.presentation?.overview);XCTAssertNil(view.controller.navigation.sourced)
        view.dispose()
    }
    func testFailedOverviewPreparationKeepsPreviousSnapshotControlsAndBitmap() async throws {
        let provider=OverviewFailingProvider(),view=MainScreenView(recipeProvider:provider)
        try update(view,OverviewFixture.snapshot(values:[1]))
        let before=view.presentation,renders=view.surfaceRenders,old=view.control(for:"screen.footer.1")
        provider.fail=true
        XCTAssertThrowsError(try update(view,OverviewFixture.snapshot(values:[9])))
        XCTAssertEqual(view.presentation,before);XCTAssertEqual(view.surfaceRenders,renders);XCTAssertTrue(old===view.control(for:"screen.footer.1"))
        provider.fail=false;try update(view,OverviewFixture.snapshot(values:[9]));XCTAssertEqual(view.presentation?.overview?.snapshot.today,9)
        view.dispose()
    }
}
@MainActor private final class OverviewFailingProvider:MainScreenRecipeProvider {
    let neutral=NeutralMainScreenRecipe();var fail=false
    func minimumSize(for p:MainScreenPresentation)->CGSize {neutral.minimumSize(for:p)}
    func recipe(for p:MainScreenPresentation,size:CGSize)throws->MainScreenRecipe {if fail {throw EngineTableError.invalidRecipe};return try neutral.recipe(for:p,size:size)}
    func font(_ r:EngineFontRequest)throws->CTFont {try neutral.font(r)}
    func image(_ id:String)throws->CGImage {throw EngineTableError.missingResource(id)}
}
