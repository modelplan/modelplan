// SPDX-License-Identifier: MIT
import AppKit
import CoreText
import XCTest
@testable import ModelPlanInstruments

private enum HistFixture {
    static let now=Fixtures.now
    static func cycles(_ count:Int = 15)->[InstrumentCycle] {
        (0..<count).map{.init(id:"c\($0)",endedAt:now.addingTimeInterval(-Double($0+1)*3600),used:Double($0),provenance:.unknown,
            breakdown:[.init(modelID:"model",effort:"high",fast:false,points:Double($0))],hadDrop:nil)}
    }
    static func input(cycles:[InstrumentCycle]? = cycles(),events:[SubscriptionResetEvent]? = [],attribution:UsageAttribution = .verifiedSubscription,
                      evidence:InstrumentEvidence = .init(),peak:PeakBand? = nil)->SubscriptionHistoryInput {
        .init(id:"a",header:.init(name:"Synthetic Alpha",plan:"Example",glyphID:nil,evidence:.init()),sourceLabel:"Synthetic reader",evidence:evidence,
            attribution:attribution,windows:[.init(id:"5h",period:.fiveHours,cycles:cycles,resets:events),
                .init(id:"weekly",period:.weekly,cycles:[.init(id:"weekly",endedAt:nil,used:nil,provenance:.correction,breakdown:[])],resets:nil)],peak:peak,modelNames:["model":"Synthetic model"])
    }
    static func snapshot(_ input:SubscriptionHistoryInput = input(),now:Date = now,calendar:Calendar = Fixtures.calendar())->SubscriptionHistorySnapshot {
        .init(inputs:[input],scope:.subscription("a"),now:now,language:.english,calendar:calendar)
    }
    static func nowSnapshot(calendar:Calendar = Fixtures.calendar())->SubscriptionNowSnapshot {
        .init(inputs:[.init(id:"a",header:.init(name:"Synthetic Alpha",plan:"Example",glyphID:nil,evidence:.init()),windows:[])],scope:.subscription("a"),
            now:now,language:.english,calendar:calendar,redBelow:25)
    }
}
final class SubscriptionHistoryTests:XCTestCase {
    func testF11RetainsTenInCallerOrderAfterExpiryAndFutureFiltering() {
        let invalid=[InstrumentCycle(id:"expired",endedAt:HistFixture.now,used:50,provenance:.natural,breakdown:[],evidence:.init(validUntil:HistFixture.now)),
            .init(id:"future",endedAt:HistFixture.now.addingTimeInterval(1),used:20,provenance:.natural,breakdown:[])]
        let snapshot=HistFixture.snapshot(HistFixture.input(cycles:invalid+HistFixture.cycles()))
        XCTAssertTrue(snapshot.valid)
        XCTAssertEqual(snapshot.accounts[0].windows[0].cycles.map{$0.id.components(separatedBy:".").last!},(0..<10).map{"c\($0)"})
        XCTAssertEqual(snapshot.accounts[0].windows[0].cycles[0].used,0)
        XCTAssertEqual(snapshot.accounts[0].windows[0].cycles[0].endedAt,HistFixture.now.addingTimeInterval(-3600))
    }
    func testMissingAndKnownEmptyHistoryStayDifferentAndChartless() {
        let missing=HistFixture.snapshot(HistFixture.input(cycles:nil,events:nil)).accounts[0].windows[0]
        XCTAssertTrue(missing.cycles.isEmpty);XCTAssertTrue(missing.events.isEmpty)
        XCTAssertTrue(missing.rows.allSatisfy{$0.value=="--"})
        let empty=HistFixture.snapshot(HistFixture.input(cycles:[],events:[])).accounts[0].windows[0]
        XCTAssertTrue(empty.cycles.isEmpty)
        XCTAssertTrue(empty.rows.contains{$0.value=="No cycles yet"});XCTAssertTrue(empty.rows.contains{$0.value=="No resets yet"})
        let stale=HistFixture.snapshot(HistFixture.input(cycles:[.init(id:"x",endedAt:nil,used:30,provenance:.unknown,breakdown:[],evidence:.init(freshness:.stale))],
            events:[.init(id:"e",at:nil,provenance:.natural,evidence:.init(freshness:.stale))])).accounts[0].windows[0]
        XCTAssertTrue(stale.cycles.isEmpty);XCTAssertTrue(stale.rows.allSatisfy{$0.value=="--"})
    }
    func testDropDoesNotInventRedemptionOriginOrTimestamp() {
        let cycle=InstrumentCycle(id:"drop",endedAt:nil,used:80,provenance:.unknown,breakdown:[.init(modelID:"model",effort:nil,fast:nil,points:nil)],hadDrop:true)
        let value=HistFixture.snapshot(HistFixture.input(cycles:[cycle])).accounts[0].windows[0].cycles[0]
        XCTAssertNil(value.endedAt);XCTAssertEqual(value.provenance,.unknown);XCTAssertEqual(value.hadDrop,true)
        XCTAssertTrue(value.help.body.contains("its cause is not supplied"));XCTAssertTrue(value.value.contains("Drop observed"))
        XCTAssertFalse(value.help.body.contains("Reset use"));XCTAssertFalse(value.help.body.contains("This cycle used a reset"))
        XCTAssertTrue(value.help.body.contains("Fast --"));XCTAssertTrue(value.value.hasPrefix("--"))
    }
    func testResetOriginsDatesAndFourEventRetentionUseOnlySuppliedFacts() {
        let sources:[ResetProvenance]=[.natural,.publicAnnouncement,.resetAllowance,.correction,.unknown]
        let events=sources.enumerated().map{SubscriptionResetEvent(id:"e\($0.offset)",at:$0.offset==0 ? nil:HistFixture.now.addingTimeInterval(-Double($0.offset)*600),
            provenance:$0.element,pending:$0.offset==1,waiting:$0.offset==1)}
        let window=HistFixture.snapshot(HistFixture.input(events:events)).accounts[0].windows[0]
        XCTAssertEqual(window.events.count,4);XCTAssertNil(window.events[0].at)
        XCTAssertEqual(window.events.map(\.provenance),Array(sources.prefix(4)))
        XCTAssertTrue(window.rows.contains{$0.title=="Window end" && $0.value=="--"})
        XCTAssertTrue(window.rows.contains{$0.title=="Official announcement" && $0.value.contains("Announced") && $0.value.contains("next read")})
        XCTAssertEqual(window.events[2].at,events[2].at)
        let future=HistFixture.snapshot(HistFixture.input(events:[.init(id:"future",at:HistFixture.now.addingTimeInterval(1),provenance:.publicAnnouncement)])).accounts[0].windows[0].events[0]
        XCTAssertNil(future.at);XCTAssertEqual(future.row.value,"--")
    }
    func testCurrentBindingAndStaleInputsWithholdHistoryAndPeak() {
        let band=PeakBand(from:HistFixture.now,until:HistFixture.now.addingTimeInterval(3600))!
        for input in [HistFixture.input(attribution:.sourceWideCurrentBinding,peak:band),HistFixture.input(attribution:.unattributed,peak:band),
                      HistFixture.input(evidence:.init(freshness:.stale),peak:band)] {
            let account=HistFixture.snapshot(input).accounts[0]
            XCTAssertTrue(account.windows.allSatisfy{$0.cycles.isEmpty && $0.events.isEmpty});XCTAssertNil(account.peak)
            XCTAssertTrue(account.windows[0].rows[0].value.contains("No history attributed"))
        }
    }
    func testSuppliedPeakRetainsBothInstantsAndNoPeakIsInvented() {
        XCTAssertNil(HistFixture.snapshot().accounts[0].peak)
        let band=PeakBand(from:HistFixture.now.addingTimeInterval(3600),until:HistFixture.now.addingTimeInterval(7200))!
        let peak=HistFixture.snapshot(HistFixture.input(peak:band)).accounts[0].peak!
        XCTAssertEqual(peak.from,band.from);XCTAssertEqual(peak.until,band.until);XCTAssertTrue(peak.row.value.contains("in 1h"))
        let ended=HistFixture.snapshot(HistFixture.input(peak:band),now:band.until).accounts[0].peak!
        XCTAssertTrue(ended.row.value.contains("Ended"));XCTAssertFalse(ended.row.value.contains(" · now"))
    }
    func testCycleSegmentsKeepModelEffortFastAndNeverFillUnknownRemainder() throws {
        let raw=InstrumentCycle(id:"c",endedAt:nil,used:80,provenance:.unknown,breakdown:[
            .init(modelID:"model",effort:"high",fast:false,points:30),.init(modelID:"model",effort:"high",fast:true,points:20),
            .init(modelID:"unknown",effort:nil,fast:nil,points:nil)])
        let window=HistFixture.snapshot(HistFixture.input(cycles:[raw])).accounts[0].windows[0],cycle=window.cycles[0]
        XCTAssertEqual(cycle.segments.map(\.points),[30,20,nil]);XCTAssertNotEqual(cycle.segments[0].identity,cycle.segments[1].identity)
        let g=try XCTUnwrap(SubscriptionCycleGeometry(cycle:cycle,plot:CGRect(x:10,y:20,width:200,height:24),maximum:window.maximum))
        XCTAssertEqual(g.bars.count,2);XCTAssertEqual(g.bars.map(\.rect.width),[60,40])
        XCTAssertEqual(g.bars.last?.rect.maxX,110);XCTAssertTrue(cycle.help.body.contains("Synthetic model"))
        let zero=HistFixture.snapshot(HistFixture.input(cycles:[.init(id:"zero",endedAt:nil,used:0,provenance:.unknown,breakdown:[])])).accounts[0].windows[0].cycles[0]
        XCTAssertTrue(SubscriptionCycleGeometry(cycle:zero,plot:g.plot,maximum:100)!.bars.isEmpty)
        XCTAssertNil(SubscriptionCycleGeometry(cycle:cycle,plot:g.plot,maximum:Double.nan))
    }
    func testF19RepeatedHoursKeepDistinctGivenDatesAndHostOffsets() {
        let dates=[Fixtures.instant("2026-11-01T08:30:17Z"),Fixtures.instant("2026-11-01T09:30:17Z")]
        let cycles=dates.enumerated().map{InstrumentCycle(id:"c\($0.offset)",endedAt:$0.element,used:10,provenance:.natural,breakdown:[])}
        let values=HistFixture.snapshot(HistFixture.input(cycles:cycles),now:Fixtures.instant("2026-11-01T12:00:00Z")).accounts[0].windows[0].cycles
        XCTAssertEqual(values.map(\.endedAt),dates.map(Optional.some));XCTAssertNotEqual(values[0].value,values[1].value)
        XCTAssertTrue(values[0].value.contains("3h30 ago"));XCTAssertTrue(values[1].value.contains("2h30 ago"))
    }
    func testDuplicateWindowOrCycleIDsRejectBeforePublish() {
        let input=HistFixture.input(cycles:[.init(id:"same",endedAt:nil,used:0,provenance:.unknown,breakdown:[]),.init(id:"same",endedAt:nil,used:1,provenance:.unknown,breakdown:[])])
        XCTAssertFalse(HistFixture.snapshot(input).valid)
        let duplicate=SubscriptionHistoryInput(id:"a",header:nil,sourceLabel:nil,attribution:.verifiedSubscription,
            windows:[.init(id:"same",period:.fiveHours,cycles:[]),.init(id:"same",period:.weekly,cycles:[])])
        XCTAssertFalse(HistFixture.snapshot(duplicate).valid)
    }
}
@MainActor final class SubscriptionHistoryViewTests:XCTestCase {
    private func update(_ view:MainScreenView,_ history:SubscriptionHistorySnapshot,tab:SubscriptionTab = .history)throws {
        let now=HistFixture.nowSnapshot(calendar:history.calendar)
        try view.update(inputs:[],selection:nil,publication:nil,publicationUsable:false,language:.english,compact:false,scope:history.scope,
            pages:[now.pageContent(history:history,initialTab:tab)])
    }
    private func setup(_ history:SubscriptionHistorySnapshot)throws->MainScreenView {
        let view=MainScreenView();view.onHelpChange={_,_ in};view.selectPage(.init(.subscriptions));try update(view,history);return view
    }
    func testTabAndWindowOptionsPreserveBackingChoicesAndRetireOldControls() async throws {
        let history=HistFixture.snapshot(),view=try setup(history),window=NSWindow(contentRect:view.frame,styleMask:[],backing:.buffered,defer:false);window.contentView=view
        XCTAssertNotNil(view.presentation?.history);XCTAssertNil(view.presentation?.subscription)
        let old=view.control(for:history.accounts[0].windows[0].cycles[0].id)!,cycleKey=view.control(for:"screen.footer.1")!
        XCTAssertTrue(window.makeFirstResponder(old));XCTAssertTrue(cycleKey.accessibilityPerformPress())
        XCTAssertEqual(view.presentation?.history?.window?.id,"weekly");XCTAssertFalse(old.becomeFirstResponder())
        XCTAssertTrue(view.control(for:"screen.footer.0")!.accessibilityPerformPress());XCTAssertNotNil(view.presentation?.subscription);XCTAssertNil(view.presentation?.history)
        XCTAssertFalse(cycleKey.accessibilityPerformPress())
        XCTAssertTrue(view.control(for:"screen.footer.1")!.accessibilityPerformPress())
        XCTAssertEqual(view.presentation?.subscription?.days,30)
        XCTAssertTrue(view.control(for:"screen.footer.0")!.accessibilityPerformPress());XCTAssertEqual(view.presentation?.history?.window?.id,"weekly")
        if case .blank=view.presentation!.footer[2] {} else {XCTFail("Third slot must stay blank")}
        view.dispose();window.contentView=nil
    }
    func testNativeCycleHelpAndStaticHatchUseTheSameKnownBreakdown() async throws {
        let raw=InstrumentCycle(id:"fast",endedAt:nil,used:70,provenance:.unknown,breakdown:[.init(modelID:"model",effort:"high",fast:true,points:70)],hadDrop:true)
        let history=HistFixture.snapshot(HistFixture.input(cycles:[raw])),view=try setup(history)
        var help:HelpExplanation?;view.onHelpChange={help=$0;_=$1}
        let cycle=history.accounts[0].windows[0].cycles[0],control=view.control(for:cycle.id)!
        XCTAssertTrue(control.becomeFirstResponder());XCTAssertEqual(control.accessibilityHelp(),help?.accessibleDescription);XCTAssertNil(control.toolTip)
        XCTAssertTrue(control.accessibilityLabel()!.contains("its cause is not supplied"))
        let commands=view.recipe!.list!.rows.first{$0.region.id==cycle.id}!.commands
        XCTAssertTrue(commands.contains{if case .clipped=$0{return true};return false})
        for scale in [1,2] {XCTAssertEqual(try view.rasterImage(scale:scale).width,600*scale)}
        view.dispose()
    }
    func testUnchangedHistoryKeepsBitmapScrollAndNoCreditHistoryAppears() async throws {
        let history=HistFixture.snapshot(),view=try setup(history),renders=view.surfaceRenders,displays=view.displayRequests
        for _ in 0..<100 {try update(view,history)}
        XCTAssertEqual(view.surfaceRenders,renders);XCTAssertEqual(view.displayRequests,displays)
        XCTAssertFalse(view.recipe!.list!.rows.contains{$0.region.id.contains("credits")})
        view.dispose()
    }
    func testHiddenPeriodAndMismatchedHostContextsCannotMutatePage() async throws {
        let now=HistFixture.nowSnapshot(),history=HistFixture.snapshot();var c=MainScreenController(location:.init(.subscriptions),scope:now.scope)
        try c.update(inputs:[],selection:nil,publication:nil,publicationUsable:false,pages:[now.pageContent(history:history,initialTab:.history)])
        XCTAssertTrue(c.chooseOption(id:"subscription.usage",value:"30").isEmpty)
        c.chooseOption(id:"subscription.tab",value:"now");XCTAssertTrue(c.chooseOption(id:"subscription.cycle",value:"weekly").isEmpty)
        let other=HistFixture.snapshot(calendar:Fixtures.calendar("Asia/Kathmandu"))
        XCTAssertThrowsError(try c.update(inputs:[],selection:nil,publication:nil,publicationUsable:false,pages:[now.pageContent(history:other)]))
    }
}
