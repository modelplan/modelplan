// SPDX-License-Identifier: MIT
import AppKit
import CoreGraphics

/// A small painted surface, not the physical wake target. Appearance pixels are externally supplied.
@MainActor public final class DockSliverView:NSView {
    public var onReveal:(()->Void)?{didSet{setAccessibilityEnabled(!failed && onReveal != nil)}}
    public var onNeedsFreshPresentation:(()->Void)?
    public private(set) var retainedBytes=0
    private var image:CGImage?,alpha=[UInt8](),scale=1,failed=true
    private var suppliedEdge:DockEdge?
    public override var isFlipped:Bool{true}
    public override var acceptsFirstResponder:Bool{false}
    public override init(frame:NSRect){super.init(frame:frame);setAccessibilityElement(false);setAccessibilityRole(.button);setAccessibilityEnabled(false)}
    required init?(coder:NSCoder){fatalError("init(coder:) is unsupported")}
    public func apply(image:CGImage?,logicalSize:CGSize,scale:Int,accessibilityLabel:String,edge:DockEdge?=nil)throws{
        self.image=nil;alpha=[];retainedBytes=0;failed=true;setAccessibilityElement(false);setAccessibilityLabel(nil);setAccessibilityEnabled(false);needsDisplay=true
        guard (1...2).contains(scale),logicalSize.width.isFinite,logicalSize.height.isFinite,
            logicalSize.width>0,logicalSize.height>0,logicalSize.width<=4096,logicalSize.height<=4096 else{throw DockArtworkError.invalidManifest}
        let w=Int(ceil(logicalSize.width*CGFloat(scale))),h=Int(ceil(logicalSize.height*CGFloat(scale)))
        guard w*h<=800_000 else{throw DockArtworkError.decodedBudget}
        if let image{
            let vertical = h > w
            guard vertical ? image.width >= w : image.height >= h else { throw DockArtworkError.invalidManifest }
            guard let c=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Big.rawValue|CGImageAlphaInfo.premultipliedLast.rawValue) else{throw DockArtworkError.invalidManifest}
            c.interpolationQuality = .high
            // A legacy supplier may still emit a short strip. Keep its authored end rounding
            // at the cross-axis scale; stretch only the middle instead of magnifying the caps.
            let sourceAlong = vertical ? image.height : image.width
            let sourceCross = vertical ? image.width : image.height
            let targetAlong = vertical ? h : w, targetCross = vertical ? w : h
            if targetAlong > 2 * targetCross, sourceAlong > 2 * sourceCross {
                let cap = sourceCross, targetCap = CGFloat(targetCross)
                for (start, length, targetStart, targetLength) in [
                    (0, cap, CGFloat(0), targetCap),
                    (cap, sourceAlong - 2 * cap, targetCap, CGFloat(targetAlong) - 2 * targetCap),
                    (sourceAlong - cap, cap, CGFloat(targetAlong) - targetCap, targetCap)
                ] {
                    let source = vertical ? CGRect(x: 0, y: start, width: sourceCross, height: length)
                                          : CGRect(x: start, y: 0, width: length, height: sourceCross)
                    // CGImage cropping starts at its top row; CGContext destinations use bottom-up Y.
                    let target = vertical ? CGRect(x: 0, y: CGFloat(h) - targetStart - targetLength, width: CGFloat(targetCross), height: targetLength)
                                          : CGRect(x: targetStart, y: 0, width: targetLength, height: CGFloat(targetCross))
                    guard let piece = image.cropping(to: source) else { throw DockArtworkError.invalidManifest }
                    c.draw(piece, in: target)
                }
            } else { c.draw(image,in:CGRect(x:0,y:0,width:w,height:h)) }
            guard let normalized=c.makeImage(),let bytes=c.data else{throw DockArtworkError.invalidManifest}
            let p=bytes.assumingMemoryBound(to:UInt8.self);alpha=(0..<(w*h)).map{p[$0*4+3]};self.image=normalized
            retainedBytes=normalized.bytesPerRow*normalized.height+alpha.count
        }
        self.scale=scale;suppliedEdge=edge;frame.size=logicalSize;failed=false;setAccessibilityElement(true);setAccessibilityEnabled(onReveal != nil);setAccessibilityLabel(accessibilityLabel)
    }
    public func isPainted(atLocal point:CGPoint)->Bool{
        guard !failed,!isHiddenOrHasHiddenAncestor,bounds.contains(point),point.x.isFinite,point.y.isFinite else{return false}
        guard let image else{return true}
        let x=min(image.width-1,max(0,Int(point.x*CGFloat(scale)))),y=min(image.height-1,max(0,Int(point.y*CGFloat(scale))))
        return alpha[y*image.width+x]>0
    }
    public override func hitTest(_ point:NSPoint)->NSView?{onReveal != nil && isPainted(atLocal:convert(point,from:superview)) ? self:nil}
    public override func viewDidMoveToWindow(){super.viewDidMoveToWindow();if window != nil{onNeedsFreshPresentation?()}}
    public override func viewDidChangeBackingProperties(){super.viewDidChangeBackingProperties();onNeedsFreshPresentation?()}
    public override func viewDidChangeEffectiveAppearance(){super.viewDidChangeEffectiveAppearance();onNeedsFreshPresentation?()}
    public override func draw(_ dirtyRect:NSRect){
        guard !failed else{return}
        NSGraphicsContext.saveGraphicsState();defer{NSGraphicsContext.restoreGraphicsState()}
        guard let graphics=NSGraphicsContext.current else{return}
        graphics.imageInterpolation = .high
        graphics.cgContext.setShouldAntialias(true)
        if let image{NSImage(cgImage:image,size:bounds.size).draw(in:bounds,from:.zero,operation:.copy,fraction:1,respectFlipped:true,hints:nil)}
        else{drawNeutralMetal(in:graphics.cgContext)}
    }
    /// Only the neutral fallback is drawn here; supplied artwork and semantic segments stay intact.
    private func drawNeutralMetal(in c:CGContext){
        let edge:DockEdge
        if let suppliedEdge{edge=suppliedEdge}
        else if bounds.width>bounds.height{edge = .bottom}
        else if let frame=window?.frame,let screen=window?.screen?.visibleFrame{
            edge=abs(frame.minX-screen.minX)<abs(frame.maxX-screen.maxX) ? .left:.right
        }else{edge = .right}
        // Owner-approved public neutral tokens: metal-solid-1 #2a2b2e, metal-3 #141517.
        func color(_ r:CGFloat,_ g:CGFloat,_ b:CGFloat,_ a:CGFloat=1)->CGColor{
            CGColor(colorSpace:CGColorSpace(name:CGColorSpace.sRGB)!,components:[r/255,g/255,b/255,a])!
        }
        let r=min(2,min(bounds.width,bounds.height)),path=CGMutablePath(),b=bounds
        let topLeft=edge == .right || edge == .bottom,topRight=edge == .left || edge == .bottom
        let bottomRight=edge == .left || edge == .top,bottomLeft=edge == .right || edge == .top
        path.move(to:CGPoint(x:b.minX+(topLeft ? r:0),y:b.minY))
        path.addLine(to:CGPoint(x:b.maxX-(topRight ? r:0),y:b.minY))
        if topRight{path.addArc(tangent1End:CGPoint(x:b.maxX,y:b.minY),tangent2End:CGPoint(x:b.maxX,y:b.minY+r),radius:r)}
        path.addLine(to:CGPoint(x:b.maxX,y:b.maxY-(bottomRight ? r:0)))
        if bottomRight{path.addArc(tangent1End:CGPoint(x:b.maxX,y:b.maxY),tangent2End:CGPoint(x:b.maxX-r,y:b.maxY),radius:r)}
        path.addLine(to:CGPoint(x:b.minX+(bottomLeft ? r:0),y:b.maxY))
        if bottomLeft{path.addArc(tangent1End:CGPoint(x:b.minX,y:b.maxY),tangent2End:CGPoint(x:b.minX,y:b.maxY-r),radius:r)}
        path.addLine(to:CGPoint(x:b.minX,y:b.minY+(topLeft ? r:0)))
        if topLeft{path.addArc(tangent1End:CGPoint(x:b.minX,y:b.minY),tangent2End:CGPoint(x:b.minX+r,y:b.minY),radius:r)}
        path.closeSubpath();c.clear(bounds);c.clip(to:bounds)
        let inner:CGPoint,outer:CGPoint,offset:CGSize
        switch edge{
        case .right:inner=CGPoint(x:b.minX,y:b.midY);outer=CGPoint(x:b.maxX,y:b.midY);offset=CGSize(width:1,height:0)
        case .left:inner=CGPoint(x:b.maxX,y:b.midY);outer=CGPoint(x:b.minX,y:b.midY);offset=CGSize(width:-1,height:0)
        case .bottom:inner=CGPoint(x:b.midX,y:b.minY);outer=CGPoint(x:b.midX,y:b.maxY);offset=CGSize(width:0,height:1)
        case .top:inner=CGPoint(x:b.midX,y:b.maxY);outer=CGPoint(x:b.midX,y:b.minY);offset=CGSize(width:0,height:-1)
        }
        // --raised plus the specified ambient shadow; the existing painted bounds clip outer shadows.
        let m=c.ctm,shadowScale=hypot(m.a,m.b)
        let shadowOffset=CGSize(width:m.a*offset.width+m.c*offset.height,height:m.b*offset.width+m.d*offset.height)
        c.setFillColor(color(42,43,46));c.setShadow(offset:.zero,blur:6*shadowScale,color:color(0,0,0,0x66/255.0))
        c.addPath(path);c.fillPath()
        c.setShadow(offset:shadowOffset,blur:2*shadowScale,color:color(0,0,0,0xaa/255.0));c.addPath(path);c.fillPath()
        c.setShadow(offset:.zero,blur:0,color:nil)
        c.setStrokeColor(color(11,12,14));c.setLineWidth(2);c.addPath(path);c.strokePath()
        c.addPath(path);c.clip()
        let gradient=CGGradient(colorsSpace:CGColorSpace(name:CGColorSpace.sRGB),colors:[color(42,43,46),color(20,21,23)] as CFArray,locations:[0,1])!
        c.drawLinearGradient(gradient,start:inner,end:outer,options:[.drawsBeforeStartLocation,.drawsAfterEndLocation])
        // Inset highlight/shade rotate with the material's thickness, rather than its long axis.
        let vertical=edge == .left || edge == .right
        for (point,ink,inset) in [(inner,color(255,255,255,0x1c/255.0),CGFloat(0.5)),(outer,color(0,0,0,0x66/255.0),CGFloat(-0.5))]{
            let direction:CGFloat=edge == .left || edge == .top ? -1:1
            c.setStrokeColor(ink);c.setLineWidth(1)
            if vertical{let x=point.x+direction*inset;c.move(to:CGPoint(x:x,y:b.minY));c.addLine(to:CGPoint(x:x,y:b.maxY))}
            else{let y=point.y+direction*inset;c.move(to:CGPoint(x:b.minX,y:y));c.addLine(to:CGPoint(x:b.maxX,y:y))}
            c.strokePath()
        }
    }
    public override func accessibilityPerformPress()->Bool{guard !failed,!isHiddenOrHasHiddenAncestor,let onReveal else{return false};onReveal();return true}
    public override func acceptsFirstMouse(for event:NSEvent?)->Bool{true}
    public override func mouseDown(with event:NSEvent){if !failed,!isHiddenOrHasHiddenAncestor{onReveal?()}}
    public func dispose(){
        failed=true;onNeedsFreshPresentation=nil;onReveal=nil;suppliedEdge=nil;image=nil;alpha=[];retainedBytes=0
        setAccessibilityElement(false);setAccessibilityEnabled(false);setAccessibilityLabel(nil);needsDisplay=true
    }
}
