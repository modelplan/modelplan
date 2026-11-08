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

    /// Build 14 walkthrough: Esc did not close the Help map. The map opens the app so its keyboard and
    /// pointer events reach the monitor, and a real Esc key event and a click outside both dismiss it.
    func testRequestedMapActivatesTheAppAndEscAndOutsideClickDismissIt() throws {
        let screen = try XCTUnwrap(NSScreen.main)
        let anchor = CGRect(x: screen.visibleFrame.midX, y: screen.visibleFrame.midY, width: 40, height: 40)
        let recipe = NeutralHelpUIRecipeProvider()
        let anchors: [DockRequestedHelpAnchor] = [.init(id: "ring", region: .rings, rect: CGRect(x: 100, y: 100, width: 40, height: 40), visible: true)]
        var surface = DockHelpSurface(revealID: UUID(), layoutID: UUID(), visible: true, dragging: false, anchors: [:])
        surface.mapAnchors = [.init(id: "ring", region: .rings, rect: anchor, visible: true)]
        let layer = HelpUILayerView(recipeProvider: recipe)
        var activations = 0
        let presenter = DockHelpPresenter(currentSurface: { surface }, isCurrent: { _ in true }, blockers: { _ in [] },
            windowPolicy: { _ in (.readOnly, []) }, language: { .english }, accessibility: { (true, true) },
            copy: { _, _ in nil }, dismiss: { _ in }, activate: { activations += 1 }, layer: layer)
        addTeardownBlock { @MainActor in presenter.dispose() }
        func open() throws -> [HelpUIDismissReason?] {
            let viewport = try XCTUnwrap(presenter.prepareMap(surface: surface))
            let input = try XCTUnwrap(DockRequestedHelpLayout.make(session: surface.layoutID, viewport: viewport.size,
                language: .english, anchors: anchors, blocked: [], recipe: recipe))
            layer.update(input)
            var reasons: [HelpUIDismissReason?] = []
            XCTAssertTrue(presenter.showPreparedMap(surface: surface, dismissMap: { reasons.append($0) }))
            return reasons
        }
        _ = try open()
        XCTAssertEqual(activations, 1, "opening the map brings the app forward")
        func key(_ code: UInt16) -> NSEvent? {
            NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
                             context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: code)
        }
        var reasons: [HelpUIDismissReason?] = []
        XCTAssertTrue(presenter.showPreparedMap(surface: surface, dismissMap: { reasons.append($0) }))
        NSApplication.shared.sendEvent(try XCTUnwrap(key(53)))
        XCTAssertEqual(reasons, [.escape], "Esc closes the Help map")
        let click = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        XCTAssertTrue(presenter.showPreparedMap(surface: surface, dismissMap: { reasons.append($0) }))
        NSApplication.shared.sendEvent(click)
        XCTAssertEqual(reasons, [.escape, .pointer], "a click outside closes the Help map")
    }
}
