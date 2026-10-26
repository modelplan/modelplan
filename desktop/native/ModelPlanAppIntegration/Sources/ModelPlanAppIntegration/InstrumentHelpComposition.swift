// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanInstruments
import ModelPlanSettings

/// Copy and a current overlay-local anchor supplied by the app's selected appearance package.
/// No private wording, material, geometry or nine-kind admission policy is duplicated here.
public struct HelpHintContent: Equatable, Sendable {
    public let anchorID: String, text: String, dismissTitle: String
    public init(anchorID: String, text: String, dismissTitle: String) {
        self.anchorID = anchorID; self.text = text; self.dismissTitle = dismissTitle
    }
}

/// Concrete adapter to M4's existing layer. It never owns an arbiter, deadline or persisted ledger.
@MainActor public final class InstrumentHelpOverlay: HintOverlayPresenting {
    public let layer: HelpUILayerView
    private let visibility: @MainActor (HelpUILayerView, CGRect) -> Bool
    private var base: HelpUIRenderInput?
    private var content: [FirstUseHintKind: HelpHintContent] = [:]
    private var currentOffer: HintOffer?
    private var trialSource: InstrumentHintSourceSnapshot?, offeredTrial: InstrumentHintSourceSnapshot?
    private var generation: UInt64 = 0
    private var disposed = false
    public init(layer: HelpUILayerView,
                visibility: (@MainActor (HelpUILayerView, CGRect) -> Bool)? = nil) {
        self.layer = layer; self.visibility = visibility ?? Self.appKitVisible
    }
    /// A necessary live AppKit visibility check, not pixel/physical acceptance or a capture bypass.
    public static func appKitVisible(_ layer: HelpUILayerView, _ rect: CGRect) -> Bool {
        guard let window = layer.window, window.isVisible, !window.isMiniaturized,
              window.alphaValue > 0, window.occlusionState.contains(.visible),
              !layer.isHiddenOrHasHiddenAncestor, layer.visibleRect.contains(rect) else { return false }
        var ancestor: NSView? = layer
        while let view = ancestor { if view.alphaValue <= 0 { return false }; ancestor = view.superview }
        return true
    }
    /// trialSource explicitly binds the app-converted overlay anchor to the current P09 source.
    /// An unbound/mismatched trial is ineligible; it must not point at an arbitrary other fader.
    public func updateSurface(_ input: HelpUIRenderInput, content: [FirstUseHintKind: HelpHintContent],
                              trialSource: InstrumentHintSourceSnapshot? = nil) {
        guard !disposed else { return }
        generation &+= 1
        var clean = input; clean.firstUse = nil // Only the sole arbiter may supply a first-use token.
        if base?.sessionID != clean.sessionID || (currentOffer?.kind == .trial && offeredTrial != trialSource) {
            currentOffer = nil; offeredTrial = nil
        }
        self.trialSource = trialSource
        base = clean; self.content = content
        renderCurrent()
    }
    public func placeableKinds(context: HintContext, trial: InstrumentHintSourceSnapshot?) -> Set<FirstUseHintKind> {
        guard !disposed, let base, base.active, base.map.mode == .hidden,
              context.cockpitOpen == base.sessionID else { return [] }
        // This layer belongs to the cockpit. Dock-only offers need the actual Dock overlay binding.
        return Set(content.keys.filter { kind in
            kind != .ignition && kind != .drag && (kind != .trial || (trial != nil && trial == trialSource))
                && content[kind].map { item in base.anchors.contains { $0.id == item.anchorID && $0.visible } } == true
        })
    }
    public func showAndVerify(_ offer: HintOffer, trial: InstrumentHintSourceSnapshot?) -> Bool {
        guard !disposed, base?.active == true, base?.map.mode == .hidden, content[offer.kind] != nil else { return false }
        guard offer.kind != .trial || (trial != nil && trial == trialSource) else { return false }
        generation &+= 1; let token = generation; currentOffer = offer
        offeredTrial = offer.kind == .trial ? trial : nil
        renderCurrent()
        return verify(offerID: offer.id, generation: token)
    }
    public func updateAndVerify(_ presentation: HintPresentation) -> Bool {
        guard currentOffer == presentation.offer, !disposed else { return false }
        generation &+= 1; let token = generation
        if base != nil { base!.reduceMotion = presentation.reducedMotion }
        renderCurrent()
        return verify(offerID: presentation.offer.id, generation: token)
    }
    public func hide(offerID: UUID) {
        guard !disposed, currentOffer?.id == offerID else { return }
        generation &+= 1; currentOffer = nil; offeredTrial = nil; renderCurrent()
    }
    private func renderCurrent() {
        guard var input = base else { return }
        if let offer = currentOffer, let copy = content[offer.kind] {
            input.firstUse = .init(offerID: offer.id, anchorID: copy.anchorID, text: copy.text, dismissTitle: copy.dismissTitle)
        }
        layer.update(input)
    }
    private func verify(offerID: UUID, generation token: UInt64) -> Bool {
        guard !disposed, generation == token, currentOffer?.id == offerID,
              let base, base.active, base.map.mode == .hidden,
              let input = layer.input, input.sessionID == base.sessionID,
              input.firstUse?.offerID == offerID, let placement = layer.presentation?.card,
              placement.identity == .firstUse(offerID),
              base.anchors.contains(where: { $0.id == placement.anchorID && $0.visible }),
              layer.bounds.contains(placement.frame) else { return false }
        let visible = visibility(layer, placement.frame)
        // Visibility/recipe callbacks can synchronously replace, suspend or dispose the app surface.
        return visible && !disposed && generation == token && currentOffer?.id == offerID
            && layer.input == input && layer.presentation?.card == placement
    }
    public func dispose() {
        guard !disposed else { return }; disposed = true; generation &+= 1
        currentOffer = nil; offeredTrial = nil; trialSource = nil; base = nil; content = [:]; layer.dispose()
    }
}

