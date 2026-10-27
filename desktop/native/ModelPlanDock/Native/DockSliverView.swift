// SPDX-License-Identifier: MIT
import AppKit
import CoreGraphics

/// A small painted surface, not the physical wake target. Appearance pixels are externally supplied.
@MainActor public final class DockSliverView:NSView {
    public var onReveal:(()->Void)?{didSet{setAccessibilityEnabled(!failed && onReveal != nil)}}
    public var onNeedsFreshPresentation:(()->Void)?
    public private(set) var retainedBytes=0
    private var image:CGImage?,alpha=[UInt8](),scale=1,failed=true
    public override var isFlipped:Bool{true}
    public override var acceptsFirstResponder:Bool{false}
    public override init(frame:NSRect){super.init(frame:frame);setAccessibilityElement(false);setAccessibilityRole(.button);setAccessibilityEnabled(false)}
    required init?(coder:NSCoder){fatalError("init(coder:) is unsupported")}
    public func apply(image:CGImage?,logicalSize:CGSize,scale:Int,accessibilityLabel:String)throws{
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
        self.scale=scale;frame.size=logicalSize;failed=false;setAccessibilityElement(true);setAccessibilityEnabled(onReveal != nil);setAccessibilityLabel(accessibilityLabel)
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
        if let image{NSImage(cgImage:image,size:bounds.size).draw(in:bounds,from:.zero,operation:.copy,fraction:1,respectFlipped:true,hints:nil)}
        else{NSColor.separatorColor.setFill();bounds.fill()}
    }
    public override func accessibilityPerformPress()->Bool{guard !failed,!isHiddenOrHasHiddenAncestor,let onReveal else{return false};onReveal();return true}
    public override func acceptsFirstMouse(for event:NSEvent?)->Bool{true}
    public override func mouseDown(with event:NSEvent){if !failed,!isHiddenOrHasHiddenAncestor{onReveal?()}}
    public func dispose(){
        failed=true;onNeedsFreshPresentation=nil;onReveal=nil;image=nil;alpha=[];retainedBytes=0
        setAccessibilityElement(false);setAccessibilityEnabled(false);setAccessibilityLabel(nil);needsDisplay=true
    }
}
