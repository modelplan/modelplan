// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanInstruments

enum M4HelpFixtures {
    static func measure(_ text:String,_ width:CGFloat,_ role:HelpUITextRole)->CGSize {
        let columns=max(1,Int(width/6))
        let lines=text.split(separator:"\n",omittingEmptySubsequences:false).reduce(0) { count,line in
            let units=line.unicodeScalars.reduce(0) { $0+($1.value<128 ? 1:2) }
            return count+max(1,Int(ceil(Double(units)/Double(columns))))
        }
        return .init(width:width,height:CGFloat(lines*15))
    }
    static func map(_ profile:HelpUIProfile,_ language:InstrumentLanguage,full:Bool=true)->HelpUIRenderInput {
        let height:CGFloat=profile == .tall890 ? 890:640
        let regions=full ? HelpMapCatalog(language).entries(for:.cockpit).map(\.region):[.window,.pin,.settings]
        var anchors=regions.enumerated().map { index,region in
            HelpUIAnchor(id:region.rawValue,rect:.init(x:640,y:120+CGFloat(index)*(height-230)/15,width:120,height:16))
        }
        var map=HelpUIMapInput(mode:.heldOption,surface:.cockpit,
            regionAnchors:Dictionary(uniqueKeysWithValues:regions.map { ($0,$0.rawValue) }),
            columns:profile == .tall890 ? [.init(x:8,y:116,width:540,height:height-124)]
                : [.init(x:8,y:116,width:260,height:height-124),.init(x:280,y:116,width:260,height:height-124)],
            header:.init(x:8,y:34,width:540,height:70))
        map.sentenceOverrides[.pin]=language == .chinese ? "分离窗口":"Detach window"
        map.returnFocusID="tray"
        if full {
            anchors += [.init(id:"average",rect:.init(x:640,y:height-90,width:120,height:16)),
                        .init(id:"live",rect:.init(x:640,y:height-60,width:120,height:16))]
            map.todayAverageAnchorID="average";map.liveSpeedAnchorID="live"
        }
        return .init(sessionID:UUID(),viewport:.init(width:1280,height:height),profile:profile,language:language,
                     anchors:anchors,liveReadings:anchors.map(\.rect),map:map)
    }
    static func hint(_ id:UUID=UUID())->HelpUIRenderInput {
        .init(sessionID:UUID(),viewport:.init(width:1100,height:640),profile:.compact640,language:.english,
              anchors:[.init(id:"travel",rect:.init(x:500,y:200,width:60,height:100))],
              liveReadings:[.init(x:500,y:200,width:60,height:100)],
              firstUse:.init(offerID:id,anchorID:"travel",text:"Synthetic once-only hint",dismissTitle:"Dismiss synthetic hint"))
    }
}

