// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanInstruments

final class H18ComparisonTests:XCTestCase {
    func testLogDomainIncludesAllBothSpeedEffortsAndIsTrialInvariant() throws {
        let tier=InstrumentFastTier(costMultiplier:6,speedMultiplier:2,taskTimeUnknown:false)
        let model=Fixtures.model(tier:tier),plot=CGRect(x:36,y:6,width:200,height:66)
        var axis:ComparisonRatioAxis?,standard:[ComparisonMetricTrace]?,current:[ComparisonChartPoint?]?,star:[ComparisonChartPoint?]?
        for effort in model.efforts {for fast in [false,true] {
            let p=ComparisonPresentation(model:model,trial:.init(effort.key,fast:fast),publicationUsable:true,language:.english)
            let g=try XCTUnwrap(p.chartGeometry(in:plot))
            XCTAssertEqual(g.effortKeys,model.efforts.map(\.key));XCTAssertEqual(p.publishedSamples.count,model.efforts.count*2)
            if let axis {XCTAssertEqual(g.axis,axis)} else {axis=g.axis}
            let traces=g.traces.filter{!$0.fast}
            if let standard {XCTAssertEqual(traces,standard)} else {standard=traces}
            let c=g.profiles.first{$0.roles.contains(.current)}!.points,r=g.profiles.first{$0.roles.contains(.recommended)}!.points
            if let current {XCTAssertEqual(c,current)} else {current=c}
            if let star {XCTAssertEqual(r,star)} else {star=r}
            XCTAssertEqual(g.traces.filter{$0.fast}.count,fast ? 2:0)
        }}
        XCTAssertEqual(axis?.minimumPower,-2);XCTAssertEqual(axis?.maximumPower,5)
        XCTAssertEqual(plot.minY+(axis!.fraction(0.5)!)*plot.height-(plot.minY+axis!.fraction(1)!*plot.height),
                       plot.minY+axis!.fraction(1)!*plot.height-(plot.minY+axis!.fraction(2)!*plot.height),accuracy:1e-12)
    }
    func testEveryTraceAndMarkerUsesSameCurrentFastArithmeticAsTable() throws {
        let tier=InstrumentFastTier(costMultiplier:6,speedMultiplier:2,taskTimeUnknown:false)
        let model=Fixtures.model(current:.init("high",fast:true),tier:tier),p=ComparisonPresentation(model:model,trial:.init("max"),publicationUsable:true,language:.english)
        let g=try XCTUnwrap(p.chartGeometry(in:CGRect(x:10,y:20,width:200,height:80)))
        for sample in p.publishedSamples {
            let expected=EffortComparison(model:model,trial:sample.configuration,publicationUsable:true).panels[1]
            if sample.configuration==model.current {continue}
            XCTAssertEqual(sample.ratios,[expected.values?.abilityRatio,expected.values?.costRatio,expected.values?.timeRatio])
        }
        for column in p.columns where !column.unlit {
            let profile=g.profiles.first{$0.configuration==column.configuration}!
            let index=g.effortKeys.firstIndex(of:column.configuration!.effort)!
            for (i,cell) in column.cells.enumerated() {if let ratio=cell.chartRatio,ratio>0 {
                let point=profile.points[i]!
                XCTAssertEqual(point.point.x,g.x(index),accuracy:1e-12)
                let inverse=pow(2,Double(g.axis.maximumPower)-(point.point.y-g.plot.minY)/g.plot.height*Double(g.axis.maximumPower-g.axis.minimumPower))
                XCTAssertEqual(inverse,ratio,accuracy:1e-12)
            }}
        }
        XCTAssertEqual(p.columns[1].cells[1].tableValue!,8.4/18,accuracy:1e-12)
    }
    func testZeroAndMissingMetricsAreGapsWithoutTableValueChanges() throws {
        let efforts=[InstrumentEffort(key:"native-a",label:"Native A",ability:Fixtures.metric(0),cost:Fixtures.metric(0),time:Fixtures.metric(60)),
            .init(key:"native-b",label:"Native B",ability:Fixtures.metric(10),cost:Fixtures.metric(1),time:Fixtures.metric(nil)),
            .init(key:"native-c",label:"Native C",ability:Fixtures.metric(20),cost:Fixtures.metric(2),time:Fixtures.metric(100))]
        let p=ComparisonPresentation(model:Fixtures.model(current:.init("native-c"),rec:"native-b",efforts:efforts),trial:.init("native-a"),publicationUsable:true,language:.english)
        let g=try XCTUnwrap(p.chartGeometry(in:CGRect(x:0,y:0,width:200,height:80)))
        XCTAssertEqual(p.columns[1].cells[1].text,"×0.00")
        XCTAssertNil(g.traces.first{$0.metric == .cost}?.points[0]);XCTAssertNil(g.traces.first{$0.metric == .ability}?.points[0])
        XCTAssertEqual(g.traces.first{$0.metric == .time}?.segments.map(\.count),[1,1])
        let unknown=ComparisonPresentation(model:Fixtures.model(current:nil),trial:.init("max"),publicationUsable:true,language:.english)
        XCTAssertNil(unknown.chartGeometry(in:g.plot))
    }
    func testNoncanonicalEffortsUnknownFastTimeAndPresenceBounds() throws {
        let efforts=(0..<7).map{InstrumentEffort(key:"e\($0)",label:"Native \($0)",ability:Fixtures.metric(Double($0+1)),cost:Fixtures.metric(Double($0+1)),time:Fixtures.metric(100))}
        let p=ComparisonPresentation(model:Fixtures.model(current:.init("e3"),rec:"e1",tier:.init(costMultiplier:2,speedMultiplier:2,taskTimeUnknown:true),efforts:efforts),trial:.init("e6",fast:true),publicationUsable:true,language:.chinese)
        let g=try XCTUnwrap(p.chartGeometry(in:CGRect(x:0,y:6,width:200,height:26),labelBounds:CGRect(x:0,y:0,width:300,height:40)))
        XCTAssertEqual(g.effortKeys,efforts.map(\.key));XCTAssertTrue(g.traces.first{$0.fast && $0.metric == .time}!.points.allSatisfy{$0==nil})
        XCTAssertEqual(g.endpoints.count,3)
        XCTAssertFalse(ComparisonPresentation.chartIsPresent(in:CGSize(width:160,height:33)))
        XCTAssertFalse(ComparisonPresentation.chartIsPresent(in:CGSize(width:159,height:34)))
        XCTAssertTrue(ComparisonPresentation.chartIsPresent(in:CGSize(width:160,height:34)))
    }
    func testPublicLinksUseCanonicalIDExactRoutesAndExternalPolicy() {
        let link=InstrumentWebsiteLink.compare(publicModelID:"auto:a~ b/é",language:.english)
        XCTAssertEqual(link.url,"https://modelplan.ai/effort?model=auto%3Aa%7E+b%2F%C3%A9")
        XCTAssertEqual(link.target,"_blank");XCTAssertEqual(link.rel,"noopener noreferrer")
        XCTAssertEqual(InstrumentWebsiteLink.methodology(comparison:true,language:.english).url,"https://modelplan.ai/methodology#cost-basis")
        XCTAssertEqual(InstrumentWebsiteLink.methodology(comparison:false,language:.chinese).url,"https://modelplan.ai/methodology#effort-ladder")
        let source=InstrumentPublicationSource(publishedAt:nil,now:Fixtures.now,language:.english)
        XCTAssertEqual(source.age,"--");XCTAssertEqual(source.links.map(\.url),["https://modelplan.ai/methodology#cost-basis","https://modelplan.ai/methodology"])
    }
}
@MainActor final class H18RecipeTests:XCTestCase {
    func testRecommendationAndTrialStayInsideShortBarWithoutMovingCapOrTravel() async throws {
        let model=Fixtures.model(current:.init("low"),rec:"low")
        let base=FaderBankPresentation(inputs:[.init(model:model)],publicationUsable:true,language:.english,compact:false,now:Fixtures.now)
        let trial=FaderBankPresentation(inputs:[.init(model:model)],trial:.init(modelID:model.id,configuration:.init("low")),publicationUsable:true,language:.english,compact:false,now:Fixtures.now)
        let provider=NeutralFaderBankRecipe(),size=provider.minimumSize(for:base),a=try provider.recipe(for:base,size:size),b=try provider.recipe(for:trial,size:size)
        XCTAssertEqual(a.caps.first{$0.kind == .real}?.frame,b.caps.first{$0.kind == .real}?.frame)
        XCTAssertEqual(a.regions.first{$0.role == .slider}?.rect,b.regions.first{$0.role == .slider}?.rect)
        let gold=EngineInk(NSColor.systemYellow),blue=EngineInk(NSColor.systemBlue)
        let frames=b.commands.compactMap { c->CGRect? in if case .stroke(let r,_,let w,let ink)=c,ink==gold,w==1{return r};return nil}
        XCTAssertEqual(frames.count,1)
        let frame=frames[0],blues=b.commands.compactMap { c->CGRect? in if case .fill(let r,_,let ink,_)=c,ink==blue,r.height==1{return r};return nil}
        XCTAssertEqual(blues.count,1);XCTAssertTrue(frame.contains(blues[0]));XCTAssertLessThan(blues[0].maxY,frame.maxY)
    }
    func testAllUnderlineUsesVendorGeometryNeutralWhiteAndDimsWithoutResize() async throws {
        let provider=NeutralEngineTableRecipe(),column=Fixtures.column("a")
        func recipe(_ scope:InstrumentScope)throws->EngineTableRecipe {try provider.recipe(for:.init(columns:[column],requestedPage:0,scope:scope,language:.english,now:Fixtures.now),size:CGSize(width:600,height:230))}
        let all=try recipe(.all),single=try recipe(.subscription("a")),allRect=all.regions.first{$0.id=="engine.all"}!.rect
        XCTAssertEqual(allRect,single.regions.first{$0.id=="engine.all"}!.rect)
        func line(_ recipe:EngineTableRecipe,_ key:CGRect)->(CGRect,EngineInk) {recipe.commands.compactMap { c->(CGRect,EngineInk)? in
            if case .fill(let r,_,let ink,_)=c,r.height==3,r.minY==key.maxY-6,key.contains(r){return(r,ink)};return nil
        }.first!}
        let a=line(all,allRect),dim=line(single,allRect),vendorKey=all.regions.first{$0.id=="engine.subscription.a"}!.rect,v=line(all,vendorKey)
        XCTAssertEqual(a.0.height,v.0.height);XCTAssertEqual(a.0.minX-allRect.minX,v.0.minX-vendorKey.minX)
        XCTAssertEqual(a.1.red,1);XCTAssertEqual(a.1.green,1);XCTAssertEqual(a.1.blue,1);XCTAssertGreaterThan(a.1.alpha,dim.1.alpha)
    }
    func testComparisonHeaderLinksDoNotConsumeHeightAndEmitOnlyHostIntent() async throws {
        let model=Fixtures.model(),pub=SelectionPublication(publicationID:"p",selectionRevision:"r"),selection=InjectedModelSelection(publication:pub,scope:.all,orderedModelIDs:[model.id])
        let view=MainScreenView();view.onHelpChange={_,_ in}
        try view.update(inputs:[.init(model:model)],selection:selection,publication:pub,publicationUsable:true,language:.english,compact:false)
        view.openComparison(modelID:model.id,from:.fader(model.id))
        let first=view.recipe!.regions.first{$0.id=="compare.link.0"}!,plot=view.recipe!.chart!.plot
        XCTAssertEqual(first.rect.height,14)
        let chart=view.recipe!.chart!,slot=view.recipe!.regions.first{$0.id=="compare.chart"}!.rect
        for profile in chart.profiles {
            let key=view.recipe!.regions.first{$0.id=="compare.effort."+profile.configuration.effort}!
            XCTAssertGreaterThanOrEqual(key.rect.width,20)
            for point in profile.points.compactMap({$0}) {XCTAssertEqual(point.point.x,key.rect.midX,accuracy:1e-10)}
        }
        for command in view.recipe!.commands {if case .text(let t)=command,t.id.hasPrefix("compare.end.") {XCTAssertTrue(slot.contains(t.rect))}}

        var intents:[MainScreenIntent]=[];view.onIntents={intents+=$0}
        XCTAssertTrue(view.control(for:first.id)!.accessibilityPerformPress())
        XCTAssertEqual(intents,[.openWebsite(.compare(publicModelID:model.id,language:.english))])
        let before=view.surfaceRenders
        for _ in 0..<10 {try view.update(inputs:[.init(model:model)],selection:selection,publication:pub,publicationUsable:true,language:.english,compact:false)}
        XCTAssertEqual(view.surfaceRenders,before);XCTAssertEqual(view.recipe!.chart!.plot,plot);view.dispose()
    }
}
