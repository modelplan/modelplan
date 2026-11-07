// SPDX-License-Identifier: MIT
import AppKit
import OSLog
import CoreGraphics
import ModelPlanCore
import ModelPlanShell
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanPrimitives
import ModelPlanSettings
import ModelPlanInstruments
import ModelPlanOfficialDock
import ModelPlanDockResources
import ModelPlanCommunityHost

/// Geometry returned by an injected appearance, already scaled in view-local points.
struct DockHoverStation {
    let inward: CGVector
    let pitch: CGFloat
}

public struct StaticDockGeometry {
    public var hoverRects: [CGRect]
    public var sliverLength: CGFloat
    public var sliverThickness: CGFloat
    public var sliverAlongAnchor: CGFloat?
    public var sliverImage: CGImage?
    public var sliverScale: Int
    public var consoleButton: CGRect?
    public var dragRegions: DockBackgroundDragRegions?
    /// Identity and along-strip positions supplied by the active appearance.
    public var noticeStationBySubscription: [String: String] = [:]
    public var noticeStationPositions: [String: CGFloat] = [:]
    public var noticeUnit: CGFloat = 1
    /// Normalized along-axis member pitch ranges registered by the active appearance.
    public var quotaPitchRanges: [String: ClosedRange<Double>] = [:]
    var hoverStations: [String: DockHoverStation] = [:]
    public init(hoverRects: [CGRect], sliverLength: CGFloat = 52, sliverThickness: CGFloat = 4, consoleButton: CGRect? = nil, dragRegions: DockBackgroundDragRegions? = nil, sliverAlongAnchor: CGFloat? = nil, sliverImage: CGImage? = nil, sliverScale: Int = 1) {
        self.hoverRects = hoverRects; self.sliverLength = sliverLength; self.sliverThickness = sliverThickness
        self.consoleButton = consoleButton; self.dragRegions = dragRegions
        self.sliverAlongAnchor = sliverAlongAnchor; self.sliverImage = sliverImage; self.sliverScale = sliverScale
    }

    @MainActor public mutating func scaleRegistration(by factor: CGFloat) {
        func rect(_ r: CGRect) -> CGRect {
            .init(x: r.minX * factor, y: r.minY * factor, width: r.width * factor, height: r.height * factor)
        }
        hoverRects = hoverRects.map(rect); sliverLength *= factor; sliverThickness *= factor
        sliverAlongAnchor = sliverAlongAnchor.map { $0 * factor }; consoleButton = consoleButton.map(rect)
        if let regions = dragRegions {
            var transform = CGAffineTransform(scaleX: factor, y: factor)
            if let body = regions.body.copy(using: &transform) {
                dragRegions = .init(body: body, grips: regions.grips.compactMap { $0.copy(using: &transform) },
                                    excludedControls: regions.excludedControls.map(rect))
            }
        }
    }
    public mutating func registerSliver(hullBounds: CGRect, expandedSize: CGSize, edge: SettingsDockEdge,
                                       parameters: DockSliverParameters = .current, scale: CGFloat = 1) throws {
        guard !hullBounds.isNull, !hullBounds.isEmpty else { throw DockEdgeError.invalidGeometry }
        let metrics = try parameters.resolve(fullSpan: edge.isHorizontal ? hullBounds.width : hullBounds.height, scale: scale)
        sliverLength = metrics.length; sliverThickness = metrics.thickness
        sliverAlongAnchor = edge.isHorizontal ? hullBounds.midX : expandedSize.height - hullBounds.midY
    }
}

@MainActor private final class StaticDockContainer: NSView { override var isFlipped: Bool { true } }
/// Empty-state copy must not swallow the neutral Dock's background grab area.
@MainActor private final class StaticDockStatusLabel: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

@MainActor private final class DockIgnitionButton: NSButton {
    var onHelpFocusChanged: (() -> Void)?
    private var keyboardFocused = false
    private var assistiveFocused = false

    private var canPresentHelp: Bool { isEnabled && !isHiddenOrHasHiddenAncestor && !bounds.isEmpty }
    var hasHelpFocus: Bool { canPresentHelp && (keyboardFocused || assistiveFocused) }

    override func becomeFirstResponder() -> Bool {
        guard super.becomeFirstResponder() else { return false }
        updateHelpFocus(keyboard: canPresentHelp)
        return true
    }

    override func resignFirstResponder() -> Bool {
        guard super.resignFirstResponder() else { return false }
        updateHelpFocus(keyboard: false)
        return true
    }

    override func setAccessibilityFocused(_ focused: Bool) {
        super.setAccessibilityFocused(focused)
        updateHelpFocus(assistive: focused && canPresentHelp)
    }

    override func viewDidHide() {
        clearHelpFocus()
        super.viewDidHide()
    }

    func clearHelpFocus() {
        setAccessibilityHelp(nil)
        updateHelpFocus(keyboard: false, assistive: false)
    }

    private func updateHelpFocus(keyboard: Bool? = nil, assistive: Bool? = nil) {
        let wasFocused = keyboardFocused || assistiveFocused
        if let keyboard { keyboardFocused = keyboard }
        if let assistive { assistiveFocused = assistive }
        if wasFocused != (keyboardFocused || assistiveFocused) { onHelpFocusChanged?() }
    }
}

public enum DockHostPurpose: Equatable, Sendable { case production, selfTest }

struct DockHelpInteraction: Equatable {
    enum Source: Equatable { case pointer, keyboard }
    let anchor: DockRequestedHelpAnchor
    let source: Source
    let receipt = UUID()
}

/// Interactive native Dock companion shared by production and explicit self-tests.
/// The static instrument renderer does not disable native panels, edge/hide, drag/drop or menus.
/// Working effects/entrance, global hooks, reader activation and services are separate owners.
@MainActor public final class StaticDockPreviewHost: NSObject, CommunityCompanionVisibility, NSMenuDelegate, DockInteractionHostPort {
    public typealias Appearance = @MainActor (DockInstrumentView, [DockInstrumentReading], SettingsPreferences) throws -> StaticDockGeometry
    public let purpose: DockHostPurpose
    public private(set) var isVisible = false
    public private(set) var lastAppearanceError: Error?
    public var visibilityChanged: (() -> Void)?
    private func reportVisibility(_ visible: Bool) {
        guard visible != isVisible else { return }
        isVisible = visible; visibilityChanged?()
    }
    public var showConsole: (() -> Void)?
    public var cockpitEntryEnabled = true {
        didSet {
            consoleButton.isEnabled = cockpitEntryEnabled
            guard oldValue != cockpitEntryEnabled else { return }
            if let presentation = edge.presentation { publishDockHelpSurface(presentation) }
            if !cockpitEntryEnabled { consoleButton.clearHelpFocus() }
        }
    }
    public var showSettings: (() -> Void)?
    var openCardSourceURL: (URL) -> Void = { _ = NSWorkspace.shared.open($0) }
    /// G3-28: the widget menu's Auto-Collapse item. The app writes the same stored setting
    /// as Settings' auto-collapse switch; without an app the preview applies nothing.
    public var requestAutoCollapse: ((Bool) -> Void)?
    /// G3-22: shown as the first, disabled line of the widget menu (the status icon may be hidden).
    public var statusIconNotice: SettingsText?
    /// Set only when the member-scoped refresh adapter is actually installed.
    public var ringRefreshAvailable = false
    public var catalogueChanged: (([SettingsSubscription]) -> Void)?
    public var displayChoicesChanged: (([SettingsDisplayChoice]) -> Void)?
    public var commitDisplayPlacement: ((String, SettingsDockEdge, Double) -> Void)?
    public var commitPlacement: ((SettingsDockEdge, Double) -> Void)?
    /// Current resolver facts, separate from saved intent. Replacing an observer replays once.
    /// The consumer may update context, but must not persist this recovery as a preference.
    public var onPlacementObserved: ((_ placement: DockEdgePlacement?, _ recovering: Bool) -> Void)? {
        didSet {
            lastPlacementObservation = nil
            if onPlacementObserved != nil { publishPlacementObservation(edge.presentation) }
        }
    }
    private struct PlacementObservation: Equatable {
        let placement: DockEdgePlacement?
        let recovering: Bool
    }
    private var lastPlacementObservation: PlacementObservation?
    private let appearance: Appearance?
    private var attention = DockAttentionState()
    private var attentionSignals: [DockSubscriptionSignal] = []
    private var attentionWasExpanded = false
    private var locateLayer: CAShapeLayer?
    private var pendingUserReveal = false
    private var cockpitPresentationBlocked = false
    private var locateTask: Task<Void, Never>?
    private var locating = false
    /// G3-12: a requested Help map is drawn over the expanded widget, so the widget stays
    /// expanded while the map is visible. Releasing the hold lets the normal hide resume.
    var helpMapHold = false {
        didSet {
            guard helpMapHold != oldValue, !helpMapHold else { return }
            Task { @MainActor [weak self] in
                guard let self, !self.retired, !self.helpMapHold else { return }
                self.edge.refresh()
            }
        }
    }
    /// Presentation is allowed by the lifecycle and not blocked by the cockpit, so a Show
    /// request can make the widget visible now.
    var canPresentForHelp: Bool { permitted && !retired && !retiring && !cockpitPresentationBlocked }
    public private(set) var menuNotice: DockNotice?
    /// The menu owner connects DockNoticeIndicatorView; no notification ledger is duplicated here.
    public var menuNoticeDidChange: ((DockNotice?, Bool) -> Void)?
    private func publishAttention() {
        guard let projection = try? attention.project(attentionSignals, stationBySubscription: geometry.noticeStationBySubscription,
                                                       sliverAlerts: preferences.sliverAlert, at: currentDate()) else { menuNotice = nil; menuNoticeDidChange?(nil, false); return }
        menuNotice = projection.menuNotice
        if let callback = menuNoticeDidChange {
            let first = projection.menuNotice.map { attention.firstAppearance(of: $0.key, on: .menu) } ?? false
            callback(projection.menuNotice, first)
        }
    }
    private var comparisonStatuses: [String: DockQuotaStatus] = [:]
    /// Only detached synthetic hosts may match the prototype's independent fixture level.
    @_spi(DockResourceChecks) public func setComparisonStatusForChecks(id: String, status: DockQuotaStatus) {
        guard !createsNativePanels, !retired, !id.isEmpty, status != .unknown else { return }
        comparisonStatuses = [id: status]; inputGeneration &+= 1; rebuild()
    }
    private var workingSignals: [String: DockWorkingSignal] = [:]
    private var workingDriver: DockWorkingEffects?
    private var workingFrameProvider: (any EffectFrameProvider)?
    private var workingInstallationError: Error?
    public private(set) var lastWorkingEffectError: Error?
    @_spi(DockResourceChecks) public var activeWorkingEffectIDs: Set<String> { workingDriver?.activeIDs ?? [] }
    @_spi(DockResourceChecks) public var rotatingWorkingEffectIDs: Set<String> { workingDriver?.rotatingIDs ?? [] }
    @_spi(DockResourceChecks) public var animatingWorkingEffectIDs: Set<String> { workingDriver?.animatingIDs ?? [] }
    @_spi(DockResourceChecks) public func seekWorkingEffectsForChecks(_ seconds: Double) { workingDriver?.seekForCapture(seconds) }
    private let sliverParameters: DockSliverParameters
    private let currentDate: @MainActor () -> Date
    private let readerCapabilities: CommunityReaderCapabilities
    private let createsNativePanels: Bool
    private let prepareDetachedAlternateAppearances: Bool
    private let nativeEnvironment: (@MainActor () -> DockEdgeEnvironment)?
    private let elapsedClock: (() -> TimeInterval)?
    private let edgeScheduling: (any DockEdgeScheduling)?
    private let pointerSampleSource: (() -> CGPoint?)?
    private lazy var pointerSurface = makePointerSurface()
    var pointerInputView: PulsePanelPointerSurface { pointerSurface }
    var edgePresentation: DockEdgePresentation? { edge.presentation }
    var nativePanel: NSPanel? { panel }
    #if MODELPLAN_DOCK_NATIVE_JOURNEY
    var suppressJourneyOrderIn = false
    #endif

