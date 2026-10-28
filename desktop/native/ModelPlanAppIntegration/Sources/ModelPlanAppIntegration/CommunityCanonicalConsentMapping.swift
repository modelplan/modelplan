// SPDX-License-Identifier: MIT
import ModelPlanCore
import ModelPlanSettings

/// Shared production mapping from bounded CLI readback into the Settings contract.
/// No grant, connection, quota or authentication is inferred during conversion.
public extension CommunityConsentPreviewFacts {
    init(canonical value: ConsentPreview) throws {
        guard let mode = SettingsReadingMode(rawValue: value.mode.rawValue) else {
            throw SettingsConnectionFailure.invalidResponse
        }
        let tools = try value.tools.map { tool -> CommunityConsentToolFacts in
            guard let access = CommunityConsentAccessClass(rawValue: tool.accessClass.rawValue),
                  let keychain = CommunityConsentKeychain(rawValue: tool.keychain.rawValue) else {
                throw SettingsConnectionFailure.invalidResponse
            }
            return .init(id: tool.id, displayName: tool.displayName, accessClass: access,
                         detected: tool.detected, allowed: tool.allowed, backend: tool.backend,
                         readerId: tool.readerId, keychain: keychain, hosts: tool.hosts)
        }
        try self.init(generation: value.generation, consentTextVersion: value.consentTextVersion,
                      mode: mode, tools: tools,
                      consentText: .init(value.consentText.en, value.consentText.zh))
    }
}
