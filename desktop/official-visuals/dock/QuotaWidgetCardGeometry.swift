// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
// Copyright (c) 2026 ModelPlan. All rights reserved.
import Foundation
import CoreGraphics

// Structural measurements supplied from the owner-approved r7 capture at
// 69f1b639201f0b9cedd1ad9f109d26423e67e75f; no prototype source or artwork copied.
/// Structural measurements only. Rendering, fonts and artwork are supplied separately.
public enum QuotaWidgetCardGeometry {
    public static let plateWidth: CGFloat = 304
    public static let plateRadius: CGFloat = 12
    public static let plateVerticalPadding: CGFloat = 10
    public static let plateHorizontalPadding: CGFloat = 11
    public static let lcdRadius: CGFloat = 8
    public static let lcdVerticalPadding: CGFloat = 5
    public static let lcdHorizontalPadding: CGFloat = 7
    public static let headingIconSize: CGFloat = 20
    public static let headingGap: CGFloat = 8
    public static let headingBottomGap: CGFloat = 7
    /// face.css task 36 widened the label column to 56 so LCD glyphs fit "Fable·wk" / "Fable·周".
    public static let rowFixedColumns: [CGFloat] = [56, 78, 34]
    public static let rowColumnGap: CGFloat = 5
    public static let rowMinimumHeight: CGFloat = 18
    public static let barSegments = 10
    public static let barHeight: CGFloat = 7
    public static let barSegmentGap: CGFloat = 1.5
    public static let arrowTransverseSize: CGFloat = 16
    public static let arrowTipBeyondRing: CGFloat = 2
    public static let arrowPlateOverlap: CGFloat = 1

    /// Four columns: the first three are fixed and the last takes the remainder.
    public static func rowColumnWidths(availableWidth: CGFloat) -> [CGFloat]? {
        let remainder = availableWidth - rowFixedColumns.reduce(0, +) - 3 * rowColumnGap
        guard availableWidth.isFinite, remainder.isFinite, remainder >= 0 else { return nil }
        return rowFixedColumns + [remainder]
    }

    public static func barSegmentWidth(availableWidth: CGFloat) -> CGFloat? {
        let usable = availableWidth - CGFloat(barSegments - 1) * barSegmentGap
        guard availableWidth.isFinite, usable.isFinite, usable >= 0 else { return nil }
        return usable / CGFloat(barSegments)
    }

    public static func anchorSpacing(nozzleDiameter: CGFloat) -> CGFloat? {
        guard nozzleDiameter.isFinite, nozzleDiameter > 0 else { return nil }
        return 12 * (nozzleDiameter / 52)
    }

    /// The caller computes both candidates from the actual nozzle ring, in the
    /// same coordinate space as the available frame. No synthetic anchor is used.
    public static func place(anchorRing: CGRect?, preferred: CGRect, flipped: CGRect,
                             available: CGRect) -> Placement? {
        guard let anchorRing, valid(anchorRing), valid(available),
              valid(preferred), valid(flipped),
              preferred.size == flipped.size,
              preferred.width <= available.width, preferred.height <= available.height else { return nil }
        let preferredClamped = clamp(preferred, to: available)
        let flippedClamped = clamp(flipped, to: available)
        let preferredUsable = !overlaps(preferredClamped, anchorRing)
        let flippedUsable = !overlaps(flippedClamped, anchorRing)
        guard preferredUsable || flippedUsable else { return nil }
        let preferredMovement = movement(preferred, preferredClamped)
        let flippedMovement = movement(flipped, flippedClamped)
        let useFlipped = flippedUsable && (!preferredUsable || flippedMovement < preferredMovement)
        return Placement(plate: useFlipped ? flippedClamped : preferredClamped,
                         anchorRing: anchorRing, flipped: useFlipped)
    }

    public struct Placement: Equatable {
        public let plate: CGRect
        public let anchorRing: CGRect
        public let flipped: Bool
    }

    private static func valid(_ rect: CGRect) -> Bool {
        !rect.isNull && !rect.isInfinite && rect.origin.x.isFinite && rect.origin.y.isFinite &&
            rect.width.isFinite && rect.height.isFinite && rect.width > 0 && rect.height > 0 &&
            rect.maxX.isFinite && rect.maxY.isFinite
    }

    private static func clamp(_ rect: CGRect, to frame: CGRect) -> CGRect {
        CGRect(x: min(max(rect.minX, frame.minX), frame.maxX - rect.width),
               y: min(max(rect.minY, frame.minY), frame.maxY - rect.height),
               width: rect.width, height: rect.height)
    }

    private static func movement(_ a: CGRect, _ b: CGRect) -> CGFloat {
        abs(a.minX - b.minX) + abs(a.minY - b.minY)
    }

    private static func overlaps(_ a: CGRect, _ b: CGRect) -> Bool {
        a.minX < b.maxX && b.minX < a.maxX && a.minY < b.maxY && b.minY < a.maxY
    }
}