/// Installs the editor observer before the asynchronous store restore. The editor permits one
/// save at a time, so at most one startup receipt can wait here; no queue/timer/second store.
@MainActor final class HelpSettingsReceiptConnection {
    private weak var target: InstrumentHelpComposition?
    private var ready = false
    private var failure: SettingsCommitDeliveryFailure?
    private var waiting: CheckedContinuation<Void, Never>?, completed: CheckedContinuation<Void, Never>?
    func receive(_ edit: SettingsCommittedEdit) async {
        let startup = !ready
        if startup { await withCheckedContinuation { waiting = $0 } }
        if failure == nil { await target?.consume(edit) }
        if startup { let done = completed; completed = nil; done?.resume() }
    }
    func connect(_ target: InstrumentHelpComposition) async {
        self.target = target; ready = true
        if let failure { target.receiptDeliveryFailed(failure) }
        let pending = waiting; waiting = nil; pending?.resume()
        if pending != nil { await withCheckedContinuation { completed = $0 } }
    }
    func failed(_ failure: SettingsCommitDeliveryFailure) {
        guard self.failure == nil else { return }; self.failure = failure
        target?.receiptDeliveryFailed(failure)
        let oldWaiting = waiting, oldCompleted = completed
        waiting = nil; completed = nil
        oldWaiting?.resume(); oldCompleted?.resume()
    }
}

