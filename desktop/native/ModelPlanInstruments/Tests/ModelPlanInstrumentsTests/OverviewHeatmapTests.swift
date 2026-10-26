// SPDX-License-Identifier: MIT
import AppKit
import CoreText
import XCTest
@testable import ModelPlanInstruments

private enum HeatFixture {
    static func snapshot(now:Date = Fixtures.now,calendar:Calendar = Fixtures.calendar(),coverage:Int? = 370,
        scope:InstrumentScope = .all,visualization:OverviewVisualization = .heatmap,second:Bool = false,missing:Bool = false) -> OverviewPageSnapshot {
        let today=calendar.startOfDay(for:now),ids=second ? ["a","b"]:["a"]
        let rows=ids.flatMap { id in (0..<371).map { offset in
            InstrumentUsageBucket(subscriptionID:id,at:calendar.date(byAdding:.day,value:-offset,to:today)!,tokens:missing ? nil:Double(offset))
        } }
        let start=coverage.map{calendar.date(byAdding:.day,value:-$0,to:today)!}
        return .init(columns:ids.map{Fixtures.column($0)},daily:rows,hourly:[],notices:[],
            identities:[.init(id:"a",name:"Synthetic Alpha",shortName:"A",ink:.init(0.2,0.4,0.6)),.init(id:"b",name:"Synthetic Beta",shortName:"B",ink:.init(0.6,0.3,0.1))],
            scope:scope,now:now,calendar:calendar,initialVisualization:visualization,coverageStart:start)
    }
    static func display(_ snapshot:OverviewPageSnapshot,language:InstrumentLanguage = .english) -> OverviewPageDisplay {
        snapshot.display(rangeKey:"24",modeKey:"stack",language:language)
    }
}
final class OverviewHeatmapTests:XCTestCase {
    func testF10Full371RowsProduce26WeeksWithNoFutureCellsAndFiveSteps() throws {
        let snapshot=HeatFixture.snapshot(),map=snapshot.heatmap,calendar=snapshot.calendar
        XCTAssertEqual(map.grid.count,182);XCTAssertEqual(map.cells.count,177)
        XCTAssertEqual(map.grid.compactMap{$0}.count,177);XCTAssertTrue(map.grid.suffix(5).allSatisfy{$0==nil})
        XCTAssertEqual(Set(map.cells.compactMap(\.intensity)),Set(0...4))
        XCTAssertFalse(map.shortCoverage);XCTAssertNil(HeatFixture.display(snapshot).coverageText)
        XCTAssertEqual(calendar.component(.weekday,from:map.cells[0].bucket.start),2)
        XCTAssertEqual(map.cells[0].column,0);XCTAssertEqual(map.cells[0].row,0)
        XCTAssertEqual(map.cells.last?.column,25);XCTAssertEqual(map.cells.last?.row,1)
        XCTAssertEqual(map.cells.last?.bucket.recordedTotal,0);XCTAssertEqual(map.cells.last?.intensity,0)
        XCTAssertEqual(map.cells.first?.bucket.total,176)
        XCTAssertEqual(Set(map.cells.map(\.id)).count,map.cells.count)
        let geometry=try XCTUnwrap(OverviewHeatmapGeometry(display:HeatFixture.display(snapshot),area:CGRect(x:10,y:20,width:560,height:160)))
        XCTAssertEqual(geometry.cells.count,177)
        XCTAssertTrue(geometry.cells.allSatisfy{geometry.area.contains($0.hitRect)})
        XCTAssertTrue(geometry.months.allSatisfy{geometry.area.contains($0.rect)})
        XCTAssertNil(OverviewHeatmapGeometry(display:HeatFixture.display(snapshot),area:CGRect(x:0,y:0,width:10,height:10)))
        XCTAssertNil(OverviewHeatmapGeometry(display:HeatFixture.display(snapshot),area:CGRect(x:Double.nan,y:0,width:600,height:160)))
    }
    func testShortCoverageDoesNotFabricateCellsBeforeRecording() throws {
        let snapshot=HeatFixture.snapshot(coverage:10),map=snapshot.heatmap,display=HeatFixture.display(snapshot)
        XCTAssertTrue(map.shortCoverage);XCTAssertEqual(display.coverageText,"Recorded since 2026-10-10")
        XCTAssertEqual(HeatFixture.display(snapshot,language:.chinese).coverageText,"从 2026-10-10 开始记录")
        XCTAssertEqual(map.cells.filter(\.covered).count,11)
        XCTAssertTrue(map.cells.dropLast(11).allSatisfy{!$0.covered && $0.intensity==nil && $0.bucket.recordedTotal==nil})
        let geometry=try XCTUnwrap(OverviewHeatmapGeometry(display:display,area:CGRect(x:0,y:0,width:560,height:160)))
        XCTAssertEqual(geometry.cells.count,11)
        XCTAssertEqual(geometry.cells.first?.cell.bucket.start,map.coverageStart)
    }
    func testCoveredMissingDaysRemainUnknownAndZeroRemainsARecordedCell() {
        let missing=HeatFixture.display(HeatFixture.snapshot(coverage:2,missing:true))
        let covered=missing.snapshot.heatmap.cells.filter(\.covered)
        XCTAssertEqual(covered.count,3);XCTAssertTrue(covered.allSatisfy{$0.intensity==nil})
        XCTAssertTrue(missing.explanation(covered.last!).body.contains("No record"))
        XCTAssertTrue(missing.explanation(covered.last!).body.contains("Synthetic Alpha --"))
        let unknown=HeatFixture.snapshot(coverage:nil,missing:true)
        XCTAssertTrue(unknown.heatmap.cells.allSatisfy{!$0.covered});XCTAssertNil(unknown.heatmap.coverageStart)
        let zero=HeatFixture.display(HeatFixture.snapshot(coverage:0))
        XCTAssertEqual(zero.snapshot.heatmap.cells.filter(\.covered).count,1)
        XCTAssertEqual(zero.snapshot.heatmap.cells.last?.intensity,0)
        XCTAssertTrue(zero.explanation(zero.snapshot.heatmap.cells.last!).body.contains("Synthetic Alpha 0"))
    }
    func testPerSubscriptionCoverageRetainsPartialFactsAndScopeIdentity() {
        let calendar=Fixtures.calendar(),now=Fixtures.now,today=calendar.startOfDay(for:now)
        let start=calendar.date(byAdding:.day,value:-10,to:today)!,later=calendar.date(byAdding:.day,value:-2,to:today)!
        let at=calendar.date(byAdding:.day,value:-5,to:today)!
        let rows=[InstrumentUsageBucket(subscriptionID:"a",at:at,tokens:100),.init(subscriptionID:"b",at:at,tokens:200)]
        func snapshot(_ scope:InstrumentScope)->OverviewPageSnapshot {
            .init(columns:[Fixtures.column("a"),Fixtures.column("b")],daily:rows,hourly:[],notices:[],
                identities:[.init(id:"a",name:"Alpha"),.init(id:"b",name:"Beta",ink:.init(0.6,0.3,0.1))],scope:scope,
                now:now,calendar:calendar,initialVisualization:.heatmap,coverageBySubscription:["a":start,"b":later])
        }
        let all=snapshot(.all),display=HeatFixture.display(all),cell=all.heatmap.cells.first{$0.bucket.start==at}!
        XCTAssertTrue(cell.covered);XCTAssertEqual(cell.bucket.values.map(\.tokens),[100,nil]);XCTAssertNil(cell.bucket.total)
        XCTAssertEqual(cell.bucket.recordedTotal,100);XCTAssertTrue(cell.bucket.partial)
        XCTAssertTrue(display.explanation(cell).body.contains("100 · partial"));XCTAssertTrue(display.explanation(cell).body.contains("Beta --"))
        let single=snapshot(.subscription("b"))
        XCTAssertEqual(single.heatmap.cells.filter(\.covered).count,3)
        XCTAssertEqual(single.series[0].ink,all.series[1].ink)
        XCTAssertEqual(single.heatmap.cells.last?.id,all.heatmap.cells.last?.id)
    }
    func testUnknownCoverageOnlyMakesActuallyRecordedDaysEligible() {
        let now=Fixtures.now,calendar=Fixtures.calendar(),today=calendar.startOfDay(for:now)
        let rows=[InstrumentUsageBucket(subscriptionID:"a",at:today,tokens:0)]
        let snapshot=OverviewPageSnapshot(columns:[Fixtures.column("a")],daily:rows,hourly:[],notices:[],scope:.all,now:now,calendar:calendar)
        XCTAssertEqual(snapshot.heatmap.cells.filter(\.covered).count,1);XCTAssertNil(snapshot.heatmap.coverageStart)
        let future=OverviewPageSnapshot(columns:[Fixtures.column("a")],daily:rows,hourly:[],notices:[],scope:.all,now:now,calendar:calendar,
            coverageStart:now.addingTimeInterval(86400))
        XCTAssertTrue(future.heatmap.cells.allSatisfy{!$0.covered});XCTAssertNil(future.heatmap.coverageStart)
    }
    func testF19UsesLocalCalendarDaysAcrossDSTAndQuarterHourZones() {
        for (stamp,duration) in [("2026-03-10T20:00:00Z",23.0),("2026-11-03T20:00:00Z",25.0)] {
            let display=HeatFixture.display(HeatFixture.snapshot(now:Fixtures.instant(stamp)))
            XCTAssertTrue(display.snapshot.heatmap.cells.contains{$0.bucket.end.timeIntervalSince($0.bucket.start)==duration*3600})
            XCTAssertTrue(display.snapshot.heatmap.cells.allSatisfy{display.snapshot.calendar.component(.hour,from:$0.bucket.start)==0})
            XCTAssertTrue(display.explanation(display.snapshot.heatmap.cells.last!).body.contains("2026-"))
            XCTAssertFalse(display.explanation(display.snapshot.heatmap.cells.last!).body.contains("GMT"))
        }
        let snapshot=HeatFixture.snapshot(calendar:Fixtures.calendar("Asia/Kathmandu")),last=snapshot.heatmap.cells.last!
        XCTAssertTrue(HeatFixture.display(snapshot).explanation(last).body.contains("2026-10-21"))
        XCTAssertEqual(snapshot.calendar.component(.minute,from:last.bucket.start),0)
    }
    func testFooterHidesRangeAndModeWithoutForgettingChoices() throws {
        let snapshot=HeatFixture.snapshot(visualization:.bars),page=snapshot.pageContent(language:.english)
        var controller=MainScreenController();try controller.update(inputs:[],selection:nil,publication:nil,publicationUsable:false,pages:[page])
        controller.chooseOption(id:"overview.range",value:"24");controller.chooseOption(id:"overview.mode",value:"split")
        controller.chooseOption(id:"overview.chart",value:"grid")
        let grid=MainScreenPresentation(controller:controller,language:.english,compact:false)
        XCTAssertEqual(grid.overview?.visualization,.heatmap);XCTAssertEqual(grid.footer[1],.blank);XCTAssertEqual(grid.footer[2],.blank)
        XCTAssertTrue(controller.chooseOption(id:"overview.range",value:"30").isEmpty)
        XCTAssertTrue(controller.chooseOption(id:"overview.mode",value:"stack").isEmpty)
        try controller.update(inputs:[],selection:nil,publication:nil,publicationUsable:false,pages:[page])
        XCTAssertEqual(MainScreenPresentation(controller:controller,language:.english,compact:false).overview?.visualization,.heatmap)
        controller.chooseOption(id:"overview.chart",value:"bars")
        let bars=MainScreenPresentation(controller:controller,language:.english,compact:false)
        XCTAssertEqual(bars.overview?.chart.range,.hours24);XCTAssertEqual(bars.overview?.mode,.split)
    }
}
@MainActor final class OverviewHeatmapViewTests:XCTestCase {
    private func update(_ view:MainScreenView,_ snapshot:OverviewPageSnapshot,language:InstrumentLanguage = .english)throws {
        try view.update(inputs:[],selection:nil,publication:nil,publicationUsable:false,language:language,compact:false,scope:snapshot.scope,
            pages:[snapshot.pageContent(language:language)])
    }
    func testGridKeyboardTraversalAndAXUseTheSameDayExplanation() async throws {
        let view=MainScreenView();try update(view,HeatFixture.snapshot())
        let window=NSWindow(contentRect:view.frame,styleMask:[],backing:.buffered,defer:false);window.contentView=view
        var shown:HelpExplanation?;view.onHelpChange={shown=$0;_=$1}
        func item(_ c:Int,_ r:Int)->MainScreenHitRegion {view.recipe!.regions.first{$0.gridPosition == .init(column:c,row:r)}!}
        func key(_ c:UInt16)->NSEvent {NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:[],timestamp:0,windowNumber:window.windowNumber,context:nil,characters:"",charactersIgnoringModifiers:"",isARepeat:false,keyCode:c)!}
        let start=item(2,3),control=view.control(for:start.id)!
        XCTAssertTrue(window.makeFirstResponder(control));XCTAssertEqual(shown?.accessibleDescription,control.accessibilityHelp());XCTAssertNil(control.toolTip)
        control.keyDown(with:key(124));XCTAssertTrue(window.firstResponder === view.control(for:item(3,3).id))
        (window.firstResponder as! NSControl).keyDown(with:key(125));XCTAssertTrue(window.firstResponder === view.control(for:item(3,4).id))
        (window.firstResponder as! NSControl).keyDown(with:key(123));XCTAssertTrue(window.firstResponder === view.control(for:item(2,4).id))
        (window.firstResponder as! NSControl).keyDown(with:key(126));XCTAssertTrue(window.firstResponder === control)
        control.keyDown(with:key(115));let ids=view.recipe!.regions.filter{$0.focusGroup=="overview.days"}.map(\.id)
        XCTAssertTrue(window.firstResponder === view.control(for:ids.first!))
        (window.firstResponder as! NSControl).keyDown(with:key(119));XCTAssertTrue(window.firstResponder === view.control(for:ids.last!))
        XCTAssertTrue(shown!.body.contains("Synthetic Alpha"));XCTAssertTrue(shown!.body.contains("2026-10-20"))
        view.dispose();window.contentView=nil
    }
    func testScopePaletteAndZeroMissingPaintingRemainDistinct() async throws {
        let snapshot=HeatFixture.snapshot(coverage:2,second:true),view=MainScreenView();try update(view,snapshot)
        let display=view.presentation!.overview!,g=try XCTUnwrap(OverviewHeatmapGeometry(display:display,area:CGRect(x:14,y:158,width:572,height:138)))
        XCTAssertEqual(g.cells.last?.cell.intensity,0)
        let fills=view.recipe!.commands.compactMap { command->EngineInk? in
            if case .fill(let rect,_,let ink,_)=command,rect.width==9,rect.height==9 {return ink};return nil
        }
        let legendFills=Array(fills.suffix(5));XCTAssertEqual(Set(legendFills.map(\.alpha)).count,5)
        XCTAssertTrue(legendFills.allSatisfy{abs($0.red-$0.green)<0.001 && abs($0.green-$0.blue)<0.001})
        try update(view,HeatFixture.snapshot(coverage:2,scope:.subscription("b"),second:true))
        let scoped=view.recipe!.commands.compactMap { command->EngineInk? in
            if case .fill(let rect,_,let ink,_)=command,rect==g.cells.last!.rect {return ink};return nil
        }
        XCTAssertEqual(scoped.last?.red,0.6);XCTAssertEqual(scoped.last?.green,0.3);XCTAssertEqual(scoped.last?.blue,0.1)
        view.dispose()
    }
    func testPointerChartChoiceRetiresHiddenControlsAndRestoresBars() async throws {
        let view=MainScreenView();view.onHelpChange={_,_ in};try update(view,HeatFixture.snapshot(visualization:.bars))
        let oldRange=view.control(for:"screen.footer.1")!,oldBucket=view.recipe!.regions.first{$0.focusGroup=="overview.buckets"}!.id
        let oldDayControl=view.control(for:oldBucket)!
        let window=NSWindow(contentRect:view.frame,styleMask:[],backing:.buffered,defer:false);window.contentView=view
        let grid=view.recipe!.regions.first{$0.id=="screen.footer.0.choice.grid"}!.rect
        func event(_ type:NSEvent.EventType)->NSEvent {NSEvent.mouseEvent(with:type,location:view.convert(.init(x:grid.midX,y:grid.midY),to:nil),modifierFlags:[],timestamp:0,windowNumber:window.windowNumber,context:nil,eventNumber:0,clickCount:1,pressure:0)!}
        let chart=view.control(for:"screen.footer.0")!;chart.mouseDown(with:event(.leftMouseDown));chart.mouseUp(with:event(.leftMouseUp))
        XCTAssertEqual(view.presentation?.overview?.visualization,.heatmap);XCTAssertFalse(oldRange.accessibilityPerformPress());XCTAssertFalse(oldDayControl.becomeFirstResponder())
        XCTAssertNil(view.control(for:"screen.footer.1"));XCTAssertNil(view.control(for:"screen.footer.2"))
        let cell=view.recipe!.regions.first{$0.focusGroup=="overview.days"}!,old=view.control(for:cell.id)!
        XCTAssertTrue(chart.accessibilityPerformPress());XCTAssertEqual(view.presentation?.overview?.visualization,.bars)
        XCTAssertFalse(old.becomeFirstResponder());XCTAssertNotNil(view.control(for:"screen.footer.1"))
        view.dispose();window.contentView=nil
    }
    func testUnchangedGridUsesNoAdditionalRastersAndCoverageIsAccessible() async throws {
        let view=MainScreenView(),snapshot=HeatFixture.snapshot(coverage:10);try update(view,snapshot)
        view.onHelpChange={_,_ in};let renders=view.surfaceRenders,ids=view.keyboardOrder
        for _ in 0..<100 {try update(view,snapshot)}
        XCTAssertEqual(view.surfaceRenders,renders);XCTAssertEqual(view.keyboardOrder,ids)
        XCTAssertEqual(view.control(for:"overview.coverage")?.accessibilityLabel(),"Recorded since 2026-10-10")
        for language in [InstrumentLanguage.english,.chinese] {try update(view,snapshot,language:language)
            for scale in [1,2] {XCTAssertEqual(try view.rasterImage(scale:scale).width,600*scale)}
        }
        view.dispose()
    }
    func testFailedGridPreparationLeavesBarsAndEffectsUncommitted() async throws {
        let provider=HeatmapFailingProvider(),view=MainScreenView(recipeProvider:provider)
        try update(view,HeatFixture.snapshot(visualization:.bars));let before=view.presentation,renders=view.surfaceRenders
        var effects:[MainScreenIntent]=[];view.onIntents={effects+=$0};provider.fail=true
        XCTAssertFalse(view.control(for:"screen.footer.0")!.accessibilityPerformPress())
        XCTAssertEqual(view.presentation,before);XCTAssertEqual(view.surfaceRenders,renders);XCTAssertTrue(effects.isEmpty)
        provider.fail=false;XCTAssertTrue(view.control(for:"screen.footer.0")!.accessibilityPerformPress())
        XCTAssertEqual(view.presentation?.overview?.visualization,.heatmap)
        view.dispose()
    }
    func testWeekRolloverRetiresRemovedCalendarDateAndKeepsNoFutureControls() async throws {
        let calendar=Fixtures.calendar(),sunday=Fixtures.instant("2026-11-01T20:00:00Z"),monday=Fixtures.instant("2026-11-02T20:00:00Z")
        let view=MainScreenView();try update(view,HeatFixture.snapshot(now:sunday,calendar:calendar))
        let first=view.recipe!.regions.first{$0.focusGroup=="overview.days"}!,old=view.control(for:first.id)!
        try update(view,HeatFixture.snapshot(now:monday,calendar:calendar))
        XCTAssertNil(view.control(for:first.id));XCTAssertFalse(old.becomeFirstResponder())
        XCTAssertEqual(view.recipe!.regions.filter{$0.focusGroup=="overview.days"}.count,176)
        view.dispose()
    }
}
@MainActor private final class HeatmapFailingProvider:MainScreenRecipeProvider {
    let neutral=NeutralMainScreenRecipe();var fail=false
    func minimumSize(for p:MainScreenPresentation)->CGSize {neutral.minimumSize(for:p)}
    func recipe(for p:MainScreenPresentation,size:CGSize)throws->MainScreenRecipe {if fail && p.overview?.visualization == .heatmap {throw EngineTableError.invalidRecipe};return try neutral.recipe(for:p,size:size)}
    func font(_ r:EngineFontRequest)throws->CTFont {try neutral.font(r)}
    func image(_ id:String)throws->CGImage {throw EngineTableError.missingResource(id)}
}
