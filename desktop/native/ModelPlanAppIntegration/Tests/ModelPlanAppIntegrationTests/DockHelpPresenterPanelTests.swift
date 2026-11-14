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
        // D114: the find-widget hint is for a collapsed widget with a status-icon anchor.
        context.widgetConcealed = true; context.statusAnchorAvailable = true
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
        func open(_ dismiss: @escaping @MainActor (HelpUIDismissReason?) -> Void) throws {
            let viewport = try XCTUnwrap(presenter.prepareMap(surface: surface))
            let input = try XCTUnwrap(DockRequestedHelpLayout.make(session: surface.layoutID, viewport: viewport.size,
                language: .english, anchors: anchors, blocked: [], recipe: recipe))
            layer.update(input)
            XCTAssertTrue(presenter.showPreparedMap(surface: surface, dismissMap: dismiss))
        }
        func press(_ event: NSEvent?) throws { NSApplication.shared.sendEvent(try XCTUnwrap(event)) }
        let esc = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
            context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53)
        let click = NSEvent.mouseEvent(with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)
        var first: [HelpUIDismissReason?] = [], second: [HelpUIDismissReason?] = []
        // Showing again replaces the first monitor: one Esc reaches only the newest handler, once.
        try open { first.append($0) }
        XCTAssertEqual(activations, 1, "opening the map brings the app forward")
        XCTAssertTrue(presenter.showPreparedMap(surface: surface, dismissMap: { second.append($0) }), "called again without prepareMap")
        try press(esc)
        XCTAssertEqual(first, [], "a replaced map's monitor is gone")
        XCTAssertEqual(second, [.escape], "one Esc press closes the Help map once")
        // A click outside, on a fresh map.
        var third: [HelpUIDismissReason?] = []
        try open { third.append($0) }
        try press(click)
        XCTAssertEqual(third, [.pointer], "one click outside closes the Help map once")
        XCTAssertEqual(second, [.escape], "no earlier monitor answered the click")
    }

    /// Build 14f walkthrough (run 43598335618): after Help from the status menu macOS refused to activate the
    /// accessory app (Finder kept the menu bar), so the local monitor saw neither Esc nor clicks and the map stayed
    /// up although it says "Press Esc or click to dismiss help". With activation refused, the map panel itself
    /// takes keyboard focus without activating the app, and a click in another app reaches a global monitor.
    func testRequestedMapDismissesWithEscAndOutsideClickWhenActivationIsRefused() throws {
        let screen = try XCTUnwrap(NSScreen.main)
        let anchor = CGRect(x: screen.visibleFrame.midX, y: screen.visibleFrame.midY, width: 40, height: 40)
        let recipe = NeutralHelpUIRecipeProvider()
        let anchors: [DockRequestedHelpAnchor] = [.init(id: "ring", region: .rings, rect: CGRect(x: 100, y: 100, width: 40, height: 40), visible: true)]
        var surface = DockHelpSurface(revealID: UUID(), layoutID: UUID(), visible: true, dragging: false, anchors: [:])
        surface.mapAnchors = [.init(id: "ring", region: .rings, rect: anchor, visible: true)]
        let layer = HelpUILayerView(recipeProvider: recipe)
        var outside: [@MainActor () -> Void] = []
        var removed = 0
        let presenter = DockHelpPresenter(currentSurface: { surface }, isCurrent: { _ in true }, blockers: { _ in [] },
            windowPolicy: { _ in (.readOnly, []) }, language: { .english }, accessibility: { (true, true) },
            copy: { _, _ in nil }, dismiss: { _ in }, activate: { /* macOS refused: the app stays inactive */ },
            outsidePointerMonitor: { handler in outside.append(handler); return { removed += 1 } }, layer: layer)
        addTeardownBlock { @MainActor in presenter.dispose() }
        func open(_ dismiss: @escaping @MainActor (HelpUIDismissReason?) -> Void) throws {
            let viewport = try XCTUnwrap(presenter.prepareMap(surface: surface))
            let input = try XCTUnwrap(DockRequestedHelpLayout.make(session: surface.layoutID, viewport: viewport.size,
                language: .english, anchors: anchors, blocked: [], recipe: recipe))
            layer.update(input)
            XCTAssertTrue(presenter.showPreparedMap(surface: surface, dismissMap: dismiss))
        }
        let esc = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
            context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53))
        var first: [HelpUIDismissReason?] = []
        try open { first.append($0) }
        let panel = try XCTUnwrap(presenter.panelForChecks)
        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel), "taking focus never activates the app")
        XCTAssertTrue(panel.canBecomeKey, "the map panel takes keyboard focus without app activation")
        XCTAssertFalse(panel.canBecomeMain)
        // Esc as the window server delivers it to a key panel of an inactive app: straight to the window,
        // never through NSApplication.sendEvent and its local monitors.
        panel.sendEvent(esc)
        XCTAssertEqual(first, [.escape], "Esc closes the map without app activation")
        presenter.endMap()
        XCTAssertFalse(panel.canBecomeKey, "a closed map gives up keyboard focus")
        XCTAssertEqual(removed, outside.count, "every outside-click monitor is removed with its map")
        // A click in another app, on a fresh map: only the newest monitor answers, once.
        var second: [HelpUIDismissReason?] = []
        try open { second.append($0) }
        let monitor = try XCTUnwrap(outside.last)
        XCTAssertEqual(removed, outside.count - 1)
        monitor()
        XCTAssertEqual(second, [.pointer], "a click outside the app closes the map")
        outside.dropLast().forEach { $0() }
        XCTAssertEqual(first, [.escape], "a closed map's monitor does nothing")
        presenter.endMap()
        monitor()
        XCTAssertEqual(second, [.pointer], "a click after the map closed does nothing")
        // Hints never take the keyboard.
        XCTAssertFalse(panel.canBecomeKey)
    }
}
