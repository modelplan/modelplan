// SPDX-License-Identifier: MIT
import AppKit

/// D371 B4e: the glyph on the Dock cards' "在驾驶舱查看" footer row. The coordinator recommended the menu-bar icon (the
/// rocket the status item shows), so the card and the menu bar read as the same door. This is the ONE place that
/// names the asset: swapping the glyph later is a change to `image` and nothing else.
@MainActor enum CockpitEntryGlyph {
    static var image: NSImage? { CommunityMenuBarResources.statusImage() }
}
