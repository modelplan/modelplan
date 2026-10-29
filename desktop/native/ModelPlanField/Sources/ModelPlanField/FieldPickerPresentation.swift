// SPDX-License-Identifier: MIT
import Foundation

public struct FieldPickerTagDisplay: Equatable, Sendable {
    public let kind: FieldPickerTag, label: String
}
public struct FieldPickerRow: Equatable, Sendable {
    public let publicID: String, name: String, developerID: String?, developerName: String
    public let recommendedEffort: String?
    public let tags: [FieldPickerTagDisplay]
    public let launched: Bool, focused: Bool, launchEnabled: Bool, focusEnabled: Bool
}
/// Text and interaction metadata only. Native/private hosts retain ownership of the approved A surface.
public struct FieldPickerPresentation: Equatable, Sendable {
    public let rows: [FieldPickerRow]
    public let selectedIDs: [String], effectiveFocusID: String?
    public let expanded: Bool, atCapacity: Bool
    public let title: String, resetTitle: String, searchTitle: String, emptyTitle: String, capacityTitle: String
    public let presets: [String]
    public init(catalogue: FieldPickerCatalogue, state: FieldFleetPicker, locale: FieldLocale) {
        let english = locale == .english
        let ids = state.selectedIDs(in: catalogue), focus = state.effectiveFocus(in: catalogue)
        let full = ids.count >= FieldFleetPicker.capacity
        selectedIDs = ids; effectiveFocusID = focus
        expanded = state.expanded; atCapacity = full
        title = english ? "Pick models" : "选模型"
        resetTitle = english ? "Reset to My subscriptions" : "重置为我的订阅"
        searchTitle = english ? "Search models" : "搜索模型"
        emptyTitle = english ? "No matching models" : "没有匹配的模型"
        capacityTitle = english ? "10 rocket limit · retract one to add another" : "最多 10 台 · 先撤回一台再加入"
        presets = english ? ["My subscriptions", "Site picks", "All"] : ["我的订阅", "网站推荐", "全部"]
        let models = Dictionary(uniqueKeysWithValues: catalogue.projection.models.map { ($0.id, $0) })
        let selected = Set(ids), query = state.query.lowercased()
        func label(_ tag: FieldPickerTag) -> String {
            switch tag {
            case .strongest: return english ? "Strongest" : "最强"
            case .bestValue: return english ? "Best value" : "最划算"
            case .cheapest: return english ? "Cheapest" : "最省"
            case .outclassed: return english ? "Outclassed" : "被比下去"
            case .pricierTwin: return english ? "Pricier twin" : "有更省"
            }
        }
        rows = catalogue.rosterModelIDs.compactMap { id in
            guard let model = models[id], state.maker.map({ $0.isEmpty || $0 == model.developerId }) ?? true else { return nil }
            let name = model.name ?? id, developer = model.developerId.flatMap { catalogue.developerNames[$0] } ?? model.developerId ?? ""
            guard query.isEmpty || (name + " " + developer).lowercased().contains(query) else { return nil }
            let on = selected.contains(id)
            let effort = model.recommended.flatMap { key in model.efforts.first { $0.effort == key } }.map { $0.label ?? $0.effort }
            return FieldPickerRow(publicID: id, name: name, developerID: model.developerId, developerName: developer,
                recommendedEffort: effort, tags: (catalogue.tags[id] ?? []).map { .init(kind: $0, label: label($0)) },
                launched: on, focused: on && focus == id, launchEnabled: on || !full, focusEnabled: on || !full)
        }
    }
}
