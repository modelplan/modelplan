// SPDX-License-Identifier: MIT
import AppKit
import QuartzCore
import XCTest
@testable import ModelPlanCockpitShell

/// CKP-ENT-02 (native half): the cockpit's quick open is a compositor-only opacity fade. No mask, clip, 3D
/// scene or extra window is created for it, and the surface owns no field panel or web view of its own.
/// The browser half (no WebGL context on the cockpit reveal) is covered by the page specs.
@MainActor final class QuickOpenIsCompositorOnlyTests: XCTestCase {
  private func allLayers(_ layer: CALayer) -> [CALayer] { [layer] + (layer.sublayers ?? []).flatMap(allLayers) }
  private func allViews(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(allViews) }

  func testQuickOpenAnimatesOnlyOpacityAndCreatesNoFieldPanel() throws {
    _ = NSApplication.shared
    let surface = CockpitShellSurface(skin: NeutralCockpitShellSkin())
    defer { surface.stop() }
    try surface.configure(.init(profile: .full, closed: false, appearance: .init()))
    let windowsBefore = NSApp.windows.count
    let viewsBefore = allViews(surface).count

    try surface.quickOpen(reduceMotion: false)

    let root = try XCTUnwrap(surface.layer)
    XCTAssertEqual(root.animationKeys(), ["cockpit-quick-open"], "the quick open adds exactly one animation")
    let fade = try XCTUnwrap(root.animation(forKey: "cockpit-quick-open") as? CABasicAnimation)
    XCTAssertEqual(fade.keyPath, "opacity", "the only animated property is opacity")
    XCTAssertEqual(fade.fromValue as? Double, 0)
    XCTAssertEqual(fade.toValue as? Double, 1)
    XCTAssertEqual(fade.duration, 0.18, accuracy: 1e-9)
    for layer in allLayers(root) {
      XCTAssertNil(layer.mask, "no mask layer, so no mask animation")
      if layer !== root { XCTAssertNil(layer.animationKeys(), "no other layer is animated") }
    }
    XCTAssertEqual(NSApp.windows.count, windowsBefore, "no panel or window is created for the open")
    XCTAssertNil(surface.window)
    XCTAssertEqual(allViews(surface).count, viewsBefore, "no view is added by the open")
    for view in allViews(surface) {
      let name = String(describing: type(of: view))
      XCTAssertFalse(name.contains("WebView") || name.contains("Panel") || name.contains("SceneView") || name.contains("Metal"),
                     "the surface hosts no web view, field panel or 3D view: \(name)")
    }

    try surface.quickOpen(reduceMotion: true)
    XCTAssertNil(root.animationKeys(), "Reduce Motion shows it at once, with no animation at all")
    XCTAssertEqual(NSApp.windows.count, windowsBefore)
  }
}
