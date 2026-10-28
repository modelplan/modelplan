// SPDX-License-Identifier: MIT
import AppKit
import CoreGraphics
import CryptoKit
import ImageIO
@_spi(DockResourceChecks) import ModelPlanDock

/// Offscreen coverage probes only; the private official key shape/palette is not reproduced here.
@MainActor func dockVisualChecks(_ root:URL)throws->Int{
    var checks=0,failures=[String](),sliverSamples=[String](),edgeHistograms=[String]()
    let output=root.appendingPathComponent("dock-visual")
    try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
    func require(_ condition:Bool,_ reason:String){checks+=1;if !condition{failures.append(reason)}}
    func png(_ image:CGImage,_ name:String)throws{
        guard let writer=CGImageDestinationCreateWithURL(output.appendingPathComponent(name+".png") as CFURL,"public.png" as CFString,1,nil) else{throw NativeFailure(message:"visual PNG destination")}
        CGImageDestinationAddImage(writer,image,nil)
        guard CGImageDestinationFinalize(writer) else{throw NativeFailure(message:"visual PNG encoding")}
    }
    @MainActor func capture(_ view:NSView,_ scale:Int,_ interpolation:NSImageInterpolation,_ antialias:Bool,draw:(@MainActor ()->Void)?=nil)throws->CGImage{
        let width=Int(ceil(view.bounds.width*CGFloat(scale))),height=Int(ceil(view.bounds.height*CGFloat(scale)))
        guard let c=CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,
            space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Big.rawValue|CGImageAlphaInfo.premultipliedLast.rawValue) else{throw NativeFailure(message:"visual context")}
        c.translateBy(x:0,y:CGFloat(height));c.scaleBy(x:CGFloat(scale),y:-CGFloat(scale))
        NSGraphicsContext.saveGraphicsState();defer{NSGraphicsContext.restoreGraphicsState()}
        let graphics=NSGraphicsContext(cgContext:c,flipped:true);NSGraphicsContext.current=graphics
        graphics.imageInterpolation=interpolation;graphics.shouldAntialias=antialias
        if let draw{draw()}else{view.draw(view.bounds)}
        require(graphics.imageInterpolation==interpolation && graphics.shouldAntialias==antialias,"view leaked drawing state")
        guard let image=c.makeImage() else{throw NativeFailure(message:"visual image")};return image
    }
    func rgba(_ image:CGImage,_ x:Int,_ y:Int)->[Int]{
        let data=image.dataProvider!.data!,bytes=CFDataGetBytePtr(data)!,offset=y*image.bytesPerRow+x*4
        return (0..<4).map{Int(bytes[offset+$0])}
    }
    // The fallback is the collapsed Dock's own surface; no host, panel, live feed or global input.
    for thickness in [CGFloat(3),4]{for scale in [1,2]{for edge in [DockEdge.right,.left,.bottom]{
        let vertical=edge != .bottom,size=vertical ? CGSize(width:thickness,height:147.3962):CGSize(width:147.3962,height:thickness)
        let sliver=DockSliverView(frame:CGRect(origin:.zero,size:size))
        try sliver.apply(image:nil,logicalSize:size,scale:scale,accessibilityLabel:"Synthetic collapsed Dock",edge:edge)
        defer{sliver.dispose()}
        var first:Data?
        for name in [NSAppearance.Name.aqua,.darkAqua]{
            sliver.appearance=NSAppearance(named:name)
            let image=try capture(sliver,scale,.none,false)
            try png(image,"sliver-\(edge)-\(thickness)pt-\(scale)x-\(name.rawValue)")
            let data=image.dataProvider!.data! as Data
            if let first{require(data==first,"night-only neutral sliver changed with system appearance")}else{first=data}
            let cross=vertical ? image.width:image.height
            let length=vertical ? image.height:image.width
            for along in [length/4,length/2,3*length/4]{for sample in [scale,cross-1-scale]{
                let pixel=vertical ? rgba(image,sample,along):rgba(image,along,sample)
                // Bitmap rows are top-down after the draw transform. Left reverses the thickness gradient.
                let location=(Double(sample)+0.5)/Double(cross),t=edge == .left ? 1-location:location
                let top=[42.0,43,46],bottom=[20.0,21,23]
                let expected=(0..<3).map{Int((top[$0]*(1-t)+bottom[$0]*t).rounded())}+[255]
                require(zip(pixel,expected).allSatisfy{abs($0-$1)<=2},"sliver token mismatch edge=\(edge) scale=\(scale) along=\(along) cross=\(sample) actual=\(pixel) expected=\(expected)")
                if name == .aqua && along == length/2{sliverSamples.append("\(edge)/\(thickness)pt/\(scale)x=\(pixel)")}
            }}
            // Radius is on the inner side; outer/screen-side corners stay square and opaque.
            let inner=vertical ? rgba(image,edge == .right ? 0:image.width-1,0):rgba(image,0,0)
            let outer=vertical ? rgba(image,edge == .right ? image.width-1:0,0):rgba(image,0,image.height-1)
            let innerMiddle=vertical ? rgba(image,edge == .right ? 0:image.width-1,image.height/2):rgba(image,image.width/2,0)
            let outerMiddle=vertical ? rgba(image,edge == .right ? image.width-1:0,image.height/2):rgba(image,image.width/2,image.height-1)
            // The specified opaque outer outline can cover a transparent corner; compare face shading.
            require(inner[0]<innerMiddle[0],"sliver rounded the wrong side edge=\(edge) scale=\(scale)")
            require(zip(outer,outerMiddle).allSatisfy{abs($0-$1)<=2},"screen-side sliver corner is not square")
            require(outer[3]==255,"screen-side sliver corner is not opaque")
        }
        require(sliver.frame.size==size,"drawing changed sliver geometry")
    }}}
    let sliverPassed=failures.isEmpty
    print("dock-visual sliver-colour \(sliverPassed ? "PASS":"FAIL") \(sliverSamples.joined(separator:" "))")

    // A neutral red coverage mask exercises the same public SVG/resource/fixed-layer/view path.
    // Its circle is not the official red-key recipe; only edge coverage and resampling are asserted.
    let svg=Data("<svg xmlns='http://www.w3.org/2000/svg' width='32' height='32'><defs><clipPath id='coverage'><circle cx='16' cy='16' r='13.25'/></clipPath></defs><rect width='32' height='32' fill='#ff0000' clip-path='url(#coverage)'/></svg>".utf8)
    try svg.write(to:output.appendingPathComponent("neutral-coverage.svg"))
    let spec=DockResourceFile(path:"neutral-coverage.svg",sha256:SHA256.hash(data:svg).map{String(format:"%02x",$0)}.joined(),bytes:svg.count)
    let store=try DockArtworkStore(root:output,manifest:DockResourceManifest(files:["coverage":spec]))
    let object:[String:Any]=["schemaVersion":1,"bounds":[[0,0],[34.25,34.75]],"bodyPolygon":[],
        "fixedLayers":[["resource":"coverage","rect":[[1.25,1.375],[31.5,31.5]]]],"stations":[],"palette":[:],
        "text":["size":11,"weight":400],"aliasText":["size":10,"weight":400]]
    let skin=try JSONDecoder().decode(DockInstrumentSkin.self,from:JSONSerialization.data(withJSONObject:object))
    let renderer=DockInstrumentRenderer(resources:store),aaStart=failures.count
    for scale in [1,2]{
        let view=DockInstrumentView(frame:.zero)
        try view.applyOfficial(skin:skin,rows:[],renderer:renderer,scale:scale,locale:"en")
        defer{view.dispose()}
        let raster=try renderer.render(skin:skin,readings:[:],scale:scale).image
        let rawDraw: @MainActor ()->Void={
            NSImage(cgImage:raster,size:view.bounds.size).draw(in:view.bounds,from:.zero,operation:.copy,fraction:1,respectFlipped:true,hints:nil)
        }
        let rawLow=try capture(view,scale,.none,false,draw:rawDraw),rawHigh=try capture(view,scale,.high,true,draw:rawDraw)
        require((rawLow.dataProvider!.data! as Data) != (rawHigh.dataProvider!.data! as Data),"coverage probe did not exercise inherited sampling at \(scale)x")
        try png(rawLow,"unfiltered-mask-\(scale)x")
        let low=try capture(view,scale,.none,false),high=try capture(view,scale,.high,true)
        try png(low,"public-mask-\(scale)x")
        require((low.dataProvider!.data! as Data) == (high.dataProvider!.data! as Data),"public bitmap inherited nearest-neighbour/aliased presentation state at \(scale)x")
        var histogram=[Int:Int]()
        for y in 1..<low.height-1{for x in 1..<low.width-1{
            let alpha=rgba(low,x,y)[3]
            if (-1...1).contains(where:{dy in (-1...1).contains{dx in rgba(low,x+dx,y+dy)[3] != alpha}}){histogram[alpha,default:0]+=1}
        }}
        let intermediate=histogram.filter{$0.key>0 && $0.key<255}.values.reduce(0,+)
        require(intermediate>0,"public mask has only hard 0/255 edge steps at \(scale)x")
        require(histogram[0,default:0]>0 && histogram[255,default:0]>0,"coverage probe lacks transparent/opaque edge samples")
        edgeHistograms.append("\(scale)x:{0:\(histogram[0,default:0]),1...254:\(intermediate),255:\(histogram[255,default:0]),levels:\(histogram.count)}")
    }
    print("dock-visual redkey-aa \(failures.count==aaStart ? "PASS":"FAIL") \(edgeHistograms.joined(separator:" "))")
    let receipt:[String:Any]=["sliverPassed":sliverPassed,"redkeyPublicPathPassed":failures.count==aaStart,
        "sliverSamples":sliverSamples,"edgeAlphaHistograms":edgeHistograms,"failures":failures,
        "officialKeyAssetTested":false,"visualSignoff":false,"uiLaunched":false]
    try JSONSerialization.data(withJSONObject:receipt,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("dock-visual.json"))
    if !failures.isEmpty{throw NativeFailure(message:failures.joined(separator:"; "))}
    return checks
}
