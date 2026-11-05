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
public struct DockBitmapLayer: Codable, Sendable {public var resource:String;public var rect:CGRect;public var opacity:Double?}
public struct DockRingRecipe: Codable, Sendable {public var radius:CGFloat,width:CGFloat,minimumVisibleFraction:Double,opacity:Double;public var trackOpacity:Double?,unknownDash:[CGFloat]?}
public struct DockClockRecipe: Codable, Sendable {public var radius:CGFloat,dotRadius:CGFloat,backWidth:CGFloat;public var positions:Int}
/// Optional native equivalent of a supplied CSS radial alpha overlay.
public struct DockRadialOverlayRecipe: Codable, Sendable {public var radius: CGFloat; public var alphas: [CGFloat]}
public struct DockTextRecipe: Codable, Sendable {public var fontResource:String?;public var systemFontName:String?;public var useSystemUIFont:Bool?;public var language:String?;public var size:CGFloat,weight:Double}
/// Optional data-only style for a registered empty station.
public struct DockPlaceholderStyle: Codable, Sendable {
    public var fillKey: String, strokeKey: String, textKey: String
    public var strokeWidth: CGFloat, dash: [CGFloat]
}
public struct DockStationRecipe: Codable, Sendable {
    public var subscriptionID:String?
    public var logicalPoints:Int?
    public var centre:CGPoint,diameter:CGFloat,readout:CGRect,aliasRect:CGRect?,eventRect:CGRect
    public var layers:[String],glyphs:[String:String]
    public var glyphRect:CGRect
    public var outer:DockRingRecipe,inner:DockRingRecipe
    public var clock:DockClockRecipe
    public var notchWidth:CGFloat,caseInnerRadius:CGFloat
    /// Optional backing radius when the longer quota window is absent.
    public var singleWindowCaseInnerRadius:CGFloat?
    public var overflowCount:Int?
    public var overflowNoticeKey:String?
    public var eventSolidDiameter:CGFloat?,eventHollowDiameter:CGFloat?,eventStrokeWidth:CGFloat?
    public var glyphOpacity:Double?
    public var replacementResource:String?,readoutOpacity:Double?
    public var eventBackdropKey:String?,eventOutlineKey:String?,eventSolidOutlineWidth:CGFloat?
    public var radialOverlay: DockRadialOverlayRecipe?
    public var showsReadout:Bool?,placeholderLabel:String?,placeholderText:DockTextRecipe?
    public var placeholderStyle: DockPlaceholderStyle?
    public var fallbackVendorName:Bool?
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
/// Metadata captured by the successful drawing pass, never inferred from pixels.
public struct DockRenderedTextInspection {
    #if DEBUG
    public internal(set) var text=""
    public internal(set) var ink=DockInk(0,0,0,0)
    #endif
    public let frame: CGRect
    #if DEBUG
    /// Transform paired with the parent-space clip rectangle, before CoreText baseline/flip.
    public internal(set) var frameTransform = CGAffineTransform.identity
    #endif
    public let glyphTransform: CGAffineTransform
    /// This renderer paints text over the existing face; it paints no dedicated text backing.
    public let hasDedicatedBacking: Bool
}
public struct DockRenderedFaceInspection {
    public enum Source: String { case suppliedMaterial, bodyPolygon, none }
    public let source: Source
    public let materialSourceIdentity: String?
    public let materialLayerRoles: [String]
    public let pixelSize: CGSize
    public let fixedResources: [String]
}
/// Completed operations in this renderer; supplied material internals remain opaque.
public struct DockRenderedLayerRole {
    public let role: String, subscriptionID: String?, resource: String?
}
public struct DockRenderedResourceFilter {
    #if DEBUG
    public internal(set) var sourceIdentity:String?
    public internal(set) var drawingTransform=CGAffineTransform.identity
    #endif
    public let resource: String, subscriptionID: String?
    public let target: CGRect, interpolationQuality: CGInterpolationQuality
    public let preservesSourcePixels: Bool, fitsVisibleGlyph: Bool
}
public struct DockRenderedNozzleMaterial {
    public let frame: CGRect
    public let surfaceTransform: CGAffineTransform
    public let resources: [String], replacementResource: String?
    public let caseInk: DockInk?, radialOverlay: DockRadialOverlayRecipe?
}
public struct DockRenderedClockDots {
    public let positions: Int, litCentres: [CGPoint]
    public let radius: CGFloat, dotRadius: CGFloat, backingWidth: CGFloat
    public let ink: DockInk, backingInk: DockInk
}
/// Successful glyph/text operations; source-RGBA logos have no single invented tint.
public struct DockRenderedLogoInspection {
    public enum ColourTreatment: String { case sourceRGBA, paletteText }
    public let resource: String?, fallbackText: String?
    public let frame: CGRect, opacity: Double
    public let colourTreatment: ColourTreatment
    public let tint: DockInk?
}
public struct DockRenderedWidgetValue {
    public let text: String
    public let displayedPercent: Double?, remainingPercent: Double?, selectedWindowID: String?
    public let quotaRole: DockQuotaStatus
    public let colorRole: String, ink: DockInk
    public let opacity: Double
}
public struct DockRenderInspection {
    public let face: DockRenderedFaceInspection
    public let readouts: [String: DockRenderedTextInspection]
    public let aliases: [String: DockRenderedTextInspection]
    public let layerRoles: [DockRenderedLayerRole], resourceFilters: [DockRenderedResourceFilter]
    public let nozzles: [String: DockRenderedNozzleMaterial], clockDots: [String: DockRenderedClockDots]
    public let logos: [String: DockRenderedLogoInspection], widgetValues: [String: DockRenderedWidgetValue]
}
public struct DockRenderResult {public let image:CGImage;public let backgroundImage:CGImage;public let metrics:[DockGlyphMetric];public let scale:Int;public let effectsRendered:Bool;public let inspection:DockRenderInspection}

@MainActor public final class DockInstrumentRenderer {
    /// Static material only. Reading text, quotas and vendor identity remain in
    /// the instrument pass so a clear can retire them independently.
    public typealias Material = @MainActor (DockInstrumentSkin, Int) throws -> CGImage
    private let resources:DockArtworkStore
    private let supplementalResources:DockArtworkStore?
    private let material:Material?
    private let materialSourceIdentity: String?
    private let materialLayerRoles: @MainActor () -> [String]
    public init(resources:DockArtworkStore, supplementalResources:DockArtworkStore? = nil, materialSourceIdentity: String? = nil,
                materialLayerRoles: @escaping @MainActor () -> [String] = { [] }, material:Material? = nil) {
        self.resources=resources;self.supplementalResources=supplementalResources;self.material=material
        self.materialSourceIdentity=materialSourceIdentity;self.materialLayerRoles=materialLayerRoles
    }
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
        c.translateBy(x:-skin.bounds.minX,y:-skin.bounds.minY)
        c.setAllowsAntialiasing(true);c.setShouldAntialias(true);c.interpolationQuality = .high
        func ink(_ name:String) throws -> CGColor {guard let v=skin.palette[name],v.valid else{throw DockArtworkError.invalidManifest};return v.cg}
        var layerRoles = [DockRenderedLayerRole](), resourceFilters = [DockRenderedResourceFilter]()
        var nozzleMaterials = [String:DockRenderedNozzleMaterial](), clockDots = [String:DockRenderedClockDots]()
        var logos = [String:DockRenderedLogoInspection](), widgetValues = [String:DockRenderedWidgetValue]()
        func role(_ name: String, _ id: String? = nil, resource: String? = nil) { layerRoles.append(.init(role:name,subscriptionID:id,resource:resource)) }
        func image(_ resource:String,_ rect:CGRect,preserveSourcePixels:Bool = false,fitVisibleGlyph:Bool = false,role imageRole:String="bitmap",subscriptionID:String?=nil) throws {
            guard rect.minX.isFinite,rect.minY.isFinite,rect.width>0,rect.height>0,rect.width<=4096,rect.height<=4096 else{throw DockArtworkError.invalidManifest}
            let size=Int(ceil(max(rect.width,rect.height)*CGFloat(scale)))
            let image: CGImage
            #if DEBUG
            var observedSource=resources
            #endif
            do { image = try fitVisibleGlyph ? resources.fittedGlyph(resource,targetPixelSize:max(1,size)) : resources.image(resource,maximumPixelSize:max(1,size),preserveSourcePixels:preserveSourcePixels) }
            catch DockArtworkError.missingResource {
                guard let supplementalResources else { throw DockArtworkError.missingResource(resource) }
                #if DEBUG
                observedSource=supplementalResources
                #endif
                image = try fitVisibleGlyph ? supplementalResources.fittedGlyph(resource,targetPixelSize:max(1,size)) : supplementalResources.image(resource,maximumPixelSize:max(1,size),preserveSourcePixels:preserveSourcePixels)
            }
            // Static SVG marks retain their intrinsic aspect ratio in the square
            // placement box, matching SVG's default xMidYMid meet behavior.
            let isVector = resources.isVectorResource(resource) ?? supplementalResources?.isVectorResource(resource) ?? false
            let drawSize: CGSize
            if isVector || fitVisibleGlyph {
                guard fitVisibleGlyph || max(image.width,image.height) >= size else { throw DockArtworkError.corruptResource(resource) }
                let fit = min(rect.width / CGFloat(image.width), rect.height / CGFloat(image.height))
                drawSize = CGSize(width:CGFloat(image.width)*fit,height:CGFloat(image.height)*fit)
            } else {
                guard image.width>=Int(ceil(rect.width*CGFloat(scale))),image.height>=Int(ceil(rect.height*CGFloat(scale))) else{throw DockArtworkError.corruptResource(resource)}
                drawSize = rect.size
            }
            let target = CGRect(x:rect.midX-drawSize.width/2,y:rect.midY-drawSize.height/2,width:drawSize.width,height:drawSize.height)
            c.saveGState();c.clip(to:rect)
            // SVG marks are already rasterized at the requested backing scale;
            // do not blur them a second time when placing the checked pixels.
            if isVector || fitVisibleGlyph { c.interpolationQuality = .none }
            c.translateBy(x:target.minX,y:target.maxY);c.scaleBy(x:1,y:-1)
            let interpolation = c.interpolationQuality
            c.draw(image,in:CGRect(origin:.zero,size:target.size));c.restoreGState()
            var observation=DockRenderedResourceFilter(resource:resource,subscriptionID:subscriptionID,target:target,interpolationQuality:interpolation,preservesSourcePixels:preserveSourcePixels,fitsVisibleGlyph:fitVisibleGlyph)
            #if DEBUG
            observation.sourceIdentity=observedSource.g1ResourceIdentity(resource)
            observation.drawingTransform=c.ctm
            #endif
            resourceFilters.append(observation)
            role(imageRole,subscriptionID,resource:resource)
        }
        if let material {
            let backing = try material(skin, scale)
            guard backing.width == width, backing.height == height else { throw DockArtworkError.invalidManifest }
            c.saveGState();c.translateBy(x:skin.bounds.minX,y:skin.bounds.maxY);c.scaleBy(x:1,y:-1)
            c.draw(backing,in:CGRect(origin:.zero,size:skin.bounds.size));c.restoreGState(); role("face.supplied-material")
        } else if !skin.bodyPolygon.isEmpty {
            c.addLines(between:skin.bodyPolygon);c.closePath();c.setFillColor(try ink("body"));c.fillPath(); role("face.body-polygon")
        }
        for fixed in skin.fixedLayers {
            let opacity = fixed.opacity ?? 1
            guard opacity.isFinite, (0...1).contains(opacity) else { throw DockArtworkError.invalidManifest }
            c.saveGState(); c.setAlpha(opacity)
            do { try image(fixed.resource,fixed.rect,preserveSourcePixels:true,role:"fixed-resource"); c.restoreGState() }
            catch { c.restoreGState(); throw error }
        }
        // Retain only material/fixed art for a failed data/profile transaction, never old readings.
        guard let backgroundImage = c.makeImage() else { throw DockArtworkError.invalidManifest }
        var metrics=[DockGlyphMetric](), readouts=[String:DockRenderedTextInspection](), aliases=[String:DockRenderedTextInspection]()
        @discardableResult func text(_ value:String,_ rect:CGRect,_ recipe:DockTextRecipe,_ color:CGColor) throws -> DockRenderedTextInspection {
            guard recipe.language.map({!$0.isEmpty && $0.utf8.count<=64}) ?? true, value.utf8.count<=1024,recipe.size.isFinite,(1...128).contains(recipe.size),rect.width>0,rect.height>0 else{throw DockArtworkError.invalidManifest}
            let font:CTFont
            if let id=recipe.fontResource {
                do { font = try resources.font(id,size:recipe.size,weight:recipe.weight) }
                catch DockArtworkError.missingResource {
                    guard let supplementalResources else { throw DockArtworkError.missingResource(id) }
                    font = try supplementalResources.font(id,size:recipe.size,weight:recipe.weight)
                }
            }
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
            #if DEBUG
            let frameTransform=c.ctm
            #endif
            c.saveGState();c.clip(to:rect)
            let baseline=rect.midY+(ascent-descent)/2
            c.translateBy(x:rect.midX-CGFloat(advance)/2,y:baseline);c.scaleBy(x:1,y:-1);c.textMatrix = .identity
            var observation = DockRenderedTextInspection(frame:rect,glyphTransform:c.ctm,hasDedicatedBacking:false)
            #if DEBUG
            observation.frameTransform=frameTransform
            let channels=color.components!
            observation.text=value;observation.ink = .init(Double(channels[0]),Double(channels[1]),Double(channels[2]),Double(channels[3]))
            #endif
            c.textPosition = .zero;CTLineDraw(line,c);c.restoreGState()
            return observation
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
        func drawNotice(_ notice: DockNotice, _ station: DockStationRecipe) throws {
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
                role("notice",station.subscriptionID)
        }
        for station in skin.stations {
            guard station.diameter.isFinite,(8...256).contains(station.diameter),station.clock.positions>0,station.clock.positions<=128 else{throw DockArtworkError.invalidManifest}
            let frame=CGRect(x:station.centre.x-station.diameter/2,y:station.centre.y-station.diameter/2,width:station.diameter,height:station.diameter)
            if let label = station.placeholderLabel, let style = station.placeholderStyle {
                guard style.strokeWidth.isFinite, style.strokeWidth > 0, style.strokeWidth <= station.diameter,
                      !style.dash.isEmpty, style.dash.count <= 16,
                      style.dash.allSatisfy({ $0.isFinite && $0 > 0 && $0 <= station.diameter }) else { throw DockArtworkError.invalidManifest }
                c.saveGState(); c.setFillColor(try ink(style.fillKey)); c.fillEllipse(in: frame)
                c.setStrokeColor(try ink(style.strokeKey)); c.setLineWidth(style.strokeWidth); c.setLineDash(phase: 0, lengths: style.dash)
                c.strokeEllipse(in: frame.insetBy(dx: style.strokeWidth / 2, dy: style.strokeWidth / 2)); c.restoreGState()
                role("empty-station.backing"); try text(label, frame, station.placeholderText ?? skin.text, try ink(style.textKey)); role("empty-station.label")
                continue
            }
            if station.replacementResource == nil {
                for layer in station.layers { try image(layer,frame,role:"nozzle-resource",subscriptionID:station.subscriptionID) }
                if let overlay = station.radialOverlay {
                    guard overlay.radius.isFinite, overlay.radius > 0, overlay.radius <= station.diameter,
                          overlay.alphas.count >= 2, overlay.alphas.count <= 128,
                          overlay.alphas.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else { throw DockArtworkError.invalidManifest }
                    let space = CGColorSpace(name: CGColorSpace.sRGB)!
                    let colors = overlay.alphas.map { CGColor(colorSpace: space, components: [0,0,0,$0])! }
                    let locations = overlay.alphas.indices.map { CGFloat($0) / CGFloat(overlay.alphas.count - 1) }
                    guard let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations) else { throw DockArtworkError.invalidManifest }
                    c.saveGState(); c.clip(to: frame)
                    c.drawRadialGradient(gradient, startCenter: station.centre, startRadius: 0,
                                         endCenter: station.centre, endRadius: overlay.radius,
                                         options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                    c.restoreGState(); role("nozzle.radial-overlay",station.subscriptionID)
                }
            }
            guard let id=station.subscriptionID,let reading=readings[id] else {
                if let n=station.overflowCount {
                    try text("+\(n)",frame,station.placeholderText ?? skin.text,try ink("text")); role("overflow.label")
                    if let key=station.overflowNoticeKey, let notice=notices[key] { try drawNotice(notice, station) }
                }
                else if let label=station.placeholderLabel {try text(label,frame,station.placeholderText ?? skin.text,try ink("text")); role("placeholder.label")}
                continue
            }
            if let replacement=station.replacementResource {try image(replacement,frame,role:"nozzle-replacement",subscriptionID:id)} else {
            let radius = reading.inner == nil ? (station.singleWindowCaseInnerRadius ?? station.caseInnerRadius) : station.caseInnerRadius
            guard radius.isFinite,radius>=0,radius<station.diameter/2 else{throw DockArtworkError.invalidManifest}
            c.setLineWidth(station.diameter/2-radius);c.setStrokeColor(try ink("case"))
            let rr=(radius+station.diameter/2)/2
            c.strokeEllipse(in:CGRect(x:station.centre.x-rr,y:station.centre.y-rr,width:2*rr,height:2*rr)); role("nozzle.case",id)
            try ring(station.outer,reading.outer,station.centre); role("quota.outer",id)
            if reading.inner != nil {try ring(station.inner,reading.inner,station.centre); role("quota.inner",id)}
            if station.notchWidth>0 {
                c.setLineWidth(station.notchWidth);c.setStrokeColor(try ink("notch"))
                c.move(to:CGPoint(x:station.centre.x,y:station.centre.y-station.diameter/2))
                c.addLine(to:CGPoint(x:station.centre.x,y:station.centre.y-radius));c.strokePath(); role("nozzle.notch",id)
            }
            if let key=reading.vendorResourceKey,let resource=station.glyphs[key] {
                let opacity=station.glyphOpacity ?? 1
                guard opacity.isFinite,(0...1).contains(opacity) else{throw DockArtworkError.invalidManifest}
                c.saveGState();c.setAlpha(opacity);defer{c.restoreGState()};try image(resource,station.glyphRect,fitVisibleGlyph:true,role:"vendor-glyph",subscriptionID:id)
                logos[id] = .init(resource:resource,fallbackText:nil,frame:resourceFilters.last?.target ?? station.glyphRect,
                    opacity:opacity,colourTreatment:.sourceRGBA,tint:nil)
            } else if station.fallbackVendorName == true {
                try text(reading.name, station.glyphRect, skin.aliasText, try ink("text")); role("vendor-name",id)
                logos[id] = .init(resource:nil,fallbackText:reading.name,frame:station.glyphRect,opacity:1,
                    colourTreatment:.paletteText,tint:skin.palette["text"])
            }
            }
            nozzleMaterials[id] = .init(frame:frame,surfaceTransform:c.ctm,resources:station.replacementResource.map { [$0] } ?? station.layers,replacementResource:station.replacementResource,caseInk:station.replacementResource == nil ? skin.palette["case"]:nil,radialOverlay:station.replacementResource == nil ? station.radialOverlay:nil)
            if reading.timeLeftFraction != nil {
                let clock=station.clock,r=clock.radius
                guard r>0,r.isFinite,clock.dotRadius>0,clock.backWidth>=0 else{throw DockArtworkError.invalidManifest}
                c.setLineWidth(clock.backWidth);c.setStrokeColor(try ink("clockBack"))
                c.strokeEllipse(in:CGRect(x:station.centre.x-r,y:station.centre.y-r,width:2*r,height:2*r))
                role("clock.backing",id)
                let count=reading.litTimePoints(positions:clock.positions) ?? 0
                var centres = [CGPoint]()
                c.setFillColor(try ink("clock"))
                for i in 0..<count {let a=Double(i)*2 * .pi/Double(clock.positions)
                    let p=CGPoint(x:station.centre.x+sin(a)*r,y:station.centre.y-cos(a)*r)
                    c.fillEllipse(in:CGRect(x:p.x-clock.dotRadius,y:p.y-clock.dotRadius,width:2*clock.dotRadius,height:2*clock.dotRadius));centres.append(p)}
                if count > 0 { role("clock.dots",id) }
                clockDots[id] = .init(positions:clock.positions,litCentres:centres,radius:r,dotRadius:clock.dotRadius,backingWidth:clock.backWidth,ink:skin.palette["clock"]!,backingInk:skin.palette["clockBack"]!)
            }
            let textColor=skin.readoutPalette?[reading.status.rawValue] ?? (reading.status == .warning || reading.status == .critical ? reading.status.rawValue : reading.status == .unknown ? "unknown":"text")
            if station.showsReadout != false {
                let opacity=station.readoutOpacity ?? 1
                guard opacity.isFinite,(0...1).contains(opacity) else{throw DockArtworkError.invalidManifest}
                c.saveGState();c.setAlpha(opacity);defer{c.restoreGState()};readouts[id] = try text(reading.readout,station.readout,skin.text,try ink(textColor)); role("readout",id)
                widgetValues[id] = .init(text:reading.readout,
                    displayedPercent:reading.readout.hasSuffix("%") ? Double(reading.readout.dropLast()):nil,
                    remainingPercent:reading.remainingPercent,selectedWindowID:reading.selectedWindowID,
                    quotaRole:reading.status,colorRole:textColor,ink:skin.palette[textColor]!,opacity:opacity)
            }
            if let alias=reading.alias,let rect=station.aliasRect {aliases[id] = try text(alias,rect,skin.aliasText,try ink("alias")); role("alias",id)}
            if let notice=notices[id] { try drawNotice(notice, station) }
        }
        guard let result=c.makeImage() else{throw DockArtworkError.invalidManifest}
        return DockRenderResult(image:result,backgroundImage:backgroundImage,metrics:metrics,scale:scale,effectsRendered:false,
            inspection: .init(face: .init(source: material != nil ? .suppliedMaterial : skin.bodyPolygon.isEmpty ? .none : .bodyPolygon, materialSourceIdentity: material != nil ? materialSourceIdentity:nil, materialLayerRoles: material != nil ? materialLayerRoles():[], pixelSize: .init(width: width, height: height), fixedResources: skin.fixedLayers.map(\.resource)), readouts: readouts, aliases: aliases, layerRoles:layerRoles, resourceFilters:resourceFilters, nozzles:nozzleMaterials, clockDots:clockDots, logos:logos, widgetValues:widgetValues))
    }
}
