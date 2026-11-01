// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
// Copyright (c) 2026 ModelPlan. All rights reserved.
import CoreGraphics
import Foundation
import ModelPlanDock

/// The source Canvas impact jet, in its original 100-unit coordinate system.
/// This produces one transient frame; lifecycle and scheduling belong to the host.
public enum T2ImpactJet {
    public enum Failure: Error { case invalidInput, allocation }
    public static func frame(diameter: CGFloat, backingScale: CGFloat, status: DockQuotaStatus, time: Double) throws -> CGImage {
        guard diameter.isFinite, (8...256).contains(diameter), backingScale.isFinite, (1...2).contains(backingScale), time.isFinite, time >= 0 else { throw Failure.invalidInput }
        let rgb: (CGFloat, CGFloat, CGFloat)
        switch status {
        case .normal: rgb = (90/255, 217/255, 186/255)
        case .warning: rgb = (234/255, 193/255, 123/255)
        case .critical: rgb = (239/255, 68/255, 68/255)
        case .unknown: throw Failure.invalidInput
        }
        let n = Int((diameter * min(backingScale, 1.5)).rounded()), rowBytes = ((n * 4 + 63) / 64) * 64
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        guard n > 0, let c = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: rowBytes,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { throw Failure.allocation }
        c.clear(CGRect(x: 0, y: 0, width: n, height: n))
        c.translateBy(x: 0, y: CGFloat(n)); c.scaleBy(x: CGFloat(n)/100, y: -CGFloat(n)/100)
        c.translateBy(x: 50, y: 50); c.setBlendMode(.plusLighter)
        let gap = max(3, 3 * diameter / 44)
        let inner = 27 * sqrt(2.0) / 2 + (1.25 + gap) * 100 / diameter
        let clip = CGMutablePath(); clip.addEllipse(in: CGRect(x: -34, y: -34, width: 68, height: 68))
        clip.addEllipse(in: CGRect(x: -inner, y: -inner, width: 2*inner, height: 2*inner))
        c.addPath(clip); c.clip(using: .evenOdd)
        func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: Double) -> CGColor {
            CGColor(colorSpace: space, components: [r,g,b,CGFloat(max(0,min(1,a)))])!
        }
        func gradient(_ colors: [CGColor], _ stops: [CGFloat]) throws -> CGGradient {
            guard let value = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: stops) else { throw Failure.allocation }
            return value
        }
        let pulse = 0.88 + 0.07 * sin(time * 4.7) + 0.05 * sin(time * 8.1 + 1.1)
        let glow = try gradient([color(240/255,255/255,248/255,0.65*pulse),color(rgb.0,rgb.1,rgb.2,0.8*pulse),
                                 color(rgb.0,rgb.1,rgb.2,0.38*pulse),color(rgb.0,rgb.1,rgb.2,0)], [0,0.42,0.68,1])
        c.saveGState(); c.clip(to: CGRect(x: -39, y: -39, width: 78, height: 78))
        c.drawRadialGradient(glow, startCenter: CGPoint(x: -2, y: 1), startRadius: 4,
            endCenter: .zero, endRadius: 36, options: [.drawsBeforeStartLocation]); c.restoreGState()
        c.setShadow(offset: .zero, blur: 2.2, color: color(rgb.0,rgb.1,rgb.2,0.8))
        for layer in 0..<3 {
            let radius = 25.3 + Double(layer) * 2.1
            c.beginPath()
            for i in 0...80 {
                let angle = Double(i) * 2 * Double.pi / 80
                let noise = 1 + 0.045*sin(angle*3.1 + time*2.7 + Double(layer)) + 0.035*sin(angle*7.3-time*3.8+Double(layer)*2)
                let p = CGPoint(x: cos(angle)*radius*noise, y: sin(angle)*radius*noise)
                if i == 0 { c.move(to: p) } else { c.addLine(to: p) }
            }
            c.closePath(); c.setLineWidth(layer == 0 ? 2.8 : 3.4)
            c.setStrokeColor(layer == 0 ? color(223/255,1,240/255,0.38*pulse) : color(rgb.0,rgb.1,rgb.2,(0.31-Double(layer)*0.06)*pulse))
            c.strokePath()
        }
        for i in 0..<3 {
            let phase = (time * 0.64 + Double(i) * 0.335).truncatingRemainder(dividingBy: 1)
            let radius = 12 + phase * 23, vertical = radius * (0.84 + 0.05 * sin(time + Double(i)))
            c.saveGState(); c.translateBy(x: -2 + sin(time*2 + Double(i)), y: 1); c.rotate(by: 0.25)
            c.setStrokeColor(color(rgb.0,rgb.1,rgb.2,0.29*sin(phase * .pi)*pulse)); c.setLineWidth(1.8*(1-phase)+0.3)
            c.strokeEllipse(in: CGRect(x: -radius, y: -vertical, width: 2*radius, height: 2*vertical)); c.restoreGState()
        }
        for i in 0..<6 {
            let a = Double(i)*2.39996 + sin(time*0.6+Double(i))*0.18
            let radius = 14 + 3*sin(time*2.1+Double(i)), end = 33 + 2*sin(time*4+Double(i)*1.8)
            let from = CGPoint(x:cos(a)*radius,y:sin(a)*radius), to = CGPoint(x:cos(a)*end,y:sin(a)*end)
            let ray = CGMutablePath(); ray.move(to: from)
            ray.addQuadCurve(to: to, control: CGPoint(x:cos(a+0.19)*26,y:sin(a+0.19)*26))
            let shape = ray.copy(strokingWithWidth: 1.25 + Double(i % 2)*0.55, lineCap: .butt, lineJoin: .miter, miterLimit: 10)
            let colors = [color(244/255,1,245/255,0.69*pulse),color(rgb.0,rgb.1,rgb.2,0.8*pulse),color(rgb.0,rgb.1,rgb.2,0)]
            let ramp = try gradient(colors, [0,0.45,1])
            // Draw the gradient-filled stroke in a transparency layer so the
            // original persistent shadow is applied to the stroke's alpha.
            c.saveGState(); c.beginTransparencyLayer(auxiliaryInfo: nil)
            c.addPath(shape); c.clip(); c.drawLinearGradient(ramp, start: from, end: to, options: [])
            c.endTransparencyLayer(); c.restoreGState()
        }
        let hot = try gradient([color(246/255,1,249/255,0.49*pulse),color(rgb.0,rgb.1,rgb.2,0.22*pulse),color(rgb.0,rgb.1,rgb.2,0)], [0,0.4,1])
        c.saveGState(); c.clip(to: CGRect(x: -25, y: -25, width: 42, height: 42))
        c.drawRadialGradient(hot, startCenter: CGPoint(x: -7, y: -7), startRadius: 0,
                             endCenter: CGPoint(x: -7, y: -7), endRadius: 15, options: [.drawsBeforeStartLocation]); c.restoreGState()
        guard let image = c.makeImage() else { throw Failure.allocation }
        return image
    }
}
