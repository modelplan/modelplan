// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanEngineClient
import ModelPlanWire

/// Retained presentation boundary for the product entry's already-admitted events.
/// The owner supplies the existing client and, when available, its authoritative
/// grant factory. Constructing the entry does not start a client or send a request.
@MainActor public final class ScopeConsentEntry {
    public let controller: ScopeConsentController
    public let view: SettingsScopeConsentView
    private let buildSigning:ScopeConsentBuildSigning
    private weak var firstRunView:SettingsScopeConsentView?
    /// G3-45: vendor marks for the first-run tool list; the app supplies its checked marks.
    public var markImage: (@MainActor (String) -> NSImage?)? { didSet { view.setMarkImage(markImage) } }
    public enum PresentationError:Error { case mutationInProgress }

    public init(client: any EngineClient, ready: @escaping @MainActor () -> Bool,
                makeGrant: (@MainActor (ScopeConsentIntent) throws -> WireConsentGrantParams)? = nil,
                language: SettingsLanguage = .chinese,buildSigning:ScopeConsentBuildSigning = .current) {
        let commands = EngineClientScopeConsentCommands(client: client, ready: ready, makeGrant: makeGrant)
        let controller = ScopeConsentController(commands: commands)
        self.controller = controller
        self.buildSigning=buildSigning
        self.view = SettingsScopeConsentView(controller: controller, language: language,buildSigning:buildSigning,compactTools:true)
    }
    /// A separate view, the same accepted facts/controller/client. Never steal the
    /// Settings view's parent, create another consent service, or pre-check scopes.
    public func makeFirstRunView(language:SettingsLanguage) throws -> SettingsScopeConsentView {
        if let firstRunView { firstRunView.apply(language:language);return firstRunView }
        guard controller.beginFirstRunDraft() else { throw PresentationError.mutationInProgress }
        let view=SettingsScopeConsentView(controller:controller,language:language,buildSigning:buildSigning,firstRun:true,markImage:markImage)
        firstRunView=view;return view
    }
    /// Close only that presentation. Current accepted permissions remain available
    /// in Settings; app/store privacy invalidation still clears every observer.
    public func endFirstRunPresentation() {
        firstRunView?.retirePresentation();firstRunView=nil;controller.endFirstRunDraft()
    }
    /// The native Settings renderer and non-windowed journey share this replacement boundary.
    public func retainingNonConsentRows(_ rows:[SettingsRow]) -> [SettingsRow] {
        rows.filter{$0.key != .detectedReaders && $0.key != .optionalReaders}
    }

    /// Only call from the owner’s accepted event fanout, synchronously on the main actor.
    public func acceptedFacts(_ facts: WireConsentFacts) { controller.receiveAcceptedFacts(facts) }
    public func acceptedRows(_ rows: WireRowsSnapshot) { controller.receiveAcceptedRows(rows) }
    public func acceptedPluginResult(requestID: WireRequestID, result: WirePluginInstallResult) {
        controller.receiveAcceptedPluginResult(requestID: requestID, result: result)
    }
    /// Clear on the owner's delivery turn before it acknowledges invalidation.
    public func clearPrivateViews() { controller.clearAcceptedPrivateState() }
    public func suspend() { endFirstRunPresentation();view.suspend() }
}
