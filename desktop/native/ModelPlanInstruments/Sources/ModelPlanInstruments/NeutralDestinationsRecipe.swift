// SPDX-License-Identifier: MIT
import AppKit

@MainActor enum NeutralDestinationsRecipe {
    static func make(_ p:DestinationsPageDisplay,in area:CGRect)->MainScreenListRecipe {
        let zh=p.snapshot.language == .chinese,format=InstrumentFormat(p.snapshot.language)
        var rows:[MainScreenListRowRecipe]=[]
        func row(_ id:String,_ title:String,_ value:String,_ help:HelpExplanation,_ action:MainScreenAction? = nil) {
            let r=CGRect(x:0,y:0,width:area.width,height:42)
            let commands:[EngineDrawingCommand]=[
                .text(.init(id:id+".title",variants:[title,String(title.prefix(30))+"…"],rect:CGRect(x:6,y:2,width:r.width-12,height:18),font:.init(size:11),ink:EngineInk(NSColor.labelColor))),
                .text(.init(id:id+".value",variants:[value,String(value.prefix(50))+"…"],rect:CGRect(x:6,y:22,width:r.width-12,height:16),font:.init(size:10),ink:EngineInk(NSColor.secondaryLabelColor)))]
            rows.append(.init(height:42,commands:commands,region:.init(id:id,rect:r,action:action,label:title+" · "+value,help:help,role:action == nil ? .readout:.button,value:value,focusGroup:"destination.rows")))
        }
        if p.location.destinationsMode == .projects {
            for project in p.projects.rows {
                let value=format.tokens(project.tokens),help=HelpCatalog(p.snapshot.language).explanation(.usage,context:.init(fact:project.name+" · "+value))
                row("destination.project."+project.id,project.name,value,help)
            }
        } else {
            for session in p.timeline.rows {
                let title=session.tool+" · "+session.model+" · "+(session.effort ?? "--")+(session.fast ? " ⚡":"")
                let value=([session.projectName,session.timeLabel,format.tokens(session.tokens)]).compactMap{$0}.joined(separator:" · ")
                row("destination.session."+session.id,title,value,session.help,.session(session.id))
            }
        }
        if rows.isEmpty {row("destination.empty",zh ? "暂无记录":"No records available","--",HelpCatalog(p.snapshot.language).explanation(.usage))}
        return .init(identity:"destinations.\(p.snapshot.scope).\(p.location.destinationsMode).\(p.location.projectPeriod).\(p.location.timelineRange)",viewport:area,rows:rows)
    }
    static func detail(_ p:DestinationSessionDisplay,language:InstrumentLanguage,in area:CGRect)->MainScreenListRecipe {
        let zh=language == .chinese,format=InstrumentFormat(language),base="session.detail."+p.id
        let fields:[(String,String,String)]=[
            ("tool",zh ? "工具":"Tool",p.tool),("model",zh ? "模型":"Model",p.model),("effort",zh ? "档位":"Effort",p.effort ?? "--"),
            ("fast",zh ? "快速":"Fast",p.fast ? (zh ? "开":"On"):(zh ? "关":"Off")),
            ("project",zh ? "项目":"Project",p.projectName ?? "--"),("time",zh ? "时间":"Time",p.timeLabel),
            ("tokens",zh ? "输出":"Output",format.tokens(p.tokens)),("speed",zh ? "速度 · 最近60秒":"Speed · last 60s",p.speed60s.map{String(format:"%.0f t/s",locale:Locale(identifier:"en_US_POSIX"),$0)} ?? "--")]
        let rows=fields.map{SubscriptionNowRow(id:base+"."+$0.0,title:$0.1,value:$0.2,help:p.help)}
        return NeutralSubscriptionRecipe.make(rows:rows,identity:base,language:language,in:area)
    }
}
