// SPDX-License-Identifier: MIT
import Foundation
import CoreGraphics
import CoreText
import CryptoKit
import ImageIO
#if canImport(ModelPlanDock)
import ModelPlanDock
#endif

struct NativeFailure:Error {let message:String}
@MainActor func nativeChecks(_ root:URL) throws {
    var checks=0
    func require(_ condition:Bool,_ message:String)throws{checks+=1;if !condition{throw NativeFailure(message:message)}}
    try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
    let imageURL=root.appendingPathComponent("synthetic.png")
    let context=CGContext(data:nil,width:32,height:32,bitsPerComponent:8,bytesPerRow:0,
        space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
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
