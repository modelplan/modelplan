// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanCore
import ModelPlanAssembly
import ModelPlanInstruments

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
/// No CockpitShell import/product dependency is smuggled into Instruments or the current package.
@MainActor public final class CockpitInstrumentComposition {
    public let surface: InstrumentSurfaceView
    public let rootView: NSView
    public private(set) var requestedScope: InstrumentScope = .all
    public var onIntent: ((InstrumentSurfaceIntent) -> Void)?
    public var onHelpChange: ((InstrumentSurfaceRegion, HelpExplanation?, CGRect?) -> Void)?
    public var onHintInput: ((InstrumentSurfaceRegion, InstrumentHintInput) -> Void)?
    private let provider: any CockpitInstrumentInputProviding
    private let layout: () throws -> InstrumentSurfaceFrames
    private let unmount: () -> Void
    private var disposed = false
    public init(mainScreen: MainScreenView, rootView: NSView, provider: any CockpitInstrumentInputProviding,
                frames: @escaping () throws -> InstrumentSurfaceFrames,
                mount: (NSView, NSView) -> Void, unmount: @escaping () -> Void = {}) {
        surface = InstrumentSurfaceView(mainScreen: mainScreen); self.rootView = rootView
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
    public func update(_ observation: CockpitInstrumentObservation) throws {
        guard !disposed else { return }
        do {
            let input = try provider.input(for: observation)
            guard input.scope == requestedScope, input.scope == observation.scope,
                  input.language == observation.language, input.now == observation.now,
                  input.selection?.publication == observation.selection.instruments?.publication,
                  input.selection?.orderedModelIDs == observation.selection.instruments?.orderedModelIDs,
                  input.selection?.publicDefaultFallback == observation.selection.instruments?.publicDefaultFallback
            else { throw InstrumentSurfaceError.selectionMismatch }
            try surface.update(input, frames: layout())
        } catch { surface.clearObservation(); throw error }
    }
    public func setPresentationAllowed(_ allowed: Bool) throws {
        guard !disposed else { return }; try surface.setPresentationAllowed(allowed)
    }
    public func close() { guard !disposed else { return }; surface.close() }
    public func dispose() {
        guard !disposed else { return }; disposed = true
        surface.dispose(); unmount(); onIntent = nil; onHelpChange = nil; onHintInput = nil
    }
}