    #if DEBUG
    var detachedCardForChecks: DockCardView? { !createsNativePanels && !card.isHidden ? card : nil }
    #endif
    func refreshPresence() { displayFollower.sample(); edge.refresh() }
    var isFollowingDisplay: Bool { displayFollower.isRunning }
    private var followedDisplayID: String?
    private lazy var displayFollower = makeDisplayFollower()
    private var application: SettingsApplication?
    public var currentMenuBarPreferences: SettingsPreferences? { (retired || retiring) ? nil : application?.snapshot.preferences }
    public var menuBarPreferencesChanged: (() -> Void)?
    /// Composition invalidates its retained provider and deadline before close returns.
    var onWillRetire: (() -> Void)?
    /// Screen-coordinate anchors exist only while the actual Dock panel is visible.
    var dockHelpSurfaceDidChange: ((DockHelpSurface?) -> Void)? {
        didSet { dockHelpSurfaceDidChange?(lastDockHelpSurface) }
    }
    private(set) var currentDockHelpInteraction: DockHelpInteraction?
    var dockHelpInteractionDidChange: ((DockHelpInteraction?) -> Void)?
    private var lastDockHelpSurface: DockHelpSurface?
    private var dockHelpInputGeneration: UInt64?
    var currentDockHelpSurface: DockHelpSurface? {
        guard let surface = lastDockHelpSurface, isCurrentDockHelpSurface(surface) else { return nil }
        return surface
    }
    private var snapshot: JoinedSnapshot?, diagnostics = StoreDiagnostics()
    private var model: CommunityDockSnapshot?
    private var contentProvider: any DockContentProvider
    private var contentMenuStatusLines: [String]?
    private var contentEmptyText: String?
    #if DEBUG && MODELPLAN_E2E_JOURNEY
    private var journeyHoverID:String?
    private var journeyOwnsCardController=false
    private final class JourneyCardScheduler:DockEdgeScheduling {
        func arm(at deadline:TimeInterval,_ action:@escaping @MainActor ()->Void) {}
        func cancel() {}
    }
    /// Read the very model fed to the retained Dock; no additional producer or projection.
    public var journeySnapshot: CommunityDockSnapshot? { CommunityJourneyCI.enabled ? model : nil }
    public var journeyFeedGeneratedAt: Date? { CommunityJourneyCI.enabled ? snapshot?.personal.generatedAt.date : nil }
    public var journeyReasonRows: [[String: String]] {
        guard CommunityJourneyCI.enabled else { return [] }
        return Array((model?.presentationRows.values.map { ["reason": $0.reason, "nextStep": $0.nextStep] } ?? []).prefix(16))
    }
    private func journeyProvider(_ source: String) -> String {
        var value = source.lowercased()
        for prefix in ["native:", "codexbar:"] where value.hasPrefix(prefix) { value = String(value.dropFirst(prefix.count)) }
        switch value { case "openai": return "codex"; case "claude-code": return "claude"; default: return value }
    }
    /// Join each actual rendered AX row to its own reported account window locators.
    /// The report carries no account/subscription identifiers and never infers membership.
    public var journeyRows: [[String: Any]] {
        guard CommunityJourneyCI.enabled, let model else { return [] }
        let nodes = (dockView.accessibilityChildren() ?? []).compactMap { $0 as? NSAccessibilityElement }
        return Array(model.inputs.enumerated().compactMap { index, input -> [String: Any]? in
            guard let node = nodes.first(where: { $0.accessibilityIdentifier() == "dock.subscription." + input.id }) else { return nil }
            let sources = (snapshot?.personal.accounts ?? []).enumerated().compactMap { accountIndex, account -> String? in
                input.windows.contains { $0.id.hasPrefix("account.\(accountIndex).window.") } ? account.source : nil
            }
            let codex = sources.contains { ["codex", "openai"].contains($0.lowercased()) }
            var providers = Set(sources.map(journeyProvider))
            for account in snapshot?.personal.accounts ?? [] where account.subscription?.subscriptionRef == input.id {
                providers.insert(journeyProvider(account.source))
            }
            if providers.isEmpty {
                for tool in SettingsConnectionTool.allCases where input.name == tool.title {
                    providers.insert(tool.rawValue)
                }
            }
            let readout = node.accessibilityValue() as? String ?? ""
            let percent = readout.hasSuffix("%") ? Double(readout.dropLast()) : nil
            let reason = model.presentationRows[input.id]
            return ["rowIndex": index, "provider": codex || input.name == "Codex" ? "codex" : "other",
                    "providers": providers.sorted(), "dataState": String(describing: input.dataState),
                    "accountAssociated": codex, "hasSubscription": model.subscriptions.contains { $0.id == input.id },
                    "readout": readout, "remainingPercent": percent.map { $0 as Any } ?? NSNull(),
                    "reason": reason?.reason ?? "", "nextStep": reason?.nextStep ?? ""]
        }.prefix(16))
    }
    /// Fixed aggregate facts from the same CLI feed; never returns raw reader output.
    public var journeyGrokFirstFailure: [String: Any] {
        guard CommunityJourneyCI.enabled, let personal = snapshot?.personal else { return [:] }
        return ["nativeErrorObserved": personal.sources?.contains {
                    $0.source == "native:grok" && ["error", "unavailable"].contains($0.status) && $0.reason == "parse_error"
                } == true,
                "accountCount": (personal.accounts ?? []).filter { journeyProvider($0.source) == "grok" }.count,
                "connectionCount": (personal.connections ?? []).filter { journeyProvider($0.id) == "grok" }.count]
    }
    /// Read the age label mounted by the actual card factory, including absence as an empty string.
    public var journeyCardAge: String? {
        guard CommunityJourneyCI.enabled, !card.isHidden else { return nil }
        func find(_ view: NSView) -> NSTextField? {
            if let field = view as? NSTextField, field.accessibilityIdentifier() == "dock.card.text.source" { return field }
            return view.subviews.lazy.compactMap(find).first
        }
        return find(card)?.stringValue ?? ""
    }
    public func journeyDismissCard() {
        guard CommunityJourneyCI.enabled else { return }
        card.onDismiss?()
    }
    /// Drive the real hover reducer and host presentation callback, never the row activation route.
    public func journeyOpenCard(at index: Int) -> Bool {
        guard CommunityJourneyCI.enabled,permitted,!retired,!rendering,preferences.showDock,
              let model,model.inputs.indices.contains(index),
              journeyRows.contains(where:{$0["rowIndex"] as? Int == index}) else{return false}
        let id=model.inputs[index].id
        if interactionController == nil {
            // The legacy journey host has no app interaction owner. Supply explicit
            // synthetic hover input, like the card-content harness, to the same reducer.
            let controller=DockInteractionController(clock:{0},scheduler:JourneyCardScheduler()) { [weak self] in
                guard let self,let model=self.model else{return .init(catalogue:[],preferences:.init(),targets:[],active:false)}
                let content=self.journeyHoverID.flatMap{try? self.cardContent(for:$0)}
                let contents=content.map{[$0.subscriptionID:$0]} ?? [:]
                return .init(catalogue:model.inputs.map(\.id),preferences:.init(),targets:[],hoveredID:self.journeyHoverID,
                    insideShared:true,parentExpanded:true,active:self.permitted && !self.retired && !self.rendering && self.preferences.showDock,contents:contents)
            }
            installInteraction(controller);journeyOwnsCardController=true;controller.start()
        }
        guard let controller=interactionController,controller.isRunning else{return false}
        if journeyOwnsCardController {
            journeyHoverID=nil;controller.refresh();journeyHoverID=id;controller.refresh()
        } else {
            guard let events=interactionView.nozzleEventDelegate else{return false}
            events.hoverNozzle(nil);events.hoverNozzle(id)
        }
        guard controller.advanceJourneyHoverDwell(for:id) else{return false}
        return !card.isHidden && cardID == id
    }
    /// The user's route from an open card to Settings: the card's enter button where the card has
    /// one, otherwise (production, D37) the widget menu's Settings… item.
    public func journeyPressCardEnter() -> Bool {
        guard CommunityJourneyCI.enabled, !card.isHidden else { return false }
        func find(_ view: NSView) -> NSButton? {
            if let button = view as? NSButton, button.accessibilityIdentifier() == "dock.card.enter" { return button }
            return view.subviews.lazy.compactMap(find).first
        }
        if let button = find(card) {
            guard button.isEnabled else { return false }
            button.performClick(nil)
            return true
        }
        let title = EngineRowsText.settings.value(preferences.language)
        guard let item = menu().items.first(where: { $0.title == title }), item.isEnabled,
              let action = item.action, let target = item.target as? NSObject else { return false }
        _ = target.perform(action, with: item)
        return true
    }
    #endif
    private var preferences = SettingsPreferences()
    private var effectiveRedBelow: Double { Double(application?.effective.redBelow ?? SettingsPreferences().redBelow) }
    private var memberSafePreferences: SettingsPreferences {
        preferences.withoutUnstableMemberChoices(model?.subscriptions ?? [])
    }
    private var catalogueKey = ""
    private var geometry = StaticDockGeometry(hoverRects: [])
    /// Internal-only registration read used by synthetic offscreen evidence.
    @_spi(DockResourceChecks) public var registeredConsoleButtonForChecks: CGRect? { geometry.consoleButton }
    /// Synthetic offscreen captures may select a deterministic backing scale.
    @_spi(DockResourceChecks) public var captureBackingScaleForChecks: Int?
    private var permitted = false, retired = false, retiring = false, rendering = false
    private weak var trackedDockMenu: NSMenu?
    private var dockMenuGeneration: UInt64 = 0
    private var menuOpen: Bool { trackedDockMenu != nil }
    /// MENU-12: an actually open menu protects the widget; the flag is also cleared by AppKit's own
    /// end-of-tracking notice, so a missed close callback never keeps the widget from collapsing.
    var menuOpenForChecks: Bool { menuOpen }
    private var menuEndObserver: NSObjectProtocol?
    private var lifecycleSuspended = false
    private var sliverPrepared = false
    private var preparedSliverGeometrySize: CGSize?
    private var rebuildPending = false
    private var inputGeneration: UInt64 = 0, cardGeneration: UInt64 = 0
    private var panel: NSPanel?, cardPanel: NSPanel?
    private var lastDisplayChoices: [SettingsDisplayChoice] = []
    private var edgeGeometries: [DockEdge: StaticDockGeometry] = [:]
    private var edgeViews: [DockEdge: DockInstrumentView] = [:]
    private let alternateViews = [DockInstrumentView(frame: .zero), DockInstrumentView(frame: .zero), DockInstrumentView(frame: .zero)]
    func ownsDockMenu(_ menu: NSMenu) -> Bool {
        if menu.delegate === self { return true }
        return (menu.delegate as? DockSliverMenu)?.owner === self
    }
    private var appearanceDisplay: DockDisplayArea?
    private var cardID: String?
    private var cardPresentedRevision: UInt64?, cardPresentedGeneration: UInt64?
    private var fallbackCardLeaveTask: Task<Void, Never>?
    private var interactionController: DockInteractionController?
    var interactionBindingInstalled: Bool { interactionController != nil }
    var interactionControllerRunning: Bool { interactionController?.isRunning ?? false }
    /// Read-only access for driving the existing controller with an injected clock.
    var interactionControllerForChecks: DockInteractionController? { interactionController }
    private var interactionEvents: [DockNozzleEvents] = []
    private var interactionHoverRevision: UInt64 = 0
    private var interactionHoveredID: String?
    private var interactionPreviewOrder: [String]?
    private var interactionOriginalActions: [(DockInstrumentView, ((DockInstrumentAction) -> Void)?, Bool)] = []
    private let overflowTray = DockOverflowTrayView(frame: .zero)
    var detachedOverflowForChecks: DockOverflowTrayView? { createsNativePanels ? nil : overflowTray }
    private let overflowScroll = NSScrollView(frame: .zero)
    private var overflowPanel: NSPanel?
    private var interactionView: DockInstrumentView {
        let orientation = edge.presentation?.placement?.edge ?? nativeEdge(preferences.dockEdge)
        return edgeViews[orientation] ?? dockView
    }