final class M4HelpLayoutTests:XCTestCase {
    func testCardUsesWhitespaceAndUnplaceableOrHiddenAnchorsRemainAbsent() {
        var input=M4HelpFixtures.hint()
        let placed=HelpUILayout.make(input,measure:M4HelpFixtures.measure)
        let frame=try! XCTUnwrap(placed.card?.frame)
        XCTAssertTrue(HelpUIGeometry.safe(input.viewport).contains(frame))
        XCTAssertFalse(input.liveReadings.contains { HelpUIGeometry.intersects(frame,$0) })
        input.liveReadings=[HelpUIGeometry.safe(input.viewport)]
        XCTAssertNil(HelpUILayout.make(input,measure:M4HelpFixtures.measure).card)
        input.liveReadings=[];input.anchors=[.init(id:"travel",rect:.zero,visible:false)]
        XCTAssertNil(HelpUILayout.make(input,measure:M4HelpFixtures.measure).card)
    }
    func testLeadersStayOrthogonalAndNeverFallBackThroughAReading() {
        let block=CGRect(x:100,y:60,width:100,height:80),size=CGSize(width:300,height:200)
        let route=HelpUIGeometry.leader(from:.init(x:20,y:100),to:.init(x:280,y:100),avoiding:[block],viewport:size)
        XCTAssertEqual(route.first,.init(x:20,y:100));XCTAssertEqual(route.last,.init(x:280,y:100))
        XCTAssertGreaterThan(route.count,2)
        for pair in zip(route,route.dropFirst()) { XCTAssertTrue(HelpUIGeometry.segmentIsClear(pair.0,pair.1,blocks:[block])) }
        XCTAssertTrue(HelpUIGeometry.leader(from:.init(x:20,y:100),to:.init(x:280,y:100),
            avoiding:[.init(x:100,y:0,width:100,height:200)],viewport:size).isEmpty)
    }
    func testTallCompactAndBothLanguagesFitWithoutOverlappingLiveData() {
        for profile in [HelpUIProfile.tall890,.compact640] {
            for language in [InstrumentLanguage.chinese,.english] {
                let input=M4HelpFixtures.map(profile,language)
                let result=HelpUILayout.make(input,measure:M4HelpFixtures.measure)
                XCTAssertNotNil(result.mapHeader);XCTAssertTrue(result.unresolvedMapIDs.isEmpty,"\(result.unresolvedMapIDs)")
                XCTAssertEqual(result.mapLabels.count,15)
                for (index,label) in result.mapLabels.enumerated() {
                    XCTAssertTrue(HelpUIGeometry.safe(input.viewport).contains(label.frame))
                    XCTAssertFalse(input.liveReadings.contains { HelpUIGeometry.intersects(label.frame,$0) })
                    XCTAssertFalse(result.mapLabels.enumerated().contains { $0.offset != index && HelpUIGeometry.intersects(label.frame,$0.element.frame) })
                    XCTAssertFalse(label.leader.isEmpty)
                    let blocks=input.liveReadings+result.mapLabels.map(\.frame)+[result.mapHeader!]
                    for segment in zip(label.leader,label.leader.dropFirst()) { XCTAssertTrue(HelpUIGeometry.segmentIsClear(segment.0,segment.1,blocks:blocks)) }
                }
                XCTAssertEqual(result.mapLabels.first { $0.id=="map.todayAverage" }?.text,InstrumentHelpDefinitions.todayAverage(language))
                XCTAssertEqual(result.mapLabels.first { $0.id=="map.liveSpeed" }?.text,InstrumentHelpDefinitions.liveSpeed(language))
            }
        }
    }
    func testDetachOverrideIsRequiredAndFixedFramesDoNotShiftOtherCaptions() {
        var input=M4HelpFixtures.map(.compact640,.english,full:false)
        let before=HelpUILayout.make(input,measure:M4HelpFixtures.measure)
        input.map.captionFrames=Dictionary(uniqueKeysWithValues:before.mapLabels.map { ($0.id,$0.frame) })
        input.map.sentenceOverrides[.pin]="Put back current window"
        let after=HelpUILayout.make(input,measure:M4HelpFixtures.measure)
        XCTAssertTrue(after.unresolvedMapIDs.isEmpty)
        XCTAssertEqual(after.mapLabels.map(\.frame),before.mapLabels.map(\.frame))
        input.map.sentenceOverrides.removeValue(forKey:.pin)
        let missing=HelpUILayout.make(input,measure:M4HelpFixtures.measure)
        XCTAssertTrue(missing.unresolvedMapIDs.contains(HelpMapRegion.pin.rawValue))
        XCTAssertNil(missing.mapLabels.first { $0.id==HelpMapRegion.pin.rawValue })
    }
    func testMapSuppressesHintAndInvalidGeometryFailsClosed() {
        var input=M4HelpFixtures.map(.tall890,.english,full:false)
        input.firstUse = .init(offerID:UUID(),anchorID:HelpMapRegion.window.rawValue,text:"Hint",dismissTitle:"Dismiss")
        XCTAssertNil(HelpUILayout.make(input,measure:M4HelpFixtures.measure).card)
        input.anchors += [input.anchors[0]]
        let invalid=HelpUILayout.make(input,measure:M4HelpFixtures.measure)
        XCTAssertNil(invalid.mapHeader);XCTAssertNil(invalid.card);XCTAssertEqual(invalid.unresolvedMapIDs,["invalidInput"])
        input=M4HelpFixtures.hint();input.active=false
        XCTAssertNil(HelpUILayout.make(input,measure:M4HelpFixtures.measure).card)
    }
    func testHostShortcutSupplementIsNotInventedAndDuplicateSemanticIDsAreRejected() {
        var input=M4HelpFixtures.map(.tall890,.english,full:false)
        input.map.supplements=[.init(id:"map.shortcuts",anchorID:HelpMapRegion.settings.rawValue,text:"Synthetic current-page shortcut facts")]
        let result=HelpUILayout.make(input,measure:M4HelpFixtures.measure)
        XCTAssertEqual(result.mapLabels.first { $0.id=="map.shortcuts" }?.text,"Synthetic current-page shortcut facts")
        input.map.supplements=[.init(id:HelpMapRegion.window.rawValue,anchorID:HelpMapRegion.window.rawValue,text:"Duplicate")]
        XCTAssertEqual(HelpUILayout.make(input,measure:M4HelpFixtures.measure).unresolvedMapIDs,["invalidInput"])
    }
}
