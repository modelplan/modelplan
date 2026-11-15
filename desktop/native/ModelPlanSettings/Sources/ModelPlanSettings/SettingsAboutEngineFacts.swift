// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanWire

extension SettingsDiagnosticCode {
    /// G3-67: the coarse diagnostic class of one accepted row reason. Fixed names only; no row text, tool or account.
    public init?(rowsReason code: RowsCode) {
        switch code {
        case .keychainUnset, .keychainDenied, .keychainCanceled, .keychainConfirmationNeeded, .consentRequired, .consentDenied,
             .browserSessionConsentRequired, .privacyBlocked, .http401, .loginExpired:
            self = .permissionDenied
        case .updateRequired, .unsupportedLogin, .schemaChanged, .catalogueRetired:
            self = .unsupported
        case .staleReading:
            self = .stale
        case .runtimeMissing, .toolNotFound, .keyMissing, .noReader, .keychainNotFound, .keychainUnavailable, .fileMissing,
             .fileUnreadable, .parseError, .notAdmitted:
            self = .readerUnavailable
        default:
            return nil
        }
    }
}

extension SettingsAbout {
    /// G3-67: the copied diagnostics describe the running engine instead of staying at their defaults.
    /// `cliVersion` is the server version of the accepted initialize reply (nil while no session is accepted).
    /// `allowedTools` are the tool ids whose consent the engine reports as allowed; `reasonCodes` are the accepted
    /// reasons of the current rows. Nothing here carries a path, an account or free text.
    public mutating func applyEngineFacts(cliVersion: String?, allowedTools: [String], reasonCodes: [RowsCode]) {
        var errors: [SettingsDiagnosticCode] = []
        if let cliVersion { self.cliVersion = cliVersion } else { errors.append(.cliUnavailable) }
        enabledReaders = Set(allowedTools.compactMap(SettingsReaderID.init(rawValue:)))
        enabledConnectionTools = Set(allowedTools.compactMap(SettingsConnectionTool.init(rawValue:)))
        for code in reasonCodes {
            if let mapped = SettingsDiagnosticCode(rowsReason: code), !errors.contains(mapped) { errors.append(mapped) }
        }
        recentErrorCodes = errors
    }
}
