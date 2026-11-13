// SPDX-License-Identifier: MIT
import Foundation

/// Already-normalized token kinds and eligible generation sums from the host's typed feed.
public struct SubscriptionUsageInput: Sendable {
    public let period: UsageSummaryPeriod
    public let detail: UsageTokenDetail?
    public let generation: [GenerationSums]
    /// Generation-rate recording availability; independently reported token kinds remain usable.
    public let recording: Bool
    public let attribution: UsageAttribution
    public let evidence: InstrumentEvidence
    public init(period:UsageSummaryPeriod,detail:UsageTokenDetail?,generation:[GenerationSums] = [],recording:Bool,
                attribution:UsageAttribution,evidence:InstrumentEvidence = .init()) {
        self.period=period;self.detail=detail;self.generation=generation;self.recording=recording;self.attribution=attribution;self.evidence=evidence
    }
}
public struct SubscriptionNowInput: Sendable {
    public let id: String
    public let header: SubscriptionHeader?
    public let sourceLabel: String?
    public let evidence: InstrumentEvidence
    public let windows: [InstrumentQuota]
    public let reserve: ReservePresentation?
    public let credits: CreditPresentation?
    public let usage: [SubscriptionUsageInput]
    public init(id:String,header:SubscriptionHeader?,windows:[InstrumentQuota],sourceLabel:String? = nil,
                evidence:InstrumentEvidence = .init(),reserve:ReservePresentation? = nil,credits:CreditPresentation? = nil,
                usage:[SubscriptionUsageInput] = []) {
        self.id=id;self.header=header;self.windows=windows;self.sourceLabel=sourceLabel;self.evidence=evidence
        self.reserve=reserve;self.credits=credits;self.usage=usage
    }
}
public struct SubscriptionQuotaGauge: Equatable, Sendable {
    public let remaining:Double?
    public let segments:Int?
    init(_ cell:QuotaCell) {remaining=cell.remaining;segments=cell.litSegments}
}
/// A supplied, still-actionable reset instant plus both host-local and relative descriptions.
public struct SubscriptionWindowReset: Equatable, Sendable {
    public let instant:Date
    public let absolute:String, countdown:String
    init?(_ cell:QuotaCell,now:Date,language:InstrumentLanguage,calendar:Calendar) {
        guard let instant=cell.resetsAt,instant>now,instant.timeIntervalSinceReferenceDate.isFinite else{return nil}
        self.instant=instant
        absolute=subscriptionAbsoluteTime(instant,language:language,calendar:calendar)
        countdown=InstrumentFormat(language).reset(instant,now:now)
    }
}
func subscriptionAbsoluteTime(_ date:Date,language:InstrumentLanguage,calendar:Calendar)->String {
    let formatter=DateFormatter()
    formatter.locale=calendar.locale ?? Locale(identifier:language == .chinese ? "zh_CN":"en_US_POSIX")
    formatter.calendar=calendar;formatter.timeZone=calendar.timeZone
    formatter.setLocalizedDateFormatFromTemplate("yMdjmsz")
    return formatter.string(from:date)
}
public struct SubscriptionNowRow: Equatable, Sendable {
    public let id: String, title: String, facts: String
    public let reset:SubscriptionWindowReset?
    public var value:String {facts+(reset.map{" · "+$0.absolute+" · "+$0.countdown} ?? "")}
    public let help: HelpExplanation
    public let level: QuotaLevel
    public let scopeTarget: String?
    public let quota:SubscriptionQuotaGauge?
    public init(id:String,title:String,value:String,help:HelpExplanation,level:QuotaLevel = .unknown,scopeTarget:String? = nil,quota:SubscriptionQuotaGauge? = nil,reset:SubscriptionWindowReset? = nil) {
        self.id=id;self.title=title;self.facts=value;self.reset=reset;self.help=help;self.level=level;self.scopeTarget=scopeTarget;self.quota=quota
    }
}
public struct SubscriptionUsageDisplay: Equatable, Sendable {
    public let days: Int
    public let rows: [SubscriptionNowRow]
}
public struct SubscriptionNowAccount: Equatable, Sendable {
    public let id: String, name: String
    public let glyphID: String?
    public let summary: SubscriptionNowRow
    public let rows: [SubscriptionNowRow]
    public let usage: [SubscriptionUsageDisplay]
}
/// A value projection only. The host supplies time/deadline updates; no reader, updater or timer is owned here.
public struct SubscriptionNowSnapshot: Equatable, Sendable {
    public let scope: InstrumentScope
    public let accounts: [SubscriptionNowAccount]
    public let initialDays: Int
    public let language:InstrumentLanguage
    public let calendar:Calendar
    public init(inputs:[SubscriptionNowInput],scope:InstrumentScope,now:Date,language:InstrumentLanguage,calendar:Calendar,redBelow:Double,initialDays:Int = 7) {
        self.language=language;self.calendar=calendar
        self.scope=scope;self.initialDays=initialDays==30 ? 30:7
        let format=InstrumentFormat(language),zh=language == .chinese,catalog=HelpCatalog(language)
        func row(_ id:String,_ title:String,_ value:String,_ topic:HelpTopic,_ level:QuotaLevel = .unknown,_ quota:SubscriptionQuotaGauge? = nil,_ reset:SubscriptionWindowReset? = nil) -> SubscriptionNowRow {
            let full=value+(reset.map{" · "+$0.absolute+" · "+$0.countdown} ?? "")
            return .init(id:id,title:title,value:value,help:catalog.explanation(topic,context:.init(fact:title+" · "+full)),level:level,quota:quota,reset:reset)
        }
        func windowName(_ cell:QuotaCell)->String {
            let name=cell.period == .fiveHours ? format.rowName(.fiveHours):cell.period == .weekly ? format.rowName(.weekly):format.period(cell.period)
            return name+(cell.scope.map{" · "+$0} ?? "")
        }
        accounts=inputs.map { input in
            let prefix="subscription."+input.id,name=input.header?.name.flatMap{$0.isEmpty ? nil:$0} ?? "--"
            let usable=input.evidence.usable(at:now)
            let windows=QuotaRows(windows:input.windows.map { w in
                .init(id:w.id,period:w.period,scope:w.scope,remaining:w.remaining,resetsAt:w.resetsAt,durationMinutes:w.durationMinutes,
                    readable:w.readable && usable,runsOutAt:w.runsOutAt,publicReset:w.publicReset)
            },now:now,redBelow:redBelow)
            let all=[windows.fiveHours,windows.weekly].compactMap{$0}+windows.other
            let status=usable ? "":zh ? " · 读数不可用":" · Reading unavailable"
            let age=format.age(input.evidence.observedAt ?? input.header?.evidence.observedAt,now:now)
            var reserveBrief:String?,creditBrief:String?
            var rows=[row(prefix+".header",name,input.header?.plan ?? "--",.subscription),
                row(prefix+".source",zh ? "读取来源与时间":"Where and when this was read",(input.sourceLabel ?? "--")+" · "+age+status,.source)]
            for cell in all {
                let deadline=SubscriptionWindowReset(cell,now:now,language:language,calendar:calendar)
                let text=format.percent(cell.remaining)+(deadline == nil ? " · --":"") +
                    (cell.runsOutAt.map{" · "+(zh ? "预计用尽 · ":"Estimated run-out · ")+format.future($0,now:now)} ?? "")
                let reset:String
                switch cell.publicReset {
                case .announced(let at):reset=zh ? " · 公开重置预告 · "+format.future(at,now:now):" · Public reset announced · "+format.future(at,now:now)
                case .confirmedAwaitingReading:reset=zh ? " · 已重置 · 等读数":" · Reset · awaiting reading"
                case nil:reset=""
                }
                rows.append(row(prefix+".window."+cell.id,windowName(cell),text+reset,.quota,cell.level,.init(cell),deadline))
            }
            if let raw=input.reserve {
                let reserve=ReservePresentation(allowances:raw.allowances,credits:nil,drawingCredits:false,now:now)
                let count=reserve.resets.map { zh ? "重置 \($0) 次":"\($0) "+($0==1 ? "reset":"resets") } ?? (zh ? "重置 -- 次":"-- resets")
                reserveBrief=count
                let compact=reserve.compactExpiries.map{format.expiry($0,now:now)}
                let value=([count]+compact+(reserve.expiryOverflow>0 ? ["+\(reserve.expiryOverflow)"]:[])).joined(separator:" · ")
                let full=(reserve.allowances ?? []).map { a in
                    let trusted=a.evidence.usable(at:now)
                    return (trusted ? a.count.flatMap{$0>=0 ? String($0):nil} ?? "--":"--")+" · "+format.expiry(trusted ? a.expiresAt:nil,now:now)
                }
                rows.append(.init(id:prefix+".reserve",title:zh ? "储备":"Reserve",value:value,
                    help:catalog.explanation(.reserve,context:.init(fact:([count]+full).joined(separator:"\n"))),level:reserve.expiryWarning ? .amber:.unknown))
            }
            if let credits=input.credits {
                let valid=credits.evidence.usable(at:now),balance=Self.number(valid ? credits.balance:nil)
                let drawing=valid ? credits.drawingCredits:nil
                let state=drawing.map { $0 ? (zh ? "正在用点数":"Using credits"):(zh ? "未在用点数":"Not using credits") } ?? (zh ? "是否正在用点数 --":"Credit use --")
                creditBrief=(zh ? "点数 ":"Credits ")+balance
                let value=balance+" · "+format.age(credits.observedAt,now:now)+" · "+state
                rows.append(.init(id:prefix+".credits",title:zh ? "点数":"Credits",value:value,
                    help:.init(title:zh ? "点数":"Credits",body:(zh ? "当前点数余额与读取时间。":"Reported credit balance and reading time.")+"\n"+value)))
            }
            let usage=[7,30].map { days->SubscriptionUsageDisplay in
                let period:UsageSummaryPeriod=days==7 ? .days7:.days30
                let matches=input.usage.filter{$0.period==period},candidate=matches.count==1 ? matches[0]:nil
                let attributed=candidate.map{$0.attribution == .verifiedSubscription && $0.evidence.usable(at:now)} ?? false
                let detail=attributed ? candidate?.detail:nil
                let speed=attributed ? GenerationSums.weightedTPS(candidate?.generation ?? [],recording:candidate?.recording ?? false):nil
                let base=prefix+".usage.\(days)",label=zh ? "\(days)日用量":"\(days)-day usage"
                var stats=[row(base+".basis",label,attributed ? (zh ? "此订阅":"This subscription"):(zh ? "暂无可归属到此订阅的统计":"No statistics attributed to this subscription yet"),.usage)]
                let values:[(String,String,Double?)]=[("input",zh ? "输入":"Input",detail?.input),("output",zh ? "输出":"Output",detail?.output),
                    ("cache.read",zh ? "缓存读":"Cache read",detail?.cacheRead),("cache.write",zh ? "缓存写":"Cache write",detail?.cacheWrite)]
                stats+=values.map{row(base+"."+$0.0,$0.1,format.tokens($0.2),.usage)}
                let hit=detail?.cacheHitRatio.map{String(format:"%.0f%%",locale:Locale(identifier:"en_US_POSIX"),$0*100)} ?? "--"
                stats.append(.init(id:base+".cache.hit",title:zh ? "缓存命中":"Cache hit",value:hit,
                    help:catalog.explanation(.usage,context:.init(fact:(zh ? "缓存命中 = 缓存读 /（输入 + 缓存读）；缓存写不重复计入。":"Cache hit = cache read / (input + cache read); cache write is not counted again.")+" · "+hit))))
                let speedText=speed.map{String(format:"%.0f t/s",locale:Locale(identifier:"en_US_POSIX"),$0)} ?? "--"
                stats.append(.init(id:base+".speed",title:zh ? "速度":"Speed",value:speedText,
                    help:catalog.explanation(.periodSpeed,context:.init(value:speedText,statisticsPeriod:days==7 ? .days7:.days30))))
                return .init(days:days,rows:stats)
            }
            let tightest=all.min { ($0.remaining ?? .infinity)<($1.remaining ?? .infinity) }
            let summaryValue=([input.header?.plan ?? "--",tightest.map{windowName($0)+" "+format.percent($0.remaining)},reserveBrief,creditBrief].compactMap{$0}).joined(separator:" · ")+status
            let summaryReset=tightest.flatMap{SubscriptionWindowReset($0,now:now,language:language,calendar:calendar)}
            let summaryFull=summaryValue+(summaryReset.map{" · "+$0.absolute+" · "+$0.countdown} ?? "")
            let summary=SubscriptionNowRow(id:prefix+".select",title:name,value:summaryValue,
                help:catalog.explanation(.subscription,context:.init(fact:name+" · "+summaryFull)),level:tightest?.level ?? .unknown,scopeTarget:input.id,quota:tightest.map{.init($0)},reset:summaryReset)
            return .init(id:input.id,name:name,glyphID:input.header?.glyphID,summary:summary,rows:rows,usage:usage)
        }
    }
    public static func number(_ value:Double?)->String {
        guard let value=known(value) else{return "--"}
        let f=NumberFormatter();f.locale=Locale(identifier:"en_US_POSIX");f.numberStyle = .decimal;f.usesGroupingSeparator=true;f.groupingSize=3
        f.usesSignificantDigits=true;f.minimumSignificantDigits=1;f.maximumSignificantDigits=15
        return f.string(from:NSNumber(value:value)) ?? "--"
    }
    var valid:Bool {
        accounts.count<=128 && Set(accounts.map(\.id)).count==accounts.count && accounts.allSatisfy { a in
            !a.id.isEmpty && a.id.utf8.count<=256 && a.rows.count<=128 && (a.glyphID?.utf8.count ?? 0)<=256 && a.usage.count==2
                && ([a.summary]+a.rows+a.usage.flatMap(\.rows)).allSatisfy { !$0.id.isEmpty && $0.id.utf8.count<=1024 && $0.title.utf8.count<=4096 && $0.value.utf8.count<=4096 && $0.help.accessibleDescription.utf8.count<=8192 }
                && Set(a.rows.map(\.id)).count==a.rows.count
        }
    }
    public func pageContent(history:SubscriptionHistorySnapshot? = nil,initialTab:SubscriptionTab = .now)->MainScreenPageContent {
        let zh=language == .chinese,help=HelpCatalog(language).explanation(.option)
        let options:[MainScreenFooterOption?]
        if case .subscription(let id)=scope,accounts.contains(where:{$0.id==id}) {
            options=[.init(id:"subscription.tab",choices:[.init("now",title:zh ? "概况":"Now"),.init("history",title:zh ? "记录":"History",enabled:history?.selectedAccount != nil)],selectedValue:initialTab == .history && history?.selectedAccount != nil ? "history":"now",help:help),
                .init(id:"subscription.usage",choices:[.init("7",title:"7"),.init("30",title:"30")],selectedValue:String(initialDays),help:help),history?.cycleOption()]
        } else {options=[nil,nil,nil]}
        return .init(.subscriptions,options:options,subscription:self,history:history)
    }
    public func display(daysKey:String?)->SubscriptionNowDisplay {
        let days=daysKey=="30" ? 30:daysKey=="7" ? 7:initialDays
        let rows:[SubscriptionNowRow],identity:String
        switch scope {
        case .all:rows=accounts.map(\.summary);identity="subscriptions.all"
        case .subscription(let id):
            let account=accounts.first{$0.id==id};rows=(account?.rows ?? [])+(account?.usage.first{$0.days==days}?.rows ?? []);identity="subscriptions.single."+id
        }
        return .init(snapshot:self,rows:rows,identity:identity,days:days,language:language)
    }
}
public struct SubscriptionNowDisplay: Equatable, Sendable {
    public let snapshot:SubscriptionNowSnapshot
    public let rows:[SubscriptionNowRow]
    public let identity:String
    public let days:Int
    public let language:InstrumentLanguage
}
