// SPDX-License-Identifier: MIT
import AppKit
import CoreGraphics

/// A small painted surface, not the16pt wake target. Appearance pixels are externally supplied.
@MainActor public final class DockSliverView:NSView {
    public var onReveal:(()->Void)?{didSet{setAccessibilityEnabled(!failed && onReveal != nil)}}
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
            guard image.width>=w,image.height>=h else{throw DockArtworkError.invalidManifest}
            guard let c=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Big.rawValue|CGImageAlphaInfo.premultipliedLast.rawValue) else{throw DockArtworkError.invalidManifest}
            c.draw(image,in:CGRect(x:0,y:0,width:w,height:h));guard let normalized=c.makeImage(),let bytes=c.data else{throw DockArtworkError.invalidManifest}
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
    public override func draw(_ dirtyRect:NSRect){
        guard !failed else{return}
        if let image{NSImage(cgImage:image,size:bounds.size).draw(in:bounds,from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:nil)}
        else{NSColor.separatorColor.setFill();bounds.fill()}
    }
    public override func accessibilityPerformPress()->Bool{guard !failed,!isHiddenOrHasHiddenAncestor,let onReveal else{return false};onReveal();return true}
    public override func acceptsFirstMouse(for event:NSEvent?)->Bool{true}
    public override func mouseDown(with event:NSEvent){if !failed,!isHiddenOrHasHiddenAncestor{onReveal?()}}
    public func dispose(){onReveal=nil;image=nil;alpha=[];retainedBytes=0;failed=true;setAccessibilityElement(false);setAccessibilityEnabled(false);setAccessibilityLabel(nil)}
}
