// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanEngineClient
import ModelPlanWire

public struct ScopeConsentConfirmation: Sendable, Equatable {
    public let id: UUID
    public let intent: ScopeConsentIntent
}
public enum ScopeConsentPhase: Sendable {
    case idle, confirmation(ScopeConsentConfirmation), sending, waitingForFacts
}
public enum ScopePluginPhase: Sendable {
    case idle, confirmation(id: UUID, tool: WirePluginTool), sending, unverified
}
public enum ScopeConsentNotice: Sendable { case none, outcomeUnknown, committedAwaitingFacts, requestFailed, checking, waitingForFacts, cleanupPending }
/// Transient UI choices over already-accepted facts. No persistence or protocol acceptance logic.
@MainActor public final class ScopeConsentController {
    public private(set) var facts: WireConsentFacts?
    public private(set) var rowsSummary: RowsRowsSummary?
    public private(set) var selectedIDs = Set<String>()
    public private(set) var phase: ScopeConsentPhase = .idle
    public private(set) var notice: ScopeConsentNotice = .none
    public private(set) var diagnosticsSummary: String?
    private let copyReport: (@MainActor (String) throws -> Void)?
    private var diagnosticsToken: UUID?
    private var inspectionToken: UUID?
    public private(set) var pluginPhase: ScopePluginPhase = .idle
    private var pluginToken: UUID?
    private let commands: any ScopeConsentCommands
    // A UI request token only; never a protocol session, epoch or generation fence.
    private var lastIntentRequestID: String?
    private var activeRequestToken: UUID?
    private var acceptedFactsCallbackToken = UUID()
    private var visibleDraftBasisToken = UUID()
    private var observers: [UUID: @MainActor () -> Void] = [:]
    public init(commands: any ScopeConsentCommands, copyReport: (@MainActor (String) throws -> Void)? = nil) {
        self.commands = commands; self.copyReport = copyReport
    }
    public var canRequestPlugin: Bool { commands.isReady && pluginToken == nil }
    public func requestPluginInstall(_ tool: WirePluginTool) {
        guard canRequestPlugin, tool.isKnown else { return }
        pluginPhase = .confirmation(id: UUID(), tool: tool); changed()
    }
    public func confirmPluginInstall(_ id: UUID) async {
        guard case .confirmation(let current, let tool) = pluginPhase, current == id,
              canRequestPlugin, !Task.isCancelled else { return }
        let token = UUID(); pluginToken = token; pluginPhase = .sending; changed()
        guard pluginToken == token, !Task.isCancelled else { return }
        do { _ = try await commands.pluginInstall(try .init(tool: tool)) }
        catch { /* Only bounded human guidance below; no raw error or direct CLI fallback. */ }
        guard pluginToken == token else { return }
        pluginToken = nil
        // The current generated contract has no result root. Completion is never an installation proof.
        pluginPhase = .unverified; changed()
    }
    public func cancelPluginConfirmation() {
        guard case .confirmation = pluginPhase else { return }
        pluginPhase = .idle; changed()
    }
    public func cancelConfirmation() {
        guard case .confirmation = phase else { return }
        phase = .idle; changed()
    }
    public var canCopyDiagnostics: Bool { diagnosticsSummary != nil && copyReport != nil }
    public var canRequestDiagnostics: Bool { commands.isReady && diagnosticsToken == nil }
    public func copyDiagnostics() {
        guard let diagnosticsSummary, let copyReport else { return }
        do { try copyReport(diagnosticsSummary) } catch { notice = .requestFailed; changed() }
    }
    public var canRequestAllow: Bool { canMutate && selectedIDs.contains { canChoose($0) } }
    public var isMutationServiceReady: Bool { commands.canMutate }
    public var canMutate: Bool {
        guard commands.canMutate, facts != nil else { return false }
        switch phase { case .sending, .waitingForFacts: return false; default: return true }
    }
    public var canInspect: Bool { commands.isReady && inspectionToken == nil && activeRequestToken == nil }
    public func canChoose(_ id: String) -> Bool {
        guard canMutate, let scope = facts?.scopes.first(where: { $0.scope == id }) else { return false }
        return scope.route.isKnown && scope.detected && !scope.retired && scope.disabledReason == nil && scope.state != .allowed && !scope.cleanupPending
    }
    @discardableResult public func requestRevoke(_ id: String) -> ScopeConsentConfirmation? {
        requestTightening(id, mutation: .revoke(scope: id))
    }
    @discardableResult public func requestForget(_ id: String) -> ScopeConsentConfirmation? {
        requestTightening(id, mutation: .forget(scope: id))
    }
    private func requestTightening(_ id: String, mutation: ScopeConsentMutation) -> ScopeConsentConfirmation? {
        // Detection and reader availability cannot hide revocation of a saved scope.
        guard canMutate, facts?.scopes.contains(where: { $0.scope == id }) == true else { return nil }
        let value = ScopeConsentConfirmation(id: UUID(), intent: .init(mutation: mutation))
        phase = .confirmation(value); changed(); return value
    }
    @discardableResult public func observe(_ body: @escaping @MainActor () -> Void) -> UUID {
        let id = UUID(); observers[id] = body; return id
    }
    public func removeObserver(_ id: UUID) { observers.removeValue(forKey: id) }
    private func changed() { for body in Array(observers.values) { body() } }
    /// Called only by the native accepted-event consumer, never by an RPC Task completion.
    public func receiveAcceptedFacts(_ value: WireConsentFacts) {
        acceptedFactsCallbackToken = UUID()
        let previous = facts
        let unchanged = sameVisibleFacts(previous, value)
        facts = value // Every value here was already accepted by M0; none is protocol-filtered here.
        if !unchanged {
            visibleDraftBasisToken = UUID()
            selectedIDs.formIntersection(Set(value.scopes.map(\.scope)))
            for scope in value.scopes {
                if let old = previous?.scopes.first(where: { $0.scope == scope.scope }) {
                    if old.state != scope.state || old.keychain != scope.keychain || old.route != scope.route {
                        selectedIDs.remove(scope.scope)
                    }
                } else if scope.state == .unset && scope.defaultCheck && scope.detected && !scope.retired && scope.disabledReason == nil {
                    selectedIDs.insert(scope.scope)
                }
            }
            if case .confirmation = phase { phase = .idle }
        }
        if case .waitingForFacts = phase { phase = .idle }
        notice = value.scopes.contains(where: \.cleanupPending) ? .cleanupPending : .none
        changed()
    }
    // Visible-draft equality only, not a canonicalizer, freshness test or protocol acceptance rule.
    private func sameVisibleFacts(_ old: WireConsentFacts?, _ new: WireConsentFacts) -> Bool {
        guard let old, old.scopes.count == new.scopes.count else { return false }
        return zip(old.scopes, new.scopes).allSatisfy { a, b in
            a.scope == b.scope && a.tool == b.tool && a.route == b.route && a.detected == b.detected &&
            a.retired == b.retired && a.state == b.state && a.defaultCheck == b.defaultCheck &&
            a.keychain == b.keychain && a.cleanupPending == b.cleanupPending && a.disabledReason == b.disabledReason
        }
    }
    /// Correlated feedback only. M0 already decided whether the receipt is historical.
    public func receiveAcceptedGrant(_ value: EngineGrantResult) {
        guard !value.supersededByLaterConsent, value.receipt.requestId == lastIntentRequestID else { return }
        switch value.receipt.code {
        case .cleanupPending: notice = .cleanupPending
        case .ok: notice = (value.receipt.cleanupPending?.isEmpty == false) ? .cleanupPending : .waitingForFacts
        case .staleGeneration, .staleConsentText, .rejected: notice = .requestFailed
        case .unknown: notice = .outcomeUnknown
        }
        // No receipt field is copied into facts, selected scopes or permission badges.
        changed()
    }
    public func receiveAcceptedDiagnostics(_ value: WireDiagnostics) {
        // Final copy allow-list: numeric summary only. No raw errors, identifiers, versions or timestamps.
        let uptime = value.uptimeSeconds >= 0 ? String(value.uptimeSeconds) : "unavailable"
        diagnosticsSummary = "ModelPlan engine diagnostics\nScope count: \(value.scopes.count)\nUptime seconds: \(uptime)"
        changed()
    }
    public func requestDiagnostics() async {
        guard canRequestDiagnostics, !Task.isCancelled else { return }
        let token = UUID(); diagnosticsToken = token; changed()
        guard diagnosticsToken == token, !Task.isCancelled else { return }
        do { _ = try await commands.diagnostics() }
        catch { if diagnosticsToken == token { notice = .requestFailed } }
        guard diagnosticsToken == token else { return }
        diagnosticsToken = nil; changed()
    }
    public func receiveAcceptedRows(_ value: WireRowsSnapshot) { rowsSummary = value.projection.rowsSummary; changed() }
    public func clearAcceptedPrivateState() {
        lastIntentRequestID = nil; pluginToken = nil; pluginPhase = .idle
        activeRequestToken = nil; inspectionToken = nil; diagnosticsToken = nil; diagnosticsSummary = nil; notice = .none
        facts = nil; rowsSummary = nil; selectedIDs = []; phase = .idle; changed()
    }
    public func isAllowed(_ id: String) -> Bool { facts?.scopes.first { $0.scope == id }?.state == .allowed }
    public func choose(_ id: String, selected: Bool) {
        guard canChoose(id) else { return }
        if selected { selectedIDs.insert(id) } else { selectedIDs.remove(id) }; phase = .idle; changed()
    }
    public func selectAll() {
        guard canMutate else { return }
        selectedIDs = Set(facts?.scopes.map(\.scope).filter { canChoose($0) } ?? [])
        phase = .idle; changed()
    }
    @discardableResult public func requestAllow() -> ScopeConsentConfirmation? {
        let eligible = selectedIDs.filter { canChoose($0) }.sorted()
        guard canMutate, !eligible.isEmpty else { return nil }
        let value = ScopeConsentConfirmation(id: UUID(), intent: .init(mutation: .allow(scopes: eligible, keychain: [])))
        phase = .confirmation(value); changed(); return value
    }
    public func confirm(_ id: UUID) async {
        guard case .confirmation(let value) = phase, value.id == id else { return }
        guard !Task.isCancelled, commands.canMutate else { return }
        let basis = visibleDraftBasisToken
        let token = UUID(); activeRequestToken = token; lastIntentRequestID = value.intent.requestID
        phase = .sending; changed()
        // Observers may synchronously withdraw the visible intent before dispatch.
        guard case .sending = phase, visibleDraftBasisToken == basis, activeRequestToken == token, commands.canMutate, facts != nil, !Task.isCancelled else {
            if activeRequestToken == token {
                activeRequestToken = nil; lastIntentRequestID = nil; phase = .idle; changed()
            }
            return
        }
        let factsAtDispatch = acceptedFactsCallbackToken
        do {
            _ = try await commands.grant(value.intent, userAction: .init(id: UUID()))
            guard activeRequestToken == token else { return }
            activeRequestToken = nil
            // Only accepted facts update permission state. Completion carries no such value.
            phase = acceptedFactsCallbackToken == factsAtDispatch ? .waitingForFacts : .idle; changed()
        } catch {
            guard activeRequestToken == token else { return }
            activeRequestToken = nil
            // A transport failure after dispatch may have committed. Never replay it automatically.
            if let error = error as? EngineClientError {
                switch error {
                case .receiptDeliveryInterrupted:
                    phase = .waitingForFacts; notice = .committedAwaitingFacts
                case .notReady, .localBusy, .invalidConfiguration, .unsupportedCapability,
                     .deadlineExceeded(.notSent), .interrupted(.notSent):
                    phase = .idle; notice = .requestFailed
                default: phase = .waitingForFacts; notice = .outcomeUnknown
                }
            } else if error is ScopeConsentCommandFailure {
                phase = .idle; notice = .requestFailed
            } else {
                phase = .waitingForFacts; notice = .outcomeUnknown
            }
            changed()
        }
    }
    /// A user-triggered read only. Its completion cannot replace accepted permission facts.
    public func inspectConsent() async {
        guard canInspect, !Task.isCancelled else { return }
        let token = UUID(); inspectionToken = token; notice = .checking; changed()
        guard inspectionToken == token, !Task.isCancelled else { return }
        do {
            _ = try await commands.inspectConsent()
            guard inspectionToken == token else { return }
            inspectionToken = nil
            if case .waitingForFacts = phase { notice = .waitingForFacts }
            else if case .checking = notice { notice = .waitingForFacts }
        } catch {
            guard inspectionToken == token else { return }
            inspectionToken = nil; notice = .requestFailed
        }
        changed()
    }

}
