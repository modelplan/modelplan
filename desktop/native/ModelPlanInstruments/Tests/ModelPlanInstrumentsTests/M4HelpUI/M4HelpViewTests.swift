// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanInstruments

@MainActor final class M4HelpViewTests:XCTestCase {
    private func text(_ view:NSView)->[String] { ((view as? NSTextField).map { [$0.stringValue] } ?? [])+view.subviews.flatMap(text) }
    func testHostOfferIsGeometryOnlyAndStaleHintButtonsCannotDismissANewOffer() throws {
        var now:Double=1,actions=[HelpUIAction](),receipts=[HelpUIPresentation]()
        let view=HelpUILayerView(elapsed:{now});view.onAction={actions.append($0)};view.onPresentation={receipts.append($0)}
        var input=M4HelpFixtures.hint();view.update(input)
        let first=try XCTUnwrap(view.currentActionButton),target=first.target,selector=try XCTUnwrap(first.action)
        let firstID=try XCTUnwrap(input.firstUse?.offerID)
        XCTAssertEqual(view.presentation?.card?.identity,.firstUse(firstID));XCTAssertTrue(actions.isEmpty)
        let layouts=view.layoutCount;view.update(input);XCTAssertEqual(view.layoutCount,layouts)
        now=100;view.update(input)
        XCTAssertEqual(view.presentation?.card?.identity,.firstUse(firstID),"only the host lifetime removes a hint")
        let secondID=UUID();input.firstUse = .init(offerID:secondID,anchorID:"travel",text:"Another synthetic offer",dismissTitle:"Dismiss")
        view.update(input)
        let second=try XCTUnwrap(view.currentActionButton);XCTAssertFalse(first===second)
        XCTAssertFalse(first.sendAction(selector,to:target));_ = NSApplication.shared.sendAction(selector,to:target,from:first)
        XCTAssertFalse(first.accessibilityPerformPress());XCTAssertTrue(actions.isEmpty)
        XCTAssertTrue(second.sendAction(second.action,to:second.target))
        XCTAssertEqual(actions,[.dismissHint(offerID:secondID,reason:.explicitButton)])
        XCTAssertEqual(receipts.last?.card?.identity,.firstUse(secondID))
        input.firstUse=nil;view.update(input);XCTAssertNil(view.presentation?.card)
        view.dispose()
    }
    func testHeldAndLatchedMapShareContentButOnlyLatchedPressIsConsumed() throws {
        var input=M4HelpFixtures.map(.compact640,.english,full:false)
        input.map.sourceActionID="methodology";input.map.sourceActionTitle="Where the data comes from"
        input.map.sourceFrame = .init(x:8,y:600,width:400,height:22)
        var actions=[HelpUIAction]()
        let view=HelpUILayerView();view.onAction={actions.append($0)};view.update(input)
        let labels=try XCTUnwrap(view.presentation?.mapLabels)
        XCTAssertFalse(labels.isEmpty);XCTAssertNil(view.currentActionButton)
        XCTAssertNil(view.hitTest(.init(x:600,y:400)),"held Option map must not intercept instrument clicks")
        XCTAssertFalse(view.outsidePointerDown());XCTAssertTrue(actions.isEmpty)
        input.map.mode = .latched;view.update(input)
        XCTAssertEqual(view.presentation?.mapLabels,labels)
        XCTAssertTrue(view.hitTest(.init(x:600,y:400)) === view)
        XCTAssertTrue(view.outsidePointerDown())
        XCTAssertEqual(actions.last,.dismissMap(reason:.pointer,returnFocusID:"tray"))
        XCTAssertTrue(view.handleEscape());XCTAssertEqual(actions.last,.dismissMap(reason:.escape,returnFocusID:"tray"))
        let source=try XCTUnwrap(view.sourceActionButton)
        XCTAssertTrue(source.sendAction(source.action,to:source.target))
        XCTAssertEqual(actions.last,.mapSourceAction(actionID:"methodology"))
        let title=HelpMapCatalog(.english)
        XCTAssertTrue(text(view).contains(title.metaphor+"\n"+title.dismissal))
        view.dispose()
    }
    func testContextUsesCanonicalTwoLineContentAndUnboundLayerDoesNotTakeInput() throws {
        var input=M4HelpFixtures.hint();input.firstUse=nil
        let explanation=HelpCatalog(.english).explanation(.todaySpeed,context:.init(value:"58 t/s"))
        input.contextual = .init(id:"reading",anchorID:"travel",explanation:explanation,actionID:"public-source",actionTitle:"Source")
        let view=HelpUILayerView();view.update(input)
        XCTAssertTrue(text(view).contains(explanation.title));XCTAssertTrue(text(view).contains(explanation.body))
        XCTAssertFalse(try XCTUnwrap(view.currentActionButton).isEnabled);XCTAssertFalse(view.handleEscape())
        var actions=[HelpUIAction]();view.onAction={actions.append($0)}
        let button=try XCTUnwrap(view.currentActionButton);XCTAssertTrue(button.isEnabled)
        XCTAssertTrue(button.sendAction(button.action,to:button.target))
        XCTAssertEqual(actions.last,.contextualAction(id:"reading",actionID:"public-source"))
        XCTAssertTrue(view.handleEscape());XCTAssertEqual(actions.last,.dismissContext(id:"reading",returnFocusID:"travel"))
        for field in view.subviews.flatMap(\.subviews) { XCTAssertNil(field.toolTip) }
        view.dispose()
    }
    func testLayoutAndKeyboardCancellationUseInjectedClockAndSuspendRetiresControls() throws {
        var clock:Double=7,cancellations=[InstrumentHintInput]()
        let view=HelpUILayerView(elapsed:{clock});view.onAction={_ in};view.onHintInput={cancellations.append($0)}
        var input=M4HelpFixtures.hint();view.update(input)
        XCTAssertEqual(cancellations.last,.cancelFaderRest(.layoutChange,at:7))
        let button=try XCTUnwrap(view.currentActionButton),target=button.target,selector=try XCTUnwrap(button.action)
        clock=8;view.suspend()
        XCTAssertTrue(cancellations.contains(.cancelFaderRest(.focusLoss,at:8)))
        XCTAssertNil(view.presentation?.card);XCTAssertFalse(button.sendAction(selector,to:target));XCTAssertFalse(view.handleEscape())
        input.viewport = .init(width:CGFloat.nan,height:640);view.update(input)
        XCTAssertNil(view.presentation?.card);XCTAssertTrue(view.bounds.width.isFinite)
        view.dispose()
        XCTAssertNil(view.input);XCTAssertNil(view.presentation)
    }
    func testMapSuppressesAHostHintAndMissingPlacementDoesNotEmitDismissal() {
        var input=M4HelpFixtures.map(.tall890,.chinese,full:false)
        input.firstUse = .init(offerID:UUID(),anchorID:HelpMapRegion.window.rawValue,text:"Synthetic hint",dismissTitle:"Dismiss")
        var actions=[HelpUIAction](),receipts=[HelpUIPresentation]()
        let view=HelpUILayerView();view.onAction={actions.append($0)};view.onPresentation={receipts.append($0)}
        view.update(input)
        XCTAssertNotNil(view.presentation?.mapHeader);XCTAssertNil(view.presentation?.card)
        XCTAssertTrue(actions.isEmpty)
        input.map.mode = .hidden;input.liveReadings=[HelpUIGeometry.safe(input.viewport)];view.update(input)
        XCTAssertNil(receipts.last?.card);XCTAssertTrue(actions.isEmpty)
        XCTAssertNil(view.hitTest(.init(x:640,y:120)))
        view.dispose()
    }
}
