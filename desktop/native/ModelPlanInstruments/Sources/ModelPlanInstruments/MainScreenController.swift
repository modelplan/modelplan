// SPDX-License-Identifier: MIT
import Foundation

public struct MainScreenOptionChoice: Equatable, Sendable {
    public let value: String, title: String
    public let enabled: Bool
    public init(_ value: String, title: String, enabled: Bool = true) { self.value = value; self.title = title; self.enabled = enabled }
}
public struct MainScreenFooterOption: Equatable, Sendable {
    public let id: String
    public let choices: [MainScreenOptionChoice]
    public let selectedValue: String?
    public let help: HelpExplanation
    public init(id: String, choices: [MainScreenOptionChoice], selectedValue: String?, help: HelpExplanation) {
        self.id = id; self.choices = choices; self.selectedValue = selectedValue; self.help = help
    }
    var valid: Bool {
        !id.isEmpty && id.utf8.count <= 256 && (1...8).contains(choices.count)
            && Set(choices.map(\.value)).count == choices.count
            && choices.allSatisfy { !$0.value.isEmpty && $0.value.utf8.count <= 256 && !$0.title.isEmpty && $0.title.utf8.count <= 4096 }
            && (selectedValue.map { selected in choices.contains { $0.value == selected } } ?? true)
    }
}
/// Page bodies are supplied by their owning later batches; this frame owns navigation.
public struct MainScreenPageContent: Equatable, Sendable {
    public let page: MainScreenPage
    public let lines: [String]
    public let options: [MainScreenFooterOption?]
    public let overview: OverviewPageSnapshot?
    public init(_ page: MainScreenPage, lines: [String] = [], options: [MainScreenFooterOption?] = [], overview: OverviewPageSnapshot? = nil) {
        self.page = page; self.lines = lines; self.options = options; self.overview = overview
    }
}
public struct MainScreenSourcedBody: Equatable, Sendable {
    public let content: MainScreenContent
    public let titleVariants: [String]
    public let lines: [String]
    public init(_ content: MainScreenContent, titleVariants: [String], lines: [String]) {
        self.content = content; self.titleVariants = titleVariants; self.lines = lines
    }
}
public enum MainScreenIntent: Equatable, Sendable {
    case overviewInformationSelected(String)
    case trialChanged(FaderTrial?)
    case sourceHighlightChanged(MainScreenSource?)
    case modelSelected(String)
    case pageSelected(MainScreenPage)
    case optionSelected(page: MainScreenPage, id: String, value: String)
}
public enum MainScreenError: Error { case invalidContent }
/// One wrapper around the existing navigation and comparison values, never a selector/solver.
public struct MainScreenController: Sendable {
    public private(set) var navigation: MainScreenNavigation
    public private(set) var inputs: [FaderChannelInput] = []
    public private(set) var selection: InjectedModelSelection?
    public private(set) var publication: SelectionPublication?
    public private(set) var publicationUsable = false
    public private(set) var pages: [MainScreenPageContent] = []
    public private(set) var sourcedBodies: [MainScreenSourcedBody] = []
    private var optionOverrides: [MainScreenPage: [String: String]] = [:]
    public init(location: MainScreenLocation = .init(.overview), scope: InstrumentScope = .all) {
        navigation = .init(location: location, scope: scope)
    }
    public var trial: FaderTrial? {
        guard let content = navigation.sourced?.content, case .comparison(let id, let config) = content else { return nil }
        return .init(modelID: id, configuration: config)
    }
    public var sourceModelID: String? {
        switch navigation.sourced?.source {
        case .fader(let id), .fast(let id): return id
        default: return nil
        }
    }
    public func input(_ id: String) -> FaderChannelInput? {
        guard publicationUsable, let selection, selection.matchesExact(publication, scope: navigation.scope),
              selection.orderedModelIDs.contains(id) else { return nil }
        let matches = inputs.filter { $0.model.id == id }
        return matches.count == 1 ? matches[0] : nil
    }
    private func valid(_ config: EffortConfiguration, model: InstrumentModel) -> Bool {
        model.effort(config.effort) != nil && (!config.fast || model.fastTier?.usable == true)
    }
    @discardableResult public mutating func update(inputs: [FaderChannelInput], selection: InjectedModelSelection?,
            publication: SelectionPublication?, publicationUsable: Bool, scope: InstrumentScope? = nil,
            pages: [MainScreenPageContent] = [], sourcedBodies: [MainScreenSourcedBody] = []) throws -> [MainScreenIntent] {
        guard pages.count <= 4, Set(pages.map(\.page)).count == pages.count,
              pages.allSatisfy({ page in
                  let options = page.options.compactMap { $0 }
                  return page.options.count <= 3 && options.allSatisfy(\.valid)
                      && Set(options.map(\.id)).count == options.count && page.lines.count <= 128
                      && page.lines.allSatisfy { $0.utf8.count <= 4096 }
                      && (page.overview.map { page.page == .overview && $0.valid && $0.scope == (scope ?? navigation.scope) } ?? true)
              }), sourcedBodies.count <= 128,
              sourcedBodies.enumerated().allSatisfy({ index, body in sourcedBodies.firstIndex(where: { $0.content == body.content }) == index }),
              sourcedBodies.allSatisfy({ $0.lines.count <= 128 && (1...8).contains($0.titleVariants.count)
                  && ($0.lines + $0.titleVariants).allSatisfy { $0.utf8.count <= 4096 } }) else { throw MainScreenError.invalidContent }
        let before = self
        for page in pages {
            for option in page.options.compactMap({ $0 }) {
                let previous = self.pages.first { $0.page == page.page }?.options.compactMap { $0 }.first { $0.id == option.id }
                if previous?.selectedValue != option.selectedValue { optionOverrides[page.page]?[option.id] = nil }
                if let override = optionOverrides[page.page]?[option.id], !option.choices.contains(where: { $0.value == override && $0.enabled }) {
                    optionOverrides[page.page]?[option.id] = nil
                }
            }
        }
        self.inputs = inputs; self.selection = selection; self.publication = publication
        self.publicationUsable = publicationUsable; self.pages = pages; self.sourcedBodies = sourcedBodies
        if let scope, scope != navigation.scope { navigation.selectScope(scope) }
        navigation.reconcile(selection: selection, publication: publication)
        if let trial, input(trial.modelID).map({ valid(trial.configuration, model: $0.model) }) != true { navigation.back() }
        return changes(from: before)
    }
    private func changes(from before: Self) -> [MainScreenIntent] {
        var result: [MainScreenIntent] = []
        if before.trial != trial { result.append(.trialChanged(trial)) }
        if before.navigation.sourced?.source != navigation.sourced?.source { result.append(.sourceHighlightChanged(navigation.sourced?.source)) }
        if before.navigation.selectedModelID != navigation.selectedModelID, let id = navigation.selectedModelID { result.append(.modelSelected(id)) }
        return result
    }
    @discardableResult public mutating func openComparison(modelID: String, configuration: EffortConfiguration? = nil,
            from source: MainScreenSource, toggle: Bool = true) -> [MainScreenIntent] {
        let before = self
        if toggle, navigation.sourced?.source == source { navigation.back(); return changes(from: before) }
        guard let model = input(modelID)?.model else { return [] }
        let chosen = configuration
            ?? model.current.flatMap { valid($0, model: model) ? $0 : nil }
            ?? model.recommended.flatMap { key in model.effort(key).map { _ in EffortConfiguration(key) } }
        guard let chosen, valid(chosen, model: model), let selection, let publication else { return [] }
        navigation.selectModel(modelID, selection: selection, publication: publication)
        navigation.activate(.comparison(modelID: modelID, trial: chosen), from: source, toggle: false)
        return changes(from: before)
    }
    @discardableResult public mutating func tryEffort(_ key: String) -> [MainScreenIntent] {
        guard let trial, let model = input(trial.modelID)?.model else { return [] }
        let next = EffortConfiguration(key, fast: trial.configuration.fast)
        guard valid(next, model: model) else { return [] }
        let before = self; navigation.updateTrial(next, modelID: trial.modelID); return changes(from: before)
    }
    @discardableResult public mutating func toggleFast() -> [MainScreenIntent] {
        guard let trial, let model = input(trial.modelID)?.model, model.fastTier?.usable == true else { return [] }
        let before = self
        navigation.updateTrial(.init(trial.configuration.effort, fast: !trial.configuration.fast), modelID: trial.modelID)
        return changes(from: before)
    }
    @discardableResult public mutating func open(_ content: MainScreenContent, from source: MainScreenSource) -> [MainScreenIntent] {
        if case .comparison(let id, let trial) = content { return openComparison(modelID: id, configuration: trial, from: source) }
        let before = self; navigation.activate(content, from: source); return changes(from: before)
    }
    @discardableResult public mutating func back() -> [MainScreenIntent] {
        let before = self; navigation.back(); return changes(from: before)
    }
    @discardableResult public mutating func selectPage(_ location: MainScreenLocation) -> [MainScreenIntent] {
        let before = self; navigation.selectPage(location); return changes(from: before) + [.pageSelected(location.page)]
    }
    @discardableResult public mutating func pressPageKey(_ page: MainScreenPage) -> [MainScreenIntent] {
        let base = navigation.sourced?.returnTo ?? navigation.location
        return selectPage(.init(page, destinationsMode: base.destinationsMode, timelineRange: base.timelineRange, projectPeriod: base.projectPeriod))
    }
    @discardableResult public mutating func selectScope(_ scope: InstrumentScope) -> [MainScreenIntent] {
        let before = self; navigation.selectScope(scope)
        pages = []; sourcedBodies = []
        return changes(from: before)
    }
    @discardableResult public mutating func selectModel(_ id: String) -> [MainScreenIntent] {
        guard let selection, let publication else { return [] }
        let before = self; navigation.selectModel(id, selection: selection, publication: publication); return changes(from: before)
    }
    public func option(_ option: MainScreenFooterOption, page: MainScreenPage) -> MainScreenFooterOption {
        .init(id: option.id, choices: option.choices, selectedValue: optionOverrides[page]?[option.id] ?? option.selectedValue, help: option.help)
    }
    @discardableResult public mutating func chooseOption(id: String, value: String? = nil) -> [MainScreenIntent] {
        if let content = navigation.sourced?.content {
            if case .page = content {} else { return [] }
        }
        guard trial == nil, let original = pages.first(where: { $0.page == navigation.location.page })?.options.compactMap({ $0 }).first(where: { $0.id == id }) else { return [] }
        let page = navigation.location.page, option = option(original, page: page), choices = option.choices.filter(\.enabled)
        guard !choices.isEmpty else { return [] }
        let chosen: String
        if let value {
            guard choices.contains(where: { $0.value == value }) else { return [] }; chosen = value
        } else {
            let index = choices.firstIndex { $0.value == option.selectedValue }.map { ($0 + 1) % choices.count } ?? 0
            chosen = choices[index].value
        }
        guard chosen != option.selectedValue else { return [] }
        optionOverrides[page, default: [:]][id] = chosen
        return [.optionSelected(page: page, id: id, value: chosen)]
    }
    @discardableResult public mutating func receiveFaderIntent(_ intent: FaderIntent) -> [MainScreenIntent] {
        switch intent {
        case .inspectModel(let id): return openComparison(modelID: id, from: .fader(id))
        case .trialChanged(let requested):
            guard let requested else { return trial == nil ? [] : back() }
            guard let model = input(requested.modelID)?.model, valid(requested.configuration, model: model) else { return [] }
            if trial?.modelID == requested.modelID {
                let before = self; navigation.updateTrial(requested.configuration, modelID: requested.modelID); return changes(from: before)
            }
            return openComparison(modelID: requested.modelID, configuration: requested.configuration, from: .fader(requested.modelID), toggle: false)
        case .selectModel(let id):
            return id == navigation.selectedModelID ? [] : selectModel(id)
        case .closeSourcedView: return back()
        case .bankChanged, .favoritesChanged: return []
        }
    }
}
