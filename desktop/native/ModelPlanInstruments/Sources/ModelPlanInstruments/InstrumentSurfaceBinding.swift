// SPDX-License-Identifier: MIT
import AppKit

public enum InstrumentSurfaceIntent: Equatable, Sendable {
    case requestScope(InstrumentScope), modelSelected(String), favoritesChanged([String])
    case openSubscriptionsSettings, openWebsite(InstrumentWebsiteLink)
    case overviewInformationSelected(String)
}
public enum InstrumentSurfaceRegion: Sendable { case engines, faders, mainScreen }

/// Wiring only. MainScreen's existing controller owns navigation/trial; the host owns effects.
@MainActor public final class InstrumentSurfaceBinding {
    private weak var surface: InstrumentSurfaceView?
    var isPublishing = false
    private var disposed = false
    public var onIntent: ((InstrumentSurfaceIntent) -> Void)?
    public var onHelpChange: ((InstrumentSurfaceRegion, HelpExplanation?, CGRect?) -> Void)?
    public var onHintInput: ((InstrumentSurfaceRegion, InstrumentHintInput) -> Void)?
    private var active: Bool {
        !disposed && !isPublishing && surface?.isPresented == true && surface?.renderError == nil
            && surface?.input != nil && surface?.console.isHidden == false
    }
    init(surface: InstrumentSurfaceView) {
        self.surface = surface
        surface.engineTable.onIntent = { [weak self] in self?.receiveEngine($0) }
        surface.faders.onIntent = { [weak self] in self?.receiveFader($0) }
        surface.mainScreen.onIntents = { [weak self] in self?.receiveMain($0) }
        surface.engineTable.onHelpChange = { [weak self] in self?.help(.engines, $0, $1) }
        surface.faders.onHelpChange = { [weak self] in self?.help(.faders, $0, $1) }
        surface.mainScreen.onHelpChange = { [weak self] in self?.help(.mainScreen, $0, $1) }
        surface.engineTable.onHintInput = { [weak self] in self?.hint(.engines, $0) }
        surface.faders.onHintInput = { [weak self] in self?.hint(.faders, $0) }
        surface.mainScreen.onHintInput = { [weak self] in self?.hint(.mainScreen, $0) }
    }
    public func receiveEngine(_ intent: EngineTableIntent) {
        guard active else { return }
        switch intent {
        case .selectScope(let scope): onIntent?(.requestScope(scope))
        case .openSubscriptionsSettings: onIntent?(.openSubscriptionsSettings)
        case .changePage: break // Existing EngineTableView already owns its page.
        }
    }
    public func receiveFader(_ intent: FaderIntent) {
        guard active, let surface else { return }
        if case .favoritesChanged(let ids) = intent { onIntent?(.favoritesChanged(ids)) }
        surface.mainScreen.receiveFaderIntent(intent)
    }
    public func receiveMain(_ intents: [MainScreenIntent]) {
        guard active, let surface else { return }
        for intent in intents {
            guard active else { return }
            do {
                switch intent {
                case .trialChanged(let trial): try surface.faders.setTrial(trial)
                case .sourceHighlightChanged: try surface.faders.setSourceHighlight(surface.mainScreen.controller.sourceModelID)
                case .modelSelected(let id): onIntent?(.modelSelected(id))
                case .subscriptionScopeSelected(let id): onIntent?(.requestScope(.subscription(id)))
                case .openWebsite(let link):
                    if surface.mainScreen.presentation?.websiteLinks.contains(link) == true { onIntent?(.openWebsite(link)) }
                case .overviewInformationSelected(let id): onIntent?(.overviewInformationSelected(id))
                case .locationChanged, .pageSelected, .optionSelected: break
                }
            } catch { surface.invalidate(error); return }
        }
    }
    private func help(_ region: InstrumentSurfaceRegion, _ explanation: HelpExplanation?, _ rect: CGRect?) {
        guard !disposed, !isPublishing else { return }
        // Cancellation must reach the one upper Help owner even while presentation is being suspended.
        if explanation == nil || active { onHelpChange?(region, explanation, rect) }
    }
    private func hint(_ region: InstrumentSurfaceRegion, _ input: InstrumentHintInput) {
        guard !disposed, !isPublishing else { return }
        onHintInput?(region, input)
    }
    public func dispose() { disposed = true; onIntent = nil; onHelpChange = nil; onHintInput = nil; surface = nil }
}
