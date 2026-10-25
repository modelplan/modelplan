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
public struct DockRingRecipe: Codable, Sendable {public var radius:CGFloat,width:CGFloat,minimumVisibleFraction:Double,opacity:Double;public var trackOpacity:Double?,unknownDash:[CGFloat]?}
public struct DockClockRecipe: Codable, Sendable {public var radius:CGFloat,dotRadius:CGFloat,backWidth:CGFloat;public var positions:Int}
public struct DockTextRecipe: Codable, Sendable {public var fontResource:String?;public var systemFontName:String?;public var useSystemUIFont:Bool?;public var language:String?;public var size:CGFloat,weight:Double}
public struct DockStationRecipe: Codable, Sendable {
    public var subscriptionID:String?
    public var logicalPoints:Int?
    public var centre:CGPoint,diameter:CGFloat,readout:CGRect,aliasRect:CGRect?,eventRect:CGRect
    public var layers:[String],glyphs:[String:String]
    public var glyphRect:CGRect
    public var outer:DockRingRecipe,inner:DockRingRecipe
    public var clock:DockClockRecipe
    public var notchWidth:CGFloat,caseInnerRadius:CGFloat
    public var overflowCount:Int?
    public var eventSolidDiameter:CGFloat?,eventHollowDiameter:CGFloat?,eventStrokeWidth:CGFloat?
    public var glyphOpacity:Double?
    public var eventBackdropKey:String?,eventOutlineKey:String?,eventSolidOutlineWidth:CGFloat?
    public var showsReadout:Bool?,placeholderLabel:String?,placeholderText:DockTextRecipe?
}
public struct DockInstrumentSkin: Codable, Sendable {
    public var schemaVersion:Int
    public var bounds:CGRect,bodyPolygon:[CGPoint],fixedLayers:[DockBitmapLayer],stations:[DockStationRecipe]
    public var palette:[String:DockInk]
    public var text:DockTextRecipe,aliasText:DockTextRecipe
    public var readoutPalette:[String:String]?
    public init(schemaVersion:Int,bounds:CGRect,bodyPolygon:[CGPoint],fixedLayers:[DockBitmapLayer],stations:[DockStationRecipe],palette:[String:DockInk],text:DockTextRecipe,aliasText:DockTextRecipe) {
        self.schemaVersion=schemaVersion;self.bounds=bounds;self.bodyPolygon=bodyPolygon;self.fixedLayers=fixedLayers
        self.stations=stations;self.palette=palette;self.text=text;self.aliasText=aliasText
    }
}
public struct DockGlyphMetric: Sendable {public let text:String,font:String;public let advance:Double,ascent:CGFloat,descent:CGFloat;public let runFonts:[String]}
public struct DockRenderResult {public let image:CGImage;public let metrics:[DockGlyphMetric];public let scale:Int;public let effectsRendered:Bool}

