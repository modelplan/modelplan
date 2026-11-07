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
    private static let grainRasters = T2GrainRasterCache()
    private lazy var compositor = CIContext(options: [.workingColorSpace: linear, .outputColorSpace: srgb])
    // Headless runners may not have a usable accelerated renderer. Retain a
    // bounded Core Image CPU fallback rather than substituting different art.
    private lazy var softwareCompositor = CIContext(options: [.workingColorSpace: linear, .outputColorSpace: srgb, .useSoftwareRenderer: true])
    public init() {}

    /// sRGB 8-bit code to linear light (IEC 61966-2-1), as SVG's linearRGB conversion.
    nonisolated static let linearTable: [Double] = (0...255).map { code in
        let v = Double(code) / 255
        return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
    }
    nonisolated static func encode(_ linear: Double) -> Double {
        let v = min(1, max(0, linear))
        return v <= 0.0031308 ? 12.92 * v : 1.055 * pow(v, 1 / 2.4) - 0.055
    }
    /// Compositing and Blending Level 1, soft-light: Cb = backdrop (in2), Cs = source (in).
    nonisolated static func softLight(backdrop cb: Double, source cs: Double) -> Double {
        if cs <= 0.5 { return cb - (1 - 2 * cs) * cb * (1 - cb) }
        let d = cb <= 0.25 ? ((16 * cb - 12) * cb + 4) * cb : sqrt(cb)
        return cb + (2 * cs - 1) * (d - cb)
    }

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
        // G3-30 colour: the grain is the study's dkGrain filter, evaluated per pixel exactly as SVG
        // defines it (filters in linearRGB, premultiplied):
        //   feTurbulence -> feColorMatrix(saturate 0) -> feFuncA(slope .018)
        //   -> feBlend(in=SourceGraphic, in2=grain, soft-light) -> feComposite(in2=SourceAlpha, in).
        // The previous Core Image chain handed the unpremultiplied turbulence raster to CIImage as
        // if it were premultiplied, so the grain colour became R/A (about 1, often above) instead of
        // about 0.5; soft-light then lifted every dark tone by roughly 0.01 linear, 15-20 sRGB
        // levels at the screen-edge band. Doing the arithmetic here also removes the dependence on
        // Core Image's blend-mode alpha conventions and on the GPU/CPU renderer choice.
        let noise = Self.grainRasters.raster(viewport: viewport, scale: scale)
        guard let pixels = context.data?.assumingMemoryBound(to: UInt8.self),
              noise.count == width * height * 16 else { throw RenderError.allocation }
        let toLinear = Self.linearTable
        noise.withUnsafeBytes { raw in
            let grain = raw.bindMemory(to: Float.self)
            for index in 0..<(width * height) {
                let p = index * 4
                let alpha = Double(pixels[p + 3]) / 255
                guard alpha > 0 else { continue }
                let n = index * 4
                let backdrop = min(1, max(0, 0.213 * Double(grain[n]) + 0.715 * Double(grain[n + 1]) + 0.072 * Double(grain[n + 2])))
                let grainAlpha = min(1, max(0, 0.018 * Double(grain[n + 3])))
                // feBlend: co = cs(1-ab) + cb(1-as) + as ab B(Cb, Cs); ao = as + ab - as ab.
                let blendedAlpha = alpha + grainAlpha - alpha * grainAlpha
                // feComposite in SourceAlpha.
                let outAlpha = blendedAlpha * alpha
                for channel in 0..<3 {
                    let encoded = min(255, Int((Double(pixels[p + channel]) / alpha).rounded()))
                    let source = toLinear[encoded]
                    let premultiplied = source * alpha * (1 - grainAlpha) + backdrop * grainAlpha * (1 - alpha)
                        + alpha * grainAlpha * Self.softLight(backdrop: backdrop, source: source)
                    let linear = premultiplied / blendedAlpha
                    pixels[p + channel] = UInt8(max(0, min(255, (Self.encode(linear) * outAlpha * 255).rounded())))
                }
                pixels[p + 3] = UInt8(max(0, min(255, (outAlpha * 255).rounded())))
            }
        }
        guard let grained = context.makeImage() else { throw RenderError.allocation }
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
        guard let soot = compositor.createCGImage(blurred, from: canvas)
                ?? softwareCompositor.createCGImage(blurred, from: canvas) else { throw RenderError.filterRender }
        guard soot.width == width, soot.height == height else { throw RenderError.filterExtent("renderedBitmap") }

        // The study composites the clipped dk-material group (soot, ignition well) over the
        // filtered body in sRGB, as ordinary SVG painting; so does this context.
        guard let final = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: srgb,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { throw RenderError.allocation }
        final.draw(grained, in: canvas)
        var device = CGAffineTransform(translationX: 0, y: CGFloat(height)).scaledBy(x: CGFloat(scale), y: -CGFloat(scale))
            .translatedBy(x: -viewport.minX, y: -viewport.minY)
        guard let deviceOutline = outline.copy(using: &device) else { throw RenderError.allocation }
        final.saveGState()
        final.addPath(deviceOutline); final.clip()
        final.draw(soot, in: canvas)
        transform(final)
        let r = 17.8 * unitScale, button = geometry.button
        let well = CGRect(x: button.x - r, y: button.y - r, width: 2*r, height: 2*r)
        final.setFillColor(CGColor(colorSpace: srgb, components: [8.0/255, 12.0/255, 16.0/255, 1])!)
        final.setStrokeColor(CGColor(gray: 0, alpha: 11.0/15))
        final.setLineWidth(0.8 * unitScale); final.addEllipse(in: well); final.drawPath(using: .fillStroke)
        final.restoreGState()
        // Original grip: rocket.css .dk-cap i, positioned by the T2 geometry.
        // Side edges use 10x22, horizontal edges 22x10, scaled with the face.
        transform(final)
        let vertical = geometry.input.coordinates.edge == .left || geometry.input.coordinates.edge == .right
        let gripWidth = (vertical ? 10.0 : 22.0) * unitScale
        let gripHeight = (vertical ? 22.0 : 10.0) * unitScale
        let grip = CGRect(x: geometry.grip.x - gripWidth/2, y: geometry.grip.y - gripHeight/2, width: gripWidth, height: gripHeight)
        let radius = min(6 * unitScale, gripWidth/2, gripHeight/2)
        let path = CGPath(roundedRect: grip, cornerWidth: radius, cornerHeight: radius, transform: nil)
        final.addPath(path); final.setLineWidth(2 * unitScale)
        final.setStrokeColor(CGColor(gray: 0, alpha: 136.0/255)); final.strokePath()
        final.saveGState(); final.addPath(path); final.clip()
        let gripColors = [CGColor(colorSpace: srgb, components: [52.0/255,55.0/255,60.0/255,1])!,
                          CGColor(colorSpace: srgb, components: [29.0/255,31.0/255,35.0/255,1])!]
        guard let gripGradient = CGGradient(colorsSpace: srgb, colors: gripColors as CFArray, locations: [0, 1]) else { throw RenderError.allocation }
        final.drawLinearGradient(gripGradient, start: CGPoint(x: grip.midX, y: grip.minY), end: CGPoint(x: grip.midX, y: grip.maxY), options: [])
        let inset = CGMutablePath()
        inset.addPath(path)
        inset.addRoundedRect(in: grip.offsetBy(dx: 0, dy: unitScale), cornerWidth: radius, cornerHeight: radius)
        final.addPath(inset); final.setFillColor(CGColor(gray: 1, alpha: 28.0/255)); final.drawPath(using: .eoFill)
        final.restoreGState()
        guard let finished = final.makeImage() else { throw RenderError.allocation }
        return finished
    }
}
