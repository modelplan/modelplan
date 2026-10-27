// SPDX-License-Identifier: MIT
import Foundation
import CoreGraphics

/// Uniform point-space adaptation of an injected recipe. No art or palette is recreated.
public extension DockInstrumentSkin {
    func scaled(by factor: CGFloat) throws -> DockInstrumentSkin {
        guard factor.isFinite, factor > 0, factor <= 8,
              bodyPolygon.count <= 4096, fixedLayers.count <= 1024, stations.count <= 64,
              stations.allSatisfy({ $0.logicalPoints.map { (1...2048).contains($0) } ?? true }) else {
            throw DockArtworkError.invalidManifest
        }
        func point(_ p: CGPoint) -> CGPoint { .init(x: p.x * factor, y: p.y * factor) }
        func rect(_ r: CGRect) -> CGRect {
            .init(x: r.minX * factor, y: r.minY * factor, width: r.width * factor, height: r.height * factor)
        }
        func ring(_ r: DockRingRecipe) -> DockRingRecipe {
            var value = r; value.radius *= factor; value.width *= factor
            value.unknownDash = value.unknownDash?.map { $0 * factor }; return value
        }
        var result = self
        result.bounds = rect(bounds); result.bodyPolygon = bodyPolygon.map(point)
        result.fixedLayers = fixedLayers.map { var v = $0; v.rect = rect(v.rect); return v }
        result.text.size *= factor; result.aliasText.size *= factor
        result.stations = stations.map {
            var v = $0
            v.centre = point(v.centre); v.diameter *= factor
            v.logicalPoints = v.logicalPoints.map { max(1, Int((CGFloat($0) * factor).rounded())) }
            v.readout = rect(v.readout); v.aliasRect = v.aliasRect.map(rect)
            v.eventRect = rect(v.eventRect); v.glyphRect = rect(v.glyphRect)
            v.outer = ring(v.outer); v.inner = ring(v.inner)
            v.clock.radius *= factor; v.clock.dotRadius *= factor; v.clock.backWidth *= factor
            v.notchWidth *= factor; v.caseInnerRadius *= factor
            v.eventSolidDiameter = v.eventSolidDiameter.map { $0 * factor }
            v.eventHollowDiameter = v.eventHollowDiameter.map { $0 * factor }
            v.eventStrokeWidth = v.eventStrokeWidth.map { $0 * factor }
            v.eventSolidOutlineWidth = v.eventSolidOutlineWidth.map { $0 * factor }
            if var placeholder = v.placeholderText { placeholder.size *= factor; v.placeholderText = placeholder }
            return v
        }
        return result
    }
}
