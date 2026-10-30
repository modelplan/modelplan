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

    public init(client: any EngineClient, ready: @escaping @MainActor () -> Bool,
                makeGrant: (@MainActor (ScopeConsentIntent) throws -> WireConsentGrantParams)? = nil,
                language: SettingsLanguage = .chinese) {
        let commands = EngineClientScopeConsentCommands(client: client, ready: ready, makeGrant: makeGrant)
        let controller = ScopeConsentController(commands: commands)
        self.controller = controller
        self.view = SettingsScopeConsentView(controller: controller, language: language)
    }

    /// Only call from the owner’s accepted event fanout, synchronously on the main actor.
    public func acceptedFacts(_ facts: WireConsentFacts) { controller.receiveAcceptedFacts(facts) }
    public func acceptedRows(_ rows: WireRowsSnapshot) { controller.receiveAcceptedRows(rows) }
    public func acceptedPluginResult(requestID: WireRequestID, result: WirePluginInstallResult) {
        controller.receiveAcceptedPluginResult(requestID: requestID, result: result)
    }
    /// Clear on the owner's delivery turn before it acknowledges invalidation.
    public func clearPrivateViews() { controller.clearAcceptedPrivateState() }
    public func suspend() { view.suspend() }
}
