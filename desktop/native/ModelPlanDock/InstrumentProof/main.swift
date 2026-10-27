// SPDX-License-Identifier: MIT
import Foundation
import AppKit
import CoreGraphics
import QuartzCore
import CoreText
import CryptoKit
import ImageIO
import ModelPlanPrimitives
#if canImport(ModelPlanDock)
@_spi(DockResourceChecks) import ModelPlanDock
#endif

@MainActor final class SyntheticDockFrameProvider:EffectFrameProvider {
    let identifier="org.modelplan.neutral-dock-check",revision="one"
    var draws=0
    func draw(pose:Int,request:EffectFrameRequest,in context:CGContext)throws {
        draws+=1;context.setFillColor(CGColor(gray:0.2+Double(pose)/20,alpha:0.5))
        context.fillEllipse(in:CGRect(x:2,y:2,width:context.width-4,height:context.height-4))
    }
}
@MainActor final class NeutralEdgeScheduler:DockEdgeScheduling {
    var deadline:TimeInterval?,pending:(@MainActor ()->Void)?,saved=[@MainActor ()->Void]()
    func arm(at deadline:TimeInterval,_ action:@escaping @MainActor ()->Void){self.deadline=deadline;pending=action;saved.append(action)}
    func cancel(){deadline=nil;pending=nil}
    func fire(){let action=pending;pending=nil;action?()}
}
struct NativeFailure:Error {let message:String}
@MainActor func nativeChecks(_ root:URL) throws {
    var checks=0
    func require(_ condition:Bool,_ message:String)throws{checks+=1;if !condition{throw NativeFailure(message:message)}}
    try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
    let imageURL=root.appendingPathComponent("synthetic.png")
    let context=CGContext(data:nil,width:32,height:32,bitsPerComponent:8,bytesPerRow:0,
        space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(CGColor(gray:0.5,alpha:1));context.fill(CGRect(x:0,y:0,width:32,height:32))
    let writer=CGImageDestinationCreateWithURL(imageURL as CFURL,"public.png" as CFString,1,nil)!
    CGImageDestinationAddImage(writer,context.makeImage()!,nil);try require(CGImageDestinationFinalize(writer),"own synthetic PNG")
    let data=try Data(contentsOf:imageURL), hash=SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()
    let file=DockResourceFile(path:"synthetic.png",sha256:hash,bytes:data.count)
    let store=try DockArtworkStore(root:root,manifest:DockResourceManifest(files:["test":file]))
    let one=try store.image("test",maximumPixelSize:32), two=try store.image("test",maximumPixelSize:32)
    try require(one === two,"same counted resource reused")
    try require(store.decodedBytes==one.bytesPerRow*one.height,"actual decoded row accounting")
    store.purge();try require(store.decodedBytes==0,"purge releases retained decoded resources")
    let tiny=try DockArtworkStore(root:root,manifest:DockResourceManifest(files:["test":file]),decodedBudget:32)
    do{_=try tiny.image("test",maximumPixelSize:32);throw NativeFailure(message:"oversized admission succeeded")}
    catch DockArtworkError.decodedBudget{checks+=1}
    let bad=try DockArtworkStore(root:root,manifest:DockResourceManifest(files:["test":DockResourceFile(path:"synthetic.png",sha256:String(repeating:"0",count:64),bytes:data.count)]))
    do{_=try bad.image("test",maximumPixelSize:32);throw NativeFailure(message:"bad digest admitted")}
    catch DockArtworkError.corruptResource{checks+=1}
    let traversal=try DockArtworkStore(root:root,manifest:DockResourceManifest(files:["test":DockResourceFile(path:"../synthetic.png",sha256:hash,bytes:data.count)]))
    do{_=try traversal.checkedURL("test");throw NativeFailure(message:"path escape admitted")}
    catch DockArtworkError.outsideRoot{checks+=1}
    let svg=Data("<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32'><circle cx='16' cy='16' r='14' fill='#888888'/></svg>".utf8)
    let vectorURL=root.appendingPathComponent("synthetic.svg");try svg.write(to:vectorURL)
    let svgFile=DockResourceFile(path:"synthetic.svg",sha256:SHA256.hash(data:svg).map{String(format:"%02x",$0)}.joined(),bytes:svg.count)
    let vectors=try DockArtworkStore(root:root,manifest:DockResourceManifest(files:["vector":svgFile]))
    let vector=try vectors.image("vector",maximumPixelSize:64)
    try require(vector.width==64 && vector.height==64,"native SVG raster uses explicit physical dimensions")
    // Neutral intrinsic-white input: no vendor contour or official visual is embedded here.
    let viewBox=Data("<svg xmlns='http://www.w3.org/2000/svg' viewBox='-2,-2 28 28'><rect width='24' height='24' fill='#ffffff'/></svg>".utf8)
    try require(try DockStaticSVG.size(viewBox)==CGSize(width:28,height:28),"viewBox-only intrinsic size with negative origin")
    try viewBox.write(to:root.appendingPathComponent("viewbox.svg"))
    let viewBoxFile=DockResourceFile(path:"viewbox.svg",sha256:SHA256.hash(data:viewBox).map{String(format:"%02x",$0)}.joined(),bytes:viewBox.count)
    let intrinsic=try DockArtworkStore(root:root,manifest:DockResourceManifest(files:["white":viewBoxFile]))
    for pixels in [20,40] {
        let image=try intrinsic.image("white",maximumPixelSize:pixels)
        try require(image.width==pixels && image.height==pixels,"viewBox-only native 1x/2x card mark dimensions")
        let sample=CGContext(data:nil,width:pixels,height:pixels,bitsPerComponent:8,bytesPerRow:pixels*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Big.rawValue|CGImageAlphaInfo.premultipliedLast.rawValue)!
        sample.draw(image,in:CGRect(x:0,y:0,width:pixels,height:pixels))
        let b=sample.data!.assumingMemoryBound(to:UInt8.self),i=(pixels/2*pixels+pixels/2)*4
        try require(b[i]==255 && b[i+1]==255 && b[i+2]==255 && b[i+3]==255,"intrinsic white is not tinted")
        try require(try intrinsic.image("white",maximumPixelSize:pixels) === image,"viewBox raster cache reused")
    }
    try require(intrinsic.decodedBytes>0 && intrinsic.decodedBytes<=16*1024*1024,"viewBox images use counted cache")
    intrinsic.purge();try require(intrinsic.decodedBytes==0,"viewBox cache purges")
    for attributes in ["", "width='28'", "height='28'", "width='bad' height='28' viewBox='0 0 28 28'", "viewBox='0 0 0 28'", "viewBox='0 0 -1 28'", "viewBox='0 0 28 4097'", "viewBox='nan 0 28 28'", "viewBox='4097 0 28 28'", "viewBox='inf 0 28 28'", "viewBox='0 0 1e-320 28'", "viewBox='0 0 28'", "viewBox='0 0 28 28 0'", "width='28' height='28' viewBox='0 0 -1 28'"] {
        let input=Data("<svg xmlns='http://www.w3.org/2000/svg' \(attributes)><rect width='1' height='1'/></svg>".utf8)
        do{_=try DockStaticSVG.size(input);throw NativeFailure(message:"invalid intrinsic viewport admitted: \(attributes)")}
        catch DockArtworkError.invalidManifest{checks+=1}
    }
    let normalisedTiny=try DockStaticSVG.pixelSize(CGSize(width:1e-200,height:1e-200),maximumPixelSize:64)
    try require(normalisedTiny.width==64 && normalisedTiny.height==64,"tiny normal dimensions normalise without reciprocal overflow")
    let thin=try DockStaticSVG.pixelSize(CGSize(width:1e-200,height:4096),maximumPixelSize:4096)
    try require(thin.width==1 && thin.height==4096,"extreme normal aspect remains a bounded one-pixel axis")
    for (index,dimensions) in [(0.0,32.0),(32,0),(-1,32),(32,-1),(Double.nan,32),(32,Double.nan),(Double.infinity,32),(32,Double.infinity),(1e-320,1e-320),(1e-320,4096),(4096,1e-320),(4097,32),(32,4097)].enumerated() {
        let (w,h)=dimensions
        let data=Data("<svg xmlns='http://www.w3.org/2000/svg' width='\(w)' height='\(h)' viewBox='0 0 1 1'><rect width='1' height='1'/></svg>".utf8)
        let name="invalid-size-\(index).svg";try data.write(to:root.appendingPathComponent(name))
        let entry=DockResourceFile(path:name,sha256:SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined(),bytes:data.count)
        let bounded=try DockArtworkStore(root:root,manifest:DockResourceManifest(files:["invalid":entry]))
        do{_=try bounded.image("invalid",maximumPixelSize:64);throw NativeFailure(message:"invalid SVG size reached store rasterisation")}
        catch DockArtworkError.invalidManifest{checks+=1}
        do{_=try DockStaticSVG.image(data,size:CGSize(width:w,height:h),maximumPixelSize:64);throw NativeFailure(message:"invalid SVG size reached direct rasterisation")}
        catch DockArtworkError.invalidManifest{checks+=1}
    }
    for (index,dimensions) in [(1e-200,1e-200),(1e-200,4096.0)].enumerated() {
        let (w,h)=dimensions,data=Data("<svg xmlns='http://www.w3.org/2000/svg' width='\(w)' height='\(h)' viewBox='0 0 1 1'><rect width='1' height='1'/></svg>".utf8)
        let name="tiny-normal-\(index).svg";try data.write(to:root.appendingPathComponent(name))
        let spec=DockResourceFile(path:name,sha256:SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined(),bytes:data.count)
        let source=try DockArtworkStore(root:root,manifest:DockResourceManifest(files:["tiny":spec]))
        let expected=try DockStaticSVG.pixelSize(CGSize(width:w,height:h),maximumPixelSize:64)
        do{let image=try source.image("tiny",maximumPixelSize:64);try require(image.width==expected.width && image.height==expected.height,"store tiny-normal raster remains bounded")}
        catch DockArtworkError.invalidManifest{checks+=1} // An unsupported AppKit representation is a safe typed rejection.
        do{let image=try DockStaticSVG.image(data,size:CGSize(width:w,height:h),maximumPixelSize:64);try require(image.width==expected.width && image.height==expected.height,"direct tiny-normal raster remains bounded")}
        catch DockArtworkError.invalidManifest{checks+=1}
    }
    for maxPixels in [0,-1,4097,Int.max] {
        do{_=try DockStaticSVG.pixelSize(CGSize(width:32,height:32),maximumPixelSize:maxPixels);throw NativeFailure(message:"unbounded pixel request admitted")}
        catch DockArtworkError.invalidManifest{checks+=1}
        do{_=try DockStaticSVG.image(svg,size:CGSize(width:32,height:32),maximumPixelSize:maxPixels);throw NativeFailure(message:"direct unbounded pixel request admitted")}
        catch DockArtworkError.invalidManifest{checks+=1}
    }
    let wide=Data("<svg xmlns='http://www.w3.org/2000/svg' width='4096' height='1' viewBox='0 0 4096 1'><rect width='4096' height='1' fill='#888888'/></svg>".utf8)
    try wide.write(to:root.appendingPathComponent("boundary.svg"))
    let wideSpec=DockResourceFile(path:"boundary.svg",sha256:SHA256.hash(data:wide).map{String(format:"%02x",$0)}.joined(),bytes:wide.count)
    let wideStore=try DockArtworkStore(root:root,manifest:DockResourceManifest(files:["wide":wideSpec]))
    let storedWide=try wideStore.image("wide",maximumPixelSize:4096),directWide=try DockStaticSVG.image(wide,size:CGSize(width:4096,height:1),maximumPixelSize:4096)
    try require(storedWide.width==4096 && storedWide.height==1,"store accepts exact4096 boundary without unsafe allocation")
    try require(directWide.width==4096 && directWide.height==1,"direct decoder uses same exact4096 bounded dimensions")
    let unsafe=Data("<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32'><image href='https://example.invalid/x.png'/></svg>".utf8)
    let unsafeURL=root.appendingPathComponent("external.svg");try unsafe.write(to:unsafeURL)
    let unsafeFile=DockResourceFile(path:"external.svg",sha256:SHA256.hash(data:unsafe).map{String(format:"%02x",$0)}.joined(),bytes:unsafe.count)
    let rejectVector=try DockArtworkStore(root:root,manifest:DockResourceManifest(files:["vector":unsafeFile]))
    do{_=try rejectVector.image("vector",maximumPixelSize:64);throw NativeFailure(message:"external SVG reference admitted")}
    catch DockArtworkError.invalidManifest{checks+=1}
    let palette=Dictionary(uniqueKeysWithValues:["body","case","track","notch","clockBack","clock","text","unknown","normal","warning","critical","alias","noticeAmber","noticeBlue","noticeWhite"].map{($0,DockInk($0=="body" ? 0.08:0.9,$0=="body" ? 0.08:0.9,$0=="body" ? 0.08:0.9))})
    let inks=try JSONSerialization.jsonObject(with:JSONEncoder().encode(palette))
    let json:[String:Any]=["schemaVersion":1,"bounds":[[0,0],[96,96]],
        "bodyPolygon":[[0,0],[96,0],[96,96],[0,96]],"fixedLayers":[],"palette":inks,
        "text":["size":11,"weight":400],"aliasText":["size":10,"weight":400],
        "stations":[["subscriptionID":"sub","centre":[48,30],"diameter":24,
            "readout":[[20,50],[56,16]],"eventRect":[[64,52],[12,12]],"glyphRect":[[36,18],[24,24]],
            "layers":[],"glyphs":[:],"outer":["radius":10,"width":2,"minimumVisibleFraction":0,"opacity":1],
            "inner":["radius":7,"width":1,"minimumVisibleFraction":0,"opacity":1],
            "clock":["radius":14,"dotRadius":0.5,"backWidth":1,"positions":10],"notchWidth":1,"caseInnerRadius":5]]]
    let skin=try JSONDecoder().decode(DockInstrumentSkin.self,from:JSONSerialization.data(withJSONObject:json))
    let instant=Date(timeIntervalSince1970:1_700_000_000)
    var input=DockInstrumentInput(id:"sub",name:"Synthetic",windows:[DockQuotaWindowInput(id:"short",period:.fiveHour,label:"5h",remainingPercent:25,resetsAt:instant.addingTimeInterval(9000),durationSeconds:18000)])
    input.dataState = .fresh
    let renderer=DockInstrumentRenderer(resources:store),reading=try DockInstrumentProjection.evaluate(input,now:instant)
    for scale in [1,2] {
        let result=try renderer.render(skin:skin,readings:["sub":reading],scale:scale)
        try require(result.image.width==96*scale && result.image.height==96*scale,"genuine physical pixel dimensions")
        try require(result.metrics.contains{$0.text=="25%" && $0.advance>0},"native CoreText data rendering")
        try require(!result.effectsRendered,"static capture does not claim pooled effects")
    }
    for diameter:CGFloat in [36,44,52] {
        let scaledView=DockInstrumentView(frame:.zero);scaledView.requestedNozzleDiameter=diameter
        try scaledView.applyOfficial(skin:skin,rows:[reading],renderer:renderer,scale:2,locale:"en")
        let factor=diameter/24
        try require(scaledView.presentedNozzleDiameters==[diameter],"requested S/M/L nozzle size reaches the actual rendered recipe")
        try require(abs(scaledView.frame.width-96*factor)<0.0001,"full hull envelope scales with the nozzle")
        let scaled=try skin.scaled(by:factor)
        try require(abs(scaled.stations[0].outer.width-2*factor)<0.0001 && abs(scaled.text.size-11*factor)<0.0001,"rings and text share the geometry scale")
        scaledView.dispose()
    }
    // Neutral precomposited control: preserve source alpha, downsample once at destination scale.
    let controlContext=CGContext(data:nil,width:180,height:180,bitsPerComponent:8,bytesPerRow:720,
        space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Big.rawValue|CGImageAlphaInfo.premultipliedLast.rawValue)!
    controlContext.setShouldAntialias(true)
    // Declare the fixture in the same sRGB space; generic RGB color matching may add green.
    controlContext.setFillColor(CGColor(colorSpace:CGColorSpace(name:CGColorSpace.sRGB)!,components:[1,0,0,1])!)
    controlContext.fillEllipse(in:CGRect(x:9,y:9,width:162,height:162))
    let controlURL=root.appendingPathComponent("neutral-control.png")
    let controlWriter=CGImageDestinationCreateWithURL(controlURL as CFURL,"public.png" as CFString,1,nil)!
    CGImageDestinationAddImage(controlWriter,controlContext.makeImage()!,nil)
    try require(CGImageDestinationFinalize(controlWriter),"neutral source control PNG")
    let controlData=try Data(contentsOf:controlURL)
    let controlFile=DockResourceFile(path:"neutral-control.png",sha256:SHA256.hash(data:controlData).map{String(format:"%02x",$0)}.joined(),bytes:controlData.count)
    let controlStore=try DockArtworkStore(root:root,manifest:DockResourceManifest(files:["control":controlFile]))
    let sourceControl=try controlStore.image("control",maximumPixelSize:23,preserveSourcePixels:true)
    try require(sourceControl.width==180 && sourceControl.height==180,"control keeps original pixels until final composition")
    try require(try controlStore.image("control",maximumPixelSize:46,preserveSourcePixels:true) === sourceControl,"source control has one counted cache entry across backing scales")
    var controlSkin=skin;controlSkin.bodyPolygon=[];controlSkin.stations=[]
    controlSkin.fixedLayers=try JSONDecoder().decode([DockBitmapLayer].self,from:Data(#"[{"resource":"control","rect":[[13.25,9.5],[22.5,22.5]]}]"#.utf8))
    let controlRenderer=DockInstrumentRenderer(resources:controlStore)
    for scale in [1,2] {
        let rendered=try controlRenderer.render(skin:controlSkin,readings:[:],scale:scale).image
        let pixels=rendered.dataProvider!.data!,bytes=CFDataGetBytePtr(pixels)!
        let alphas=(0..<rendered.height).flatMap { y in (0..<rendered.width).map { x in bytes[y*rendered.bytesPerRow+x*4+3] } }
        try require(alphas.contains{ $0>0 && $0<255 },"fractional control edge retains antialias coverage at 1x and 2x")
        try require(bytes[3]==0,"source transparent margin stays transparent")
        for y in 0..<rendered.height { for x in 0..<rendered.width {
            let offset=y*rendered.bytesPerRow+x*4
            if bytes[offset+3]>0 {
                try require(bytes[offset]>=bytes[offset+3]-1 && bytes[offset+1]==0 && bytes[offset+2]==0,"premultiplied source edge has no dark fringe: scale=\(scale) x=\(x) y=\(y) rgba=\(bytes[offset]),\(bytes[offset+1]),\(bytes[offset+2]),\(bytes[offset+3]) sourceSpace=\(String(describing:sourceControl.colorSpace?.name))")
            }
        } }
        let scaledView=DockInstrumentView(frame:.zero);scaledView.presentationBackingScale=scale
        try scaledView.applyOfficial(skin:controlSkin,rows:[],renderer:controlRenderer,scale:3-scale,locale:"en")
        try require(scaledView.renderedPixelSize==CGSize(width:96*scale,height:96*scale),"destination backing overrides a stale supplier scale")
        scaledView.dispose()
    }
    // Reuse one offscreen backing context to expose alpha accumulation during repeated redraws.
    let materialView=DockInstrumentView(frame:.zero)
    try materialView.applyOfficial(skin:controlSkin,rows:[],renderer:controlRenderer,scale:1,locale:"en")
    let materialContext=CGContext(data:nil,width:96,height:96,bitsPerComponent:8,bytesPerRow:384,
        space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Big.rawValue|CGImageAlphaInfo.premultipliedLast.rawValue)!
    func drawMaterial(_ view:DockInstrumentView)->Data {
        NSGraphicsContext.saveGraphicsState();defer{NSGraphicsContext.restoreGraphicsState()}
        NSGraphicsContext.current=NSGraphicsContext(cgContext:materialContext,flipped:true)
        view.draw(view.bounds)
        return Data(bytes:materialContext.data!,count:materialContext.bytesPerRow*materialContext.height)
    }
    let firstMaterial=drawMaterial(materialView)
    for appearance in [NSAppearance.Name.aqua,.darkAqua,.aqua] {
        materialView.appearance=NSAppearance(named:appearance)
        materialView.isHidden=true;materialView.isHidden=false
        try require(drawMaterial(materialView)==firstMaterial,"show/hide/theme redraw replaces rather than accumulates supplied material alpha")
    }
    var dataSkin=controlSkin;dataSkin.stations=skin.stations
    try materialView.applyOfficial(skin:dataSkin,rows:[reading],renderer:controlRenderer,scale:1,locale:"en")
    var brokenSkin=dataSkin;brokenSkin.fixedLayers[0].resource="missing"
    do { try materialView.applyOfficial(skin:brokenSkin,rows:[reading],renderer:controlRenderer,scale:1,locale:"en");throw NativeFailure(message:"missing material accepted") }
    catch DockArtworkError.missingResource { checks+=1 }
    try require(drawMaterial(materialView)==firstMaterial,"failed refresh retains exact supplied background without stale quota text")
    try require((materialView.accessibilityChildren() ?? []).isEmpty,"failed refresh retires stale instrument actions")
    materialView.dispose()
    var staleInput=input;staleInput.dataState = .stale
    let staleReading=try DockInstrumentProjection.evaluate(staleInput,now:instant)
    var staleSkin=skin;staleSkin.stations[0].replacementResource="test";staleSkin.stations[0].readoutOpacity=0.6
    let staleResult=try renderer.render(skin:staleSkin,readings:["sub":staleReading],scale:1)
    try require(staleReading.dataState == .stale && staleResult.metrics.contains{$0.text=="--"},"external stale appearance preserves unavailable quota semantics")
    var bilingualSkin=skin;bilingualSkin.stations[0].aliasRect=CGRect(x:20,y:70,width:56,height:12)
    bilingualSkin.aliasText.useSystemUIFont=true;bilingualSkin.aliasText.language="zh-Hans"
    var bilingualInput=input;bilingualInput.alias="工作甲"
    let bilingual=try renderer.render(skin:bilingualSkin,readings:["sub":try DockInstrumentProjection.evaluate(bilingualInput,now:instant)],scale:2)
    try require(bilingual.metrics.contains{$0.text=="工作甲" && $0.advance>0 && !$0.runFonts.isEmpty},"actual CJK fallback runs are recorded rather than inferred from the base font")
    let view=DockInstrumentView(frame:CGRect(x:0,y:0,width:240,height:44));var actions=0
    view.onAction={_ in actions+=1};try view.applyCommunity([reading])
    let first=(view.accessibilityChildren() as? [NSAccessibilityElement])?.first
    try require(first?.accessibilityValue() as? String == "25%","community fallback preserves data without private resources")
    _=first?.accessibilityPerformPress();try require(actions==1,"one AX action invokes one local intent")
    input.alias="Synthetic alias";let refreshed=try DockInstrumentProjection.evaluate(input,now:instant);try view.applyCommunity([refreshed])
    try require(first === (view.accessibilityChildren() as? [NSAccessibilityElement])?.first,"same stable-ID accessibility object after repaint")
    try view.applyCommunity([]);try require(first?.accessibilityPerformPress()==false,"removed accessibility node cannot dispatch old subscription")
    try view.applyCommunity([reading])
    try require(first?.accessibilityPerformPress()==false,"removed AX object stays invalid even if the same ID returns")
    view.dispose()
    var asymmetric=skin;asymmetric.stations=[];asymmetric.bodyPolygon=[CGPoint(x:0,y:0),CGPoint(x:40,y:0),CGPoint(x:0,y:10)]
    let hitView=DockInstrumentView(frame:asymmetric.bounds)
    try hitView.applyOfficial(skin:asymmetric,rows:[],renderer:renderer,scale:2,locale:"en")
    try require(hitView.hitTest(hitView.convert(CGPoint(x:3,y:2),to:hitView.superview)) === hitView,"top-left painted alpha is hittable at 2x")
    try require(hitView.hitTest(hitView.convert(CGPoint(x:3,y:80),to:hitView.superview)) == nil,"opposite transparent row is not vertically inverted")
    try require(hitView.hitTest(hitView.convert(CGPoint(x:80,y:2),to:hitView.superview)) == nil,"transparent pixel is not confused with a colour byte")
    hitView.dispose()
    asymmetric.bounds.origin.x = .nan
    do{_=try renderer.render(skin:asymmetric,readings:[:],scale:2);throw NativeFailure(message:"nonfinite geometry admitted")}
    catch DockArtworkError.invalidManifest{checks+=1}
    var combined=json;combined["bounds"]=[[0,0],[384,96]];combined["bodyPolygon"]=[[0,0],[384,0],[384,96],[0,96]]
    let template=(json["stations"] as! [[String:Any]])[0]
    combined["stations"]=(0..<6).map{index->[String:Any] in
        var station=template;station["subscriptionID"]="work-\(index)";station["logicalPoints"]=64;station["diameter"]=64
        station["centre"]=[32+64*index,32];station["readout"]=[[64*index+4,66],[56,16]];return station
    }
    let effectsSkin=try JSONDecoder().decode(DockInstrumentSkin.self,from:JSONSerialization.data(withJSONObject:combined))
    let working=try (0..<6).map{index->DockInstrumentReading in
        let id="work-\(index)"
        var input=DockInstrumentInput(id:id,name:"Synthetic",windows:[DockQuotaWindowInput(id:"short",period:.fiveHour,label:"5h",remainingPercent:[70.0,30,10][index%3],resetsAt:nil,durationSeconds:nil)])
        input.dataState = .fresh;input.working=DockWorkingSignal(subscriptionID:id,bindingVerified:true,fresh:true,observedOutput:true)
        return try DockInstrumentProjection.evaluate(input,now:instant)
    }
    try require(Set(working.map(\.status)) == Set([DockQuotaStatus.normal,.warning,.critical]),"cache fixture must exercise three quota-state variants")
    var hiddenReadout=skin;hiddenReadout.stations[0].showsReadout=false
    let hiddenResult=try renderer.render(skin:hiddenReadout,readings:["sub":reading],scale:2)
    try require(!hiddenResult.metrics.contains{$0.text==reading.readout},"percentage-off omits only visible quota text")
    let hiddenView=DockInstrumentView(frame:hiddenReadout.bounds)
    try hiddenView.applyOfficial(skin:hiddenReadout,rows:[reading],renderer:renderer,scale:2,locale:"en")
    try require((hiddenView.accessibilityChildren() as? [NSAccessibilityElement])?.first?.accessibilityValue() as? String==reading.readout,"hidden percentage remains accessible without repainting text")
    hiddenView.dispose()
    let effectsView=DockInstrumentView(frame:effectsSkin.bounds)
    try effectsView.applyOfficial(skin:effectsSkin,rows:working,renderer:renderer,scale:2,locale:"en")
    let pool=EffectResourcePool(),driver=DockWorkingEffects(pool:pool,systemReduceMotion:{false}),provider=SyntheticDockFrameProvider()
    let magnifications=Dictionary(uniqueKeysWithValues:working.map{($0.subscriptionID,1.5)})
    try driver.configure(view:effectsView,skin:effectsSkin,readings:working,profile:RenderProfile(scale:2),magnification:magnifications,compositing:.screen,provider:{_ in provider})
    try require(driver.activeIDs.count==6 && driver.animatingIDs.count==6,"six distinct native consumers")
    try require(effectsView.layerUsesCoreImageFilters,"screen compositing uses the public native filter path")
    try require(pool.activeLeaseCount==6 && pool.atlasCount==3 && provider.draws==27,"three variants share counted leases, no per-ID atlas")
    try require(pool.decodedBytes==3_981_312 && pool.decodedBytes<=EffectResourcePool.maximumBytes,"64 pt strongest-hover stress case uses exact shared budget")
    driver.seekForCapture(0.5);try require(driver.animatingIDs.isEmpty && pool.activeLeaseCount==6,"capture keeps counted lease without copied atlas")
    try effectsView.applyCommunity([]);pool.purgeUnleased();try require(pool.activeLeaseCount==0 && pool.decodedBytes==0,"profile reset stops consumers before purging")
    try effectsView.applyOfficial(skin:effectsSkin,rows:working,renderer:renderer,scale:2,locale:"en")
    try driver.configure(view:effectsView,skin:effectsSkin,readings:working,profile:RenderProfile(scale:2,reduceMotion:true),magnification:magnifications,provider:{_ in provider})
    try require(driver.activeIDs.count==6 && driver.animatingIDs.isEmpty,"Reduced Motion retains static frame zero")
    driver.stop();pool.purgeUnleased();effectsView.dispose();try require(pool.activeLeaseCount==0 && pool.decodedBytes==0,"explicit teardown releases every jet")
    // Optional motion remains independent of the shared discrete bitmap clock.
    var syntheticSystemReduction=false
    let motionPool=EffectResourcePool(),motionDriver=DockWorkingEffects(pool:motionPool,systemReduceMotion:{syntheticSystemReduction})
    let recipe=DockEffectRotation(period:2,direction:.clockwise)
    func motion(_ profile:RenderProfile = .init(scale:1),quiet:Set<String>=[])throws {
        try effectsView.applyOfficial(skin:effectsSkin,rows:working,renderer:renderer,scale:1,locale:"en")
        try motionDriver.configure(view:effectsView,skin:effectsSkin,readings:working,profile:profile,rotation:recipe,quietIDs:quiet,provider:{_ in provider})
    }
    try motion()
    try require(motionDriver.rotatingIDs.count==6 && motionDriver.animatingIDs.count==6,"independent bitmap and rotation timelines")
    let jet=effectsView.workingLayerParents["work-0"]!.sublayers!.first!
    let spin=jet.animation(forKey:"dock-effect-rotation") as! CABasicAnimation
    let flicker=jet.animation(forKey:"stepped-images") as! CAKeyframeAnimation
    try require(spin.duration==2 && spin.keyPath=="transform.rotation.z" && spin.repeatCount.isInfinite,"host-supplied period, effect-only Z rotation")
    try require(spin.timingFunction==CAMediaTimingFunction(name:.linear),"linear motion timing")
    try require(flicker.duration==1 && flicker.calculationMode == .discrete && flicker.values?.count==9,"original nine-pose one-second bitmap clock unchanged")
    try require(effectsView.layer?.animationKeys()?.isEmpty ?? true,"static surface has no rotation")
    let motionRoot=effectsView.layer!,centre=jet.convert(CGPoint(x:32,y:32),to:effectsView.layer!)
    for (seconds,expected) in [(0.0,CGPoint(x:32,y:4)),(0.5,CGPoint(x:60,y:32)),(1.0,CGPoint(x:32,y:60)),(1.5,CGPoint(x:4,y:32)),(2.0,CGPoint(x:32,y:4))] {
        motionDriver.seekForCapture(seconds)
        let point=jet.convert(CGPoint(x:32,y:60),to:motionRoot)
        try require(hypot(point.x-(centre.x+expected.x-32),point.y-(centre.y+expected.y-32))<0.001,"final native root-view clockwise held pose")
    }
    try require(motionDriver.rotatingIDs.isEmpty && motionDriver.animatingIDs.isEmpty && motionPool.activeLeaseCount==6,"capture freezes both timelines while retaining counted leases")
    try motion(quiet:["work-0"])
    try require(motionDriver.rotatingIDs.count==5 && motionDriver.animatingIDs.count==5 && motionDriver.activeIDs.count==6,"quiet keeps only static frame zero")
    let quietJet=effectsView.workingLayerParents["work-0"]!.sublayers!.first!,quietImage=quietJet.contents as! CGImage
    motionDriver.seekForCapture(0.75)
    try require(quietJet.contents as! CGImage === quietImage && CATransform3DIsIdentity(quietJet.transform),"quiet capture cannot advance bitmap or rotation")
    try motion(RenderProfile(scale:1,reduceMotion:true))
    try require(motionDriver.activeIDs.count==6 && motionDriver.rotatingIDs.isEmpty && motionDriver.animatingIDs.isEmpty,"app reduction stops both timelines")
    syntheticSystemReduction=true;try motion()
    try require(motionDriver.rotatingIDs.isEmpty && motionDriver.animatingIDs.isEmpty,"injected system reduction is independent of app profile")
    syntheticSystemReduction=false;try motion()
    effectsView.viewDidHide();motionPool.purgeUnleased()
    try require(motionDriver.activeIDs.isEmpty && motionDriver.rotatingIDs.isEmpty && motionPool.activeLeaseCount==0 && motionPool.decodedBytes==0,"hide retires rotation, contents and leases")
    try motion()
    for invalid in [Double.nan,Double.infinity,0,-1,0.001,86_401] {
        do {try motionDriver.configure(view:effectsView,skin:effectsSkin,readings:working,profile:.init(),rotation:.init(period:invalid),provider:{_ in provider});throw NativeFailure(message:"invalid motion admitted")}
        catch DockArtworkError.invalidManifest{checks+=1}
    }
    try require(motionDriver.activeIDs.isEmpty && motionDriver.rotatingIDs.isEmpty,"failed recipe retires prior motion")
    motionDriver.stop();motionPool.purgeUnleased();effectsView.dispose()
    // B07 uses injected display/protection truth and one scheduler. No NSWindow is created.
    let display=DockDisplayArea(id:"screen",frame:CGRect(x:0,y:0,width:1000,height:800),visibleFrame:CGRect(x:0,y:0,width:1000,height:800))
    let edgeLayouts=DockEdgeGeometry.allowedEdges.map{edge in
        let size=edge == .bottom ? CGSize(width:240,height:80):CGSize(width:80,height:240)
        return DockEdgeLayout(displayID:"screen",edge:edge,expandedSize:size,sliverLength:240,sliverThickness:3,hoverRects:[CGRect(origin:.zero,size:size)])
    }
    var edgeTime=0.0,edgeEnv=DockEdgeEnvironment(displays:[display],layouts:edgeLayouts,pointer:CGPoint(x:999,y:400))
    let edgeScheduler=NeutralEdgeScheduler()
    let edgeDriver=DockEdgeController(preference:.init(displayID:"screen",edge:.right),clock:{edgeTime},scheduler:edgeScheduler,read:{edgeEnv})
    var edgePaints=0,edgeReveals=0,edgeClears=[DockRecordedLocks]()
    edgeDriver.onPresent={_ in edgePaints+=1};edgeDriver.onReveal={edgeReveals+=1}
    edgeDriver.onClearRecordedLocks={locks in edgeClears.append(locks);edgeEnv.presence.recordedLocks.subtract(locks)}
    edgeDriver.start()
    try require(edgeDriver.presentation?.state == .sliver && edgeScheduler.deadline==0.15,"wake dwell starts at first geometry sample")
    try require(edgeDriver.presentation?.paintedFrame?.width==3 && edgeDriver.presentation?.placement?.wakeFrame.width==20,"wake rectangle is not an input panel")
    let staleEdgeTimer=edgeScheduler.saved[0]
    edgeTime=0.149;edgeScheduler.fire();try require(edgeDriver.presentation?.state == .sliver,"no early reveal")
    edgeTime=0.15;edgeScheduler.fire();try require(edgeDriver.presentation?.state == .expanded && edgeReveals==1,"one genuine deadline reveal")
    edgeTime=0.151;try require(!edgeDriver.acceptsPress() && edgeDriver.acceptsPress(keyboardOrAccessibility:true),"arrival blocks pointer, not explicit AX")
    edgeTime=0.45;try require(edgeDriver.acceptsPress(),"pointer admitted after300ms")
    let paintsAfterReveal=edgePaints
    edgeTime=0.5;edgeDriver.refresh();try require(edgePaints==paintsAfterReveal && edgeReveals==1,"sampling does not redraw or repeat reveal policy")
    edgeEnv.pointer=CGPoint(x:500,y:790);edgeTime=1;edgeDriver.refresh()
    edgeEnv.cardFrame=CGRect(x:650,y:300,width:180,height:200);edgeEnv.pointer=CGPoint(x:850,y:400);edgeTime=1.4;edgeDriver.refresh()
    edgeTime=1.7;edgeDriver.refresh();try require(edgeDriver.presentation?.state == .expanded,"full-depth card corridor retains dock")
    edgeEnv.cardFrame=nil;edgeEnv.pointer=CGPoint(x:500,y:790);edgeTime=2;edgeDriver.refresh()
    edgeTime=2.499;edgeScheduler.fire();try require(edgeDriver.presentation?.state == .expanded,"leave grace not early")
    edgeTime=2.5;edgeScheduler.fire();try require(edgeDriver.presentation?.state == .sliver,"leave grace500ms")
    edgeDriver.reveal();edgeEnv.presence.recordedLocks=[.drag,.menu,.keyboard];edgeEnv.presence.menuActuallyOpen=true
    edgeTime=3;edgeDriver.refresh();edgeTime=7;edgeDriver.refresh()
    try require(edgeDriver.presentation?.state == .expanded && edgeEnv.presence.recordedLocks.contains(.menu),"real menu protection outlives stale-lock fallback")
    edgeEnv.presence.menuActuallyOpen=false;edgeTime=7.1;edgeDriver.refresh()
    try require(edgeDriver.presentation?.state == .sliver && edgeEnv.presence.recordedLocks.isEmpty,"stale locks clear only without actual protections")
    edgeEnv.presence.cockpitClosed=false;edgeTime=8;edgeDriver.refresh();edgeEnv.presence.cockpitClosed=true;edgeTime=9;edgeDriver.restoreAfterCockpitClose()
    try require(edgeDriver.presentation?.state == .sliver,"away close restores sliver without expanded flash")
    edgeEnv.pointer=CGPoint(x:999,y:400);edgeTime=10;edgeDriver.restoreAfterCockpitClose()
    try require(edgeDriver.presentation?.state == .expanded && !edgeDriver.acceptsPress(),"wake close restores dock with arrival guard")
    edgeDriver.stop();let paintsStopped=edgePaints;staleEdgeTimer()
    try require(edgePaints==paintsStopped && edgeScheduler.pending==nil,"cancelled generation cannot revive surface")
    edgeEnv.presence.autoHide=false;edgeTime=11;edgeDriver.resume();edgeTime=11.4
    let body=CGPath(rect:CGRect(x:0,y:0,width:80,height:240),transform:nil)
    let edgeRegions=DockBackgroundDragRegions(body:body,excludedControls:[CGRect(x:20,y:60,width:40,height:60),CGRect(x:0,y:200,width:20,height:40)])
    edgeDriver.dragRegions=edgeRegions
    try require(!edgeDriver.backgroundCanDrag(local:CGPoint(x:30,y:80)) && !edgeDriver.backgroundCanDrag(local:CGPoint(x:10,y:220)),"nozzle and ignition never drag the dock")
    try require(edgeDriver.beginBackgroundMove(local:CGPoint(x:5,y:5),global:CGPoint(x:925,y:515)),"painted body begins capture")
    edgeEnv.presence.autoHide=true;edgeEnv.presence.mouseButtonDown=true;edgeEnv.pointer=CGPoint(x:20,y:300);edgeTime=11.5;edgeDriver.updateBackgroundMove(global:edgeEnv.pointer!)
    try require(edgeDriver.presentation?.snapPreview?.edge == .left && edgeDriver.isBackgroundMoving && edgeDriver.presentation?.placement?.edge == .right,"exact snap destination is separate from stationary dock")
    var commits=0;edgeDriver.onCommittedPlacement={_ in commits+=1}
    edgeEnv.presence.mouseButtonDown=false;edgeTime=15;edgeDriver.endBackgroundMove(global:edgeEnv.pointer!)
    try require(commits==1 && edgeDriver.preference.edge == .left && !edgeDriver.isBackgroundMoving,"long drag release commits once before stale fallback")
    edgeDriver.endBackgroundMove(global:edgeEnv.pointer!);try require(commits==1,"duplicate mouse-up cannot commit")
    edgeTime=15.4;try require(!edgeDriver.beginBackgroundMove(local:CGPoint(x:5,y:5),global:CGPoint(x:5,y:300)),"old edge hit regions cannot act before new layout binding")
    edgeDriver.dragRegions=edgeRegions
    try require(edgeDriver.beginBackgroundMove(local:CGPoint(x:5,y:5),global:CGPoint(x:5,y:300)),"new drag admitted")
    edgeDriver.updateBackgroundMove(global:CGPoint(x:980,y:500));edgeDriver.cancelBackgroundMove()
    try require(commits==1 && edgeDriver.preference.edge == .left && edgeDriver.presentation?.snapPreview==nil,"Escape/cancel leaves committed placement")
    edgeTime=16;_ = edgeDriver.beginBackgroundMove(local:CGPoint(x:5,y:5),global:CGPoint(x:5,y:300))
    edgeDriver.updateBackgroundMove(global:CGPoint(x:980,y:500))
    let clearsBeforeRemoval=edgeClears.count
    edgeEnv.displays=[];edgeEnv.layouts=[];edgeTime=16.1;edgeDriver.refresh();edgeDriver.endBackgroundMove(global:CGPoint(x:980,y:500))
    try require(commits==1 && edgeDriver.presentation?.paintedFrame==nil && edgeClears.count==clearsBeforeRemoval+1,"display removal cancels capture exactly once, no floating frame")
    edgeEnv.displays=[display];edgeEnv.layouts=edgeLayouts;edgeEnv.pointer=CGPoint(x:999,y:400);edgeEnv.presence.autoHide=false
    edgeTime=20;edgeDriver.stop();edgeDriver.setPreference(.init(displayID:"screen",edge:.right));edgeDriver.resume();edgeTime=20.4;edgeDriver.dragRegions=edgeRegions
    let anchorBefore=edgeDriver.presentation!.placement!.sliverFrame.midY
    _ = edgeDriver.beginBackgroundMove(local:CGPoint(x:5,y:20),global:CGPoint(x:925,y:anchorBefore+100))
    edgeEnv.presence.mouseButtonDown=true
    edgeDriver.updateBackgroundMove(global:CGPoint(x:925,y:anchorBefore+120))
    try require(abs(edgeDriver.presentation!.snapPreview!.sliverFrame.midY-(anchorBefore+20))<0.001,"same-edge grip drag preserves grab offset, no centre jump")
    edgeDriver.cancelBackgroundMove()
    edgeDriver.stop()
    let sliver=DockSliverView(frame:CGRect(x:0,y:0,width:3,height:20));var sliverPresses=0;sliver.onReveal={sliverPresses+=1}
    try sliver.apply(image:nil,logicalSize:CGSize(width:3,height:20),scale:2,accessibilityLabel:"Synthetic reveal")
    try require(sliver.accessibilityPerformPress() && sliverPresses==1 && sliver.retainedBytes==0,"neutral sliver has an explicit AX reveal")
    do{try sliver.apply(image:nil,logicalSize:CGSize(width:CGFloat.nan,height:20),scale:2,accessibilityLabel:"bad");throw NativeFailure(message:"bad sliver admitted")}
    catch DockArtworkError.invalidManifest{checks+=1}
    try require(!sliver.accessibilityPerformPress() && !sliver.isPainted(atLocal:CGPoint(x:1,y:1)),"failed sliver cannot preserve old actions")
    sliver.dispose()
    let outline=DockSnapOutlineView(frame:CGRect(x:0,y:0,width:40,height:40))
    try require(outline.hitTest(CGPoint(x:10,y:10))==nil,"snap outline never catches input")
    let secondDisplay=DockDisplayArea(id:"other",frame:CGRect(x:2000,y:0,width:1000,height:800),visibleFrame:CGRect(x:2000,y:0,width:1000,height:800))
    var orderedEnv=DockEdgeEnvironment(displays:[display,secondDisplay],layouts:edgeLayouts,primaryDisplayID:"screen",pointer:CGPoint(x:999,y:400))
    orderedEnv.presence.autoHide=false
    let orderedScheduler=NeutralEdgeScheduler(),orderedDriver=DockEdgeController(preference:.init(displayID:"screen",edge:.right),clock:{edgeTime},scheduler:orderedScheduler,read:{orderedEnv})
    edgeTime=30;orderedDriver.start();edgeTime=30.4;orderedDriver.dragRegions=edgeRegions
    _ = orderedDriver.beginBackgroundMove(local:CGPoint(x:5,y:5),global:CGPoint(x:925,y:515))
    orderedEnv.presence.mouseButtonDown=true;orderedDriver.updateBackgroundMove(global:CGPoint(x:925,y:535))
    orderedEnv.displays.reverse();orderedEnv.layouts.reverse();orderedDriver.refresh()
    try require(orderedDriver.isBackgroundMoving,"benign array ordering does not cancel unchanged geometry")
    orderedDriver.cancelBackgroundMove();orderedDriver.stop()
    let gateView=DockInstrumentView(frame:skin.bounds);try gateView.applyCommunity([reading])
    var guardedActions=0;gateView.onAction={_ in guardedActions+=1}
    let retiredAfterGate=(gateView.accessibilityChildren() as! [NSAccessibilityElement]).first!
    gateView.permitsAction={_,_ in try? gateView.applyCommunity([]);return true}
    try require(!retiredAfterGate.accessibilityPerformPress() && guardedActions==0,"action gate snapshot refresh cannot dispatch a retired AX node")
    gateView.dispose()
    var otherPointerInput=DockInstrumentInput(id:"pointer-other",name:"Synthetic other",windows:[])
    otherPointerInput.dataState = .fresh
    let otherPointerReading=try DockInstrumentProjection.evaluate(otherPointerInput,now:instant)
    let pointerView=DockInstrumentView(frame:skin.bounds);try pointerView.applyCommunity([reading,otherPointerReading])
    var pointerActions=[DockInstrumentAction]();pointerView.onAction={pointerActions.append($0)}
    pointerView.permitsAction={_,_ in try? pointerView.applyCommunity([otherPointerReading,reading]);return true}
    try require(!pointerView.performPointerPress(atLocal:CGPoint(x:10,y:20)) && pointerActions.isEmpty,"gate reorder retaining both readings cannot dispatch the old station")
    pointerView.permitsAction=nil
    try require(pointerView.performPointerPress(atLocal:CGPoint(x:10,y:20)) && pointerActions == [.subscription(otherPointerReading.subscriptionID)],"fresh pointer press can select the current reordered target")
    pointerView.dispose()
    let overflowGateView=DockInstrumentView(frame:skin.bounds)
    try overflowGateView.applyOfficial(skin:skin,rows:[reading],renderer:renderer,scale:1,locale:"en")
    var overflowGateActions=0;overflowGateView.onAction={_ in overflowGateActions+=1}
    var overflowGateSkin=skin;overflowGateSkin.stations[0].subscriptionID=nil;overflowGateSkin.stations[0].overflowCount=2
    overflowGateView.permitsAction={_,_ in try? overflowGateView.applyOfficial(skin:overflowGateSkin,rows:[reading],renderer:renderer,scale:1,locale:"en");return true}
    try require(!overflowGateView.performPointerPress(atLocal:CGPoint(x:48,y:30)) && overflowGateActions==0,"gate migration into overflow rejects the old station even while its reading survives")
    overflowGateView.dispose()
    var clearStopEnv=DockEdgeEnvironment(displays:[display],layouts:edgeLayouts,pointer:CGPoint(x:999,y:400))
    clearStopEnv.presence.autoHide=false;clearStopEnv.presence.recordedLocks=[.menu]
    let clearStopScheduler=NeutralEdgeScheduler(),clearStopDriver=DockEdgeController(preference:.init(displayID:"screen",edge:.right),clock:{40},scheduler:clearStopScheduler,read:{clearStopEnv})
    var clearStopReveals=0;clearStopDriver.onReveal={clearStopReveals+=1}
    clearStopDriver.onClearRecordedLocks={_ in clearStopDriver.stop()}
    clearStopDriver.start()
    try require(clearStopDriver.presentation?.state == .suppressed(.lifecycle) && clearStopDriver.presentation?.paintedFrame==nil,"lock-clear reentrant stop cannot be overwritten by the old refresh result")
    try require(clearStopScheduler.pending==nil && clearStopReveals==0,"reentrant stop cannot rearm or announce a stale reveal")
    var releaseStopEnv=DockEdgeEnvironment(displays:[display],layouts:edgeLayouts,pointer:CGPoint(x:999,y:400)),releaseStopTime=50.0
    releaseStopEnv.presence.autoHide=false
    let releaseStopScheduler=NeutralEdgeScheduler(),releaseStopDriver=DockEdgeController(preference:.init(displayID:"screen",edge:.right),clock:{releaseStopTime},scheduler:releaseStopScheduler,read:{releaseStopEnv})
    releaseStopDriver.start();releaseStopTime=50.4;releaseStopDriver.dragRegions=edgeRegions
    try require(releaseStopDriver.beginBackgroundMove(local:CGPoint(x:5,y:5),global:CGPoint(x:925,y:515)),"release reentrancy fixture captures background")
    releaseStopEnv.presence.mouseButtonDown=true;releaseStopEnv.pointer=CGPoint(x:20,y:300);releaseStopTime=50.5
    releaseStopDriver.updateBackgroundMove(global:releaseStopEnv.pointer!)
    var stoppedCommits=0;releaseStopDriver.onCommittedPlacement={_ in stoppedCommits+=1}
    releaseStopDriver.onClearRecordedLocks={_ in releaseStopDriver.stop()}
    releaseStopEnv.presence.mouseButtonDown=false;releaseStopTime=51;releaseStopDriver.endBackgroundMove(global:releaseStopEnv.pointer!)
    try require(stoppedCommits==0 && releaseStopDriver.preference.edge == .right && releaseStopDriver.presentation?.state == .suppressed(.lifecycle),"release lock-clear stop prevents stale preference mutation/commit")
    try require(releaseStopScheduler.pending==nil,"release callback stop leaves no timer")
    releaseStopDriver.onClearRecordedLocks=nil;releaseStopTime=52;releaseStopDriver.resume();releaseStopTime=52.4;releaseStopDriver.dragRegions=edgeRegions
    _ = releaseStopDriver.beginBackgroundMove(local:CGPoint(x:5,y:5),global:CGPoint(x:925,y:515))
    var recursiveClears=0;releaseStopDriver.onClearRecordedLocks={_ in recursiveClears+=1;if recursiveClears==1{releaseStopDriver.stop()}}
    releaseStopDriver.stop()
    try require(recursiveClears==1 && releaseStopDriver.presentation?.state == .suppressed(.lifecycle),"stop retires capture before a reentrant clear callback")
    let continuous=ContinuousClock(),origin=continuous.now
    func elapsed()->Double{let d=origin.duration(to:continuous.now).components;return Double(d.seconds)+Double(d.attoseconds)/1e18}
    let nativeScheduler=DockCommonModeScheduler(clock:{elapsed()});var trackingFired=false
    let trackingMode=RunLoop.Mode("ModelPlanSyntheticTracking")
    CFRunLoopAddCommonMode(CFRunLoopGetMain(),CFRunLoopMode(rawValue:trackingMode.rawValue as CFString))
    nativeScheduler.arm(at:elapsed()+0.01){trackingFired=true}
    let trackingEnd=Date().addingTimeInterval(0.2)
    while !trackingFired && Date()<trackingEnd{RunLoop.main.run(mode:trackingMode,before:trackingEnd)}
    try require(trackingFired,"deadline runs in an owned synthetic tracking common mode, not default-only")
    nativeScheduler.cancel()
    var interactionTime=0.0,interactionEnv=DockInteractionEnvironment(catalogue:["a","b","c"],preferences:.init(),targets:[.init(id:"a",along:0),.init(id:"b",along:20)],overflowIDs:["c"],hoveredID:"a",insideShared:true,contents:["a":.init(subscriptionID:"a",name:"Synthetic A",rows:[.init(id:"q",kind:.quota,label:"Window",value:"--")])])
    let interactionScheduler=NeutralEdgeScheduler(),interaction=DockInteractionController(clock:{interactionTime},scheduler:interactionScheduler,read:{interactionEnv})
    var interactionPaints=0;interaction.onPresent={_ in interactionPaints+=1};interaction.start()
    try require(interaction.presentation?.card == .hidden && interactionScheduler.deadline==0.25,"native card controller arms250ms once")
    let retiredCardTimer=interactionScheduler.saved[0]
    interactionTime=0.25;interactionScheduler.fire();try require(interaction.presentation?.card == .hover("a"),"deadline revalidates current hover/content")
    interaction.click("a");interactionTime=10;interactionEnv.parentExpanded=false;interactionEnv.insideShared=false;interaction.refresh()
    try require(interaction.presentation?.card == .pinned("a"),"native cockpit suppression retains pin model")
    interactionEnv.catalogue=["b","c"];interaction.refresh();try require(interaction.presentation?.card == .hidden,"removed card target retired")
    interaction.stop();let stoppedCardPaints=interactionPaints;retiredCardTimer()
    try require(interactionPaints==stoppedCardPaints && interactionScheduler.pending==nil,"old hover callback cannot reopen stopped card")
    interactionEnv.catalogue=["a","b","c"];interactionEnv.parentExpanded=true;interactionEnv.hoveredID=nil;interactionEnv.insideShared=true;interactionTime=11;interaction.start()
    var orderRequests=[DockOrderRequest](),orderAnnouncements=[String]()
    interaction.onOrderRequest={orderRequests.append($0)};interaction.onOrderAnnouncement={id,index,total in orderAnnouncements.append("\(id):\(index):\(total)")}
    interaction.moveByKeyboard(id:"a",delta:1)
    try require(orderRequests.count==1 && orderAnnouncements.isEmpty,"Option move emits host intent, no speculative announcement")
    let accepted=orderRequests[0];interactionEnv.preferences=accepted.proposed;interaction.orderAccepted(accepted.id,preferences:interactionEnv.preferences,catalogue:interactionEnv.catalogue)
    try require(orderAnnouncements==["a:1:3"],"accepted Option move announces each actual position once")
    interaction.orderAccepted(accepted.id,preferences:interactionEnv.preferences,catalogue:interactionEnv.catalogue)
    try require(orderAnnouncements.count==1,"duplicate acceptance does not reannounce")
    interaction.moveByKeyboard(id:"b",delta:1)
    let toOverflow=orderRequests.last!;interactionEnv.preferences=toOverflow.proposed;interactionEnv.overflowIDs.insert("b")
    interaction.orderAccepted(toOverflow.id,preferences:interactionEnv.preferences,catalogue:interactionEnv.catalogue)
    try require(interaction.presentation?.overflowIDs.contains("b")==true && orderAnnouncements.count==2,"accepted off-main move opens overflow before focus/announcement handoff")
    _=interaction.beginNozzle(id:"a",along:0);interaction.canPreviewOrder={_ in interaction.stop();return true};interaction.moveNozzle(along:25)
    try require(interaction.presentation?.reorder==nil && !interaction.hasCapture,"preview callback stop cannot reenter an inout gesture or resurrect it")
    interaction.canPreviewOrder={_ in true};interactionTime=12;interaction.start();_=interaction.beginNozzle(id:"a",along:0)
    interactionEnv.bindingRevision+=1;interaction.refresh();try require(!interaction.hasCapture,"binding change cancels captured old nozzle")
    interaction.toggleOverflow();try require(interaction.presentation?.overflowIDs==["b","c"],"overflow list retains accepted off-main subscriptions in shared canonical order")
    interaction.stop()
    let reorderSurface=DockReorderLayersView(frame:effectsSkin.bounds)
    let firstVisuals=try renderer.reorderVisuals(skin:effectsSkin,readings:Dictionary(uniqueKeysWithValues:working.map{($0.subscriptionID,$0)}),scale:1)
    try reorderSurface.apply(firstVisuals,draggedID:nil,reducedMotion:false)
    var yieldedSkin=effectsSkin;yieldedSkin.stations[0].centre.x+=10;yieldedSkin.stations[1].centre.x-=10
    let secondVisuals=try renderer.reorderVisuals(skin:yieldedSkin,readings:Dictionary(uniqueKeysWithValues:working.map{($0.subscriptionID,$0)}),scale:1)
    try reorderSurface.apply(secondVisuals,draggedID:"work-0",reducedMotion:false)
    try require(!reorderSurface.animatingIDs.contains("work-0") && reorderSurface.animatingIDs.contains("work-1"),"native neighbour yield is separate from dragged nozzle/effect bitmap clocks")
    try reorderSurface.apply(firstVisuals,draggedID:nil,reducedMotion:true)
    try require(reorderSurface.animatingIDs.isEmpty && reorderSurface.retainedBytes<=16*1024*1024,"RM yield is instant with bounded static parts")
    reorderSurface.dispose();try require(reorderSurface.retainedBytes==0,"reorder composition releases its counted static parts")
    let labels=Dictionary(uniqueKeysWithValues:DockMenuCommand.allCases.map{($0,"Synthetic-"+$0.rawValue)})
    var menuHelp=0,menuFocus=0,menuSettings=0,menuStates=[Bool]()
    let statusMenu=DockStatusMenu(labels:labels,handlers:[.help:{menuHelp+=1},.settings:{menuSettings+=1}])
    try require(statusMenu.menu.items.filter{!$0.isSeparatorItem}.map{$0.representedObject as! String}==DockMenuCommand.allCases.map(\.rawValue),"native menu follows semantic command order")
    try require(statusMenu.menu.items.filter(\.isSeparatorItem).count==2,"native separators bound to commands")
    statusMenu.onMenuActuallyOpen={menuStates.append($0)};statusMenu.menuWillOpen(statusMenu.menu);statusMenu.menuDidClose(statusMenu.menu)
    try require(menuStates==[true,false] && !statusMenu.isActuallyOpen,"actual menu callbacks feed protection truth")
    statusMenu.onRestoreStatusFocus={menuFocus+=1};statusMenu.perform(.help);statusMenu.helpDidDismiss();statusMenu.helpDidDismiss();statusMenu.perform(.settings)
    try require(menuHelp==1 && menuFocus==1 && menuSettings==1,"Help uses injected map/focus callbacks once")
    let legacyMenu=DockStatusMenu(labels:labels,handlers:[:])
    try require(legacyMenu.menu.items.filter{!$0.isSeparatorItem}.count==7 && legacyMenu.menu.items.filter(\.isSeparatorItem).count==2,"missing Help callback preserves native seven-item compatibility")
    statusMenu.dispose();statusMenu.perform(.help);try require(menuHelp==1,"disposed menu cannot replay callback")
    legacyMenu.dispose()
    let cardSurface=DockCardView(frame:CGRect(x:0,y:0,width:300,height:200))
    let cardContent=DockCardContent(subscriptionID:"a",name:"Synthetic",rows:[.init(id:"extra",kind:.extraQuota,label:"Full extra name",value:"0%",remainingFraction:0,tone:.critical)])
    let templateBrand=NSImage(size:NSSize(width:20,height:20));templateBrand.isTemplate=true
    try cardSurface.apply(cardContent,pinned:true,brandImage:templateBrand);try require(!cardSurface.subviews.isEmpty,"native card builds bounded rows/footer")
    let cardHeader=(cardSurface.subviews.first as! NSStackView).arrangedSubviews.first as! NSStackView
    try require((cardHeader.arrangedSubviews.first as? NSImageView)?.image?.isTemplate==false && templateBrand.isTemplate,"card brand copy remains intrinsic without mutating caller template")
    let unsafeCardContent=DockCardContent(subscriptionID:"a",name:"Synthetic",rows:[],links:[.init(label:"bad",url:URL(string:"file:///synthetic")!)])
    do{try cardSurface.apply(unsafeCardContent,pinned:true);throw NativeFailure(message:"unsafe card link admitted")}catch DockLogicError.invalidCatalogue{checks+=1}
    cardSurface.dispose()
    let traySurface=DockOverflowTrayView(frame:CGRect(x:0,y:0,width:160,height:80))
    try traySurface.apply([.init(id:"a",label:"Synthetic",value:"--",dragHelp:"Synthetic drag help")]);try require(!traySurface.subviews.isEmpty,"neutral overflow tray is available without official source")
    traySurface.dispose()
    if CommandLine.arguments.count>2 {
        let fontRoot=URL(fileURLWithPath:CommandLine.arguments[2])
        let fontURL=fontRoot.appendingPathComponent("jetbrains-mono-latin-wght-normal.ttf"), bytes=try Data(contentsOf:fontURL)
        let spec=DockResourceFile(path:fontURL.lastPathComponent,sha256:SHA256.hash(data:bytes).map{String(format:"%02x",$0)}.joined(),bytes:bytes.count)
        let fonts=try DockArtworkStore(root:fontRoot,manifest:DockResourceManifest(files:["mono":spec]))
        let font=try fonts.font("mono",size:11,weight:400)
        try require((CTFontCopyPostScriptName(font) as String)=="JetBrainsMono-Regular","actual Regular instance, not the first Thin descriptor")
    }
    let receipt:[String:Any]=["schemaVersion":1,"checks":checks,"result":"passed","fixtureOnly":true,
        "physicalInputAccepted":false,"officialPixelAccepted":false,"effectsAccepted":false,"uiLaunched":false]
    try JSONSerialization.data(withJSONObject:receipt,options:[.prettyPrinted,.sortedKeys]).write(to:root.appendingPathComponent("native-checks.json"),options:.atomic)
    print("PASS \(checks) native resource/raster/font checks (synthetic; no visual or input acceptance)")
}
MainActor.assumeIsolated {
    do{try nativeChecks(URL(fileURLWithPath:CommandLine.arguments[1]))}catch{fputs("FAIL \(error)\n",stderr);exit(1)}
}
