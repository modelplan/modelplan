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
            var beside: CGRect?
            if let panel = avoid.first(where: { $0.insetBy(dx: -4, dy: -4).intersects(anchor.rect) }) {
                let x = panel.midX < viewport.width / 2 ? panel.maxX + 10 : panel.minX - 10 - width
                let y = max(anchor.rect.midY - height / 2, columnBottom + 4, 32)
                let candidate = CGRect(x: x, y: y, width: width, height: height)
                if candidate.minX >= 8, candidate.maxX <= viewport.width - 8, candidate.maxY <= viewport.height - 8,
                   !blocked.contains(where: { $0.intersects(candidate) }) {
                    beside = candidate; columnBottom = candidate.maxY
                }
            }
            guard let frame = beside ?? HelpUIGeometry.placeCard(anchor: anchor.rect, size: size,
                                                                 viewport: viewport, blocked: obstacles) else { return nil }
            frames[labelID] = frame; obstacles.append(frame)
        }
        // The header goes last, so that no caption has to route a leader around it.
        let headerWidth = min(400, viewport.width - 32)
        let headerText = catalog.metaphor + "\n" + catalog.dismissal
        let headerHeight = ceil(recipe.measure(headerText, width: headerWidth - 16, role: .header).height) + 10
        guard let header = HelpUIGeometry.placeCard(anchor: visible[0].rect,
                size: CGSize(width: headerWidth, height: headerHeight), viewport: viewport, blocked: obstacles) else { return nil }
        map.header = header
        map.captionFrames = frames
        map.straightLeaders = true
        return HelpUIRenderInput(sessionID: session, viewport: viewport, profile: .compact640, language: language,
                                 anchors: visible.map { .init(id: $0.id, rect: $0.rect) }, liveReadings: blocked, map: map)
    }
}
