// SPDX-License-Identifier: MIT
import AppKit
import QuartzCore

public struct DockNozzleVisual {
    public let id:String,image:CGImage,frame:CGRect,anchor:CGPoint
}
public struct DockReorderVisuals {
    public let base:CGImage,items:[DockNozzleVisual],bounds:CGRect,scale:Int
}
extension DockInstrumentRenderer {
    /// Registered static parts, excluding every animated effect. No official coordinates/colors are defined here.
    public func reorderVisuals(skin:DockInstrumentSkin,readings:[String:DockInstrumentReading],notices:[String:DockNotice]=[:],scale:Int)throws->DockReorderVisuals{
        var backing=skin;backing.stations=[]
        let base=try render(skin:backing,readings:[:],scale:scale).image
        var items=[DockNozzleVisual]()
        for station in skin.stations{
            guard let id=station.subscriptionID else{continue}
            let radius=max(station.diameter/2,station.clock.radius+station.clock.dotRadius+station.clock.backWidth/2)
            var box=CGRect(x:station.centre.x-radius,y:station.centre.y-radius,width:radius*2,height:radius*2).union(station.glyphRect)
            if station.showsReadout != false{box=box.union(station.readout)}
            if let alias=station.aliasRect{box=box.union(alias)}
            if notices[id] != nil{box=box.union(station.eventRect)}
            // Preserve fractional registration at the selected native sampling density.
            box=CGRect(x:floor(box.minX*CGFloat(scale))/CGFloat(scale),y:floor(box.minY*CGFloat(scale))/CGFloat(scale),width:ceil(box.maxX*CGFloat(scale))/CGFloat(scale)-floor(box.minX*CGFloat(scale))/CGFloat(scale),height:ceil(box.maxY*CGFloat(scale))/CGFloat(scale)-floor(box.minY*CGFloat(scale))/CGFloat(scale))
            var part=skin;part.bounds=box;part.bodyPolygon=[];part.fixedLayers=[];part.stations=[station]
            let image=try render(skin:part,readings:readings,notices:notices,scale:scale).image
            items.append(.init(id:id,image:image,frame:box.offsetBy(dx:-skin.bounds.minX,dy:-skin.bounds.minY),anchor:CGPoint(x:station.centre.x-skin.bounds.minX,y:station.centre.y-skin.bounds.minY)))
        }
        return .init(base:base,items:items,bounds:skin.bounds,scale:scale)
    }
}
/// Passive composition overlay; input still belongs to the original validated instrument view.
@MainActor public final class DockReorderLayersView:NSView {
    public private(set) var retainedBytes=0
    private var base:CGImage?,images=[String:CALayer](),anchors=[String:CGPoint]()
    public override var isFlipped:Bool{true}
    public override init(frame:NSRect){super.init(frame:frame);wantsLayer=true;layer?.isGeometryFlipped=true;setAccessibilityElement(false)}
    required init?(coder:NSCoder){fatalError()}
    public override func hitTest(_ point:NSPoint)->NSView?{nil}
    public func apply(_ value:DockReorderVisuals,draggedID:String?,reducedMotion:Bool,auxiliaryLayers:[String:CALayer]=[:])throws{
        let bytes=value.base.bytesPerRow*value.base.height+value.items.reduce(0){$0+$1.image.bytesPerRow*$1.image.height}
        guard (1...2).contains(value.scale),bytes<=16*1024*1024,Set(value.items.map(\.id)).count==value.items.count else{throw DockArtworkError.decodedBudget}
        CATransaction.begin();CATransaction.setDisableActions(true);defer{CATransaction.commit()}
        let ids=Set(value.items.map(\.id))
        for id in Array(images.keys) where !ids.contains(id){images[id]?.removeFromSuperlayer();images.removeValue(forKey:id);anchors.removeValue(forKey:id)}
        for item in value.items{
            let image=images[item.id] ?? CALayer(),old=anchors[item.id]
            let oldPosition=image.presentation()?.position ?? image.position
            image.contents=item.image;image.contentsScale=CGFloat(value.scale);image.frame=item.frame
            image.removeAnimation(forKey:"dock-neighbour-yield")
            if old != nil,!reducedMotion,item.id != draggedID{
                let animation=CABasicAnimation(keyPath:"position");animation.fromValue=NSValue(point:oldPosition);animation.toValue=NSValue(point:image.position);animation.duration=0.150;animation.timingFunction=CAMediaTimingFunction(name:.easeOut);image.add(animation,forKey:"dock-neighbour-yield")
            }
            if image.superlayer==nil{layer?.addSublayer(image)};images[item.id]=image
            if let auxiliary=auxiliaryLayers[item.id],let old{
                auxiliary.removeAnimation(forKey:"dock-neighbour-yield")
                if !reducedMotion,item.id != draggedID{
                    let animation=CABasicAnimation(keyPath:"position");animation.fromValue=NSValue(point:CGPoint(x:auxiliary.position.x-(item.anchor.x-old.x),y:auxiliary.position.y-(item.anchor.y-old.y)));animation.toValue=NSValue(point:auxiliary.position);animation.duration=0.150;animation.timingFunction=CAMediaTimingFunction(name:.easeOut);auxiliary.add(animation,forKey:"dock-neighbour-yield")
                }
            }
            anchors[item.id]=item.anchor
        }
        base=value.base;retainedBytes=bytes;frame.size=value.bounds.size;needsDisplay=true
    }
    public override func draw(_ dirtyRect:NSRect){if let base{NSImage(cgImage:base,size:bounds.size).draw(in:bounds,from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:nil)}}
    public var animatingIDs:Set<String>{Set(images.filter{$0.value.animation(forKey:"dock-neighbour-yield") != nil}.map(\.key))}
    public func dispose(){images.values.forEach{$0.removeAllAnimations();$0.removeFromSuperlayer()};images=[:];anchors=[:];base=nil;retainedBytes=0}
}
