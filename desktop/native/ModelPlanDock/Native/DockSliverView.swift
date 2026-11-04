// SPDX-License-Identifier: MIT
import AppKit
import CoreGraphics
import QuartzCore

/// An admitted semantic notice and its appearance-owned relative position.
public struct DockSliverNoticeMark: Equatable {
    public let position: CGFloat, notice: DockNotice, unit: CGFloat
    public init(position: CGFloat, notice: DockNotice, unit: CGFloat) { self.position = position; self.notice = notice; self.unit = unit }
}

/// One member's registered pitch. A nil role means no alert paint over the neutral body.
public struct DockSliverQuotaInput {
    public let subscriptionID: String, remainingPercent: Double?, quotaRole: DockQuotaStatus?, ink: DockInk?
    public let from: Double, through: Double, opacity: Double
    public init(subscriptionID:String,remainingPercent:Double?,quotaRole:DockQuotaStatus?,ink:DockInk?,from:Double,through:Double,opacity:Double=0.18) {
        self.subscriptionID=subscriptionID;self.remainingPercent=remainingPercent;self.quotaRole=quotaRole
        self.ink=quotaRole == nil ? nil:ink;self.opacity=quotaRole == nil ? 0:opacity
        self.from=from;self.through=through
    }
}
/// Registered member pitch and alert paint. Nil role/zero opacity means no quota overlay.
/// A raw raster diagnostic has no member provenance; unknown readings never invent a percentage.
public struct DockSliverResolvedColorSegment: Equatable {
    public let from: Double, through: Double
    public let rgbaHex: String, subscriptionID: String?
    public let remainingPercent: Double?
    public let quotaRole: DockQuotaStatus?
    public let opacity: Double
    public init(from:Double,through:Double,rgbaHex:String,remainingPercent:Double?,quotaRole:DockQuotaStatus?,subscriptionID:String?=nil,opacity:Double=1) {
        self.from=from;self.through=through;self.rgbaHex=rgbaHex;self.remainingPercent=remainingPercent;self.quotaRole=quotaRole;self.subscriptionID=subscriptionID;self.opacity=opacity
    }
}

