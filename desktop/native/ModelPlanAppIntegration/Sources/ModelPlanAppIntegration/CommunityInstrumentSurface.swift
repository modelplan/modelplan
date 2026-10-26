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
        self.publishedAt = publishedAt.flatMap { $0 <= observedAt ? $0 : nil }; self.observedAt = observedAt
    }
    public var age: TimeInterval? { publishedAt.map { observedAt.timeIntervalSince($0) } }
}

/// Upper provider retained by the real Community entry; one application feed, no second store/selector.
@MainActor public final class CommunityInstrumentSurfaceProvider: NativeSurfaceProvider {
    public private(set) var current: CommunityInstrumentView?
    private var settings: SettingsApplication?
    private weak var help: InstrumentHelpComposition?
    public init() {}
    public func makeOverview() -> any NativeOverviewSurface {
        if let current { return current }
        let surface = CommunityInstrumentView()
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

@MainActor private final class InstrumentContainer: NSView { override var isFlipped: Bool { true } }

/// Live read-only public model/effort consumer using M3's existing native MainScreenView.
/// This is not the complete four-region cockpit, Dock, renderer or an official appearance provider.
@MainActor public final class CommunityInstrumentView: NSObject, CommunityInstrumentSurface {
    public let view: NSView = InstrumentContainer()
    public let mainScreen = MainScreenView()
    public let modelPicker = NSPopUpButton(frame: .zero, pullsDown: false)
    public private(set) var orderedModelIDs: [String] = []
    public private(set) var selectedModelID: String?
    public private(set) var preferredContentSize = CGSize(width: 600, height: 372)
    public private(set) var sourceStamp = PublicationSourceStamp(publishedAt: nil, observedAt: .distantPast)
    public private(set) var renderFailure = false
    public private(set) var isPresented = false
    public var requestFreshSelection: (() -> Void)?
    public var contentSizeChanged: (() -> Void)?
    private let status = NSTextField(wrappingLabelWithString: "")
    private var settings: SettingsApplication?
    private var selection: AssembledModelSelection?
    private var diagnostics = StoreDiagnostics()
    private var rendering = false
    private var publishRequested = false, compareRequested = false
    private var retired = false
    private var helpBinding: CommunityContextHelpBinding?
    private var helpGeneration: UInt64 = 0
    private var needsSelection = false
    public var instrumentLanguage: InstrumentLanguage { settings?.effective.language == .english ? .english : .chinese }
    public override init() {
        super.init()
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
    public func bindHelp(_ composition: InstrumentHelpComposition) {
        guard !retired, helpBinding?.composition !== composition else { return }
        helpGeneration &+= 1; let token = helpGeneration
        let old = helpBinding; helpBinding = nil; old?.dispose()
        guard !retired, helpGeneration == token else { return }
        let binding = CommunityContextHelpBinding(composition: composition, source: mainScreen, container: view,
            active: { [weak self] in self?.isPresented == true && self?.retired == false },
            language: { [weak self] in self?.instrumentLanguage ?? .chinese },
            accessibility: { [weak self] in (self?.settings?.effective.reduceMotion ?? true, self?.settings?.effective.reduceTransparency ?? true) })
        helpBinding = binding; binding.install()
    }
    public func apply(_ application: SettingsApplication) {
        guard !retired, application.snapshot.revision >= (settings?.snapshot.revision ?? 0) else { return }
        let languageChanged = settings?.effective.language != application.effective.language
        settings = application
        modelPicker.setAccessibilityLabel(instrumentLanguage == .chinese ? "选择模型" : "Choose a model")
        switch application.snapshot.preferences.theme {
        case .system: mainScreen.appearance = nil
        case .day: mainScreen.appearance = NSAppearance(named: .aqua)
        case .night: mainScreen.appearance = NSAppearance(named: .darkAqua)
        }
        // An application commit must reevaluate live feeds, not resurrect a cached exact personal join.
        if isPresented, let requestFreshSelection { requestFreshSelection() }
        else if languageChanged { needsSelection = true; clearForPendingLanguage() }
        helpBinding?.refresh()
    }
    public func render(snapshot: JoinedSnapshot?, diagnostics: StoreDiagnostics) { self.diagnostics = diagnostics }
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
    }
    public func suspendPresentation() { isPresented = false; mainScreen.suspend(); helpBinding?.suspend() }
    public func closePresentation() { isPresented = false; mainScreen.closeForCockpit(); helpBinding?.suspend() }
    public func dispose() {
        guard !retired else { return }; retired = true; isPresented = false; helpGeneration &+= 1
        let binding = helpBinding; helpBinding = nil; binding?.dispose()
        modelPicker.target = nil; modelPicker.action = nil; modelPicker.isEnabled = false
        mainScreen.closeForCockpit(); mainScreen.onIntents = nil
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
        mainScreen.closeForCockpit(); mainScreen.isHidden = true
        modelPicker.isEnabled = false
        status.stringValue = instrumentLanguage == .chinese ? "正在等待当前语言的模型目录" : "Waiting for the current model catalogue"
        status.frame = .init(x: 8, y: 40, width: max(1, preferredContentSize.width - 16), height: 60)
        status.isHidden = false; helpBinding?.suspend()
    }
    private func fail() {
        mainScreen.closeForCockpit(); mainScreen.isHidden = true; renderFailure = true
        status.stringValue = instrumentLanguage == .chinese ? "当前数据暂无法在原生视图显示" : "Current data cannot be displayed in the native view"
        status.frame = .init(x: 8, y: 40, width: max(1, preferredContentSize.width - 16), height: 60)
        status.isHidden = false; modelPicker.isEnabled = false; helpBinding?.suspend()
    }
}
