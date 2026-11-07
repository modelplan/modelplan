// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanInstruments
import ModelPlanSettings
@testable import ModelPlanAppIntegration

/// A real panel, read back in the same turn it is ordered in: AppKit reports its occlusion later,
/// and a first-use hint that waited for it inside showAndVerify could never be shown.
@MainActor final class DockHelpPresenterPanelTests: XCTestCase {
    func testHintShowsOnAPanelOrderedInThisTurn() throws {
        let screen = try XCTUnwrap(NSScreen.main)
        let anchor = CGRect(x: screen.frame.midX, y: screen.frame.midY, width: 60, height: 120)
        let surface = DockHelpSurface(revealID: UUID(), layoutID: UUID(), visible: true, dragging: false,
                                      anchors: [.findWidget: anchor])
        let layer = HelpUILayerView()
        let presenter = DockHelpPresenter(currentSurface: { surface }, isCurrent: { _ in true }, blockers: { _ in [] },
            windowPolicy: { _ in (.readOnly, []) }, language: { .english }, accessibility: { (true, true) },
            copy: { _, _ in ("Synthetic hint", "OK") }, dismiss: { _ in }, layer: layer)
        addTeardownBlock { @MainActor in presenter.dispose() }
        var hints = FirstUseHints()
        var context = HintContext(dockReveal: surface.revealID)
        context.v1MinimalHints = true
        try hints.updateContext(context, at: 1)
        let offer = try XCTUnwrap(hints.nextOffer(placeable: [.findWidget], at: 1))
        XCTAssertTrue(presenter.showAndVerify(offer, trial: nil))
        XCTAssertEqual(layer.window?.isVisible, true)
    }
}
