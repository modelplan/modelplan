// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanAssembly
import ModelPlanCore
import ModelPlanShell
import ModelPlanInstruments
import ModelPlanCommunityHost
import ModelPlanSettings

/// Actual publication metadata for a future Option source-corner consumer, never synthetic age.
public struct PublicationSourceStamp: Equatable, Sendable {
    public let publishedAt: Date?, observedAt: Date
    public init(publishedAt: Date?, observedAt: Date) {
        self.publishedAt = publishedAt.flatMap { $0.timeIntervalSinceReferenceDate.isFinite && observedAt.timeIntervalSinceReferenceDate.isFinite && $0 <= observedAt ? $0 : nil }; self.observedAt = observedAt
    }
    public var age: TimeInterval? { publishedAt.map { observedAt.timeIntervalSince($0) } }
}

/// Upper provider retained by the real Community entry; one application feed, no second store/selector.
@MainActor public final class CommunityInstrumentSurfaceProvider: NativeSurfaceProvider {
    public private(set) var current: CommunityInstrumentView?
    private var settings: SettingsApplication?
    private weak var help: InstrumentHelpComposition?
    private let openWebsite: @MainActor (InstrumentWebsiteLink) -> Void
    private let makeMainScreen: (@MainActor () -> MainScreenView)?
    private let makeCockpit: (@MainActor (MainScreenView) throws -> CockpitInstrumentComposition)?
    public init(openWebsite: @escaping @MainActor (InstrumentWebsiteLink) -> Void = { _ in },
                makeCockpit: (@MainActor (MainScreenView) throws -> CockpitInstrumentComposition)? = nil,
                makeMainScreen: (@MainActor () -> MainScreenView)? = nil) {
        self.openWebsite = openWebsite; self.makeCockpit = makeCockpit; self.makeMainScreen = makeMainScreen
    }
    public func makeOverview() -> any NativeOverviewSurface {
        if let current { return current }
        let surface = CommunityInstrumentView(mainScreen: makeMainScreen?(), openWebsite: openWebsite)
        if let makeCockpit {
            do {
                let composition = try makeCockpit(surface.mainScreen)
                do { try surface.attachCockpit(composition) }
                catch { composition.dispose(); surface.fail() }
            } catch { surface.fail() }
        }
        current = surface
        if let settings { surface.apply(settings) }
        if let help { surface.bindHelp(help) }
        return surface
    }
    public func bindHelp(_ composition: InstrumentHelpComposition) {
        help = composition; current?.bindHelp(composition)
    }
    public func apply(_ application: SettingsApplication) {
        guard application.snapshot.revision >= (settings?.snapshot.revision ?? 0) else { return }
        settings = application; current?.apply(application)
    }
}

@MainActor private final class InstrumentContainer: NSView {
    var optionChanged: ((Bool) -> Void)?
    var escape: (() -> Bool)?
    override var isFlipped: Bool { true }
    override func flagsChanged(with event: NSEvent) { optionChanged?(event.modifierFlags.contains(.option));super.flagsChanged(with:event) }
    override func keyDown(with event: NSEvent) { if event.keyCode==53,escape?()==true { return };super.keyDown(with:event) }
}

