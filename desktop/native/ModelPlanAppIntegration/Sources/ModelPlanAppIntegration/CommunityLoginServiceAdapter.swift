// SPDX-License-Identifier: MIT
import ModelPlanSettings
import ModelPlanShell

public enum CommunityLoginHandling: Equatable, Sendable {
    case unhandled, stale, alreadyHandled, notAuthorized, unsupported
    case observed(LoginServiceState), performed(LoginServiceState), failed(LoginServiceState)
}
/// Host-owned effect adapter. It does not install/replace the editor's single
/// onHostRequest receiver: the entry owner forwards only its accepted request.
@MainActor public final class CommunityLoginServiceAdapter {
    private let item: PulseLoginItem
    private var handledRevision: UInt64?
    public init(item: PulseLoginItem) { self.item = item }
    public var observedState: LoginServiceState { Self.map(item.state) }
    public func handle(_ request: SettingsHostRequest, current: SettingsSnapshot,
                       mayChangeLoginItem: Bool = false) -> CommunityLoginHandling {
        let enabled: Bool, origin: PulseLoginOrigin
        switch request.intent {
        case .action(.setLoginEnabled(let value)): enabled = value; origin = .explicitUserChoice
        case .firstRunCompleted(_, .setLoginEnabled(let value)?): enabled = value; origin = .firstRunCompletion
        default: return .unhandled
        }
        guard request.revision == current.revision,
              current.preferences.openAtLogin == enabled else { return .stale }
        guard mayChangeLoginItem else { return .notAuthorized }
        guard handledRevision.map({ request.revision > $0 }) ?? true else { return .alreadyHandled }
        handledRevision = request.revision
        switch item.request(enabled: enabled, origin: origin) {
        case .unsupported: return .unsupported
        case .unchanged(let value): return .observed(Self.map(value))
        case .performed(let value): return .performed(Self.map(value))
        case .failed(let value): return .failed(Self.map(value))
        }
    }
    private static func map(_ state: PulseLoginState) -> LoginServiceState {
        switch state {
        case .on: return .enabled
        case .off: return .notRegistered
        case .needsApproval: return .requiresApproval
        case .unavailable: return .unavailable
        }
    }
}
