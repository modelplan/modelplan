// SPDX-License-Identifier: MIT
import Foundation

public enum SettingsConnectionUnavailableReason: String, Sendable {
    case componentMissing, componentUpdating, componentUnverified, unavailable
}
/// Cached facts supplied by the component owner. They are not consent or system permission.
public struct SettingsConnectionAvailability: Equatable, Sendable {
    public let reason: SettingsConnectionUnavailableReason?
    public let canInspect, canGrant, canForget: Bool
    public let pluginTools: Set<SettingsPluginTool>
    public init(reason: SettingsConnectionUnavailableReason? = nil, canInspect: Bool = false,
                canGrant: Bool = false, canForget: Bool = false, pluginTools: Set<SettingsPluginTool> = []) {
        self.reason = reason; self.canInspect = canInspect; self.canGrant = canGrant
        self.canForget = canForget; self.pluginTools = pluginTools
    }
    public var hasAnyAction: Bool { canInspect || canGrant || canForget || !pluginTools.isEmpty }
    public static let unverified = Self(reason: .componentUnverified)
    /// Compatibility for the original non-Allowing read/action seam. New production Allowing adapters
    /// must declare their actual capability; they never receive this fallback.
    static let legacy = Self(canInspect: true, canGrant: true, canForget: true, pluginTools: Set(SettingsPluginTool.allCases))
}
@MainActor public protocol SettingsConnectionAvailabilityProviding: SettingsConnectionService {
    /// Must be side-effect-free. Controller reads it only at construction/bind, not during admission.
    var settingsConnectionAvailability: SettingsConnectionAvailability { get }
}
