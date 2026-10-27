// SPDX-License-Identifier: MIT
import Foundation
import CoreGraphics

public struct DockNozzleDiameters: Equatable, Sendable {
    public static let current = DockNozzleDiameters(small: 36, medium: 44, large: 52)
    public var small: CGFloat, medium: CGFloat, large: CGFloat
    public init(small: CGFloat, medium: CGFloat, large: CGFloat) { self.small = small; self.medium = medium; self.large = large }
}
public enum DockSliverLength: Equatable, Sendable { case fullSpan, fixed(CGFloat) }
public struct DockSliverScaleTable: Equatable, Sendable {
    public var small: CGFloat, medium: CGFloat, large: CGFloat
    public init(small: CGFloat, medium: CGFloat, large: CGFloat) { self.small = small; self.medium = medium; self.large = large }
}
/// Geometry policy only. Suppliers continue to own the artwork and its registration.
public struct DockSliverParameters: Equatable, Sendable {
    // Change the approved geometry here; tracking depth is physical and never size-scaled.
    public static let current = DockSliverParameters(visibleThickness: 4, visibleLength: .fullSpan, trackingDepth: 20,
        sizeScales: .init(small: DockNozzleDiameters.current.small / DockNozzleDiameters.current.medium, medium: 1,
                          large: DockNozzleDiameters.current.large / DockNozzleDiameters.current.medium))
    public var visibleThickness: CGFloat, visibleLength: DockSliverLength, trackingDepth: CGFloat
    public var sizeScales: DockSliverScaleTable
    public init(visibleThickness: CGFloat, visibleLength: DockSliverLength, trackingDepth: CGFloat, sizeScales: DockSliverScaleTable) {
        self.visibleThickness = visibleThickness; self.visibleLength = visibleLength
        self.trackingDepth = trackingDepth; self.sizeScales = sizeScales
    }
    public func resolve(fullSpan: CGFloat, scale: CGFloat) throws -> (length: CGFloat, thickness: CGFloat) {
        let scales = [sizeScales.small, sizeScales.medium, sizeScales.large, scale]
        guard scales.allSatisfy({ $0.isFinite && $0 > 0 && $0 <= 8 }),
              fullSpan.isFinite, fullSpan > 0, fullSpan <= 4096,
              visibleThickness.isFinite, visibleThickness > 0, visibleThickness <= 256,
              trackingDepth.isFinite, trackingDepth > 0, trackingDepth <= 256 else { throw DockEdgeError.invalidGeometry }
        let length: CGFloat
        switch visibleLength { case .fullSpan: length = fullSpan; case .fixed(let points): length = points * scale }
        let thickness = visibleThickness * scale
        guard length.isFinite, length > 0, length <= 4096, thickness <= trackingDepth else { throw DockEdgeError.invalidGeometry }
        return (length, thickness)
    }
}
