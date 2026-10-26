// SPDX-License-Identifier: MIT
import Foundation

public struct DestinationProjectDisplay:Equatable,Sendable {
    public let id:String,name:String,tokens:Double?
}
public struct DestinationSessionDisplay:Equatable,Sendable {
    public let id:String,tool:String,model:String,effort:String?,projectName:String?
    public let fast:Bool,activity:RecordActivity
    public let tokens:Double?,speed60s:Double?
    public let startedAt:Date?,endedAt:Date?
    public let timeLabel:String
    public let help:HelpExplanation
}
public struct DestinationProjectPeriod:Equatable,Sendable {
    public let period:ProjectRankingPeriod
    public let rows:[DestinationProjectDisplay]
    public let unavailable:Bool
}
public struct DestinationTimeline:Equatable,Sendable {
    public let range:TimelineRange
    public let rows:[DestinationSessionDisplay]
}
public struct DestinationsPageSnapshot:Equatable,Sendable {
    public let scope:InstrumentScope,language:InstrumentLanguage
    public let calendar:Calendar
    public let projects:[DestinationProjectPeriod],timelines:[DestinationTimeline]
    public let details:[DestinationSessionDisplay]
    public init(rankings:[SuppliedProjectRanking],sessions:[InstrumentSession],scope:InstrumentScope,showProjectNames:Bool,
                now:Date,calendar:Calendar,language:InstrumentLanguage) {
        self.scope=scope;self.language=language;self.calendar=calendar
        let zh=language == .chinese,format=InstrumentFormat(language)
        let eligible=sessions.filter{$0.evidence.usable(at:now)}
        func session(_ line:RecordLine)->DestinationSessionDisplay {
            let matches=eligible.filter{$0.id==line.id},raw=matches.count==1 ? matches[0]:nil
            let start=raw?.startedAt.flatMap{$0<=now ? $0:nil},end=raw?.endedAt.flatMap{$0<=now ? $0:nil}
            let time:String
            if line.working {time=(zh ? "运行中 · ":"Running · ")+format.duration(minutes:start.map{now.timeIntervalSince($0)/60})}
            else if let end {time=(zh ? "已结束 · ":"Ended · ")+format.age(end,now:now)}
            else {time=(zh ? "状态未知 · 最后读数 ":"Unknown state · Last seen ")+(line.age ?? "--")}
            let project=showProjectNames ? line.projectName:nil
            let values=[line.tool,line.model,line.effort ?? "--",line.fast ? (zh ? "快速":"Fast"):"",project,time,
                (zh ? "输出 ":"Output ")+format.tokens(line.tokens),line.speed60s.map{String(format:"%.0f t/s",locale:Locale(identifier:"en_US_POSIX"),$0)}]
                .compactMap{$0}.filter{!$0.isEmpty}.joined(separator:" · ")
            return .init(id:line.id,tool:line.tool,model:line.model,effort:line.effort,projectName:project,fast:line.fast,activity:line.activity,
                tokens:line.tokens,speed60s:line.speed60s,startedAt:start,endedAt:end,timeLabel:time,
                help:HelpCatalog(language).explanation(.session,context:.init(fact:values)))
        }
        projects=[ProjectRankingPeriod.days7,.days30].map { period in
            let matches=rankings.filter{$0.period==period}
            let p=DestinationsPresentation(ranking:matches.count==1 ? matches[0]:nil,expectedPeriod:period,sessions:[],scope:scope,
                timelineRange:.today,showProjectNames:showProjectNames,now:now,calendar:calendar,language:language)
            return .init(period:period,rows:p.projects.map{.init(id:$0.id,name:$0.name ?? (zh ? "项目":"Project"),tokens:$0.tokens)},unavailable:p.projectUnavailableReason != nil)
        }
        timelines=[TimelineRange.today,.days7].map { range in
            let p=DestinationsPresentation(projects:[],sessions:eligible,scope:scope,timelineRange:range,showProjectNames:showProjectNames,now:now,calendar:calendar,language:language)
            return .init(range:range,rows:p.timeline.map(session))
        }
        details=eligible.filter{scope == .all || $0.subscriptionID.map{scope == .subscription($0)} == true}.map { raw in
            let working=raw.working(now:now),identity=raw.effort.map{SessionRateIdentity(sessionID:raw.id,modelID:raw.model,effort:$0,fast:raw.fast)}
            let line=RecordLine(id:raw.id,working:working,speed60s:working ? identity.flatMap{raw.rate?.reading(now:now,matching:$0)}:nil,
                age:working ? nil:format.age(raw.endedAt ?? raw.lastAt,now:now),tool:raw.tool,model:raw.model,effort:raw.effort,fast:raw.fast,
                projectID:raw.projectID,projectName:showProjectNames ? raw.projectName:nil,tokens:raw.tokens,
                activity:working ? .working:raw.endedAt.map{$0<=now ? .completed:.unknown} ?? .unknown)
            return session(line)
        }
    }
    var valid:Bool {
        projects.allSatisfy{$0.rows.count<=256 && Set($0.rows.map(\.id)).count==$0.rows.count && $0.rows.allSatisfy{!$0.id.isEmpty && $0.id.utf8.count<=256 && $0.name.utf8.count<=4096}}
            && details.count<=256 && Set(details.map(\.id)).count==details.count
            && details.allSatisfy{$0.help.accessibleDescription.utf8.count<=8192}
            && timelines.allSatisfy{$0.rows.count<=256 && Set($0.rows.map(\.id)).count==$0.rows.count && $0.rows.allSatisfy{!$0.id.isEmpty && $0.id.utf8.count<=256 && $0.help.accessibleDescription.utf8.count<=8192}}
    }
    public func pageContent()->MainScreenPageContent {
        let zh=language == .chinese,help=HelpCatalog(language).explanation(.option)
        return .init(.destinations,options:[
            .init(id:"destinations.mode",choices:[.init("proj",title:zh ? "项目":"Projects"),.init("time",title:zh ? "时间":"Timeline")],selectedValue:"proj",help:help),
            .init(id:"destinations.days",choices:[.init("7",title:"7"),.init("30",title:"30")],selectedValue:"7",help:help),
            .init(id:"destinations.time",choices:[.init("today",title:zh ? "今日":"Today"),.init("7d",title:zh ? "7天":"7d")],selectedValue:"today",help:help)],destinations:self)
    }
    public func display(location:MainScreenLocation)->DestinationsPageDisplay {
        .init(snapshot:self,location:location,projects:projects.first{$0.period==location.projectPeriod}!,timeline:timelines.first{$0.range==location.timelineRange}!)
    }
}
public struct DestinationsPageDisplay:Equatable,Sendable {
    public let snapshot:DestinationsPageSnapshot
    public let location:MainScreenLocation
    public let projects:DestinationProjectPeriod
    public let timeline:DestinationTimeline
}
