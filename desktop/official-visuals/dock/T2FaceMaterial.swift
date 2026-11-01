// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
// Copyright (c) 2026 ModelPlan. All rights reserved.
import Foundation
import CoreGraphics
import CoreImage

/// DOCK-3.1-10/-11: the native face layer. This does not include soot, seams,
/// the well, instruments or ignition; those retain their own back-to-front layers.
@MainActor public final class T2FaceMaterial {
    public enum RenderError: Error { case invalidViewport, allocation, filter }
    private let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
    private let linear = CGColorSpace(name: CGColorSpace.linearSRGB)!
    private let grain = T2Grain()
    private lazy var compositor = CIContext(options: [.workingColorSpace: linear, .outputColorSpace: srgb])
    public init() {}

    /// The viewport is expressed in the same top-left study coordinates as the
    /// geometry, so cropping changes neither gradient registration nor noise phase.
    public func render(geometry: T2Geometry, viewport: CGRect, scale: Int) throws -> CGImage {
        guard (1...3).contains(scale), !viewport.isEmpty,
              [viewport.minX, viewport.minY, viewport.width, viewport.height].allSatisfy(\.isFinite),
              viewport.width <= 4096, viewport.height <= 4096,
              abs(viewport.minX) < 100_000, abs(viewport.minY) < 100_000 else { throw RenderError.invalidViewport }
        let width = Int(ceil(viewport.width * CGFloat(scale))), height = Int(ceil(viewport.height * CGFloat(scale)))
        guard width * height <= 4_194_304 else { throw RenderError.invalidViewport }
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: srgb,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { throw RenderError.allocation }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: CGFloat(scale), y: -CGFloat(scale))
        context.translateBy(x: -viewport.minX, y: -viewport.minY)
        let outline = CGMutablePath()
        guard let first = geometry.outline.first else { throw RenderError.invalidViewport }
        // The study serializes its SVG path with toFixed(3) before rasterization.
        func pathPoint(_ point: CGPoint) -> CGPoint {
            CGPoint(x: (point.x * 1000).rounded() / 1000, y: (point.y * 1000).rounded() / 1000)
        }
        outline.move(to: pathPoint(first))
        for point in geometry.outline.dropFirst() { outline.addLine(to: pathPoint(point)) }
        outline.closeSubpath(); context.addPath(outline); context.clip()
        let inks: [[CGFloat]] = [[21,29,35], [54,63,68], [38,50,57], [16,27,36], [3,9,17]]
        let colors = inks.map { CGColor(colorSpace: srgb, components: [$0[0]/255, $0[1]/255, $0[2]/255, 1])! }
        guard let gradient = CGGradient(colorsSpace: srgb, colors: colors as CFArray,
            locations: [0, 0.17, 0.43, 0.74, 1]) else { throw RenderError.allocation }
        let c = geometry.input.coordinates, depth = geometry.freeDepth
        let start: CGPoint, end: CGPoint
        switch c.edge {
        case .right: start = CGPoint(x: c.width - depth, y: 0); end = CGPoint(x: c.width, y: 0)
        case .left: start = CGPoint(x: 0, y: 0); end = CGPoint(x: depth, y: 0)
        case .bottom: start = CGPoint(x: 0, y: c.height - depth); end = CGPoint(x: 0, y: c.height)
        case .top: start = CGPoint(x: 0, y: c.menuBarExclusion); end = CGPoint(x: 0, y: c.menuBarExclusion + depth)
        }
        context.drawLinearGradient(gradient, start: start, end: end,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        guard let source = context.makeImage() else { throw RenderError.allocation }

        var samples = [Float](repeating: 0, count: width * height * 4)
        for row in 0..<height {
            for column in 0..<width {
                let x = Double(viewport.minX) + (Double(column) + 0.5) / Double(scale)
                let y = Double(viewport.minY) + (Double(row) + 0.5) / Double(scale)
                let channels = grain.channels(x: x, y: y), offset = (row * width + column) * 4
                for channel in 0..<4 { samples[offset + channel] = Float(channels[channel]) }
            }
        }
        let bytes = samples.withUnsafeBytes { Data($0) }
        let noise = CIImage(bitmapData: bytes, bytesPerRow: width * 16,
            size: CGSize(width: width, height: height), format: .RGBAf, colorSpace: linear)
        // feColorMatrix(saturate=0), feFuncA(slope=.018), then the study's
        // feBlend(in=SourceGraphic, mode=soft-light), feComposite(in2=SourceAlpha, in).
        let gray = noise.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0.213, y: 0.715, z: 0.072, w: 0),
            "inputGVector": CIVector(x: 0.213, y: 0.715, z: 0.072, w: 0),
            "inputBVector": CIVector(x: 0.213, y: 0.715, z: 0.072, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: T2Grain.opacity)])
        let graphic = CIImage(cgImage: source)
        let blended = graphic.applyingFilter("CISoftLightBlendMode", parameters: [kCIInputBackgroundImageKey: gray])
        let clipped = blended.applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: graphic])
        guard let result = compositor.createCGImage(clipped, from: CGRect(x: 0, y: 0, width: width, height: height)) else {
            throw RenderError.filter
        }
        return result
    }
}
