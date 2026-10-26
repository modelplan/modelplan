// SPDX-License-Identifier: MIT
import Foundation

public enum HelpUILayout {
    public typealias Measure = (String, CGFloat, HelpUITextRole) -> CGSize
    public static func make(_ input: HelpUIRenderInput, measure: Measure) -> HelpUIPresentation {
        func empty(_ unresolved:[String]=[])->HelpUIPresentation { .init(sessionID:input.sessionID,unresolvedMapIDs:unresolved) }
        let bounds=CGRect(origin:.zero,size:input.viewport),safe=HelpUIGeometry.safe(input.viewport)
        guard input.active else { return empty() }
        guard HelpUIGeometry.valid(safe),input.viewport.width<=16_384,input.viewport.height<=16_384,
              input.anchors.count<=64,input.liveReadings.count<=64,
              Set(input.anchors.map(\.id)).count==input.anchors.count,
              input.anchors.allSatisfy({!$0.id.isEmpty && $0.id.utf8.count<=256 && (!$0.visible || HelpUIGeometry.valid($0.rect))}),
              input.liveReadings.allSatisfy(HelpUIGeometry.valid) else { return empty(["invalidInput"]) }
        let anchors=Dictionary(uniqueKeysWithValues:input.anchors.filter { $0.visible && HelpUIGeometry.intersects($0.rect,bounds) }.map { ($0.id,$0.rect) })
        if input.map.mode != .hidden { return map(input,anchors:anchors,measure:measure) }
        let width=min(370,safe.width)
        let identity:HelpUICardIdentity,anchorID:String,height:CGFloat
        if let hint=input.firstUse {
            guard !hint.text.isEmpty,hint.text.utf8.count<=4096,!hint.dismissTitle.isEmpty,hint.dismissTitle.utf8.count<=256 else { return empty() }
            identity = .firstUse(hint.offerID);anchorID=hint.anchorID
            height=ceil(measure(hint.text,width-22,.hintBody).height)+ceil(measure(hint.dismissTitle,width-22,.button).height)+27
        } else if let context=input.contextual {
            guard !context.id.isEmpty,context.id.utf8.count<=256,!context.explanation.title.isEmpty,!context.explanation.body.isEmpty,
                  (context.actionID?.utf8.count ?? 0)<=256,(context.actionTitle?.utf8.count ?? 0)<=512,
                  context.explanation.title.utf8.count<=512,context.explanation.body.utf8.count<=8192 else { return empty() }
            identity = .context(context.id);anchorID=context.anchorID
            height=ceil(measure(context.explanation.title,width-22,.contextTitle).height)
                + ceil(measure(context.explanation.body,width-22,.contextBody).height)+23
                + ((context.actionID != nil && context.actionTitle != nil) ? 26:0)
        } else { return empty() }
        guard let anchor=anchors[anchorID],let frame=HelpUIGeometry.placeCard(anchor:anchor,size:.init(width:width,height:max(48,height)),
            viewport:input.viewport,blocked:input.liveReadings) else { return empty() }
        return .init(sessionID:input.sessionID,card:.init(identity:identity,anchorID:anchorID,frame:frame))
    }

