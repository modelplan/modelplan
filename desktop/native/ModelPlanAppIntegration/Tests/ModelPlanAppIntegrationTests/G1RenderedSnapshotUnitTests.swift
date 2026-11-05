// SPDX-License-Identifier: MIT
import AppKit
import JavaScriptCore
@testable import ModelPlanCockpitWeb
import ModelPlanPrimitives
import XCTest

@testable import ModelPlanAppIntegration

@MainActor private final class G1PaintTestView: NSView, G1NativePaintObserving {
  var g1DrawnPaints: [G1NativePaint] = []
}

@MainActor final class G1RenderedSnapshotUnitTests: XCTestCase {
  func testDOMObservationExecutesVisibleRootAndInheritsZeroOpacity() throws {
    let context = try XCTUnwrap(JSContext())
    var failure: String?
    context.exceptionHandler = { _, error in failure = error?.toString() }
    context.evaluateScript(#"""
      function node(id, opacity, children=[]) {
        return {tagName:'DIV',id,className:'',classList:[],childNodes:[],children,parentElement:null,opacity,
          getBoundingClientRect(){return {x:0,y:0,width:20,height:20,right:20,bottom:20,left:0,top:0}},
          getAnimations(){return []},hasAttribute(){return false},getAttribute(){return null},matches(){return false}};
      }
      const root=node('visible','1',[node('transparent','0',[node('transparent-child','1')])]);
      globalThis.document={createElement:()=>({getContext:()=>null,style:{}}),querySelector:()=>root,body:root};
      globalThis.getComputedStyle=n=>({backgroundColor:'rgb(0, 0, 0)',color:'rgb(255, 255, 255)',
        filter:'none',backdropFilter:'none',boxShadow:'none',backgroundImage:'none',opacity:n.opacity,
        display:'block',visibility:'visible',position:'static',isolation:'auto',mixBlendMode:'normal',transform:'none',zIndex:'auto'});
      globalThis.Node={TEXT_NODE:3};globalThis.innerWidth=100;globalThis.innerHeight=100;globalThis.devicePixelRatio=1;
      globalThis.performance={timeOrigin:0,now:()=>1};
      """#)
    let result = context.evaluateScript(G1CockpitDOMScript.source)?.toString()
    XCTAssertNil(failure, "The shipped observer must execute for a visible root")
    let json = try XCTUnwrap(result?.data(using: .utf8))
    let value = try XCTUnwrap(JSONSerialization.jsonObject(with: json) as? [String: Any])
    let tree = try XCTUnwrap(value["tree"] as? [String: Any])
    XCTAssertEqual(tree["visible"] as? Bool, true)
    let hidden = try XCTUnwrap((tree["children"] as? [[String: Any]])?.first)
    XCTAssertEqual(hidden["visible"] as? Bool, false)
    let descendant = try XCTUnwrap((hidden["children"] as? [[String: Any]])?.first)
    XCTAssertEqual(descendant["visible"] as? Bool, false)
  }
  func testContractMappingDoesNotRelabelLocalOrCssFramesAsScreenCoordinates() {
    var node = G1RenderedElement("observed", role: "AXButton")
    node.frame = .init(x: 10, y: 20, width: 30, height: 40)
    node.visible = true
    node.text = "Actual text"; node.ink = .init(0.1, 0.2, 0.3)
    node.interaction = .init(hover: true, press: true, disabled: true)
    node.filters = ["observed-filter"]; node.effects = ["observed-effect"]
    node.animationPhase = "closing"
    let unmapped = G1ContractAdapter.element(node)
    XCTAssertNil(unmapped.frame); XCTAssertEqual(unmapped.interaction,.disabled)
    XCTAssertFalse(unmapped.enabled); XCTAssertEqual(unmapped.text,node.text)
    XCTAssertEqual(unmapped.filters,["observed-filter","observed-effect"])
    XCTAssertEqual(unmapped.transition,"closing")
    node.coordinateSpace = "web-viewport-css-px-top-left"
    XCTAssertNil(G1ContractAdapter.element(node).frame)
    node.coordinateSpace = "screen"
    XCTAssertEqual(G1ContractAdapter.element(node).frame,node.frame)
    node.visible = false
    XCTAssertNil(G1ContractAdapter.element(node).frame)
    node.visible = true; node.coordinateSpace = "parent-local"
    node.screenFrame = .init(x: 100, y: 200, width: 30, height: 40)
    XCTAssertEqual(G1ContractAdapter.element(node).frame,node.screenFrame)
  }
  func testSecureNativeFieldDoesNotExposeItsValueOrChangeTheControl() {
    let field = NSSecureTextField(frame: .init(x: 0, y: 0, width: 120, height: 24))
    field.stringValue = "synthetic-secret"
    let node = G1SnapshotReader.native(field, id: "secure")
    XCTAssertNil(node.text)
    XCTAssertEqual(node.unavailable["text"], "Secure control content withheld")
    XCTAssertEqual(field.stringValue, "synthetic-secret")
  }
  func testRasterFrameUsesTheCompletedDrawingTransformAndBackingScale() throws {
    let base = CGAffineTransform(translationX: 0, y: 200).scaledBy(x: 2, y: -2)
    let rect = CGRect(x: 10, y: 20, width: 30, height: 40)
    XCTAssertEqual(
      G1SnapshotReader.rasterRect(rect, transform: base, scale: 2, pixelHeight: 200), rect)
    XCTAssertEqual(
      G1SnapshotReader.rasterRect(
        rect, transform: base.scaledBy(x: 1.5, y: 1.5), scale: 2, pixelHeight: 200),
      CGRect(x: 15, y: 30, width: 45, height: 60))
    XCTAssertNil(G1SnapshotReader.rasterRect(rect, transform: base, scale: 0, pixelHeight: 200))
  }
  func testPaintBackdropUsesLayerOrderAndRejectsNonuniformOverlap() throws {
    let view = G1PaintTestView(frame: CGRect(x: 0, y: 0, width: 20, height: 10))
    let white = G1RenderedColor(1, 1, 1)
    view.g1DrawnPaints = [
      .init(
        role: "track", frame: view.bounds, color: NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.5)
      ), .init(role: "fill", frame: CGRect(x: 0, y: 0, width: 10, height: 10), color: .white),
    ]
    let tree = G1SnapshotReader.native(view, id: "paint", background: white)
    let filled = try XCTUnwrap(tree.element("paint/paint1"))
    XCTAssertEqual(filled.background?.r, 0.5)
    XCTAssertEqual(filled.background?.g, 0.5)
    XCTAssertEqual(filled.background?.b, 0.5)
    XCTAssertEqual(try XCTUnwrap(filled.contrastAgainstParent), 3.976653, accuracy: 0.00001)
    XCTAssertNil(
      G1SnapshotReader.paintBackdrop(
        CGRect(x: 0, y: 0, width: 30, height: 10), earlier: view.g1DrawnPaints[...], over: white,
        in: view))
  }
  func testHexParsingPreservesEveryRenderedChannelAndRejectsMissingAlpha() throws {
    let color = try XCTUnwrap(G1RenderedColor.fromHex("#12345678"))
    XCTAssertEqual(color.r, 18.0 / 255.0)
    XCTAssertEqual(color.g, 52.0 / 255.0)
    XCTAssertEqual(color.b, 86.0 / 255.0)
    XCTAssertEqual(color.a, 120.0 / 255.0)
    XCTAssertEqual(color.hex, "#12345678")
    XCTAssertEqual(G1RenderedColor.fromHex("#00000000"), .init(0, 0, 0, 0))
    XCTAssertEqual(G1RenderedColor.fromHex("#FFFFFFFF"), .init(1, 1, 1, 1))
    XCTAssertNil(G1RenderedColor.fromHex("#123456"))
    XCTAssertNil(G1RenderedColor.fromHex("#1234567Z"))
  }
  func testContrastRequiresObservedBackdropAndUsesActualAlpha() throws {
    let black = G1RenderedColor(0, 0, 0)
    let white = G1RenderedColor(1, 1, 1)
    XCTAssertEqual(try XCTUnwrap(black.contrast(against: white)), 21, accuracy: 0.000001)
    XCTAssertNil(black.contrast(against: .init(1, 1, 1, 0)))
    let blended = try XCTUnwrap(G1RenderedColor(0, 0, 0, 0.5).composited(over: white))
    XCTAssertEqual(blended.r, 0.5)
    XCTAssertEqual(blended.g, 0.5)
    XCTAssertEqual(blended.b, 0.5)
    XCTAssertNil(G1RenderedColor(0, 0, 0, 0.5).composited(over: nil))
  }
}
