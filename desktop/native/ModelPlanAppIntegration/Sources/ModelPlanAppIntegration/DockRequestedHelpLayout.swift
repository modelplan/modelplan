// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanInstruments

/// A rectangle is supplied by a visible live control, never inferred from an absent surface.
struct DockRequestedHelpAnchor: Equatable {
    let id: String
    let region: HelpMapRegion
    let rect: CGRect
    let visible: Bool
    var caption: String? = nil
}

@MainActor enum DockRequestedHelpLayout {
    static func make(session: UUID, viewport: CGSize, language: InstrumentLanguage,
                     anchors: [DockRequestedHelpAnchor], blocked: [CGRect], avoid: [CGRect] = [],
                     recipe: any HelpUIRecipeProvider, refreshAvailable: Bool = false) -> HelpUIRenderInput? {
        var selectedRegions = Set<HelpMapRegion>()
        // Leaders run no higher than y = 28, below the menu bar, and end 4 pt beyond an anchor's edge.
        // The menu-bar item lies above that, so it is reached from just under the bar.
        let reachable = anchors.map { anchor in
            anchor.rect.maxY >= 24 || anchor.rect.isEmpty ? anchor : DockRequestedHelpAnchor(id: anchor.id, region: anchor.region,
                rect: CGRect(x: anchor.rect.minX, y: anchor.rect.minY, width: anchor.rect.width, height: 24 - anchor.rect.minY),
                visible: anchor.visible, caption: anchor.caption)
        }
        let visible = reachable.filter { anchor in
            guard anchor.visible else { return false }
            return anchor.caption != nil || selectedRegions.insert(anchor.region).inserted
        }.sorted {
            $0.rect.midY == $1.rect.midY ? $0.id < $1.id : $0.rect.midY < $1.rect.midY
        }
        guard !visible.isEmpty, visible.count <= 24,
              Set(visible.map(\.id)).count == visible.count,
              viewport.width.isFinite, viewport.height.isFinite, viewport.width > 80, viewport.height > 80 else { return nil }
        let bounds = CGRect(origin: .zero, size: viewport)
        guard visible.allSatisfy({ !$0.id.isEmpty && !$0.rect.isEmpty && bounds.intersects($0.rect) }) else { return nil }
        let catalog = HelpMapCatalog(language)
        let catalogEntries = Dictionary(uniqueKeysWithValues: catalog.entries(for: .dock).map { ($0.region, $0) })
        var map = HelpUIMapInput(mode: .latched, surface: .dock)
        // `avoid` (the widget itself) only steers placement. Leaders must still reach targets inside it,
        // so it is not a reading the layer routes around.
        var obstacles = blocked + avoid + visible.map(\.rect)
        var frames: [String: CGRect] = [:]
        var columnBottom = -CGFloat.infinity
        enum ColumnSide { case left, right }
        var columnSide: ColumnSide?
        var column: [String] = []
        for anchor in visible {
            guard let entry = catalogEntries[anchor.region] else { return nil }
            let fallback = language == .chinese ? "喷口：悬停查看卡片，拖动可排序，⌥ 加方向键移动一位。" : "Nozzle: hover for its card, drag to reorder or use Option arrows to move one place."
            let caption = anchor.caption ?? (anchor.region == .nozzle && !refreshAvailable ? fallback : nil)
            let text = caption ?? entry.sentence
            let labelID: String
            if caption == nil && map.regionAnchors[anchor.region] == nil {
                map.regionAnchors[anchor.region] = anchor.id; labelID = entry.id
            } else {
                guard map.supplements.count < 16 else { return nil }
                labelID = "extra." + anchor.id
                map.supplements.append(.init(id: labelID, anchorID: anchor.id, text: text))
            }
            let maxWidth = min(320, viewport.width - 32)
            let measured = recipe.measure(text, width: maxWidth - 16, role: .caption)
            let width = min(maxWidth, max(80, ceil(measured.width) + 16))
            let height = ceil(recipe.measure(text, width: width - 16, role: .caption).height) + 10
            let size = CGSize(width: width, height: height)
            // A target on the widget gets its caption in one column beside the panel, as high as the target
            // allows and never over the previous caption. Targets and captions then run in the same order,
            // so the straight leaders between them cannot cross.
            // The column side is chosen once per panel; a side too narrow for the full width narrows the
            // caption (not below 120 pt), and only then falls back to the other side.
            var beside: CGRect?
            if let panel = avoid.first(where: { $0.insetBy(dx: -4, dy: -4).intersects(anchor.rect) }) {
                let rightRoom = viewport.width - 8 - (panel.maxX + 10), leftRoom = panel.minX - 10 - 8
                let preferRight = columnSide.map { $0 == .right } ?? (panel.midX < viewport.width / 2 ? rightRoom >= 120 || rightRoom >= leftRoom : !(leftRoom >= 120 || leftRoom >= rightRoom))
                for side in (preferRight ? [ColumnSide.right, .left] : [.left, .right]) where columnSide == nil || columnSide == side {
                    let room = side == .right ? rightRoom : leftRoom
                    let w = min(width, room)
                    guard w >= min(width, 120) else { continue }
                    let h = w == width ? height : ceil(recipe.measure(text, width: w - 16, role: .caption).height) + 10
                    let x = side == .right ? panel.maxX + 10 : panel.minX - 10 - w
                    let y = max(anchor.rect.midY - h / 2, columnBottom + 4, 32)
                    let candidate = CGRect(x: x, y: y, width: w, height: h)
                    if !blocked.contains(where: { $0.intersects(candidate) }) {
                        beside = candidate; columnBottom = candidate.maxY; columnSide = side
                        column.append(labelID); break
                    }
                }
            }
            // Never hide the map for want of a clean spot: widen the search, then clamp inside the screen.
            let frame = beside
                ?? HelpUIGeometry.placeCard(anchor: anchor.rect, size: size, viewport: viewport, blocked: obstacles)
                ?? HelpUIGeometry.placeCard(anchor: anchor.rect, size: size, viewport: viewport, blocked: blocked + visible.map(\.rect))
                ?? CGRect(x: min(max(8, anchor.rect.maxX + 10), max(8, viewport.width - 8 - width)),
                          y: min(max(32, anchor.rect.midY - height / 2), max(32, viewport.height - 8 - height)),
                          width: width, height: height)
            frames[labelID] = frame; obstacles.append(frame)
        }
        // A column that runs off the bottom of a short screen moves up as one, keeping order and spacing.
        if let last = column.last, let first = column.first, let lastFrame = frames[last], let firstFrame = frames[first],
           lastFrame.maxY > viewport.height - 8 {
            let shift = min(lastFrame.maxY - (viewport.height - 8), max(0, firstFrame.minY - 32))
            for id in column { if let f = frames[id] { frames[id] = f.offsetBy(dx: 0, dy: -shift) } }
        }
        // The header goes last, so that no caption has to route a leader around it.
        let headerWidth = min(400, viewport.width - 32)
        let headerText = catalog.metaphor + "\n" + catalog.dismissal
        let headerHeight = ceil(recipe.measure(headerText, width: headerWidth - 16, role: .header).height) + 10
        let headerSize = CGSize(width: headerWidth, height: headerHeight)
        let header = HelpUIGeometry.placeCard(anchor: visible[0].rect, size: headerSize, viewport: viewport, blocked: obstacles)
            ?? HelpUIGeometry.placeCard(anchor: visible[0].rect, size: headerSize, viewport: viewport, blocked: blocked + visible.map(\.rect))
            ?? CGRect(x: (viewport.width - headerWidth) / 2, y: max(8, viewport.height - 8 - headerHeight), width: headerWidth, height: headerHeight)
        map.header = header
        map.captionFrames = frames
        map.straightLeaders = true
        return HelpUIRenderInput(sessionID: session, viewport: viewport, profile: .compact640, language: language,
                                 anchors: visible.map { .init(id: $0.id, rect: $0.rect) }, liveReadings: blocked, map: map)
    }
}
