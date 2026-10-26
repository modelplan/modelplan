// SPDX-License-Identifier: MIT
import Foundation

public struct DockCardRow:Equatable,Sendable {
    public enum Kind:Equatable,Sendable {case quota,extraQuota,reserve,statistic,notice}
    public let id:String,kind:Kind,label:String,value:String,detail:String
    public let remainingFraction:Double?,tone:DockQuotaStatus
    public init(id:String,kind:Kind,label:String,value:String,detail:String="",remainingFraction:Double?=nil,tone:DockQuotaStatus = .unknown){
        self.id=id;self.kind=kind;self.label=label;self.value=value;self.detail=detail;self.remainingFraction=remainingFraction;self.tone=tone
    }
}
public struct DockCardLink:Equatable,Sendable {
    public let label:String,url:URL
    public init(label:String,url:URL){self.label=label;self.url=url}
    public var allowed:Bool{url.scheme?.lowercased()=="https" && !(url.host ?? "").isEmpty && url.user==nil && url.password==nil}
}
/// Already validated, scoped and localized facts from the app's data projection. No fallback/scoring/TTL inference.
public struct DockCardContent:Equatable,Sendable {
    public let subscriptionID:String,revision:UInt64,name:String,plan:String,sourceAndAge:String,stateLabel:String
    public let rows:[DockCardRow],links:[DockCardLink],enterLabel:String,dismissLabel:String
    public init(subscriptionID:String,revision:UInt64=0,name:String,plan:String="",sourceAndAge:String="",stateLabel:String="",rows:[DockCardRow],links:[DockCardLink]=[],enterLabel:String="Open",dismissLabel:String="Close"){
        self.subscriptionID=subscriptionID;self.revision=revision;self.name=name;self.plan=plan;self.sourceAndAge=sourceAndAge;self.stateLabel=stateLabel
        self.rows=rows;self.links=links;self.enterLabel=enterLabel;self.dismissLabel=dismissLabel
    }
    public func validate()throws{
        let strings=[subscriptionID,name,plan,sourceAndAge,stateLabel,enterLabel,dismissLabel]+rows.flatMap{[$0.id,$0.label,$0.value,$0.detail]}+links.map(\.label)
        guard !subscriptionID.isEmpty,rows.count<=64,links.count<=8,Set(rows.map(\.id)).count==rows.count,!rows.contains(where:{$0.id.isEmpty}),strings.allSatisfy({$0.utf8.count<=2048}),links.allSatisfy(\.allowed),rows.allSatisfy({r in r.remainingFraction.map{$0.isFinite && (0...1).contains($0)} ?? true}) else{throw DockLogicError.invalidCatalogue}
    }
}
