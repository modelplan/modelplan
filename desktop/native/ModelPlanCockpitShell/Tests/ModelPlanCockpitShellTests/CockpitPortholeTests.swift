// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanCockpitShell

@MainActor final class CockpitPortholeTests:XCTestCase {
    private func image()->CGImage {
        CGContext(data:nil,width:1,height:1,bitsPerComponent:8,bytesPerRow:4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
    }
    private func state(closed:Bool = false,interactive:Bool = true,available:Bool = true,projectionCapture:String = "capture",stillCapture:String = "capture",projectionKey:String = "still",ids:[String] = ["a","b"])->CockpitPortholeState {
        let projection = CockpitRocketProjection(captureID:projectionCapture,stillKey:projectionKey,points:[
            .init(modelID:"a",normalized:CGPoint(x:0.25,y:0.5)),.init(modelID:"b",normalized:CGPoint(x:0.75,y:0.5))])
        let still = CockpitStill(key:"still",image:image(),captureID:stillCapture,rocketProjection:projection)
        return .init(size:CGSize(width:200,height:100),imageRect:CGRect(x:0,y:0,width:200,height:100),still:still,admittedModelIDs:ids,closed:closed,interactive:interactive,rendererAvailable:available)
    }
    func testNearestUsesViewportRadiusAndCaptureOrderForTies() {
        let projection = state().still!.rocketProjection!
        for scale in [CGFloat(0.5),1,2] {
            let convert:(CGPoint)->CGPoint = { CGPoint(x:$0.x*200*scale,y:$0.y*100*scale) }
            let origin = convert(CGPoint(x:0.25,y:0.5))
            XCTAssertEqual(projection.nearest(to:CGPoint(x:origin.x,y:origin.y+28),admittedIDs:["a","b"],convertNormalizedPoint:convert),"a")
            XCTAssertNil(projection.nearest(to:CGPoint(x:origin.x,y:origin.y+28.01),admittedIDs:["a","b"],convertNormalizedPoint:convert))
        }
        XCTAssertEqual(projection.nearest(to:CGPoint(x:50,y:50),admittedIDs:["a","b"],radius:60) { CGPoint(x:$0.x*100,y:$0.y*100) },"a")
    }
    func testSingleRocketClickSelectsFocusAndEmptyClickKeepsSelection() throws {
        let view = CockpitPortholeView();try view.configure(state());view.setPresentationAllowed(true)
        var intents:[CockpitPortholeIntent] = [];view.onEnlargeRequest = {intents.append($0);return true}
        XCTAssertTrue(view.requestEnlarge(trigger:.field,atLocalPoint:CGPoint(x:50,y:50)))
        XCTAssertEqual(intents.last?.focusModelID,"a");XCTAssertEqual(intents.last?.captureID,"capture")
        view.setEnlarged(false)
        XCTAssertTrue(view.requestEnlarge(trigger:.field,atLocalPoint:CGPoint(x:100,y:0)))
        XCTAssertNil(intents.last?.focusModelID)
    }
    func testViewCoordinateConversionKeepsViewportRadiusUnderRootScale() throws {
        for scale in [CGFloat(0.5),1,2] {
            let parent = NSView(frame:CGRect(x:0,y:0,width:200*scale,height:300*scale));parent.bounds = CGRect(x:0,y:0,width:200,height:300)
            let view = CockpitPortholeView(),base = state()
            try view.configure(.init(size:CGSize(width:200,height:300),imageRect:CGRect(x:0,y:0,width:200,height:300),still:base.still,admittedModelIDs:base.admittedModelIDs,closed:false,rendererAvailable:true))
            parent.addSubview(view);view.setPresentationAllowed(true)
            var focus:String?;view.onEnlargeRequest = { focus = $0.focusModelID;return true }
            XCTAssertTrue(view.requestEnlarge(trigger:.field,atLocalPoint:CGPoint(x:50,y:150+28/scale)));XCTAssertEqual(focus,"a")
            view.setEnlarged(false)
            XCTAssertTrue(view.requestEnlarge(trigger:.field,atLocalPoint:CGPoint(x:50,y:150+28.01/scale)));XCTAssertNil(focus)
        }
    }
    func testStaleCaptureKeyAndUnadmittedModelsCannotFocus() throws {
        let view = CockpitPortholeView();var focused:[String?] = [];view.onEnlargeRequest = {focused.append($0.focusModelID);return true};view.setPresentationAllowed(true)
        for value in [state(projectionCapture:"old"),state(projectionKey:"old"),state(projectionCapture:"",stillCapture:""),state(ids:["b"])] {
            try view.configure(value);view.setEnlarged(false)
            XCTAssertTrue(view.requestEnlarge(trigger:.field,atLocalPoint:CGPoint(x:50,y:50)));XCTAssertNil(focused.last!)
        }
    }
    func testOpeningIsIdempotentAcrossFieldZoomAXAndReentrantCallbacks() throws {
        let view = CockpitPortholeView();try view.configure(state());view.setPresentationAllowed(true);var calls = 0
        view.onEnlargeRequest = {_ in calls += 1;XCTAssertFalse(view.requestEnlarge());return true}
        XCTAssertTrue(view.requestEnlarge(trigger:.field,atLocalPoint:CGPoint(x:50,y:50)))
        XCTAssertFalse(view.requestEnlarge());XCTAssertFalse(view.accessibilityPerformPress());try view.configure(state())
        XCTAssertFalse(view.requestEnlarge(trigger:.field,atLocalPoint:CGPoint(x:50,y:50),gesture:.init(timestamp:1,windowPoint:.zero,clickCount:2)))
        XCTAssertEqual(calls,1);view.setEnlarged(false);XCTAssertTrue(view.accessibilityPerformPress());XCTAssertEqual(calls,2)
        view.stop();XCTAssertFalse(view.requestEnlarge())
    }
    func testGuardsKeepRendererDefaultOffAndRejectHiddenClosedAndAperture() throws {
        let view = CockpitPortholeView();var calls = 0;view.onEnlargeRequest = {_ in calls += 1;return true}
        try view.configure(state());XCTAssertFalse(view.requestEnlarge());view.setPresentationAllowed(true)
        for value in [state(closed:true),state(interactive:false),state(available:false)] {
            try view.configure(value);XCTAssertFalse(view.requestEnlarge())
        }
        try view.configure(state());view.isHidden = true;XCTAssertFalse(view.requestEnlarge());view.isHidden = false
        view.containsFieldPoint = {_ in false};XCTAssertFalse(view.requestEnlarge(trigger:.field,atLocalPoint:CGPoint(x:50,y:50)))
        XCTAssertFalse(view.requestEnlarge(trigger:.field,atLocalPoint:CGPoint(x:201,y:50)));XCTAssertEqual(calls,0)
        view.onEnlargeRequest = {_ in false};XCTAssertFalse(view.requestEnlarge());XCTAssertFalse(view.opening)
    }
    func testInvalidProjectionDoesNotCreateFocusAndConfigurationFailsAtomically() throws {
        let projection = CockpitRocketProjection(captureID:"c",stillKey:"s",points:[.init(modelID:"a",normalized:CGPoint(x:Double.nan,y:0)),.init(modelID:"a",normalized:.zero)])
        XCTAssertNil(projection.nearest(to:.zero,admittedIDs:["a"]) {$0})
        let view = CockpitPortholeView();try view.configure(state())
        XCTAssertThrowsError(try view.configure(.init(size:CGSize(width:200,height:100),imageRect:CGRect(x:0,y:0,width:201,height:100),still:nil,admittedModelIDs:[],closed:false)))
        XCTAssertEqual(view.state?.admittedModelIDs,["a","b"])
    }
}
