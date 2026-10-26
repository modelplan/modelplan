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
        var input=DockInstrumentInput(id:id,name:"Synthetic",windows:[DockQuotaWindowInput(id:"short",period:.fiveHour,label:"5h",remainingPercent:[70.0,20,10][index%3],resetsAt:nil,durationSeconds:nil)])
        input.dataState = .fresh;input.working=DockWorkingSignal(subscriptionID:id,bindingVerified:true,fresh:true,observedOutput:true)
        return try DockInstrumentProjection.evaluate(input,now:instant)
    }
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
    try require(pool.decodedBytes==3_981_312 && pool.decodedBytes<=EffectResourcePool.maximumBytes,"L64 strongest-hover uses exact shared budget")
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
    let parent=effectsView.workingLayerParents["work-0"]!
    for (seconds,expected) in [(0.0,CGPoint(x:32,y:4)),(0.5,CGPoint(x:60,y:32)),(1.0,CGPoint(x:32,y:60)),(1.5,CGPoint(x:4,y:32)),(2.0,CGPoint(x:32,y:4))] {
        motionDriver.seekForCapture(seconds)
        let point=jet.convert(CGPoint(x:32,y:4),to:parent)
        try require(hypot(point.x-expected.x,point.y-expected.y)<0.001,"native flipped layer clockwise held pose")
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
