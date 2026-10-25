// SPDX-License-Identifier: MIT
import Foundation
import CoreGraphics
import CoreText

/// Generic drawing schema. Official silhouettes, placements, radii, pixels and palette are external data.
public struct DockInk: Codable, Sendable {
    public var r:Double,g:Double,b:Double,a:Double
    public init(_ r:Double,_ g:Double,_ b:Double,_ a:Double=1){self.r=r;self.g=g;self.b=b;self.a=a}
    var valid:Bool{[r,g,b,a].allSatisfy{$0.isFinite && (0...1).contains($0)}}
    var cg:CGColor{CGColor(colorSpace:CGColorSpace(name:CGColorSpace.sRGB)!,components:[r,g,b,a])!}
}
public struct DockBitmapLayer: Codable, Sendable {public var resource:String;public var rect:CGRect}
public struct DockRingRecipe: Codable, Sendable {public var radius:CGFloat,width:CGFloat,minimumVisibleFraction:Double,opacity:Double}
public struct DockClockRecipe: Codable, Sendable {public var radius:CGFloat,dotRadius:CGFloat,backWidth:CGFloat;public var positions:Int}
public struct DockTextRecipe: Codable, Sendable {public var fontResource:String?;public var size:CGFloat,weight:Double}
public struct DockStationRecipe: Codable, Sendable {
    public var subscriptionID:String?
    public var centre:CGPoint,diameter:CGFloat,readout:CGRect,aliasRect:CGRect?,eventRect:CGRect
    public var layers:[String],glyphs:[String:String]
    public var glyphRect:CGRect
    public var outer:DockRingRecipe,inner:DockRingRecipe
    public var clock:DockClockRecipe
    public var notchWidth:CGFloat,caseInnerRadius:CGFloat
    public var overflowCount:Int?
}
public struct DockInstrumentSkin: Codable, Sendable {
    public var schemaVersion:Int
    public var bounds:CGRect,bodyPolygon:[CGPoint],fixedLayers:[DockBitmapLayer],stations:[DockStationRecipe]
    public var palette:[String:DockInk]
    public var text:DockTextRecipe,aliasText:DockTextRecipe
    public init(schemaVersion:Int,bounds:CGRect,bodyPolygon:[CGPoint],fixedLayers:[DockBitmapLayer],stations:[DockStationRecipe],palette:[String:DockInk],text:DockTextRecipe,aliasText:DockTextRecipe) {
        self.schemaVersion=schemaVersion;self.bounds=bounds;self.bodyPolygon=bodyPolygon;self.fixedLayers=fixedLayers
        self.stations=stations;self.palette=palette;self.text=text;self.aliasText=aliasText
    }
}
public struct DockGlyphMetric: Sendable {public let text:String,font:String;public let advance:Double,ascent:CGFloat,descent:CGFloat}
public struct DockRenderResult {public let image:CGImage;public let metrics:[DockGlyphMetric];public let scale:Int;public let effectsRendered:Bool}

