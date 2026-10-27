// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanInstruments

@MainActor private final class ReentrantHelpRecipe:HelpUIRecipeProvider {
    let base=NeutralHelpUIRecipeProvider()
    var onRead:((String)->Void)?
    func presentation(for input:HelpUIRenderInput)->HelpUIPresentation { onRead?("presentation");return base.presentation(for:input) }
    func measure(_ text:String,width:CGFloat,role:HelpUITextRole)->CGSize { onRead?("measure");return base.measure(text,width:width,role:role) }
    func font(for role:HelpUITextRole)->NSFont { onRead?("font");return base.font(for:role) }
    var primaryInk:NSColor { onRead?("ink");return base.primaryInk }
    var secondaryInk:NSColor { base.secondaryInk }
    var panelColor:NSColor { base.panelColor }
    var borderColor:NSColor { base.borderColor }
}

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
    func testBothSourceButtonsTrackActionBindingWithoutChangingRenderInput() throws {
        var input=M4HelpFixtures.map(.compact640,.english,full:false)
        input.map.sourceActionID="about";input.map.sourceActionTitle="About"
        input.map.sourceFrame = .init(x:8,y:600,width:200,height:22)
        input.map.secondarySourceActionID="data";input.map.secondarySourceActionTitle="Data"
        input.map.secondarySourceFrame = .init(x:220,y:600,width:200,height:22)
        for initiallyBound in [false,true] {
            let view=HelpUILayerView();var actions=[HelpUIAction]()
            if initiallyBound { view.onAction={actions.append($0)} }
            view.update(input)
            let buttons=view.subviews.compactMap{$0 as? NSButton}
            XCTAssertEqual(buttons.count,2)
            if !initiallyBound {
                XCTAssertTrue(buttons.allSatisfy{!$0.isEnabled})
                view.onAction={actions.append($0)}
            }
            XCTAssertTrue(buttons.allSatisfy{$0.isEnabled})
            let layouts=view.layoutCount;view.update(input);XCTAssertEqual(view.layoutCount,layouts)
            for button in buttons { XCTAssertTrue(button.sendAction(button.action,to:button.target)) }
            XCTAssertEqual(actions.count,2)
            XCTAssertTrue(actions.contains(.mapSourceAction(actionID:"about")))
            XCTAssertTrue(actions.contains(.mapSourceAction(actionID:"data")))
            view.onAction=nil
            XCTAssertTrue(buttons.allSatisfy{!$0.isEnabled})
            let count=actions.count
            for button in buttons { XCTAssertFalse(button.sendAction(button.action,to:button.target));_ = button.accessibilityPerformPress() }
            XCTAssertEqual(actions.count,count);view.dispose()
        }
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
        XCTAssertFalse(view.outsidePointerDown());XCTAssertEqual(actions.last,.dismissContext(id:"reading",returnFocusID:nil))
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
    func testReentrantClearDuringLayoutCancellationWinsOverOuterUpdate() throws {
        let view=HelpUILayerView(elapsed:{1})
        var actions=[HelpUIAction](),receipts=[HelpUIPresentation]()
        view.onAction={actions.append($0)};view.onPresentation={receipts.append($0)}
        var next=M4HelpFixtures.hint();view.update(next)
        let stale=try XCTUnwrap(view.currentActionButton),target=stale.target,selector=try XCTUnwrap(stale.action)
        next.viewport.width+=1
        var inactive=next;inactive.active=false
        var clearPending=true
        view.onHintInput={ input in
            if case .cancelFaderRest(.layoutChange,at:_)=input,clearPending {
                clearPending=false;view.update(inactive)
            }
        }
        receipts.removeAll();view.update(next)
        XCTAssertFalse(clearPending);XCTAssertEqual(view.input,inactive)
        XCTAssertNil(view.presentation?.card);XCTAssertNil(view.presentation?.mapHeader)
        XCTAssertNil(view.currentActionButton);XCTAssertNil(view.sourceActionButton)
        XCTAssertTrue(receipts.allSatisfy {$0.card==nil && $0.mapHeader==nil})
        XCTAssertFalse(stale.sendAction(selector,to:target));XCTAssertFalse(stale.accessibilityPerformPress())
        XCTAssertFalse(view.handleEscape());XCTAssertTrue(actions.isEmpty)
        view.dispose()
    }
    func testDisposalDuringLayoutCancellationDoesNotRestorePresentationOrActions() throws {
        let view=HelpUILayerView(elapsed:{1});var actions=[HelpUIAction]()
        view.onAction={actions.append($0)}
        var next=M4HelpFixtures.hint();view.update(next)
        let stale=try XCTUnwrap(view.currentActionButton),target=stale.target,selector=try XCTUnwrap(stale.action)
        next.viewport.width+=1
        var disposalPending=true
        view.onHintInput={ input in
            if case .cancelFaderRest(.layoutChange,at:_)=input,disposalPending {
                disposalPending=false;view.dispose()
            }
        }
        view.update(next)
        XCTAssertFalse(disposalPending);XCTAssertNil(view.input);XCTAssertNil(view.presentation)
        XCTAssertNil(view.currentActionButton);XCTAssertNil(view.sourceActionButton)
        XCTAssertNil(view.onAction);XCTAssertNil(view.onHintInput);XCTAssertNil(view.onPresentation)
        XCTAssertFalse(stale.sendAction(selector,to:target));XCTAssertFalse(stale.accessibilityPerformPress())
        XCTAssertFalse(view.handleEscape());XCTAssertTrue(actions.isEmpty)
    }
    func testReentrantWithdrawalMatchingPreviousInactiveInputStillWins() {
        let view=HelpUILayerView(elapsed:{1})
        var inactive=M4HelpFixtures.hint();inactive.active=false
        view.update(inactive);view.onAction={_ in}
        var next=inactive;next.active=true;next.viewport.width+=1
        var clearPending=true
        view.onHintInput={ input in
            if case .cancelFaderRest(.layoutChange,at:_)=input,clearPending {
                clearPending=false;view.update(inactive)
            }
        }
        view.update(next)
        XCTAssertFalse(clearPending);XCTAssertEqual(view.input,inactive)
        XCTAssertNil(view.presentation?.card);XCTAssertNil(view.currentActionButton)
        XCTAssertFalse(view.handleEscape());view.dispose()
    }
    func testReentrantCancellationKeepsTheLatchedMapPressConsumedWithoutStaleActions() {
        for escape in [false,true] {
            let view=HelpUILayerView(elapsed:{1});var actions=[HelpUIAction]()
            var input=M4HelpFixtures.map(.compact640,.english,full:false);input.map.mode = .latched
            view.onAction={actions.append($0)};view.update(input)
            var inactive=input;inactive.active=false
            view.onHintInput={ _ in view.onHintInput=nil;view.update(inactive) }
            XCTAssertTrue(escape ? view.handleEscape():view.outsidePointerDown(),"the original help press must not reach the cockpit underneath")
            XCTAssertEqual(view.input,inactive);XCTAssertNil(view.presentation?.mapHeader)
            XCTAssertTrue(actions.isEmpty);view.dispose()
        }
    }
    func testReentrantRecipeClearOrDisposalCannotPublishStaleCardOrMap() {
        for stage in ["presentation","font","measure","ink"] {
            for dispose in [false,true] {
                for map in [false,true] where stage != "measure" || !map {
                    let recipe=ReentrantHelpRecipe(),view=HelpUILayerView(recipeProvider:recipe)
                    var actions=[HelpUIAction](),receipts=[HelpUIPresentation]()
                    view.onAction={actions.append($0)};view.onPresentation={receipts.append($0)}
                    let next=map ? M4HelpFixtures.map(.compact640,.english,full:false):M4HelpFixtures.hint()
                    var inactive=next;inactive.active=false
                    recipe.onRead={ call in
                        guard call==stage else { return };recipe.onRead=nil
                        if dispose { view.dispose() } else { view.update(inactive) }
                    }
                    view.update(next)
                    XCTAssertNil(recipe.onRead,"the requested recipe callout must execute")
                    if dispose { XCTAssertNil(view.input);XCTAssertNil(view.presentation) }
                    else { XCTAssertEqual(view.input,inactive);XCTAssertNil(view.presentation?.card);XCTAssertNil(view.presentation?.mapHeader) }
                    XCTAssertNil(view.currentActionButton);XCTAssertNil(view.sourceActionButton)
                    XCTAssertTrue(receipts.allSatisfy {$0.card==nil && $0.mapHeader==nil})
                    XCTAssertFalse(view.handleEscape());XCTAssertTrue(actions.isEmpty)
                    view.dispose()
                }
            }
        }
    }
}
