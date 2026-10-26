// SPDX-License-Identifier: MIT
import Foundation

public struct DockReorderTarget:Equatable,Sendable {
    public let id:String,along:Double
    public init(id:String,along:Double){self.id=id;self.along=along}
}
public struct DockOrderRequest:Sendable {
    public let id:UUID,catalogue:[String],expected:DockSubscriptionPreferences,proposed:DockSubscriptionPreferences
    public let movedID:String,position:Int
}
public enum DockNozzleRelease:Sendable {case none,click(String),order(DockOrderRequest)}
public struct DockReorderPreview:Equatable,Sendable {
    public let source:String,order:[String],along:Double
    public let neighbourYieldSeconds:Double
}
/// Preview from the canonical order reducer. No preference file, account command or independent order store.
public struct DockNozzleInteraction:Sendable {
    public private(set) var preview:DockReorderPreview?
    public private(set) var source:String?
    public private(set) var overflowHelpNeeded=false
    private var start=0.0,overflow=false,moved=false
    private var catalogue=[String](),targets=[DockReorderTarget](),expected=DockSubscriptionPreferences()
    private var session:DockReorderSession?
    public init(){}
    public mutating func begin(id:String,along:Double,overflow:Bool,targets:[DockReorderTarget],catalogue:[String],preferences:DockSubscriptionPreferences)throws{
        cancel()
        guard along.isFinite,targets.allSatisfy({$0.along.isFinite}),Set(targets.map(\.id)).count==targets.count else{throw DockEdgeError.invalidGeometry}
        guard catalogue.contains(id),overflow || targets.contains(where:{$0.id==id}) else{throw DockLogicError.missingSubscription}
        let next=try preferences.beginReorder(id,in:catalogue)
        self.catalogue=catalogue;expected=preferences;self.targets=targets;self.source=id;start=along;self.overflow=overflow;session=next
    }
    public mutating func move(along:Double,reducedMotion:Bool,canPreview:([String])->Bool = {_ in true})throws{
        guard let source,along.isFinite else{return}
        guard moved || abs(along-start)>5 else{return};moved=true
        if overflow{overflowHelpNeeded=true;return}
        guard let target=targets.min(by:{abs($0.along-along)<abs($1.along-along)}) else{return}
        var next=session!;try next.hover(over:target.id)
        guard canPreview(next.preview) else{return}
        session=next;preview = .init(source:source,order:next.preview,along:max(targets.map(\.along).min()!,min(targets.map(\.along).max()!,along)),neighbourYieldSeconds:reducedMotion ? 0:0.150)
    }
    public mutating func release(insideMain:Bool,overSameSource:Bool,catalogue:[String],preferences:DockSubscriptionPreferences)throws->DockNozzleRelease{
        guard let source else{return .none}
        defer{cancel()}
        guard catalogue==self.catalogue,preferences==expected else{throw DockLogicError.staleReorder}
        if !moved{return overSameSource ? .click(source):.none}
        guard !overflow,insideMain,let preview,preview.order != (try preferences.orderedIDs(in:catalogue)) else{return .none}
        var proposal=preferences;try session!.commit(into:&proposal,catalogue:catalogue)
        let position=try proposal.orderedIDs(in:catalogue).firstIndex(of:source)!
        return .order(.init(id:UUID(),catalogue:catalogue,expected:preferences,proposed:proposal,movedID:source,position:position))
    }
    public func matches(catalogue:[String],preferences:DockSubscriptionPreferences)->Bool{
        source==nil || (self.catalogue==catalogue && expected==preferences)
    }
    public mutating func cancel(){session?.cancel();session=nil;source=nil;preview=nil;overflowHelpNeeded=false;moved=false;targets=[]}
    public static func keyboardMove(id:String,delta:Int,catalogue:[String],preferences:DockSubscriptionPreferences)throws->DockOrderRequest?{
        guard delta == -1 || delta == 1 else{throw DockLogicError.staleReorder}
        let order=try preferences.orderedIDs(in:catalogue);guard let i=order.firstIndex(of:id) else{throw DockLogicError.missingSubscription}
        let target=max(0,min(order.count-1,i+delta));guard i != target else{return nil}
        var proposal=preferences;try proposal.move(id,to:target,in:catalogue)
        return .init(id:UUID(),catalogue:catalogue,expected:preferences,proposed:proposal,movedID:id,position:target)
    }
}
