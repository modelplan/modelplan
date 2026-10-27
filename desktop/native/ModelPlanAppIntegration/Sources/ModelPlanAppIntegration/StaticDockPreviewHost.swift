// SPDX-License-Identifier: MIT
import AppKit
import CoreGraphics
import ModelPlanCore
import ModelPlanDock
import ModelPlanSettings
import ModelPlanCommunityHost

/// Geometry returned by an injected appearance, already scaled in view-local points.
public struct StaticDockGeometry {
    public var hoverRects: [CGRect]
    public var sliverLength: CGFloat
    public var sliverThickness: CGFloat
    public var sliverAlongAnchor: CGFloat?
    public var sliverImage: CGImage?
    public var sliverScale: Int
    public var consoleButton: CGRect?
    public var dragRegions: DockBackgroundDragRegions?
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
        let metrics = try parameters.resolve(fullSpan: edge == .bottom ? hullBounds.width : hullBounds.height, scale: scale)
        sliverLength = metrics.length; sliverThickness = metrics.thickness
        sliverAlongAnchor = edge == .bottom ? hullBounds.midX : expandedSize.height - hullBounds.midY
    }
}

@MainActor private final class StaticDockContainer: NSView { override var isFlipped: Bool { true } }

/// Self-test host. Reuses the Dock projection/edge controller and the application's one feed/store.
/// No working effects, entrance animation, global input monitor, reader activation or service registration.
@MainActor public final class StaticDockPreviewHost: NSObject, CommunityCompanionVisibility, NSMenuDelegate {
    public typealias Appearance = @MainActor (DockInstrumentView, [DockInstrumentReading], SettingsPreferences) throws -> StaticDockGeometry
    public private(set) var isVisible = false
    public var visibilityChanged: (() -> Void)?
    private func reportVisibility(_ visible: Bool) {
        guard visible != isVisible else { return }
        isVisible = visible; visibilityChanged?()
    }
    public var showConsole: (() -> Void)?
    public var showSettings: (() -> Void)?
    public var catalogueChanged: (([SettingsSubscription]) -> Void)?
    public var displayChoicesChanged: (([SettingsDisplayChoice]) -> Void)?
    public var commitDisplayPlacement: ((String, SettingsDockEdge, Double) -> Void)?
    public var commitPlacement: ((SettingsDockEdge, Double) -> Void)?
    private let appearance: Appearance?
    private let sliverParameters: DockSliverParameters
    private let currentDate: @MainActor () -> Date
    private let createsNativePanels: Bool
    private let nativeEnvironment: (@MainActor () -> DockEdgeEnvironment)?
    private let elapsedClock: (() -> TimeInterval)?
    private let edgeScheduling: (any DockEdgeScheduling)?
    var edgePresentation: DockEdgePresentation? { edge.presentation }
    func refreshPresence() { edge.refresh() }
    private var application: SettingsApplication?
    private var snapshot: JoinedSnapshot?, diagnostics = StoreDiagnostics()
    private var model: CommunityDockSnapshot?
    private var preferences = SettingsPreferences()
    private var catalogueKey = ""
    private var geometry = StaticDockGeometry(hoverRects: [])
    private var permitted = false, retired = false, rendering = false, menuOpen = false
    private var sliverPrepared = false
    private var preparedSliverGeometrySize: CGSize?
    private var rebuildPending = false
    private var inputGeneration: UInt64 = 0, cardGeneration: UInt64 = 0
    private var panel: NSPanel?, cardPanel: NSPanel?
    private var lastDisplayChoices: [SettingsDisplayChoice] = []
    private var edgeGeometries: [DockEdge: StaticDockGeometry] = [:]
    private var edgeViews: [DockEdge: DockInstrumentView] = [:]
    private let alternateViews = [DockInstrumentView(frame: .zero), DockInstrumentView(frame: .zero)]
    private var outlinePanel: NSPanel?
    private let outlineView = DockSnapOutlineView()
    private var cardID: String?
    public let dockView = DockInstrumentView(frame: .zero)
    private let sliver = DockSliverView(frame: .zero)
    private let empty = NSTextField(wrappingLabelWithString: "No local subscriptions / 暂无本地订阅")
    let card = DockCardView(frame: .zero)
    private let container = StaticDockContainer()
    private let consoleButton = NSButton(frame: .zero)
    private lazy var edge = makeEdge(policy: visibilityPolicy)

