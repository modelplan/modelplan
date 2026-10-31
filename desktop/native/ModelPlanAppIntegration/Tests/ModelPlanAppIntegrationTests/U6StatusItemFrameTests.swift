// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanAppIntegration

@MainActor final class U6StatusItemFrameTests: XCTestCase {
    func testUnplacedFramesAndHalfSecondStability() throws {
        let screen=CGRect(x:0,y:0,width:2560,height:1440)
        func geometry(_ frame:CGRect) -> U6StatusItemFrameSampler.Geometry? {
            U6StatusItemFrameSampler.geometry(frame:frame,screen:screen,primaryTop:1440,menuHeight:28,active:true)
        }
        XCTAssertNil(geometry(CGRect(x:0,y:-22,width:60,height:44)))
        XCTAssertNil(geometry(CGRect(x:0,y:-33,width:60,height:44)))
        let good=try XCTUnwrap(geometry(CGRect(x:1796,y:1403,width:60,height:44)))
        XCTAssertEqual(CGPoint(x:good.frame.midX,y:good.frame.midY),CGPoint(x:1826,y:15))
        var tracker=U6StatusItemFrameSampler.Stability()
        XCTAssertNil(tracker.observe(good,windowNumber:7,visible:true,mono:10)?.stableSince)
        XCTAssertNil(tracker.observe(good,windowNumber:7,visible:true,mono:10.49))
        XCTAssertEqual(tracker.observe(good,windowNumber:7,visible:true,mono:10.5)?.stableSince,10)
        XCTAssertNil(tracker.observe(good,windowNumber:7,visible:true,mono:10.6))
        let moved=try XCTUnwrap(geometry(CGRect(x:1700,y:1403,width:60,height:44)))
        let invalidated=try XCTUnwrap(tracker.observe(moved,windowNumber:7,visible:true,mono:11))
        XCTAssertNil(invalidated.stableSince);XCTAssertEqual(invalidated.generation,2)
        XCTAssertEqual(tracker.observe(moved,windowNumber:7,visible:true,mono:11.5)?.stableSince,11)
        let hidden=try XCTUnwrap(tracker.observe(nil,windowNumber:7,visible:false,mono:12))
        XCTAssertFalse(hidden.visible);XCTAssertNil(hidden.stableSince);XCTAssertEqual(hidden.generation,3)
        let replaced=try XCTUnwrap(tracker.observe(good,windowNumber:8,visible:true,mono:13))
        XCTAssertEqual(replaced.windowNumber,8);XCTAssertEqual(replaced.generation,4);XCTAssertNil(replaced.stableSince)
        XCTAssertNil(tracker.observe(good,windowNumber:8,visible:true,mono:13.49))
        XCTAssertEqual(tracker.observe(good,windowNumber:8,visible:true,mono:13.5)?.generation,4)
        XCTAssertNil(U6StatusItemFrameSampler.geometry(frame:good.frame,screen:screen,primaryTop:1440,menuHeight:28,active:false))
    }

    func testHostedStatusItemTitleChangePublishesLastSettledTopFrame() async throws {
        guard ProcessInfo.processInfo.environment["GITHUB_ACTIONS"]=="true",
              ProcessInfo.processInfo.environment["RUNNER_ENVIRONMENT"]=="github-hosted" else {
            throw XCTSkip("Owned status-item placement is exercised only on the approved hosted Mac lane")
        }
        let app=NSApplication.shared,policy=NSApplication.shared.activationPolicy()
        app.setActivationPolicy(.accessory)
        let item=NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
        defer { NSStatusBar.system.removeStatusItem(item);app.setActivationPolicy(policy) }
        let button=try XCTUnwrap(item.button);var emitted:[[String:Any]]=[]
        let sampler=U6StatusItemFrameSampler { emitted.append($0) }
        button.title="U6 A";sampler.bind(button)
        let firstDeadline=ProcessInfo.processInfo.systemUptime+8
        while emitted.last?["settled"] as? Bool != true && ProcessInfo.processInfo.systemUptime<firstDeadline {
            sampler.sample();try await Task.sleep(for:.milliseconds(50))
        }
        XCTAssertEqual(emitted.last?["settled"] as? Bool,true,"Initial own status item was never placed")
        let count=emitted.count
        let generation=try XCTUnwrap(emitted.last?["frameGeneration"] as? UInt64)
        button.title="U6 settled frame regression";sampler.bind(button)
        let deadline=ProcessInfo.processInfo.systemUptime+8
        while (emitted.count==count || emitted.last?["settled"] as? Bool != true ||
               (emitted.last?["frameGeneration"] as? UInt64 ?? 0)<=generation) && ProcessInfo.processInfo.systemUptime<deadline {
            sampler.sample();try await Task.sleep(for:.milliseconds(50))
        }
        XCTAssertGreaterThan(emitted.count,count,"Title change must produce its settled placement")
        let last=try XCTUnwrap(emitted.last),since=try XCTUnwrap(last["stableSinceMono"] as? Double)
        XCTAssertGreaterThan(try XCTUnwrap(last["frameGeneration"] as? UInt64),generation)
        XCTAssertEqual(last["settled"] as? Bool,true)
        XCTAssertGreaterThanOrEqual(ProcessInfo.processInfo.systemUptime-since,0.5)
        let x=try XCTUnwrap(last["cgX"] as? CGFloat),y=try XCTUnwrap(last["cgY"] as? CGFloat)
        let width=try XCTUnwrap(last["width"] as? CGFloat),height=try XCTUnwrap(last["height"] as? CGFloat)
        let bounds=try XCTUnwrap(last["displayBounds"] as? [Double]),band=try XCTUnwrap(last["menuBarBand"] as? [Double])
        XCTAssertLessThanOrEqual(y,CGFloat(bounds[1])+1);XCTAssertGreaterThanOrEqual(y+height,CGFloat(bounds[1])-1)
        XCTAssertTrue(CGRect(x:band[0],y:band[1],width:band[2],height:band[3]).contains(CGPoint(x:x+width/2,y:y+height/2)))
    }
}
