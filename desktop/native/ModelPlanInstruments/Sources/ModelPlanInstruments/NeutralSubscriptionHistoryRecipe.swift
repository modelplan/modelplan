// SPDX-License-Identifier: MIT
import AppKit

@MainActor enum NeutralSubscriptionHistoryRecipe {
    static func make(_ display:SubscriptionHistoryDisplay,in viewport:CGRect)->MainScreenListRecipe {
        let language=display.snapshot.language,foreground=EngineInk(NSColor.labelColor),muted=EngineInk(NSColor.secondaryLabelColor),rule=EngineInk(NSColor.separatorColor)
        let header=display.headerRows+(display.peak.map{[$0.row]} ?? [])+(display.window?.rows ?? [])
        var rows=header.isEmpty ? []:NeutralSubscriptionRecipe.make(rows:header,identity:display.identity,language:language,in:viewport).rows
        if let window=display.window {
            for cycle in window.cycles {
                let height=84.0,plot=CGRect(x:6,y:44,width:viewport.width-12,height:24)
                var commands:[EngineDrawingCommand]=[
                    .text(.init(id:cycle.id+".title",variants:[cycle.title],rect:CGRect(x:6,y:2,width:viewport.width-12,height:17),font:.init(size:12),ink:foreground)),
                    .text(.init(id:cycle.id+".value",variants:[cycle.value,"…"],rect:CGRect(x:6,y:21,width:viewport.width-12,height:17),font:.init(size:10),ink:muted)),
                    .stroke(rect:plot,radius:0,width:0.5,ink:rule)]
                if let geometry=SubscriptionCycleGeometry(cycle:cycle,plot:plot,maximum:window.maximum) {
                    for bar in geometry.bars {
                        let key=bar.segment?.identity ?? "total"
                        let slot=Int(key.utf8.reduce(UInt64(14695981039346656037)){($0 ^ UInt64($1)) &* 1099511628211}%5)
                        let opacity=[1.0,0.8,0.6,0.4,0.25][slot],ink=EngineInk(foreground.red,foreground.green,foreground.blue,opacity)
                        commands.append(.fill(rect:bar.rect,radius:0,ink:ink))
                        if bar.segment?.fast == true {
                            var hatch:[EngineDrawingCommand]=[]
                            var x=bar.rect.minX-bar.rect.height
                            while x<bar.rect.maxX {
                                hatch.append(.polyline(points:[.init(x:x,y:bar.rect.maxY),.init(x:x+bar.rect.height,y:bar.rect.minY)],width:1,ink:rule));x+=6
                            }
                            commands.append(.clipped(rect:bar.rect,radius:0,commands:hatch))
                        }
                    }
                }
                commands.append(.text(.init(id:cycle.id+".scale",variants:["0–"+SubscriptionNowSnapshot.number(window.maximum)+"%"],rect:CGRect(x:6,y:70,width:viewport.width-12,height:12),font:.init(size:9),ink:muted,alignment:.right)))
                commands.append(.polyline(points:[.init(x:6,y:height-1),.init(x:viewport.width-6,y:height-1)],width:0.5,ink:rule))
                rows.append(.init(height:height,commands:commands,region:.init(id:cycle.id,rect:CGRect(x:0,y:0,width:viewport.width,height:height),
                    label:cycle.help.body,help:cycle.help,role:.readout,value:cycle.value,focusGroup:"subscription.rows")))
            }
        }
        if rows.isEmpty {
            let row=SubscriptionNowRow(id:display.identity+".unavailable",title:language == .chinese ? "记录":"History",value:"--",help:HelpCatalog(language).explanation(.usage))
            rows=NeutralSubscriptionRecipe.make(rows:[row],identity:display.identity,language:language,in:viewport).rows
        }
        return .init(identity:display.identity,viewport:viewport,rows:rows)
    }
}
