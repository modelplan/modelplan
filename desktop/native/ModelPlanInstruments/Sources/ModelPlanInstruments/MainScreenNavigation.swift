// SPDX-License-Identifier: MIT
import Foundation

public enum DestinationsMode: Equatable, Sendable { case projects, timeline }
public struct MainScreenLocation: Equatable, Sendable {
    public let page: MainScreenPage
    public let destinationsMode: DestinationsMode
    public let timelineRange: TimelineRange
    public let projectPeriod: ProjectRankingPeriod
    public init(_ page: MainScreenPage, destinationsMode: DestinationsMode = .projects, timelineRange: TimelineRange = .today,
                projectPeriod: ProjectRankingPeriod = .days7) {
        self.page = page; self.destinationsMode = destinationsMode; self.timelineRange = timelineRange
        self.projectPeriod = projectPeriod
    }
}
public enum MainScreenSource: Equatable, Sendable {
    case hud, fader(String), fast(String), record(String), recordOverflow, alertLamp, noticeOverflow
}
public enum MainScreenContent: Equatable, Sendable {
    case page(MainScreenLocation), comparison(modelID: String, trial: EffortConfiguration), session(String), alerts
}
public struct SourcedScreenContent: Equatable, Sendable {
    public let source: MainScreenSource
    public let content: MainScreenContent
    public let returnTo: MainScreenLocation
}

/// Local presentation intents only: no transport/model-setting writes and only one sourced view/trial.
public struct MainScreenNavigation: Sendable {
    public private(set) var location: MainScreenLocation
    public private(set) var scope: InstrumentScope
    public private(set) var sourced: SourcedScreenContent?
    public private(set) var selectedModelID: String?
    public private(set) var selectionPublication: SelectionPublication?
    public init(location: MainScreenLocation = .init(.overview), scope: InstrumentScope = .all) {
        self.location = location; self.scope = scope
    }
    public var highlightedPage: MainScreenPage? {
        if let content = sourced?.content, case .comparison = content { return nil }
        return location.page
    }
    public var trial: EffortConfiguration? {
        if let content = sourced?.content, case .comparison(_, let trial) = content { return trial }
        return nil
    }
    public mutating func activate(_ content: MainScreenContent, from source: MainScreenSource) {
        if sourced?.source == source { back(); return }
        let returnTo = sourced?.returnTo ?? location
        sourced = SourcedScreenContent(source: source, content: content, returnTo: returnTo)
        if case .page(let target) = content { location = target }
    }
    /// Drag/key changes update the same local comparison rather than toggling its source off.
    public mutating func updateTrial(_ trial: EffortConfiguration, modelID: String) {
        guard let current = sourced, case .comparison(let id, _) = current.content, id == modelID else { return }
        sourced = SourcedScreenContent(source: current.source, content: .comparison(modelID: modelID, trial: trial), returnTo: current.returnTo)
    }
    public mutating func back() {
        if let sourced { location = sourced.returnTo }
        sourced = nil
    }
    public mutating func selectPage(_ location: MainScreenLocation) { sourced = nil; self.location = location }
    public mutating func selectScope(_ scope: InstrumentScope) {
        back(); self.scope = scope; selectedModelID = nil; selectionPublication = nil
    }
    public mutating func selectModel(_ id: String, selection: InjectedModelSelection, publication: SelectionPublication) {
        guard selection.matches(publication, scope: scope), selection.orderedModelIDs.contains(id) else { return }
        back(); selectedModelID = id; selectionPublication = publication
    }
    public mutating func reconcile(selection: InjectedModelSelection?, publication: SelectionPublication?) {
        guard let selection, selection.matches(publication, scope: scope) else {
            discardPublicationDependentView(); selectedModelID = nil; selectionPublication = nil; return
        }
        if selectionPublication != publication { discardPublicationDependentView() }
        if let content = sourced?.content, case .comparison(let id, _) = content, !selection.orderedModelIDs.contains(id) { back() }
        selectionPublication = publication
        if let selectedModelID, selection.orderedModelIDs.contains(selectedModelID) { return }
        selectedModelID = selection.selectedModelID.flatMap { selection.orderedModelIDs.contains($0) ? $0 : nil }
    }
    private mutating func discardPublicationDependentView() {
        guard let content = sourced?.content else { return }
        switch content {
        case .comparison: back()
        case .page(let target) where target.page == .effort: back()
        case .page, .session, .alerts: break
        }
    }
    public mutating func close() { back() }
}
