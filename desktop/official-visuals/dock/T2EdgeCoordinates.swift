// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
// Copyright (c) 2026 ModelPlan. All rights reserved.
import CoreGraphics
import Foundation

/// T2 study coordinates use a top-left origin; callers convert once at the
/// boundary when drawing into a non-flipped AppKit coordinate space.
public enum T2Edge: Sendable {
    case left, right, bottom, top
}

/// The source-art constants are scaled from M52; screen clearance and the
/// wake target are physical points and do not scale with the instruments.
public enum T2GeometryConstants {
    public static let wakeDepth: CGFloat = 20
    public static let cornerExclusion: CGFloat = 24
    public static let maximumSlice: CGFloat = 16 * .pi / 180
    public static let maximumSagitta: CGFloat = 8

    public static func sourceScale(diameter: CGFloat) -> CGFloat {
        diameter / 52
    }

    /// Matches the study's 60-step bisection on a length in M52 units.
    public static func slice(for length: CGFloat) -> CGFloat {
        func sagitta(_ angle: CGFloat) -> CGFloat {
            length / angle * (1 - cos(angle / 2))
        }
        if sagitta(maximumSlice) <= maximumSagitta { return maximumSlice }
        var low: CGFloat = 0.000001
        var high = maximumSlice
        for _ in 0..<60 {
            let midpoint = (low + high) / 2
            if sagitta(midpoint) > maximumSagitta { high = midpoint }
            else { low = midpoint }
        }
        return low
    }
}

public struct T2EdgeCoordinates: Sendable {
    public let edge: T2Edge
    public let width: CGFloat
    public let height: CGFloat
    public let menuBarExclusion: CGFloat

    public init(edge: T2Edge, width: CGFloat, height: CGFloat, menuBarExclusion: CGFloat) {
        self.edge = edge
        self.width = width
        self.height = height
        self.menuBarExclusion = menuBarExclusion
    }

    public func point(along u: CGFloat, inward d: CGFloat, midpoint: CGFloat) -> CGPoint {
        switch edge {
        case .right: return CGPoint(x: width - d, y: midpoint + u)
        case .left: return CGPoint(x: d, y: midpoint + u)
        case .bottom: return CGPoint(x: midpoint + u, y: height - d)
        case .top: return CGPoint(x: midpoint + u, y: menuBarExclusion + d)
        }
    }

    public func direction(along u: CGFloat, inward d: CGFloat) -> CGVector {
        switch edge {
        case .right: return CGVector(dx: -d, dy: u)
        case .left: return CGVector(dx: d, dy: u)
        case .bottom: return CGVector(dx: u, dy: -d)
        case .top: return CGVector(dx: u, dy: d)
        }
    }
}
