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
        self.input = input; self.frames = frames
        if isPresented { try publish() }
    }
    public func setPresentationAllowed(_ allowed: Bool) throws {
        guard !isDisposed else { return }
        isPresented = allowed
        if allowed { try publish() }
        else { engines.isHidden = true; console.isHidden = true; suspendViews() }
    }
    private func publish() throws {
        guard let input, let frames, isPresented, !isDisposed else { return }
        binding.isPublishing = true; defer { binding.isPublishing = false }
        renderError = nil
        do {
            if engines.frame.size != frames.engines { engines.setFrameSize(frames.engines) }
            if console.frame.size != frames.console { console.setFrameSize(frames.console) }
            let engineFrame = CGRect(origin: .zero, size: frames.engines)
            if engineTable.frame != engineFrame { engineTable.frame = engineFrame }
            if mainScreen.frame != frames.mainScreen { mainScreen.frame = frames.mainScreen }
            if faders.frame != frames.faders { faders.frame = frames.faders }
            try engineTable.update(columns: input.columns, identities: input.identities, language: input.language,
                                   now: input.now, scope: input.scope)
            try mainScreen.update(inputs: input.channels, selection: input.selection, publication: input.publication,
                publicationUsable: input.publicationUsable, language: input.language, compact: input.compact,
                scope: input.scope, pages: input.pages, sourcedBodies: input.sourcedBodies)
            try faders.update(inputs: input.channels, publicationUsable: input.publicationUsable,
                language: input.language, compact: input.compact, now: input.now, favoriteIDs: input.favoriteIDs,
                selectedModelID: mainScreen.controller.navigation.selectedModelID, showProjectNames: input.showProjectNames)
            // nil in update is "no override"; mirror explicit removals through the existing setter.
            try faders.setTrial(mainScreen.controller.trial)
            try faders.setSourceHighlight(mainScreen.controller.sourceModelID)
            engines.isHidden = false; console.isHidden = false
        } catch {
            invalidate(error); throw error
        }
    }
    func invalidate(_ error: Error) {
        renderError = error; engines.isHidden = true; console.isHidden = true; suspendViews()
    }
    private func suspendViews() { engineTable.suspend(); faders.suspend(); mainScreen.suspend() }
    /// Retire an old observation immediately while the host obtains current scope/selection facts.
    public func clearObservation() {
        guard !isDisposed else { return }
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
        close(); isDisposed = true; binding.dispose()
        engineTable.dispose(); faders.dispose(); mainScreen.dispose()
        engines.removeFromSuperview(); console.removeFromSuperview()
    }
}
