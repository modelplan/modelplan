// SPDX-License-Identifier: MIT
import Foundation
import CoreGraphics
import CoreText
import ImageIO
import CryptoKit

public enum DockArtworkError: Error {
    case invalidManifest, outsideRoot, missingResource(String), corruptResource(String), decodedBudget
}
public struct DockResourceFile: Codable, Sendable {
    public var path: String, sha256: String
    public var bytes: Int
    public init(path: String, sha256: String, bytes: Int) {self.path=path;self.sha256=sha256;self.bytes=bytes}
}
public struct DockResourceManifest: Codable, Sendable {
    public var schemaVersion: Int
    public var files: [String:DockResourceFile]
    public init(schemaVersion: Int = 1, files: [String:DockResourceFile]) {self.schemaVersion=schemaVersion;self.files=files}
}

/// External artwork is data, never executable code. Community views need no external directory.
/// Images handed to a caller are transient: do not keep uncounted layer copies after a profile transaction.
@MainActor public final class DockArtworkStore {
    private let root: URL, manifest: DockResourceManifest
    private struct Cached {let image:CGImage;let bytes:Int;var age:UInt64}
    private var images=[String:Cached](), age:UInt64=0
    public let decodedBudget:Int
    public private(set) var decodedBytes=0, peakDecodedBytes=0
    public init(root:URL,manifest:DockResourceManifest,decodedBudget:Int = 16_000_000) throws {
        guard root.isFileURL,manifest.schemaVersion==1,manifest.files.count<=4096,(1...32_000_000).contains(decodedBudget),
            manifest.files.allSatisfy({!$0.key.isEmpty && $0.value.bytes>0 && $0.value.bytes<=16_777_216 && $0.value.sha256.count==64}) else{throw DockArtworkError.invalidManifest}
        self.root=root.standardizedFileURL.resolvingSymlinksInPath();self.manifest=manifest;self.decodedBudget=decodedBudget
    }
    private func checkedResource(_ id:String) throws -> (URL,Data) {
        guard let item=manifest.files[id] else{throw DockArtworkError.missingResource(id)}
        let pieces=item.path.split(separator:"/",omittingEmptySubsequences:false)
        guard !item.path.hasPrefix("/"),!pieces.contains(".."),!pieces.contains("") else{throw DockArtworkError.outsideRoot}
        let url=root.appendingPathComponent(item.path).standardizedFileURL.resolvingSymlinksInPath()
        guard url.path.hasPrefix(root.path+"/") else{throw DockArtworkError.outsideRoot}
        let metadata=try url.resourceValues(forKeys:[.fileSizeKey,.isRegularFileKey])
        guard metadata.isRegularFile==true,metadata.fileSize==item.bytes else{throw DockArtworkError.corruptResource(id)}
        let data=try Data(contentsOf:url)
        guard data.count==item.bytes,SHA256.hash(data:data).map({String(format:"%02x",$0)}).joined()==item.sha256.lowercased() else{throw DockArtworkError.corruptResource(id)}
        return (url,data)
    }
    public func checkedURL(_ id:String) throws -> URL {try checkedResource(id).0}
    public func isVectorResource(_ id:String) -> Bool? {
        manifest.files[id].map { $0.path.lowercased().hasSuffix(".svg") }
    }
    public func image(_ id:String, maximumPixelSize:Int, preserveSourcePixels:Bool = false) throws -> CGImage {
        guard (1...4096).contains(maximumPixelSize) else{throw DockArtworkError.invalidManifest}
        let isVector = manifest.files[id]?.path.lowercased().hasSuffix(".svg") == true
        let key = id + (preserveSourcePixels && !isVector ? "@source" : "@" + String(maximumPixelSize));age &+= 1
        if var entry=images[key]{entry.age=age;images[key]=entry;return entry.image}
        let (_,data)=try checkedResource(id)
        if isVector {
            let size=try DockStaticSVG.size(data),pixels=try DockStaticSVG.pixelSize(size,maximumPixelSize:maximumPixelSize)
            try makeRoom(for:((pixels.width*4+63)/64)*64*pixels.height)
            let image=try DockStaticSVG.image(data,size:size,maximumPixelSize:maximumPixelSize),bytes=image.bytesPerRow*image.height
            try makeRoom(for:bytes);images[key]=Cached(image:image,bytes:bytes,age:age);decodedBytes+=bytes;peakDecodedBytes=max(decodedBytes,peakDecodedBytes)
            return image
        }
        guard let source=CGImageSourceCreateWithData(data as CFData,[kCGImageSourceShouldCache:false] as CFDictionary),
            let properties=CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any],
            let width=properties[kCGImagePropertyPixelWidth] as? Int,let height=properties[kCGImagePropertyPixelHeight] as? Int,
            width>0,height>0,width<=4096,height<=4096,width*height<=16_777_216 else{throw DockArtworkError.corruptResource(id)}
        let ratio=preserveSourcePixels ? 1 : min(1,Double(maximumPixelSize)/Double(max(width,height)))
        let estimate=((Int(ceil(Double(width)*ratio))*4+63)/64)*64*Int(ceil(Double(height)*ratio))
        try makeRoom(for:estimate)
        let decoded: CGImage?
        if preserveSourcePixels {
            decoded = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately:true] as CFDictionary)
        } else {
            decoded = CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,
                kCGImageSourceThumbnailMaxPixelSize:maximumPixelSize,kCGImageSourceShouldCacheImmediately:true] as CFDictionary)
        }
        guard let image = decoded else { throw DockArtworkError.corruptResource(id) }
        let bytes=image.bytesPerRow*image.height;try makeRoom(for:bytes)
        images[key]=Cached(image:image,bytes:bytes,age:age);decodedBytes+=bytes;peakDecodedBytes=max(decodedBytes,peakDecodedBytes)
        return image
    }
    /// Rasterize at a bounded probe size, then fit the visible alpha extent rather
    /// than vendor-provided clear space. Source bytes are verified but never edited.
    public func fittedGlyph(_ id: String, targetPixelSize: Int) throws -> CGImage {
        guard (1...512).contains(targetPixelSize) else { throw DockArtworkError.invalidManifest }
        func visible(_ image: CGImage) throws -> CGRect {
            let w = image.width, h = image.height
            guard w > 0, h > 0, w <= 4096, h <= 4096,
                  let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else { throw DockArtworkError.invalidManifest }
            c.clear(CGRect(x: 0, y: 0, width: w, height: h)); c.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            guard let bytes = c.data?.assumingMemoryBound(to: UInt8.self) else { throw DockArtworkError.corruptResource(id) }
            var minX = w, minY = h, maxX = -1, maxY = -1
            for y in 0..<h { for x in 0..<w where bytes[(y * w + x) * 4 + 3] > 0 {
                minX = min(minX, x); minY = min(minY, y); maxX = max(maxX, x); maxY = max(maxY, y)
            }}
            guard maxX >= minX, maxY >= minY else { throw DockArtworkError.corruptResource(id) }
            return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        }
        let probe = try image(id, maximumPixelSize: max(256, targetPixelSize))
        let bounds = try visible(probe)
        let fraction = max(bounds.width, bounds.height) / CGFloat(max(probe.width, probe.height))
        guard fraction.isFinite, fraction > 0 else { throw DockArtworkError.corruptResource(id) }
        let needed = Int(ceil(CGFloat(targetPixelSize) / fraction))
        guard needed <= 4096 else { throw DockArtworkError.decodedBudget }
        let raster = try image(id, maximumPixelSize: max(targetPixelSize, needed))
        let crop = try visible(raster)
        guard let glyph = raster.cropping(to: crop), max(glyph.width, glyph.height) > 0 else { throw DockArtworkError.corruptResource(id) }
        return glyph
    }
    private func makeRoom(for bytes:Int) throws {
        guard bytes<=decodedBudget else{throw DockArtworkError.decodedBudget}
        while decodedBytes+bytes>decodedBudget,let victim=images.min(by:{$0.value.age<$1.value.age}) {
            decodedBytes-=victim.value.bytes;images.removeValue(forKey:victim.key)
        }
    }
    public func font(_ id:String,size:CGFloat,weight:Double = 400) throws -> CTFont {
        guard size.isFinite,(1...128).contains(size),weight.isFinite,(1...1000).contains(weight) else{throw DockArtworkError.invalidManifest}
        let (_,data)=try checkedResource(id)
        guard data.starts(with:[0,1,0,0]) || data.starts(with:Array("OTTO".utf8)),
              let provider=CGDataProvider(data:data as CFData),let graphics=CGFont(provider) else{throw DockArtworkError.corruptResource(id)}
        // Build the variable font directly from verified bytes. CoreText omits
        // default-valued axes in CTFontCopyVariation, so verify the explicit
        // graphics-font instance (and its CoreText round trip) instead.
        let base=CTFontCreateWithGraphicsFont(graphics,size,nil,nil)
        let axes=CTFontCopyVariationAxes(base) as? [[CFString:Any]] ?? []
        guard let axis=axes.first(where:{($0[kCTFontVariationAxisIdentifierKey] as? NSNumber)?.uint32Value==0x77676874}) else{return base}
        guard let low=(axis[kCTFontVariationAxisMinimumValueKey] as? NSNumber)?.doubleValue,
              let high=(axis[kCTFontVariationAxisMaximumValueKey] as? NSNumber)?.doubleValue,
              let defaultValue=(axis[kCTFontVariationAxisDefaultValueKey] as? NSNumber)?.doubleValue,
              (low...high).contains(weight),
              let graphicsAxes=graphics.variationAxes as? [[CFString:Any]] else {throw DockArtworkError.corruptResource(id)}
        // CoreText may localize the axis display name while CoreGraphics uses
        // its canonical name. Match by the declared range/default, requiring
        // a unique match rather than assuming a language or axis order.
        let matches=graphicsAxes.filter {
            ($0[CGFont.variationAxisMinValue] as? NSNumber)?.doubleValue == low &&
            ($0[CGFont.variationAxisMaxValue] as? NSNumber)?.doubleValue == high &&
            ($0[CGFont.variationAxisDefaultValue] as? NSNumber)?.doubleValue == defaultValue
        }
        guard matches.count == 1, let name=matches[0][CGFont.variationAxisName] as? String, !name.isEmpty,
              let instance=graphics.copy(withVariations:[name:weight] as CFDictionary),
              let values=instance.variations as? [String:NSNumber], let selected=values[name],
              abs(selected.doubleValue-weight)<0.001 else {throw DockArtworkError.corruptResource(id)}
        let font=CTFontCreateWithGraphicsFont(instance,size,nil,nil)
        guard let roundTrip=CTFontCopyGraphicsFont(font,nil).variations as? [String:NSNumber],
              let actual=roundTrip[name],abs(actual.doubleValue-weight)<0.001 else {throw DockArtworkError.corruptResource(id)}
        return font
    }
    public func purge() {images.removeAll();decodedBytes=0}
}
