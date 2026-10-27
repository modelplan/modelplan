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
    try test("sliver quota state persists independently of one-shot acknowledgements") {
        var state=DockAttentionState(), signals=[fresh("a",.warning),fresh("b",.critical),fresh("c"),fresh("d")]
        let stations=Dictionary(uniqueKeysWithValues:signals.map{($0.id,"station-"+$0.id)})
        try expect(try state.project(signals,stationBySubscription:stations,at:now).segments.map(\.subscriptionID)==["a","b"],"only current affected segments")
        try state.acknowledgeDockOpen(signals,at:now)
        try expect(try state.project(signals,stationBySubscription:stations,at:now).segments.map(\.severity)==[.warning,.critical],"revealing does not clear current quota state")
        signals[0].alert = .critical
        try expect(try state.project(signals,stationBySubscription:stations,at:now).segments.count==2,"worsening updates without hiding another subscription")
        signals[1].dataState = .stale
        try expect(try state.project(signals,stationBySubscription:stations,at:now).segments.map(\.subscriptionID)==["a"],"stale personal quota color is withheld")
        signals[1].dataState = .fresh
        try expect(try state.project(signals,stationBySubscription:stations,at:now).segments.count==2,"fresh unchanged quota is shown after recovery")
        signals[1].alert = .none
        try expect(try state.project(signals,stationBySubscription:stations,at:now).segments.map(\.subscriptionID)==["a"],"real improvement clears only its segment")
        signals[1].alert = .warning
        try state.acknowledgeDockOpen(signals,at:now)
        try expect(try state.project(signals,stationBySubscription:stations,at:now).segments.count==2,"repeated reveal cannot acknowledge away persistent quota state")
        try expect(try state.project(signals,stationBySubscription:stations,sliverAlerts:false,at:now).segments.isEmpty,"saved explicit off disables segments")
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
        for (r,expected) in [(0.0,DockQuotaStatus.critical),(15.0,.critical),(16.0,.critical),(25.0,.critical),(25.01,.warning),(40.0,.warning),(41.0,.normal)] {
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
    try test("configured critical thresholds include equality for saved and new choices") {
        for threshold in [10.0, 16, 20, 25] {
            for remaining in [threshold - 0.01, threshold, threshold + 0.01] {
                let window = DockQuotaWindowInput(id:"quota",period:.fiveHour,label:"Quota",remainingPercent:remaining,resetsAt:nil,durationSeconds:nil)
                var input = DockInstrumentInput(id:"sub",name:"Synthetic",windows:[window]);input.dataState = .fresh
                for used in [false,true] {
                    input.showUsedPercent = used
                    let reading = try DockInstrumentProjection.evaluate(input,now:now,redBelow:threshold)
                    let expected:DockQuotaStatus = remaining <= threshold ? .critical:.warning
                    try expect(reading.status == expected && reading.outer?.status == expected,"readout mode never changes inclusive remaining threshold")
                }
            }
        }
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
    func layouts(_ displays:[DockDisplayArea],scale:CGFloat=1)->[DockEdgeLayout]{
        displays.flatMap{d in DockEdgeGeometry.allowedEdges.map{edge in
            let size=edge == .bottom ? CGSize(width:240*scale,height:80*scale):CGSize(width:80*scale,height:240*scale)
            return DockEdgeLayout(displayID:d.id,edge:edge,expandedSize:size,sliverLength:240*scale,sliverThickness:3*scale,hoverRects:[CGRect(origin:.zero,size:size)])
        }}
    }
    try test("B07 placement: visible-frame containment, registered scaling and fixed wake"){
        let frame=CGRect(x:-1000,y:600,width:1000,height:800),d=DockDisplayArea(id:"display",frame:frame,visibleFrame:frame)
        for scale in [CGFloat(0.8),1,1.3]{for edge in DockEdgeGeometry.allowedEdges{
            let p=try DockEdgeGeometry.resolve(preference:.init(displayID:d.id,edge:edge),displays:[d],layouts:layouts([d],scale:scale),pointer:nil,primaryID:d.id)!
            try expect(d.usableFrame.contains(p.frame) && d.usableFrame.contains(p.sliverFrame) && d.usableFrame.contains(p.wakeFrame),"all painted/wake frames stay usable")
            let thickness=edge == .bottom ? p.sliverFrame.height:p.sliverFrame.width
            let wake=edge == .bottom ? p.wakeFrame.height:p.wakeFrame.width
            try expect(abs(thickness-3*scale)<0.0001 && wake==20,"registered sliver scales, physical wake does not")
            let along=edge == .bottom ? p.frame.minX-d.usableFrame.minX:p.frame.minY-d.usableFrame.minY
            try expect(along>=24,"physical hot-corner clearance")
            try expect(p.edge != .top,"top never emitted")
        }}
    }
    try test("B07 seams: partial, negative, above and fully surrounded fallback"){
        let a=DockDisplayArea(id:"a",frame:CGRect(x:0,y:0,width:1000,height:800),visibleFrame:CGRect(x:0,y:0,width:1000,height:800))
        let b=DockDisplayArea(id:"b",frame:CGRect(x:1000,y:400,width:800,height:400),visibleFrame:CGRect(x:1000,y:400,width:800,height:400))
        let p=try DockEdgeGeometry.resolve(preference:.init(displayID:"a",edge:.right,alongFraction:0.9),displays:[a,b],layouts:layouts([a,b]),pointer:nil,primaryID:"a")!
        try expect(p.edge == .right && p.frame.maxY<=400,"partial edge fits wholly below shared interval")
        try expect(!DockEdgeGeometry.canWake(at:CGPoint(x:999,y:400),placement:p,displays:[a,b]),"exact seam endpoint cannot wake")
        try expect(DockEdgeGeometry.canWake(at:CGPoint(x:999,y:399),placement:p,displays:[a,b]),"exposed wake remains available")
        let left=DockDisplayArea(id:"left",frame:CGRect(x:-1000,y:0,width:1000,height:800),visibleFrame:CGRect(x:-1000,y:0,width:1000,height:800))
        let q=try DockEdgeGeometry.resolve(preference:.init(displayID:"left",edge:.right),displays:[a,left],layouts:layouts([a,left]),pointer:nil,primaryID:"a")!
        try expect(q.edge != .right,"negative-origin adjoining seam is not a placement")
        let above=DockDisplayArea(id:"above",frame:CGRect(x:0,y:800,width:1000,height:800),visibleFrame:CGRect(x:0,y:800,width:1000,height:800))
        let r=try DockEdgeGeometry.resolve(preference:.init(displayID:"above",edge:.bottom),displays:[a,above],layouts:layouts([a,above]),pointer:nil,primaryID:"a")!
        try expect(r.edge != .bottom,"above-screen bottom seam cannot reveal")
        let right=DockDisplayArea(id:"right",frame:CGRect(x:1000,y:0,width:1000,height:800),visibleFrame:CGRect(x:1000,y:0,width:1000,height:800))
        let below=DockDisplayArea(id:"below",frame:CGRect(x:0,y:-800,width:1000,height:800),visibleFrame:CGRect(x:0,y:-800,width:1000,height:800))
        let all=[a,left,right,below]
        let fallback=try DockEdgeGeometry.resolve(preference:.init(displayID:"a",edge:.right),displays:all,layouts:layouts(all),pointer:CGPoint(x:500,y:400),primaryID:"a")!
        try expect(fallback.displayID != "a","fully surrounded display falls back without removing it from topology")
        try expect(DockEdgeGeometry.canWake(at:CGPoint(x:fallback.wakeFrame.midX,y:fallback.wakeFrame.midY),placement:fallback,displays:all),"fallback remains exposed in full topology")
    }
    try test("B07 non-drag fallback preserves position while pointer moves"){
        let a=DockDisplayArea(id:"a",frame:CGRect(x:0,y:0,width:1000,height:800),visibleFrame:CGRect(x:0,y:0,width:1000,height:800))
        let b=DockDisplayArea(id:"b",frame:CGRect(x:1000,y:0,width:1000,height:800),visibleFrame:CGRect(x:1000,y:0,width:1000,height:800))
        // The preview registers its selected edge only. A's right edge is an internal seam.
        let selected=layouts([a,b]).filter{$0.edge == .right}
        for pinned in [Optional("a"),nil]{
            let preference=DockEdgePreference(displayID:pinned,edge:.right,alongFraction:0.4)
            let lower=try DockEdgeGeometry.resolve(preference:preference,displays:[a,b],layouts:selected,pointer:CGPoint(x:500,y:180),primaryID:"a")!
            let upper=try DockEdgeGeometry.resolve(preference:preference,displays:[a,b],layouts:selected,pointer:CGPoint(x:500,y:620),primaryID:"a")!
            try expect(lower.displayID == "b" && upper.displayID == "b","fallback uses an exposed registered display")
            try expect(lower.frame == upper.frame && lower.sliverFrame == upper.sliverFrame,"ordinary pointer motion must not vertically move expanded dock or sliver")
            try expect(abs(lower.alongFraction-0.4)<0.0001,"fallback preserves stored along-edge intent")
            let drop=try DockEdgeGeometry.resolve(preference:preference,displays:[a,b],layouts:selected,pointer:CGPoint(x:1999,y:620),primaryID:"a",nearest:true)!
            try expect(drop.frame != lower.frame,"an explicit nearest drag/drop may change along-edge position")
        }
    }
    try test("B07 migration/drop: missing display, top normalization and no floating"){
        let f=CGRect(x:0,y:0,width:1000,height:800),d=DockDisplayArea(id:"primary",frame:f,visibleFrame:f)
        let top=try DockEdgeGeometry.resolve(preference:.init(displayID:d.id,edge:.top),displays:[d],layouts:layouts([d]),pointer:nil,primaryID:d.id)!
        try expect(top.edge == .right && top.frame.maxY==776,"top normalizes to nearest allowed registered position")
        let bottom=try DockEdgeGeometry.resolve(preference:.init(displayID:"removed"),displays:[d],layouts:layouts([d]),pointer:CGPoint(x:450,y:5),primaryID:d.id,nearest:true)!
        try expect(bottom.edge == .bottom && bottom.frame.minY==0,"nearest drop snaps, never floats")
        let reserved=DockDisplayArea(id:"primary",frame:f,visibleFrame:CGRect(x:0,y:50,width:1000,height:724))
        let avoid=try DockEdgeGeometry.resolve(preference:.init(displayID:d.id,edge:.bottom),displays:[reserved],layouts:layouts([reserved]),pointer:CGPoint(x:450,y:55),primaryID:d.id)!
        try expect(avoid.edge != .bottom && avoid.frame.maxY<=reserved.visibleFrame.maxY,"visible system-Dock edge avoided when an alternative exists")
        try expect(try DockEdgeGeometry.resolve(preference:.init(),displays:[],layouts:[],pointer:nil,primaryID:nil)==nil,"empty screens do not invent a frame")
    }
    try test("B07 registration: asymmetric full bounds keep the supplied sliver anchor"){
        let f=CGRect(x:0,y:0,width:1000,height:800),d=DockDisplayArea(id:"d",frame:f,visibleFrame:f)
        let layout=DockEdgeLayout(displayID:"d",edge:.right,expandedSize:CGSize(width:80,height:240),sliverLength:200,sliverThickness:3,hoverRects:[],alongAnchor:80)
        let p=try DockEdgeGeometry.resolve(preference:.init(displayID:"d",edge:.right),displays:[d],layouts:[layout],pointer:nil,primaryID:"d")!
        try expect(p.sliverFrame.midY==400 && p.frame.minY==320,"registered anchor, not expanded bounding-box centre")
        try expect(p.globalHoverRects.isEmpty,"no invented painted regions")
    }
    try test("B07 lifecycle: suspension and fresh geometry never reuse actionable arrival state"){
        var v=DockVisibilityState(),presence=DockPresence();presence.autoHide=false
        _=try v.step(presence,at:0,intent:.lifecycleCancel)
        try expect(!v.acceptsPress(at:0.1) && v.acceptsPress(at:0.3),"non-auto-hide reflow keeps arrival guard")
        presence.lifecycleActive=false;let paused=try v.step(presence,at:0.4)
        try expect(paused.state == .suppressed(.lifecycle) && paused.nextDeadline==nil,"lifecycle is an explicit suppression")
    }
    try test("B08 card:250ms entry, shared corridor ownership and true pins"){
        var card=DockCardInteraction()
        try card.step(catalogue:["a","b"],hoveredID:"a",insideShared:true,parentOwnsHide:true,parentExpanded:true,menuActuallyOpen:false,at:0)
        try expect(card.visibility == .hidden && card.nextDeadline==0.25,"card entry is250ms")
        try card.step(catalogue:["a","b"],hoveredID:"a",insideShared:true,parentOwnsHide:true,parentExpanded:true,menuActuallyOpen:false,at:0.249)
        try expect(card.visibility == .hidden,"no early card")
        try card.step(catalogue:["a","b"],hoveredID:"a",insideShared:true,parentOwnsHide:true,parentExpanded:true,menuActuallyOpen:false,at:0.25)
        try expect(card.visibility == .hover("a"),"entry deadline shows scoped card")
        try card.step(catalogue:["a","b"],hoveredID:nil,insideShared:false,parentOwnsHide:true,parentExpanded:true,menuActuallyOpen:false,at:1)
        try expect(card.visibility == .hover("a") && card.nextDeadline==nil,"auto-hide Dock owns500ms corridor decision, no competing card leave timer")
        try card.click("a",at:1);try card.step(catalogue:["a","b"],hoveredID:nil,insideShared:false,parentOwnsHide:true,parentExpanded:false,menuActuallyOpen:false,at:20)
        try expect(card.visibility == .pinned("a"),"cockpit suppression does not unpin")
        try card.step(catalogue:["b"],hoveredID:nil,insideShared:false,parentOwnsHide:true,parentExpanded:false,menuActuallyOpen:false,at:21)
        try expect(card.visibility == .hidden,"removed subscription cannot retain a card")
    }
    try test("B08 independent card:leave/menu protection/click toggle without a repeat loop"){
        var card=DockCardInteraction()
        try card.step(catalogue:["a"],hoveredID:"a",insideShared:true,parentOwnsHide:false,parentExpanded:true,menuActuallyOpen:false,at:0)
        try card.step(catalogue:["a"],hoveredID:"a",insideShared:true,parentOwnsHide:false,parentExpanded:true,menuActuallyOpen:false,at:0.25)
        try card.step(catalogue:["a"],hoveredID:nil,insideShared:false,parentOwnsHide:false,parentExpanded:true,menuActuallyOpen:true,at:5)
        try expect(card.visibility == .hover("a") && card.nextDeadline==nil,"actual menu stays protected beyond2s")
        try card.step(catalogue:["a"],hoveredID:nil,insideShared:false,parentOwnsHide:false,parentExpanded:true,menuActuallyOpen:false,at:6)
        try expect(card.nextDeadline==6.25,"standalone retains existing250ms leave grace")
        try card.step(catalogue:["a"],hoveredID:nil,insideShared:false,parentOwnsHide:false,parentExpanded:true,menuActuallyOpen:false,at:6.25)
        try expect(card.visibility == .hidden,"standalone leave hides")
        try card.click("a",at:7);try card.click("a",at:8)
        try expect(card.visibility == .hidden,"same pinned click toggles closed")
        try rejects(.invalidTime){try card.click("a",at:7)}
    }
    try test("B08 nozzle:along threshold,canonical preview,RM and single host order request"){
        let prefs=DockSubscriptionPreferences(order:["missing","a","b","c","d"]),catalogue=["a","b","c","d"]
        let targets=[DockReorderTarget(id:"a",along:0),.init(id:"b",along:20),.init(id:"c",along:40)]
        var gesture=DockNozzleInteraction();try gesture.begin(id:"a",along:0,overflow:false,targets:targets,catalogue:catalogue,preferences:prefs)
        try gesture.move(along:5,reducedMotion:false);try expect(gesture.preview==nil,"strictly more than5 along points")
        try gesture.move(along:38,reducedMotion:false)
        try expect(gesture.preview?.order == ["b","c","a","d"] && gesture.preview?.neighbourYieldSeconds==0.15,"canonical original-target preview")
        try expect(prefs.order == ["missing","a","b","c","d"],"preview writes no preferences")
        if case .order(let request)=try gesture.release(insideMain:true,overSameSource:false,catalogue:catalogue,preferences:prefs){
            try expect(request.expected==prefs && request.proposed.order==["missing","b","c","a","d"],"intent preserves reconnect slot and baseline")
        }else{throw CheckFailure(description:"missing order request")}
        if case .none=try gesture.release(insideMain:true,overSameSource:true,catalogue:catalogue,preferences:prefs){}else{throw CheckFailure(description:"double release")}
        try gesture.begin(id:"a",along:0,overflow:false,targets:targets,catalogue:catalogue,preferences:prefs)
        try gesture.move(along:38,reducedMotion:true);try expect(gesture.preview?.neighbourYieldSeconds==0,"RM instant yield")
        if case .none=try gesture.release(insideMain:false,overSameSource:false,catalogue:catalogue,preferences:prefs){}else{throw CheckFailure(description:"outside drop committed")}
    }
    try test("B08 overflow/stale/rejected geometry never reorders or accidentally clicks"){
        let prefs=DockSubscriptionPreferences(),ids=["a","b","c"],targets=[DockReorderTarget(id:"a",along:0),.init(id:"b",along:20)]
        var gesture=DockNozzleInteraction();try gesture.begin(id:"c",along:0,overflow:true,targets:targets,catalogue:ids,preferences:prefs)
        try gesture.move(along:30,reducedMotion:false);try expect(gesture.overflowHelpNeeded && gesture.preview==nil,"overflow drag is help only")
        if case .none=try gesture.release(insideMain:false,overSameSource:true,catalogue:ids,preferences:prefs){}else{throw CheckFailure(description:"overflow drag clicked")}
        try gesture.begin(id:"c",along:0,overflow:true,targets:targets,catalogue:ids,preferences:prefs)
        if case .click("c")=try gesture.release(insideMain:false,overSameSource:true,catalogue:ids,preferences:prefs){}else{throw CheckFailure(description:"overflow tap lost")}
        try gesture.begin(id:"a",along:0,overflow:false,targets:targets,catalogue:ids,preferences:prefs)
        try gesture.move(along:25,reducedMotion:false,canPreview:{_ in false});try expect(gesture.preview==nil,"alias/pitch overflow rejects preview")
        gesture.cancel();try gesture.begin(id:"a",along:0,overflow:false,targets:targets,catalogue:ids,preferences:prefs)
        try gesture.move(along:25,reducedMotion:false)
        try rejects(.staleReorder){_=try gesture.release(insideMain:true,overSameSource:false,catalogue:["a","b"],preferences:prefs)}
        try expect(gesture.source==nil,"stale release is retired")
        let key=try DockNozzleInteraction.keyboardMove(id:"a",delta:1,catalogue:ids,preferences:prefs)!
        try expect(key.position==1 && key.proposed.orderedIDs(in:ids)==["b","a","c"],"Option-arrow moves one canonical place")
    }
    try test("B08 menu:optional Help and action-bound separators; acknowledge scopes stay distinct"){
        let old=DockMenuModel.entries(hasHelp:false),full=DockMenuModel.entries(hasHelp:true)
        try expect(old.count==7 && full.count==8,"callback omission preserves original menu")
        try expect(full.map(\.command)==[.website,.methodology,.privacy,.checkForUpdates,.help,.settings,.about,.quit],"Help immediately above Settings")
        try expect(full.filter(\.separatorBefore).map(\.command)==[.checkForUpdates,.quit] && old.filter(\.separatorBefore).count==2,"groups are not positional indices")
        var attention=DockAttentionState(),signal=fresh("a",.critical);signal.reset=reset()
        try attention.acknowledge(.cockpitOpening,signals:[signal],at:now)
        let afterCockpit=try attention.project([signal],stationBySubscription:["a":"a"],at:now)
        try expect(afterCockpit.menuNotice==nil && afterCockpit.dots.count==1 && afterCockpit.segments.count==1,"cockpit opens acknowledge menu only")
        try attention.acknowledge(.dockRevealed,signals:[signal],at:now)
        let afterDock=try attention.project([signal],stationBySubscription:["a":"a"],at:now)
        try expect(afterDock.dots.isEmpty && afterDock.segments.isEmpty,"genuine Dock reveal acknowledges sliver")
    }
    try test("B08 card data uses canonical quota truth and retains unknown versus zero"){
        var input=DockInstrumentInput(id:"a",name:"Synthetic",windows:[.init(id:"five",period:.fiveHour,label:"Short",remainingPercent:0,resetsAt:now.addingTimeInterval(100),durationSeconds:18000),.init(id:"week",period:.week,label:"Long",remainingPercent:nil,resetsAt:nil,durationSeconds:nil)])
        input.dataState = .fresh;input.showUsedPercent=true
        let card=try DockCardProjection.content(input:input,at:now)
        try expect(card.rows[0].value=="100%" && card.rows[0].remainingFraction==0 && card.rows[0].tone == .critical,"used display never reverses fuel/status truth")
        try expect(card.rows[1].value=="--" && card.rows[1].remainingFraction==nil,"missing is not zero")
        input.dataState = .stale
        let stale=try DockCardProjection.content(input:input,at:now)
        try expect(stale.rows.allSatisfy{$0.value=="--" && $0.remainingFraction==nil},"stale data does not regain actionable quota")
    }
    print("PASS \(groups) groups; \(assertions) assertions")
} catch { fputs("FAIL \(error)\n",stderr);exit(1) }
