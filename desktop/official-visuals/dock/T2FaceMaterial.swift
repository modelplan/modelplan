// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
// Copyright (c) 2026 ModelPlan. All rights reserved.
import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// DOCK-3.1-10/-11/-20: native face material, soot and clipped ignition well.
/// Instruments, the grip and ignition remain later layers.
@MainActor public final class T2FaceMaterial {
    public enum RenderError: Error { case invalidViewport, allocation, filterStage(String), filterExtent(String), filterRender }
    private let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
    private let linear = CGColorSpace(name: CGColorSpace.linearSRGB)!
    private let grain = T2Grain()
    private lazy var compositor = CIContext(options: [.workingColorSpace: linear, .outputColorSpace: srgb])
    // Headless runners may not have a usable accelerated renderer. Retain a
    // bounded Core Image CPU fallback rather than substituting different art.
    private lazy var softwareCompositor = CIContext(options: [.workingColorSpace: linear, .outputColorSpace: srgb, .useSoftwareRenderer: true])
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
        let canvas = CGRect(x: 0, y: 0, width: width, height: height)
        // A bounded extent is part of the rendering contract. In particular,
        // blur may grow its extent; crop each output to the requested bitmap.
        func checked(_ value: CIImage?, _ stage: String) throws -> CIImage {
            guard let value else { throw RenderError.filterStage(stage) }
            let extent = value.extent
            guard !extent.isNull, !extent.isEmpty, !extent.isInfinite,
                  [extent.minX, extent.minY, extent.width, extent.height].allSatisfy(\.isFinite),
                  extent.contains(canvas) else { throw RenderError.filterExtent(stage) }
            return value.cropped(to: canvas)
        }
        let matrix = CIFilter.colorMatrix()
        matrix.inputImage = noise
        matrix.rVector = CIVector(x: 0.213, y: 0.715, z: 0.072, w: 0)
        matrix.gVector = CIVector(x: 0.213, y: 0.715, z: 0.072, w: 0)
        matrix.bVector = CIVector(x: 0.213, y: 0.715, z: 0.072, w: 0)
        matrix.aVector = CIVector(x: 0, y: 0, z: 0, w: T2Grain.opacity)
        let gray = try checked(matrix.outputImage, "colorMatrix")
        let graphic = CIImage(cgImage: source)
        let blend = CIFilter.softLightBlendMode()
        blend.inputImage = graphic; blend.backgroundImage = gray
        let blended = try checked(blend.outputImage, "softLightBlendMode")
        let clip = CIFilter.sourceInCompositing()
        clip.inputImage = blended; clip.backgroundImage = graphic
        let clipped = try checked(clip.outputImage, "sourceInFace")
        // face-view.js places three quadratic soot fans per station. They use
        // the station mapping, never a second fit to the face contour.
        guard let sootContext = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: srgb,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { throw RenderError.allocation }
        func transform(_ c: CGContext) {
            c.translateBy(x: 0, y: CGFloat(height)); c.scaleBy(x: CGFloat(scale), y: -CGFloat(scale))
            c.translateBy(x: -viewport.minX, y: -viewport.minY)
        }
        transform(sootContext)
        let unitScale = geometry.input.diameter / 52
        for station in geometry.stations {
            for k in [-1, 0, 1] {
                let k = CGFloat(k), s = station.arcPosition, depth = geometry.stationDepth
                let start = geometry.point(arc: s + k * 5 * unitScale, depth: depth + 15 * unitScale)
                let control = geometry.point(arc: s + (k * 10 + 7) * unitScale, depth: depth + 26 * unitScale)
                let end = geometry.point(arc: s + (k * 15 + 13) * unitScale, depth: depth + 37 * unitScale)
                let last = geometry.point(arc: s + (k * 10 + 12) * unitScale, depth: depth + 33 * unitScale)
                sootContext.beginPath(); sootContext.move(to: pathPoint(start))
                sootContext.addQuadCurve(to: pathPoint(end), control: pathPoint(control))
                sootContext.addLine(to: pathPoint(last)); sootContext.closePath()
                sootContext.setFillColor(CGColor(colorSpace: srgb,
                    components: [1.0/255, 4.0/255, 7.0/255, k == 0 ? 0.13 : 0.09])!)
                sootContext.fillPath()
            }
        }
        guard let sootBitmap = sootContext.makeImage() else { throw RenderError.allocation }
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = CIImage(cgImage: sootBitmap)
        blur.radius = Float(1.1 * unitScale * CGFloat(scale))
        let blurred = try checked(blur.outputImage, "gaussianBlur")
        let sootClip = CIFilter.sourceInCompositing()
        sootClip.inputImage = blurred; sootClip.backgroundImage = graphic
        let soot = try checked(sootClip.outputImage, "sourceInSoot")
        let sootOver = CIFilter.sourceOverCompositing()
        sootOver.inputImage = soot; sootOver.backgroundImage = clipped
        let withSoot = try checked(sootOver.outputImage, "sourceOverSoot")
        guard let wellContext = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: srgb,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { throw RenderError.allocation }
        transform(wellContext); wellContext.addPath(outline); wellContext.clip()
        let r = 17.8 * unitScale, button = geometry.button
        let well = CGRect(x: button.x - r, y: button.y - r, width: 2*r, height: 2*r)
        wellContext.setFillColor(CGColor(colorSpace: srgb, components: [8.0/255, 12.0/255, 16.0/255, 1])!)
        wellContext.setStrokeColor(CGColor(gray: 0, alpha: 11.0/15))
        wellContext.setLineWidth(0.8 * unitScale); wellContext.addEllipse(in: well); wellContext.drawPath(using: .fillStroke)
        guard let wellBitmap = wellContext.makeImage() else { throw RenderError.allocation }
        let wellOver = CIFilter.sourceOverCompositing()
        wellOver.inputImage = CIImage(cgImage: wellBitmap); wellOver.backgroundImage = withSoot
        let face = try checked(wellOver.outputImage, "sourceOverWell")
        guard let result = compositor.createCGImage(face, from: canvas)
                ?? softwareCompositor.createCGImage(face, from: canvas) else { throw RenderError.filterRender }
        guard result.width == width, result.height == height else { throw RenderError.filterExtent("renderedBitmap") }
        return result
    }
}
