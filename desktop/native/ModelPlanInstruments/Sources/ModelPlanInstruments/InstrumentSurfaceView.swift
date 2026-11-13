// SPDX-License-Identifier: MIT
import AppKit

@MainActor private final class InstrumentSlotContent: NSView {
    override var isFlipped: Bool { true }
}

/// Three existing views, exposed as two slot contents. The host supplies every frame and lifecycle edge.
@MainActor public final class InstrumentSurfaceView {
    public let engineTable: EngineTableView
    public let faders: FaderBankView
    public let mainScreen: MainScreenView
    public let engines: NSView = InstrumentSlotContent()
    public let console: NSView = InstrumentSlotContent()
    public private(set) var input: InstrumentSurfaceInput?
    public private(set) var frames: InstrumentSurfaceFrames?
    public private(set) var isPresented = false
    public private(set) var renderError: Error?
    public private(set) var isDisposed = false
    private var pendingAppearance: NSAppearance?, appearanceSupplied = false
    private var generation: UInt64 = 0
    private var retiring = false
    public lazy var binding = InstrumentSurfaceBinding(surface: self)
    public init(engineTable: EngineTableView? = nil, faders: FaderBankView? = nil,
                mainScreen: MainScreenView? = nil) {
        self.engineTable = engineTable ?? EngineTableView(frame: .zero)
        self.faders = faders ?? FaderBankView(frame: .zero)
        self.mainScreen = mainScreen ?? MainScreenView(frame: .zero)
        engines.isHidden = true; console.isHidden = true
        engines.addSubview(self.engineTable); console.addSubview(self.mainScreen); console.addSubview(self.faders)
        _ = binding
    }
    public func update(_ input: InstrumentSurfaceInput, frames: InstrumentSurfaceFrames) throws {
        guard !isDisposed else { return }
        generation &+= 1
        self.input = input; self.frames = frames
        if isPresented { try publish() }
    }
    public func applyAppearance(_ appearance: NSAppearance?) {
        guard !isDisposed else { return }
        generation &+= 1
        pendingAppearance = appearance; appearanceSupplied = true
        if isPresented { do { try publish() } catch { invalidate(error) } }
    }
    public func setPresentationAllowed(_ allowed: Bool) throws {
        guard !isDisposed, allowed != isPresented else { return }
        generation &+= 1
        isPresented = allowed
        if allowed { try publish() }
        else { engines.isHidden = true; console.isHidden = true; suspendViews() }
    }
    private func publish() throws {
        guard let input, let frames, isPresented, !isDisposed else { return }
        let token = generation
        binding.isPublishing = true; defer { binding.isPublishing = false }
        renderError = nil
        do {
            if appearanceSupplied {
                for view in [engineTable as NSView, mainScreen, faders] where view.appearance?.name != pendingAppearance?.name {
                    view.appearance = pendingAppearance
                    guard current(token) else { return }
                }
            }
            if engines.frame.size != frames.engines { engines.setFrameSize(frames.engines) }
            if console.frame.size != frames.console { console.setFrameSize(frames.console) }
            let engineFrame = CGRect(origin: .zero, size: frames.engines)
            if engineTable.frame != engineFrame { engineTable.frame = engineFrame }
            guard current(token) else { return }
            if mainScreen.frame != frames.mainScreen { mainScreen.frame = frames.mainScreen }
            guard current(token) else { return }
            if faders.frame != frames.faders { faders.frame = frames.faders }
            guard current(token) else { return }
            try engineTable.update(columns: input.columns, identities: input.identities, language: input.language,
                                   now: input.now, scope: input.scope, membershipKnowledge: input.membershipKnowledge)
            guard current(token) else { return }
            try mainScreen.update(inputs: input.channels, selection: input.selection, publication: input.publication,
                publicationUsable: input.publicationUsable, language: input.language, compact: input.compact,
                scope: input.scope, pages: input.pages, sourcedBodies: input.sourcedBodies)
            guard current(token) else { return }
            try faders.update(inputs: input.channels, publicationUsable: input.publicationUsable,
                language: input.language, compact: input.compact, now: input.now, favoriteIDs: input.favoriteIDs,
                selectedModelID: mainScreen.controller.navigation.selectedModelID, showProjectNames: input.showProjectNames,
                catalogueOnly: input.selection?.publicDefaultFallback == true)
            guard current(token) else { return }
            // nil in update is "no override"; mirror explicit removals through the existing setter.
            try faders.setTrial(mainScreen.controller.trial)
            guard current(token) else { return }
            try faders.setSourceHighlight(mainScreen.controller.sourceModelID)
            guard current(token) else { return }
            engines.isHidden = false; console.isHidden = false
        } catch {
            invalidate(error); throw error
        }
    }
    private func current(_ token: UInt64) -> Bool { !isDisposed && isPresented && generation == token }
    func invalidate(_ error: Error) {
        guard !isDisposed else { return }
        renderError = error; engines.isHidden = true; console.isHidden = true; suspendViews()
    }
    private func suspendViews() { engineTable.suspend(); faders.suspend(); mainScreen.suspend() }
    /// Retire an old observation immediately while the host obtains current scope/selection facts.
    public func clearObservation() {
        guard !isDisposed, !retiring else { return }
        generation &+= 1; retiring = true; defer { retiring = false }
        input = nil; engines.isHidden = true; console.isHidden = true
        mainScreen.closeForCockpit(); faders.closeForCockpit(); engineTable.suspend()
    }
    public func close() {
        guard !isDisposed else { return }
        isPresented = false; engines.isHidden = true; console.isHidden = true
        clearObservation()
    }
    public func dispose() {
        guard !isDisposed else { return }
        isDisposed = true; generation &+= 1; isPresented = false; input = nil
        engines.isHidden = true; console.isHidden = true
        faders.closeForCockpit()
        engineTable.dispose(); faders.dispose(); mainScreen.dispose()
        binding.dispose()
        engines.removeFromSuperview(); console.removeFromSuperview()
    }
}
