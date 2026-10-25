// SPDX-License-Identifier: MIT
import Foundation
import CoreGraphics
#if canImport(ModelPlanDock)
import ModelPlanDock
#endif

struct CheckFailure: Error, CustomStringConvertible { let description: String }
var assertions = 0, groups = 0
func expect(_ value: @autoclosure () throws -> Bool, _ message: String, file: StaticString = #fileID, line: UInt = #line) throws {
    assertions += 1
    if try !value() { throw CheckFailure(description: "\(file):\(line) \(message)") }
}
func rejects(_ expected: DockLogicError, _ body: () throws -> Void) throws {
    do { try body(); throw CheckFailure(description: "Expected \(expected)") }
    catch let actual as DockLogicError { try expect(actual == expected, "error category") }
}
func test(_ name: String, _ body: () throws -> Void) throws {
    try body(); groups += 1; print("PASS \(name)")
}
let now = Date(timeIntervalSince1970: 1_700_000_000)
func fresh(_ id: String, _ alert: DockAlertSeverity = .none) -> DockSubscriptionSignal {
    var s = DockSubscriptionSignal(id: id); s.dataState = .fresh; s.alert = alert; return s
}
func reset(_ id: String = "public-event", confirmed: Bool = false) -> DockResetSignal {
    DockResetSignal(id: id, status: confirmed ? .confirmed : .announced,
                    announcedAt: now.addingTimeInterval(-100), confirmedAt: confirmed ? now : nil)
}