@MainActor public final class DockInstrumentRenderer {
    private let resources:DockArtworkStore
    public init(resources:DockArtworkStore){self.resources=resources}
    public func render(skin:DockInstrumentSkin,readings:[String:DockInstrumentReading],notices:[String:DockNotice]=[:],scale:Int) throws -> DockRenderResult {
        guard skin.schemaVersion==1,(1...2).contains(scale),!skin.bounds.isNull,!skin.bounds.isEmpty,
            skin.bounds.width<=4096,skin.bounds.height<=4096,skin.bodyPolygon.count<=4096,skin.stations.count<=64,
            skin.fixedLayers.count<=1024,skin.palette.values.allSatisfy(\.valid) else{throw DockArtworkError.invalidManifest}
        // Animated official jets are supplied by the shared pooled-frame layer, not baked into static captures.
        // A static renderer must never silently replace them with the calibration triangle or an uncounted cache.
        let width=Int(ceil(skin.bounds.width*CGFloat(scale))),height=Int(ceil(skin.bounds.height*CGFloat(scale)))
        guard width>0,height>0,width<=8192,height<=8192,width*height<=16_777_216,
              let c=CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:0,
                space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else{throw DockArtworkError.invalidManifest}
        c.translateBy(x:0,y:CGFloat(height));c.scaleBy(x:CGFloat(scale),y:-CGFloat(scale))
        c.translateBy(x:-skin.bounds.minX,y:-skin.bounds.minY);c.setAllowsAntialiasing(true)
        func ink(_ name:String) throws -> CGColor {guard let v=skin.palette[name],v.valid else{throw DockArtworkError.invalidManifest};return v.cg}
        func image(_ resource:String,_ rect:CGRect) throws {
            guard rect.minX.isFinite,rect.minY.isFinite,rect.width>0,rect.height>0,rect.width<=4096,rect.height<=4096 else{throw DockArtworkError.invalidManifest}
            let size=Int(ceil(max(rect.width,rect.height)*CGFloat(scale)))
            let image=try resources.image(resource,maximumPixelSize:max(1,size))
            // Image pixels and logical geometry are distinct; no nominal @2x relabelling.
            guard image.width>=Int(ceil(rect.width*CGFloat(scale))),image.height>=Int(ceil(rect.height*CGFloat(scale))) else{throw DockArtworkError.corruptResource(resource)}
            c.saveGState();c.translateBy(x:rect.minX,y:rect.maxY);c.scaleBy(x:1,y:-1)
            c.draw(image,in:CGRect(origin:.zero,size:rect.size));c.restoreGState()
        }
        if !skin.bodyPolygon.isEmpty {
            c.addLines(between:skin.bodyPolygon);c.closePath();c.setFillColor(try ink("body"));c.fillPath()
        }
        for fixed in skin.fixedLayers {try image(fixed.resource,fixed.rect)}
        var metrics=[DockGlyphMetric]()
        func text(_ value:String,_ rect:CGRect,_ recipe:DockTextRecipe,_ color:CGColor) throws {
            guard value.utf8.count<=1024,recipe.size.isFinite,(1...128).contains(recipe.size),rect.width>0,rect.height>0 else{throw DockArtworkError.invalidManifest}
            let font:CTFont
            if let id=recipe.fontResource {font=try resources.font(id,size:recipe.size,weight:recipe.weight)}
            else {font=CTFontCreateUIFontForLanguage(.userFixedPitch,recipe.size,nil)!}
            let line=CTLineCreateWithAttributedString(NSAttributedString(string:value,attributes:[
                NSAttributedString.Key(kCTFontAttributeName as String):font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String):color]))
            var ascent:CGFloat=0,descent:CGFloat=0,leading:CGFloat=0
            let advance=CTLineGetTypographicBounds(line,&ascent,&descent,&leading)
            metrics.append(DockGlyphMetric(text:value,font:CTFontCopyPostScriptName(font) as String,advance:advance,ascent:ascent,descent:descent))
            c.saveGState();c.clip(to:rect)
            let baseline=rect.midY+(ascent-descent)/2
            c.translateBy(x:rect.midX-CGFloat(advance)/2,y:baseline);c.scaleBy(x:1,y:-1);c.textMatrix = .identity
            c.textPosition = .zero;CTLineDraw(line,c);c.restoreGState()
        }
        func ring(_ recipe:DockRingRecipe,_ arc:DockQuotaArc?,_ centre:CGPoint) throws {
            guard recipe.radius>0,recipe.width>0,recipe.radius.isFinite,recipe.width.isFinite,
                recipe.opacity.isFinite,(0...1).contains(recipe.opacity),(0...1).contains(recipe.minimumVisibleFraction) else{throw DockArtworkError.invalidManifest}
            c.saveGState();c.setAlpha(recipe.opacity);c.setLineWidth(recipe.width);c.setLineCap(.butt)
            let rect=CGRect(x:centre.x-recipe.radius,y:centre.y-recipe.radius,width:2*recipe.radius,height:2*recipe.radius)
            c.setStrokeColor(try ink("track"));c.strokeEllipse(in:rect)
            if let arc,let fraction=arc.fraction,fraction.isFinite,(0...1).contains(fraction),fraction>0 {
                c.setStrokeColor(try ink(arc.status.rawValue));c.addArc(center:centre,radius:recipe.radius,startAngle:-.pi/2,
                    endAngle:-.pi/2+CGFloat(max(recipe.minimumVisibleFraction,fraction))*2 * .pi,clockwise:false);c.strokePath()
            }
            c.restoreGState()
        }
        for station in skin.stations {
            guard station.diameter.isFinite,(8...256).contains(station.diameter),station.clock.positions>0,station.clock.positions<=128 else{throw DockArtworkError.invalidManifest}
            let frame=CGRect(x:station.centre.x-station.diameter/2,y:station.centre.y-station.diameter/2,width:station.diameter,height:station.diameter)
            for layer in station.layers {try image(layer,frame)}
            guard let id=station.subscriptionID,let reading=readings[id] else {
                if let n=station.overflowCount {try text("+\(n)",frame,skin.text,try ink("text"))}
                continue
            }
            let radius=station.caseInnerRadius
            guard radius>=0,radius<station.diameter/2 else{throw DockArtworkError.invalidManifest}
            c.setLineWidth(station.diameter/2-radius);c.setStrokeColor(try ink("case"))
            let rr=(radius+station.diameter/2)/2
            c.strokeEllipse(in:CGRect(x:station.centre.x-rr,y:station.centre.y-rr,width:2*rr,height:2*rr))
            try ring(station.outer,reading.outer,station.centre)
            if reading.inner != nil {try ring(station.inner,reading.inner,station.centre)}
            if station.notchWidth>0 {
                c.setLineWidth(station.notchWidth);c.setStrokeColor(try ink("notch"))
                c.move(to:CGPoint(x:station.centre.x,y:station.centre.y-station.diameter/2))
                c.addLine(to:CGPoint(x:station.centre.x,y:station.centre.y-radius));c.strokePath()
            }
            if let key=reading.vendorResourceKey,let resource=station.glyphs[key] {try image(resource,station.glyphRect)}
            if reading.timeLeftFraction != nil {
                let clock=station.clock,r=clock.radius
                guard r>0,r.isFinite,clock.dotRadius>0,clock.backWidth>=0 else{throw DockArtworkError.invalidManifest}
                c.setLineWidth(clock.backWidth);c.setStrokeColor(try ink("clockBack"))
                c.strokeEllipse(in:CGRect(x:station.centre.x-r,y:station.centre.y-r,width:2*r,height:2*r))
                let count=reading.litTimePoints(positions:clock.positions) ?? 0
                c.setFillColor(try ink("clock"))
                for i in 0..<count {let a=Double(i)*2 * .pi/Double(clock.positions)
                    let p=CGPoint(x:station.centre.x+sin(a)*r,y:station.centre.y-cos(a)*r)
                    c.fillEllipse(in:CGRect(x:p.x-clock.dotRadius,y:p.y-clock.dotRadius,width:2*clock.dotRadius,height:2*clock.dotRadius))}
            }
            let textColor=reading.status == .warning || reading.status == .critical ? reading.status.rawValue : reading.status == .unknown ? "unknown":"text"
            try text(reading.readout,station.readout,skin.text,try ink(textColor))
            if let alias=reading.alias,let rect=station.aliasRect {try text(alias,rect,skin.aliasText,try ink("alias"))}
            if let notice=notices[id] {
                let palette=notice.tone == .amber ? "noticeAmber":notice.tone == .blue ? "noticeBlue":"noticeWhite"
                let r=station.eventRect.insetBy(dx:station.eventRect.width/4,dy:station.eventRect.height/4)
                if notice.shape == .solid {c.setFillColor(try ink(palette));c.fillEllipse(in:r)}
                else {c.setStrokeColor(try ink(palette));c.setLineWidth(1.2);c.strokeEllipse(in:r)}
            }
        }
        guard let result=c.makeImage() else{throw DockArtworkError.invalidManifest}
        return DockRenderResult(image:result,metrics:metrics,scale:scale,effectsRendered:false)
    }
}
