// Copyright (c) 2026 qunqin24. Licensed under the Apache License, Version 2.0.
// ModelPlan adaptation: explicit requests only; no UserDefaults default-on,
// LaunchAgents, adoption or path repair. Requested choice stays in Settings.
import Foundation
import ServiceManagement

public enum PulseLoginState: Equatable, Sendable { case on, off, needsApproval, unavailable }
public enum PulseLoginOrigin: Sendable { case explicitUserChoice, firstRunCompletion, restoration, systemObservation }
public enum PulseLoginResult: Equatable, Sendable {
    case unchanged(PulseLoginState), performed(PulseLoginState), failed(PulseLoginState), unsupported
}
@MainActor public protocol PulseLoginService: AnyObject {
    var state: PulseLoginState { get }
    func register() throws
    func unregister() throws
}
@MainActor private final class MainAppLoginService: PulseLoginService {
    var state: PulseLoginState {
        switch SMAppService.mainApp.status {
        case .enabled: return .on
        case .notRegistered: return .off
        case .requiresApproval: return .needsApproval
        case .notFound: return .unavailable
        @unknown default: return .unavailable
        }
    }
    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
}

/// Modern app-bundle route only. Bare executables report unsupported and never
/// write a LaunchAgent. Neither initialization nor observation registers anything.
@MainActor public final class PulseLoginItem {
    private let isAppBundle: Bool
    private let service: any PulseLoginService
    public init(isAppBundle: Bool, service: any PulseLoginService) {
        self.isAppBundle = isAppBundle; self.service = service
    }
    public convenience init(bundle: Bundle = .main) {
        self.init(isAppBundle: bundle.bundleIdentifier != nil && bundle.bundlePath.hasSuffix(".app"),
                  service: MainAppLoginService())
    }
    public var state: PulseLoginState { isAppBundle ? service.state : .unavailable }
    public func request(enabled: Bool, origin: PulseLoginOrigin) -> PulseLoginResult {
        guard isAppBundle else { return .unsupported }
        let observed = service.state
        guard origin == .explicitUserChoice || origin == .firstRunCompletion else { return .unchanged(observed) }
        switch (observed, enabled) {
        case (.off, true), (.on, false), (.needsApproval, false): break
        case (.unavailable, _): return .unsupported
        default: return .unchanged(observed)
        }
        do {
            if enabled { try service.register() } else { try service.unregister() }
            // Approval-required and externally changed state are reported as
            // observed, never converted optimistically into enabled/disabled.
            return .performed(service.state)
        } catch { return .failed(service.state) }
    }
}