/// A small painted surface, not the physical wake target. Appearance pixels are externally supplied.
@MainActor public final class DockSliverView:NSView {
    private struct PitchKey:Hashable { let from:Double, through:Double }
    private var quotaDrawing: [(segment:DockSliverResolvedColorSegment, ink:DockInk?)] = []
    /// Semantic bindings consumed by draw(), with no pixel-to-quota inference or window side effect.
    public var quotaSegmentColorRolesForChecks: [DockSliverResolvedColorSegment] { failed ? [] : quotaDrawing.map(\.segment) }
    /// Optional raster calibration only; these runs make no quota/member claim.
    public var rasterColorRunsForChecks: [DockSliverResolvedColorSegment] {
        guard !failed, bounds.width.isFinite, bounds.height.isFinite,
              bounds.width > 0, bounds.height > 0, bounds.width <= 4096, bounds.height <= 4096 else { return [] }
        let width = Int(ceil(bounds.width * CGFloat(scale))), height = Int(ceil(bounds.height * CGFloat(scale)))
        guard width > 0, height > 0, width * height <= 800_000,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else { return [] }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: CGFloat(scale), y: -CGFloat(scale))
        context.translateBy(x: -bounds.minX, y: -bounds.minY)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        draw(bounds)
        NSGraphicsContext.restoreGraphicsState()
        guard let data = context.data else { return [] }
        let bytes = data.assumingMemoryBound(to: UInt8.self)
        let vertical = height > width, length = vertical ? height : width
        func colour(_ index: Int) -> String {
            let x = vertical ? width / 2 : index, y = vertical ? index : height / 2
            let offset = (y * width + x) * 4, alpha = Int(bytes[offset + 3])
            let rgb = (0..<3).map { alpha == 0 ? 0 : min(255, (Int(bytes[offset + $0]) * 255 + alpha / 2) / alpha) }
            return String(format: "#%02X%02X%02X%02X", rgb[0], rgb[1], rgb[2], alpha)
        }
        var result: [DockSliverResolvedColorSegment] = [], start = 0, current = colour(0)
        for index in 1...length {
            let next = index < length ? colour(index) : ""
            if next != current {
                result.append(.init(from: Double(start) / Double(length), through: Double(index) / Double(length),
                    rgbaHex: current, remainingPercent: nil, quotaRole: nil))
                start = index; current = next
            }
        }
        return result
    }
    public var onReveal:(()->Void)?{didSet{setAccessibilityEnabled(!failed && onReveal != nil)}}
    public var onNeedsFreshPresentation:(()->Void)?
    public var noticeMarks: [DockSliverNoticeMark] = [] { didSet { if oldValue != noticeMarks { clearPulses(); needsDisplay = true } } }
    private var noticePulseLayers = [CALayer]()
    @_spi(DockResourceChecks) public var noticePulseCountForChecks: Int { noticePulseLayers.count }
    private func clearPulses() { noticePulseLayers.forEach { $0.removeAllAnimations(); $0.removeFromSuperlayer() }; noticePulseLayers = [] }
    public private(set) var retainedBytes=0
    private var image:CGImage?,alpha=[UInt8](),scale=1,failed=true
    public override var isFlipped:Bool{true}
    public override var acceptsFirstResponder:Bool{false}
    public override init(frame:NSRect){super.init(frame:frame);wantsLayer=true;layer?.masksToBounds=true;setAccessibilityElement(false);setAccessibilityRole(.button);setAccessibilityEnabled(false)}
    required init?(coder:NSCoder){fatalError("init(coder:) is unsupported")}
    public func apply(image:CGImage?,logicalSize:CGSize,scale:Int,accessibilityLabel:String,quotaReadings:[DockSliverQuotaInput]=[])throws{
        self.image=nil;alpha=[];quotaDrawing=[];retainedBytes=0;failed=true;setAccessibilityElement(false);setAccessibilityLabel(nil);setAccessibilityEnabled(false);needsDisplay=true
        guard (1...2).contains(scale),logicalSize.width.isFinite,logicalSize.height.isFinite,
            logicalSize.width>0,logicalSize.height>0,logicalSize.width<=4096,logicalSize.height<=4096 else{throw DockArtworkError.invalidManifest}
        guard quotaReadings.count <= 256, Set(quotaReadings.map(\.subscriptionID)).count == quotaReadings.count,
              quotaReadings.allSatisfy({ value in
                guard !value.subscriptionID.isEmpty, value.subscriptionID.utf8.count <= 256,
                      value.from.isFinite, value.through.isFinite, 0 <= value.from, value.from < value.through, value.through <= 1,
                      value.remainingPercent.map({ $0.isFinite && (0...100).contains($0) }) ?? true else { return false }
                if let role=value.quotaRole {
                    return (role == .warning || role == .critical) && value.remainingPercent != nil && value.ink?.valid == true && value.opacity.isFinite && value.opacity > 0 && value.opacity < 1
                }
                return value.ink == nil && value.opacity == 0
              }) else { throw DockArtworkError.invalidManifest }
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
        quotaDrawing = quotaReadings.map { value in
            let hex = value.ink.map { ink in String(format:"#%02X%02X%02X%02X",Int((ink.r*255).rounded()),Int((ink.g*255).rounded()),Int((ink.b*255).rounded()),Int((ink.a*255).rounded())) } ?? ""
            let segment = DockSliverResolvedColorSegment(from:value.from,through:value.through,rgbaHex:hex,remainingPercent:value.remainingPercent,quotaRole:value.quotaRole,subscriptionID:value.subscriptionID,opacity:value.opacity)
            return (segment,value.ink)
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
        NSGraphicsContext.saveGraphicsState();defer{NSGraphicsContext.restoreGraphicsState()}
        guard let graphics=NSGraphicsContext.current else{return}
        graphics.imageInterpolation = .high
        graphics.cgContext.setShouldAntialias(true)
        if let image{NSImage(cgImage:image,size:bounds.size).draw(in:bounds,from:.zero,operation:.copy,fraction:1,respectFlipped:true,hints:nil)}
        else{drawNeutralMetal(in:graphics.cgContext)}
        // The body stays neutral. Alert paint is faint, static, and limited to the registered pitch.
        // Overflow members share a physical pitch: paint its highest severity once, without accumulating alpha.
        let c = graphics.cgContext
        var paints = [PitchKey:Int]()
        for (index,value) in quotaDrawing.enumerated() where value.segment.quotaRole != nil {
            let key = PitchKey(from:value.segment.from,through:value.segment.through)
            if let previous=paints[key], quotaDrawing[previous].segment.quotaRole == .critical { continue }
            paints[key]=index
        }
        c.saveGState(); c.setBlendMode(.sourceAtop)
        for role in [DockQuotaStatus.warning,.critical] {
            for index in paints.values where quotaDrawing[index].segment.quotaRole == role {
                let value=quotaDrawing[index]
                guard let ink=value.ink else { continue }
                let horizontal = bounds.width > bounds.height
                let from = CGFloat(value.segment.from), through = CGFloat(value.segment.through)
                let rect = horizontal
                    ? CGRect(x:bounds.minX+bounds.width*from,y:bounds.minY,width:bounds.width*(through-from),height:bounds.height)
                    : CGRect(x:bounds.minX,y:bounds.minY+bounds.height*from,width:bounds.width,height:bounds.height*(through-from))
                c.setAlpha(value.segment.opacity); c.setFillColor(ink.cg); c.fill(rect)
            }
        }
        c.restoreGState()
        for mark in noticeMarks where mark.position.isFinite && (0...1).contains(mark.position) && mark.unit.isFinite && mark.unit > 0 {
            let horizontal = bounds.width > bounds.height
            let center = horizontal ? CGPoint(x: bounds.width * mark.position, y: bounds.midY) : CGPoint(x: bounds.midX, y: bounds.height * mark.position)
            let diameter = (mark.notice.shape == .hollow ? 6 : 5) * mark.unit
            let rect = CGRect(x: center.x-diameter/2, y: center.y-diameter/2, width: diameter, height: diameter)
            let components: [CGFloat]
            switch mark.notice.tone {
            case .amber: components = [234.0/255,193.0/255,123.0/255,1]
            case .blue: components = [159.0/255,210.0/255,1,1]
            case .white: components = [1,1,1,1]
            }
            let c = graphics.cgContext, color = CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: components)!
            c.saveGState(); c.setAlpha(0.7)
            if mark.notice.shape == .hollow {
                let width = 1.2 * mark.unit; c.setStrokeColor(color); c.setLineWidth(width)
                c.strokeEllipse(in: rect.insetBy(dx: width/2, dy: width/2))
            } else { c.setFillColor(color); c.fillEllipse(in: rect) }
            c.restoreGState()
        }
    }
    /// One transient brightness flash on a projected mark; the persistent dot remains in this painter.
    @discardableResult public func pulseNotice(_ key: DockNoticeKey) -> Bool {
        guard !failed, let root = layer, let mark = noticeMarks.first(where: { $0.notice.key == key }),
              mark.position.isFinite, (0...1).contains(mark.position), mark.unit.isFinite, mark.unit > 0 else { return false }
        let horizontal = bounds.width > bounds.height
        let center = horizontal ? CGPoint(x: bounds.width * mark.position, y: bounds.midY) : CGPoint(x: bounds.midX, y: bounds.height * mark.position)
        let diameter = (mark.notice.shape == .hollow ? 6 : 5) * mark.unit
        let dot = CGRect(x: center.x-diameter/2, y: center.y-diameter/2, width: diameter, height: diameter)
        let components: [CGFloat]
        switch mark.notice.tone {
        case .amber: components = [234.0/255, 193.0/255, 123.0/255]
        case .blue: components = [159.0/255, 210.0/255, 1]
        case .white: components = [1, 1, 1]
        }
        let bright = components.map { min(1, $0 * 2.2) } + [CGFloat(1)]
        let color = CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: bright)!
        let overlay = CAShapeLayer(); overlay.frame = bounds
        if mark.notice.shape == .hollow {
            let width = 1.2 * mark.unit; overlay.path = CGPath(ellipseIn: dot.insetBy(dx: width/2, dy: width/2), transform: nil)
            overlay.fillColor = nil; overlay.strokeColor = color; overlay.lineWidth = width
        } else { overlay.path = CGPath(ellipseIn: dot, transform: nil); overlay.fillColor = color }
        root.addSublayer(overlay); noticePulseLayers.append(overlay)
        let pulse = CAKeyframeAnimation(keyPath: "opacity"); pulse.values = [0, 0.7, 0]; pulse.keyTimes = [0, 0.35, 1]
        pulse.duration = 0.45; pulse.timingFunctions = [CAMediaTimingFunction(name: .easeOut), CAMediaTimingFunction(name: .easeOut)]
        CATransaction.begin(); CATransaction.setCompletionBlock { [weak self, weak overlay] in
            overlay?.removeFromSuperlayer()
            self?.noticePulseLayers.removeAll { $0 === overlay }
        }
        overlay.add(pulse, forKey: "dock-notice-first-appearance"); CATransaction.commit()
        return true
    }
    /// Only the neutral fallback is drawn here; supplied artwork and semantic segments stay intact.
    private func drawNeutralMetal(in c:CGContext){
        let edge:DockEdge
        if bounds.width>bounds.height{edge = .bottom}
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
        // CSS 180deg remains top-to-bottom: only the corner radii depend on the edge.
        let top=CGPoint(x:b.midX,y:b.minY),bottom=CGPoint(x:b.midX,y:b.maxY),offset=CGSize(width:0,height:1)
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
        c.drawLinearGradient(gradient,start:top,end:bottom,options:[.drawsBeforeStartLocation,.drawsAfterEndLocation])
        // --raised inset highlights/shades remain on the physical top and bottom in every placement.
        for (y,ink) in [(b.minY+0.5,color(255,255,255,0x1c/255.0)),(b.maxY-0.5,color(0,0,0,0x66/255.0))]{
            c.setStrokeColor(ink);c.setLineWidth(1)
            c.move(to:CGPoint(x:b.minX,y:y));c.addLine(to:CGPoint(x:b.maxX,y:y));c.strokePath()
        }
    }
    public override func accessibilityPerformPress()->Bool{guard !failed,!isHiddenOrHasHiddenAncestor,let onReveal else{return false};onReveal();return true}
    public override func acceptsFirstMouse(for event:NSEvent?)->Bool{true}
    public override func mouseDown(with event:NSEvent){if !failed,!isHiddenOrHasHiddenAncestor{onReveal?()}}
    public func dispose(){
        failed=true;quotaDrawing=[];noticeMarks=[];onNeedsFreshPresentation=nil;onReveal=nil;image=nil;alpha=[];retainedBytes=0
        setAccessibilityElement(false);setAccessibilityEnabled(false);setAccessibilityLabel(nil);needsDisplay=true
    }
}
