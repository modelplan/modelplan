// SPDX-License-Identifier: MIT
import AppKit
import CoreText

@MainActor enum NeutralSubscriptionRecipe {
    private static func shortened(_ value:String,width:Double,size:Double)->String {
        let characters=Array(value),font=NSFont.monospacedSystemFont(ofSize:size,weight:.regular)
        func fits(_ s:String)->Bool {CTLineGetTypographicBounds(CTLineCreateWithAttributedString(NSAttributedString(string:s,attributes:[.font:font])),nil,nil,nil)<=width}
        if fits(value) {return value}
        var lower=0,upper=characters.count
        while lower<upper {let mid=(lower+upper+1)/2;if fits(String(characters.prefix(mid))+"…") {lower=mid} else {upper=mid-1}}
        return String(characters.prefix(lower))+"…"
    }
    static func make(_ display:SubscriptionNowDisplay,in viewport:CGRect)->MainScreenListRecipe {
        let foreground=EngineInk(NSColor.labelColor),muted=EngineInk(NSColor.secondaryLabelColor)
        let input=display.rows.isEmpty ? [SubscriptionNowRow(id:display.identity+".empty",title:display.language == .chinese ? "暂无信息":"No information available",value:"--",help:HelpCatalog(display.language).explanation(.subscription))]:display.rows
        let rows=input.map { row -> MainScreenListRowRecipe in
            let color=row.level == .critical ? EngineInk(NSColor.systemRed):row.level == .amber ? EngineInk(NSColor.systemOrange):foreground
            let extra=row.reset == nil ? 0.0:36.0
            let height=(row.quota == nil ? 40.0:56.0)+extra,rect=CGRect(x:0,y:0,width:viewport.width,height:height)
            var commands:[EngineDrawingCommand]=[
                .text(.init(id:row.id+".title",variants:[row.title,shortened(row.title,width:rect.width-12,size:12)],rect:CGRect(x:6,y:2,width:rect.width-12,height:17),font:.init(size:12),ink:color)),
                .text(.init(id:row.id+".value",variants:[row.facts,shortened(row.facts,width:rect.width-12,size:10)],rect:CGRect(x:6,y:20,width:rect.width-12,height:16),font:.init(size:10),ink:muted)),
                .polyline(points:[.init(x:6,y:height-1),.init(x:rect.maxX-6,y:height-1)],width:0.5,ink:EngineInk(NSColor.separatorColor))]
            if let reset=row.reset {
                commands.append(.text(.init(id:row.id+".reset.absolute",variants:[reset.absolute],rect:CGRect(x:6,y:38,width:rect.width-12,height:16),font:.init(size:10),ink:foreground)))
                commands.append(.text(.init(id:row.id+".reset.countdown",variants:[reset.countdown],rect:CGRect(x:6,y:56,width:rect.width-12,height:16),font:.init(size:10),ink:muted)))
            }
            if let quota=row.quota {
                let width=min(180,rect.width-12),segment=(width-27)/10
                for i in 0..<10 {
                    let bar=CGRect(x:6+Double(i)*(segment+3),y:42+extra,width:segment,height:8)
                    commands.append(.stroke(rect:bar,radius:0,width:0.5,ink:EngineInk(NSColor.separatorColor)))
                    if let lit=quota.segments,i<lit {commands.append(.fill(rect:bar,radius:0,ink:color))}
                }
            }
            return .init(height:height,commands:commands,region:.init(id:row.id,rect:rect,action:row.scopeTarget.map{.subscriptionScope($0)},
                label:row.title+"\n"+row.value,help:row.help,role:row.scopeTarget == nil ? .readout:.button,value:row.value,focusGroup:"subscription.rows"))
        }
        return .init(identity:display.identity,viewport:viewport,rows:rows)
    }
}