    private static func map(_ input:HelpUIRenderInput,anchors:[String:CGRect],measure:Measure)->HelpUIPresentation {
        struct Item { let id:String,text:String,anchorID:String,anchor:CGRect }
        let catalog=HelpMapCatalog(input.language),safe=HelpUIGeometry.safe(input.viewport)
        var items=[Item](),unresolved=[String]()
        for entry in catalog.entries(for:input.map.surface) {
            guard let id=input.map.regionAnchors[entry.region],let anchor=anchors[id] else { continue }
            if entry.region == .pin && input.map.sentenceOverrides[.pin] == nil {
                unresolved.append(entry.id);continue // The historical Pin text is not the approved Detach/Put back.
            }
            let text=input.map.sentenceOverrides[entry.region] ?? entry.sentence
            guard !text.isEmpty,text.utf8.count<=4096 else { unresolved.append(entry.id);continue }
            items.append(.init(id:entry.id,text:text,anchorID:id,anchor:anchor))
        }
        if let id=input.map.todayAverageAnchorID,let anchor=anchors[id] {
            items.append(.init(id:"map.todayAverage",text:InstrumentHelpDefinitions.todayAverage(input.language),anchorID:id,anchor:anchor))
        }
        if let id=input.map.liveSpeedAnchorID,let anchor=anchors[id] {
            items.append(.init(id:"map.liveSpeed",text:InstrumentHelpDefinitions.liveSpeed(input.language),anchorID:id,anchor:anchor))
        }
        guard input.map.supplements.count<=16 else { return .init(sessionID:input.sessionID,unresolvedMapIDs:["invalidInput"]) }
        for note in input.map.supplements {
            guard let anchor=anchors[note.anchorID] else { continue }
            guard !note.id.isEmpty,note.id.utf8.count<=256,!note.text.isEmpty,note.text.utf8.count<=4096,
                  !items.contains(where:{$0.id==note.id}) else { return .init(sessionID:input.sessionID,unresolvedMapIDs:["invalidInput"]) }
            items.append(.init(id:note.id,text:note.text,anchorID:note.anchorID,anchor:anchor))
        }
        items.sort { $0.anchor.midY == $1.anchor.midY ? $0.id < $1.id:$0.anchor.midY < $1.anchor.midY }
        let header=input.map.header,headerText=catalog.metaphor+"\n"+catalog.dismissal
        guard !items.isEmpty,HelpUIGeometry.valid(header),safe.contains(header),
              HelpUIGeometry.free(header,from:input.liveReadings),
              measure(headerText,max(1,header.width-16),.header).height+10<=header.height else {
            return .init(sessionID:input.sessionID,unresolvedMapIDs:Array(Set(unresolved+items.map(\.id))).sorted())
        }
        let columns=input.map.columns
        let validColumns = !columns.isEmpty && columns.count<=4 && columns.allSatisfy { HelpUIGeometry.valid($0) && safe.contains($0) }
        var cursors=columns.map(\.minY),placed=[(Item,CGRect)]()
        let gap:CGFloat=input.profile == .tall890 ? 12:6
        for (index,item) in items.enumerated() {
            let frame:CGRect?
            if let frames=input.map.captionFrames {
                frame=frames[item.id]
            } else if validColumns {
                let perColumn=max(1,Int(ceil(Double(items.count)/Double(columns.count))))
                let preferred=min(columns.count-1,index/perColumn)
                var result:CGRect?
                for column in [preferred]+columns.indices.filter({$0 != preferred}) {
                    let width=columns[column].width
                    let height=ceil(measure(item.text,max(1,width-16),.caption).height)+10
                    let candidate=CGRect(x:columns[column].minX,y:cursors[column],width:width,height:height)
                    if columns[column].contains(candidate),HelpUIGeometry.free(candidate,from:input.liveReadings+[header]+placed.map(\.1)) {
                        result=candidate;cursors[column]=candidate.maxY+gap;break
                    }
                }
                frame=result
            } else { frame=nil }
            guard let frame,HelpUIGeometry.valid(frame),safe.contains(frame),
                  measure(item.text,max(1,frame.width-16),.caption).height+10<=frame.height,
                  HelpUIGeometry.free(frame,from:input.liveReadings+[header]+placed.map(\.1)) else { unresolved.append(item.id);continue }
            placed.append((item,frame))
        }
        var sourceFrame:CGRect?
        if input.map.sourceActionID != nil || input.map.sourceActionTitle != nil {
            if let frame=input.map.sourceFrame,let title=input.map.sourceActionTitle,!title.isEmpty,title.utf8.count<=512,
               let id=input.map.sourceActionID,!id.isEmpty,id.utf8.count<=256,HelpUIGeometry.valid(frame),safe.contains(frame),
               HelpUIGeometry.free(frame,from:input.liveReadings+[header]+placed.map(\.1)),
               measure(title,frame.width,.button).height<=frame.height { sourceFrame=frame }
            else { unresolved.append("map.source") }
        }
        let blocks=input.liveReadings+[header]+placed.map(\.1)+(sourceFrame.map { [$0] } ?? [])
        let labels=placed.map { item,frame -> HelpUIMapLabel in
            let starts=[CGPoint(x:frame.maxX+4,y:frame.midY),.init(x:frame.minX-4,y:frame.midY)]
            let ends=[CGPoint(x:item.anchor.minX-4,y:item.anchor.midY),.init(x:item.anchor.maxX+4,y:item.anchor.midY),
                      .init(x:item.anchor.midX,y:item.anchor.minY-4),.init(x:item.anchor.midX,y:item.anchor.maxY+4)]
            var leader=[CGPoint]()
            for start in starts where leader.isEmpty {
                for end in ends.sorted(by:{hypot($0.x-start.x,$0.y-start.y)<hypot($1.x-start.x,$1.y-start.y)}) where leader.isEmpty {
                    leader=HelpUIGeometry.leader(from:start,to:end,avoiding:blocks,viewport:input.viewport)
                }
            }
            if leader.isEmpty { unresolved.append(item.id) }
            return .init(id:item.id,text:item.text,anchorID:item.anchorID,frame:frame,leader:leader)
        }
        return .init(sessionID:input.sessionID,mapHeader:labels.isEmpty ? nil:header,mapLabels:labels,mapSourceFrame:labels.isEmpty ? nil:sourceFrame,
                     unresolvedMapIDs:Array(Set(unresolved)).sorted())
    }
}
