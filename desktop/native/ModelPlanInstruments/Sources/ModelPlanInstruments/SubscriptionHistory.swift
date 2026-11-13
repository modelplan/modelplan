// SPDX-License-Identifier: MIT
import Foundation

public enum SubscriptionTab: Sendable {case now,history}
public struct SubscriptionResetEvent: Sendable {
    public let id:String
    public let at:Date?
    public let provenance:ResetProvenance
    public let pending:Bool,waiting:Bool
    public let evidence:InstrumentEvidence
    public init(id:String,at:Date?,provenance:ResetProvenance,pending:Bool = false,waiting:Bool = false,evidence:InstrumentEvidence = .init()) {
        self.id=id;self.at=at;self.provenance=provenance;self.pending=pending;self.waiting=waiting;self.evidence=evidence
    }
}
public struct SubscriptionHistoryWindowInput: Sendable {
    public let id:String
    public let period:QuotaPeriod
    /// nil is unavailable; [] is a supplied empty history. Caller order is newest first.
    public let cycles:[InstrumentCycle]?
    public let resets:[SubscriptionResetEvent]?
    public init(id:String,period:QuotaPeriod,cycles:[InstrumentCycle]?,resets:[SubscriptionResetEvent]? = nil) {
        self.id=id;self.period=period;self.cycles=cycles;self.resets=resets
    }
}
public struct SubscriptionHistoryInput: Sendable {
    public let id:String
    public let header:SubscriptionHeader?
    public let sourceLabel:String?
    public let evidence:InstrumentEvidence
    public let attribution:UsageAttribution
    public let windows:[SubscriptionHistoryWindowInput]
    public let peak:PeakBand?
    public let modelNames:[String:String]
    public init(id:String,header:SubscriptionHeader?,sourceLabel:String?,evidence:InstrumentEvidence = .init(),attribution:UsageAttribution,
                windows:[SubscriptionHistoryWindowInput],peak:PeakBand? = nil,modelNames:[String:String] = [:]) {
        self.id=id;self.header=header;self.sourceLabel=sourceLabel;self.evidence=evidence;self.attribution=attribution
        self.windows=windows;self.peak=peak;self.modelNames=modelNames
    }
}
public struct SubscriptionHistorySegment: Equatable,Sendable {
    public let modelID:String,effort:String?,fast:Bool?,points:Double?
    public let name:String
    public var identity:String {modelID+"\u{1f}"+(effort ?? "?")+"\u{1f}"+(fast.map{$0 ? "fast":"normal"} ?? "?")}
}
public struct SubscriptionCycleDisplay: Equatable,Sendable {
    public let id:String
    public let endedAt:Date?
    public let used:Double?,hadDrop:Bool?
    public let provenance:ResetProvenance
    public let segments:[SubscriptionHistorySegment]
    public let title:String,value:String
    public let help:HelpExplanation
}
public struct SubscriptionResetDisplay:Equatable,Sendable {
    public let at:Date?
    public let provenance:ResetProvenance
    public let pending:Bool,waiting:Bool
    public let row:SubscriptionNowRow
}
public struct SubscriptionPeakDisplay:Equatable,Sendable {
    public let from:Date,until:Date
    public let row:SubscriptionNowRow
}
public struct SubscriptionHistoryWindow: Equatable,Sendable {
    public let id:String,label:String
    public let rows:[SubscriptionNowRow]
    public let cycles:[SubscriptionCycleDisplay]
    public let events:[SubscriptionResetDisplay]
    public var maximum:Double {
        max(100,cycles.compactMap(\.used).max() ?? 0,cycles.compactMap{strictSum($0.segments.compactMap(\.points).map(Optional.some))}.max() ?? 0)
    }
}
public struct SubscriptionHistoryAccount: Equatable,Sendable {
    public let id:String
    public let headerRows:[SubscriptionNowRow]
    public let windows:[SubscriptionHistoryWindow]
    public let peak:SubscriptionPeakDisplay?
}
/// History consumes supplied facts only. Drop flags never manufacture a redemption/event/timestamp.
public struct SubscriptionHistorySnapshot: Equatable,Sendable {
    public let scope:InstrumentScope,language:InstrumentLanguage
    public let calendar:Calendar
    public let accounts:[SubscriptionHistoryAccount]
    public let initialWindowID:String?
    public init(inputs:[SubscriptionHistoryInput],scope:InstrumentScope,now:Date,language:InstrumentLanguage,calendar:Calendar,initialWindowID:String? = nil) {
        self.scope=scope;self.language=language;self.calendar=calendar;self.initialWindowID=initialWindowID
        let zh=language == .chinese,format=InstrumentFormat(language),catalog=HelpCatalog(language)
        func provenance(_ value:ResetProvenance)->String {
            switch value {
            case .natural:return zh ? "自然到期":"Window end"
            case .publicAnnouncement:return zh ? "官方预告":"Official announcement"
            case .confirmedAwaitingReading:return zh ? "已确认 · 等新读数":"Confirmed · next read"
            case .resetAllowance:return zh ? "重置次数":"Reset use"
            case .correction:return zh ? "修正":"Correction"
            case .unknown:return "--"
            }
        }
        func when(_ date:Date?)->String {
            guard let date,date.timeIntervalSinceReferenceDate.isFinite,date<=now else{return "--"}
            return format.age(date,now:now)
        }
        func row(_ id:String,_ title:String,_ value:String)->SubscriptionNowRow {
            .init(id:id,title:title,value:value,help:catalog.explanation(.usage,context:.init(fact:title+" · "+value)))
        }
        accounts=inputs.map { input in
            let base="subscription.history."+input.id,usable=input.evidence.usable(at:now),attributed=input.attribution == .verifiedSubscription && usable
            let name=input.header?.name ?? "--",age=format.age(input.evidence.observedAt ?? input.header?.evidence.observedAt,now:now)
            let headers=[row(base+".header",name,input.header?.plan ?? "--"),row(base+".source",zh ? "读取来源与时间":"Where and when this was read",(input.sourceLabel ?? "--")+" · "+age)]
            let windows=input.windows.map { window -> SubscriptionHistoryWindow in
                let prefix=base+".window."+window.id
                // Reuse the approved attribution, expiry and ten-cycle retention projection.
                let p=SubscriptionPresentation(id:input.id,windows:.init(windows:[],now:now),reserve:nil,credits:nil,statistics:.unavailable,
                    cycles:window.cycles ?? [],peak:input.peak,observedAt:input.evidence.observedAt,historyAttributed:attributed,now:now,language:language)
                var rows:[SubscriptionNowRow]=[],events:[SubscriptionResetDisplay]=[]
                if !attributed {rows.append(row(prefix+".unavailable",zh ? "记录":"History",zh ? "暂无可归属到此订阅的历史":"No history attributed to this subscription yet"))}
                else if let supplied=window.resets {
                    let active=supplied.filter{$0.evidence.usable(at:now)}.prefix(4)
                    events=active.map { event in
                        let date=event.at.flatMap{$0.timeIntervalSinceReferenceDate.isFinite && $0<=now ? $0:nil}
                        let state=(event.pending ? (zh ? " · 已预告":" · Announced"):"")+(event.waiting ? (zh ? " · 等新读数":" · next read"):"")
                        let item=row(prefix+".reset."+event.id,provenance(event.provenance),when(date)+state)
                        return .init(at:date,provenance:event.provenance,pending:event.pending,waiting:event.waiting,row:item)
                    }
                    rows+=events.map(\.row)
                    if active.isEmpty {rows.append(row(prefix+".resets.empty",zh ? "重置记录":"Resets",supplied.isEmpty ? (zh ? "还没有重置记录":"No resets yet"):"--"))}
                } else {rows.append(row(prefix+".resets.unavailable",zh ? "重置记录":"Resets","--"))}
                let cycles=p.cycles.map { cycle -> SubscriptionCycleDisplay in
                    let date=cycle.endedAt.flatMap{$0.timeIntervalSinceReferenceDate.isFinite && $0<=now ? $0:nil}
                    let segments=cycle.breakdown.map { value in SubscriptionHistorySegment(modelID:value.modelID,effort:value.effort,fast:value.fast,points:value.points,
                        name:input.modelNames[value.modelID] ?? (value.modelID.isEmpty ? "--":value.modelID)) }
                    let used=cycle.used.map{SubscriptionNowSnapshot.number($0)+"%"} ?? "--"
                    let details=segments.map { s in
                        s.name+" · "+(s.effort ?? "--")+" · "+(s.fast.map{$0 ? (zh ? "快速":"Fast"):(zh ? "普通":"Normal")} ?? (zh ? "快速 --":"Fast --"))+" · "+(s.points.map{SubscriptionNowSnapshot.number($0)+"%"} ?? "--")
                    }
                    let drop=cycle.hadDrop.map{$0 ? (zh ? "观察到读数下降；原因未提供":"A reading drop was observed; its cause is not supplied"):(zh ? "未报告读数下降":"No reading drop reported")} ?? (zh ? "读数下降状态 --":"Reading-drop state --")
                    let value=when(date)+" · "+(zh ? "已用 ":"Used ")+used+" · "+provenance(cycle.provenance)+(cycle.hadDrop == true ? (zh ? " · 读数下降":" · Drop observed"):"")
                    let help=HelpExplanation(title:zh ? "周期历史":"Cycles",body:([value]+details+[drop]).joined(separator:"\n"))
                    return .init(id:prefix+".cycle."+cycle.id,endedAt:date,used:cycle.used,hadDrop:cycle.hadDrop,provenance:cycle.provenance,segments:segments,
                        title:zh ? "周期历史":"Cycles",value:value,help:help)
                }
                if cycles.isEmpty {rows.append(row(prefix+".cycles.empty",zh ? "周期历史":"Cycles",attributed && window.cycles?.isEmpty == true ? (zh ? "暂无周期记录":"No cycles yet"):"--"))}
                let label=window.period == .fiveHours ? format.rowName(.fiveHours):window.period == .weekly ? format.rowName(.weekly):format.period(window.period)
                return .init(id:window.id,label:label,rows:rows,cycles:cycles,events:events)
            }
            let peak:SubscriptionPeakDisplay?
            if attributed,let band=input.peak,band.from.timeIntervalSinceReferenceDate.isFinite,band.until.timeIntervalSinceReferenceDate.isFinite {
                let state=now<band.from ? format.future(band.from,now:now):now<band.until ? (zh ? "进行中":"now"):(zh ? "已结束 · ":"Ended · ")+format.age(band.until,now:now)
                peak = .init(from:band.from,until:band.until,row:row(base+".peak",zh ? "高峰时段":"Peak hours",subscriptionAbsoluteTime(band.from,language:language,calendar:calendar)+" – "+subscriptionAbsoluteTime(band.until,language:language,calendar:calendar)+" · "+state))
            } else {peak=nil}
            return .init(id:input.id,headerRows:headers,windows:windows,peak:peak)
        }
    }
    var valid:Bool {
        accounts.count<=128 && Set(accounts.map(\.id)).count==accounts.count && accounts.allSatisfy { a in
            ([a.peak?.row].compactMap{$0}+a.headerRows).allSatisfy{$0.title.utf8.count<=4096 && $0.value.utf8.count<=4096 && $0.help.accessibleDescription.utf8.count<=8192}
                && !a.id.isEmpty && a.id.utf8.count<=256 && a.windows.count<=8 && Set(a.windows.map(\.id)).count==a.windows.count && a.windows.allSatisfy { window in
                !window.id.isEmpty && window.id.utf8.count<=256 && window.label.utf8.count<=4096 && window.cycles.count<=10 && Set(window.cycles.map(\.id)).count==window.cycles.count
                    && window.cycles.allSatisfy{!$0.id.isEmpty && $0.id.utf8.count<=1024 && $0.help.accessibleDescription.utf8.count<=8192 && $0.segments.count<=64}
                    && Set(window.rows.map(\.id)).count==window.rows.count
                    && (a.headerRows+window.rows+[a.peak?.row].compactMap{$0}).allSatisfy{$0.title.utf8.count<=4096 && $0.value.utf8.count<=4096 && $0.help.accessibleDescription.utf8.count<=8192}
            }
        }
    }
    public var selectedAccount:SubscriptionHistoryAccount? {
        guard case .subscription(let id)=scope else{return nil};return accounts.first{$0.id==id}
    }
    public func cycleOption()->MainScreenFooterOption? {
        guard let account=selectedAccount,!account.windows.isEmpty else{return nil}
        return .init(id:"subscription.cycle",choices:account.windows.map{.init($0.id,title:$0.label)},
            selectedValue:account.windows.first(where:{$0.id==initialWindowID})?.id ?? account.windows[0].id,help:HelpCatalog(language).explanation(.option))
    }
    public func display(windowKey:String?)->SubscriptionHistoryDisplay {
        let account=selectedAccount,window=account?.windows.first{$0.id==windowKey} ?? account?.windows.first{$0.id==initialWindowID} ?? account?.windows.first
        return .init(snapshot:self,headerRows:account?.headerRows ?? [],window:window,peak:account?.peak,
            identity:"subscription.history."+(account?.id ?? "missing")+"."+(window?.id ?? "missing"))
    }
}
public struct SubscriptionHistoryDisplay: Equatable,Sendable {
    public let snapshot:SubscriptionHistorySnapshot
    public let headerRows:[SubscriptionNowRow]
    public let window:SubscriptionHistoryWindow?
    public let peak:SubscriptionPeakDisplay?
    public let identity:String
}
