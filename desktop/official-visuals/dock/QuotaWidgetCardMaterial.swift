// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
// Copyright (c) 2026 ModelPlan. All rights reserved.
import CoreGraphics

/// The accepted r7 card material (G3-05 / G3-31, R64 D-3): flat plate, dark readout window and
/// LCD ink. Values only; drawing stays in the neutral card. The card stays dark on every wallpaper.
/// Prototype: clients/official-visuals/dock-aftview-integration/face.css:47-82 (#card.c7 tokens),
/// design-handoffs/opus-r7/src/rocket-r1/theme.css:15,25 (status and LCD tokens).
public enum QuotaWidgetCardMaterial {
    /// sRGB components 0...1.
    public struct RGBA: Equatable, Sendable {
        public let red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat
        init(_ hex: UInt32, alpha: UInt8 = 0xff) {
            red = CGFloat((hex >> 16) & 0xff) / 255; green = CGFloat((hex >> 8) & 0xff) / 255
            blue = CGFloat(hex & 0xff) / 255; self.alpha = CGFloat(alpha) / 255
        }
    }
    public static let plate = RGBA(0x101b24)
    public static let seam = RGBA(0x000000, alpha: 0xbb)
    public static let window = RGBA(0x03060a)
    public static let windowSeam = RGBA(0x000000, alpha: 0xbb)
    public static let ink = RGBA(0xe9edf0)
    public static let muted = RGBA(0x87939e)
    public static let ghost = RGBA(0xffffff, alpha: 0x0c)
    /// The selected window's row (face.css .selected-window #ffffff08).
    public static let rowHighlight = RGBA(0xffffff, alpha: 0x08)
    public static let normal = RGBA(0x5ad9ba)
    public static let warning = RGBA(0xeac17b)
    public static let critical = RGBA(0xef4444)
    /// Announced/confirmed public reset ink (dock.css --dk-notice, card.js cd-ev).
    public static let notice = RGBA(0x9fd2ff)
    /// Header name / small text / percent value sizes; the readout font is the dock's LCD face.
    public static let nameFontSize: CGFloat = 13, smallFontSize: CGFloat = 11, valueFontSize: CGFloat = 11.5
    public static let readoutFontResource = "font-jetbrains-mono"
    /// The selected ring's glow while its card is open (dock.css:68 drop-shadow 0 0 7px #ffffff2e).
    public static let hotGlow = RGBA(0xffffff, alpha: 0x2e)
    public static let hotGlowBlur: CGFloat = 7
}

