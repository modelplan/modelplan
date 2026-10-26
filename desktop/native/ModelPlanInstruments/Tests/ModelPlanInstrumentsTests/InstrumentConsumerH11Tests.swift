// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanInstruments

@MainActor final class InstrumentConsumerH11Tests: XCTestCase {
    private func input() -> [FaderChannelInput] { [.init(model: Fixtures.model())] }
    private func mouse(_ view: NSView, _ type: NSEvent.EventType, _ point: CGPoint) -> NSEvent {
        if type == .mouseEntered || type == .mouseExited {
            return NSEvent.enterExitEvent(with: type, location: view.convert(point, to: nil), modifierFlags: [], timestamp: 0,
                windowNumber: view.window?.windowNumber ?? 0, context: nil, eventNumber: 0, trackingNumber: 0, userData: nil)!
        }
        return NSEvent.mouseEvent(with: type, location: view.convert(point, to: nil), modifierFlags: [], timestamp: 0,
            windowNumber: view.window?.windowNumber ?? 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 0)!
    }
    private func key(_ characters: String, code: UInt16 = 0) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
            context: nil, characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code)!
    }
    func testFaderRestIsTypedTravelAnchorInputAndNeverStartsTrial() async throws {
        var at = 10.0, events: [InstrumentHintInput] = []
        var unpressed = true
        let view = FaderBankView(elapsed: { at }, hintPointerEligible: { unpressed }); view.onHelpChange = { _, _ in }; view.onHintInput = { events.append($0) }
        try view.update(inputs: input(), publicationUsable: true, language: .english, compact: false, now: Fixtures.now)
        let travel = try XCTUnwrap(view.recipe?.regions.first { $0.role == .slider })
        let point = CGPoint(x: travel.rect.midX, y: travel.rect.midY)
        view.mouseEntered(with: mouse(view, .mouseEntered, point))
        guard case .faderRestCandidate(let anchor, let pointer, let time) = events.last else { return XCTFail("Missing typed rest candidate") }
        XCTAssertEqual(anchor.modelID, "model"); XCTAssertEqual(anchor.regionID, travel.id); XCTAssertEqual(anchor.travel, travel.rect)
        XCTAssertEqual(pointer, point); XCTAssertEqual(time, 10); XCTAssertEqual(FaderRestAnchor.requiredRest, 0.5)
        XCTAssertNil(view.controller.trial); XCTAssertEqual(view.presentation?.channels[0]?.current, .init("high"))
        at = 10.2; events = []
        view.mouseMoved(with: mouse(view, .mouseMoved, CGPoint(x: point.x, y: point.y + 1)))
        XCTAssertEqual(events.first, .cancelFaderRest(.movement, at: 10.2))
        guard case .faderRestCandidate(_, _, let restarted) = events.last else { return XCTFail("Missing restart input") }
        XCTAssertEqual(restarted, 10.2); XCTAssertNil(view.controller.trial)
        unpressed = false; events = []
        view.mouseEntered(with: mouse(view, .mouseEntered, point))
        XCTAssertFalse(events.contains { if case .faderRestCandidate = $0 { return true }; return false })
        view.dispose()
    }
    func testDragDoesNotOfferHintAndLeaveKeyFocusRemovalCancelRest() async throws {
        var events: [InstrumentHintInput] = []
        let view = FaderBankView(elapsed: { 12 }, hintPointerEligible: { true }); view.onHelpChange = { _, _ in }; view.onHintInput = { events.append($0) }
        let window = NSWindow(contentRect: view.frame, styleMask: [], backing: .buffered, defer: false); window.contentView = view
        try view.update(inputs: input(), publicationUsable: true, language: .english, compact: false, now: Fixtures.now)
        let region = try XCTUnwrap(view.recipe?.regions.first { $0.role == .slider }), control = try XCTUnwrap(view.control(for: region.id))
        let point = CGPoint(x: region.rect.midX, y: region.top!)
        view.mouseMoved(with: mouse(view, .mouseMoved, point)); events = []
        control.mouseDown(with: mouse(view, .leftMouseDown, point))
        control.mouseDragged(with: mouse(view, .leftMouseDragged, CGPoint(x: point.x, y: point.y+1)))
        XCTAssertTrue(events.contains(.cancelFaderRest(.pointerDown, at: 12)))
        XCTAssertFalse(events.contains { if case .faderRestCandidate = $0 { return true }; return false })
        control.mouseUp(with: mouse(view, .leftMouseUp, point))
        events = []; view.keyDown(with: key("\t", code: 48))
        XCTAssertTrue(events.contains(.cancelFaderRest(.keyboard, at: 12)))
        events = []; view.mouseExited(with: mouse(view, .mouseExited, point))
        XCTAssertTrue(events.contains(.cancelFaderRest(.leave, at: 12)))
        view.mouseMoved(with: mouse(view, .mouseMoved, point)); events = []
        NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: window)
        XCTAssertTrue(events.contains(.cancelFaderRest(.focusLoss, at: 12)))
        view.mouseMoved(with: mouse(view, .mouseMoved, point)); events = []
        try view.update(inputs: [], publicationUsable: true, language: .english, compact: false, now: Fixtures.now)
        XCTAssertTrue(events.contains(.cancelFaderRest(.removal, at: 12)))
        view.dispose(); window.contentView = nil
    }
    func testOnlySubscriptionNamesHaveNativeTooltipsEvenWhenNameFits() async throws {
        let engine = EngineTableView(); engine.onHelpChange = { _, _ in }
        let identities = ["a": EngineTableIdentity(name: "A", shortName: "A")]
        try engine.update(columns: [Fixtures.column("a")], identities: identities, language: .english, now: Fixtures.now)
        let name = try XCTUnwrap(engine.control(for: "engine.subscription.a"))
        XCTAssertEqual(name.toolTip, "A") // no overflow or abbreviation condition
        XCTAssertNil(engine.control(for: "engine.all")?.toolTip)
        XCTAssertNil(engine.control(for: "engine.a.today")?.toolTip)
        XCTAssertTrue(name.accessibilityPerformPress()); XCTAssertEqual(name.toolTip, "A")
        let full = ["a": EngineTableIdentity(name: "A full subscription name", shortName: "A")]
        try engine.update(columns: [Fixtures.column("a")], identities: full, language: .english, now: Fixtures.now)
        XCTAssertEqual(name.toolTip, "A full subscription name"); XCTAssertTrue(name.accessibilityHelp()?.contains("A full subscription name") == true)
        let fader = FaderBankView(); fader.onHelpChange = { _, _ in }
        try fader.update(inputs: input(), publicationUsable: true, language: .english, compact: false, now: Fixtures.now)
        for region in fader.recipe!.regions {
            XCTAssertNil(fader.control(for: region.id)?.toolTip)
            XCTAssertFalse(fader.control(for: region.id)?.accessibilityHelp()?.isEmpty ?? true)
        }
        engine.dispose(); fader.dispose()
    }
    func testCanonicalDefinitionsAreSharedDataForAXAndLaterOptionHelp() async throws {
        for language in [InstrumentLanguage.chinese, .english] {
            let catalog = HelpCatalog(language)
            XCTAssertEqual(catalog.explanation(.today).body, InstrumentHelpDefinitions.todayAverage(language))
            XCTAssertEqual(catalog.explanation(.todaySpeed).body, InstrumentHelpDefinitions.todayAverage(language))
            XCTAssertEqual(catalog.explanation(.liveSpeed).body, InstrumentHelpDefinitions.liveSpeed(language))
            XCTAssertTrue(InstrumentHelpDefinitions.liveSpeed(language).contains("5"))
            XCTAssertTrue(InstrumentHelpDefinitions.liveSpeed(language).contains("--"))
        }
        XCTAssertTrue(InstrumentHelpDefinitions.todayAverage(.english).contains("current source binding"))
        XCTAssertTrue(InstrumentHelpDefinitions.todayAverage(.chinese).contains("非历史账户归属"))
    }
}
