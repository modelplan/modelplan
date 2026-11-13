// SPDX-License-Identifier: MIT
import Foundation
import Security

/// A local code-signature observation, not a Keychain, grant or entitlement fact.
public enum ScopeConsentBuildSigning:Equatable,Sendable {
    case signed, unsigned, unknown
    public static let current:Self = {
        var code:SecCode?
        let own=SecCodeCopySelf(SecCSFlags(rawValue:0),&code)
        if own == errSecCSUnsigned { return .unsigned }
        guard own == errSecSuccess,let code else { return .unknown }
        let validity=SecCodeCheckValidity(code,SecCSFlags(rawValue:0),nil)
        if validity == errSecCSUnsigned { return .unsigned }
        // A valid ad-hoc signature counts as signed here. This promises neither
        // notarization/Developer ID nor persistence of a Keychain item after update.
        return validity == errSecSuccess ? .signed:.unknown
    }()
}
