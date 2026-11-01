// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
// Copyright (c) 2026 ModelPlan. All rights reserved.
import Foundation
import CoreGraphics

/// Rendering values supplied by the admitted per-member provider presentation.
/// This is not a wire decoder, event lifetime reducer or acknowledgement store.
public struct T2ResetEventPresentation: Sendable, Codable {
    public enum Style: String, Codable, Sendable, Equatable { case announced, confirmed }
    public let memberKey: String
    public let style: Style
    public let unacknowledged: Bool
    public init(memberKey: String, style: Style, unacknowledged: Bool) {
        self.memberKey = memberKey; self.style = style; self.unacknowledged = unacknowledged
    }
}

public struct T2ResetDot: Sendable {
    public enum Surface: Sendable, Equatable { case dock, sliver }
    public let memberKey: String
    public let surface: Surface
    public let style: T2ResetEventPresentation.Style
    public let centre: CGPoint
    public let diameter: CGFloat
    public let strokeWidth: CGFloat
    public let opacity: CGFloat
    public let outlineWidth: CGFloat
    public static var blue: CGColor {
        CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [159.0/255, 210.0/255, 1, 1])!
    }
}

public enum T2ResetEventDots {
    public enum Failure: Error { case duplicateMember, tooManyEvents, invalidReadout, invalidSliver }

    /// Dock centres are in study coordinates; sliver centres are local top-left
    /// coordinates. The caller supplies the actual percentage-row rectangles,
    /// including alias layout, rather than inferring them from names or labels.
    public static func layout(geometry: T2Geometry, events: [T2ResetEventPresentation],
                              percentageRows: [String: CGRect], showsPercentages: Bool,
                              nozzlePresentationRects: [String: CGRect] = [:],
                              sliverSize suppliedSize: CGSize? = nil) throws -> [T2ResetDot] {
        guard events.count <= 256 else { throw Failure.tooManyEvents }
        guard Set(events.map(\.memberKey)).count == events.count else { throw Failure.duplicateMember }
        let d = geometry.input.diameter, scale = d / 52
        let horizontal = geometry.input.coordinates.edge == .bottom || geometry.input.coordinates.edge == .top
        let thickness = 4 * d / 44
        let size = suppliedSize ?? (horizontal ? CGSize(width: geometry.span, height: thickness) : CGSize(width: thickness, height: geometry.span))
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else { throw Failure.invalidSliver }
        let admitted = Set((geometry.shown + geometry.overflow).map(\.id))
        var result = [T2ResetDot]()
        for event in events where admitted.contains(event.memberKey) {
            guard let station = geometry.stations.first(where: { $0.subscription?.id == event.memberKey }) ??
                    (geometry.overflow.contains(where: { $0.id == event.memberKey }) ? geometry.stations.first(where: \.isOverflow) : nil) else { continue }
            // Hidden overflow members map to the +N station on the sliver.
            // The open Dock/tray only paints them when an actual row/nozzle
            // anchor was supplied; do not invent a notice on the +N control.
            let drawDock = !station.isOverflow || (showsPercentages
                ? percentageRows[event.memberKey] != nil : nozzlePresentationRects[event.memberKey] != nil)
            if drawDock {
                let centre: CGPoint
                if showsPercentages {
                    guard let row = percentageRows[event.memberKey], !row.isEmpty,
                          [row.minX, row.minY, row.maxX, row.maxY, row.width, row.height].allSatisfy(\.isFinite) else { throw Failure.invalidReadout }
                    // The 12-unit target starts 16 units after the value centre;
                    // its painted dot sits another 6 units into that target.
                    centre = CGPoint(x: row.midX + 22 * scale, y: row.midY)
                } else {
                    // Screen-space one o'clock, independent of the attached edge.
                    let nozzle = nozzlePresentationRects[event.memberKey] ?? CGRect(x: station.centre.x - d/2,
                        y: station.centre.y - d/2, width: d, height: d)
                    guard !nozzle.isEmpty, [nozzle.minX, nozzle.minY, nozzle.maxX, nozzle.maxY, nozzle.width, nozzle.height].allSatisfy(\.isFinite),
                          abs(nozzle.width - nozzle.height) <= 1e-7 else { throw Failure.invalidReadout }
                    centre = CGPoint(x: nozzle.midX + nozzle.width * 0.25, y: nozzle.midY - nozzle.height * 0.433013)
                }
                result.append(T2ResetDot(memberKey: event.memberKey, surface: .dock, style: event.style,
                    centre: centre, diameter: (event.style == .announced ? 6 : 5) * scale,
                    strokeWidth: event.style == .announced ? 1.2 * scale : 0, opacity: 1,
                    outlineWidth: event.style == .confirmed && showsPercentages ? scale : 0))
            }
            if event.unacknowledged {
                let position = horizontal ? station.centre.x : station.centre.y
                let normalized = max(0, min(1, (position - (geometry.placementCentre - geometry.span / 2)) / geometry.span))
                result.append(T2ResetDot(memberKey: event.memberKey, surface: .sliver, style: event.style,
                    centre: horizontal ? CGPoint(x: normalized * size.width, y: size.height / 2) :
                        CGPoint(x: size.width / 2, y: normalized * size.height),
                    diameter: 4 * d / 44, strokeWidth: event.style == .announced ? d / 44 : 0,
                    opacity: 0.7, outlineWidth: 0))
            }
        }
        return result
    }

    /// Paints supplied state only, in the event pass after the dot-free static
    /// background has been captured. Never retain these dots in the material
    /// cache. The caller supplies the coordinate transform; this does not ack.
    public static func draw(_ dots: [T2ResetDot], surface: T2ResetDot.Surface, in context: CGContext) {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        for dot in dots where dot.surface == surface {
            context.saveGState(); defer { context.restoreGState() }
            context.setBlendMode(.normal); context.setLineDash(phase: 0, lengths: [])
            context.setAlpha(dot.opacity)
            let bounds = CGRect(x: dot.centre.x - dot.diameter / 2, y: dot.centre.y - dot.diameter / 2,
                width: dot.diameter, height: dot.diameter)
            if dot.outlineWidth > 0 {
                context.setFillColor(CGColor(colorSpace: space, components: [16.0/255, 21.0/255, 28.0/255, 0.6])!)
                context.fillEllipse(in: bounds.insetBy(dx: -dot.outlineWidth, dy: -dot.outlineWidth))
            }
            if dot.style == .announced {
                if dot.surface == .dock {
                    context.setFillColor(CGColor(colorSpace: space, components: [16.0/255, 21.0/255, 28.0/255, 1])!)
                    context.fillEllipse(in: bounds)
                }
                context.setStrokeColor(T2ResetDot.blue); context.setLineWidth(dot.strokeWidth)
                context.strokeEllipse(in: bounds.insetBy(dx: dot.strokeWidth / 2, dy: dot.strokeWidth / 2))
            } else {
                context.setFillColor(T2ResetDot.blue); context.fillEllipse(in: bounds)
            }
        }
    }
}
