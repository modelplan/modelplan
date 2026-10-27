// SPDX-License-Identifier: MIT
import AppKit
import CoreText
import XCTest
@testable import ModelPlanInstruments

final class B23ComparisonAccessibilityTests:XCTestCase {
    func testPublishedOrderSpeedsEndpointsAndMarkerMeaningsAreLocalized() throws {
        for language in [InstrumentLanguage.chinese,.english] {
            let p=ComparisonPresentation(model:Fixtures.model(tier:.init(costMultiplier:6,speedMultiplier:2,taskTimeUnknown:false)),trial:.init("max",fast:true),publicationUsable:true,language:language)
            let chart=try XCTUnwrap(p.chartGeometry(in:.init(x:0,y:0,width:300,height:100)))
            let details=p.accessibilityDetails(for:chart),byID=Dictionary(uniqueKeysWithValues:details.map{($0.id,$0)})
            XCTAssertEqual(byID["effortOrder"]?.value,"Low → Med → High → Max")
            XCTAssertEqual(Set(details.map(\.id)).count,details.count)
            XCTAssertNotNil(byID["trace.standard.ability.max"]);XCTAssertNotNil(byID["trace.fast.cost.max"])
            XCTAssertNil(byID["trace.fast.ability"],"Fast overlays cost/time; do not invent another ability trace")
            XCTAssertTrue(byID["trace.standard.cost"]!.value.contains("Max"))
            for (id,word) in [("current",language == .chinese ? "白色":"white"),("recommended",language == .chinese ? "金色":"gold"),("trial",language == .chinese ? "蓝色":"blue")] {
                XCTAssertTrue(byID["marker."+id]!.value.contains(word))
            }
            XCTAssertTrue(byID["marker.trial"]!.value.contains("⚡"))
            XCTAssertTrue(byID["trace.fast.time.max"]!.value.contains(language == .chinese ? "快速":"Fast"))
        }
    }
    func testMissingValuesStayGapsAndEndpointUsesLastPlottedEffort() throws {
        var efforts=Fixtures.efforts
        efforts[3] = .init(key:"max",label:"Max",ability:Fixtures.metric(75),cost:Fixtures.metric(8.4),time:Fixtures.metric(nil))
        let p=ComparisonPresentation(model:Fixtures.model(efforts:efforts),trial:.init("max"),publicationUsable:true,language:.english)
        let chart=try XCTUnwrap(p.chartGeometry(in:.init(x:0,y:0,width:300,height:100)))
        let details=p.accessibilityDetails(for:chart)
        XCTAssertTrue(details.first{$0.id=="trace.standard.time.max"}!.value.contains("gap"))
        XCTAssertTrue(details.first{$0.id=="trace.standard.time"}!.value.contains("High"))
        XCTAssertFalse(details.contains{$0.id.hasPrefix("trace.fast.")})
        let different=ComparisonPresentation(model:Fixtures.model(efforts:Array(efforts.prefix(2))),trial:nil,publicationUsable:true,language:.english)
        XCTAssertTrue(different.accessibilityDetails(for:chart).isEmpty)
    }
    @MainActor func testDuplicateAccessibilityIDsFailRecipeValidation() {
        let detail=MainScreenAccessibilityDetail(id:"same",label:"Value",value:"1")
        let region=MainScreenHitRegion(id:"chart",rect:.init(x:0,y:0,width:100,height:100),label:"Chart",help:.init(title:"Chart",body:"Synthetic"),role:.readout,accessibilityDetails:[detail,detail])
        XCTAssertThrowsError(try MainScreenRecipe(size:.init(width:100,height:100),commands:[],regions:[region]).validate())
    }
    @MainActor func testScrollableRowsKeepDetailsAndTheWholeTreeHasOneBound() throws {
        let detail=MainScreenAccessibilityDetail(id:"metric",label:"Value",value:"1")
        func region(_ id:String,_ details:[MainScreenAccessibilityDetail])->MainScreenHitRegion{
            .init(id:id,rect:.init(x:0,y:0,width:100,height:40),label:id,help:.init(title:id,body:"Synthetic"),role:.readout,accessibilityDetails:details)
        }
        let list=MainScreenListRecipe(identity:"b23",viewport:.init(x:0,y:0,width:100,height:80),rows:[
            .init(height:40,commands:[],region:region("one",[detail])),.init(height:40,commands:[],region:region("two",[detail]))])
        try MainScreenRecipe(size:.init(width:100,height:100),commands:[],regions:[],list:list).validate()
        XCTAssertEqual(list.positionedRegions[1].rect.minY,40)
        XCTAssertEqual(list.positionedRegions[1].accessibilityDetails,[detail])
        let many=(0..<300).map{MainScreenAccessibilityDetail(id:"point.\($0)",label:"Point",value:"1")}
        XCTAssertThrowsError(try MainScreenRecipe(size:.init(width:100,height:100),commands:[],regions:[region("one",many),region("two",many)]).validate())
    }
}

