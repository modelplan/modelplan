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
    case idle, confirmation(id: UUID, tool: WirePluginTool), sending, unverified, result(WirePluginInstallStatus)
}
public enum ScopeConsentNotice: Sendable { case none, outcomeUnknown, committedAwaitingFacts, requestFailed, checking, waitingForFacts, cleanupPending }
/// Why a detected tool cannot be read, from the engine's accepted rows (G3-38, D52).
public enum ScopeToolBlock: Sendable, Equatable { case notSignedIn, unsupportedLogin }
/// G3-45: one detected tool on the first-run page. Built from accepted facts only.
public struct FirstRunTool: Sendable, Equatable {
    public let tool: String
    /// Every standard (non-browser) path of this tool that the engine knows and can change.
    public let scopes: [String]
    public let routes: [RowsRoute]
    public let block: ScopeToolBlock?
    /// D61: a path of this tool can show a macOS Keychain prompt (the engine's access class,
    /// sent as a Keychain choice on the scope), so it is read only after Done and only if ticked.
    public let promptsKeychain: Bool
    /// False only for a supported tool this Mac does not have (Settings lists it with the reason; first run does not).
    public var detected: Bool = true
    public var canRead: Bool { detected && block == nil && !scopes.isEmpty }
}
/// Transient UI choices over already-accepted facts. No persistence or protocol acceptance logic.
@MainActor public final class ScopeConsentController {
    public private(set) var facts: WireConsentFacts?
    public private(set) var rowsSummary: RowsRowsSummary?
    public private(set) var selectedIDs = Set<String>()
    public private(set) var phase: ScopeConsentPhase = .idle
    public private(set) var notice: ScopeConsentNotice = .none
    public private(set) var diagnosticsSummary: String?
    public private(set) var diagnosticsPresentation:SettingsText?
    private let copyReport: (@MainActor (String) throws -> Void)?
    private var diagnosticsToken: UUID?
    private var inspectionToken: UUID?
    public private(set) var pluginPhase: ScopePluginPhase = .idle
    private var pluginToken: UUID?
    private var expectedPluginTool: WirePluginTool?
    private var completedPluginRequestID: WireRequestID?
    private var pendingPluginResults: [(WireRequestID, WirePluginInstallStatus)] = []
    private let commands: any ScopeConsentCommands
    // A UI request token only; never a protocol session, epoch or generation fence.
    private var lastIntentRequestID: String?
    private var activeRequestToken: UUID?
    private var acceptedFactsCallbackToken = UUID()
    private var visibleDraftBasisToken = UUID()
    private var firstRunExplicitSelection=false
    /// G3-45: the user's own first-run changes; untouched tools follow their default.
    private var firstRunToolChoices: [String: Bool] = [:]
    private var rowCodes: [String: RowsCode] = [:]
    private var rowStates: [String: RowsState] = [:]
    private var observers: [UUID: @MainActor () -> Void] = [:]
    public init(commands: any ScopeConsentCommands, copyReport: (@MainActor (String) throws -> Void)? = nil) {
        self.commands = commands; self.copyReport = copyReport
    }
    /// Presentation policy only; no grant, persistence, inspection or assumed restore.
    public func beginFirstRunDraft() -> Bool {
        guard case .idle=phase else { return false }
        firstRunExplicitSelection=true;selectedIDs=[];firstRunToolChoices=[:];changed();return true
    }
    public func endFirstRunDraft() { firstRunExplicitSelection=false }
    public var canRequestPlugin: Bool { commands.isReady && pluginToken == nil }
    public func requestPluginInstall(_ tool: WirePluginTool) {
        guard canRequestPlugin, tool.isKnown else { return }
        expectedPluginTool = tool; completedPluginRequestID = nil; pendingPluginResults = []
        pluginPhase = .confirmation(id: UUID(), tool: tool); changed()
    }
    public func confirmPluginInstall(_ id: UUID) async {
        guard case .confirmation(let current, let tool) = pluginPhase, current == id,
              canRequestPlugin, !Task.isCancelled else { return }
        let token = UUID(); pluginToken = token; pluginPhase = .sending; changed()
        guard pluginToken == token, !Task.isCancelled else { return }
        do {
            let completion = try await commands.pluginInstall(try .init(tool: tool))
            guard pluginToken == token else { return }
            pluginToken = nil; completedPluginRequestID = completion.requestID
            if let match = pendingPluginResults.first(where: { $0.0 == completion.requestID }) {
                pluginPhase = .result(match.1)
            } else { pluginPhase = .unverified }
            pendingPluginResults = []; changed()
        } catch {
            guard pluginToken == token else { return }
            pluginToken = nil; expectedPluginTool = nil; completedPluginRequestID = nil
            pendingPluginResults = []; pluginPhase = .unverified; changed()
        }
    }
    /// Only call with the native store's accepted typed result; completion supplies correlation only.
    public func receiveAcceptedPluginResult(requestID: WireRequestID, result: WirePluginInstallResult) {
        guard result.tool == expectedPluginTool else { return }
        if let completedPluginRequestID {
            guard requestID == completedPluginRequestID else { return }
            pluginPhase = .result(result.status); changed()
        } else if pluginToken != nil, pendingPluginResults.count < 16 {
            pendingPluginResults.append((requestID, result.status))
        }
    }
    public func cancelPluginConfirmation() {
        guard case .confirmation = pluginPhase else { return }
        pluginPhase = .idle; expectedPluginTool = nil; completedPluginRequestID = nil; pendingPluginResults = []; changed()
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
    private var claudeRowState: RowsState?, keychainLater = false
    /// G3-67: the engine's own consent per tool row, from the accepted rows; nil until the first rows are accepted.
    private var rowConsent: [String: RowsConsent]?
    public func canChoose(_ id: String) -> Bool {
        guard canMutate, let scope = facts?.scopes.first(where: { $0.scope == id }) else { return false }
        return scope.route.isKnown && scope.route != .knownUnknown && scope.detected && !scope.retired && scope.disabledReason == nil && scope.state != .allowed && !scope.cleanupPending
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
    /// Re-render connection readiness without treating it as a consent response.
    public func refreshAvailability() { changed() }
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
                } else if !firstRunExplicitSelection && scope.state == .unset && scope.route != .savedLoginApi && scope.route != .browserSession && scope.route != .knownUnknown && scope.route.isKnown && scope.defaultCheck && scope.detected && !scope.retired && scope.disabledReason == nil {
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
        guard let old, old.consentTextVersion == new.consentTextVersion, old.scopes.count == new.scopes.count else { return false }
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
        diagnosticsPresentation = .init("Reading paths: \(value.scopes.count)\nRuntime (seconds): \(uptime)",
            "读取路径数量：\(value.scopes.count)\n运行时间（秒）：\(value.uptimeSeconds >= 0 ? uptime:"未知")")
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
    public func receiveAcceptedRows(_ value: WireRowsSnapshot) {
        rowsSummary = value.projection.rowsSummary
        claudeRowState = value.projection.rows.first { $0.id == "claude" }?.state
        rowCodes = Dictionary(value.projection.rows.map { ($0.id, $0.reason.code) }, uniquingKeysWith: { first, _ in first })
        rowStates = Dictionary(value.projection.rows.map { ($0.id, $0.state) }, uniquingKeysWith: { first, _ in first })
        var consents: [String: RowsConsent] = [:]
        for row in value.projection.rows where row.kind == .tool { consents[row.id] = row.consent }
        rowConsent = consents
        changed()
    }
    public func clearAcceptedPrivateState() {
        lastIntentRequestID = nil; pluginToken = nil; pluginPhase = .idle; expectedPluginTool = nil; completedPluginRequestID = nil; pendingPluginResults = []
        activeRequestToken = nil; inspectionToken = nil; diagnosticsToken = nil; diagnosticsSummary = nil;diagnosticsPresentation=nil; notice = .none
        facts = nil; rowsSummary = nil; claudeRowState = nil; rowConsent = nil; keychainLater = false; selectedIDs = []; phase = .idle
        firstRunToolChoices = [:]; rowCodes = [:]; rowStates = [:]; changed()
    }
    /// D41: Claude Code's saved-login path, when it is here and usable.
    private var claudeSavedLogin: WireConsentScope? {
        facts?.scopes.first {
            $0.tool == "claude" && $0.route == .savedLoginApi && $0.detected && !$0.retired && $0.disabledReason == nil && !$0.cleanupPending
        }
    }
    /// D41: the first-run sheet asks once, unless the login reads without the Keychain or the
    /// user already chose. Later only hides the question; nothing is recorded.
    public var asksForKeychainOnFirstRun: Bool {
        guard let scope = claudeSavedLogin, !keychainLater else { return false }
        return scope.keychain == .unset && claudeRowState != .fresh
    }
    /// D41: the standing state after Later or a refusal. It is shown, never prompted.
    public var needsKeychainAccess: Bool {
        guard let scope = claudeSavedLogin, scope.keychain != .allow else { return false }
        return scope.keychain == .deny || claudeRowState == .needsKeychain
    }
    public func chooseKeychainLater() { keychainLater = true; changed() }
    /// D41: the button is the consent, so no second confirmation. The engine's foreground read
    /// after this grant is what makes macOS show its dialog; nothing else may trigger it.
    public func allowKeychain() async {
        guard canMutate, let id = claudeSavedLogin?.scope else { return }
        let value = ScopeConsentConfirmation(id: UUID(), intent: .init(mutation: .allow(scopes: [id], keychain: [id])))
        phase = .confirmation(value)
        await confirm(value.id)
    }
    public func isAllowed(_ id: String) -> Bool { facts?.scopes.first { $0.scope == id }?.state == .allowed }
    /// D27 (owner 11-06): a standard reader the engine reads without a consent click — no saved
    /// decision yet and on by the compiled policy (defaultCheck). Browser sessions always ask first.
    public func isOnByDefault(_ id: String) -> Bool {
        guard let scope = facts?.scopes.first(where: { $0.scope == id }) else { return false }
        return scope.state == .unset && scope.defaultCheck && scope.route.isKnown && scope.route != .knownUnknown &&
            scope.route != .browserSession && !scope.retired && scope.disabledReason == nil
    }
    /// Whether ModelPlan reads this path now: explicitly allowed or on by default.
    /// G3-67: a path that is only on by the compiled default counts as read when the engine's rows agree (consent
    /// implicit or allowed for that tool). A default the engine does not admit (Claude's Keychain-only login, a
    /// missing ZCode key file, Kiro, which has no default grant) is shown off instead of ticked. Before any rows
    /// are accepted the compiled default stands.
    public func isReading(_ id: String) -> Bool { isAllowed(id) || (isOnByDefault(id) && engineAdmitsDefault(id)) }
    private func engineAdmitsDefault(_ id: String) -> Bool {
        guard let rowConsent, let tool = facts?.scopes.first(where: { $0.scope == id })?.tool else { return true }
        switch rowConsent[tool] {
        case .some(.implicit), .some(.allowed): return true
        default: return false
        }
    }
    public func choose(_ id: String, selected: Bool) {
        guard canChoose(id) else { return }
        if selected { selectedIDs.insert(id) } else { selectedIDs.remove(id) }; phase = .idle; changed()
    }
    public func selectAll() {
        guard canMutate else { return }
        selectedIDs = Set(facts?.scopes.filter { $0.route != .browserSession && canChoose($0.scope) }.map(\.scope) ?? [])
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
            } else if error is ScopeConsentCommandFailure || error is EngineConsentGrantError {
                phase = .idle; notice = .requestFailed
            } else {
                phase = .waitingForFacts; notice = .outcomeUnknown
            }
            changed()
        }
    }
    /// G3-38 / G3-45: why a detected tool cannot be read, when the engine's rows say so.
    public func block(forTool tool: String) -> ScopeToolBlock? {
        switch rowCodes[tool] {
        case .some(.notSignedIn): return .notSignedIn
        case .some(.unsupportedLogin): return .unsupportedLogin
        default: return nil
        }
    }
    /// G3-45: each detected tool once, in the engine's order. Browser-session paths stay out:
    /// they ask on their own at first need (FR-9-05), never through this one consent.
    public var firstRunTools: [FirstRunTool] {
        guard let facts else { return [] }
        var order: [String] = [], byTool: [String: [WireConsentScope]] = [:]
        for scope in facts.scopes where scope.detected && !scope.retired {
            if byTool[scope.tool] == nil { order.append(scope.tool) }
            byTool[scope.tool, default: []].append(scope)
        }
        return order.map { tool in
            let standard = (byTool[tool] ?? []).filter {
                $0.route.isKnown && $0.route != .knownUnknown && $0.route != .browserSession && $0.disabledReason == nil && !$0.cleanupPending
            }
            return FirstRunTool(tool: tool, scopes: standard.map(\.scope), routes: standard.map(\.route), block: block(forTool: tool),
                                promptsKeychain: standard.contains { $0.keychain != nil })
        }
    }
    /// G3-59: Settings lists every tool first run would list (same rows, engine order), then each supported
    /// tool this Mac does not have, so the user can always see what is supported and why it is not read.
    public var settingsTools: [FirstRunTool] {
        guard let facts else { return [] }
        var seen = Set(facts.scopes.filter { $0.detected && !$0.retired }.map(\.tool)), absent: [FirstRunTool] = []
        for scope in facts.scopes where !scope.retired && seen.insert(scope.tool).inserted {
            absent.append(FirstRunTool(tool: scope.tool, scopes: [], routes: [], block: nil, promptsKeychain: false, detected: false))
        }
        return firstRunTools + absent
    }
    /// Checked unless the user unchecked it, it cannot be read, or every path was already refused.
    public func isFirstRunToolChosen(_ tool: String) -> Bool {
        guard let entry = firstRunTools.first(where: { $0.tool == tool }), entry.canRead else { return false }
        if let choice = firstRunToolChoices[tool] { return choice }
        let states = entry.scopes.compactMap { id in facts?.scopes.first { $0.scope == id }?.state }
        return !states.allSatisfy { $0 == .denied }
    }
    /// Settings: a tool reads when every standard path of it is read (explicitly allowed or on by default).
    public func isToolReading(_ tool: String) -> Bool {
        guard let entry = firstRunTools.first(where: { $0.tool == tool }), entry.canRead else { return false }
        return entry.scopes.allSatisfy { isReading($0) }
    }
    /// Settings: turn a whole tool on or off with one confirmed choice (the same grant the first-run Done sends).
    @discardableResult public func requestToolChoice(_ tool: String, on: Bool) -> ScopeConsentConfirmation? {
        guard canMutate, let facts, let entry = firstRunTools.first(where: { $0.tool == tool && $0.canRead }) else { return nil }
        var allow: [String] = [], deny: [String] = []
        for id in entry.scopes {
            guard let scope = facts.scopes.first(where: { $0.scope == id }) else { continue }
            if on { if scope.state != .allowed { allow.append(id) } } else if scope.state != .denied { deny.append(id) }
        }
        guard !allow.isEmpty || !deny.isEmpty else { return nil }
        let value = ScopeConsentConfirmation(id: UUID(), intent: .init(mutation: .choose(allow: allow, deny: deny, keychain: [])))
        phase = .confirmation(value); changed(); return value
    }
    public func chooseFirstRunTool(_ tool: String, chosen: Bool) {
        guard canMutate, firstRunTools.contains(where: { $0.tool == tool && $0.canRead }) else { return }
        firstRunToolChoices[tool] = chosen; changed()
    }
    /// D61 (3): when any tool can be read, at least one must be ticked before Done.
    public var firstRunChoiceSatisfied: Bool {
        let readable = firstRunTools.filter(\.canRead)
        return readable.isEmpty || readable.contains { isFirstRunToolChosen($0.tool) }
    }
    /// The one grant Done sends: checked tools allowed, unchecked ones refused. A tool that cannot
    /// be read is left as it is. A Keychain-capable path (by access class, D61) gets its Keychain
    /// read only when ticked, when no Keychain choice exists yet and its tool does not already read
    /// without it, so macOS asks at most once (D41).
    public func firstRunChoiceIntent() -> ScopeConsentIntent? {
        guard let facts else { return nil }
        var allow: [String] = [], deny: [String] = [], keychain: [String] = []
        for entry in firstRunTools where entry.canRead {
            let chosen = isFirstRunToolChosen(entry.tool)
            for id in entry.scopes {
                guard let scope = facts.scopes.first(where: { $0.scope == id }) else { continue }
                if chosen {
                    if scope.state != .allowed { allow.append(id) }
                    if scope.keychain == .unset, rowStates[scope.tool] != .fresh, !keychainLater {
                        if scope.state == .allowed { allow.append(id) }
                        keychain.append(id)
                    }
                } else if scope.state != .denied {
                    deny.append(id)
                }
            }
        }
        guard !allow.isEmpty || !deny.isEmpty else { return nil }
        return .init(mutation: .choose(allow: allow, deny: deny, keychain: keychain))
    }
    /// Done's one consent request (owner 10-27: one first-run consent). Returns false only when the
    /// request could not be sent, so the page stays open with the user's choices.
    public func commitFirstRunChoices() async -> Bool {
        guard facts != nil else { return true }
        guard firstRunChoiceSatisfied else { return false }
        guard let intent = firstRunChoiceIntent() else { return true }
        guard canMutate else { return false }
        let value = ScopeConsentConfirmation(id: UUID(), intent: intent)
        phase = .confirmation(value); changed()
        await confirm(value.id)
        if case .requestFailed = notice { return false }
        return true
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
