// SPDX-License-Identifier: MIT
import Foundation

public enum SettingsConnectionPhase: Equatable, Sendable {
    case unavailable, idle, loading, awaitingConfirmation(SettingsConnectionConfirmation)
    case running(SettingsConnectionAction), pluginResult(SettingsPluginInstallResult), failed(SettingsConnectionFailure), cancelled
    case consentRecordedReadingBlocked(SettingsReadingMode)
}

/// Transient presentation over injected observations. No preference store, clock, selector or service creation.
/// Settings and first run share this one controller through their existing SettingsEditor.
@MainActor public final class SettingsConnectionController {
    public private(set) var snapshot: SettingsConnectionSnapshot?
    public private(set) var phase: SettingsConnectionPhase
    public private(set) var availability: SettingsConnectionAvailability
    private var service: SettingsConnectionService?
    private var generation: UInt64 = 0
    private var observation: UInt64 = 0
    private var observers: [UUID: () -> Void] = [:]
    public init(service: SettingsConnectionService? = nil) {
        self.service = service
        let capability = Self.initialAvailability(service)
        availability = capability
        phase = service == nil || !capability.hasAnyAction ? .unavailable : .idle
    }
    private static func initialAvailability(_ service: SettingsConnectionService?) -> SettingsConnectionAvailability {
        guard let service else { return .init(reason: .unavailable) }
        if let provider = service as? any SettingsConnectionAvailabilityProviding { return provider.settingsConnectionAvailability }
        return service is any SettingsConnectionAllowing ? .unverified : .legacy
    }
    public var isAvailable: Bool { service != nil && availability.hasAnyAction }
    public var hasAllowanceBackend: Bool { service is any SettingsConnectionAllowing }
    public func isBound(to expected: SettingsConnectionService) -> Bool { service === expected }
    /// Late composition uses the existing editor/controller. A second backend cannot take it over.
    @discardableResult public func bind(service: SettingsConnectionService) -> Bool {
        guard self.service == nil, !isBusy else { return false }
        generation &+= 1; let token = generation
        let capability = Self.initialAvailability(service)
        guard self.service == nil, generation == token else { return false }
        self.service = service; availability = capability
        phase = isAvailable ? .idle : .unavailable; changed(); return true
    }
    public func updateAvailability(_ value: SettingsConnectionAvailability) {
        generation &+= 1; availability = service == nil ? .init(reason: .unavailable) : value
        phase = isAvailable ? .idle : .unavailable; changed()
    }
    public func canConnect(_ tool: SettingsConnectionTool, access: SettingsConnectionAccess) -> Bool {
        isAvailable && !isBusy && canRequest(.connect(tool, access))
    }
    public func canAllow(_ intent: SettingsConnectionIntent) -> Bool {
        isAvailable && !isBusy && intent.basis == snapshot && canRequest(.applyStandardConsent(allow: intent.orderedTools, deny: []))
    }
    @discardableResult public func requestAllow(_ intent: SettingsConnectionIntent) -> SettingsConnectionConfirmation? {
        guard canAllow(intent) else { return nil }
        return request(.applyStandardConsent(allow: intent.orderedTools, deny: []))
    }
    public func canForget(_ tool: SettingsConnectionTool) -> Bool {
        isAvailable && !isBusy && canRequest(.applyStandardConsent(allow: [], deny: [tool]))
    }
    /// Explicitly destructive, independent of choosing/unchecking first-run Allow intentions.
    @discardableResult public func requestForget(_ tool: SettingsConnectionTool) -> SettingsConnectionConfirmation? {
        guard canForget(tool) else { return nil }
        return request(.applyStandardConsent(allow: [], deny: [tool]))
    }
    public var isBusy: Bool {
        switch phase { case .loading, .running: return true; default: return false }
    }
    public func observe(_ body: @escaping () -> Void) -> UUID {
        let id = UUID(); observers[id] = body; return id
    }
    public func removeObserver(_ id: UUID) { observers.removeValue(forKey: id) }
    private func changed() { for body in Array(observers.values) { body() } }
    /// The app's newer observation invalidates confirmation and any in-flight UI receipt.
    /// Unknown/empty is explicit; it never becomes inferred authorization or an invented subscription.
    public func receive(_ value: SettingsConnectionSnapshot) {
        generation &+= 1
        do { try accept(value); phase = isAvailable ? .idle : .unavailable }
        catch { phase = .failed(.stale) }
        changed()
    }
    /// Cancels UI admission/results, not an already accepted external effect. The runtime owns cancellation.
    public func cancel() {
        generation &+= 1; phase = isAvailable ? .cancelled : .unavailable; changed()
    }
    public func refresh() async {
        guard let service, availability.canInspect else { phase = .unavailable; changed(); return }
        guard !isBusy else { return }
        guard !Task.isCancelled else { cancel(); return }
        generation &+= 1; let token = generation
        phase = .loading; changed()
        // Observers may synchronously cancel or replace the observation before dispatch.
        guard generation == token, phase == .loading, availability.canInspect else { return }
        guard !Task.isCancelled else { cancel(); return }
        do {
            let value = try await service.detect()
            guard generation == token else { return }
            guard !Task.isCancelled else { cancel(); return }
            try accept(value); phase = .idle; changed()
        } catch { failed(error, token: token) }
    }
    /// An explicit request only presents a confirmation. No service is invoked here.
    @discardableResult public func request(_ action: SettingsConnectionAction) -> SettingsConnectionConfirmation? {
        guard isAvailable, !isBusy, canRequest(action) else { return nil }
        generation &+= 1
        let confirmation = SettingsConnectionConfirmation(id: UUID(), action: action, observation: observation)
        phase = .awaitingConfirmation(confirmation); changed(); return confirmation
    }
    public func confirm(_ id: UUID) async {
        guard let service, case .awaitingConfirmation(let confirmation) = phase,
              confirmation.id == id, confirmation.observation == observation,
              canRequest(confirmation.action) else { return }
        guard !Task.isCancelled else { cancel(); return }
        generation &+= 1; let token = generation
        let request = SettingsConnectionRequestContext(id: confirmation.id, expectedConsentGeneration: snapshot?.consentGeneration,
                                                       consentTextVersion: snapshot?.consentPreview?.textVersion)
        phase = .running(confirmation.action); changed()
        guard generation == token, confirmation.observation == observation,
              phase == .running(confirmation.action), canRequest(confirmation.action) else { return }
        guard !Task.isCancelled else { cancel(); return }
        do {
            switch confirmation.action {
            case .applyStandardConsent(let tools, let denied):
                guard let allowing = service as? any SettingsConnectionAllowing else { throw SettingsConnectionFailure.unavailable }
                let value = try await allowing.applyStandardConsent(allow: tools, deny: denied, request: request)
                guard generation == token else { return }
                guard !Task.isCancelled else { cancel(); return }
                try acceptActionResult(value)
                let complete = tools.allSatisfy { id in value.tools.contains { $0.tool == id && $0.authorization == .allowed } }
                    && denied.allSatisfy { id in value.tools.contains { $0.tool == id && ($0.authorization == .denied || $0.authorization == .noConsent) } }
                phase = !complete ? .failed(.invalidResponse) : (value.mode == .off || value.mode == .unknown)
                    ? .consentRecordedReadingBlocked(value.mode) : .idle
            case .connect(let tool, let access):
                let value = try await service.connect(tool, access: access, request: request)
                guard generation == token else { return }
                guard !Task.isCancelled else { cancel(); return }
                try acceptActionResult(value); phase = .idle
            case .disconnect(let tool):
                let value = try await service.disconnect(tool, request: request)
                guard generation == token else { return }
                guard !Task.isCancelled else { cancel(); return }
                try acceptActionResult(value); phase = .idle
            case .installPlugin(let tool):
                let value = try await service.installPlugin(tool, request: request)
                guard generation == token else { return }
                guard !Task.isCancelled else { cancel(); return }
                guard value.tool == tool else { throw SettingsConnectionFailure.invalidResponse }
                phase = .pluginResult(value)
            }
            changed()
        } catch { failed(error, token: token) }
    }
    private func canRequest(_ action: SettingsConnectionAction) -> Bool {
        switch action {
        case .applyStandardConsent(let allow, let deny):
            let tools = allow + deny
            guard service is any SettingsConnectionAllowing, !tools.isEmpty, Set(tools).count == tools.count,
                  allow.isEmpty ? availability.canForget : availability.canGrant,
                  allow.isEmpty || deny.isEmpty,
                  allow.isEmpty || snapshot?.mode == .automatic || snapshot?.mode == .passive,
                  snapshot?.consentGeneration != nil, let preview = snapshot?.consentPreview else { return false }
            return allow.allSatisfy { id in preview.standardTools.contains(id) && snapshot?.standardTools.contains { $0.tool == id && $0.canRequestConnection } == true }
                && deny.allSatisfy { id in preview.deniableTools.contains(id) && snapshot?.standardTools.contains { $0.tool == id && $0.presence == .detected } == true }
        case .installPlugin(let tool): return availability.pluginTools.contains(tool)
        case .connect(let tool, let access):
            return availability.canGrant && snapshot?.tools.contains { $0.tool == tool && $0.access == access && $0.canRequestConnection } == true
        case .disconnect(let tool): return availability.canForget && snapshot?.tools.contains { $0.tool == tool } == true
        }
    }
    private func accept(_ value: SettingsConnectionSnapshot) throws {
        // A canonical generation rollback cannot replace a newer observed grant/revocation.
        if let current = snapshot?.consentGeneration,
           value.consentGeneration.map({ $0 < current }) ?? true {
            throw SettingsConnectionFailure.stale
        }
        observation &+= 1; snapshot = value
    }
    private func acceptActionResult(_ value: SettingsConnectionSnapshot) throws {
        // Turning reading on/off is not evidence that a subscription stopped belonging to its owner.
        // Do not fabricate a merge: reject an incomplete action receipt and retain the last observation.
        // The app may still replace ownership via its separately verified receive(...) observation.
        let prior = snapshot?.subscriptions ?? []
        guard prior.allSatisfy({ old in value.subscriptions.contains { $0.reference == old.reference && $0.tool == old.tool } })
        else { throw SettingsConnectionFailure.invalidResponse }
        try accept(value)
    }
    private func failed(_ error: Error, token: UInt64) {
        guard generation == token else { return }
        if Task.isCancelled || error is CancellationError { phase = .cancelled }
        else { phase = .failed((error as? SettingsConnectionFailure) ?? .requestFailed) }
        changed()
    }
}
