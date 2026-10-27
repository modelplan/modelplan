// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanCore
import ModelPlanDock
import ModelPlanSettings
import ModelPlanCommunityHost

/// Geometry returned by an injected appearance, already scaled in view-local points.
public struct StaticDockGeometry {
    public var hoverRects: [CGRect]
    public var sliverLength: CGFloat
    public var sliverThickness: CGFloat
    public var consoleButton: CGRect?
    public var dragRegions: DockBackgroundDragRegions?
    public init(hoverRects: [CGRect], sliverLength: CGFloat = 52, sliverThickness: CGFloat = 4, consoleButton: CGRect? = nil, dragRegions: DockBackgroundDragRegions? = nil) {
        self.hoverRects = hoverRects; self.sliverLength = sliverLength; self.sliverThickness = sliverThickness
        self.consoleButton = consoleButton; self.dragRegions = dragRegions
    }
}

@MainActor private final class StaticDockContainer: NSView { override var isFlipped: Bool { true } }

/// Self-test host. Reuses the Dock projection/edge controller and the application's one feed/store.
/// No working effects, entrance animation, global input monitor, reader activation or service registration.
@MainActor public final class StaticDockPreviewHost: NSObject, CommunityCompanionSurface, NSMenuDelegate {
    public typealias Appearance = @MainActor (DockInstrumentView, [DockInstrumentReading], SettingsPreferences) throws -> StaticDockGeometry
    public var showConsole: (() -> Void)?
    public var showSettings: (() -> Void)?
    public var catalogueChanged: (([SettingsSubscription]) -> Void)?
    public var commitPlacement: ((SettingsDockEdge, Double) -> Void)?
    private let appearance: Appearance?
    private let currentDate: @MainActor () -> Date
    private var application: SettingsApplication?
    private var snapshot: JoinedSnapshot?, diagnostics = StoreDiagnostics()
    private var model: CommunityDockSnapshot?
    private var preferences = SettingsPreferences()
    private var catalogueKey = ""
    private var geometry = StaticDockGeometry(hoverRects: [])
    private var permitted = false, retired = false, rendering = false, menuOpen = false
    private var panel: NSPanel?, cardPanel: NSPanel?
    private var fixedDisplayID: String?
    private var cardID: String?
    public let dockView = DockInstrumentView(frame: .zero)
    private let sliver = DockSliverView(frame: .zero)
    private let empty = NSTextField(wrappingLabelWithString: "No local subscriptions / 暂无本地订阅")
    private let card = DockCardView(frame: .zero)
    private let container = StaticDockContainer()
    private let consoleButton = NSButton(frame: .zero)
    private lazy var edge = DockEdgeController(read: { [weak self] in self?.environment() ?? .init(displays: [], layouts: []) })

