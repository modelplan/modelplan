// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanCore
import ModelPlanAssembly
import ModelPlanInstruments
import ModelPlanCockpitShell

@MainActor private final class CockpitInstrumentSlotView: NSView, CockpitPresentationConsumer {
    var presentationChanged: ((Bool) -> Void)?
    var stopped: (() -> Void)?
    private(set) var allowed = false
    private(set) var ownsRegistration = true
    private let content: NSView
    override var isFlipped: Bool { true }
    init(_ content: NSView) { self.content = content; super.init(frame: .zero); addSubview(content) }
    required init?(coder: NSCoder) { nil }
    override func layout() { super.layout(); content.frame = bounds }
    func setPresentationAllowed(_ allowed: Bool) {
        guard ownsRegistration else { return }
        self.allowed = allowed; presentationChanged?(allowed)
    }
    func stop() {
        guard ownsRegistration else { return }
        // Shell revokes registration before calling out to the retired composition.
        ownsRegistration = false; allowed = false; stopped?()
    }
}

/// The two existing host callbacks supply these facts. This is not a second store or decoder.
public struct CockpitInstrumentObservation: Sendable {
    public let snapshot: JoinedSnapshot?
    public let selection: AssembledModelSelection
    public let scope: InstrumentScope, language: InstrumentLanguage
    public let publishedAt: Date?, now: Date
    public let showProjectNames: Bool
    public init(snapshot: JoinedSnapshot?, selection: AssembledModelSelection, scope: InstrumentScope,
                language: InstrumentLanguage, publishedAt: Date?, now: Date, showProjectNames: Bool) {
        self.snapshot = snapshot; self.selection = selection; self.scope = scope; self.language = language
        self.publishedAt = publishedAt; self.now = now; self.showProjectNames = showProjectNames
    }
}

/// M0 supplies the existing Assembly's typed conversion and exact layout frames.
@MainActor public protocol CockpitInstrumentInputProviding: AnyObject {
    func input(for observation: CockpitInstrumentObservation) throws -> InstrumentSurfaceInput
}

