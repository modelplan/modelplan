// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanInstruments
import ModelPlanSettings

/// One existing composition, attached above one actual MainScreen. No dwell/admission policy.
@MainActor final class CommunityContextHelpBinding {
    private(set) weak var composition: InstrumentHelpComposition?
    private weak var source: MainScreenView?, container: NSView?
    private let active: () -> Bool
    private let language: () -> InstrumentLanguage
    private let accessibility: () -> (Bool, Bool)
    private var explanation: HelpExplanation?, sourceRect: CGRect?
    private var contextID = UUID().uuidString
    private let session = UUID()
    private var retired = false, optionHeld = false, optionDismissed = false
    private let publicationSource: () -> InstrumentPublicationSource
    private let openWebsite: (InstrumentWebsiteLink) -> Void
    private var sourceActions: [String:InstrumentWebsiteLink] = [:]
    private var actionGeneration: UInt64 = 0
    init(composition: InstrumentHelpComposition, source: MainScreenView, container: NSView,
         active: @escaping () -> Bool, language: @escaping () -> InstrumentLanguage,
         accessibility: @escaping () -> (Bool, Bool),
         publicationSource: @escaping () -> InstrumentPublicationSource,
         openWebsite: @escaping (InstrumentWebsiteLink) -> Void) {
        self.composition = composition; self.source = source; self.container = container
        self.active = active; self.language = language; self.accessibility = accessibility
        self.publicationSource = publicationSource;self.openWebsite = openWebsite
    }
    func install() {
        guard !retired, let source, let container, let composition else { return }
        container.addSubview(composition.layer)
        source.onHelpChange = { [weak self] explanation, rect in
            guard let self, !self.retired else { return }
            self.explanation = self.optionHeld ? nil:explanation; self.sourceRect = self.optionHeld ? nil:rect; self.contextID = UUID().uuidString
            self.refresh()
        }
        refresh()
    }
    private func installActions() {
        guard let composition else { return };actionGeneration &+= 1;let token=actionGeneration
        composition.onHelpAction = { [weak self] action in
            guard let self, !self.retired, self.active(),self.actionGeneration==token else { return }
            switch action {
            case .dismissContext(let id, _) where id == self.contextID: self.source?.leaveHelp()
            case .dismissMap: self.optionDismissed=true;self.optionHeld=false;self.refresh()
            case .mapSourceAction(let id):
                guard self.optionHeld,let composition=self.composition,
                      ((composition.layer.input?.map.sourceActionID==id && composition.layer.presentation?.mapSourceFrame != nil)
                       || (composition.layer.input?.map.secondarySourceActionID==id && composition.layer.presentation?.secondaryMapSourceFrame != nil)),
                      let link=self.sourceActions[id] else { return }
                self.openWebsite(link)
            default: break
            }
        }
    }
    func setOptionHeld(_ held: Bool) {
        guard !retired,active() else { return }
        if !held { optionDismissed=false }
        guard !optionDismissed,optionHeld != held else { return }
        optionHeld=held;explanation=nil;sourceRect=nil;contextID=UUID().uuidString
        refresh()
    }
    func refresh() {
        guard !retired, let source, let container, let composition else { return }
        guard active(), !source.isHiddenOrHasHiddenAncestor, let recipe = source.recipe else { suspend(); return }
        let layer = composition.layer
        layer.frame.origin = .zero
        var readings = recipe.regions.map { source.convert($0.rect, to: layer) }
        readings += textAndImages(recipe.commands).map { source.convert($0, to: layer) }
        if let plot = recipe.chart?.plot { readings.append(source.convert(plot, to: layer)) }
        // The picker is a sibling above MainScreen and must not be covered by a card.
        readings.append(.init(x: 0, y: 0, width: container.bounds.width, height: source.frame.minY))
        let rect = sourceRect.flatMap { r in recipe.regions.contains(where: { $0.rect == r && $0.help == explanation }) ? source.convert(r, to: layer) : nil }
        let card: HelpUIContextCard?
        if let explanation, rect != nil { card = .init(id: contextID, anchorID: "community.main-screen", explanation: explanation) }
        else { card = nil }
        var input = HelpUIRenderInput(sessionID: session, viewport: container.bounds.size, profile: .compact640,
            language: language(), anchors: rect.map { [.init(id: "community.main-screen", rect: $0)] } ?? [],
            liveReadings: readings, contextual: card)
        let (motion, transparency) = accessibility()
        input.reduceMotion = motion; input.reduceTransparency = transparency
        sourceActions=[:]
        if optionHeld,let anchor=recipe.regions.first {
            let published=publicationSource(),epoch=UUID().uuidString
            let about=epoch+".about",data=epoch+".data"
            let sourceTitle=(published.age=="--" ? (language() == .chinese ? "发布时间未知":"Publication age unknown"):published.age)+" · "+published.links[0].title
            sourceActions=[about:published.links[0],data:published.links[1]]
            input.anchors=[.init(id:"community.main-screen",rect:source.convert(anchor.rect,to:layer))]
            input.contextual=nil
            input.map=CommunityOptionHelpLayout.map(viewport:input.viewport,readings:readings,
                sourceTitle:sourceTitle,dataTitle:published.links[1].title,about:about,data:data)
        }
        guard active(),!retired else { return }
        // A generic public catalogue window is not evidence of a cockpit open or Dock reveal.
        // This binding supplies contextual Help only; no first-use copy, trial lease or offer.
        installActions()
        do { try composition.update(input, content: [:], context: .init()) }
        catch { suspend() }
    }
    func suspend() {
        guard !retired else { return };actionGeneration &+= 1; optionHeld=false;optionDismissed=false;sourceActions=[:];explanation = nil; sourceRect = nil; contextID = UUID().uuidString
        composition?.suspend()
    }
    func dispose() {
        guard !retired else { return }; retired = true
        // Retire ownership before callouts. Held old callbacks cannot modify a replacement binding.
        source?.onHelpChange = nil; composition?.onHelpAction = nil
        if let composition, composition.layer.superview === container { composition.layer.removeFromSuperview() }
        composition?.suspend()
    }
    private func textAndImages(_ commands: [EngineDrawingCommand]) -> [CGRect] {
        commands.flatMap { command -> [CGRect] in
            switch command {
            case .text(let text): return [text.rect]
            case .image(_, let rect, _): return [rect]
            case .group(_, let children): return textAndImages(children)
            case .clipped(let clip, _, let children): return textAndImages(children).map { $0.intersection(clip) }.filter { !$0.isNull && !$0.isEmpty }
            default: return [] // Background fills/rules are not live readings.
            }
        }
    }
}
