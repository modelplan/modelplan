// SPDX-License-Identifier: MIT
import AppKit
import Foundation
import CoreGraphics

/// A static, self-contained vector subset. No scripts, foreign objects, external images, CSS imports or entities.
final class DockSVGShapeValidator: NSObject,XMLParserDelegate {
    private(set) var size=CGSize.zero, valid=true
    private var depth=0,nodes=0
    private let allowed:Set<String>=["svg","defs","g","path","circle","ellipse","rect","line","polyline","polygon","linearGradient","radialGradient","stop","clipPath","mask","filter","feGaussianBlur","feTurbulence","feColorMatrix","feComponentTransfer","feFuncA","feFuncR","feFuncG","feFuncB","feBlend","feComposite","feMorphology","feFlood","title","desc"]
    func parser(_ parser:XMLParser,didStartElement elementName:String,namespaceURI:String?,qualifiedName qName:String?,attributes:[String:String]) {
        depth+=1;nodes+=1
        guard allowed.contains(elementName),depth<=32,nodes<=4096 else{valid=false;parser.abortParsing();return}
        for (name,value) in attributes {
            let v=value.lowercased().replacingOccurrences(of:" ",with:"").replacingOccurrences(of:"'",with:"").replacingOccurrences(of:"\"",with:"")
            if value.utf8.count>65536 || value.contains("\\") || value.contains("@") || name.lowercased().hasPrefix("on") || v.contains("javascript:") || v.contains("@import") || v.contains("var(") || v.components(separatedBy:"url(").dropFirst().contains(where:{!$0.hasPrefix("#")}) || name.lowercased().contains("href") && !value.hasPrefix("#") {
                valid=false;parser.abortParsing();return
            }
        }
        if depth==1 {
            // A viewBox-only vector has an intrinsic aspect ratio and needs no rewritten source bytes.
            // Partial or malformed dimensions never fall back to viewBox to bypass validation.
            var viewport:CGSize?
            if let box=attributes["viewBox"] {
                let parts=box.split(whereSeparator:{$0.isWhitespace || $0==","})
                let numbers=parts.compactMap{Double($0)}
                guard numbers.count==4,parts.count==4,numbers.allSatisfy({$0.isFinite}),
                    abs(numbers[0])<=4096,abs(numbers[1])<=4096,numbers[2].isNormal,numbers[3].isNormal,numbers[2]>0,numbers[3]>0,
                    numbers[2]<=4096,numbers[3]<=4096 else{valid=false;parser.abortParsing();return}
                viewport=CGSize(width:numbers[2],height:numbers[3])
            }
            if attributes["width"]==nil && attributes["height"]==nil,let viewport {
                size=viewport
            } else {
                guard elementName=="svg",let w=attributes["width"].flatMap(Double.init),let h=attributes["height"].flatMap(Double.init),
                    w.isNormal,h.isNormal,w>0,h>0,w<=4096,h<=4096 else{valid=false;parser.abortParsing();return}
                size=CGSize(width:w,height:h)
            }
            guard elementName=="svg" else{valid=false;parser.abortParsing();return}
        }
    }
    func parser(_ parser:XMLParser,didEndElement:String,namespaceURI:String?,qualifiedName:String?){depth-=1}
    func parser(_ parser:XMLParser,foundProcessingInstructionWithTarget:String,data:String?){valid=false;parser.abortParsing()}
    func parser(_ parser:XMLParser,foundExternalEntityDeclarationWithName:String,publicID:String?,systemID:String?){valid=false;parser.abortParsing()}
    func parser(_ parser:XMLParser,foundInternalEntityDeclarationWithName:String,value:String?){valid=false;parser.abortParsing()}
}
/// Instrumentation SPI lets the neutral executable cover the raw decoder, not a supported product API.
@_spi(DockResourceChecks) @MainActor public enum DockStaticSVG {
    public static func pixelSize(_ size:CGSize,maximumPixelSize:Int)throws->(width:Int,height:Int) {
        // Normalise before multiplication: maxPixel / a subnormal source dimension can overflow.
        guard (1...4096).contains(maximumPixelSize),size.width.isNormal,size.height.isNormal,
            size.width>0,size.height>0,size.width<=4096,size.height<=4096 else{throw DockArtworkError.invalidManifest}
        let longest=max(size.width,size.height)
        let width=ceil((size.width/longest)*CGFloat(maximumPixelSize))
        let height=ceil((size.height/longest)*CGFloat(maximumPixelSize))
        guard width.isFinite,height.isFinite,width>=1,height>=1,
            width<=CGFloat(maximumPixelSize),height<=CGFloat(maximumPixelSize) else{throw DockArtworkError.invalidManifest}
        return (Int(width),Int(height)) // Only bounded finite values reach integer conversion.
    }
    public static func size(_ data:Data)throws->CGSize {
        guard data.count<=1_048_576,let text=String(data:data,encoding:.utf8),!text.lowercased().contains("<!doctype"),!text.lowercased().contains("<!entity") else{throw DockArtworkError.invalidManifest}
        let validator=DockSVGShapeValidator(),parser=XMLParser(data:data)
        parser.shouldResolveExternalEntities=false;parser.externalEntityResolvingPolicy = .never;parser.delegate=validator
        guard parser.parse(),validator.valid else{throw DockArtworkError.invalidManifest}
        _=try pixelSize(validator.size,maximumPixelSize:1);return validator.size
    }
    public static func image(_ data:Data,size:CGSize,maximumPixelSize:Int)throws->CGImage {
        let parsed=try Self.size(data)
        guard parsed==size else{throw DockArtworkError.invalidManifest}
        let pixels=try pixelSize(size,maximumPixelSize:maximumPixelSize),width=pixels.width,height=pixels.height
        guard width<=4096,height<=4096,let image=NSImage(data:data),
            image.size.width.isNormal,image.size.height.isNormal,image.size.width>0,image.size.height>0,
            let context=CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:0,
                space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else{throw DockArtworkError.invalidManifest}
        NSGraphicsContext.saveGraphicsState();defer{NSGraphicsContext.restoreGraphicsState()}
        NSGraphicsContext.current=NSGraphicsContext(cgContext:context,flipped:false)
        image.draw(in:CGRect(x:0,y:0,width:width,height:height),from:.zero,operation:.copy,fraction:1,respectFlipped:false,hints:nil)
        guard let result=context.makeImage() else{throw DockArtworkError.invalidManifest};return result
    }
}