@MainActor public final class DockInstrumentRenderer {
    private let resources:DockArtworkStore
    public init(resources:DockArtworkStore){self.resources=resources}
    public func render(skin:DockInstrumentSkin,readings:[String:DockInstrumentReading],notices:[String:DockNotice]=[:],scale:Int) throws -> DockRenderResult {
        func finite(_ p:CGPoint)->Bool{p.x.isFinite && p.y.isFinite && abs(p.x)<=1_000_000 && abs(p.y)<=1_000_000}
        func finiteRect(_ r:CGRect)->Bool{finite(r.origin) && r.width.isFinite && r.height.isFinite && r.width>0 && r.height>0 && r.width<=4096 && r.height<=4096}
        let ids=skin.stations.compactMap(\.subscriptionID)
        guard Set(ids).count==ids.count,finiteRect(skin.bounds),skin.bodyPolygon.allSatisfy(finite),
            skin.fixedLayers.allSatisfy({finiteRect($0.rect)}),skin.stations.allSatisfy({finite($0.centre) && finiteRect($0.readout) && finiteRect($0.eventRect) && finiteRect($0.glyphRect) && ($0.aliasRect.map(finiteRect) ?? true)}),
            skin.schemaVersion==1,(1...3).contains(scale),!skin.bounds.isNull,!skin.bounds.isEmpty,
            skin.bounds.width<=4096,skin.bounds.height<=4096,skin.bodyPolygon.count<=4096,skin.stations.count<=64,
            skin.fixedLayers.count<=1024,skin.palette.values.allSatisfy(\.valid) else{throw DockArtworkError.invalidManifest}
        // Static offscreen reference sampling may use 3x; the window host only admits native 1x/2x.
        // Animated official jets are supplied by the shared pooled-frame layer, not baked into static captures.
        // A static renderer must never silently replace them with the calibration triangle or an uncounted cache.
        let width=Int(ceil(skin.bounds.width*CGFloat(scale))),height=Int(ceil(skin.bounds.height*CGFloat(scale)))
        guard width>0,height>0,width<=8192,height<=8192,width*height<=16_777_216,
              let c=CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:0,
                space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else{throw DockArtworkError.invalidManifest}
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
            guard recipe.language.map({!$0.isEmpty && $0.utf8.count<=64}) ?? true, value.utf8.count<=1024,recipe.size.isFinite,(1...128).contains(recipe.size),rect.width>0,rect.height>0 else{throw DockArtworkError.invalidManifest}
            let font:CTFont
            if let id=recipe.fontResource {font=try resources.font(id,size:recipe.size,weight:recipe.weight)}
            else if recipe.useSystemUIFont == true {font=CTFontCreateUIFontForLanguage(.system,recipe.size,recipe.language.map{$0 as CFString})!}
            else if let name=recipe.systemFontName {
                guard !name.isEmpty,name.utf8.count<=128 else{throw DockArtworkError.invalidManifest}
                font=CTFontCreateWithName(name as CFString,recipe.size,nil)
            } else {font=CTFontCreateUIFontForLanguage(.userFixedPitch,recipe.size,nil)!}
            var attributes:[NSAttributedString.Key:Any]=[
                NSAttributedString.Key(kCTFontAttributeName as String):font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String):color]
            if let language=recipe.language {
                guard !language.isEmpty,language.utf8.count<=64 else{throw DockArtworkError.invalidManifest}
                attributes[NSAttributedString.Key(kCTLanguageAttributeName as String)]=language
            }
            let line=CTLineCreateWithAttributedString(NSAttributedString(string:value,attributes:attributes))
            let runFonts=(CTLineGetGlyphRuns(line) as NSArray).compactMap{item -> String? in
                let run=item as! CTRun,attributes=CTRunGetAttributes(run) as NSDictionary
                guard let actual=attributes[kCTFontAttributeName] else{return nil}
                return CTFontCopyPostScriptName(actual as! CTFont) as String
            }
            var ascent:CGFloat=0,descent:CGFloat=0,leading:CGFloat=0
            let advance=CTLineGetTypographicBounds(line,&ascent,&descent,&leading)
            metrics.append(DockGlyphMetric(text:value,font:CTFontCopyPostScriptName(font) as String,advance:advance,ascent:ascent,descent:descent,runFonts:Array(Set(runFonts)).sorted()))
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
            let trackOpacity=recipe.trackOpacity ?? recipe.opacity
            guard trackOpacity.isFinite,(0...1).contains(trackOpacity) else{throw DockArtworkError.invalidManifest}
            c.setAlpha(trackOpacity)
            if arc?.fraction == nil,let dash=recipe.unknownDash {
                guard dash.count<=16,dash.allSatisfy({$0.isFinite && $0>0 && $0<=256}) else{throw DockArtworkError.invalidManifest}
                c.setLineDash(phase:0,lengths:dash)
            }
            c.setStrokeColor(try ink("track"));c.strokeEllipse(in:rect)
            c.setLineDash(phase:0,lengths:[]);c.setAlpha(recipe.opacity)
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
                if let n=station.overflowCount {try text("+\(n)",frame,station.placeholderText ?? skin.text,try ink("text"))}
                else if let label=station.placeholderLabel {try text(label,frame,station.placeholderText ?? skin.text,try ink("text"))}
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
            if let key=reading.vendorResourceKey,let resource=station.glyphs[key] {
                let opacity=station.glyphOpacity ?? 1
                guard opacity.isFinite,(0...1).contains(opacity) else{throw DockArtworkError.invalidManifest}
                c.saveGState();c.setAlpha(opacity);defer{c.restoreGState()};try image(resource,station.glyphRect)
            }
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
            let textColor=skin.readoutPalette?[reading.status.rawValue] ?? (reading.status == .warning || reading.status == .critical ? reading.status.rawValue : reading.status == .unknown ? "unknown":"text")
            if station.showsReadout != false {try text(reading.readout,station.readout,skin.text,try ink(textColor))}
            if let alias=reading.alias,let rect=station.aliasRect {try text(alias,rect,skin.aliasText,try ink("alias"))}
            if let notice=notices[id] {
                let palette=notice.tone == .amber ? "noticeAmber":notice.tone == .blue ? "noticeBlue":"noticeWhite"
                let diameter=(notice.shape == .solid ? station.eventSolidDiameter:station.eventHollowDiameter) ?? station.eventRect.width/2
                let stroke=station.eventStrokeWidth ?? 1.2
                guard diameter.isFinite,diameter>0,diameter<=station.eventRect.width,stroke.isFinite,stroke>0,stroke<=diameter else{throw DockArtworkError.invalidManifest}
                let r=CGRect(x:station.eventRect.midX-diameter/2,y:station.eventRect.midY-diameter/2,width:diameter,height:diameter)
                if notice.shape == .solid {
                    if let key=station.eventOutlineKey {
                        let width=station.eventSolidOutlineWidth ?? 0
                        guard width.isFinite,width>=0,width<=12 else{throw DockArtworkError.invalidManifest}
                        c.setFillColor(try ink(key));c.fillEllipse(in:r.insetBy(dx:-width,dy:-width))
                    }
                    c.setFillColor(try ink(palette));c.fillEllipse(in:r)
                } else {
                    if let key=station.eventBackdropKey {c.setFillColor(try ink(key));c.fillEllipse(in:r)}
                    c.setStrokeColor(try ink(palette));c.setLineWidth(stroke);c.strokeEllipse(in:r.insetBy(dx:stroke/2,dy:stroke/2))
                }
            }
        }
        guard let result=c.makeImage() else{throw DockArtworkError.invalidManifest}
        return DockRenderResult(image:result,metrics:metrics,scale:scale,effectsRendered:false)
    }
}
