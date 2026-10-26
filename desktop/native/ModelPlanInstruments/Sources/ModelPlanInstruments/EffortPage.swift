// SPDX-License-Identifier: MIT
import Foundation

public struct EffortPagePoint:Equatable,Sendable {
    public let key:String,label:String
    public let ability:Double?,cost:Double?,time:Double?
    public let qualifiers:[String]
}
public struct EffortPageModel:Equatable,Sendable {
    public let id:String,name:String,badge:String?,availability:String?
    public let points:[EffortPagePoint]
    public let current:EffortConfiguration?
    public let recommended:String?
}
/// Display projection of the ONE injected selection. No ranking/frontier solver or older-model policy is added.
public struct EffortPageSnapshot:Equatable,Sendable {
    public let scope:InstrumentScope,language:InstrumentLanguage
    public let publication:SelectionPublication?
    public let orderedIDs:[String]
    public private(set) var selectedModelID:String?
    public let exact:Bool,publicationUsable:Bool
    public let models:[EffortPageModel]
    public let notice:String?
    public let plotComparable:Bool
    public let sourceInfo:InstrumentPublicationSource?
    public init(models:[InstrumentModel],selection:InjectedModelSelection?,publication:SelectionPublication?,publicationUsable:Bool,
                scope:InstrumentScope,language:InstrumentLanguage,sourceInfo:InstrumentPublicationSource? = nil) {
        self.scope=scope;self.language=language;self.publication=publication;self.publicationUsable=publicationUsable;self.sourceInfo=sourceInfo
        let page=EffortPagePresentation(models:models,selection:selection,scope:scope,publication:publication,publicationUsable:publicationUsable,language:language)
        orderedIDs=page.orderedModelIDs;selectedModelID=page.selectedModelID
        let exact=publicationUsable && selection?.matchesExact(publication,scope:scope) == true
        self.exact=exact
        notice=page.selectionNotice ?? page.emptyStateNotice
        self.models=page.models.map { model in
            let unique=Set(model.efforts.map(\.key)).count==model.efforts.count
            let points=unique ? model.efforts.map { effort in
                EffortPagePoint(key:effort.key,label:effort.label,ability:publicationUsable ? effort.ability.value:nil,
                    cost:publicationUsable ? effort.cost.value:nil,time:publicationUsable ? effort.time.value:nil,
                    qualifiers:[effort.ability.qualifier,effort.cost.qualifier,effort.time.qualifier].compactMap{$0})
            }:[]
            return .init(id:model.id,name:model.name,badge:model.olderBadge(language),availability:page.modelAvailabilityNotes[model.id],points:points,
                current:exact ? model.current:nil,recommended:model.recommended)
        }
        let plotted=page.models.flatMap(\.efforts).filter{$0.ability.value != nil && $0.cost.value != nil}
        plotComparable=publicationUsable && !plotted.isEmpty && plotted.allSatisfy{$0.ability.basis != nil && $0.cost.basis != nil}
            && Set(plotted.compactMap{$0.ability.basis}).count==1 && Set(plotted.compactMap{$0.cost.basis}).count==1
    }
    var valid:Bool {
        models.count<=128 && Set(models.map(\.id)).count==models.count && models.allSatisfy {
            !$0.id.isEmpty && $0.id.utf8.count<=256 && $0.name.utf8.count<=4096 && $0.points.count<=64
                && $0.points.allSatisfy{!$0.key.isEmpty && $0.key.utf8.count<=256 && $0.label.utf8.count<=4096 && $0.qualifiers.joined().utf8.count<=4096}
        }
    }
    func matches(_ selection:InjectedModelSelection?,publication:SelectionPublication?,usable:Bool)->Bool {
        guard self.publication==publication,self.publicationUsable==usable else{return false}
        if models.isEmpty {return true}
        guard let selection else{return orderedIDs.isEmpty}
        return selection.matches(publication,scope:scope) && orderedIDs==selection.orderedModelIDs && selectedModelID==selection.selectedModelID
    }
    func selecting(_ id:String?)->Self {
        var value=self
        if let id,models.contains(where:{$0.id==id}) {value.selectedModelID=id}
        return value
    }
    public var links:[InstrumentWebsiteLink] {
        guard let id=selectedModelID ?? models.first?.id else{return []}
        return [.compare(publicModelID:id,language:language),.methodology(comparison:false,language:language)]
    }
    public func pageContent()->MainScreenPageContent {.init(.effort,options:[nil,nil,nil],effort:self)}
}