do {
    try test("preferences: canonical IDs, hidden state, reconnect and Codable") {
        var p = DockSubscriptionPreferences(order: ["gone", "b", "b", "", "a"], hiddenIDs: ["a"])
        try expect(p.order == ["gone", "b", "a"], "deduplicated preferences")
        try expect(p.orderedIDs(in: ["a", "b", "c"], visibleOnly: true) == ["b", "c"], "hide without deleting order")
        try p.move("c", to: 0, in: ["a", "b", "c"])
        try expect(p.orderedIDs(in: ["a", "b", "c"]) == ["c", "b", "a"], "move appended ID")
        try expect(p.orderedIDs(in: ["a", "b", "c", "gone"]).first == "gone", "reconnect preference retained")
        let d = try JSONEncoder().encode(p), q = try JSONDecoder().decode(DockSubscriptionPreferences.self, from: d)
        try expect(p == q, "presentation-only round trip")
        try rejects(.invalidCatalogue) { _ = try p.orderedIDs(in: ["a", "a"]) }
        try rejects(.invalidCatalogue) { _ = try p.orderedIDs(in: [""]) }
        p.resetOrder(); try expect(p.order.isEmpty && p.hiddenIDs == ["a"], "reset order does not unhide")
    }
    try test("reorder: drop in both directions, repeated hover, cancel, one commit") {
        var p = DockSubscriptionPreferences(); let catalogue = ["a", "b", "c", "d"]
        var drag = try p.beginReorder("a", in: catalogue)
        try drag.hover(over: "c"); try expect(drag.preview == ["b", "c", "a", "d"], "downward drop matches source rule")
        try drag.hover(over: "c"); try expect(drag.preview == ["b", "c", "a", "d"] && p.order.isEmpty, "idempotent preview never persists")
        try drag.commit(into: &p, catalogue: catalogue)
        try rejects(.staleReorder) { try drag.commit(into: &p, catalogue: catalogue) }
        var up = try p.beginReorder("d", in: catalogue); try up.hover(over: "b"); try up.commit(into: &p, catalogue: catalogue)
        try expect(p.orderedIDs(in: catalogue) == ["d", "b", "c", "a"], "upward drop")
        let before = p; var cancel = try p.beginReorder("a", in: catalogue); try cancel.hover(over: "d"); cancel.cancel()
        try rejects(.staleReorder) { try cancel.commit(into: &p, catalogue: catalogue) }; try expect(p == before, "cancel keeps preferences")
    }
    try test("reorder: concurrent preference/catalogue changes invalidate transactions") {
        var p = DockSubscriptionPreferences(), a = try p.beginReorder("a", in: ["a", "b"])
        try a.hover(over: "b"); try p.move("b", to: 0, in: ["a", "b"])
        try rejects(.staleReorder) { try a.commit(into: &p, catalogue: ["a", "b"]) }
        p.resetOrder(); try rejects(.staleReorder) { try a.commit(into: &p, catalogue: ["a", "b"]) }
        var b = try p.beginReorder("a", in: ["a", "b"])
        try rejects(.staleReorder) { try b.commit(into: &p, catalogue: ["a"]) }
        try expect(p.order.isEmpty, "removed ID never resurrected")
    }
    try test("reorder: complete permutation invariants across 1...30 IDs") {
        for n in 1...30 {
            let ids = (0..<n).map { "套餐-\($0)" }
            for source in ids { for destination in [0,n/2,n-1] {
                var p = DockSubscriptionPreferences(hiddenIDs: Set(ids.prefix(1)))
                try p.move(source, to: destination, in: ids)
                let result = try p.orderedIDs(in: ids)
                try expect(result.count == n && Set(result) == Set(ids), "no duplicate/lost IDs")
                try expect(result[destination] == source, "final requested position")
                try expect(result.filter { $0 != source } == ids.filter { $0 != source }, "other relative order preserved")
            } }
        }
    }
    try test("visibility: reveal dwell, arrival guard and explicit keyboard entry") {
        var state = DockVisibilityState(), input = DockPresence(); input.pointer = .wake
        let first = try state.step(input, at: 0); try expect(first.nextDeadline == 0.15, "reveal deadline")
        try expect(try state.step(input, at: 0.149).state == .sliver, "dwell not complete")
        let shown = try state.step(input, at: 0.15); try expect(shown.didReveal && shown.state == .expanded, "single reveal")
        try expect(!state.acceptsPress(at: 0.2) && state.acceptsPress(at: 0.451), "arrival pointer guard")
        try expect(state.acceptsPress(at: 0.2, keyboardOrAccessibility: true), "explicit AX not pointer-guarded")
        try expect(!(try state.step(input, at: 5)).didReveal, "stationary wake never reopens/acknowledges twice")
        var quick = DockVisibilityState(); input.pointer = .outside
        try expect(try quick.step(input, at: 0, intent: .reveal).didReveal, "explicit reveal bypasses hover dwell")
    }
    try test("visibility: card overshoot, grace/reentry, unknown pointer") {
        var state = DockVisibilityState(), input = DockPresence(); input.pointer = .inside
        _ = try state.step(input, at: 0, intent: .reveal); input.pointer = .outside
        try expect(try state.step(input, at: 1).nextDeadline == 1.5, "leave absolute deadline")
        try expect(try state.step(input, at: 1.45).state == .expanded, "450ms overshoot retained")
        input.pointer = .inside; _ = try state.step(input, at: 1.46)
        input.pointer = .outside; _ = try state.step(input, at: 2)
        try expect(try state.step(input, at: 2.4).state == .expanded, "400ms outside retained")
        let hidden = try state.step(input, at: 2.6); try expect(hidden.didCollapse && !hidden.forcedHide, "600ms outside hides")
        _ = try state.step(input, at: 3, intent: .reveal); input.pointer = .unknown
        try expect(try state.step(input, at: 100).state == .expanded, "unknown pointer cannot be taken as outside")
    }
    try test("visibility: stale locks expire but each real protection survives") {
        for lock in [DockRecordedLocks.drag, .menu, .keyboard] {
            var state = DockVisibilityState(), input = DockPresence(); input.pointer = .outside; input.recordedLocks = lock
            _ = try state.step(input, at: 0, intent: .reveal); _ = try state.step(input, at: 1)
            try expect(try state.step(input, at: 2.99).state == .expanded, "stale lock grace")
            let hidden = try state.step(input, at: 3.1)
            try expect(hidden.forcedHide && hidden.clearRecordedLocks == lock, "recovery clears stale lock")
        }
        for protection in 0..<4 {
            var state = DockVisibilityState(), input = DockPresence(); input.pointer = .outside; input.recordedLocks = [.drag,.menu,.keyboard]
            switch protection {case 0:input.mouseButtonDown=true;case 1:input.menuActuallyOpen=true;case 2:input.ignitionHeld=true;default:input.cardPinned=true}
            _ = try state.step(input, at: 0, intent: .reveal); _ = try state.step(input, at: 1)
            try expect(try state.step(input, at: 10).state == .expanded, "genuine protection remains")
            input.mouseButtonDown=false;input.menuActuallyOpen=false;input.ignitionHeld=false;input.cardPinned=false
            try expect(try state.step(input, at: 11).forcedHide, "release permits overdue stale recovery")
        }
    }
    try test("visibility: suppression, lifecycle and invalid clock/config") {
        for mode in 0..<4 {
            var state = DockVisibilityState(), input = DockPresence(); input.pointer = .wake
            switch mode {case 0:input.enabled=false;case 1:input.cockpitClosed=false;case 2:input.allowedOverFullscreen=false;default:input.outerEdge=false}
            let result=try state.step(input, at: 0, intent: .reveal)
            if case .suppressed = result.state {} else { throw CheckFailure(description:"suppression overrides reveal") }
            try expect(result.nextDeadline == nil, "no hidden timer")
        }
        var state=DockVisibilityState(), input=DockPresence();input.pointer = .outside;input.recordedLocks = .drag
        _=try state.step(input, at: 0, intent: .reveal);let before=state.generation
        let cancelled=try state.step(input, at: 1, intent: .lifecycleCancel)
        try expect(cancelled.generation != before && cancelled.state == .sliver && cancelled.nextDeadline == nil, "lifecycle retires timer generation")
        try rejects(.staleGeneration) { _=try state.step(input,at:2,intent:.reveal,expectedGeneration:before) }
        try expect(state.surface == .sliver,"old timer cannot restore a cancelled surface")
        try rejects(.invalidTime) { _=try state.step(input, at: .nan) }
        try rejects(.invalidTime) { _=try state.step(input, at: 0.5) }
        var policy=DockVisibilityPolicy();policy.leaveGrace = -1
        var invalid=DockVisibilityState(policy:policy);try rejects(.invalidTime) { _=try invalid.step(input, at: 0) }
        input.autoHide=false;try expect(try state.step(input, at: 2).state == .expanded, "auto-hide disabled stays expanded")
    }
    try test("regions: four edges, S/M/L wake containment and full card corridor") {
        let display=CGRect(x:-900,y:-500,width:900,height:700)
        for edge in DockEdge.allCases { for side in [CGFloat(44),52,64] {
            let wake:CGRect, card:CGRect
            switch edge {
            case .left:wake=CGRect(x:display.minX,y:-300,width:16,height:300);card=CGRect(x:-750,y:-280,width:200,height:180)
            case .right:wake=CGRect(x:display.maxX-16,y:-300,width:16,height:300);card=CGRect(x:-350,y:-280,width:200,height:180)
            case .top:wake=CGRect(x:-700,y:display.maxY-16,width:300,height:16);card=CGRect(x:-670,y:-150,width:200,height:180)
            case .bottom:wake=CGRect(x:-700,y:display.minY,width:300,height:16);card=CGRect(x:-670,y:-350,width:200,height:180)
            }
            let area=DockPresenceArea(painted:[CGRect(x:-700,y:-250,width:side,height:side)],wake:wake,card:card,display:display,edge:edge)
            for i in 0...10 {for j in 0...10 {
                let point=CGPoint(x:wake.minX+wake.width*CGFloat(i)/10,y:wake.minY+wake.height*CGFloat(j)/10)
                try expect(area.region(at:point) == .wake,"entire wake target, including endpoints, stays inside")
            }}
            let p:CGPoint
            switch edge {case .left:p=CGPoint(x:-800,y:card.midY);case .right:p=CGPoint(x:-100,y:card.midY);case .top:p=CGPoint(x:card.midX,y:150);case .bottom:p=CGPoint(x:card.midX,y:-450)}
            try expect(area.region(at:p) == .inside, "card corridor includes full depth")
            var shared=area;shared.outerEdge=false;shared.painted=[];shared.card=nil
            try expect(shared.region(at:CGPoint(x:wake.midX,y:wake.midY)) == .outside,"shared edge cannot wake")
        }}
    }
    try test("notice priority, distinct shapes, no low-quota-only event") {
        var s=fresh("a",.critical)
        try expect(DockNoticeProjection.selected(for:s,at:now)==nil,"low quota alone is not an event")
        s.drawingCredits=true;s.creditsKnown=true;s.exhaustedQuotaObserved=true
        s.cards=[DockResetCardSignal(id:"card",expiresAt:now.addingTimeInterval(3600))];s.reset=reset()
        s.forecast=DockForecastSignal(windowID:"5h",validUntil:now.addingTimeInterval(600))
        try expect(DockNoticeProjection.candidates(for:s,at:now).map(\.key.kind)==[.forecast,.resetAnnounced,.cardsExpiring,.credits],"priority order")
        s.forecast=nil;try expect(DockNoticeProjection.selected(for:s,at:now)?.shape == .hollow,"announced hollow blue")
        s.reset=reset(confirmed:true);let confirmed=DockNoticeProjection.selected(for:s,at:now)
        try expect(confirmed?.tone == .blue && confirmed?.shape == .solid,"confirmed solid blue, never credits white")
        s.reset?.restartedReading=true;try expect(DockNoticeProjection.selected(for:s,at:now)?.key.kind == .cardsExpiring,"reading clears confirmed reset only")
        s.cards=[];try expect(DockNoticeProjection.selected(for:s,at:now)?.tone == .white,"credits are white")
        s.creditsKnown=false;try expect(DockNoticeProjection.selected(for:s,at:now)==nil,"unknown credits not fabricated")
    }
    try test("notice UTC expiry boundaries and unknown/future readings") {
        var s=fresh("a");s.reset=reset()
        try expect(DockNoticeProjection.selected(for:s,at:now.addingTimeInterval(48*3600-100))==nil,"announcement expires at deadline")
        s.reset=DockResetSignal(id:"scheduled",status:.announced,scheduledThrough:now.addingTimeInterval(10))
        try expect(DockNoticeProjection.selected(for:s,at:now) != nil && DockNoticeProjection.selected(for:s,at:now.addingTimeInterval(10)) == nil,"scheduled end, not nominal 48h")
        s.reset=reset(confirmed:true);try expect(DockNoticeProjection.selected(for:s,at:now.addingTimeInterval(24*3600))==nil,"confirmed 24h")
        s.reset?.confirmedAt=now.addingTimeInterval(1);try expect(DockNoticeProjection.selected(for:s,at:now)==nil,"future confirmation withheld")
        s.reset=nil;s.cards=[DockResetCardSignal(id:"expired",expiresAt:now),DockResetCardSignal(id:"boundary",expiresAt:now.addingTimeInterval(48*3600)),DockResetCardSignal(id:"late",expiresAt:now.addingTimeInterval(48*3600+1))]
        try expect(DockNoticeProjection.selected(for:s,at:now)?.key.sourceIDs == ["boundary"],"card 48h inclusive, zero excluded")
        s.forecast=DockForecastSignal(windowID:"5h",validUntil:now.addingTimeInterval(100));s.dataState = .stale
        try expect(DockNoticeProjection.selected(for:s,at:now)==nil,"stale personal notices withheld")
        s.reset=reset();try expect(DockNoticeProjection.selected(for:s,at:now)?.key.kind == .resetAnnounced,"dated public reset does not fabricate personal quota")
    }
    try test("sliver segment acknowledgement, improvement/worsening and no unknown downgrade") {
        var state=DockAttentionState(), signals=[fresh("a",.warning),fresh("b",.critical),fresh("c"),fresh("d")]
        let stations=Dictionary(uniqueKeysWithValues:signals.map{($0.id,"station-"+$0.id)})
        try expect(try state.project(signals,stationBySubscription:stations,at:now).segments.map(\.subscriptionID)==["a","b"],"only affected segments")
        try state.acknowledgeDockOpen(signals,at:now);try expect(try state.project(signals,stationBySubscription:stations,at:now).segments.isEmpty,"open acknowledges current ranks")
        signals[0].alert = .critical;try expect(try state.project(signals,stationBySubscription:stations,at:now).segments.map(\.subscriptionID)==["a"],"later worsening returns")
        signals[1].dataState = .stale;_=try state.project(signals,stationBySubscription:stations,at:now)
        signals[1].dataState = .fresh;try expect(!(try state.project(signals,stationBySubscription:stations,at:now).segments.contains{$0.subscriptionID=="b"}),"unknown is not improvement")
        signals[1].alert = .none;_=try state.project(signals,stationBySubscription:stations,at:now)
        signals[1].alert = .warning;try expect(try state.project(signals,stationBySubscription:stations,at:now).segments.contains{$0.subscriptionID=="b"},"real improvement then worsening recurs")
        try expect(try state.project(signals,stationBySubscription:stations,sliverAlerts:false,at:now).segments.isEmpty,"setting disables segments")
    }
    try test("overflow identity, selected-event acknowledgement and menu tie order") {
        var signals=(0..<7).map{fresh("s\($0)")};signals[5].alert = .warning;signals[6].alert = .critical
        signals[5].reset=reset();signals[6].reset=reset()
        let stations=Dictionary(uniqueKeysWithValues:signals.enumerated().map{($0.element.id,$0.offset<5 ? "station-\($0.offset)":"overflow")})
        var state=DockAttentionState();let p=try state.project(signals,stationBySubscription:stations,at:now)
        try expect(p.segments.map(\.stationID)==["overflow","overflow"] && Set(p.segments.map(\.subscriptionID)).count==2,"overflow does not erase account identities")
        try expect(p.dots.count==2 && p.menuNotice?.key.subscriptionID == "s5","one menu dot with stable order tie")
        try state.acknowledgeCockpitOpen(signals,at:now)
        let afterCockpit=try state.project(signals,stationBySubscription:stations,at:now)
        try expect(afterCockpit.menuNotice==nil && afterCockpit.dots.count==2,"cockpit clears menu, not collapsed sliver")
        try state.acknowledgeDockOpen(signals,at:now);try expect(try state.project(signals,stationBySubscription:stations,at:now).dots.isEmpty,"dock open acknowledges sliver")
        try expect(DockNoticeProjection.selected(for:signals[5],at:now) != nil,"ack does not clear open-dock notice")
        try expect(DockNoticeProjection.selected(for:signals[5],at:now)?.key != DockNoticeProjection.selected(for:signals[6],at:now)?.key,"same public event stays subscription scoped")
    }
    try test("first-appearance state is explicit, per surface and pruned") {
        var state=DockAttentionState(), s=fresh("a");s.reset=reset()
        let p=try state.project([s],stationBySubscription:["a":"one"],at:now), key=p.dots[0].notice.key
        _=try state.project([s],stationBySubscription:["a":"one"],at:now)
        try expect(state.firstAppearance(of:key,on:.sliver),"projection alone never consumes appearance")
        let retainedBefore=state.retainedKeyCount
        try rejects(.invalidTime) { _=try state.project([s],stationBySubscription:["a":"one"],at:Date(timeIntervalSinceReferenceDate:.nan)) }
        try expect(state.retainedKeyCount==retainedBefore,"invalid wall time cannot erase semantic acknowledgement state")
        try expect(!state.firstAppearance(of:key,on:.sliver) && state.firstAppearance(of:key,on:.menu),"once per surface")
        _=try state.project([],stationBySubscription:[:],at:now);try expect(state.retainedKeyCount==0 && !state.firstAppearance(of:key,on:.sliver),"removed IDs cannot leak pulse/ack memory")
        try rejects(.invalidCatalogue) { _=try state.project([s,s],stationBySubscription:[:],at:now) }
        s.cards=[DockResetCardSignal(id:"b",expiresAt:now.addingTimeInterval(5)),DockResetCardSignal(id:"a",expiresAt:now.addingTimeInterval(6))];s.reset=nil
        let one=DockNoticeProjection.selected(for:s,at:now);s.cards.reverse()
        try expect(one==DockNoticeProjection.selected(for:s,at:now),"card order does not invent a new event")
    }
    try test("acknowledged personal notices do not replay after transient stale reads") {
        var state=DockAttentionState(), s=fresh("a")
        s.forecast=DockForecastSignal(windowID:"weekly",validUntil:now.addingTimeInterval(600))
        let key=try state.project([s],stationBySubscription:["a":"one"],at:now).dots[0].notice.key
        try expect(state.firstAppearance(of:key,on:.sliver),"initial semantic appearance")
        try state.acknowledgeDockOpen([s],at:now)
        s.dataState = .stale
        try expect(try state.project([s],stationBySubscription:["a":"one"],at:now).dots.isEmpty,"stale evidence is not displayed")
        try expect(!state.firstAppearance(of:key,on:.sliver),"stale key cannot be consumed as a visible appearance")
        s.dataState = .fresh
        try expect(try state.project([s],stationBySubscription:["a":"one"],at:now).dots.isEmpty,"same resumed observation remains acknowledged")
        try expect(!state.firstAppearance(of:key,on:.sliver),"no repeated flash after freshness recovery")
        _=try state.project([s],stationBySubscription:["a":"one"],at:now.addingTimeInterval(601))
        try expect(state.retainedKeyCount==0,"expired evidence retires retained acknowledgements")
    }
    try test("acknowledgement is per selected event; lower-priority event is not pre-acknowledged") {
        var state=DockAttentionState(), s=fresh("a")
        s.reset=reset();s.forecast=DockForecastSignal(windowID:"5h",validUntil:now.addingTimeInterval(60))
        try state.acknowledgeDockOpen([s],at:now)
        s.forecast=nil
        let projection=try state.project([s],stationBySubscription:["a":"one"],at:now)
        try expect(projection.dots.first?.notice.key.kind == .resetAnnounced,"unseen reset remains discoverable")
        for i in 0..<1000 {
            s.reset=reset("event-\(i)")
            let p=try state.project([s],stationBySubscription:["a":"one"],at:now)
            if let key=p.dots.first?.notice.key {_=state.firstAppearance(of:key,on:.sliver)}
            try state.acknowledgeDockOpen([s],at:now)
            try expect(state.retainedKeyCount <= 3,"inactive event keys are pruned, not unbounded history")
        }
    }
    try test("configured deadlines use the policy, including delayed callbacks") {
        var policy=DockVisibilityPolicy();policy.revealDwell=0.300;policy.leaveGrace=0.700;policy.staleLockRecovery=3;policy.arrivalGuard=0.400
        var state=DockVisibilityState(policy:policy), input=DockPresence();input.pointer = .wake
        try expect(try state.step(input,at:0).nextDeadline == policy.revealDwell,"configured dwell deadline")
        try expect(try state.step(input,at:policy.revealDwell-0.001).state == .sliver,"no hardcoded short reveal")
        _=try state.step(input,at:policy.revealDwell)
        try expect(!state.acceptsPress(at:policy.revealDwell+policy.arrivalGuard-0.001),"configured arrival guard")
        input.pointer = .outside
        try expect(try state.step(input,at:1).nextDeadline == 1+policy.leaveGrace,"configured grace")
        try expect(try state.step(input,at:100).didCollapse,"delayed callback evaluates absolute elapsed deadline")
    }
    try test("B06 rings stay fixed while selected period and time points change") {
        let five=DockQuotaWindowInput(id:"5h",period:.fiveHour,label:"5h",remainingPercent:80,resetsAt:now.addingTimeInterval(7200),durationSeconds:18000)
        let week=DockQuotaWindowInput(id:"week",period:.week,label:"Weekly",remainingPercent:20,resetsAt:now.addingTimeInterval(302400),durationSeconds:604800)
        var input=DockInstrumentInput(id:"sub",name:"Synthetic",windows:[week,five]);input.dataState = .fresh
        var result=try DockInstrumentProjection.evaluate(input,now:now)
        try expect(result.outer?.windowID=="5h" && result.inner?.windowID=="week","fixed period order, not remaining order")
        try expect(result.readout=="20%" && result.selectedWindowID=="week" && result.litTimePoints(positions:37)==19,"selected tightest quota, clock actual time")
        input.selectedWindowID="5h";input.showUsedPercent=true;result=try DockInstrumentProjection.evaluate(input,now:now)
        try expect(result.readout=="20%" && result.status == .normal && result.litTimePoints(positions:37)==15,"used display does not invert status or clock")
        try expect(result.outer?.windowID=="5h" && result.inner?.windowID=="week","pin never swaps quota rings")
    }
    try test("B06 boundary status and unknown/stale/passed resets are not invented fuel") {
        for (r,expected) in [(0.0,DockQuotaStatus.critical),(15.0,.critical),(16.0,.warning),(40.0,.warning),(41.0,.normal)] {
            let w=DockQuotaWindowInput(id:"five",period:.fiveHour,label:"5h",remainingPercent:r,resetsAt:nil,durationSeconds:nil)
            var i=DockInstrumentInput(id:"sub",name:"Synthetic",windows:[w]);i.dataState = .fresh
            let p=try DockInstrumentProjection.evaluate(i,now:now)
            try expect(p.status==expected && p.timeLeftFraction==nil,"quota threshold with unknown reset time")
        }
        var w=DockQuotaWindowInput(id:"month",period:.month,label:"Monthly",remainingPercent:30,resetsAt:now.addingTimeInterval(5000),durationSeconds:nil)
        var i=DockInstrumentInput(id:"sub",name:"Synthetic",windows:[w]);i.dataState = .fresh
        try expect(try DockInstrumentProjection.evaluate(i,now:now).litTimePoints(positions:37)==nil,"no invented thirty-day month")
        w.durationSeconds=31*86400;i.windows=[w]
        try expect(try DockInstrumentProjection.evaluate(i,now:now).litTimePoints(positions:37)==1,"any positive actual time retains one point")
        i.dataState = .stale;let old=try DockInstrumentProjection.evaluate(i,now:now)
        try expect(old.dataState == .stale && old.readout=="--" && old.outer?.fraction==nil && old.litTimePoints(positions:37)==nil,"stale is neither zero nor full")
        i.dataState = .fresh;i.windows[0].resetsAt=now
        try expect(try DockInstrumentProjection.evaluate(i,now:now).readout=="--","passed reset retires quota")
    }
    try test("B06 working effect requires distinct matching fresh observed output") {
        for n in [0,1,2,6] {
            var active=Set<String>()
            for id in 0..<6 {
                let sid="sub-\(id)", w=DockQuotaWindowInput(id:"five",period:.fiveHour,label:"5h",remainingPercent:60,resetsAt:nil,durationSeconds:nil)
                var i=DockInstrumentInput(id:sid,name:"Synthetic",windows:[w]);i.dataState = .fresh
                i.working=DockWorkingSignal(subscriptionID:sid,bindingVerified:true,fresh:true,observedOutput:id<n)
                if try DockInstrumentProjection.evaluate(i,now:now).jetEligible {active.insert(sid)}
            }
            try expect(active.count==n,"working ID count is exact, no shared-source duplication")
        }
        let w=DockQuotaWindowInput(id:"five",period:.fiveHour,label:"5h",remainingPercent:0,resetsAt:nil,durationSeconds:nil)
        var i=DockInstrumentInput(id:"sub-a",name:"Same maker",windows:[w]);i.dataState = .fresh
        for binding in [String?.none,"sub-b"] {
            i.working=DockWorkingSignal(subscriptionID:binding,bindingVerified:true,fresh:true,observedOutput:true)
            try expect(!(try DockInstrumentProjection.evaluate(i,now:now).jetEligible),"ambiguous/mismatched session lights neither subscription")
        }
        i.working=DockWorkingSignal(subscriptionID:"sub-a",bindingVerified:true,fresh:true,observedOutput:true)
        try expect(try DockInstrumentProjection.evaluate(i,now:now).jetEligible,"zero remains known critical while observed output uses credits")
        i.windows[0].remainingPercent=nil
        try expect(!(try DockInstrumentProjection.evaluate(i,now:now).jetEligible),"unknown selected status does not invent a jet colour")
    }
    try test("task62 cockpit restore inserts the final state without an away reveal frame") {
        for edge in ["left","right","bottom"] {for autoHide in [true,false] {for pointer in [DockPointerRegion.outside,.inside,.wake,.unknown] {
            var state=DockVisibilityState(),input=DockPresence();input.autoHide=autoHide;input.cockpitClosed=false
            _=try state.step(input,at:0);let oldGeneration=state.generation
            input.cockpitClosed=true;input.pointer=pointer;input.recordedLocks=[.drag]
            let change=try state.step(input,at:1,intent:.restoreFromCockpit)
            let expanded = !autoHide || pointer == .inside || pointer == .wake
            try expect(change.state == (expanded ? .expanded:.sliver),"\(edge) restore final state")
            try expect(change.didReveal==expanded && !change.didCollapse,"no away reveal/collapse pair")
            try expect(change.nextDeadline==nil && change.clearRecordedLocks == [.drag],"no stale grace or drag timer")
            try rejects(.staleGeneration){_=try state.step(input,at:2,expectedGeneration:oldGeneration)}
            if expanded{try expect(!state.acceptsPress(at:1.01),"restored visible instrument preserves arrival guard")}
        }}}
        var retained=DockVisibilityState(),input=DockPresence();input.pointer = .outside
        _=try retained.step(input,at:0,intent:.reveal)
        let restored=try retained.step(input,at:1,intent:.restoreFromCockpit)
        try expect(restored.state == .sliver && !restored.didReveal && !restored.didCollapse,"restoration also avoids an animated collapse when the old hidden view retained expanded state")
    }
    if let i=CommandLine.arguments.firstIndex(of:"--receipt"), i+1<CommandLine.arguments.count {
        let value:[String:Any]=["schemaVersion":1,"testGroups":groups,"assertions":assertions,"result":"passed","uiLaunched":false,"fixtureClock":"2023-11-14T22:13:20Z"]
        try JSONSerialization.data(withJSONObject:value,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:CommandLine.arguments[i+1]),options:.atomic)
    }
    print("PASS \(groups) groups; \(assertions) assertions")
} catch { fputs("FAIL \(error)\n",stderr);exit(1) }
