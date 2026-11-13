// SPDX-License-Identifier: MIT
import Foundation

public struct SubscriptionCycleBar:Equatable,Sendable {
    public let segment:SubscriptionHistorySegment?
    public let rect:CGRect
    public let points:Double
}
/// Uses reported cycle/segment percentages only; absent parts never acquire fabricated height or provenance.
public struct SubscriptionCycleGeometry:Equatable,Sendable {
    public let plot:CGRect
    public let bars:[SubscriptionCycleBar]
    public init?(cycle:SubscriptionCycleDisplay,plot:CGRect,maximum:Double) {
        guard [plot.minX,plot.minY,plot.maxX,plot.maxY,plot.width,plot.height,maximum].allSatisfy(\.isFinite),
              plot.width>0,plot.height>0,maximum>=100 else{return nil}
        self.plot=plot
        var bars:[SubscriptionCycleBar]=[],x=plot.minX
        if cycle.segments.isEmpty,let used=cycle.used,used>0 {
            guard used<=maximum else{return nil}
            bars.append(.init(segment:nil,rect:CGRect(x:x,y:plot.minY,width:used/maximum*plot.width,height:plot.height),points:used))
        } else {
            for segment in cycle.segments {
                guard let points=segment.points,points>0 else{continue}
                let width=points/maximum*plot.width
                guard width.isFinite,width>0,x+width<=plot.maxX+0.001 else{return nil}
                bars.append(.init(segment:segment,rect:CGRect(x:x,y:plot.minY,width:width,height:plot.height),points:points));x+=width
            }
        }
        self.bars=bars
    }
}
