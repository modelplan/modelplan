// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanPrimitives
import XCTest

@testable import ModelPlanAppIntegration

@MainActor private final class G1PaintTestView: NSView, G1NativePaintObserving {
  var g1DrawnPaints: [G1NativePaint] = []
}

@MainActor final class G1RenderedSnapshotUnitTests: XCTestCase {
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
