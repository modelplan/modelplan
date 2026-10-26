// SPDX-License-Identifier: MIT
import AppKit
import CoreText

/// Ordinary system-font overview. Official chart registration, palette and material remain injected.
@MainActor enum NeutralOverviewRecipe {
    static func legendRows(_ display: OverviewPageDisplay) -> Int { max(1,(display.snapshot.series.count+2)/3) }
    static func minimumHeight(_ display: OverviewPageDisplay) -> Double {
        max(340,250+Double(legendRows(display))*20+Double(max(0,display.snapshot.series.count-1))*2)
    }
    static func make(_ display: OverviewPageDisplay, in area: CGRect) throws -> (commands:[EngineDrawingCommand],regions:[MainScreenHitRegion]) {
        let zh=display.language == .chinese
        let fg=EngineInk(NSColor.labelColor),muted=EngineInk(NSColor.secondaryLabelColor),rule=EngineInk(NSColor.separatorColor)
        let palette=[NSColor.systemBlue,.systemOrange,.systemGreen,.systemPurple,.systemPink,.systemTeal].map(EngineInk.init)
        var commands:[EngineDrawingCommand]=[],regions:[MainScreenHitRegion]=[]
        func ink(_ id: String) -> EngineInk { display.snapshot.series.first{$0.id==id}?.ink ?? palette[display.snapshot.paletteSlot(for:id)] }
        func text(_ id: String,_ value: String,_ rect: CGRect,_ color: EngineInk = fg,_ size: Double = 11) {
            // One-line visual truncation retains the complete string in the native data alternative.
            let font=NSFont.monospacedSystemFont(ofSize:size,weight:.regular)
            let line=CTLineCreateWithAttributedString(NSAttributedString(string:value,attributes:[.font:font]))
            var shown=value
            if CTLineGetTypographicBounds(line,nil,nil,nil)>rect.width {
                var prefix=value
                while !prefix.isEmpty {
                    prefix.removeLast();shown=prefix+"…"
                    let candidate=CTLineCreateWithAttributedString(NSAttributedString(string:shown,attributes:[.font:font]))
                    if CTLineGetTypographicBounds(candidate,nil,nil,nil)<=rect.width {break}
                }
            }
            commands.append(.text(.init(id:id,variants:[shown],rect:rect,font:.init(size:size),ink:color)))
        }
        let notices=display.visibleNotices(limit:3)
        for (i,notice) in notices.notices.enumerated() {
            let rect=CGRect(x:area.minX,y:area.minY+Double(i)*20,width:area.width,height:18)
            let color=EngineInk(notice.severity == .critical ? NSColor.systemRed:notice.severity == .amber ? .systemOrange:.systemBlue)
            commands.append(.ellipse(rect:CGRect(x:rect.minX,y:rect.midY-3,width:6,height:6),ink:color))
            text("overview.notice.\(notice.id)",notice.text,rect.insetBy(dx:12,dy:0),color)
            regions.append(.init(id:"overview.notice.\(notice.id)",rect:rect,label:notice.text,
                help:.init(title:zh ? "提醒":"Alerts",body:notice.text),role:.readout))
        }
        if notices.more>0 {
            let label=zh ? "+\(notices.more) 条提醒 ›":"+\(notices.more) alerts ›"
            let rect=CGRect(x:area.minX,y:area.minY+40,width:area.width,height:18)
            text("overview.more",label,rect)
            regions.append(.init(id:"overview.more",rect:rect,action:.overviewAlerts,label:label,
                help:.init(title:zh ? "提醒":"Alerts",body:label)))
        } else if let info=notices.information {
            let rect=CGRect(x:area.minX,y:area.minY+Double(notices.notices.count)*20,width:area.width,height:18)
            text("overview.information",info.text+(info.actionLabel.map{" · "+$0} ?? ""),rect,muted)
            regions.append(.init(id:"overview.information",rect:rect,action:info.actionLabel == nil ? nil:.overviewInformation(info.id),
                label:info.text,help:.init(title:zh ? "信息":"Information",body:info.text),role:info.actionLabel == nil ? .readout:.button))
        }
        let totalRect=CGRect(x:area.minX,y:area.minY+64,width:area.width,height:20)
        let totals=(zh ? "今日 ":"Today ")+display.todayText+" · "+(zh ? "30天 ":"30 days ")+display.days30Text
        text("overview.totals",totals,totalRect)
        regions.append(.init(id:"overview.totals",rect:totalRect,label:totals,help:.init(title:zh ? "用量":"Usage",body:totals),role:.readout))
        if display.visualization == .heatmap {
            let color:EngineInk
            if case .subscription(let id)=display.snapshot.scope {color=ink(id)} else {color=fg}
            let drawing=try NeutralHeatmapRecipe.make(display,in:CGRect(x:area.minX,y:area.minY+92,width:area.width,height:area.height-92),ink:color)
            return (commands+drawing.commands,regions+drawing.regions)
        }
        let legendHeight=Double(legendRows(display))*20
        let plot=CGRect(x:area.minX,y:area.minY+92,width:area.width,height:area.height-112-legendHeight)
        guard let geometry=OverviewChartGeometry(display:display,plot:plot) else {throw EngineTableError.invalidRecipe}
        for fraction in [0.0,0.5,1] {
            let y=plot.maxY-plot.height*fraction
            commands.append(.polyline(points:[.init(x:plot.minX,y:y),.init(x:plot.maxX,y:y)],width:0.5,ink:rule))
        }
        for bar in geometry.bars { commands.append(.fill(rect:bar.rect,radius:0,ink:ink(bar.subscriptionID))) }
        for bucket in geometry.buckets {
            let help=display.explanation(bucket.bucket)
            regions.append(.init(id:bucket.bucket.id,rect:bucket.hitRect,label:help.body,help:help,role:.readout,value:help.body,focusGroup:"overview.buckets"))
        }
        let count=geometry.buckets.count
        let ticks=[0,count/2,count-1]
        for (j,i) in ticks.enumerated() {
            let bucket=geometry.buckets[i].bucket
            let date=DateFormatter();date.calendar=display.snapshot.calendar;date.timeZone=display.snapshot.calendar.timeZone
            date.locale=Locale(identifier:zh ? "zh_CN":"en_US_POSIX");date.dateFormat=display.chart.range == .hours24 ? "HH:mm":"M/d"
            let rect=CGRect(x:plot.minX+Double(j)*(plot.width-72)/2,y:plot.maxY+2,width:72,height:16)
            text("overview.tick.\(i)",date.string(from:bucket.start),rect,muted,10)
        }
        for (i,series) in display.snapshot.series.enumerated() {
            let rect=CGRect(x:area.minX+Double(i%3)*area.width/3,y:plot.maxY+20+Double(i/3)*20,width:area.width/3,height:18)
            commands.append(.fill(rect:CGRect(x:rect.minX,y:rect.minY+5,width:8,height:8),radius:0,ink:ink(series.id)))
            text("overview.legend.\(series.id)",series.shortName,CGRect(x:rect.minX+12,y:rect.minY,width:rect.width-14,height:rect.height),fg,10)
            regions.append(.init(id:"overview.legend.\(series.id)",rect:rect,label:series.name,help:.init(title:series.name,body:series.name),role:.readout))
        }
        return (commands,regions)
    }
}
