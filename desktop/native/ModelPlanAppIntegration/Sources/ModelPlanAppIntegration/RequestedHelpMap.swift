// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanInstruments
import ModelPlanSettings

/// Adapts an explicit user request to the existing Help composition; it has no hint ledger.
@MainActor public final class RequestedHelpMap {
    public typealias Apply = @MainActor (HelpUIRenderInput, [FirstUseHintKind: HelpHintContent], HintContext, InstrumentHintSourceSnapshot?) throws -> HelpUIPresentation?
    private let apply: Apply
    private let isCurrent: @MainActor (HelpUIRenderInput) -> Bool
    private var previous: (HelpUIRenderInput, [FirstUseHintKind: HelpHintContent], HintContext, InstrumentHintSourceSnapshot?)?
    private var generation: UInt64 = 0

    public init(apply: @escaping Apply, isCurrent: @escaping @MainActor (HelpUIRenderInput) -> Bool) {
        self.apply = apply; self.isCurrent = isCurrent
    }

    public convenience init(composition: InstrumentHelpComposition, isCurrent: @escaping @MainActor (HelpUIRenderInput) -> Bool) {
        self.init(apply: { [weak composition] input, content, context, trial in
            guard let composition else { return nil }
            try composition.update(input, content: content, context: context, trialSource: trial)
            return composition.layer.presentation
        }, isCurrent: isCurrent)
    }

    /// Input supplies live overlay-local anchors, map regions, available caption geometry,
    /// viewport and reading obstacles. True means complete geometry, not window visibility.
    @discardableResult public func presentHelpMap(input: HelpUIRenderInput,
        content: [FirstUseHintKind: HelpHintContent], context: HintContext,
        trialSource: InstrumentHintSourceSnapshot? = nil) throws -> Bool {
        if previous != nil { try dismissHelpMap() }
        generation &+= 1; let token = generation
        guard input.active, isCurrent(input), generation == token else { return false }
        let ids = input.anchors.filter(\.visible).map(\.id)
        guard !ids.isEmpty, Set(ids).count == ids.count else { return false }
        var hidden = input; hidden.map.mode = .hidden
        previous = (hidden, content, context, trialSource)
        var shown = input; shown.map.mode = .latched; shown.contextual = nil; shown.firstUse = nil
        let result: HelpUIPresentation?
        do { result = try apply(shown, content, context, trialSource) }
        catch {
            if generation == token { previous = nil; _ = try? apply(hidden, content, context, trialSource) }
            throw error
        }
        guard generation == token, isCurrent(input), generation == token else { return false }
        guard let result, result.sessionID == input.sessionID, result.mapHeader != nil,
              result.unresolvedMapIDs.isEmpty, Set(result.mapLabels.map(\.anchorID)) == Set(ids) else {
            previous = nil
            _ = try apply(hidden, content, context, trialSource)
            return false
        }
        return true
    }

    public func dismissHelpMap() throws {
        generation &+= 1; let token = generation
        guard let (input, content, context, trial) = previous else { return }
        previous = nil
        guard isCurrent(input), generation == token else { return }
        _ = try apply(input, content, context, trial)
    }

    /// Forward map dismiss actions from the composition and Option-key release from the owner.
    @discardableResult public func handleHelpAction(_ action: HelpUIAction) throws -> Bool {
        guard case .dismissMap = action, previous != nil else { return false }
        try dismissHelpMap(); return true
    }
    public func optionReleased() throws { try dismissHelpMap() }
}
