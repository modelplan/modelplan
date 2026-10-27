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
        // The descriptor array may start at a named Thin instance, not the font's default instance.
        let base=CTFontCreateWithGraphicsFont(graphics,size,nil,nil)
        let axes=CTFontCopyVariationAxes(base) as? [[CFString:Any]] ?? []
        guard axes.contains(where:{($0[kCTFontVariationAxisIdentifierKey] as? NSNumber)?.uint32Value==0x77676874}) else{return base}
        let desired=CTFontDescriptorCreateWithAttributes([kCTFontVariationAttribute:[NSNumber(value:0x77676874):NSNumber(value:weight)]] as CFDictionary)
        return CTFontCreateCopyWithAttributes(base,size,nil,desired)
    }
    public func purge() {images.removeAll();decodedBytes=0}
}
