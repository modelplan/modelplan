// SPDX-License-Identifier: MIT
import AppKit

@MainActor enum NeutralEffortPageRecipe {
    static func make(_ p:EffortPageSnapshot,in area:CGRect)->(commands:[EngineDrawingCommand],regions:[MainScreenHitRegion],list:MainScreenListRecipe?) {
        let fg=EngineInk(NSColor.labelColor),muted=EngineInk(NSColor.secondaryLabelColor),rule=EngineInk(NSColor.separatorColor),gold=EngineInk(NSColor.systemYellow)
        let zh=p.language == .chinese
        func help(_ model:EffortPageModel,_ point:EffortPagePoint)->HelpExplanation {
            let value=[model.name,model.badge,model.availability,point.label,(zh ? "能力 ":"Ability ")+SubscriptionNowSnapshot.number(point.ability),
                (zh ? "成本 ":"Cost ")+SubscriptionNowSnapshot.number(point.cost),(zh ? "耗时 ":"Time ")+SubscriptionNowSnapshot.number(point.time)]
                .compactMap{$0}.joined(separator:" · ")+" · "+point.qualifiers.joined(separator:" · ")
            return HelpCatalog(p.language).explanation(.effort,context:.init(fact:value))
        }
        guard p.plotComparable else {
            let rows=p.models.flatMap { model in model.points.map { point in
                let h=help(model,point)
                return MainScreenListRowRecipe(height:40,commands:[.text(.init(id:"effort."+model.id+"."+point.key+".text",variants:[model.name+" · "+point.label,"…"],rect:CGRect(x:6,y:4,width:area.width-12,height:30),font:.init(size:11),ink:fg))],
                    region:.init(id:"effort."+model.id+"."+point.key,rect:CGRect(x:0,y:0,width:area.width,height:40),action:p.exact ? .inspectEffort(modelID:model.id,key:point.key):nil,
                        label:h.body,help:h,role:p.exact ? .button:.readout,focusGroup:"effort.rows"))
            }}
            let fallback=rows.isEmpty ? [MainScreenListRowRecipe(height:40,commands:[.text(.init(id:"effort.empty",variants:[p.notice ?? (zh ? "暂无可显示的公开模型数据":"No public model data is available to display.")],rect:CGRect(x:6,y:4,width:area.width-12,height:30),font:.init(size:11),ink:muted))],region:.init(id:"effort.empty",rect:CGRect(x:0,y:0,width:area.width,height:40),label:p.notice ?? "--",help:HelpCatalog(p.language).explanation(.effort),role:.readout))]:rows
            let gutter=links(p,in:area)
            let viewport=CGRect(x:area.minX,y:area.minY,width:area.width,height:max(20,area.height-16))
            return (gutter.0,gutter.1,.init(identity:"effort.catalog",viewport:viewport,rows:fallback))
        }
        let plot=CGRect(x:area.minX+38,y:area.minY+6,width:area.width-106,height:area.height-32)
        let points=p.models.flatMap(\.points),maxCost=max(1,points.compactMap(\.cost).max() ?? 1),maxAbility=max(1,points.compactMap(\.ability).max() ?? 1)
        var commands:[EngineDrawingCommand]=[],regions:[MainScreenHitRegion]=[]
        func text(_ id:String,_ title:String,_ r:CGRect,_ ink:EngineInk=muted) {commands.append(.text(.init(id:id,variants:[title],rect:r,font:.init(size:10),ink:ink)))}
        commands.append(.polyline(points:[.init(x:plot.minX,y:plot.minY),.init(x:plot.minX,y:plot.maxY),.init(x:plot.maxX,y:plot.maxY)],width:1,ink:rule))
        text("effort.axis.ability",zh ? "能力":"Ability",CGRect(x:area.minX,y:plot.minY,width:36,height:14))
        text("effort.axis.cost",zh ? "成本":"Cost",CGRect(x:plot.maxX+6,y:plot.maxY-12,width:60,height:14))
        for (index,model) in p.models.enumerated() {
            let opacity=[1.0,0.8,0.6,0.4][index%4],ink=EngineInk(fg.red,fg.green,fg.blue,opacity)
            var segment:[CGPoint]=[]
            for point in model.points {
                guard let cost=point.cost,let ability=point.ability else {
                    if segment.count>1 {commands.append(.polyline(points:segment,width:1,ink:ink))};segment=[];continue
                }
                let pos=CGPoint(x:plot.minX+cost/maxCost*plot.width,y:plot.maxY-ability/maxAbility*plot.height)
                segment.append(pos)
                let star=model.recommended==point.key,current=model.current?.effort==point.key
                commands.append(.ellipse(rect:CGRect(x:pos.x-2,y:pos.y-2,width:4,height:4),ink:ink))
                if star {commands.append(.stroke(rect:CGRect(x:pos.x-4,y:pos.y-4,width:8,height:8),radius:4,width:1,ink:gold))}
                if current {commands.append(.stroke(rect:CGRect(x:pos.x-5,y:pos.y-5,width:10,height:10),radius:0,width:1,ink:fg))}
                let rect=CGRect(x:max(area.minX,min(area.maxX-20,pos.x-10)),y:max(area.minY,min(area.maxY-20,pos.y-10)),width:20,height:20),h=help(model,point)
                regions.append(.init(id:"effort."+model.id+"."+point.key,rect:rect,action:p.exact ? .inspectEffort(modelID:model.id,key:point.key):nil,
                    label:h.body,help:h,role:p.exact ? .button:.readout,value:point.label))
            }
            if segment.count>1 {commands.append(.polyline(points:segment,width:1,ink:ink))}
            if let end=segment.last {text("effort.name."+model.id,String(model.name.prefix(9))+(model.badge.map{" · "+$0} ?? ""),CGRect(x:plot.maxX+4,y:max(area.minY,min(plot.maxY-14,end.y-7)),width:62,height:14),ink)}
        }
        let gutter=links(p,in:area);commands+=gutter.0;regions+=gutter.1
        return (commands,regions,nil)
    }
    private static func links(_ p:EffortPageSnapshot,in area:CGRect)->([EngineDrawingCommand],[MainScreenHitRegion]) {
        var commands:[EngineDrawingCommand]=[],regions:[MainScreenHitRegion]=[],x=area.minX
        for (i,link) in p.links.enumerated() {
            let w=min((area.width-8)/2,Double(link.title.count)*6+4),rect=CGRect(x:x,y:area.maxY-14,width:w,height:14)
            commands.append(.text(.init(id:"effort.link.\(i)",variants:[link.title],rect:rect,font:.init(size:10),ink:EngineInk(NSColor.secondaryLabelColor))))
            regions.append(.init(id:"effort.link.\(i)",rect:rect,action:.website(link),label:link.title,help:HelpCatalog(p.language).explanation(.link,context:.init(fact:link.title))))
            x+=w+8
        }
        return (commands,regions)
    }

}