    public convenience init(appearance: Appearance? = nil, sliverParameters: DockSliverParameters = .current, currentDate: @escaping @MainActor () -> Date = { Date() }) {
        self.init(appearance: appearance, currentDate: currentDate, createsNativePanels: true, sliverParameters: sliverParameters)
    }
    /// In-memory publication seam for the same host callbacks; no NSWindow is created in checks.
    init(appearance: Appearance? = nil, currentDate: @escaping @MainActor () -> Date, createsNativePanels: Bool,
         sliverParameters: DockSliverParameters = .current, nativeEnvironment: (@MainActor () -> DockEdgeEnvironment)? = nil,
         elapsedClock: (() -> TimeInterval)? = nil, edgeScheduling: (any DockEdgeScheduling)? = nil) {
        self.nativeEnvironment = nativeEnvironment; self.elapsedClock = elapsedClock; self.edgeScheduling = edgeScheduling
        self.sliverParameters = sliverParameters
        self.appearance = appearance; self.currentDate = currentDate; self.createsNativePanels = createsNativePanels
        super.init()
        consoleButton.title = ""; consoleButton.isBordered = false; consoleButton.isTransparent = true
        consoleButton.target = self; consoleButton.action = #selector(openConsole)
        consoleButton.setAccessibilityLabel("Open console / 打开控制台")
        container.addSubview(dockView); container.addSubview(consoleButton)
        dockView.onAction = { [weak self] action in
            guard let self, self.permitted, !self.retired, !self.rendering else { return }
            switch action {
            case .subscription(let id), .notice(let id): self.showCard(id)
            case .overflow: self.showConsole?()
            }
        }
        dockView.permitsAction = { [weak self] _, source in
            guard let self else { return false }
            return self.acceptsInstrumentAction(from: self.dockView, source: source)
        }
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
    private func connectEdge() {
        edge.onPresent = { [weak self] value in self?.present(value) }
        edge.onCommittedPlacement = { [weak self] value in
            guard let self, let next = SettingsDockEdge(rawValue: String(describing: value.edge)) else { return }
            if let id = value.displayID { self.commitDisplayPlacement?(id, next, value.alongFraction) }
            self.commitPlacement?(next, value.alongFraction)
        }
    }
    public func apply(_ value: SettingsApplication) {
        guard !retired, value.snapshot.revision >= (application?.snapshot.revision ?? 0) else { return }
        inputGeneration &+= 1
        application = value
        let oldReveal = preferences.revealMilliseconds
        preferences = value.snapshot.preferences
        if !preferences.showDock { dismissCard() }
        if preferences.revealMilliseconds != oldReveal {
            let saved = edge.preference
            edge.stop(); edge.onPresent = nil; edge.onCommittedPlacement = nil
            edge = makeEdge(preference: saved, policy: visibilityPolicy)
            connectEdge()
        }
        rebuild()
    }
    public func render(snapshot: JoinedSnapshot?, diagnostics: StoreDiagnostics) {
        guard !retired else { return }
        inputGeneration &+= 1
        self.snapshot = snapshot; self.diagnostics = diagnostics
        rebuild()
    }
    public func setPresentationAllowed(_ allowed: Bool) {
        guard !retired else { return }
        inputGeneration &+= 1
        permitted = allowed
        if allowed { rebuild(); edge.start() }
        else { edge.stop(); dismissCard(); panel?.orderOut(nil); outlinePanel?.orderOut(nil) }
    }
    private func rebuild() {
        guard !retired, application != nil else { return }
        rebuildPending = true
        guard !rendering else { return }
        rendering = true
        defer { rendering = false }
        while rebuildPending, !retired {
            rebuildPending = false
            rebuildPass(inputGeneration)
        }
    }
    private func passIsCurrent(_ generation: UInt64) -> Bool {
        guard !retired else { dockView.dispose(); return false }
        guard inputGeneration == generation else { rebuildPending = true; return false }
        return true
    }
    private func rebuildPass(_ generation: UInt64) {
        let choices = NSScreen.screens.enumerated().map { index, screen in
            SettingsDisplayChoice(id: displayID(screen, index: index), name: screen.localizedName)
        }
        if choices != lastDisplayChoices { lastDisplayChoices = choices; displayChoicesChanged?(choices) }
        guard passIsCurrent(generation) else { return }
        let passPreferences = preferences
        let now = currentDate(), next = CommunityDockSnapshot(snapshot: snapshot, diagnostics: diagnostics, now: now)
        let key = next.subscriptions.map { "\($0.id)|\($0.name.english)|\($0.source)" }.joined(separator: "\n")
        if key != catalogueKey { catalogueKey = key; catalogueChanged?(next.subscriptions) }
        guard passIsCurrent(generation) else { return }
        let byID = Dictionary(uniqueKeysWithValues: next.inputs.map { ($0.id, $0) })
        let order = (try? passPreferences.presentedSubscriptionIDs(next.inputs.map(\.id))) ?? next.inputs.map(\.id)
        let rows = order.compactMap { byID[$0] }.compactMap { input -> DockInstrumentReading? in
            let value = passPreferences.applying(to: input)
            return try? DockInstrumentProjection.evaluate(value, now: now, redBelow: Double(passPreferences.redBelow))
        }
        dockView.requestedNozzleDiameter = passPreferences.size.nozzleDiameter
        alternateViews.forEach { $0.requestedNozzleDiameter = passPreferences.size.nozzleDiameter }
        let backingScale = destinationBackingScale()
        dockView.presentationBackingScale = backingScale
        alternateViews.forEach { $0.presentationBackingScale = backingScale }
        do {
            if let appearance {
                let candidate = try appearance(dockView, rows, passPreferences)
                guard passIsCurrent(generation) else { return }
                geometry = candidate
                geometry.scaleRegistration(by: dockView.appliedGeometryScale)
                try registerSliver(&geometry, view: dockView, preferences: passPreferences)
            }
            else {
                try dockView.applyCommunity(rows, locale: passPreferences.language.rawValue)
                geometry = .init(hoverRects: [dockView.bounds])
            }
        } catch {
            guard passIsCurrent(generation) else { return }
            if appearance != nil {
                // A transient official refresh must not replace the supplied hull with a theme rectangle.
                dockView.retireOfficialPresentation()
            } else {
                try? dockView.applyCommunity(rows, locale: passPreferences.language.rawValue)
                geometry = .init(hoverRects: [dockView.bounds])
            }
        }
        guard passIsCurrent(generation) else { return }
        model = next
        if rows.isEmpty && appearance == nil {
            let factor = passPreferences.size.nozzleDiameter / DockNozzleDiameters.current.medium
            dockView.setFrameSize(CGSize(width: 210 * factor, height: 60 * factor))
            empty.font = .systemFont(ofSize: 13 * factor)
            empty.frame = dockView.bounds.insetBy(dx: 10 * factor, dy: 10 * factor)
            if empty.superview == nil { dockView.addSubview(empty) }
        } else { empty.removeFromSuperview() }
        if appearance == nil {
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
        // Resolve every orientation before tracking. Pointer samples reuse prepared geometry/pixels.
        if createsNativePanels, let appearance {
            for (view, orientation) in zip(alternateViews, DockEdgeGeometry.allowedEdges.filter { $0 != selected }) {
                var oriented = passPreferences
                oriented.dockEdge = settingsEdge(orientation)
                do {
                    var candidate = try appearance(view, rows, oriented)
                    candidate.scaleRegistration(by: view.appliedGeometryScale)
                    try registerSliver(&candidate, view: view, preferences: oriented)
                    guard passIsCurrent(generation) else { return }
                    view.onAction = dockView.onAction
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
        if sliverPrepared {
            let logical = sliverLogicalSize
            // AppKit can round the owned window to whole backing pixels. A data-only
            // update must keep that actual surface size until registered geometry changes.
            let size = preparedSliverGeometrySize == logical ? sliver.frame.size : logical
            _ = try? prepareSliver(size: size)
        }
        let primary = environment().primaryDisplayID ?? "primary-unavailable"
        let selectedID = passPreferences.dockDisplayID ?? primary
        let preference = DockEdgePreference(displayID: passPreferences.followActiveDisplay ? nil : selectedID,
            edge: selected, alongFraction: passPreferences.dockAlongFraction)
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
            return DockEdgeController(preference: preference, policy: policy, clock: elapsedClock, scheduler: edgeScheduling, read: read)
        }
        return DockEdgeController(preference: preference, policy: policy, read: read)
    }
    private func environment() -> DockEdgeEnvironment {
        let native: DockEdgeEnvironment
        if let nativeEnvironment { native = nativeEnvironment() }
        else {
            let displays = NSScreen.screens.enumerated().map { index, screen in
                DockDisplayArea(id: displayID(screen, index: index), frame: screen.frame, visibleFrame: screen.visibleFrame)
            }
            var presence = DockPresence()
            presence.mouseButtonDown = NSEvent.pressedMouseButtons != 0
            native = .init(displays: displays, layouts: [], primaryDisplayID: displays.first?.id,
                           pointer: NSEvent.mouseLocation, presence: presence)
        }
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
        presence.allowedOverFullscreen = native.presence.allowedOverFullscreen || preferences.showOverFullscreen
        presence.menuActuallyOpen = menuOpen; presence.cardPinned = cardPanel?.isVisible == true
        // Preview does not claim to detect another app's fullscreen state or activate another Space.
        return .init(displays: displays, layouts: layouts, primaryDisplayID: native.primaryDisplayID,
            pointer: native.pointer, presence: presence, cardFrame: cardPanel?.isVisible == true ? cardPanel?.frame : nil)
    }
    private func destinationBackingScale() -> Int {
        let screens = NSScreen.screens, env = environment()
        let primary = screens.first.map { displayID($0, index: 0) }
        let preference = DockEdgePreference(displayID: preferences.followActiveDisplay ? nil : preferences.dockDisplayID ?? primary,
            edge: nativeEdge(preferences.dockEdge), alongFraction: preferences.dockAlongFraction)
        let placement = try? DockEdgeGeometry.resolve(preference: preference, displays: env.displays, layouts: env.layouts,
            pointer: env.pointer, primaryID: primary, wakeDepth: visibilityPolicy.wakeDepth)
        let target = placement?.displayID ?? preference.displayID
        let selected = screens.enumerated().first { displayID($0.element, index: $0.offset) == target }?.element
            ?? screens.first { preferences.followActiveDisplay && $0.frame.contains(NSEvent.mouseLocation) } ?? screens.first
        return min(2, max(1, Int(selected?.backingScaleFactor ?? 1)))
    }
    private func displayID(_ screen: NSScreen, index: Int) -> String {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return "session.\(index)" }
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() else { return "session.\(number)" }
        return CFUUIDCreateString(nil, uuid) as String
    }
    private func acceptsInstrumentAction(from view: DockInstrumentView, source: DockActionSource) -> Bool {
        guard !createsNativePanels || view.superview === container else { return false }
        guard edge.acceptsPress(keyboardOrAccessibility: source == .accessibility) else { return false }
        // The gate samples current geometry and can synchronously switch the displayed edge.
        return !createsNativePanels || view.superview === container
    }
    private func nativeEdge(_ value: SettingsDockEdge) -> DockEdge { value == .left ? .left : value == .bottom ? .bottom : .right }
    private func settingsEdge(_ value: DockEdge) -> SettingsDockEdge { value == .left ? .left : value == .bottom ? .bottom : .right }
    private var visibilityPolicy: DockVisibilityPolicy {
        var value = DockVisibilityPolicy()
        value.revealDwell = Double(preferences.revealMilliseconds) / 1000
        value.wakeDepth = sliverParameters.trackingDepth
        return value
    }
    private func registerSliver(_ geometry: inout StaticDockGeometry, view: DockInstrumentView, preferences: SettingsPreferences) throws {
        guard let hull = view.registeredHullBounds else { return }
        let scales = sliverParameters.sizeScales
        let factor = preferences.size == .small ? scales.small : preferences.size == .large ? scales.large : scales.medium
        try geometry.registerSliver(hullBounds: hull, expandedSize: view.frame.size, edge: preferences.dockEdge,
                                    parameters: sliverParameters, scale: factor)
    }
    private var presentationGeometry: StaticDockGeometry {
        edge.presentation?.placement.flatMap { edgeGeometries[$0.edge] } ?? geometry
    }
    private func makePanel() -> NSPanel {
        let value = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        value.isFloatingPanel = true; value.level = .floating; value.isOpaque = false
        value.backgroundColor = .clear; value.hasShadow = false; value.hidesOnDeactivate = false
        value.isReleasedWhenClosed = false
        return value
    }
    private func present(_ value: DockEdgePresentation) {
        guard createsNativePanels else { return }
        guard permitted, !retired, let frame = value.paintedFrame else { panel?.orderOut(nil); outlinePanel?.orderOut(nil); reportVisibility(false); return }
        if panel == nil { panel = makePanel() }
        guard let panel else { return }
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
            let regions = current.dragRegions ?? view.registeredDragRegions(excluding: current.consoleButton.map { [$0] } ?? [])
            if let regions { edge.dragRegions = regions; view.backgroundDragDelegate = edge }
            else { view.backgroundDragDelegate = nil; edge.dragRegions = nil }
            content = container
        case .sliver:
            do { content = try prepareSliver(size: panel.frame.size) }
            catch { panel.orderOut(nil); reportVisibility(false); return }
        case .suppressed: panel.orderOut(nil); outlinePanel?.orderOut(nil); reportVisibility(false); return
        }
        if panel.contentView !== content { panel.contentView = content }
        content.menu = menu(); content.subviews.forEach { $0.menu = content.menu }
        if let preview = value.snapPreview, let view = edgeViews[preview.edge], let path = view.registeredHullPath {
            if outlinePanel == nil { outlinePanel = makePanel(); outlinePanel?.ignoresMouseEvents = true; outlinePanel?.contentView = outlineView }
            outlineView.path = path
            outlinePanel?.setFrame(preview.frame, display: true); outlinePanel?.orderFrontRegardless()
        } else { outlinePanel?.orderOut(nil) }
        panel.displayIfNeeded(); panel.orderFrontRegardless()
        reportVisibility(panel.isVisible)
    }
    private var sliverLogicalSize: CGSize {
        let current = presentationGeometry
        return (edge.presentation?.placement?.edge ?? nativeEdge(preferences.dockEdge)) == .bottom
            ? CGSize(width: current.sliverLength, height: current.sliverThickness)
            : CGSize(width: current.sliverThickness, height: current.sliverLength)
    }
    /// Uses the same bounded view preparation in native presentation and no-window checks.
    func prepareSliver(size: CGSize) throws -> DockSliverView {
        guard !retired else { throw DockArtworkError.invalidManifest }
        do {
            let geometry = presentationGeometry
            let nativeScale = panel.map { min(2, max(1, Int($0.backingScaleFactor))) } ?? geometry.sliverScale
            try sliver.apply(image: geometry.sliverImage, logicalSize: size, scale: min(nativeScale, geometry.sliverScale),
                             accessibilityLabel: "Show Dock / 显示挂件")
            sliverPrepared = true; preparedSliverGeometrySize = sliverLogicalSize
            return sliver
        } catch { sliverPrepared = false; preparedSliverGeometrySize = nil; throw error }
    }
    private func menu() -> NSMenu {
        let menu = NSMenu(); menu.delegate = self
        for (title, action) in [("Console… / 控制台…", #selector(openConsole)), ("Settings… / 设置…", #selector(openSettings))] {
            let item = menu.addItem(withTitle: title, action: action, keyEquivalent: ""); item.target = self
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit preview / 退出自测版", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }
    public func menuWillOpen(_ menu: NSMenu) { menuOpen = true; edge.refresh() }
    public func menuDidClose(_ menu: NSMenu) { menuOpen = false; edge.refresh() }
    @objc private func openConsole() { guard permitted, !retired else { return }; dismissCard(); showConsole?() }
    @objc private func openSettings() { guard permitted, !retired else { return }; showSettings?() }
    @objc private func displaysChanged() { guard permitted, !retired else { return }; inputGeneration &+= 1; rebuild(); edge.refresh() }
    private func showCard(_ id: String) {
        guard permitted, !retired, preferences.showDock,
              (try? preferences.presentedSubscriptionIDs(model?.inputs.map(\.id) ?? []))?.contains(id) == true,
              let input = model?.inputs.first(where: { $0.id == id }),
              let content = try? DockCardProjection.content(input: preferences.applying(to: input),
                revision: application?.snapshot.revision ?? 0,
                stateLabel: input.dataState == .fresh ? "Local reading / 本地读数" : "Unavailable or stale / 不可用或已过期",
                enterLabel: "Console / 控制台", dismissLabel: "Close / 关闭", at: currentDate()) else { dismissCard(); return }
        cardGeneration &+= 1
        let token = cardGeneration, feed = inputGeneration
        cardID = id; card.isHidden = false
        card.permitsAction = { [weak self] id, revision in self?.cardIsCurrent(id, revision: revision, token: token, feed: feed) == true }
        card.onEnter = { [weak self] id, revision in
            guard let self, self.cardIsCurrent(id, revision: revision, token: token, feed: feed) else { return }
            self.dismissCard()
            guard self.permitted, !self.retired else { return }
            self.showConsole?()
        }
        card.onDismiss = { [weak self] in
            guard let self, self.cardGeneration == token, self.inputGeneration == feed else { return }
            self.dismissCard()
        }
        do { try card.apply(content, pinned: true) } catch { dismissCard(); return }
        guard createsNativePanels else { return }
        if cardPanel == nil { cardPanel = makePanel() }
        guard let cardPanel, let anchor = panel?.frame, let screen = NSScreen.screens.first(where: { $0.frame.intersects(anchor) }) else { return }
        let size = card.frame.size, safe = screen.visibleFrame
        let x = preferences.dockEdge == .left ? anchor.maxX + 8 : anchor.minX - size.width - 8
        let y = preferences.dockEdge == .bottom ? anchor.maxY + 8 : anchor.midY - size.height / 2
        cardPanel.contentView = card
        cardPanel.setFrame(.init(x: max(safe.minX, min(x, safe.maxX-size.width)), y: max(safe.minY, min(y, safe.maxY-size.height)), width: size.width, height: size.height), display: true)
        cardPanel.orderFrontRegardless(); edge.refresh()
    }
    private func cardIsCurrent(_ id: String, revision: UInt64, token: UInt64, feed: UInt64) -> Bool {
        guard permitted, !retired, !rendering, preferences.showDock, !card.isHidden,
              cardID == id, cardGeneration == token, inputGeneration == feed,
              application?.snapshot.revision == revision,
              model?.inputs.contains(where: { $0.id == id }) == true,
              (try? preferences.presentedSubscriptionIDs(model?.inputs.map(\.id) ?? []))?.contains(id) == true else { return false }
        return !createsNativePanels || cardPanel?.isVisible == true
    }
    private func dismissCard() {
        cardGeneration &+= 1; cardID = nil; card.isHidden = true
        card.dispose(); cardPanel?.orderOut(nil)
    }
    public func close() {
        guard !retired else { return }; inputGeneration &+= 1; retired = true; permitted = false
        dismissCard()
        NotificationCenter.default.removeObserver(self)
        edge.stop(); edge.onPresent = nil; edge.onCommittedPlacement = nil
        dockView.onNeedsFreshPresentation = nil
        dockView.dispose(); alternateViews.forEach { $0.dispose() }; sliver.dispose(); card.dispose()
        edgeViews = [:]; edgeGeometries = [:]; outlinePanel?.orderOut(nil); outlinePanel = nil
        panel?.orderOut(nil); cardPanel?.orderOut(nil); panel = nil; cardPanel = nil
        reportVisibility(false); visibilityChanged = nil
        showConsole = nil; showSettings = nil; catalogueChanged = nil; commitPlacement = nil; commitDisplayPlacement = nil; displayChoicesChanged = nil
    }
}