    public init(appearance: Appearance? = nil, currentDate: @escaping @MainActor () -> Date = { Date() }) {
        self.appearance = appearance; self.currentDate = currentDate
        super.init()
        consoleButton.title = ""; consoleButton.isBordered = false; consoleButton.isTransparent = true
        consoleButton.target = self; consoleButton.action = #selector(openConsole)
        consoleButton.setAccessibilityLabel("Open console / 打开控制台")
        container.addSubview(dockView); container.addSubview(consoleButton)
        dockView.onAction = { [weak self] action in
            guard let self, self.permitted, !self.retired else { return }
            switch action {
            case .subscription(let id), .notice(let id): self.showCard(id)
            case .overflow: self.showConsole?()
            }
        }
        dockView.permitsAction = { [weak self] _, source in self?.edge.acceptsPress(keyboardOrAccessibility: source == .accessibility) ?? false }
        sliver.onReveal = { [weak self] in self?.edge.reveal() }
        connectEdge()
        card.onEnter = { [weak self] _, _ in self?.dismissCard(); self?.showConsole?() }
        card.onDismiss = { [weak self] in self?.dismissCard() }
        NotificationCenter.default.addObserver(self, selector: #selector(displaysChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }
    private func connectEdge() {
        edge.onPresent = { [weak self] value in self?.present(value) }
        edge.onCommittedPlacement = { [weak self] value in
            guard let self, let next = SettingsDockEdge(rawValue: String(describing: value.edge)) else { return }
            self.fixedDisplayID = value.displayID
            self.commitPlacement?(next, value.alongFraction)
        }
    }
    public func apply(_ value: SettingsApplication) {
        guard !retired, value.snapshot.revision >= (application?.snapshot.revision ?? 0) else { return }
        application = value
        let oldReveal = preferences.revealMilliseconds
        preferences = value.snapshot.preferences
        if !preferences.showDock { dismissCard() }
        if preferences.revealMilliseconds != oldReveal {
            let saved = edge.preference
            edge.stop(); edge.onPresent = nil; edge.onCommittedPlacement = nil
            edge = DockEdgeController(preference: saved, policy: value.effective.visibilityPolicy, read: { [weak self] in self?.environment() ?? .init(displays: [], layouts: []) })
            connectEdge()
        }
        rebuild()
    }
    public func render(snapshot: JoinedSnapshot?, diagnostics: StoreDiagnostics) {
        guard !retired else { return }
        self.snapshot = snapshot; self.diagnostics = diagnostics
        rebuild()
    }
    public func setPresentationAllowed(_ allowed: Bool) {
        guard !retired else { return }
        permitted = allowed
        if allowed { rebuild(); edge.start() }
        else { edge.stop(); dismissCard(); panel?.orderOut(nil) }
    }
    private func rebuild() {
        guard !retired, !rendering, application != nil else { return }
        rendering = true
        defer { rendering = false }
        let now = currentDate(), next = CommunityDockSnapshot(snapshot: snapshot, diagnostics: diagnostics, now: now)
        model = next
        let key = next.subscriptions.map { "\($0.id)|\($0.name.english)|\($0.source)" }.joined(separator: "\n")
        if key != catalogueKey { catalogueKey = key; catalogueChanged?(next.subscriptions) }
        let byID = Dictionary(uniqueKeysWithValues: next.inputs.map { ($0.id, $0) })
        let order = (try? preferences.presentedSubscriptionIDs(next.inputs.map(\.id))) ?? next.inputs.map(\.id)
        let rows = order.compactMap { byID[$0] }.compactMap { input -> DockInstrumentReading? in
            let value = preferences.applying(to: input)
            return try? DockInstrumentProjection.evaluate(value, now: now, redBelow: Double(preferences.redBelow))
        }
        do {
            if let appearance { geometry = try appearance(dockView, rows, preferences) }
            else {
                try dockView.applyCommunity(rows, locale: preferences.language.rawValue)
                geometry = .init(hoverRects: [dockView.bounds])
            }
        } catch {
            // A failed official renderer never leaves stale actionable pixels or fake readings.
            try? dockView.applyCommunity(rows, locale: preferences.language.rawValue)
            geometry = .init(hoverRects: [dockView.bounds])
        }
        if rows.isEmpty && appearance == nil {
            dockView.setFrameSize(CGSize(width: 210, height: 60))
            empty.frame = dockView.bounds.insetBy(dx: 10, dy: 10)
            if empty.superview == nil { dockView.addSubview(empty) }
        } else { empty.removeFromSuperview() }
        container.setFrameSize(dockView.frame.size)
        consoleButton.isHidden = geometry.consoleButton == nil
        if let rect = geometry.consoleButton { consoleButton.frame = rect }
        // Cross-edge drag requires every registered edge recipe; this preview changes edge in Settings.
        dockView.backgroundDragDelegate = nil
        edge.dragRegions = nil
        let edgeValue: DockEdge = preferences.dockEdge == .left ? .left : preferences.dockEdge == .bottom ? .bottom : .right
        if fixedDisplayID == nil, let screen = NSScreen.screens.first { fixedDisplayID = displayID(screen, index: 0) }
        edge.setPreference(.init(displayID: preferences.followActiveDisplay ? nil : fixedDisplayID, edge: edgeValue, alongFraction: edge.preference.alongFraction))
        if let cardID { if order.contains(cardID) { showCard(cardID) } else { dismissCard() } }
        if permitted { edge.start(); edge.refresh() }
    }
    private func environment() -> DockEdgeEnvironment {
        let screens = NSScreen.screens
        let displays = screens.enumerated().map { index, screen in
            DockDisplayArea(id: displayID(screen, index: index), frame: screen.frame, visibleFrame: screen.visibleFrame)
        }
        let selectedEdge: DockEdge = preferences.dockEdge == .left ? .left : preferences.dockEdge == .bottom ? .bottom : .right
        let layouts = displays.map { display in
            DockEdgeLayout(displayID: display.id, edge: selectedEdge, expandedSize: dockView.frame.size,
                sliverLength: geometry.sliverLength, sliverThickness: geometry.sliverThickness,
                hoverRects: geometry.hoverRects.isEmpty ? [dockView.bounds] : geometry.hoverRects)
        }
        var presence = DockPresence()
        presence.enabled = preferences.showDock; presence.autoHide = preferences.autoHide
        presence.lifecycleActive = permitted && !retired; presence.mouseButtonDown = NSEvent.pressedMouseButtons != 0
        presence.menuActuallyOpen = menuOpen; presence.cardPinned = cardPanel?.isVisible == true
        // Preview does not claim to detect another app's fullscreen state or activate another Space.
        let pointer = preferences.followActiveDisplay ? NSEvent.mouseLocation : nil
        return .init(displays: displays, layouts: layouts, primaryDisplayID: displays.first?.id,
            pointer: pointer ?? NSEvent.mouseLocation, presence: presence, cardFrame: cardPanel?.isVisible == true ? cardPanel?.frame : nil)
    }
    private func displayID(_ screen: NSScreen, index: Int) -> String {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue ?? "display.\(index)"
    }
    private func makePanel() -> NSPanel {
        let value = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        value.isFloatingPanel = true; value.level = .floating; value.isOpaque = false
        value.backgroundColor = .clear; value.hasShadow = false; value.hidesOnDeactivate = false
        value.isReleasedWhenClosed = false
        return value
    }
    private func present(_ value: DockEdgePresentation) {
        guard permitted, !retired, let frame = value.paintedFrame else { panel?.orderOut(nil); return }
        if panel == nil { panel = makePanel() }
        guard let panel else { return }
        panel.collectionBehavior = preferences.showOverFullscreen ? [.canJoinAllSpaces, .fullScreenAuxiliary] : [.canJoinAllSpaces]
        let content: NSView
        switch value.state {
        case .expanded: content = container
        case .sliver:
            try? sliver.apply(image: nil, logicalSize: frame.size, scale: 1, accessibilityLabel: "Show Dock / 显示挂件")
            content = sliver
        case .suppressed: panel.orderOut(nil); return
        }
        if panel.contentView !== content { panel.contentView = content }
        content.menu = menu(); dockView.menu = content.menu
        panel.setFrame(frame, display: true); panel.orderFrontRegardless()
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
    @objc private func displaysChanged() { guard permitted, !retired else { return }; edge.refresh() }
    private func showCard(_ id: String) {
        guard permitted, !retired, preferences.showDock, let input = model?.inputs.first(where: { $0.id == id }),
              let content = try? DockCardProjection.content(input: preferences.applying(to: input),
                revision: application?.snapshot.revision ?? 0,
                stateLabel: input.dataState == .fresh ? "Local reading / 本地读数" : "Unavailable or stale / 不可用或已过期",
                enterLabel: "Console / 控制台", dismissLabel: "Close / 关闭", at: currentDate()) else { dismissCard(); return }
        cardID = id
        try? card.apply(content, pinned: true)
        if cardPanel == nil { cardPanel = makePanel() }
        guard let cardPanel, let anchor = panel?.frame, let screen = NSScreen.screens.first(where: { $0.frame.intersects(anchor) }) else { return }
        let size = card.frame.size, safe = screen.visibleFrame
        let x = preferences.dockEdge == .left ? anchor.maxX + 8 : anchor.minX - size.width - 8
        let y = preferences.dockEdge == .bottom ? anchor.maxY + 8 : anchor.midY - size.height / 2
        cardPanel.contentView = card
        cardPanel.setFrame(.init(x: max(safe.minX, min(x, safe.maxX-size.width)), y: max(safe.minY, min(y, safe.maxY-size.height)), width: size.width, height: size.height), display: true)
        cardPanel.orderFrontRegardless(); edge.refresh()
    }
    private func dismissCard() { cardID = nil; cardPanel?.orderOut(nil) }
    public func close() {
        guard !retired else { return }; retired = true; permitted = false
        NotificationCenter.default.removeObserver(self)
        edge.stop(); edge.onPresent = nil; edge.onCommittedPlacement = nil
        dockView.dispose(); sliver.dispose(); card.dispose()
        panel?.orderOut(nil); cardPanel?.orderOut(nil); panel = nil; cardPanel = nil
        showConsole = nil; showSettings = nil; catalogueChanged = nil; commitPlacement = nil
    }
}