    private var cardHasKeyboardFocus: Bool {
        guard permitted, !retired, !card.isHidden, let id = cardID,
              let revision = cardPresentedRevision, let generation = cardPresentedGeneration,
              let panel = cardPanel, panel.isVisible, let focus = panel.firstResponder as? NSView else { return false }
        let control = focus as? NSControl
        let current = generation == inputGeneration && revision == application?.snapshot.revision &&
            model?.inputs.contains(where: { $0.id == id }) == true &&
            (try? memberSafePreferences.presentedSubscriptionIDs(model?.inputs.map(\.id) ?? []))?.contains(id) == true
        return DockCardFocus.protectsCard(isKeyWindow: panel.isKeyWindow,
            isDescendant: focus !== card && focus.isDescendant(of: card),
            isFocusableControl: control?.isEnabled == true && focus.acceptsFirstResponder, isCurrent: current)
    }
    @objc private func cardKeyStateChanged(_ notification: Notification) { refreshCardFocusSoon() }
    private func refreshCardFocusSoon() {
        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, self.permitted, !self.retired else { return }
            self.edge.refresh(); self.interactionController?.refresh()
        }
    }

    /// Row tracking geometry is authoritative when painted hover regions drift during a rebuild.
    static func cardPointerEvidence(sampled: Bool?, pointer: CGPoint?, trackedRow: CGRect?) -> Bool? {
        guard let pointer, pointer.x.isFinite, pointer.y.isFinite else { return nil }
        if let trackedRow, !trackedRow.isEmpty, trackedRow.contains(pointer) { return true }
        return sampled
    }

    /// Catalogue keys and preferences come from the accepted content transaction.
    /// bindingRevision is the host's input generation; card revisions remain the
    /// canonical Settings revision used by their action-validation boundary.
    public func interactionEnvironment() -> DockInteractionEnvironment {
        let env = environment(), place = edge.presentation?.placement
        let orientation = place?.edge ?? nativeEdge(preferences.dockEdge)
        let view = interactionView
        let catalogue = model?.inputs.map(\.id) ?? []
        let expanded = edge.presentation?.state == .expanded
        let active = permitted && !retired && !rendering && preferences.showDock &&
            env.presence.cockpitClosed && appearance != nil && view.interactionProjectionAvailable && model != nil
        var inside: Bool?
        if let place, let pointer = env.pointer,
           let display = env.displays.first(where: { $0.id == place.displayID }) {
            var painted = place.globalHoverRects
            if overflowPanel?.isVisible == true, let frame = overflowPanel?.frame { painted.append(frame) }
            let region = DockPresenceArea(painted: painted, wake: place.wakeFrame, card: env.cardFrame,
                display: display.usableFrame, edge: orientation,
                outerEdge: DockEdgeGeometry.canWake(at: pointer, placement: place, displays: env.displays))
                .region(at: pointer, policy: visibilityPolicy)
            switch region { case .inside, .wake: inside = true; case .outside: inside = false; default: inside = nil }
            var trackedFrame: CGRect?
            if let id = interactionHoveredID, let anchor = view.interactionAnchor(id) {
                if let window = view.window {
                    trackedFrame = window.convertToScreen(view.convert(anchor, to: nil))
                } else if expanded, view.bounds.size == place.frame.size {
                    // Detached synthetic hosts use the same registered local geometry.
                    trackedFrame = CGRect(x: place.frame.minX + anchor.minX - view.bounds.minX,
                        y: place.frame.maxY - anchor.maxY + view.bounds.minY, width: anchor.width, height: anchor.height)
                }
            }
            inside = Self.cardPointerEvidence(sampled: inside, pointer: pointer, trackedRow: trackedFrame)
        }
        let focusedID = view.keyboardTargetID.flatMap { catalogue.contains($0) ? $0 : nil }
        if cardHasKeyboardFocus || focusedID != nil { inside = true }
        let safePreferences = memberSafePreferences
        let visible = Set((try? safePreferences.presentedSubscriptionIDs(catalogue)) ?? [])
        var contents: [String: DockCardContent] = [:]
        for id in catalogue where visible.contains(id) { contents[id] = interactionCardContent(id) }
        return DockInteractionEnvironment(catalogue: catalogue, preferences: safePreferences.subscriptions,
            targets: view.interactionTargets(edge: orientation), overflowIDs: view.interactionOverflowIDs,
            bindingRevision: inputGeneration, hoverEventRevision: interactionHoverRevision, hoveredID: focusedID ?? interactionHoveredID, insideShared: inside,
            parentOwnsHide: true, parentExpanded: expanded && active, menuActuallyOpen: menuOpen,
            active: active, reducedMotion: application?.effective.reduceMotion ?? true, edge: orientation, contents: contents)
    }

    private func updateNozzleMagnification() {
        let displayed = interactionView
        let views = [dockView] + alternateViews
        // R64 D-2: poses ease over 0.12 s unless Reduce Motion is on (then magnification is off too).
        for view in views { view.animatesPoses = application?.effective.reduceMotion == false }
        for view in views where view !== displayed { view.setNozzlePoses([:]) }
        guard permitted, !retired, edge.presentation?.state == .expanded, !edge.isBackgroundPressed,
              interactionController?.presentation?.reorder == nil, preferences.magnification != .none,
              application?.effective.reduceMotion == false, let id = interactionHoveredID,
              let hovered = displayed.interactionAnchor(id) else { displayed.setNozzlePoses([:]); return }
        let stations = presentationGeometry.hoverStations
        let horizontal = edge.presentation?.placement?.edge.isHorizontal == true
        let diameter = preferences.size.nozzleDiameter
        var along = horizontal ? hovered.midX : hovered.midY
        if let window = displayed.window, let pointer = environment().pointer {
            let local = displayed.convert(window.convertPoint(fromScreen: pointer), from: nil)
            along = horizontal ? local.x : local.y
        }
        var poses = [String: DockNozzlePose]()
        for (member, station) in stations {
            let scale: CGFloat
            let offset: CGPoint
            switch preferences.magnification {
            case .none: continue
            case .subtle:
                // G3-29: like the prototype, the hovered ring grows outward (away from the screen
                // edge, along the station's inward normal), never toward the readout below it.
                guard member == id else { continue }
                let length = hypot(station.inward.dx, station.inward.dy)
                scale = 1.15
                offset = length > 0 ? CGPoint(x: 6 * station.inward.dx / length, y: 6 * station.inward.dy / length) : .zero
            case .strong:
                guard station.pitch > 0, let anchor = displayed.interactionAnchor(member) else { continue }
                let centre = horizontal ? anchor.midX : anchor.midY
                let influence = max(0, 1 - abs(along - centre) / (1.6 * station.pitch))
                guard influence > 0 else { continue }
                scale = (1000 * (1 + 0.5 * influence * influence * (3 - 2 * influence))).rounded() / 1000
                let shift = (scale - 1) * (diameter / 2 + 4)
                offset = CGPoint(x: station.inward.dx * shift, y: station.inward.dy * shift)
            }
            poses[member] = .init(scale: scale, offset: offset)
        }
        displayed.setNozzlePoses(poses)
    }

    @discardableResult func sweepRefresh(_ id: String) -> Bool {
        guard permitted, !retired, preferences.showDock,
              model?.inputs.contains(where: { $0.id == id }) == true else { return false }
        return interactionView.playRefreshSweep(id, reduceMotion: application?.effective.reduceMotion ?? true)
    }

    public func installInteraction(_ controller: DockInteractionController) {
        guard !retired, interactionController !== controller else { return }
        if let previous = interactionController { uninstallInteraction(previous) }
        interactionController = controller
        controller.onOrderAnnouncement = { [weak self] id, position, count in
            guard let self, let item = self.model?.inputs.first(where: { $0.id == id }) else { return }
            let name = self.memberSafePreferences.applying(to: item).alias ?? item.name
            let message = self.preferences.language == .english
                ? "\(name), position \(position + 1) of \(count)"
                : "\(name)，第 \(position + 1) 项，共 \(count) 项"
            let view = self.interactionView
            view.setAccessibilityValue(message)
            if self.createsNativePanels {
                NSAccessibility.post(element: view, notification: .announcementRequested,
                    userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.medium.rawValue])
            }
        }
        #if DEBUG && MODELPLAN_E2E_JOURNEY
        journeyOwnsCardController=false;journeyHoverID=nil
        #endif
        controller.onPresent = { [weak self, weak controller] value in
            guard let self, let controller, self.interactionController === controller, !self.retired else { return }
            self.renderInteraction(value)
        }
        for view in [dockView] + alternateViews {
            interactionOriginalActions.append((view, view.onAction, view.keyboardNavigationEnabled))
            let events = DockNozzleEvents(controller: controller, edge: { [weak self] in
                guard let self else { return .right }
                return self.edge.presentation?.placement?.edge ?? self.nativeEdge(self.preferences.dockEdge)
            })
            events.onHover = { [weak self, weak view] id in
                guard let self, let view, self.interactionView === view else { return }
                self.interactionHoverRevision &+= 1
                self.interactionHoveredID = id
                self.updateNozzleMagnification()
            }
            events.insideMainDrop = { [weak self, weak view] point in
                guard let self, let view, self.interactionView === view, let window = view.window,
                      self.interactionEnvironment().active else { return false }
                return view.isPainted(atLocal: view.convert(window.convertPoint(fromScreen: point), from: nil))
            }
            interactionEvents.append(events)
        }
        overflowTray.onClick = { [weak controller] id in controller?.click(id) }
        overflowTray.onHover = { [weak self, weak controller] id in
            self?.interactionHoverRevision &+= 1
            self?.interactionHoveredID = id; controller?.refresh()
        }
        overflowTray.onOptionMove = { [weak controller] id, delta in controller?.moveByKeyboard(id: id, delta: delta) }
        overflowTray.permitsAction = { [weak self] id, source in
            guard let self, self.interactionEnvironment().overflowIDs.contains(id) else { return false }
            return self.acceptsInstrumentAction(from: self.interactionView, source: source)
        }
        // The consumer owns start/stop and onOrderRequest. Installing the port
        // never starts a timer, commits preferences or replaces that callback.
        bindInteractionInput()
    }

    private func bindInteractionInput() {
        guard interactionController != nil else { return }
        let active = interactionEnvironment().active
        for (index, original) in interactionOriginalActions.enumerated() where index < interactionEvents.count {
            let (view, action, keyboard) = original
            let events = interactionEvents[index]
            if active && view.interactionProjectionAvailable {
                events.install(on: view); view.keyboardNavigationEnabled = true
            } else if view.nozzleEventDelegate === events {
                view.nozzleEventDelegate = nil; view.onAction = action; view.keyboardNavigationEnabled = keyboard
            }
        }
    }

    public func uninstallInteraction(_ controller: DockInteractionController) {
        guard interactionController === controller else { return }
        controller.onPresent = nil
        controller.onOrderAnnouncement = nil
        for (index, original) in interactionOriginalActions.enumerated() {
            let (view, action, keyboard) = original
            if index < interactionEvents.count, view.nozzleEventDelegate === interactionEvents[index] {
                view.nozzleEventDelegate = nil; view.onAction = action; view.keyboardNavigationEnabled = keyboard
            }
        }
        interactionEvents.forEach { $0.cancelNozzle() }
        interactionEvents = []; interactionOriginalActions = []
        interactionController = nil; interactionHoveredID = nil; interactionPreviewOrder = nil
        #if DEBUG && MODELPLAN_E2E_JOURNEY
        journeyOwnsCardController=false;journeyHoverID=nil
        #endif
        dismissCard(); overflowTray.dispose(); overflowPanel?.orderOut(nil)
        if !retired { rebuild() }
    }

    private func renderInteraction(_ value: DockInteractionPresentation) {
        defer { publishDockHelpInteraction() }
        guard permitted, !retired else { dismissCard(); overflowPanel?.orderOut(nil); return }
        let preview = value.reorder?.order
        if preview != interactionPreviewOrder { interactionPreviewOrder = preview; rebuild() }
        updateNozzleMagnification()
        if let id = value.card.subscriptionID, let content = value.content {
            showCard(id, supplied: content)
        } else {
            dismissCard()
        }
        guard !value.overflowIDs.isEmpty, let model else {
            // Retire the rows, keeping their host bindings for the next open.
            try? overflowTray.apply([])
            overflowPanel?.orderOut(nil)
            return
        }
        let rows = Dictionary(uniqueKeysWithValues: model.inputs.map { ($0.id, $0) })
        let entries = value.overflowIDs.compactMap { id -> DockOverflowEntry? in
            guard let input = rows[id], let reading = try? DockInstrumentProjection.evaluate(memberSafePreferences.applying(to: input), now: currentDate(), redBelow: effectiveRedBelow) else { return nil }
            let help = preferences.language == .english ? "Use Option-arrow keys to reorder this subscription." : "使用 ⌥ 方向键调整此订阅的顺序。"
            return DockOverflowEntry(id: id, label: reading.alias ?? reading.name, value: reading.readout, dragHelp: help)
        }
        do { try overflowTray.apply(entries) } catch { overflowPanel?.orderOut(nil); return }
        overflowTray.edge = nativeEdge(preferences.dockEdge); overflowTray.keyboardNavigationEnabled = true
        guard createsNativePanels, let anchor = panel?.frame,
              let screen = topology(of: sampleEnvironment()).display(edge.presentation?.placement?.displayID) else { return }
        if overflowPanel == nil { overflowPanel = makePanel() }
        guard let overflowPanel else { return }
        let safe = screen.visibleFrame
        let size = CGSize(width: min(200, safe.width), height: min(max(40, overflowTray.frame.height), safe.height))
        overflowScroll.frame = CGRect(origin: .zero, size: size); overflowScroll.documentView = overflowTray
        overflowScroll.hasVerticalScroller = true; overflowScroll.drawsBackground = true
        overflowScroll.appearance = NSAppearance(named: (application?.effective.darkAppearance ?? true) ? .darkAqua : .aqua)
        let x = preferences.dockEdge == .left ? anchor.maxX + 12 : anchor.minX - size.width - 12
        let y = preferences.dockEdge == .bottom ? anchor.maxY + 12 : preferences.dockEdge == .top ? anchor.minY - size.height - 12 : anchor.midY - size.height / 2
        overflowPanel.contentView = overflowScroll
        overflowPanel.setFrame(CGRect(x: max(safe.minX, min(x, safe.maxX - size.width)),
            y: max(safe.minY, min(y, safe.maxY - size.height)), width: size.width, height: size.height), display: true)
        overflowPanel.orderFrontRegardless()
    }
    /// G3-31 / G3-05 (R64 D-3, D-4): the accepted r7 card, from the official visuals package
    /// (QuotaWidgetCardGeometry measurements, QuotaWidgetCardMaterial values); no new art.
    static var prototypeCardStyle: DockCardStyle {
        typealias M = QuotaWidgetCardMaterial
        func colour(_ c: M.RGBA) -> NSColor { NSColor(srgbRed: c.red, green: c.green, blue: c.blue, alpha: c.alpha) }
        var style = DockCardStyle()
        style.width = QuotaWidgetCardGeometry.plateWidth
        style.padding = QuotaWidgetCardGeometry.plateHorizontalPadding
        style.verticalPadding = QuotaWidgetCardGeometry.plateVerticalPadding
        style.plateRadius = QuotaWidgetCardGeometry.plateRadius
        style.brandSize = QuotaWidgetCardGeometry.headingIconSize
        style.headerGap = QuotaWidgetCardGeometry.headingGap
        style.headerBottomGap = QuotaWidgetCardGeometry.headingBottomGap
        style.windowRadius = QuotaWidgetCardGeometry.lcdRadius
        style.windowPadding = NSEdgeInsets(top: QuotaWidgetCardGeometry.lcdVerticalPadding, left: QuotaWidgetCardGeometry.lcdHorizontalPadding,
                                           bottom: QuotaWidgetCardGeometry.lcdVerticalPadding, right: QuotaWidgetCardGeometry.lcdHorizontalPadding)
        style.columns = QuotaWidgetCardGeometry.rowFixedColumns
        style.columnGap = QuotaWidgetCardGeometry.rowColumnGap
        style.rowMinimumHeight = QuotaWidgetCardGeometry.rowMinimumHeight
        style.barSize = CGSize(width: QuotaWidgetCardGeometry.rowFixedColumns[1], height: QuotaWidgetCardGeometry.barHeight)
        style.barGap = QuotaWidgetCardGeometry.barSegmentGap
        style.nameFontSize = M.nameFontSize; style.smallFontSize = M.smallFontSize; style.readoutSize = M.valueFontSize
        style.background = colour(M.plate); style.seam = colour(M.seam)
        style.window = colour(M.window); style.windowSeam = colour(M.windowSeam)
        style.ink = colour(M.ink); style.muted = colour(M.muted); style.track = colour(M.ghost)
        style.quota = [.normal: colour(M.normal), .warning: colour(M.warning), .critical: colour(M.critical), .unknown: colour(M.muted)]
        style.notice = colour(M.notice)
        style.readoutFont = cardReadoutFont(size: M.valueFontSize); style.readoutSmallFont = cardReadoutFont(size: M.smallFontSize)
        return style
    }
    /// The bundled LCD face (JetBrains Mono, the dock readout font); nil falls back to the system mono.
    private static var cardFonts: [CGFloat: NSFont] = [:]
    private static func cardReadoutFont(size: CGFloat) -> NSFont? {
        if let font = cardFonts[size] { return font }
        guard let store = cardResourceStore(zaiMarkEnabled: false),
              let font = try? store.font(QuotaWidgetCardMaterial.readoutFontResource, size: size) else { return nil }
        let value = font as NSFont
        cardFonts[size] = value
        return value
    }
    private static var cardStores: [Bool: DockArtworkStore] = [:]
    private static func cardResourceStore(zaiMarkEnabled: Bool) -> DockArtworkStore? {
        if let store = cardStores[zaiMarkEnabled] { return store }
        guard let data = try? DockThirdPartyResources.manifestData(zaiMarkEnabled: zaiMarkEnabled),
              let manifest = try? JSONDecoder().decode(DockResourceManifest.self, from: data),
              let root = try? DockThirdPartyResources.rootURL(),
              let store = try? DockArtworkStore(root: root, manifest: manifest) else { return nil }
        cardStores[zaiMarkEnabled] = store
        return store
    }
    /// The card header's vendor mark: the same checked mark the ring shows (no new art).
    private func cardBrandImage(_ id: String) -> NSImage? {
        let view = interactionView
        guard let key = view.presentedReadingsForChecks[id]?.vendorResourceKey,
              let resource = view.presentedSkinForChecks?.stations.first(where: { $0.subscriptionID == id })?.glyphs[key],
              let store = Self.cardResourceStore(zaiMarkEnabled: view.zaiMarkEnabled),
              let image = try? store.image(resource, maximumPixelSize: 64) else { return nil }
        let size = QuotaWidgetCardGeometry.headingIconSize
        return NSImage(cgImage: image, size: NSSize(width: size, height: size))
    }
    public let dockView = DockInstrumentView(frame: .zero)
    private let sliver = DockSliverView(frame: .zero)
    private let empty = StaticDockStatusLabel(wrappingLabelWithString: "")
    let card = DockCardView(frame: .zero)
    private let cardChrome = NSView(frame: .zero), cardArrow = HostCardArrowView(frame: .zero)
    /// The card's pointer arrow polygon in screen coordinates while a native card panel is shown.
    var cardArrowForChecks: [CGPoint]? {
        guard let window = cardArrow.window, !cardArrow.isHidden, cardArrow.points.count == 3 else { return nil }
        return cardArrow.points.map { window.convertPoint(toScreen: cardArrow.convert($0, to: nil)) }
    }
    private let container = StaticDockContainer()
    /// R64 D-9: the surface state last put on screen, so a sliver <-> expanded change can animate.
    private var presentedSurfaceState: DockSurfaceState?
    private let collapseGhost = DockCollapseGhost()
    private let snapPreview = DockSnapPreview()
    var snapPreviewFrameForChecks: CGRect? { snapPreview.frameForChecks }
    var collapseAnimatingForChecks: Bool { collapseGhost.animatingForChecks }
    private(set) var revealAnimationsForChecks = 0
    var containerAnimationsForChecks: [String: CAAnimation] {
        guard let layer = container.layer else { return [:] }
        return Dictionary(uniqueKeysWithValues: (layer.animationKeys() ?? []).compactMap { key in layer.animation(forKey: key).map { (key, $0) } })
    }
    private let consoleButton = DockIgnitionButton(frame: .zero)
    private lazy var edge = makeEdge(policy: visibilityPolicy)

    public convenience init(appearance: Appearance? = nil, sliverParameters: DockSliverParameters = .current, readerCapabilities: CommunityReaderCapabilities = .init(), currentDate: @escaping @MainActor () -> Date = { Date() },
                            contentProvider: (any DockContentProvider)? = nil) {
        self.init(appearance: appearance, currentDate: currentDate, createsNativePanels: true, sliverParameters: sliverParameters, readerCapabilities: readerCapabilities, contentProvider: contentProvider)
    }
    public convenience init(purpose: DockHostPurpose, appearance: Appearance? = nil,
                            sliverParameters: DockSliverParameters = .current,
                            readerCapabilities: CommunityReaderCapabilities = .init(),
                            currentDate: @escaping @MainActor () -> Date = { Date() },
                            contentProvider: (any DockContentProvider)? = nil) {
        self.init(appearance: appearance, currentDate: currentDate, createsNativePanels: true,
                  sliverParameters: sliverParameters, readerCapabilities: readerCapabilities, purpose: purpose, contentProvider: contentProvider)
    }
    /// In-memory publication seam for the same host callbacks; no NSWindow is created in checks.
    init(appearance: Appearance? = nil, currentDate: @escaping @MainActor () -> Date, createsNativePanels: Bool,
         prepareDetachedAlternateAppearances: Bool = false, sliverParameters: DockSliverParameters = .current, nativeEnvironment: (@MainActor () -> DockEdgeEnvironment)? = nil,
         elapsedClock: (() -> TimeInterval)? = nil, edgeScheduling: (any DockEdgeScheduling)? = nil,
         readerCapabilities: CommunityReaderCapabilities = .init(), purpose: DockHostPurpose = .selfTest,
         contentProvider: (any DockContentProvider)? = nil, pointerSampleSource: (() -> CGPoint?)? = nil) {
        self.pointerSampleSource = pointerSampleSource
        self.contentProvider = contentProvider ?? LegacyDockContentProvider()
        self.purpose = purpose
        self.readerCapabilities = readerCapabilities
        self.nativeEnvironment = nativeEnvironment; self.elapsedClock = elapsedClock; self.edgeScheduling = edgeScheduling
        self.sliverParameters = sliverParameters
        self.appearance = appearance; self.currentDate = currentDate; self.createsNativePanels = createsNativePanels
        self.prepareDetachedAlternateAppearances = prepareDetachedAlternateAppearances
        super.init()
        consoleButton.title = ""; consoleButton.isBordered = false; consoleButton.isTransparent = true
        consoleButton.target = self; consoleButton.action = #selector(openConsole)
        consoleButton.setAccessibilityIdentifier("dock.ignition")
        consoleButton.onHelpFocusChanged = { [weak self] in self?.publishDockHelpInteraction() }
        consoleButton.setAccessibilityLabel(EngineRowsText.openCockpit.value(preferences.language))
        // G3-23: the ignition cap shows the official red art at full strength, as in the prototype.
        // A disabled cockpit entry only disables the button; no dark veil is painted over it.
        container.addSubview(dockView); container.addSubview(consoleButton)
        bindEmptyStation(to: dockView)
        dockView.onAction = { [weak self] action in
            guard let self, self.permitted, !self.retired, !self.rendering else { return }
            switch action {
            case .subscription, .notice: break // Refresh is bound only after scope and floor admission.
            case .overflow: self.openConsole()
            }
        }
        dockView.permitsAction = { [weak self] _, source in
            guard let self else { return false }
            return self.acceptsInstrumentAction(from: self.dockView, source: source)
        }
        dockView.onEscape = { [weak self] in self?.closeHeldCard() ?? false }
        sliver.onReveal = { [weak self] in self?.edge.reveal() }
        connectEdge()
        let refresh: () -> Void = { [weak self] in
            guard let self, self.permitted, !self.retired else { return }
            self.inputGeneration &+= 1
            self.rebuild()
        }
        dockView.onNeedsFreshPresentation = refresh
        sliver.onNeedsFreshPresentation = refresh
        card.isHidden = true
        NotificationCenter.default.addObserver(self, selector: #selector(displaysChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }
    private func bindEmptyStation(to view: DockInstrumentView) {
        view.onHelpFocusChanged = { [weak self] in self?.publishDockHelpInteraction() }
        // G3-10: the grip, ignition and event dot raise no other host event on hover.
        view.onHelpPointerMoved = { [weak self, weak view] in
            guard let self, let view, self.interactionView === view else { return }
            self.publishDockHelpInteraction()
        }
        view.onEmptyAction = { [weak self, weak view] in
            guard let self, let view, self.permitted, !self.retired, !self.rendering,
                  view.emptyStationRectForChecks != nil, let showSettings = self.showSettings else { return false }
            showSettings(); return true
        }
        view.permitsEmptyAction = { [weak self, weak view] source in
            guard let self, let view else { return false }
            return self.acceptsInstrumentAction(from: view, source: source)
        }
    }
    private func connectEdge() {
        edge.onPresent = { [weak self] value in self?.present(value) }
        edge.prepareDragDisplay = { [weak self] display in
            // Also prepare the top-edge artwork once per carry on the same display (lazy, G3-27).
            guard let self, self.appearanceDisplay != display || self.edgeViews[.top] == nil, !self.rendering else { return }
            self.rendering = true
            defer { self.rendering = false }
            self.rebuildPass(self.inputGeneration, carriedTo: display)
        }
        edge.onDragCancelled = { [weak self] in self?.rebuild() }
        edge.onCommittedPlacement = { [weak self] value in
            guard let self, let next = SettingsDockEdge(rawValue: String(describing: value.edge)) else { return }
            if let id = value.displayID, let commit = self.commitDisplayPlacement {
                if self.preferences.followActiveDisplay { self.followedDisplayID = id }
                commit(id, next, value.alongFraction)
            } else {
                self.commitPlacement?(next, value.alongFraction)
            }
        }
    }
    public func apply(_ value: SettingsApplication) {
        guard !retired, value.snapshot.revision >= (application?.snapshot.revision ?? 0) else { return }
        inputGeneration &+= 1
        application = value
        let oldReveal = preferences.revealMilliseconds
        preferences = value.snapshot.preferences
        if value.effective.reduceMotion { locateLayer?.removeAnimation(forKey: "locate-pulse") }
        empty.stringValue = preferences.language == .english ? "No local subscriptions" : "暂无本地订阅"
        consoleButton.setAccessibilityLabel(EngineRowsText.openCockpit.value(preferences.language))
        if !preferences.showDock { pendingUserReveal = false; clearLocateHighlight(); dismissCard() }
        if preferences.revealMilliseconds != oldReveal {
            let saved = edge.preference
            edge.stop(); edge.onPresent = nil; edge.onCommittedPlacement = nil
            edge = makeEdge(preference: saved, policy: visibilityPolicy)
            connectEdge()
        }
        rebuild()
        syncDisplayFollower()
        menuBarPreferencesChanged?()
    }
    private var dockConsent: ConsentPreview?
    public func updateDockConsent(_ preview: ConsentPreview?) {
        guard !retired else { return }
        inputGeneration &+= 1
        dockConsent = preview
        rebuild()
    }
    public enum WorkingInjectionError: Error { case invalidSignals }
    /// Replace an admitted per-member working snapshot; no activity is inferred.
    public func setWorkingSignals(_ values: [DockWorkingSignal]) throws {
        guard values.count <= 256 else { throw WorkingInjectionError.invalidSignals }
        var next = [String: DockWorkingSignal]()
        for value in values {
            guard let id = value.subscriptionID, !id.isEmpty, next[id] == nil else { throw WorkingInjectionError.invalidSignals }
            next[id] = value
        }
        guard !retired else { return }
        workingSignals = next; inputGeneration &+= 1; rebuild()
    }
    /// The composition owner supplies the one shared pool and approved frame source.
    public func installWorkingEffects(pool: EffectResourcePool, provider: any EffectFrameProvider) {
        installWorkingEffects(pool: pool, provider: provider, systemReduceMotion: { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion })
    }
    @_spi(DockResourceChecks) public func installWorkingEffectsForChecks(pool: EffectResourcePool, provider: any EffectFrameProvider,
                                                                          systemReduceMotion: @escaping () -> Bool) {
        installWorkingEffects(pool: pool, provider: provider, systemReduceMotion: systemReduceMotion)
    }
    private func installWorkingEffects(pool: EffectResourcePool, provider: any EffectFrameProvider, systemReduceMotion: @escaping () -> Bool) {
        guard !retired else { return }
        workingInstallationError = nil
        workingDriver?.stop(); workingDriver = DockWorkingEffects(pool: pool, systemReduceMotion: systemReduceMotion)
        workingFrameProvider = provider; inputGeneration &+= 1; rebuild()
    }
    func recordWorkingEffectFailure(_ error: Error) { workingInstallationError = error; lastWorkingEffectError = error }
    public func uninstallWorkingEffects() {
        workingDriver?.stop(); workingDriver = nil; workingFrameProvider = nil; lastWorkingEffectError = nil
    }

    /// Synchronously retire cached values and accessibility nodes before replacement.
    /// Reset notice acknowledgements only on a privacy withdrawal, not on a timer tick.
    @discardableResult
    func withdrawAdmittedContent(privacy: Bool, keepingCardFor members: Set<String> = []) -> Bool {
        guard !retired else { return false }
        let keepCard = !privacy && cardPresentedGeneration != nil && (cardID.map(members.contains) ?? false)
        if keepCard {
            // Leave only an empty shell during the synchronous replacement.
            // Its old labels, AX nodes and action generation retire before recompute.
            cardPresentedGeneration = nil
            card.dispose()
        } else {
            dismissCard()
        }
        inputGeneration &+= 1
        model = nil; contentMenuStatusLines = []; contentEmptyText = nil
        workingSignals = [:]; attentionSignals = []
        if privacy { attention = DockAttentionState() }
        menuNotice = nil; menuNoticeDidChange?(nil, false)
        if !keepCard { catalogueKey = ""; catalogueChanged?([]) }
        try? overflowTray.apply([]); overflowPanel?.orderOut(nil)
        for view in [dockView] + alternateViews { view.retireOfficialPresentation() }
        sliver.noticeMarks = []
        try? sliver.apply(image: nil, logicalSize: .zero, scale: 1, accessibilityLabel: "")
        return keepCard
    }

    func finishCardReplacement() -> Bool {
        guard cardID != nil, cardPresentedGeneration == nil else { return false }
        dismissCard()
        return true
    }

    /// Installs the content consumer without replacing window/input ownership.
    public func setDockContentProvider(_ provider: any DockContentProvider) {
        guard !retired else { return }
        workingSignals = [:]
        contentProvider = provider
        refreshDockContent()
    }
    /// Called by the accepted engine-state consumer; adds no reader or timer.
    public func refreshDockContent() {
        guard !retired else { return }
        workingSignals = [:]
        inputGeneration &+= 1
        rebuild()
    }
    public func render(snapshot: JoinedSnapshot?, diagnostics: StoreDiagnostics) {
        guard !retired else { return }
        inputGeneration &+= 1
        workingSignals = [:]
        self.snapshot = snapshot; self.diagnostics = diagnostics
        rebuild()
    }
    func pauseForLifecycle() {
        lifecycleSuspended = true
        NotificationCenter.default.post(name: LivePrivateMenus.lifecyclePause, object: self)
        setPresentationAllowed(false)
    }
    func resumeFromLifecycle() { lifecycleSuspended = false }
    public func setPresentationAllowed(_ allowed: Bool) {
        guard !retired else { return }
        inputGeneration &+= 1
        permitted = allowed
        if allowed { rebuild(); edge.start() }
        else { retireTrackedDockMenu(); clearLocateHighlight(); workingDriver?.stop(); pointerSurface.stop(); displayFollower.stop(); followedDisplayID = nil; edge.stop(); dismissCard(); panel?.orderOut(nil) }
        bindInteractionInput(); interactionController?.refresh()
        syncDisplayFollower()
    }
    private func makeDisplayFollower() -> ActiveDisplayFollower {
        let follower = ActiveDisplayFollower(currentDisplayIdentifier: { [weak self] in
            guard let self, self.permitted, !self.retired, self.preferences.showDock,
                  self.preferences.followActiveDisplay else { return nil }
            let env = self.environment()
            guard let pointer = env.pointer else { return nil }
            return env.displays.first(where: { $0.frame.contains(pointer) })?.id
        })
        follower.onEnter = { [weak self] identifier in
            guard let self, self.permitted, !self.retired, !self.rendering,
                  !self.edge.isBackgroundPressed else { return false }
            guard self.followedDisplayID != identifier else { return true }
            self.followedDisplayID = identifier
            self.inputGeneration &+= 1
            self.rebuild()
            return true
        }
        return follower
    }
    private func syncDisplayFollower() {
        guard permitted, !retired, preferences.showDock, preferences.followActiveDisplay else {
            displayFollower.stop(); followedDisplayID = nil; return
        }
        displayFollower.start(); displayFollower.sample()
    }
    private func rebuild() {
        guard !retired, !retiring, application != nil else { return }
        rebuildPending = true
        guard !rendering, !edge.isBackgroundPressed, !edge.isPublishingRelease else { return }
        rendering = true
        defer { rendering = false; bindInteractionInput(); interactionController?.refresh() }
        while rebuildPending, !retired {
            rebuildPending = false
            rebuildPass(inputGeneration)
        }
    }
    private func passIsCurrent(_ generation: UInt64) -> Bool {
        guard !retired, !retiring else { dockView.dispose(); return false }
        guard inputGeneration == generation else { rebuildPending = true; return false }
        return true
    }
    private func rebuildPass(_ generation: UInt64, carriedTo: DockDisplayArea? = nil) {
        let displayFacts = sampleEnvironment()
        let topology = topology(of: displayFacts)
        let choices = topology.displays.map { SettingsDisplayChoice(id: $0.id, name: $0.name ?? $0.id) }
        if carriedTo == nil, choices != lastDisplayChoices { lastDisplayChoices = choices; displayChoicesChanged?(choices) }
        guard passIsCurrent(generation) else { return }
        let now = currentDate()
        let facts = CommunityReaderFactsBinding.make(snapshot: snapshot, diagnostics: diagnostics, capabilities: readerCapabilities)
        let content = contentProvider.makeContent(.init(snapshot: snapshot, diagnostics: diagnostics,
            now: now, readerFacts: facts, canonicalConsent: dockConsent))
        let next = content.snapshot
        let passPreferences = preferences.withoutUnstableMemberChoices(next.subscriptions)
        contentMenuStatusLines = content.menuStatusLines
        contentEmptyText = content.emptyText
        let key = next.subscriptions.map { "\($0.id)|\($0.name.english)|\($0.source)|\($0.isUnstable)" }.joined(separator: "\n")
        if carriedTo == nil, key != catalogueKey { catalogueKey = key; catalogueChanged?(next.subscriptions) }
        guard passIsCurrent(generation) else { return }
        let byID = Dictionary(uniqueKeysWithValues: next.inputs.map { ($0.id, $0) })
        let canonicalOrder = (try? passPreferences.presentedSubscriptionIDs(next.inputs.map(\.id))) ?? next.inputs.map(\.id)
        let order = interactionPreviewOrder.flatMap { preview -> [String]? in
            let visible = preview.filter { canonicalOrder.contains($0) }
            return Set(visible) == Set(canonicalOrder) ? visible : nil
        } ?? canonicalOrder
        let rows = order.compactMap { byID[$0] }.compactMap { input -> DockInstrumentReading? in
            var value = passPreferences.applying(to: input)
            value.unavailableReason=next.presentationRows[input.id]?.reason
            if let signal = workingSignals[input.id] { value.working = signal }
            guard let reading = try? DockInstrumentProjection.evaluate(value, now: now, redBelow: effectiveRedBelow) else { return nil }
            if !createsNativePanels, let fixtureStatus = comparisonStatuses[input.id] { return reading.comparisonFixture(status: fixtureStatus) }
            return reading
        }
        dockView.requestedNozzleDiameter = passPreferences.size.nozzleDiameter
        alternateViews.forEach { $0.requestedNozzleDiameter = passPreferences.size.nozzleDiameter }
        let followed = topology.display(followedDisplayID) ?? displayFacts.pointer.flatMap { topology.containing($0) }
        let destination = passPreferences.followActiveDisplay ? followed?.id : passPreferences.dockDisplayID
        let display = carriedTo ?? PulseRestingPlacement.display(preference: .init(displayID: destination),
            displays: topology.displays, pointer: nil, primaryID: topology.primaryID)
        let backingScale = captureBackingScaleForChecks.flatMap { (1...2).contains($0) ? $0 : nil } ?? display?.backingScale ?? 1
        dockView.presentationBackingScale = backingScale
        alternateViews.forEach { $0.presentationBackingScale = backingScale }
        let admittedIDs = Set(rows.map(\.subscriptionID))
        let filteredSignals = content.signals.filter { admittedIDs.contains($0.id) }
        // Duplicate identities fail closed instead of arbitrarily choosing a source.
        attentionSignals = Set(filteredSignals.map(\.id)).count == filteredSignals.count ? filteredSignals : []
        _ = try? attention.project(attentionSignals, stationBySubscription: [:], at: now)
        let presentationNotices = Dictionary(uniqueKeysWithValues: attentionSignals.compactMap { signal in
            DockNoticeProjection.selected(for: signal, at: now).map { (signal.id, $0) }
        })
        for view in [dockView] + alternateViews {
            view.appearanceNotices = presentationNotices
            view.appearanceDisplaySize = display?.usableFrame.size
            view.appearanceMenuBarExclusion = display.map { max(0, $0.frame.maxY - $0.usableFrame.maxY) } ?? 0
        }
        var appearanceFallback = false
        lastAppearanceError = nil
        do {
            if let appearance {
                let candidate = try appearance(dockView, rows, passPreferences)
                guard passIsCurrent(generation) else { return }
                geometry = candidate
                geometry.scaleRegistration(by: dockView.appliedGeometryScale)
            }
            else {
                try dockView.applyCommunity(rows, locale: passPreferences.language.rawValue)
                geometry = .init(hoverRects: [dockView.bounds])
            }
        } catch {
            guard passIsCurrent(generation) else { return }
            appearanceFallback = appearance != nil
            if appearanceFallback {
                lastAppearanceError = error
                Logger(subsystem: "ai.modelplan.dock", category: "appearance").error("Official Dock appearance failed: \(String(describing: error), privacy: .private)")
            }
            try? dockView.applyCommunity(rows, locale: passPreferences.language.rawValue)
            geometry = .init(hoverRects: [dockView.bounds])
        }
        guard passIsCurrent(generation) else { return }
        lastWorkingEffectError = workingInstallationError
        if let driver = workingDriver, let provider = workingFrameProvider,
           permitted, preferences.showDock, !appearanceFallback,
           (!createsNativePanels || (dockView.window?.isVisible == true && dockView.window?.occlusionState.contains(.visible) == true)) {
            do {
                let profile = RenderProfile(dark: true, scale: backingScale, reduceMotion: application?.effective.reduceMotion ?? true)
                try driver.configure(view: dockView, readings: rows, profile: profile,
                                     rotation: DockEffectRotation(period: 1), provider: { _ in provider })
            } catch { driver.stop(); lastWorkingEffectError = error }
        } else { workingDriver?.stop() }
        publishAttention()
        model = next
        if appearanceFallback || (rows.isEmpty && appearance == nil) {
            let factor = passPreferences.size.nozzleDiameter / DockNozzleDiameters.current.medium
            dockView.setFrameSize(CGSize(width: 210 * factor, height: 60 * factor))
            empty.stringValue = appearanceFallback ? (passPreferences.language == .english ? "Quota Widget appearance unavailable" : "额度挂件外观暂不可用") : (contentEmptyText ?? CommunityReaderStatusPresentation.emptyText(next, english: passPreferences.language == .english))
            empty.setAccessibilityIdentifier("dock.empty-reader-status")
            empty.font = .systemFont(ofSize: 13 * factor)
            empty.frame = dockView.bounds.insetBy(dx: 10 * factor, dy: 10 * factor)
            if empty.superview == nil { dockView.addSubview(empty) }
        } else { empty.removeFromSuperview() }
        if appearance == nil || appearanceFallback {
            geometry.hoverRects = [dockView.bounds]
            let scales = sliverParameters.sizeScales
            let factor = passPreferences.size == .small ? scales.small : passPreferences.size == .large ? scales.large : scales.medium
            try? geometry.registerSliver(hullBounds: dockView.bounds, expandedSize: dockView.frame.size,
                                        edge: passPreferences.dockEdge, parameters: sliverParameters, scale: factor)
        }
        container.setFrameSize(dockView.frame.size)
        consoleButton.isHidden = geometry.consoleButton == nil
        if let rect = geometry.consoleButton { consoleButton.frame = rect }
        let selected = nativeEdge(passPreferences.dockEdge)
        var nextGeometries = [selected: geometry], nextViews = [selected: dockView]
        // The same neutral rectangle is valid at every edge. Register destinations before tracking,
        // so a right-edge Community Dock can actually preview and drop on the left, bottom or top.
        if appearance == nil {
            for orientation in DockEdgeGeometry.allowedEdges where orientation != selected {
                var candidate = geometry
                let scales = sliverParameters.sizeScales
                let factor = passPreferences.size == .small ? scales.small : passPreferences.size == .large ? scales.large : scales.medium
                try? candidate.registerSliver(hullBounds: dockView.bounds, expandedSize: dockView.frame.size,
                    edge: settingsEdge(orientation), parameters: sliverParameters, scale: factor)
                nextGeometries[orientation] = candidate; nextViews[orientation] = dockView
            }
        }
        // The official factory opts detached integration hosts into production
        // edge layouts; arbitrary injected appearances retain their own lifecycle.
        if (createsNativePanels || prepareDetachedAlternateAppearances), let appearance {
            // The top edge (G3-27) is drawn only while the widget rests there or is being carried:
            // an official horizontal face is costly, and a resting widget never needs it otherwise.
            let needsTop = selected == .top || carriedTo != nil || edge.isBackgroundPressed
            for (view, orientation) in zip(alternateViews, DockEdgeGeometry.allowedEdges.filter { $0 != selected && ($0 != .top || needsTop) }) {
                var oriented = passPreferences
                oriented.dockEdge = settingsEdge(orientation)
                do {
                    var candidate = try appearance(view, rows, oriented)
                    candidate.scaleRegistration(by: view.appliedGeometryScale)
                    guard passIsCurrent(generation) else { return }
                    bindEmptyStation(to: view)
                    view.onAction = dockView.onAction
                    view.onEscape = dockView.onEscape
                    view.permitsAction = { [weak self, weak view] _, source in
                        guard let self, let view else { return false }
                        return self.acceptsInstrumentAction(from: view, source: source)
                    }
                    view.onNeedsFreshPresentation = dockView.onNeedsFreshPresentation
                    nextGeometries[orientation] = candidate; nextViews[orientation] = view
                } catch { view.dispose() }
            }
        }
        edgeGeometries = nextGeometries; edgeViews = nextViews
        appearanceDisplay = display
        if carriedTo != nil { return }
        if sliverPrepared {
            let logical = sliverLogicalSize
            // AppKit can round the owned window to whole backing pixels. A data-only
            // update must keep that actual surface size until registered geometry changes.
            let size = preparedSliverGeometrySize == logical ? sliver.frame.size : logical
            _ = try? prepareSliver(size: size, backingScale: display?.backingScale)
        }
        let selectedID = passPreferences.followActiveDisplay ? display?.id : (passPreferences.dockDisplayID ?? topology.main?.id)
        let preference = DockEdgePreference(displayID: selectedID, edge: selected, alongFraction: passPreferences.dockAlongFraction)
        if edge.preference != preference { edge.setPreference(preference) }
        guard passIsCurrent(generation) else { return }
        if let cardID { if order.contains(cardID) { showCard(cardID) } else { dismissCard() } }
        if permitted {
            edge.start(); edge.refresh()
            // Pixel/material changes can leave the geometric presentation equal. Flush that
            // same-frame refresh as well, including the sliver and current edge variant.
            if let presentation = edge.presentation { present(presentation) }
        }
    }
    private func makeEdge(preference: DockEdgePreference = .init(), policy: DockVisibilityPolicy = .init()) -> DockEdgeController {
        let read: () -> DockEdgeEnvironment = { [weak self] in self?.environment() ?? .init(displays: [], layouts: []) }
        if let elapsedClock, let edgeScheduling {
            return DockEdgeController(preference: preference, policy: policy, clock: elapsedClock, scheduler: edgeScheduling, read: read, position: PulseDockPositioning.resolve)
        }
        return DockEdgeController(preference: preference, policy: policy, read: read, position: PulseDockPositioning.resolve)
    }
    private func topology(of environment: DockEdgeEnvironment) -> DockDisplayTopology {
        .init(displays: environment.displays, primaryID: environment.primaryDisplayID)
    }

    private func sampleEnvironment() -> DockEdgeEnvironment {
        if let nativeEnvironment { return nativeEnvironment() }
        let topology = DockDisplayTopology.system()
        var presence = DockPresence()
        presence.mouseButtonDown = NSEvent.pressedMouseButtons != 0
        return .init(displays: topology.displays, layouts: [], primaryDisplayID: topology.primaryID,
                     pointer: NSEvent.mouseLocation, presence: presence)
    }

    private func environment() -> DockEdgeEnvironment {
        let native = sampleEnvironment()
        let displays = native.displays
        let layouts = displays.flatMap { display in
            edgeGeometries.compactMap { orientation, geometry -> DockEdgeLayout? in
                guard let view = edgeViews[orientation] else { return nil }
                return DockEdgeLayout(displayID: display.id, edge: orientation, expandedSize: view.frame.size,
                    sliverLength: geometry.sliverLength, sliverThickness: geometry.sliverThickness,
                    hoverRects: geometry.hoverRects.isEmpty ? [view.bounds] : geometry.hoverRects,
                    alongAnchor: geometry.sliverAlongAnchor)
            }
        }
        var presence = native.presence
        presence.enabled = preferences.showDock; presence.autoHide = preferences.autoHide
        presence.lifecycleActive = permitted && !retired
        presence.cockpitClosed = presence.cockpitClosed && !cockpitPresentationBlocked
        presence.allowedOverFullscreen = native.presence.allowedOverFullscreen || preferences.showOverFullscreen
        presence.menuActuallyOpen = menuOpen; presence.locating = locating || helpMapHold
        presence.cardFocused = cardHasKeyboardFocus || interactionView.keyboardTargetID != nil
        // Preview does not claim to detect another app's fullscreen state or activate another Space.
        var auxiliary = cardPanel?.isVisible == true ? cardPanel?.frame : (!createsNativePanels ? native.cardFrame : nil)
        if overflowPanel?.isVisible == true, let frame = overflowPanel?.frame { auxiliary = auxiliary.map { $0.union(frame) } ?? frame }
        return .init(displays: displays, layouts: layouts, primaryDisplayID: native.primaryDisplayID,
            pointer: native.pointer, presence: presence, cardFrame: auxiliary)
    }
    private func acceptsInstrumentAction(from view: DockInstrumentView, source: DockActionSource) -> Bool {
        guard !createsNativePanels || view.superview === container else { return false }
        guard edge.acceptsPress(keyboardOrAccessibility: source == .accessibility) else { return false }
        // The gate samples current geometry and can synchronously switch the displayed edge.
        return !createsNativePanels || view.superview === container
    }
    private func nativeEdge(_ value: SettingsDockEdge) -> DockEdge {
        switch value { case .left: return .left; case .right: return .right; case .bottom: return .bottom; case .top: return .top }
    }
    private func settingsEdge(_ value: DockEdge) -> SettingsDockEdge {
        switch value { case .left: return .left; case .right: return .right; case .bottom: return .bottom; case .top: return .top }
    }
    private var visibilityPolicy: DockVisibilityPolicy {
        var value = DockVisibilityPolicy()
        value.revealDwell = Double(preferences.revealMilliseconds) / 1000
        value.wakeDepth = sliverParameters.trackingDepth
        return value
    }
    private var presentationGeometry: StaticDockGeometry {
        edge.presentation?.placement.flatMap { edgeGeometries[$0.edge] } ?? geometry
    }
    private func makePanel(forDock: Bool = false) -> NSPanel {
        let value: NSPanel
        if forDock {
            let dock = PulseDockPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            dock.mouseHandler = self
            if let nativeEnvironment {
                dock.pointerLocation = { nativeEnvironment().pointer }
            }
            value = dock
        } else {
            value = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        }
        value.isFloatingPanel = true; value.level = .floating; value.isOpaque = false
        value.backgroundColor = .clear; value.hasShadow = false; value.hidesOnDeactivate = false
        value.isReleasedWhenClosed = false
        return value
    }
    private func publishPlacementObservation(_ value: DockEdgePresentation?) {
        guard let callback = onPlacementObserved else { return }
        let placement: DockEdgePlacement?
        if permitted, !retired, application != nil, let value, value.paintedFrame != nil,
           !createsNativePanels || panel?.isVisible == true {
            placement = value.placement
        } else { placement = nil }
        let intent = edge.preference
        let recovering = placement.map { actual in
            // Follow mode supplies its observed display; automatic following is not persisted.
            (intent.displayID.map { $0 != actual.displayID } ?? false)
                || intent.edge != actual.edge
                || abs(intent.alongFraction - actual.alongFraction) > 1e-9
        } ?? false
        let observation = PlacementObservation(placement: placement, recovering: recovering)
        guard observation != lastPlacementObservation else { return }
        // Record before delivery: context updates can synchronously re-enter the Host.
        lastPlacementObservation = observation
        callback(observation.placement, observation.recovering)
    }
    private func bindBackgroundMovement(_ value: DockEdgePresentation) {
        dockView.backgroundDragDelegate = nil
        alternateViews.forEach { $0.backgroundDragDelegate = nil }
        edge.dragRegions = nil
        guard permitted, !retired, value.state == .expanded else { return }
        let orientation = value.placement?.edge ?? nativeEdge(preferences.dockEdge)
        let view = edgeViews[orientation] ?? dockView
        let current = edgeGeometries[orientation] ?? geometry
        if let regions = current.dragRegions ?? view.registeredDragRegions(excluding: current.consoleButton.map { [$0] } ?? []) {
            edge.dragRegions = regions; view.backgroundDragDelegate = edge
        }
    }
    private func makePointerSurface() -> PulsePanelPointerSurface {
        let surface = PulsePanelPointerSurface(pointSource: pointerSampleSource)
        surface.onChange = { [weak self] _ in
            guard let self, self.permitted, !self.retired, !self.rendering else { return }
            // Local samples invalidate input observation. Resolve fresh global
            // pointer/card/wake facts through the one controller; nil is not
            // presumed outside because the pointer may be over a separate card.
            self.edge.refresh()
            self.interactionController?.refresh()
            self.updateNozzleMagnification()
            self.publishDockHelpInteraction()
        }
        return surface
    }
    private func bindPointerInput(_ value: DockEdgePresentation, content: NSView? = nil) {
        guard permitted, !retired, value.paintedFrame != nil else { pointerSurface.stop(); return }
        let target: NSView
        if let content { target = content }
        else {
            switch value.state {
            case .expanded: target = container
            case .sliver: target = sliver
            case .suppressed: pointerSurface.stop(); return
            }
        }
        if pointerSurface.superview !== target {
            pointerSurface.stop(); pointerSurface.removeFromSuperview()
            target.addSubview(pointerSurface, positioned: .below, relativeTo: nil)
            pointerSurface.reportAgain()
        }
        pointerSurface.frame = target.bounds
        pointerSurface.autoresizingMask = [.width, .height]
        pointerSurface.setActive(true)
    }
    private func present(_ value: DockEdgePresentation) {
        defer {
            // The controller is still sampling during onPresent. Apply a queued
            // reveal after this delivery so its own reveal intent can be sampled.
            if pendingUserReveal, value.paintedFrame != nil {
                Task { @MainActor [weak self] in self?.fulfillUserReveal() }
            }
            publishDockHelpSurface(value)
            updateNozzleMagnification()
            if !rendering { bindInteractionInput(); interactionController?.refresh() }
        }
        // A withdrawn surface must not accept late tracking from its old menus.
        if value.paintedFrame == nil {
            dockMenuGeneration &+= 1
            retireTrackedDockMenu()
        }
        // Native panels and the no-window construction checks share this actual input binding.
        bindBackgroundMovement(value)
        guard createsNativePanels else { bindPointerInput(value); publishPlacementObservation(value); return }
        guard permitted, !retired, let frame = value.paintedFrame else {
            attentionWasExpanded = false; pointerSurface.stop(); presentedSurfaceState = nil; collapseGhost.stop(); snapPreview.hide()
            panel?.orderOut(nil); publishPlacementObservation(nil); reportVisibility(false); return
        }
        if panel == nil {
            let newPanel = makePanel(forDock: true)
            panel = newPanel
            NotificationCenter.default.addObserver(self, selector: #selector(dockHelpOcclusionChanged(_:)),
                name: NSWindow.didChangeOcclusionStateNotification, object: newPanel)
        }
        guard let panel else { publishPlacementObservation(nil); return }
        let previousState = panel.isVisible ? presentedSurfaceState : nil
        let motionEdge = value.placement?.edge ?? nativeEdge(preferences.dockEdge)
        let reduceMotion = application?.effective.reduceMotion ?? true
        // D-9 collapse: the last expanded image fades out sliding toward the edge, in its own
        // click-through panel, while this panel shows the sliver at once (no state is delayed).
        if value.state == .sliver, previousState == .expanded, panel.contentView === container, !value.moving {
            collapseGhost.play(snapshotOf: container, frame: panel.frame, level: panel.level, edge: motionEdge, reduceMotion: reduceMotion)
        } else if value.state == .expanded { collapseGhost.stop() }
        panel.level = value.moving ? .statusBar : .floating
        updateSnapPreview(value)
        panel.setFrame(frame, display: false)
        panel.collectionBehavior = preferences.showOverFullscreen ? [.canJoinAllSpaces, .fullScreenAuxiliary] : [.canJoinAllSpaces]
        let content: NSView
        switch value.state {
        case .expanded:
            let orientation = value.placement?.edge ?? nativeEdge(preferences.dockEdge)
            let view = edgeViews[orientation] ?? dockView
            for child in container.subviews where child is DockInstrumentView && child !== view { child.removeFromSuperview() }
            if view.superview !== container { container.addSubview(view, positioned: .below, relativeTo: consoleButton) }
            container.setFrameSize(view.frame.size)
            let current = edgeGeometries[orientation] ?? geometry
            consoleButton.isHidden = current.consoleButton == nil
            if let rect = current.consoleButton { consoleButton.frame = rect }
            content = container
        case .sliver:
            do { content = try prepareSliver(size: panel.frame.size) }
            catch { pointerSurface.stop(); panel.orderOut(nil); publishPlacementObservation(nil); reportVisibility(false); return }
        case .suppressed: attentionWasExpanded = false; pointerSurface.stop(); presentedSurfaceState = nil; collapseGhost.stop(); snapPreview.hide(); panel.orderOut(nil); publishPlacementObservation(nil); reportVisibility(false); return
        }
        if panel.contentView !== content { panel.contentView = content }
        bindPointerInput(value, content: content)
        // Keep the AppKit tracking instance attached while the surface redraws.
        let contextualMenu = trackedDockMenu ?? menu()
        content.menu = contextualMenu
        content.subviews.forEach { $0.menu = contextualMenu }
        #if MODELPLAN_DOCK_NATIVE_JOURNEY
        if suppressJourneyOrderIn { return }
        #endif
        if !panel.isVisible, let dockPanel = panel as? PulseDockPanel {
            dockPanel.orderInAtPlacement { granted in
                guard let placement = value.placement,
                      let display = topology(of: sampleEnvironment()).display(placement.displayID) else { return nil }
                return PulseRestingPlacement.replaceGranted(granted, requested: frame, edge: placement.edge,
                                                             visible: display.usableFrame)
            }
        } else {
            panel.displayIfNeeded()
            panel.orderFrontRegardless()
        }
        // D-9 reveal: the expanded content fades in from 14 pt toward the edge.
        if panel.isVisible, value.state == .expanded, previousState == .sliver, !value.moving {
            DockRevealMotion.reveal(container, edge: motionEdge, reduceMotion: reduceMotion); revealAnimationsForChecks += 1
        }
        presentedSurfaceState = panel.isVisible ? value.state : nil
        if panel.isVisible, value.state == .expanded, !attentionWasExpanded { acknowledgeDockReveal() }
        attentionWasExpanded = panel.isVisible && value.state == .expanded
        if panel.isVisible { pulsePresentedNotices(value) }
        publishPlacementObservation(value)
        reportVisibility(panel.isVisible)
        #if DEBUG && MODELPLAN_U5_REAL_INPUT
        U5RealInputObservation.install(self, panel: panel)
        #endif
    }
    /// Samples only registered, hit-testable body/grip points. Missing geometry
    /// remains absent; a panel frame is never substituted for an actual anchor.
    private func dockHelpDragAnchor(in view: DockInstrumentView, regions: DockBackgroundDragRegions) -> CGRect? {
        DockHelpAnchorSearch.find(paths: regions.grips + [regions.body],
                                  visible: view.visibleRect, contains: regions.contains)
    }
    private func withdrawDockHelpSurface() {
        guard lastDockHelpSurface != nil else {
            if !permitted || retired { consoleButton.clearHelpFocus() }
            return
        }
        lastDockHelpSurface = nil; dockHelpInputGeneration = nil
        consoleButton.clearHelpFocus()
        publishDockHelpInteraction()
        dockHelpSurfaceDidChange?(nil)
    }
    @objc private func dockHelpOcclusionChanged(_ notification: Notification) {
        guard let current = edge.presentation else { withdrawDockHelpSurface(); return }
        publishDockHelpSurface(current)
    }
    func isCurrentDockHelpSurface(_ value: DockHelpSurface) -> Bool {
        guard !retired, !retiring, permitted, preferences.showDock, lastDockHelpSurface == value,
              dockHelpInputGeneration == inputGeneration,
              let panel, panel.isVisible, !panel.isMiniaturized, panel.alphaValue > 0,
              panel.occlusionState.contains(.visible), edge.presentation?.state == .expanded else { return false }
        return true
    }
    func dockHelpBlockingRects(_ value: DockHelpSurface) -> [CGRect] {
        guard isCurrentDockHelpSurface(value), let panel else { return [] }
        var result = [panel.frame]
        if let cardPanel, cardPanel.isVisible { result.append(cardPanel.frame) }
        if let overflowPanel, overflowPanel.isVisible { result.append(overflowPanel.frame) }
        return result
    }
    func dockHelpMapBlockingRects(_ value: DockHelpSurface) -> [CGRect] {
        guard isCurrentDockHelpSurface(value), let panel else { return [] }
        let view = interactionView
        var result = (model?.inputs ?? []).compactMap { input -> CGRect? in
            guard let rect = view.helpReadoutAnchor(input.id), view.visibleRect.contains(rect) else { return nil }
            return panel.convertToScreen(view.convert(rect, to: nil))
        }
        if let cardPanel, cardPanel.isVisible { result.append(cardPanel.frame) }
        if let overflowPanel, overflowPanel.isVisible { result.append(overflowPanel.frame) }
        return result
    }
    func dockHelpWindowPolicy(_ value: DockHelpSurface) -> (NSWindow.SharingType, NSWindow.CollectionBehavior)? {
        guard isCurrentDockHelpSurface(value), let panel else { return nil }
        return (panel.sharingType, panel.collectionBehavior)
    }
    /// The presenter supplies the same title and body it displayed, after its own dwell.
    /// An older surface or focus receipt cannot overwrite or clear the current control.
    @discardableResult func setDockHelpAccessibilityExplanation(
        _ text: String?, for interaction: DockHelpInteraction, on surface: DockHelpSurface
    ) -> Bool {
        guard isCurrentDockHelpSurface(surface), !surface.dragging, interaction.source == .keyboard,
              currentDockHelpInteraction == interaction, focusedDockHelpAnchorID == interaction.anchor.id else { return false }
        if interaction.anchor.id == "dock.ignition" {
            consoleButton.setAccessibilityHelp(text)
            return true
        }
        return interactionView.setFocusedHelpExplanation(text, for: interaction.anchor.id)
    }

    var focusedDockHelpAnchorID: String? {
        guard permitted, !retired, edge.presentation?.state == .expanded, edge.presentation?.moving != true,
              interactionController?.hasCapture != true else { return nil }
        return consoleButton.hasHelpFocus ? "dock.ignition" : interactionView.focusedHelpAnchorID
    }

    private func clearDockHelpAccessibilityExplanation() {
        consoleButton.setAccessibilityHelp(nil)
        dockView.clearFocusedHelpExplanation()
        alternateViews.forEach { $0.clearFocusedHelpExplanation() }
    }

    private func publishDockHelpInteraction() {
        let next: DockHelpInteraction?
        if let surface = currentDockHelpSurface, !surface.dragging,
           interactionController?.hasCapture != true, let panel {
            let view = interactionView
            if let focused = focusedDockHelpAnchorID,
               let anchor = surface.mapAnchors.first(where: { $0.id == focused && $0.visible }) {
                next = .init(anchor: anchor, source: .keyboard)
            } else if let pointer = environment().pointer {
                let local = view.convert(panel.convertPoint(fromScreen: pointer), from: nil)
                let targetID = view.helpAnchorID(atLocal: local)
                let anchor = surface.mapAnchors.first { $0.visible && $0.id == targetID }
                    ?? surface.mapAnchors.first {
                        guard $0.visible, $0.rect.contains(pointer) else { return false }
                        if $0.id == "dock.ignition" {
                            return consoleButton.isEnabled && !consoleButton.isHiddenOrHasHiddenAncestor
                        }
                        return $0.id == "dock.move" || $0.id == "dock.card"
                    }
                next = anchor.map { .init(anchor: $0, source: .pointer) }
            } else { next = nil }
        } else { next = nil }
        // A fresh focus visit gets a new receipt, but repeated samples of one visit stay silent.
        guard next?.anchor != currentDockHelpInteraction?.anchor ||
                next?.source != currentDockHelpInteraction?.source else { return }
        clearDockHelpAccessibilityExplanation()
        currentDockHelpInteraction = next
        dockHelpInteractionDidChange?(next)
    }

    private func publishDockHelpSurface(_ value: DockEdgePresentation) {
        guard createsNativePanels, !retired, !retiring, permitted, preferences.showDock, value.state == .expanded,
              let panel, panel.isVisible, !panel.isMiniaturized, panel.alphaValue > 0,
              panel.occlusionState.contains(.visible) else { withdrawDockHelpSurface(); return }
        let orientation = value.placement?.edge ?? nativeEdge(preferences.dockEdge)
        let view = edgeViews[orientation] ?? dockView
        guard view.window === panel, !view.isHiddenOrHasHiddenAncestor else { withdrawDockHelpSurface(); return }
        defer { publishDockHelpInteraction() }
        let current = edgeGeometries[orientation] ?? geometry
        func screenRect(_ rect: CGRect) -> CGRect? {
            guard !rect.isNull, !rect.isInfinite, rect.width > 0, rect.height > 0,
                  view.visibleRect.contains(rect) else { return nil }
            let global = panel.convertToScreen(view.convert(rect, to: nil))
            guard global.origin.x.isFinite, global.origin.y.isFinite,
                  global.width.isFinite, global.height.isFinite else { return nil }
            return global
        }
        var anchors: [FirstUseHintKind: CGRect] = [:]
        if let hull = view.registeredHullBounds, let global = screenRect(hull) {
            anchors[.findWidget] = global
        }
        if let id = model?.inputs.first(where: { view.interactionAnchor($0.id) != nil })?.id,
           let local = view.interactionAnchor(id), let global = screenRect(local) {
            anchors[.ringRefresh] = global
        }
        if cockpitEntryEnabled, !consoleButton.isHiddenOrHasHiddenAncestor,
           consoleButton.window === panel, consoleButton.bounds.width > 0, consoleButton.bounds.height > 0,
           consoleButton.visibleRect.contains(consoleButton.bounds) {
            let global = panel.convertToScreen(consoleButton.convert(consoleButton.bounds, to: nil))
            if global.origin.x.isFinite, global.origin.y.isFinite,
               global.width.isFinite, global.height.isFinite { anchors[.ignition] = global }
        }
        if let regions = current.dragRegions ?? view.registeredDragRegions(excluding: current.consoleButton.map { [$0] } ?? []),
           let drag = dockHelpDragAnchor(in: view, regions: regions), let global = screenRect(drag) {
            anchors[.drag] = global
        }
        var mapAnchors: [DockRequestedHelpAnchor] = []
        for (index, rect) in view.registeredGripRects.enumerated() {
            if let global = screenRect(rect) {
                mapAnchors.append(.init(id: "dock.grip.\(index)", region: .dockMove, rect: global, visible: true))
            }
        }
        if let grip = anchors[.drag] { mapAnchors.append(.init(id: "dock.move", region: .dockMove, rect: grip, visible: true)) }
        if let ignition = anchors[.ignition] { mapAnchors.append(.init(id: "dock.ignition", region: .ignition, rect: ignition, visible: true)) }
        for input in model?.inputs ?? [] {
            if let local = view.interactionAnchor(input.id), let rect = screenRect(local) {
                mapAnchors.append(.init(id: "dock.nozzle." + input.id, region: .nozzle, rect: rect, visible: true))
            }
            if let local = view.helpRingsAnchor(input.id), let rect = screenRect(local) {
                mapAnchors.append(.init(id: "dock.rings." + input.id, region: .rings, rect: rect, visible: true))
            }
            if let local = view.helpReadoutAnchor(input.id), let rect = screenRect(local) {
                mapAnchors.append(.init(id: "dock.number." + input.id, region: .number, rect: rect, visible: true))
            }
            if let local = view.helpNoticeAnchor(input.id), let rect = screenRect(local) {
                mapAnchors.append(.init(id: "dock.notice." + input.id, region: .eventDot, rect: rect, visible: true))
            }
        }
        if !card.isHidden, let cardPanel, cardPanel.isVisible, cardPanel.occlusionState.contains(.visible),
           card.window === cardPanel, card.bounds.width > 0, card.bounds.height > 0 {
            let language: InstrumentLanguage = preferences.language == .chinese ? .chinese : .english
            let rect = cardPanel.convertToScreen(card.convert(card.bounds, to: nil))
            mapAnchors.append(.init(id: "dock.card", region: .rings, rect: rect, visible: true,
                                    caption: HelpCatalog(language).explanation(.dockQuota).body))
        }
        let previous = lastDockHelpSurface
        let sameLayout = previous?.anchors == anchors && previous?.mapAnchors == mapAnchors && dockHelpInputGeneration == inputGeneration
        var next = DockHelpSurface(revealID: previous?.revealID ?? UUID(),
                                   layoutID: sameLayout ? (previous?.layoutID ?? UUID()) : UUID(),
                                   visible: true, dragging: value.moving, anchors: anchors)
        next.mapAnchors = mapAnchors
        guard next != previous else { return }
        clearDockHelpAccessibilityExplanation()
        lastDockHelpSurface = next; dockHelpInputGeneration = inputGeneration
        dockHelpSurfaceDidChange?(next)
    }
    /// Consume a first appearance only on the surface actually presented.
    private func pulsePresentedNotices(_ value: DockEdgePresentation) {
        let reduced = (application?.effective.reduceMotion ?? true) || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        switch value.state {
        case .expanded:
            let orientation = value.placement?.edge ?? nativeEdge(preferences.dockEdge)
            let view = edgeViews[orientation] ?? dockView
            pulseDockNotices(view, reduced: reduced)
        case .sliver:
            for mark in sliver.noticeMarks {
                let first = attention.firstAppearance(of: mark.notice.key, on: .sliver)
                if first && !reduced { _ = sliver.pulseNotice(mark.notice.key) }
            }
        case .suppressed: break
        }
    }
    private func pulseDockNotices(_ view: DockInstrumentView, reduced: Bool) {
        for (key, notice) in view.visibleNoticesForPulse {
            let first = attention.firstAppearance(of: notice.key, on: .dock)
            if first && !reduced { _ = view.pulseNotice(key) }
        }
    }
    @_spi(DockResourceChecks) public func pulseDockNoticesForChecks(reduced: Bool) {
        pulseDockNotices(dockView, reduced: reduced)
    }
    private var sliverLogicalSize: CGSize {
        let current = presentationGeometry
        return (edge.presentation?.placement?.edge ?? nativeEdge(preferences.dockEdge)).isHorizontal
            ? CGSize(width: current.sliverLength, height: current.sliverThickness)
            : CGSize(width: current.sliverThickness, height: current.sliverLength)
    }
    private func quotaReadingsForSliver() -> [DockSliverQuotaInput] {
        guard preferences.sliverAlert, let model else { return [] }
        let inputs = Dictionary(uniqueKeysWithValues:model.inputs.map { ($0.id,$0) })
        guard let order = try? memberSafePreferences.presentedSubscriptionIDs(model.inputs.map(\.id)) else { return [] }
        let view = interactionView
        let pitches = presentationGeometry.quotaPitchRanges
        func ink(_ role:DockQuotaStatus) -> DockInk {
            if let supplied = view.quotaInk(for:role) { return supplied }
            let fallback:NSColor
            switch role { case .warning: fallback = .systemYellow; case .critical: fallback = .systemRed; case .normal,.unknown: fallback = .secondaryLabelColor }
            guard let rgb=fallback.usingColorSpace(.sRGB) else { return DockInk(0.5,0.5,0.5) }
            return DockInk(Double(rgb.redComponent),Double(rgb.greenComponent),Double(rgb.blueComponent),Double(rgb.alphaComponent))
        }
        let now = currentDate()
        return order.compactMap { id in
            guard let input = inputs[id], let pitch=pitches[id] else { return nil }
            // The model already withholds unproven values; evaluate expiry/selection again at presentation time.
            let reading = try? DockInstrumentProjection.evaluate(memberSafePreferences.applying(to:input),now:now,redBelow:effectiveRedBelow)
            let status = reading?.status ?? .unknown
            let role:DockQuotaStatus? = status == .warning || status == .critical ? status:nil
            return .init(subscriptionID:id,remainingPercent:reading?.remainingPercent,quotaRole:role,ink:role.map(ink),from:pitch.lowerBound,through:pitch.upperBound)
        }
    }
    /// Uses the same bounded view preparation in native presentation and no-window checks.
    func prepareSliver(size: CGSize, backingScale: Int? = nil) throws -> DockSliverView {
        guard !retired else { throw DockArtworkError.invalidManifest }
        do {
            let geometry = presentationGeometry
            let projection = try attention.project(attentionSignals, stationBySubscription: geometry.noticeStationBySubscription,
                                                   sliverAlerts: preferences.sliverAlert, at: currentDate())
            var marks = [String: DockSliverNoticeMark]()
            for dot in projection.dots {
                guard let position = geometry.noticeStationPositions[dot.stationID] else { continue }
                if let old = marks[dot.stationID], old.notice.rank <= dot.notice.rank { continue }
                marks[dot.stationID] = DockSliverNoticeMark(position: position, notice: dot.notice, unit: geometry.noticeUnit)
            }
            sliver.noticeMarks = marks.values.sorted { $0.position == $1.position ? $0.notice.key.subscriptionID < $1.notice.key.subscriptionID : $0.position < $1.position }
            let nativeScale = backingScale
                ?? topology(of: sampleEnvironment()).display(edge.presentation?.placement?.displayID)?.backingScale
                ?? geometry.sliverScale
            try sliver.apply(image: geometry.sliverImage, logicalSize: size, scale: min(nativeScale, geometry.sliverScale),
                             accessibilityLabel: EngineRowsText.showQuotaWidget.value(preferences.language), quotaReadings: quotaReadingsForSliver())
            sliverPrepared = true; preparedSliverGeometrySize = sliverLogicalSize
            return sliver
        } catch { sliverPrepared = false; preparedSliverGeometrySize = nil; throw error }
    }
    func menu() -> NSMenu {
        let component = DockSliverMenu(labels: [:], handlers: [:])
        component.owner = self
        let menu = component.menu
        let generation = dockMenuGeneration
        component.onMenuActuallyOpen = { [weak self, weak menu] open in
            guard let self, let menu, self.dockMenuGeneration == generation else { return }
            if open { self.menuWillOpen(menu) }
            else { self.menuDidClose(menu) }
        }
        component.retainWithMenu()
        // G3-28 + owner HIG decision (11-06): [Auto-Collapse ✓, Settings…] — [Quit ModelPlan].
        // D37 (11-06): no shortcut hints in this contextual menu; ⌘, and ⌘Q stay in the status menu.
        // No Hide item here: the widget is turned off from the status menu or Settings.
        // "收起/Collapse" only names the edge-strip state.
        let english = application == nil || preferences.language == .english
        let quit: String
        switch (purpose, english) {
        case (.production, true): quit = "Quit ModelPlan"
        case (.production, false): quit = "退出 ModelPlan"
        case (.selfTest, true): quit = "Quit Preview"
        case (.selfTest, false): quit = "退出自测版"
        }
        let available = permitted && !lifecycleSuspended
        var items: [DockMenuPresentationItem] = []
        if let statusIconNotice {
            items.append(.init(title: statusIconNotice.value(preferences.language), accessibilityID: "dock.menu.notice"))
            items.append(.init(title: nil))
        }
        if lifecycleSuspended {
            items.append(.init(title: EngineRowsText.paused.value(preferences.language)))
            items.append(.init(title: nil))
        } else if cockpitEntryEnabled {
            items.append(.init(title: english ? "Open Cockpit" : "打开驾驶舱", action: { [weak self] in self?.openConsole() }))
            items.append(.init(title: nil))
        }
        let autoCollapse = preferences.autoHide
        items.append(.init(title: EngineRowsText.autoCollapse.value(preferences.language), accessibilityID: "dock.menu.autoCollapse",
                           checked: autoCollapse,
                           action: available && requestAutoCollapse != nil ? { [weak self] in self?.toggleAutoCollapseFromMenu(!autoCollapse) } : nil))
        items.append(.init(title: EngineRowsText.settings.value(preferences.language), accessibilityID: "dock.menu.settings",
                           action: available ? { [weak self] in self?.openSettings() } : nil))
        items.append(.init(title: nil))
        items.append(.init(title: quit, accessibilityID: "dock.menu.quit",
                           target: NSApplication.shared, selector: #selector(NSApplication.terminate(_:))))
        component.replace(with: items)
        return menu
    }
    public func menuWillOpen(_ menu: NSMenu) {
        guard permitted, !retired, !retiring, edge.presentation?.paintedFrame != nil, ownsDockMenu(menu) else { return }
        trackedDockMenu = menu
        if let menuEndObserver { NotificationCenter.default.removeObserver(menuEndObserver) }
        menuEndObserver = NotificationCenter.default.addObserver(forName: NSMenu.didEndTrackingNotification, object: menu, queue: .main) { [weak self, weak menu] _ in
            MainActor.assumeIsolated {
                guard let self, let menu else { return }
                self.menuDidClose(menu)
            }
        }
        edge.refresh()
    }

    public func menuDidClose(_ menu: NSMenu) {
        guard trackedDockMenu === menu else { return }
        trackedDockMenu = nil
        if let menuEndObserver { NotificationCenter.default.removeObserver(menuEndObserver); self.menuEndObserver = nil }
        edge.refresh()
    }

    private func retireTrackedDockMenu() {
        let menu = trackedDockMenu
        trackedDockMenu = nil
        if let menuEndObserver { NotificationCenter.default.removeObserver(menuEndObserver); self.menuEndObserver = nil }
        menu?.cancelTracking()
    }

    private func closeContext() {
        guard permitted, !retired, !retiring else { return }
        retireTrackedDockMenu()
        if let controller = interactionController, controller.isActive { controller.dismissCard() }
        dismissCard()
        edge.refresh()
    }
    func acknowledgeDockReveal() {
        guard permitted, !retired else { return }
        try? attention.acknowledge(.dockRevealed, signals: attentionSignals, at: currentDate())
        publishAttention()
    }
    func setCockpitPresentationBlocked(_ blocked: Bool) {
        guard !retired, cockpitPresentationBlocked != blocked else { return }
        cockpitPresentationBlocked = blocked
        if blocked {
            clearLocateHighlight()
            edge.refresh()
            dismissCard()
        } else {
            edge.restoreAfterCockpitClose()
        }
    }

    func revealForUser() {
        guard !retired, preferences.showDock else { return }
        pendingUserReveal = true
        fulfillUserReveal()
    }

    private func fulfillUserReveal() {
        guard pendingUserReveal, permitted, !retired, preferences.showDock,
              edge.presentation?.paintedFrame != nil else { return }
        clearLocateHighlight(); locating = true; edge.reveal()
        guard let presentation = edge.presentation, presentation.state == .expanded,
              let placement = presentation.placement, let view = edgeViews[placement.edge],
              !view.bounds.isEmpty, let parent = view.layer else {
            locating = false; edge.refresh(); return
        }
        pendingUserReveal = false
        let path = view.registeredMoveOutlinePath ?? CGPath(roundedRect: view.bounds.insetBy(dx: 1.5, dy: 1.5), cornerWidth: 6, cornerHeight: 6, transform: nil)
        let mark = CAShapeLayer(); mark.name = "dock.locate-highlight"; mark.frame = view.bounds; mark.path = path
        mark.fillColor = NSColor.clear.cgColor; mark.strokeColor = NSColor.controlAccentColor.cgColor
        mark.lineWidth = 3; mark.lineJoin = .round; parent.addSublayer(mark); locateLayer = mark
        if !(application?.effective.reduceMotion ?? true) {
            let pulse = CABasicAnimation(keyPath: "opacity"); pulse.fromValue = 0.45; pulse.toValue = 1
            pulse.duration = 0.4; pulse.autoreverses = true; pulse.repeatCount = 2
            pulse.isRemovedOnCompletion = false; pulse.fillMode = .forwards
            mark.add(pulse, forKey: "locate-pulse")
        }
        locateTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self else { return }
            self.clearLocateHighlight(); self.edge.refresh()
        }
    }
    private func clearLocateHighlight() {
        locateTask?.cancel(); locateTask = nil; locateLayer?.removeAllAnimations()
        locateLayer?.removeFromSuperlayer(); locateLayer = nil; locating = false
    }
    public func acknowledgeCockpitOpening() {
        guard cockpitEntryEnabled, !retired else { return }
        try? attention.acknowledge(.cockpitOpening, signals: attentionSignals, at: currentDate())
        publishAttention()
    }
    @objc private func openConsole() {
        guard cockpitEntryEnabled, permitted, !retired, let showConsole else { return }
        acknowledgeCockpitOpening(); dismissCard(); showConsole()
    }
    @objc private func openSettings() {
        guard permitted, !retired, !retiring else { return }
        closeContext()
        showSettings?()
    }
    private func toggleAutoCollapseFromMenu(_ on: Bool) {
        guard permitted, !retired, !lifecycleSuspended else { return }
        requestAutoCollapse?(on)
    }
    @objc private func displaysChanged() {
        guard permitted, !retired else { return }
        inputGeneration &+= 1; displayFollower.forgetLastDisplay()
        rebuild(); syncDisplayFollower(); edge.refresh()
    }
    /// The same read-only content used by presentation; querying it never opens a card/window.
    public func cardContent(for id:String,at date:Date? = nil) throws -> DockCardContent? {
        let now=date ?? currentDate()
        guard !retired,let input=model?.inputs.first(where:{$0.id == id}) else { return nil }
        let projected = memberSafePreferences.applying(to: input)
        let row = model?.presentationRows[id]
        let selected = row?.windowObservations == nil ? nil :
            try DockInstrumentProjection.evaluate(projected, now: now, redBelow: effectiveRedBelow).selectedWindowID
        return try DockCardProjection.content(input: projected,
                revision: application?.snapshot.revision ?? 0,
                plan:model?.presentationRows[id]?.plan ?? "",
                sourceAndAge: row?.cardSourceAndAge(at:now,english:preferences.language == .english,selectedWindowID:selected) ?? CommunityDockObservation.text(input: memberSafePreferences.applying(to: input), snapshot: snapshot, model: model, now: now, language: preferences.language),
                stateLabel: model?.presentationRows[id]?.cardBadge(at: now, english: preferences.language == .english) ?? (input.dataState == .fresh ? "" : (preferences.language == .english ? "Unavailable or stale" : "不可用或已过期")),
                windowDetails:model?.presentationRows[id]?.resetDetails(at:now,english:preferences.language == .english) ?? [:],
                additionalRows: model?.presentationRows[id]?.cardAdditionalRows(at: now, english: preferences.language == .english) ?? [],
                links: currentCardSourceLinks(for: id, at: now),
                enterLabel: (cardUsesSettings(id) ? EngineRowsText.contextSettings : EngineRowsText.cockpitAction).value(preferences.language),
                dismissLabel: EngineRowsText.contextClose.value(preferences.language),
                redBelow: effectiveRedBelow, at: now)
    }
    private func cardUsesSettings(_ id: String) -> Bool {
        purpose == .production || model?.presentationRows[id] != nil
    }
    private func currentCardSourceLinks(for id: String, at now: Date) -> [DockCardLink] {
        guard let expiry = attentionSignals.first(where: { $0.id == id })?.reset?.expiresAt, now < expiry else { return [] }
        return model?.presentationRows[id]?.links ?? []
    }
    private func interactionCardContent(_ id: String) -> DockCardContent? { try? cardContent(for:id) }
    private func showCard(_ id: String, supplied: DockCardContent? = nil) {
        guard permitted, !retired, preferences.showDock,
              (try? memberSafePreferences.presentedSubscriptionIDs(model?.inputs.map(\.id) ?? []))?.contains(id) == true,
              let content = supplied ?? interactionCardContent(id), content.subscriptionID == id,
              content.revision == (application?.snapshot.revision ?? 0) else { dismissCard(); return }
        cardGeneration &+= 1
        let token = cardGeneration, feed = inputGeneration
        cardID = id; cardPresentedRevision = content.revision; cardPresentedGeneration = feed; card.isHidden = false
        card.appearance = NSAppearance(named: (application?.effective.darkAppearance ?? true) ? .darkAqua : .aqua)
        card.permitsAction = { [weak self] id, revision in self?.cardIsCurrent(id, revision: revision, token: token, feed: feed) == true }
        card.onOpenURL = { [weak self] url in
            guard let self, self.cardIsCurrent(id, revision: content.revision, token: token, feed: feed),
                  EngineRowsEventDecoder.isHTTPSSourceURL(url),
                  self.currentCardSourceLinks(for: id, at: self.currentDate()).contains(where: { $0.url == url }) else { return }
            self.openCardSourceURL(url)
        }
        card.onEnter = { [weak self] id, revision in
            guard let self, self.cardIsCurrent(id, revision: revision, token: token, feed: feed) else { return }
            if self.cardUsesSettings(id) { self.openSettings() }
            else { self.closeContext(); self.openConsole() }
        }
        card.onDismiss = { [weak self] in
            guard let self, self.cardGeneration == token, self.inputGeneration == feed else { return }
            if let controller = self.interactionController, controller.isActive { controller.dismissCard() }
            self.dismissCard()
        }
        card.onFocusChange = { [weak self] in self?.refreshCardFocusSoon() }
        let unavailable = !cardUsesSettings(id) && !cockpitEntryEnabled
        var style = Self.prototypeCardStyle
        // D37 (11-06): the production card has no Settings/Close buttons (prototype card);
        // Settings is in the widget's right-click menu.
        style.showsActions = purpose != .production
        do {
            try card.apply(content, style: style, brandImage: cardBrandImage(id), enterDisabledReason: unavailable ? EngineRowsText.comingSoon.value(preferences.language) : nil)
        } catch { dismissCard(); return }
        if interactionController?.isActive != true { scheduleFallbackCardLeave() }
        // M-1: the ring whose card is open glows (only on the presented edge view).
        for view in edgeViews.values where view !== interactionView { view.setHotNozzle(nil) }
        let glow = QuotaWidgetCardMaterial.hotGlow
        interactionView.setHotNozzle(id, glow: CGColor(srgbRed: glow.red, green: glow.green, blue: glow.blue, alpha: glow.alpha),
                                     blur: QuotaWidgetCardMaterial.hotGlowBlur)
        guard createsNativePanels else { return }
        if cardPanel == nil {
            let panel = makePanel(); cardPanel = panel
            // The plate's drop shadow (prototype face.css:52 0 8px 24px #0007) comes from the window server.
            panel.hasShadow = true
            NotificationCenter.default.addObserver(self, selector: #selector(cardKeyStateChanged(_:)), name: NSWindow.didBecomeKeyNotification, object: panel)
            NotificationCenter.default.addObserver(self, selector: #selector(cardKeyStateChanged(_:)), name: NSWindow.didResignKeyNotification, object: panel)
        }
        guard let cardPanel, let panelFrame = panel?.frame,
              let screen = topology(of: sampleEnvironment()).display(edge.presentation?.placement?.displayID) else { dismissCard(); return }
        let view = interactionView
        guard let local = view.interactionAnchor(id), let window = view.window else { dismissCard(); return }
        let anchor = window.convertToScreen(view.convert(local, to: nil))
        let actualEdge = edge.presentation?.placement?.edge ?? nativeEdge(preferences.dockEdge)
        guard let frame = HostCardPlacement.place(anchor: anchor, size: card.frame.size,
                                                  available: screen.visibleFrame, edge: actualEdge) else {
            dismissCard(); return
        }
        // The plate plus its pointer arrow toward the ring (prototype card.js place()).
        if card.superview !== cardChrome { card.removeFromSuperview(); cardChrome.addSubview(card) }
        if cardArrow.superview !== cardChrome { cardChrome.addSubview(cardArrow, positioned: .above, relativeTo: card) }
        let pointer = HostCardPointer.layout(plate: frame, ring: anchor)
        let chromeFrame = pointer?.panel ?? frame
        card.setFrameOrigin(CGPoint(x: frame.minX - chromeFrame.minX, y: frame.minY - chromeFrame.minY))
        if let pointer {
            let xs = pointer.arrow.map(\.x), ys = pointer.arrow.map(\.y)
            let box = CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!).insetBy(dx: -1, dy: -1)
            cardArrow.frame = box.offsetBy(dx: -chromeFrame.minX, dy: -chromeFrame.minY)
            cardArrow.setArrow(pointer.arrow.map { CGPoint(x: $0.x - box.minX, y: $0.y - box.minY) },
                               fill: style.background, seam: style.seam)
            cardArrow.isHidden = false
        } else { cardArrow.isHidden = true; cardArrow.setArrow([], fill: style.background, seam: nil) }
        cardChrome.frame = CGRect(origin: .zero, size: chromeFrame.size)
        if cardPanel.contentView !== cardChrome { cardPanel.contentView = cardChrome }
        cardPanel.setFrame(chromeFrame, display: true)
        cardPanel.invalidateShadow()
        cardPanel.orderFrontRegardless(); edge.refresh()
    }
    private func cardIsCurrent(_ id: String, revision: UInt64, token: UInt64, feed: UInt64) -> Bool {
        guard permitted, !retired, !rendering, preferences.showDock, !card.isHidden,
              cardID == id, cardGeneration == token, inputGeneration == feed,
              application?.snapshot.revision == revision,
              model?.inputs.contains(where: { $0.id == id }) == true,
              (try? memberSafePreferences.presentedSubscriptionIDs(model?.inputs.map(\.id) ?? []))?.contains(id) == true else { return false }
        return !createsNativePanels || cardPanel?.isVisible == true
    }
    private func scheduleFallbackCardLeave() {
        guard fallbackCardLeaveTask == nil else { return }
        fallbackCardLeaveTask = Task { @MainActor [weak self] in
            var outsideSince: ContinuousClock.Instant?
            let clock = ContinuousClock()
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled, let self, !self.retired, self.cardID != nil else { return }
                if self.interactionController?.isActive == true { self.fallbackCardLeaveTask = nil; return }
                if self.menuOpen || self.interactionEnvironment().insideShared != false {
                    outsideSince = nil
                } else if let start = outsideSince {
                    if start.duration(to: clock.now) >= .milliseconds(250) { self.dismissCard(); return }
                } else { outsideSince = clock.now }
            }
        }
    }
    /// M-2: outline the snap destination while the carried widget is off it.
    private func updateSnapPreview(_ value: DockEdgePresentation) {
        guard value.moving, value.state == .expanded, let placement = value.placement, let carried = value.carriedFrame,
              abs(carried.minX - placement.frame.minX) + abs(carried.minY - placement.frame.minY) > 1 else { snapPreview.hide(); return }
        let view = edgeViews[placement.edge]
        let size = placement.frame.size
        let path = view?.registeredMoveOutlinePath
            ?? placement.layout.hoverRects.first.map { CGPath(roundedRect: $0, cornerWidth: 6, cornerHeight: 6, transform: nil) }
            ?? CGPath(rect: CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5), transform: nil)
        let stroke = QuotaWidgetSnapPreviewMaterial.stroke
        snapPreview.show(path: path, flipped: view?.isFlipped ?? true, frame: placement.frame,
                         stroke: NSColor(srgbRed: stroke.red, green: stroke.green, blue: stroke.blue, alpha: stroke.alpha),
                         lineWidth: QuotaWidgetSnapPreviewMaterial.lineWidth, level: .statusBar)
    }
    /// Esc on a keyboard-focused ring closes its open card; the ring keeps the focus and the
    /// card stays closed until focus or hover moves to another ring.
    private func closeHeldCard() -> Bool {
        guard permitted, !retired, !card.isHidden, cardID != nil else { return false }
        if let controller = interactionController, controller.isActive { controller.dismissCard() }
        dismissCard()
        edge.refresh()
        return true
    }
    private func dismissCard() {
        fallbackCardLeaveTask?.cancel(); fallbackCardLeaveTask = nil
        cardGeneration &+= 1; cardID = nil; cardPresentedRevision = nil; cardPresentedGeneration = nil
        card.isHidden = true
        card.dispose(); cardPanel?.orderOut(nil)
        dockView.setHotNozzle(nil); edgeViews.values.forEach { $0.setHotNozzle(nil) }
        if let current = edge.presentation { publishDockHelpSurface(current) }
    }
    public func close() {
        guard !retired, !retiring else { return }
        retiring = true
        retireTrackedDockMenu()
        let retireContent = onWillRetire; onWillRetire = nil
        retireContent?()
        withdrawAdmittedContent(privacy: true)
        clearLocateHighlight(); inputGeneration &+= 1; retired = true; permitted = false
        withdrawDockHelpSurface(); dockHelpSurfaceDidChange = nil
        if let controller = interactionController { uninstallInteraction(controller) }
        workingSignals = [:]; attentionSignals = []; menuNotice = nil; menuNoticeDidChange?(nil, false); menuNoticeDidChange = nil; uninstallWorkingEffects()
        menuBarPreferencesChanged?(); menuBarPreferencesChanged = nil
        dismissCard()
        NotificationCenter.default.removeObserver(self)
        pointerSurface.stop(); pointerSurface.onChange = nil; pointerSurface.removeFromSuperview()
        displayFollower.stop(); followedDisplayID = nil
        edge.stop(); publishPlacementObservation(nil)
        edge.onPresent = nil; edge.onCommittedPlacement = nil
        onPlacementObserved = nil
        dockView.onNeedsFreshPresentation = nil
        dockView.dispose(); alternateViews.forEach { $0.dispose() }; sliver.dispose(); card.dispose()
        edgeViews = [:]; edgeGeometries = [:]; appearanceDisplay = nil
        overflowTray.dispose(); overflowPanel?.orderOut(nil); overflowPanel = nil
        collapseGhost.stop(); snapPreview.hide(); panel?.orderOut(nil); cardPanel?.orderOut(nil); panel = nil; cardPanel = nil
        reportVisibility(false); visibilityChanged = nil
        showConsole = nil; showSettings = nil; requestAutoCollapse=nil; catalogueChanged = nil; commitPlacement = nil; commitDisplayPlacement = nil; displayChoicesChanged = nil
    }
}

extension StaticDockPreviewHost: CommunityDockConsentReceiving {}

// Window-level native event capture is borrowed from Pulse; the existing
// background-region/consent/lifecycle gates remain authoritative for this slice.
extension StaticDockPreviewHost: PulsePanelMouseHandling {
    public func beginPanelMove(windowPoint: CGPoint, globalPoint: CGPoint) -> Bool {
        guard permitted, !retired, !rendering, let panel,
              edge.presentation?.state == .expanded else { return false }
        let orientation = edge.presentation?.placement?.edge ?? nativeEdge(preferences.dockEdge)
        let view = edgeViews[orientation] ?? dockView
        guard view.window === panel else { return false }
        return edge.beginBackgroundMove(local: view.convert(windowPoint, from: nil), global: globalPoint)
    }
    public func continuePanelMove(globalPoint: CGPoint) {
        guard permitted, !retired else { edge.cancelBackgroundMove(); return }
        edge.updateBackgroundMove(global: globalPoint)
    }
    public func finishPanelMove(globalPoint: CGPoint) {
        guard permitted, !retired else { edge.cancelBackgroundMove(); return }
        edge.endBackgroundMove(global: globalPoint)
    }
    public var hasPanelControlCapture: Bool { interactionController?.hasCapture == true }

    public func cancelPanelMove() {
        if hasPanelControlCapture { interactionController?.cancelNozzle() }
        edge.cancelBackgroundMove()
    }
}