/// Mount closures bridge the existing CockpitShellSurface engines/console slots above root modules.
/// CockpitShell is an explicit upper-package dependency; Instruments never imports it.
@MainActor public final class CockpitInstrumentComposition {
    public let surface: InstrumentSurfaceView
    public let rootView: NSView
    public internal(set) var field: CommunityCockpitField?
    public private(set) var requestedScope: InstrumentScope = .all
    public var onIntent: ((InstrumentSurfaceIntent) -> Void)?
    public var onHelpChange: ((InstrumentSurfaceRegion, HelpExplanation?, CGRect?) -> Void)?
    public var onHintInput: ((InstrumentSurfaceRegion, InstrumentHintInput) -> Void)?
    public var onFailure: ((Error) -> Void)?
    private let provider: any CockpitInstrumentInputProviding
    private let layout: () throws -> InstrumentSurfaceFrames
    private let unmount: () -> Void
    private var disposed = false
    private var hostPresented = false, shellPresented = true
    public init(mainScreen: MainScreenView, rootView: NSView, provider: any CockpitInstrumentInputProviding,
                engineTable: EngineTableView? = nil, faders: FaderBankView? = nil,
                frames: @escaping () throws -> InstrumentSurfaceFrames,
                mount: (NSView, NSView) -> Void, unmount: @escaping () -> Void = {}) {
        surface = InstrumentSurfaceView(engineTable: engineTable, faders: faders, mainScreen: mainScreen); self.rootView = rootView
        self.provider = provider; layout = frames; self.unmount = unmount
        mount(surface.engines, surface.console)
        surface.binding.onIntent = { [weak self] intent in
            guard let self, !self.disposed else { return }
            if case .requestScope(let scope) = intent {
                guard scope != self.requestedScope else { return }
                self.requestedScope = scope; self.surface.clearObservation()
            }
            self.onIntent?(intent)
        }
        surface.binding.onHelpChange = { [weak self] region, help, rect in self?.onHelpChange?(region, help, rect) }
        surface.binding.onHintInput = { [weak self] region, input in self?.onHintInput?(region, input) }
    }
    /// The caller supplies an already configured frozen shell; no slot positions or dimensions are invented.
    public convenience init(mainScreen: MainScreenView, shell: CockpitShellSurface,
                            provider: any CockpitInstrumentInputProviding,
                            engineTable: EngineTableView? = nil, faders: FaderBankView? = nil,
                            frames: @escaping () throws -> InstrumentSurfaceFrames) {
        var engineSlot: CockpitInstrumentSlotView?, consoleSlot: CockpitInstrumentSlotView?
        self.init(mainScreen: mainScreen, rootView: shell, provider: provider, engineTable: engineTable, faders: faders, frames: {
            let value = try frames()
            guard shell.surfaceLayout?.slots[.engines]?.size == value.engines,
                  shell.surfaceLayout?.slots[.console]?.size == value.console
            else { throw InstrumentSurfaceError.invalidFrames }
            return value
        }, mount: { engines, console in
            let e = CockpitInstrumentSlotView(engines), c = CockpitInstrumentSlotView(console)
            engineSlot = e; consoleSlot = c
            shell.setContent(e, for: .engines); shell.setContent(c, for: .console)
        }, unmount: {
            if let engineSlot, engineSlot.ownsRegistration, engineSlot.superview === shell {
                shell.setContent(nil, for: .engines)
            }
            if let consoleSlot, consoleSlot.ownsRegistration, consoleSlot.superview === shell {
                shell.setContent(nil, for: .console)
            }
        })
        shellPresented = engineSlot?.allowed == true && consoleSlot?.allowed == true
        let changed: (Bool) -> Void = { [weak self, weak engineSlot, weak consoleSlot] _ in
            guard let self, !self.disposed else { return }
            self.shellPresented = engineSlot?.allowed == true && consoleSlot?.allowed == true
            do { try self.applyPresentation() } catch { self.surface.clearObservation(); self.onFailure?(error) }
        }
        engineSlot?.presentationChanged = changed; consoleSlot?.presentationChanged = changed
        engineSlot?.stopped = { [weak self] in self?.close() }
        consoleSlot?.stopped = { [weak self] in self?.close() }
    }
    public func update(_ observation: CockpitInstrumentObservation) throws {
        guard !disposed else { return }
        do {
            let input = try provider.input(for: observation)
            guard !disposed else { return }
            guard input.scope == requestedScope, input.scope == observation.scope,
                  input.language == observation.language, observation.selection.language == observation.language,
                  input.now == observation.now, input.showProjectNames == observation.showProjectNames,
                  input.publication == observation.selection.instruments?.publication,
                  input.selection?.publication == observation.selection.instruments?.publication,
                  input.selection?.scope == observation.selection.instruments?.scope,
                  input.selection?.selectedModelID == observation.selection.instruments?.selectedModelID,
                  input.selection?.orderedModelIDs == observation.selection.instruments?.orderedModelIDs,
                  input.selection?.publicDefaultFallback == observation.selection.instruments?.publicDefaultFallback
            else { throw InstrumentSurfaceError.selectionMismatch }
            let frames = try layout()
            guard !disposed else { return }
            try surface.update(input, frames: frames)
        } catch { surface.clearObservation(); throw error }
    }
    public func setPresentationAllowed(_ allowed: Bool) throws {
        guard !disposed else { return }; hostPresented = allowed; try applyPresentation()
    }
    private func applyPresentation() throws {
        let allowed = hostPresented && shellPresented
        field?.setPresented(allowed)
        if surface.isPresented != allowed { try surface.setPresentationAllowed(allowed) }
    }
    public func close() { guard !disposed else { return }; hostPresented = false; field?.setPresented(false); surface.close() }
    public func dispose() {
        guard !disposed else { return }; disposed = true
        field?.dispose(); field = nil; surface.dispose(); unmount(); onIntent = nil; onHelpChange = nil; onHintInput = nil; onFailure = nil
    }
}
