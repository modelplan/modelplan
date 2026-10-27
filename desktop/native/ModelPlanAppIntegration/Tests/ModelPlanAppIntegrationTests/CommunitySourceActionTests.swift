// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanCore
import ModelPlanAssembly
import ModelPlanInstruments
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor private final class SourceScheduler: HintDeadlineScheduling {
    var arms=0
    func arm(at:Double,_ action:@escaping @MainActor ()->Void) { arms+=1 }
    func cancel() {}
}
@MainActor private final class SourceFacts {
    var publishedAt:Date?
    var opened:[InstrumentWebsiteLink]=[]
    var onOpen:(()->Void)?
}
@MainActor final class CommunitySourceActionTests:XCTestCase {
    private let now=Date(timeIntervalSince1970:1_800_000_000)
    private func packet(language:InstrumentLanguage,exact:Bool=false)throws->AssembledModelSelection {
        let model:[String:Any]=["id":"model","name":"Model","developerId":"dev","lineageId":"line","lineageStatus":"current","defaultSelected":true,
            "recommended":"high","efforts":[["effort":"high","label":"High","ability":10,"cost":2,"time":3]]]
        let wire:[String:Any]=["schemaVersion":1,"publicationId":"p","selectionRevision":"r",
            "units":["ability":"websiteAbility","cost":"usdPerReferenceTask","time":"taskTimeCrossModel"],"models":[model],"lineups":[]]
        let personal:[String:Any]=["schemaVersion":1,"kind":"modelplan.personal-snapshot","generatedAt":ISO8601DateFormatter().string(from:now),
            "validUntil":ISO8601DateFormatter().string(from:now.addingTimeInterval(300)),"publication":["publicationId":"p"],"subscriptions":[]]
        var assembly=SelectionAssembly()
        return assembly.evaluate(feeds:.init(publication:try FeedDecoder.publication(JSONSerialization.data(withJSONObject:wire)),
            personal:exact ? try FeedDecoder.personal(JSONSerialization.data(withJSONObject:personal)):nil,personalUsable:exact),scope:.all,language:language,now:now)
    }
    private func setup(exact:Bool=false)async throws->(CommunityInstrumentView,InstrumentHelpComposition,SourceFacts,SourceScheduler,SettingsApplicationCoordinator) {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent("source-help-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
        addTeardownBlock { try? FileManager.default.removeItem(at:dir) }
        let facts=SourceFacts();facts.publishedAt=now.addingTimeInterval(-1800)
        let provider=CommunityInstrumentSurfaceProvider { link in facts.opened.append(link);facts.onOpen?() }
        let app=SettingsApplicationCoordinator(store:try SettingsStore(url:dir.appendingPathComponent("prefs.json"))) { provider.apply($0) }
        let scheduler=SourceScheduler(),help=await InstrumentHelpComposition.restored(application:app,scheduler:scheduler,uptime:{0})
        provider.bindHelp(help)
        let surface=try XCTUnwrap(provider.makeOverview() as? CommunityInstrumentView)
        surface.requestFreshSelection={ [weak surface] in
            guard let surface else { return }
            surface.render(selection:try! self.packet(language:surface.instrumentLanguage,exact:exact),publishedAt:facts.publishedAt,now:self.now)
        }
        surface.resumePresentation()
        return (surface,help,facts,scheduler,app)
    }
    func testHeldOptionUsesRealAgeAndBothSourceButtonsWithoutSpendingHints()async throws {
        let (surface,help,facts,scheduler,_)=try await setup();defer{surface.dispose();help.dispose()}
        let size=surface.preferredContentSize,bitmapCount=surface.mainScreen.surfaceRenders
        surface.setOptionHelpHeld(true)
        XCTAssertEqual(help.layer.input?.map.mode,.heldOption)
        XCTAssertNotNil(help.layer.presentation?.mapSourceFrame)
        XCTAssertNotNil(help.layer.presentation?.secondaryMapSourceFrame)
        let source=InstrumentPublicationSource(publishedAt:facts.publishedAt,now:now,language:surface.instrumentLanguage)
        XCTAssertTrue(help.layer.input?.map.sourceActionTitle?.contains(source.age)==true)
        let buttons=help.layer.subviews.compactMap{$0 as? NSButton}
        XCTAssertEqual(buttons.count,2)
        // AX return values are not physical-display proof; assert actual routed effects below.
        for button in buttons { _ = button.accessibilityPerformPress() }
        XCTAssertEqual(Set(facts.opened.map(\.url)),Set(source.links.map(\.url)))
        XCTAssertTrue(help.host.hints.preferences.seen.isEmpty);XCTAssertNil(help.host.hints.offered)
        XCTAssertEqual(scheduler.arms,0);XCTAssertEqual(surface.preferredContentSize,size)
        XCTAssertEqual(surface.mainScreen.surfaceRenders,bitmapCount);XCTAssertNil(surface.mainScreen.window)
    }
    func testFreshUnknownAndLanguageRetireOldSourceActions()async throws {
        let (surface,help,facts,_,app)=try await setup();defer{surface.dispose();help.dispose()}
        surface.setOptionHelpHeld(true)
        let old=try XCTUnwrap(help.layer.input?.map.sourceActionID),held=help.onHelpAction
        facts.publishedAt=now.addingTimeInterval(10);surface.requestFreshSelection?()
        XCTAssertNil(surface.sourceStamp.publishedAt)
        XCTAssertTrue(help.layer.input?.map.sourceActionTitle?.contains("发布时间未知")==true)
        held?(.mapSourceAction(actionID:old));XCTAssertTrue(facts.opened.isEmpty)
        held?(.dismissMap(reason:.escape,returnFocusID:nil))
        XCTAssertEqual(help.layer.input?.map.mode,.heldOption)
        _=try await app.editor.commit(SettingsB21Edit.language(.english))
        XCTAssertTrue(help.layer.input?.map.sourceActionTitle?.contains("Publication age unknown")==true)
        XCTAssertEqual(help.layer.input?.map.secondarySourceActionTitle,InstrumentWebsiteLink.dataSource(language:.english).title)
    }
    func testSuspendCloseDisposeAndEscapeCannotResurrectOrOpenOldActions()async throws {
        let (surface,help,facts,_,_)=try await setup();defer{surface.dispose();help.dispose()}
        surface.setOptionHelpHeld(true)
        let id=try XCTUnwrap(help.layer.input?.map.sourceActionID),held=help.onHelpAction
        XCTAssertTrue(surface.mainScreen.handleEscape())
        surface.setOptionHelpHeld(true);XCTAssertEqual(help.layer.input?.map.mode,.hidden)
        surface.setOptionHelpHeld(false);surface.setOptionHelpHeld(true)
        XCTAssertNotNil(help.layer.presentation?.mapSourceFrame)
        surface.suspendPresentation();held?(.mapSourceAction(actionID:id));XCTAssertTrue(facts.opened.isEmpty)
        surface.resumePresentation();XCTAssertEqual(help.layer.input?.map.mode,.hidden)
        surface.setOptionHelpHeld(true);surface.closePresentation();XCTAssertNil(help.layer.presentation?.mapSourceFrame)
        surface.dispose();held?(.mapSourceAction(actionID:id));XCTAssertTrue(facts.opened.isEmpty)
    }
    func testActualComparisonWebsiteIntentIsCurrentAndReentrantCloseStopsBatch()async throws {
        let (surface,help,facts,_,_)=try await setup(exact:true);defer{surface.dispose();help.dispose()}
        surface.selectModel("model")
        let link=try XCTUnwrap(surface.mainScreen.presentation?.websiteLinks.first)
        surface.mainScreen.onIntents?([.openWebsite(.sourceAbout(language:.chinese))]);XCTAssertTrue(facts.opened.isEmpty)
        facts.onOpen={ [weak surface] in surface?.closePresentation() }
        let callback=surface.mainScreen.onIntents
        callback?([.openWebsite(link),.openWebsite(link)])
        XCTAssertEqual(facts.opened,[link]);callback?([.openWebsite(link)]);XCTAssertEqual(facts.opened,[link])
    }
    func testHelpEscapePrecedesComparisonBackWithoutClearingItsTrial()async throws {
        let (surface,help,_,_,_)=try await setup(exact:true);defer{surface.dispose();help.dispose()}
        surface.selectModel("model");XCTAssertEqual(surface.mainScreen.controller.trial?.modelID,"model")
        surface.setOptionHelpHeld(true)
        XCTAssertTrue(surface.mainScreen.handleEscape())
        XCTAssertEqual(surface.mainScreen.controller.trial?.modelID,"model")
        XCTAssertEqual(help.layer.input?.map.mode,.hidden)
        XCTAssertTrue(surface.mainScreen.handleEscape());XCTAssertNil(surface.mainScreen.controller.trial)
    }
    func testActualModifierResponderRouteRetiresButtonsOnOptionRelease()async throws {
        let (surface,help,facts,_,_)=try await setup();defer{surface.dispose();help.dispose()}
        let down=try XCTUnwrap(NSEvent.keyEvent(with:.flagsChanged,location:.zero,modifierFlags:.option,timestamp:1,
            windowNumber:0,context:nil,characters:"",charactersIgnoringModifiers:"",isARepeat:false,keyCode:58))
        surface.view.flagsChanged(with:down)
        XCTAssertEqual(help.layer.input?.map.mode,.heldOption)
        let old=help.layer.subviews.compactMap{$0 as? NSButton};XCTAssertEqual(old.count,2)
        let up=try XCTUnwrap(NSEvent.keyEvent(with:.flagsChanged,location:.zero,modifierFlags:[],timestamp:2,
            windowNumber:0,context:nil,characters:"",charactersIgnoringModifiers:"",isARepeat:false,keyCode:58))
        surface.view.flagsChanged(with:up)
        XCTAssertEqual(help.layer.input?.map.mode,.hidden)
        for button in old { XCTAssertFalse(button.isEnabled);_ = button.accessibilityPerformPress() }
        XCTAssertTrue(facts.opened.isEmpty);XCTAssertNil(surface.view.window)
    }
    func testOccupiedViewportDoesNotPublishSourceControls() {
        let map=CommunityOptionHelpLayout.map(viewport:.init(width:600,height:372),readings:[.init(x:0,y:0,width:600,height:372)],sourceTitle:"Unknown · About",dataTitle:"Data",about:"a",data:"b")
        XCTAssertNil(map.sourceFrame);XCTAssertNil(map.secondarySourceFrame)
        let input=HelpUIRenderInput(sessionID:UUID(),viewport:.init(width:600,height:372),profile:.compact640,language:.english,
            anchors:[.init(id:"community.main-screen",rect:.init(x:12,y:40,width:60,height:20))],liveReadings:[.init(x:0,y:0,width:600,height:372)],map:map)
        let p=NeutralHelpUIRecipeProvider().presentation(for:input)
        XCTAssertNil(p.mapSourceFrame);XCTAssertNil(p.secondaryMapSourceFrame)
    }
    func testReentrantCloseDuringMapPublicationWinsAndUnknownDatesStayUnknown()async throws {
        let (surface,help,facts,_,_)=try await setup();defer{surface.dispose();help.dispose()}
        help.layer.onPresentation={p in if p.mapHeader != nil {surface.closePresentation()} }
        surface.setOptionHelpHeld(true)
        XCTAssertFalse(surface.isPresented);XCTAssertNil(help.layer.presentation?.mapSourceFrame)
        XCTAssertTrue(facts.opened.isEmpty);XCTAssertTrue(help.host.hints.preferences.seen.isEmpty)
        XCTAssertNil(PublicationSourceStamp(publishedAt:Date(timeIntervalSinceReferenceDate:.nan),observedAt:now).publishedAt)
        XCTAssertNil(PublicationSourceStamp(publishedAt:now,observedAt:Date(timeIntervalSinceReferenceDate:.infinity)).publishedAt)
    }
}