/// Live read-only public model/effort consumer using M3's existing native MainScreenView.
/// This is not the complete four-region cockpit, Dock, renderer or an official appearance provider.
@MainActor public final class CommunityInstrumentView: NSObject, CommunityInstrumentSurface, CommunityPublicCatalogueConsumer, CommunityInstrumentSettingsRouting {
    public let view: NSView = InstrumentContainer()
    public let mainScreen: MainScreenView
    public let modelPicker = NSPopUpButton(frame: .zero, pullsDown: false)
    public private(set) var orderedModelIDs: [String] = []
    public private(set) var selectedModelID: String?
    public private(set) var preferredContentSize = CGSize(width: 600, height: 372)
    public private(set) var sourceStamp = PublicationSourceStamp(publishedAt: nil, observedAt: .distantPast)
    public private(set) var renderFailure = false
    public private(set) var isPresented = false
    public var requestFreshSelection: (() -> Void)?
    public var contentSizeChanged: (() -> Void)?
    public private(set) var cockpitComposition: CockpitInstrumentComposition?
    public var requestedInstrumentScope: InstrumentScope { cockpitComposition?.requestedScope ?? .all }
    /// Settings/favourites and other application effects stay with the upper owner.
    public var requestSubscriptionsSettings: (() async -> Void)?
    public var onInstrumentIntent: ((InstrumentSurfaceIntent) -> Void)?
    private let status = NSTextField(wrappingLabelWithString: "")
    private var settings: SettingsApplication?
    private var selection: AssembledModelSelection?
    private var diagnostics = StoreDiagnostics()
    private var instrumentSnapshot: JoinedSnapshot?
    private var publicCatalogue: PublicPublication?
    public func render(publication: PublicPublication?) { publicCatalogue = publication }
    private var rendering = false
    private var publishRequested = false, compareRequested = false
    private var retired = false
    private var helpBinding: CommunityContextHelpBinding?
    private var helpGeneration: UInt64 = 0
    private var needsSelection = false
    public var instrumentLanguage: InstrumentLanguage { settings?.effective.language == .english ? .english : .chinese }
    private let openWebsite: @MainActor (InstrumentWebsiteLink) -> Void
    public init(mainScreen suppliedMainScreen: MainScreenView? = nil, openWebsite: @escaping @MainActor (InstrumentWebsiteLink) -> Void = { _ in }) {
        self.mainScreen = suppliedMainScreen ?? MainScreenView(); self.openWebsite = openWebsite
        super.init()
        // Process-local AppKit focus notifications; no activation, event monitor or global shortcut.
        NotificationCenter.default.addObserver(self,selector:#selector(applicationLostFocus(_:)),
            name:NSApplication.didResignActiveNotification,object:nil)
        NotificationCenter.default.addObserver(self,selector:#selector(windowLostKey(_:)),
            name:NSWindow.didResignKeyNotification,object:nil)
        (view as? InstrumentContainer)?.optionChanged = { [weak self] held in self?.setOptionHelpHeld(held) }
        let escape: () -> Bool = { [weak self] in self?.helpBinding?.consumeEscape() ?? false }
        mainScreen.onHelpEscape=escape;(view as? InstrumentContainer)?.escape=escape
        mainScreen.onIntents = { [weak self] intents in
            guard let self,self.isPresented,!self.retired,!self.renderFailure else { return }
            for intent in intents {
                guard self.isPresented,!self.retired,!self.renderFailure else { return }
                if case .openWebsite(let link)=intent,self.mainScreen.presentation?.websiteLinks.contains(link)==true {
                    self.openWebsite(link)
                }
            }
        }
        view.addSubview(modelPicker); view.addSubview(mainScreen); view.addSubview(status)
        mainScreen.appearance = nil
        modelPicker.target = self; modelPicker.action = #selector(pickedModel(_:))
        modelPicker.setAccessibilityIdentifier("community.model-picker")
        modelPicker.setAccessibilityLabel("选择模型")
        status.setAccessibilityIdentifier("community.instrument-status")
        modelPicker.frame = .init(x: 0, y: 0, width: 600, height: 26)
        mainScreen.frame.origin = .init(x: 0, y: 32)
        view.setFrameSize(preferredContentSize)
    }
    @objc private func applicationLostFocus(_ notification: Notification) { retireFocusHelp() }
    public func attachCockpit(_ composition: CockpitInstrumentComposition) throws {
        guard !retired, !isPresented, cockpitComposition == nil,
              composition.surface.mainScreen === mainScreen, composition.rootView !== view,
              !composition.rootView.isDescendant(of: mainScreen)
        else { throw InstrumentSurfaceError.invalidInput }
        cockpitComposition = composition
        composition.onFailure = { [weak self] _ in self?.fail() }
        modelPicker.isHidden = true; composition.rootView.frame.origin = .zero
        view.addSubview(composition.rootView)
        composition.onIntent = { [weak self, weak composition] intent in
            guard let self, let composition, self.cockpitComposition === composition,
                  !self.retired, self.isPresented, !self.renderFailure else { return }
            switch intent {
            case .openWebsite(let link):
                guard self.mainScreen.presentation?.websiteLinks.contains(link) == true else { return }
                self.openWebsite(link)
            case .modelSelected(let id): self.selectedModelID = id; self.requestFreshSelection?()
            case .requestScope: self.requestFreshSelection?()
            default: break
            }
            self.onInstrumentIntent?(intent)
        }
    }
    @objc private func windowLostKey(_ notification: Notification) {
        guard let current=view.window,let window=notification.object as? NSWindow,window === current else { return }
        retireFocusHelp()
    }
    private func retireFocusHelp() {
        guard !retired,isPresented else { return }
        // Retire held/dismissed state and callback ownership before the source's leave callout.
        helpBinding?.suspend();mainScreen.leaveHelp()
    }
    public func bindHelp(_ composition: InstrumentHelpComposition) {
        guard !retired, helpBinding?.composition !== composition else { return }
        helpGeneration &+= 1; let token = helpGeneration
        let old = helpBinding; helpBinding = nil; old?.dispose()
        guard !retired, helpGeneration == token else { return }
        let binding = CommunityContextHelpBinding(composition: composition, source: mainScreen, container: view,
            active: { [weak self] in self?.isPresented == true && self?.retired == false },
            language: { [weak self] in self?.instrumentLanguage ?? .chinese },
            accessibility: { [weak self] in (self?.settings?.effective.reduceMotion ?? true, self?.settings?.effective.reduceTransparency ?? true) },
            publicationSource: { [weak self] in
                guard let self else { return .init(publishedAt:nil,now:.distantPast,language:.chinese) }
                return .init(publishedAt:self.sourceStamp.publishedAt,now:self.sourceStamp.observedAt,language:self.instrumentLanguage)
            }, openWebsite: { [weak self] link in
                guard let self,self.isPresented,!self.retired,!self.renderFailure else { return };self.openWebsite(link)
            })
        helpBinding = binding; binding.install()
    }
    public func setOptionHelpHeld(_ held: Bool) { guard !retired,isPresented,!renderFailure else { return };helpBinding?.setOptionHeld(held) }
    public func apply(_ application: SettingsApplication) {
        guard !retired, application.snapshot.revision >= (settings?.snapshot.revision ?? 0) else { return }
        let languageChanged = settings?.effective.language != application.effective.language
        settings = application
        modelPicker.setAccessibilityLabel(instrumentLanguage == .chinese ? "选择模型" : "Choose a model")
        let appearance: NSAppearance?
        switch application.snapshot.preferences.theme {
        case .system: appearance = nil
        case .day: appearance = NSAppearance(named: .aqua)
        case .night: appearance = NSAppearance(named: .darkAqua)
        }
        if let cockpitComposition { cockpitComposition.surface.applyAppearance(appearance) }
        else { mainScreen.appearance = appearance }
        // An application commit must reevaluate live feeds, not resurrect a cached exact personal join.
        if isPresented, let requestFreshSelection { requestFreshSelection() }
        else if languageChanged { needsSelection = true; clearForPendingLanguage() }
        helpBinding?.refresh()
    }
    public func render(snapshot: JoinedSnapshot?, diagnostics: StoreDiagnostics) {
        guard !retired else { return }; self.diagnostics = diagnostics; instrumentSnapshot = snapshot
    }
    public func render(selection: AssembledModelSelection, publishedAt: Date?, now: Date) {
        guard !retired else { return }
        self.selection = selection; needsSelection = false
        sourceStamp = .init(publishedAt: publishedAt, observedAt: now)
        guard isPresented else { return } // Buffer facts while closed/hidden, no raster work or timer.
        requestPublish()
    }
    public func resumePresentation() {
        guard !retired else { return }; isPresented = true
        if let requestFreshSelection { requestFreshSelection() }
        else if !needsSelection, selection != nil { requestPublish() }
        do { try cockpitComposition?.setPresentationAllowed(true) } catch { fail() }
    }
    public func suspendPresentation() {
        isPresented = false; try? cockpitComposition?.setPresentationAllowed(false)
        mainScreen.suspend(); helpBinding?.suspend()
    }
    public func closePresentation() {
        isPresented = false; cockpitComposition?.close(); mainScreen.closeForCockpit(); helpBinding?.suspend()
    }
    public func dispose() {
        guard !retired else { return }; retired = true; isPresented = false; helpGeneration &+= 1
        NotificationCenter.default.removeObserver(self,name:NSApplication.didResignActiveNotification,object:nil)
        NotificationCenter.default.removeObserver(self,name:NSWindow.didResignKeyNotification,object:nil)
        let binding = helpBinding; helpBinding = nil; binding?.dispose()
        modelPicker.target = nil; modelPicker.action = nil; modelPicker.isEnabled = false
        (view as? InstrumentContainer)?.optionChanged = nil;(view as? InstrumentContainer)?.escape=nil
        mainScreen.onHelpEscape=nil
        mainScreen.closeForCockpit(); mainScreen.onIntents = nil
        cockpitComposition?.dispose(); cockpitComposition = nil; onInstrumentIntent = nil; requestSubscriptionsSettings = nil; instrumentSnapshot = nil
        requestFreshSelection = nil; contentSizeChanged = nil
    }
    @objc private func pickedModel(_ sender: NSPopUpButton) {
        guard sender === modelPicker, let id = sender.selectedItem?.representedObject as? String else { return }
        selectModel(id)
    }
    public func selectModel(_ id: String) {
        guard !retired, isPresented, !rendering else { return }
        requestFreshSelection?()
        guard !retired, isPresented, selection != nil, orderedModelIDs.contains(id) else { return }
        selectedModelID = id; requestPublish(compare: true)
    }
    private func requestPublish(compare: Bool = false) {
        publishRequested = true; compareRequested = compareRequested || compare
        guard !rendering else { return }
        rendering = true; defer { rendering = false }
        while publishRequested, isPresented, !retired, let selection {
            let compare = compareRequested
            publishRequested = false; compareRequested = false
            publish(selection, compare: compare)
        }
    }
    private func publish(_ selection: AssembledModelSelection, compare: Bool) {
        guard selection.language == instrumentLanguage else { clearForPendingLanguage(); return }
        if let cockpitComposition { publishCockpit(cockpitComposition, selection: selection, compare: compare); return }
        let grouped = Dictionary(grouping: selection.models, by: \.id)
        let ids = selection.shared.orderedIDs
        guard ids.allSatisfy({ grouped[$0]?.count == 1 }) else { fail(); return }
        let inputs = ids.compactMap { grouped[$0]?.first }.map {
            FaderChannelInput(model: $0, basisNote: selection.modelAvailabilityNotes[$0.id])
        }
        orderedModelIDs = ids
        if let id = selectedModelID, !ids.contains(id) { selectedModelID = nil }
        modelPicker.removeAllItems()
        let zh = instrumentLanguage == .chinese
        let notice = selection.selectionNotice ?? (zh ? "只读模型目录" : "Read-only model catalogue")
        let caption = notice + (diagnostics.publicationWarning ? (zh ? " · 使用已缓存的公开数据" : " · Cached public data") : "")
        modelPicker.addItem(withTitle: caption); modelPicker.lastItem?.isEnabled = false
        for input in inputs {
            modelPicker.addItem(withTitle: input.model.name)
            modelPicker.lastItem?.representedObject = input.model.id
        }
        if let id = selectedModelID, let index = ids.firstIndex(of: id) { modelPicker.selectItem(at: index + 1) }
        else { modelPicker.selectItem(at: 0) }
        modelPicker.isEnabled = !ids.isEmpty
        let selected = inputs.first { $0.model.id == selectedModelID }
        var lines = [notice]
        if let selected {
            lines.append(selected.model.name)
            let efforts = selected.model.efforts.map(\.label).joined(separator: " / ")
            lines.append(efforts.isEmpty ? (zh ? "已发布档位暂不可用" : "Published efforts unavailable") : (zh ? "已发布档位：" : "Published efforts: ") + efforts)
            if let basis = selected.basisNote { lines.append(basis) }
        } else { lines.append(ids.isEmpty ? selection.emptyStateMessage : (zh ? "选择模型查看已发布档位" : "Choose a model to inspect published efforts")) }
        // Do not invent usage/credits/coverage or precise current-model facts for missing joins.
        let pages: [MainScreenPageContent] = [
            .init(.overview, lines: [notice, zh ? "使用情况未在此视图接入" : "Usage is not connected to this view"]),
            .init(.effort, lines: lines),
            .init(.subscriptions, lines: [zh ? "订阅详情未在此视图接入" : "Subscription details are not connected to this view"]),
            .init(.destinations, lines: [zh ? "去向信息未在此视图接入" : "Destination data is not connected to this view"]),
        ]
        // Settings.size is explicitly Dock size, not permission to change cockpit/profile geometry.
        // This independent community surface retains the existing default MainScreen profile.
        let compact = false
        do {
            // A picker action replaces its sourced comparison before either sizing or drawing.
            // Otherwise update would first render A at B's preflight size, or keep A when B
            // has no usable recommendation and openComparison(B) correctly declines.
            if compare { mainScreen.closeForCockpit() }
            var controller = mainScreen.controller
            _ = try controller.update(inputs: inputs, selection: selection.instruments,
                publication: selection.instruments?.publication, publicationUsable: selection.instruments != nil,
                scope: .all, pages: pages)
            if compare, let selectedModelID { _ = controller.openComparison(modelID: selectedModelID, from: .comparisonRow(selectedModelID), toggle: false) }
            var minimum = CGSize(width: 600, height: 340)
            // Prepare enough room before publishing a changed page/comparison; never retain an old bitmap on failure.
            for page in MainScreenPage.allCases {
                var candidate = controller; _ = candidate.selectPage(.init(page))
                let required = mainScreen.recipeProvider.minimumSize(for: .init(controller: candidate, language: instrumentLanguage, compact: compact))
                minimum.width = max(minimum.width, required.width); minimum.height = max(minimum.height, required.height)
            }
            let currentMinimum = mainScreen.recipeProvider.minimumSize(for: .init(controller: controller, language: instrumentLanguage, compact: compact))
            minimum.width = max(minimum.width, currentMinimum.width); minimum.height = max(minimum.height, currentMinimum.height)
            guard minimum.width <= 1600, minimum.height <= 1000 else { fail(); return }
            mainScreen.setFrameSize(minimum)
            try mainScreen.update(inputs: inputs, selection: selection.instruments,
                publication: selection.instruments?.publication, publicationUsable: selection.instruments != nil,
                language: instrumentLanguage, compact: compact, scope: .all, pages: pages)
            if compare, let selectedModelID {
                mainScreen.openComparison(modelID: selectedModelID, from: .comparisonRow(selectedModelID), toggle: false)
                if mainScreen.controller.trial == nil { mainScreen.selectPage(.init(.effort)) }
            }
            let next = CGSize(width: minimum.width, height: minimum.height + 32)
            let changed = preferredContentSize != next; preferredContentSize = next
            view.setFrameSize(next); modelPicker.frame.size.width = next.width
            status.isHidden = true; mainScreen.isHidden = false; renderFailure = false
            if changed { contentSizeChanged?() }
            helpBinding?.refresh()
        } catch { fail() }
    }
    private func clearForPendingLanguage() {
        cockpitComposition?.field?.setPresented(false)
        cockpitComposition?.surface.clearObservation(); cockpitComposition?.rootView.isHidden = true
        mainScreen.closeForCockpit(); mainScreen.isHidden = true
        modelPicker.isEnabled = false
        status.stringValue = instrumentLanguage == .chinese ? "正在等待当前语言的模型目录" : "Waiting for the current model catalogue"
        status.frame = .init(x: 8, y: 40, width: max(1, preferredContentSize.width - 16), height: 60)
        status.isHidden = false; helpBinding?.suspend()
    }
    fileprivate func fail() {
        cockpitComposition?.field?.setPresented(false)
        cockpitComposition?.surface.clearObservation(); cockpitComposition?.rootView.isHidden = true
        mainScreen.closeForCockpit(); mainScreen.isHidden = true; renderFailure = true
        status.stringValue = instrumentLanguage == .chinese ? "当前数据暂无法在原生视图显示" : "Current data cannot be displayed in the native view"
        status.frame = .init(x: 8, y: 40, width: max(1, preferredContentSize.width - 16), height: 60)
        status.isHidden = false; modelPicker.isEnabled = false; helpBinding?.suspend()
    }
    private func publishCockpit(_ composition: CockpitInstrumentComposition,
                                selection: AssembledModelSelection, compare: Bool) {
        do {
            try composition.field?.update(publication: publicCatalogue, selection: selection,
                appearance: .init(theme: view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .night : .day,
                                  locale: instrumentLanguage == .english ? .english : .chinese),
                reduceMotion: settings?.effective.reduceMotion ?? true,
                reduceTransparency: settings?.effective.reduceTransparency ?? true)
            try composition.update(.init(snapshot: instrumentSnapshot, selection: selection,
                scope: composition.requestedScope, language: instrumentLanguage,
                publishedAt: sourceStamp.publishedAt, now: sourceStamp.observedAt,
                showProjectNames: settings?.effective.showProjectNames ?? false))
            guard !retired, isPresented, cockpitComposition === composition else { return }
            let size = composition.rootView.frame.size
            guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0,
                  size.width <= 2048, size.height <= 2048 else { throw InstrumentSurfaceError.invalidFrames }
            orderedModelIDs = selection.shared.orderedIDs
            if let id = selectedModelID, !orderedModelIDs.contains(id) { selectedModelID = nil }
            if compare, let selectedModelID {
                mainScreen.openComparison(modelID: selectedModelID, from: .comparisonRow(selectedModelID), toggle: false)
            }
            let changed = preferredContentSize != size; preferredContentSize = size
            view.setFrameSize(size); modelPicker.isHidden = true; status.isHidden = true
            composition.rootView.isHidden = false; renderFailure = false
            if changed { contentSizeChanged?() }; helpBinding?.refresh()
        } catch { fail() }
    }
}
