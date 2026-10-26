// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanPrimitives
@testable import ModelPlanCockpitShell

@MainActor private final class OverflowStripSkin: CockpitStripSkin {
    let neutral = NeutralCockpitControlsSkin()
    func layout(for state:CockpitStripState) throws -> CockpitStripLayout {
        CockpitStripLayout(size:CGSize(width:320,height:26),controls:[.shutter:CGRect(x:0,y:-3,width:100,height:32),
            .alert:CGRect(x:110,y:-3,width:44,height:32),.settings:CGRect(x:180,y:-3,width:32,height:32),
            .attachment:CGRect(x:222,y:-3,width:32,height:32),.close:CGRect(x:264,y:-3,width:32,height:32)],shutterTravel:80)
    }
    func drawStrip(in context:CGContext,bounds:CGRect,state:CockpitStripState) {}
    func artwork(for control:CockpitControlID,state:CockpitStripState,button:CockpitButtonState) throws -> CockpitControlArtwork { try neutral.artwork(for:control,state:state,button:button) }
    func shutterArtwork(for state:CockpitStripState,focused:Bool) throws -> CockpitShutterArtwork { try neutral.shutterArtwork(for:state,focused:focused) }
    func discardCachedArtwork() {}
}
final class CockpitControlsTests: XCTestCase {
    func testShutterGestureTwoDetentsSlopCancellationAndDisabled() throws {
        XCTAssertNil(CockpitShutterGesture(x:.nan,closed:false,travel:100))
        XCTAssertNil(CockpitShutterGesture(x:0,closed:false,travel:0))
        var click = try XCTUnwrap(CockpitShutterGesture(x:20,closed:false,travel:100))
        click.move(to:23); XCTAssertFalse(click.moved); XCTAssertEqual(click.finish(at:23,enabled:true),true)
        var drag = try XCTUnwrap(CockpitShutterGesture(x:20,closed:false,travel:100))
        drag.move(to:69); XCTAssertTrue(drag.moved); XCTAssertEqual(drag.fraction,0.49,accuracy:1e-9)
        XCTAssertEqual(drag.finish(at:69,enabled:true),false)
        XCTAssertEqual(drag.finish(at:70,enabled:true),true)
        XCTAssertNil(drag.finish(at:120,enabled:false)); XCTAssertNil(drag.finish(at:.nan,enabled:true))
        var closing = try XCTUnwrap(CockpitShutterGesture(x:0,closed:true,travel:100))
        closing.move(to:-200); XCTAssertEqual(closing.fraction,0)
        XCTAssertEqual(closing.finish(at:-200,enabled:true),false)
    }
    func testCautionAbsoluteDeadlineAckWorseningAndNoHiddenRestart() async throws {
        try await MainActor.run {
            let origin = ContinuousClock.now; var instant = origin
            let strip = CockpitStripView(skin:NeutralCockpitControlsSkin(),now:{instant})
            defer { strip.stop() }
            var actions: [CockpitControlAction] = [];strip.onAction = { actions.append($0) }
            try strip.configure(.init(appearance:.init(scale:1),windowClosed:false))
            strip.setPresentationAllowed(true)
            strip.updateCautions([.init(id:"quota",severity:.amber)])
            let deadline = strip.cautionPresentation.deadline
            // A system Reduce Motion setting may legitimately suppress the visual animation.
            if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { XCTAssertEqual(strip.cautionAnimationDuration,10) }
            instant = origin.advanced(by:.seconds(4));strip.setPresentationAllowed(false)
            XCTAssertNil(strip.cautionAnimationDuration)
            instant = origin.advanced(by:.seconds(7));strip.setPresentationAllowed(true)
            if strip.cautionPresentation.mode == .blinking {
                XCTAssertEqual(strip.cautionPresentation.deadline,deadline)
                XCTAssertEqual(strip.cautionAnimationDuration,3)
            }
            instant = origin.advanced(by:.seconds(11));strip.validateCaution()
            XCTAssertEqual(strip.cautionPresentation.mode,.steadyUnacknowledged);XCTAssertNil(strip.cautionAnimationDuration)
            XCTAssertTrue(strip.control(.alert)!.accessibilityPerformPress())
            XCTAssertEqual(actions,[.openAlerts]);XCTAssertEqual(strip.cautionPresentation.mode,.acknowledged)
            strip.updateCautions([.init(id:"quota",severity:.red)])
            XCTAssertEqual(strip.cautionPresentation.severity,.red)
            XCTAssertNotEqual(strip.cautionPresentation.mode,.acknowledged)
            strip.updateCautions([]);XCTAssertEqual(strip.cautionPresentation.mode,.off);XCTAssertNil(strip.cautionAnimationDuration)
        }
    }
    func testControlAXLabelsOptionTargetsAndCallbackOnlyAttachment() async throws {
        try await MainActor.run {
            let strip = CockpitStripView(skin:NeutralCockpitControlsSkin()); defer {strip.stop()}
            var actions:[CockpitControlAction] = [];strip.onAction = {actions.append($0)}
            try strip.configure(.init(appearance:.init(scale:1,locale:"zh-CN",reduceMotion:true),windowClosed:true,windowEnabled:false))
            strip.setPresentationAllowed(true)
            XCTAssertEqual((strip.control(.alert) as? NSButton)?.title,"ALERT")
            XCTAssertEqual(strip.control(.alert)?.accessibilityLabel(),"警报")
            XCTAssertEqual(strip.control(.attachment)?.accessibilityLabel(),"分离为独立窗口")
            XCTAssertEqual(strip.helpTargets().first(where:{$0.id=="attachment"})?.label,"分离窗口")
            XCTAssertFalse(strip.control(.shutter)!.accessibilityPerformIncrement())
            XCTAssertTrue(strip.control(.attachment)!.accessibilityPerformPress());XCTAssertEqual(actions,[.toggleAttachment])
            XCTAssertEqual(strip.stripState?.detached,false) // M0 owns resulting placement/state.
            let anchors = strip.helpTargets().map(\.anchor)
            try strip.configure(.init(appearance:.init(scale:1,locale:"en",reduceMotion:true),windowClosed:true,detached:true))
            XCTAssertEqual(strip.helpTargets().map(\.anchor),anchors)
            XCTAssertEqual(strip.helpTargets().first(where:{$0.id=="attachment"})?.label,"Put back")
            XCTAssertTrue(strip.control(.settings)!.accessibilityPerformPress());XCTAssertTrue(strip.control(.close)!.accessibilityPerformPress())
            XCTAssertEqual(actions,[.toggleAttachment,.openSettings,.close])
            XCTAssertEqual((strip.control(.alert) as? NSButton)?.title,"ALERT")
            for id in CockpitControlID.allCases { XCTAssertNil(strip.control(id)?.toolTip) }
            strip.stop();XCTAssertNil(strip.stripState);XCTAssertNil(strip.stripLayout)
            strip.validateCaution();XCTAssertFalse(strip.control(.settings)!.accessibilityPerformPress())
            XCTAssertEqual(actions,[.toggleAttachment,.openSettings,.close])
        }
    }
    func testRegisteredControlOverhangHitSurvivesWholeRootScale() async throws {
        try await MainActor.run {
            let surface = CockpitShellSurface(skin:NeutralCockpitShellSkin())
            let strip = CockpitStripView(skin:OverflowStripSkin());defer {strip.stop();surface.stop()}
            try strip.configure(.init(appearance:.init(scale:1),windowClosed:false))
            try surface.configure(.init(profile:.full,closed:false,appearance:.init(scale:1)))
            surface.setContent(strip,for:.controls)
            let parent = NSView(frame:CGRect(x:0,y:0,width:800,height:1000));parent.addSubview(surface)
            for scale in [CGFloat(1),0.5] {
                try surface.setRootScale(scale)
                let local = strip.convert(CGPoint(x:190,y:-2),to:surface)
                let point = parent.convert(local,from:surface)
                XCTAssertTrue(surface.hitTest(point) === strip.control(.settings))
            }
            surface.stop();XCTAssertNil(strip.stripState)
        }
    }
    func testHUDGeometryNullableValuesExtremeCostsAndPublishedOrder() {
        let models = [model("a",ability:20,cost:2),model("b",ability:50,cost:8)]
        let chart = CockpitHUDChart.project(models,frontierIDs:["a","b"],size:CGSize(width:162,height:77))
        XCTAssertEqual(chart.costBaseline,2);XCTAssertEqual(chart.points.map(\.id),["a","b"])
        XCTAssertEqual(chart.points[0].recommended.x,8,accuracy:1e-8)
        XCTAssertEqual(chart.points[1].recommended.x,153,accuracy:1e-8)
        XCTAssertEqual(chart.frontier.count,2)
        let same = CockpitHUDModel(id:"same",name:"Same",shortName:"Same",recommendedEffort:"High",recommended:.init(ability:20,cost:2),current:.init(ability:20,cost:2),currentIsRecommended:true,reportedEffort:"High")
        XCTAssertNil(CockpitHUDChart.project([same],frontierIDs:["same"],size:CGSize(width:162,height:77)).points.first?.current)
        let unknown = CockpitHUDModel(id:"u",name:"Unknown",shortName:"U",recommendedEffort:"--",recommended:nil)
        XCTAssertTrue(CockpitHUDChart.project([unknown],frontierIDs:[],size:CGSize(width:162,height:77)).points.isEmpty)
        let extremes = CockpitHUDChart.project([model("lo",ability:1,cost:.leastNonzeroMagnitude),model("hi",ability:2,cost:.greatestFiniteMagnitude)],frontierIDs:[],size:CGSize(width:72,height:30))
        XCTAssertEqual(extremes.points.count,2);XCTAssertTrue(extremes.points.allSatisfy{$0.recommended.x.isFinite && $0.recommended.y.isFinite})
    }
    func testHUDClosedZeroAllocationStableTargetsFullNamesAndReturn() async throws {
        try await MainActor.run {
            let hud = CockpitHUDView(skin:NeutralCockpitControlsSkin());defer {hud.stop()}
            let models = [model("a",ability:20,cost:2),model("b",ability:50,cost:8)]
            var chosen:[String?] = [];hud.onOpenEffort = {chosen.append($0)}
            try hud.configure(.init(profile:.full,appearance:.init(scale:1),models:models,frontierIDs:["a","b"]))
            let row = try XCTUnwrap(hud.subviews.compactMap{$0 as? NSButton}.first{$0.accessibilityIdentifier()=="cockpit.hud.a"})
            XCTAssertEqual(row.toolTip,"Full a");XCTAssertTrue(row.accessibilityPerformPress());XCTAssertEqual(chosen,["a"])
            try hud.configure(.init(profile:.compact,appearance:.init(scale:2,locale:"zh-CN"),models:models,frontierIDs:["a","b"]))
            XCTAssertTrue(hud.subviews.contains{$0 === row})
            let buttons: [NSButton] = hud.subviews.compactMap { $0 as? NSButton }
            let points = buttons.filter { button in (button.accessibilityIdentifier() ?? "").contains(".point.") }
            XCTAssertEqual(points.count,2)
            XCTAssertTrue(points.allSatisfy { $0.toolTip == nil })
            try hud.configure(.init(profile:.compact,appearance:.init(scale:1),closed:true,models:Array(repeating:models[0],count:7)))
            XCTAssertNil(hud.state);XCTAssertNil(hud.hudLayout);XCTAssertEqual(hud.frame.size,.zero);XCTAssertTrue(hud.subviews.isEmpty)
            XCTAssertFalse(hud.accessibilityPerformPress());XCTAssertFalse(row.accessibilityPerformPress());XCTAssertEqual(chosen,["a"])
        }
    }
    func testHelpLeafIsPointerTransparentAndOwnerControlled() async throws {
        try await MainActor.run {
            let overlay = CockpitHelpOverlay(skin:NeutralCockpitControlsSkin())
            let annotation = CockpitHelpAnnotation(id:"attachment",text:"Detach",label:CGRect(x:2,y:2,width:80,height:24),anchor:CGPoint(x:10,y:40),leaderEnd:CGPoint(x:10,y:26))
            try overlay.configure(visible:true,annotations:[annotation],appearance:.init(scale:1))
            XCTAssertFalse(overlay.isHidden);XCTAssertNil(overlay.hitTest(CGPoint(x:10,y:10)))
            overlay.setPresentationAllowed(false);XCTAssertTrue(overlay.isHidden)
            overlay.setPresentationAllowed(true);XCTAssertFalse(overlay.isHidden)
            overlay.stop();overlay.setPresentationAllowed(true);XCTAssertTrue(overlay.isHidden)
            XCTAssertThrowsError(try overlay.configure(visible:true,annotations:[annotation,annotation],appearance:.init(scale:1)))
        }
    }
    func testHUDClearRefreshPreservesCallerAdmissionAndExplicitPause() async throws {
        try await MainActor.run {
            let item = model("one",ability:50,cost:2)
            let populated = CockpitHUDState(profile:.full,appearance:.init(scale:1),models:[item],frontierIDs:["one"])
            let enter = try XCTUnwrap(NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:[],timestamp:0,windowNumber:0,context:nil,characters:"\r",charactersIgnoringModifiers:"\r",isARepeat:false,keyCode:36))
            for closed in [false,true] {
                let hud = CockpitHUDView(skin:NeutralCockpitControlsSkin());defer {hud.stop()}
                var actions = 0;hud.onOpenEffort = { _ in actions += 1 }
                let cleared = CockpitHUDState(profile:.full,appearance:.init(scale:1),closed:closed,models:closed ? [item]:[])
                try hud.configure(cleared);try hud.configure(populated)
                let row = try XCTUnwrap(hud.subviews.compactMap{$0 as? NSButton}.first{$0.accessibilityIdentifier()=="cockpit.hud.one"})
                XCTAssertTrue(row.accessibilityPerformPress());XCTAssertEqual(actions,1)
                hud.setPresentationAllowed(false)
                try hud.configure(cleared);try hud.configure(populated)
                XCTAssertFalse(hud.accessibilityPerformPress())
                let pausedRow = try XCTUnwrap(hud.subviews.compactMap{$0 as? NSButton}.first{$0.accessibilityIdentifier()=="cockpit.hud.one"})
                XCTAssertFalse(pausedRow.accessibilityPerformPress());hud.keyDown(with:enter);XCTAssertEqual(actions,1)
                hud.setPresentationAllowed(true);XCTAssertTrue(pausedRow.accessibilityPerformPress());XCTAssertEqual(actions,2)
                hud.stop();try hud.configure(populated);XCTAssertFalse(hud.accessibilityPerformPress())
            }
        }
    }
    func testNeutralHUDPaintsKnownCurrentDotAndLinkWithoutUnknownOrEqualMarkers() async throws {
        try await MainActor.run {
            let skin = NeutralCockpitControlsSkin()
            let known = CockpitHUDModel(id:"one",name:"One",shortName:"One",recommendedEffort:"High",recommended:.init(ability:80,cost:4),current:.init(ability:20,cost:1),reportedEffort:"Low")
            let state = CockpitHUDState(profile:.full,appearance:.init(scale:1),models:[known])
            let layout = try skin.layout(for:state)
            let chart = CockpitHUDChart.project([known],frontierIDs:[],size:layout.chart.size)
            let p = try XCTUnwrap(chart.points.first),current = try XCTUnwrap(p.current)
            let without = CockpitHUDChart(points:[CockpitHUDPoint(id:p.id,recommended:p.recommended,current:nil)],frontier:chart.frontier,costBaseline:chart.costBaseline)
            let width = Int(layout.frame.width),height = Int(layout.frame.height),stride = width*4
            @MainActor func paint(_ state:CockpitHUDState,_ chart:CockpitHUDChart)->[UInt8] {
                let context = CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:stride,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
                context.translateBy(x:0,y:CGFloat(height));context.scaleBy(x:1,y:-1)
                skin.drawHUD(in:context,state:state,layout:layout,chart:chart)
                return Array(UnsafeBufferPointer(start:context.data!.assumingMemoryBound(to:UInt8.self),count:stride*height))
            }
            let visible = paint(state,chart),blank = paint(state,without)
            func changed(near point:CGPoint)->Bool {
                let x = Int(point.x+layout.chart.minX),y = Int(point.y+layout.chart.minY)
                for row in (y-2)...(y+2) { for col in (x-2)...(x+2) {
                    let offset = row*stride+col*4
                    if (0..<3).contains(where:{abs(Int(visible[offset+$0])-Int(blank[offset+$0]))>8}) { return true }
                } }
                return false
            }
            XCTAssertTrue(changed(near:current),"A supplied current point must be visible at its hit target")
            XCTAssertTrue(changed(near:CGPoint(x:(current.x+p.recommended.x)/2,y:(current.y+p.recommended.y)/2)),"A supplied current point must connect to its own recommendation")
            let unknown = CockpitHUDModel(id:"one",name:"One",shortName:"One",recommendedEffort:"High",recommended:known.recommended)
            let equal = CockpitHUDModel(id:"one",name:"One",shortName:"One",recommendedEffort:"High",recommended:known.recommended,current:known.recommended,currentIsRecommended:true,reportedEffort:"High")
            let unknownChart = CockpitHUDChart.project([unknown],frontierIDs:[],size:layout.chart.size)
            let equalChart = CockpitHUDChart.project([equal],frontierIDs:[],size:layout.chart.size)
            XCTAssertNil(unknownChart.points.first?.current);XCTAssertNil(equalChart.points.first?.current)
            XCTAssertEqual(paint(.init(profile:.full,appearance:state.appearance,models:[unknown]),unknownChart),paint(.init(profile:.full,appearance:state.appearance,models:[equal]),equalChart))
        }
    }
    private func model(_ id:String,ability:Double,cost:Double)->CockpitHUDModel {
        CockpitHUDModel(id:id,name:"Full "+id,shortName:id,recommendedEffort:"High",recommended:.init(ability:ability,cost:cost))
    }
}
