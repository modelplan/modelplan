// SPDX-License-Identifier: MIT
import AppKit
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
}

@MainActor final class B23ChartTreeTests:XCTestCase {
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