/// App-scoped concrete P10→M4 binding, restored from the existing application's single SettingsStore.
/// The caller embeds layer in its real cockpit and supplies live context/geometry and released copy.
@MainActor public final class InstrumentHelpComposition {
    public let host: HintExecutionHost
    public let overlay: InstrumentHelpOverlay
    public var layer: HelpUILayerView { overlay.layer }
    /// Map/context actions stay with the owning surface; this module performs no URL/focus/window effect.
    public var onHelpAction: ((HelpUIAction) -> Void)?
    public var onSettingsReceipt: ((SettingsCommittedEdit, Bool) -> Void)?
    public private(set) var receiptDeliveryFailure: SettingsCommitDeliveryFailure?
    public var onReceiptDeliveryFailure: ((SettingsCommitDeliveryFailure) -> Void)?
    private let application: SettingsApplicationCoordinator
    private let uptime: () -> TimeInterval
    private var observer: UUID?
    private var refreshTask: Task<Void, Never>?
    private var previousInput: HelpUIRenderInput?
    private var generation: UInt64 = 0
    private var active = false, disposed = false, refreshAgain = false
    private init(application: SettingsApplicationCoordinator, host: HintExecutionHost,
                 overlay: InstrumentHelpOverlay, uptime: @escaping () -> TimeInterval, observer: UUID) {
        self.application = application; self.host = host; self.overlay = overlay; self.uptime = uptime
        self.observer = observer
        host.onPersisted = { [weak self] _ in self?.refreshEditor() }
    }
    public static func restored(application: SettingsApplicationCoordinator,
                                recipeProvider: HelpUIRecipeProvider? = nil,
                                scheduler: (any HintDeadlineScheduling)? = nil,
                                uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
                                visibility: (@MainActor (HelpUILayerView, CGRect) -> Bool)? = nil) async -> InstrumentHelpComposition {
        let connection = HelpSettingsReceiptConnection()
        let observer = application.editor.observeCommittedEdits(onFailure: { failure in connection.failed(failure) }) {
            edit in await connection.receive(edit)
        }
        if application.editor.snapshot == nil { await application.reload() }
        let layer = HelpUILayerView(recipeProvider: recipeProvider, elapsed: uptime)
        let overlay = InstrumentHelpOverlay(layer: layer, visibility: visibility)
        let host = await HintExecutionHost.restored(persistence: application.editor.store,
            scheduler: scheduler ?? HintCommonModeScheduler(uptime: uptime), overlay: overlay, uptime: uptime)
        let composition = InstrumentHelpComposition(application: application, host: host, overlay: overlay, uptime: uptime, observer: observer)
        // Do not expose a live surface until the startup receipt boundary has been applied.
        await connection.connect(composition)
        return composition
    }
    public func update(_ input: HelpUIRenderInput, content: [FirstUseHintKind: HelpHintContent], context: HintContext,
                       trialSource: InstrumentHintSourceSnapshot? = nil) throws {
        guard !disposed else { return }
        generation &+= 1; let token = generation; active = input.active
        let geometryChanged = previousInput?.sessionID != input.sessionID || previousInput?.anchors != input.anchors
            || previousInput?.viewport != input.viewport || previousInput?.profile != input.profile
        previousInput = input
        overlay.updateSurface(input, content: content, trialSource: trialSource)
        if geometryChanged { host.sources.cancelPendingRest(reason: .targetRemoval) }
        guard !disposed, generation == token else { return }
        layer.onAction = { [weak self] action in
            guard let self, !self.disposed, self.active, self.generation == token else { return }
            if case .dismissHint(let id, _) = action {
                guard self.host.hints.visible?.offer.id == id || self.host.hints.offered?.id == id else { return }
                self.host.dismiss()
            } else { self.onHelpAction?(action) }
        }
        layer.onHintInput = { [weak self] input in
            guard let self, !self.disposed, self.active, self.generation == token,
                  case .cancelFaderRest(let reason, let at) = input else { return }
            let now = self.uptime()
            guard at.isFinite, at >= 0, now.isFinite, at <= now, self.generation == token else { return }
            let cancellation: TrialHintCancellation
            switch reason {
            case .pointerDown: cancellation = .pointerDown
            case .keyboard: cancellation = .keyInput
            case .focusLoss: cancellation = .focusLoss
            case .layoutChange, .removal, .teardown: cancellation = .targetRemoval
            case .movement, .leave: return // Real source-view movement must carry its P09 lease.
            }
            self.host.sources.cancelPendingRest(reason: cancellation)
        }
        var aligned = context; aligned.helpMapVisible = input.map.mode != .hidden; aligned.reducedMotion = input.reduceMotion
        guard input.active else { host.suspend(); return }
        if host.isRunning { try host.updateContext(aligned) } else { try host.resume(context: aligned) }
    }
    public func suspend() {
        guard !disposed else { return }; generation &+= 1; active = false; host.suspend(); layer.suspend()
    }
    fileprivate func consume(_ edit: SettingsCommittedEdit) async {
        guard !disposed, edit.belongs(to: application.editor.store) else { return }
        host.observeCommitted(edit.after)
        let accepted: Bool
        if let reset = edit.resetRequest { accepted = await host.applyCommittedReset(reset) }
        else { accepted = await host.reconcileUnchangedHints(edit) }
        guard !disposed else { return }
        onSettingsReceipt?(edit, accepted)
    }
    private func refreshEditor() {
        guard !disposed else { return }
        refreshAgain = true
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            guard let self, !self.disposed else { return }
            while !self.disposed, self.refreshAgain {
                self.refreshAgain = false
                await self.application.reload()
            }
            self.refreshTask = nil
        }
    }
    public func flush() async {
        await host.flushPersistence()
        while let task = refreshTask { await task.value }
    }
    fileprivate func receiptDeliveryFailed(_ failure: SettingsCommitDeliveryFailure) {
        guard !disposed else { return }
        receiptDeliveryFailure = failure
        let callback = onReceiptDeliveryFailure
        host.abandonPendingPersistenceForRetirement()
        dispose()
        callback?(failure)
    }
    public func dispose() {
        guard !disposed else { return }; disposed = true; generation &+= 1; active = false
        if let observer { application.editor.removeCommitObserver(observer) }; observer = nil
        host.onPersisted = nil; host.dispose(); overlay.dispose()
        onHelpAction = nil; onSettingsReceipt = nil; onReceiptDeliveryFailure = nil
    }
}
