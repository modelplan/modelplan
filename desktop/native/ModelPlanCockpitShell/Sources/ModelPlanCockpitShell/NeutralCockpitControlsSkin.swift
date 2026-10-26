// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanPrimitives

/// Generic system-font community presentation. It reads no official resource or sibling checkout.
@MainActor public final class NeutralCockpitControlsSkin: CockpitStripSkin, CockpitHUDSkin {
    public init() {}
    public func layout(for state: CockpitStripState) throws -> CockpitStripLayout {
        CockpitStripLayout(size:CGSize(width:320,height:28),controls:[.shutter:CGRect(x:8,y:0,width:112,height:28),
            .alert:CGRect(x:128,y:0,width:44,height:28),.settings:CGRect(x:200,y:0,width:28,height:28),
            .attachment:CGRect(x:236,y:0,width:28,height:28),.close:CGRect(x:272,y:0,width:28,height:28)],shutterTravel:80)
    }
    public func drawStrip(in context: CGContext, bounds: CGRect, state: CockpitStripState) {
        context.setFillColor(NSColor.controlBackgroundColor.cgColor); context.fill(bounds)
    }
    private func raster(_ bounds: CGRect,scale:Int,body:(CGContext)->Void) throws -> CockpitControlArtwork {
        guard let ctx = CGContext(data:nil,width:Int(bounds.width)*scale,height:Int(bounds.height)*scale,bitsPerComponent:8,bytesPerRow:0,
            space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { throw CockpitSurfaceError.invalidRaster }
        ctx.translateBy(x:0,y:CGFloat(ctx.height)); ctx.scaleBy(x:CGFloat(scale),y:-CGFloat(scale)); body(ctx)
        guard let image = ctx.makeImage() else { throw CockpitSurfaceError.invalidRaster }
        return CockpitControlArtwork(base:image,bounds:bounds)
    }
    public func artwork(for control: CockpitControlID, state: CockpitStripState, button: CockpitButtonState) throws -> CockpitControlArtwork {
        let size = try layout(for:state).controls[control]!.size, rect = CGRect(origin:.zero,size:size)
        func painted(_ color:NSColor) throws -> CGImage {
            try raster(rect,scale:state.appearance.scale) { ctx in
                ctx.setFillColor(color.cgColor); ctx.fill(rect.insetBy(dx:1,dy:1))
                let label: String
                switch control { case .shutter: label=""; case .alert: label="ALERT"; case .settings: label="⚙"; case .attachment: label=state.detached ? "↩":"↗"; case .close: label="×" }
                drawText(label,rect:rect.insetBy(dx:2,dy:6),color:.labelColor,size:11,context:ctx)
                if button.focused { ctx.setStrokeColor(NSColor.keyboardFocusIndicatorColor.cgColor);ctx.setLineWidth(2);ctx.stroke(rect.insetBy(dx:2,dy:2)) }
            }.base
        }
        let base = try painted(.controlColor)
        let light = control == .alert ? try button.lampSeverity.map { try painted($0 == .red ? NSColor.systemRed:NSColor.systemOrange) }:nil
        return CockpitControlArtwork(base:base,light:light,bounds:rect)
    }
    public func shutterArtwork(for state: CockpitStripState, focused: Bool) throws -> CockpitShutterArtwork {
        let scale = state.appearance.scale
        let track = try raster(CGRect(x:0,y:0,width:112,height:28),scale:scale) { ctx in
            ctx.setFillColor(NSColor.separatorColor.cgColor); ctx.fill(CGRect(x:0,y:0,width:112,height:28))
            if focused { ctx.setStrokeColor(NSColor.keyboardFocusIndicatorColor.cgColor);ctx.setLineWidth(2);ctx.stroke(CGRect(x:2,y:2,width:108,height:24)) }
        }
        let thumb = try raster(CGRect(x:2,y:2,width:28,height:24),scale:scale) { ctx in
            ctx.setFillColor(NSColor.controlAccentColor.cgColor); ctx.fill(CGRect(x:0,y:0,width:28,height:24))
        }
        let blind = try raster(CGRect(x:3,y:4,width:80,height:20),scale:scale) { ctx in
            ctx.setFillColor(NSColor.tertiaryLabelColor.cgColor); ctx.fill(CGRect(x:0,y:0,width:80,height:20))
        }
        return CockpitShutterArtwork(track:track,thumb:thumb,blind:blind)
    }
    public func discardCachedArtwork() {}
    public func layout(for state: CockpitHUDState) throws -> CockpitHUDLayout {
        let rows = min(state.profile == .full ? 6:3,state.models.count)
        return CockpitHUDLayout(frame:CGRect(x:8,y:8,width:180,height:80+rows*18),chart:CGRect(x:8,y:4,width:164,height:64),
            rows:(0..<rows).map { CGRect(x:4,y:80+$0*18,width:172,height:18) })
    }
    public func drawHUD(in context: CGContext,state: CockpitHUDState,layout: CockpitHUDLayout,chart: CockpitHUDChart) {
        context.setFillColor(NSColor.windowBackgroundColor.cgColor); context.fill(CGRect(origin:.zero,size:layout.frame.size))
        context.saveGState(); context.translateBy(x:layout.chart.minX,y:layout.chart.minY)
        context.setStrokeColor(NSColor.labelColor.cgColor); context.setLineWidth(1)
        if let first = chart.frontier.first { context.move(to:first); for p in chart.frontier.dropFirst() { context.addLine(to:p) }; context.strokePath() }
        for p in chart.points {
            if let current = p.current {
                context.setStrokeColor(NSColor.secondaryLabelColor.cgColor);context.setLineWidth(1)
                context.move(to:current);context.addLine(to:p.recommended);context.strokePath()
                let dot = CGRect(x:current.x-2.4,y:current.y-2.4,width:4.8,height:4.8)
                context.setFillColor(NSColor.white.cgColor);context.fillEllipse(in:dot)
                context.setStrokeColor(NSColor.labelColor.cgColor);context.strokeEllipse(in:dot)
            }
        }
        context.setFillColor(NSColor.labelColor.cgColor)
        for p in chart.points { context.setFillColor((p.id==state.hoveredID || p.id==state.selectedID ? NSColor.controlAccentColor:NSColor.labelColor).cgColor);context.fillEllipse(in:CGRect(x:p.recommended.x-2,y:p.recommended.y-2,width:4,height:4)) }
        context.restoreGState()
        for (index,rect) in layout.rows.enumerated() where state.models.indices.contains(index) {
            let m = state.models[index]; drawText(m.shortName+" ★"+m.recommendedEffort,rect:rect,color:.labelColor,size:10,context:context)
        }
    }
}
@MainActor private func drawText(_ text:String,rect:CGRect,color:NSColor,size:CGFloat,context:CGContext) {
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext:context,flipped:true)
    (text as NSString).draw(in:rect,withAttributes:[.font:NSFont.systemFont(ofSize:size),.foregroundColor:color])
    NSGraphicsContext.restoreGraphicsState()
}