@MainActor final class B23ChartTreeTests:XCTestCase {
    func testReduceMotionImmediatelyStopsAnInFlightReadingWithoutChangingItsValue() throws {
        let view=EngineTableView(recipeProvider:B23ReadingRecipe())
        try view.update(columns:[],language:.english,now:Fixtures.now)
        let reading=try XCTUnwrap(view.layer?.sublayers?.first(where:{$0.contents != nil}))
        let fade=CABasicAnimation(keyPath:"opacity");fade.fromValue=0;fade.toValue=1;fade.duration=10
        reading.add(fade,forKey:"reading");XCTAssertNotNil(reading.animation(forKey:"reading"))
        let before=view.recipe
        view.reducedMotion=true
        XCTAssertNil(reading.animation(forKey:"reading"));XCTAssertEqual(view.recipe,before)
        view.reducedMotion=false;XCTAssertNil(reading.animation(forKey:"reading"));view.dispose()
    }
    func testChartChildrenSurviveLocaleAndHostThemeRefreshAndRetireOnBack() throws {
        let view=MainScreenView();view.onHelpChange={_,_ in}
        let publication=SelectionPublication(publicationID:"b23-synthetic",selectionRevision:"1")
        let selection=InjectedModelSelection(publication:publication,scope:.all,orderedModelIDs:["model"],selectedModelID:"model")
        func update(_ language:InstrumentLanguage)throws {
            try view.update(inputs:[.init(model:Fixtures.model())],selection:selection,publication:publication,publicationUsable:true,language:language,compact:false)
        }
        try update(.english);view.openComparison(modelID:"model",configuration:.init("max"),from:.fader("model"))
        let chart=try XCTUnwrap(view.control(for:"compare.chart"))
        XCTAssertEqual(chart.accessibilityRole(),.group)
        let first=try XCTUnwrap((chart.accessibilityChildren() as? [NSAccessibilityElement])?.first)
        XCTAssertEqual(first.accessibilityValue() as? String,"Low → Med → High → Max")
        let frame=chart.frame,plot=view.recipe!.chart?.plot
        for appearance in [NSAppearance.Name.aqua,.darkAqua] {
            let host=NSView();host.appearance=NSAppearance(named:appearance);host.addSubview(view)
            for language in [InstrumentLanguage.chinese,.english] {
                try update(language)
                XCTAssertTrue(chart === view.control(for:"compare.chart"))
                XCTAssertTrue(first === (chart.accessibilityChildren() as? [NSAccessibilityElement])?.first)
                XCTAssertEqual(first.accessibilityLabel(),language == .chinese ? "发布档位顺序":"Published effort order")
                XCTAssertEqual(chart.frame,frame);XCTAssertEqual(view.recipe!.chart?.plot,plot)
                XCTAssertEqual(view.effectiveAppearance.bestMatch(from:[.aqua,.darkAqua]),.darkAqua,"LCD stays dark in both host themes")
            }
            view.removeFromSuperview()
        }
        view.back();XCTAssertNil(view.control(for:"compare.chart"));XCTAssertNil(first.accessibilityParent())
    }
}

@MainActor private final class B23ReadingRecipe:EngineTableRecipeProvider {
    let base=NeutralEngineTableRecipe()
    func image(_ id:String)throws->CGImage{try base.image(id)}
    func font(_ request:EngineFontRequest)throws->CTFont{try base.font(request)}
    func recipe(for presentation:EngineTablePresentation,size:CGSize)throws->EngineTableRecipe{
        .init(size:size,commands:[.text(.init(id:"reading",variants:["123"],rect:.init(x:0,y:0,width:80,height:20),font:.init(size:12),ink:.init(1,1,1),transitionDuration:0.08))],regions:[])
    }
}
