// SPDX-License-Identifier: MIT
import Foundation

public enum CockpitProfile: Equatable, Sendable { case full, compact }
public enum CockpitHeightTier: Equatable, Sendable { case full, compact, collapsed }

/// Presentation supplies closed dimensions after its reference is frozen.
/// Heights measure the visible body; the exhaust reserve is separate.
public struct CockpitMetrics: Equatable, Sendable {
    public let contentWidth: CGFloat
    public let silhouetteWidth: CGFloat
    public let closedFullHeight: CGFloat
    public let closedCompactHeight: CGFloat
    public let exhaustReserve: CGFloat
    public static let fullHeight: CGFloat = 890
    public static let compactHeight: CGFloat = 640
    public static let topGap: CGFloat = 6

    public init(contentWidth: CGFloat, silhouetteWidth: CGFloat,
                closedFullHeight: CGFloat, closedCompactHeight: CGFloat,
                exhaustReserve: CGFloat = 34) {
        precondition(contentWidth.isFinite && contentWidth > 0)
        precondition(silhouetteWidth.isFinite && silhouetteWidth >= contentWidth)
        precondition(closedFullHeight.isFinite && closedFullHeight > 0)
        precondition(closedCompactHeight.isFinite && closedCompactHeight > 0)
        precondition(exhaustReserve.isFinite && exhaustReserve >= 0)
        self.contentWidth = contentWidth
        self.silhouetteWidth = silhouetteWidth
        self.closedFullHeight = closedFullHeight
        self.closedCompactHeight = closedCompactHeight
        self.exhaustReserve = exhaustReserve
    }

    public func bodyHeight(profile: CockpitProfile, closed: Bool) -> CGFloat {
        switch (profile, closed) {
        case (.full, false): return Self.fullHeight
        case (.compact, false): return Self.compactHeight
        case (.full, true): return closedFullHeight
        case (.compact, true): return closedCompactHeight
        }
    }
}

/// Already resolved by the native display coordinator, in global AppKit points (Y up).
/// `usableFrame` excludes system UI/safe areas once, including the usable menu-bar underside.
public struct CockpitPlacementInput: Equatable, Sendable {
    public let usableFrame: CGRect
    public let anchorX: CGFloat
    /// Point within the content's top edge that should align with the menu-bar icon.
    public let anchorOffset: CGFloat

    public init(usableFrame: CGRect, anchorX: CGFloat, anchorOffset: CGFloat) {
        self.usableFrame = usableFrame
        self.anchorX = anchorX
        self.anchorOffset = anchorOffset
    }
}

public struct CockpitFit: Equatable, Sendable {
    public let profile: CockpitProfile
    public let tier: CockpitHeightTier
    public let forcedClosed: Bool
    public let scale: CGFloat
    public let unscaledBodyHeight: CGFloat
    /// The visible body starts at this frame's top; no transparent window padding is included.
    public let contentFrame: CGRect
    /// Includes the complete silhouette and scaled exhaust reserve.
    public let occupiedFrame: CGRect

    public var isClosed: Bool { tier == .collapsed }

    /// Root-local points are measured from the visible top, with Y down.
    public func screenPoint(from local: CGPoint) -> CGPoint {
        CGPoint(x: contentFrame.minX + local.x * scale, y: contentFrame.maxY - local.y * scale)
    }

    public func localPoint(from screen: CGPoint) -> CGPoint {
        CGPoint(x: (screen.x - contentFrame.minX) / scale, y: (contentFrame.maxY - screen.y) / scale)
    }
}

public enum CockpitLayout {
    /// No NSScreen lookup, backing-pixel rounding, scrolling, or module-specific shrinking.
    /// Nil means no usable area, invalid placement input, or an open silhouette too wide to fit.
    public static func fit(_ input: CockpitPlacementInput, metrics: CockpitMetrics,
                           window: CockpitWindowState) -> CockpitFit? {
        let area = input.usableFrame
        guard !area.isNull, !area.isInfinite,
              area.origin.x.isFinite, area.origin.y.isFinite,
              area.width.isFinite, area.height.isFinite,
              area.width > 0, area.height > CockpitMetrics.topGap,
              input.anchorX.isFinite, input.anchorOffset.isFinite,
              (0...metrics.contentWidth).contains(input.anchorOffset) else { return nil }

        let heightBelowGap = area.height - CockpitMetrics.topGap
        let bodyBudget = heightBelowGap - metrics.exhaustReserve
        let profile: CockpitProfile = bodyBudget >= CockpitMetrics.fullHeight ? .full : .compact
        let forcedClosed = bodyBudget < CockpitMetrics.compactHeight
        let closed = window.isClosed(forcedClosed: forcedClosed)
        // The height tiers do not introduce a new width-triggered closure policy.
        guard closed || area.width >= metrics.silhouetteWidth else { return nil }
        let height = metrics.bodyHeight(profile: profile, closed: closed)
        let scale: CGFloat = closed
            ? min(1, heightBelowGap / (height + metrics.exhaustReserve), area.width / metrics.silhouetteWidth)
            : 1
        let overhang = (metrics.silhouetteWidth - metrics.contentWidth) / 2 * scale
        let contentWidth = metrics.contentWidth * scale
        let desiredX = input.anchorX - input.anchorOffset * scale
        let x = max(area.minX + overhang, min(desiredX, area.maxX - contentWidth - overhang))
        let top = area.maxY - CockpitMetrics.topGap
        let body = CGRect(x: x, y: top - height * scale, width: contentWidth, height: height * scale)
        let occupied = CGRect(x: x - overhang, y: body.minY - metrics.exhaustReserve * scale,
                              width: metrics.silhouetteWidth * scale,
                              height: (height + metrics.exhaustReserve) * scale)
        return CockpitFit(profile: profile, tier: closed ? .collapsed : (profile == .full ? .full : .compact),
                          forcedClosed: forcedClosed, scale: scale, unscaledBodyHeight: height,
                          contentFrame: body, occupiedFrame: occupied)
    }
}
