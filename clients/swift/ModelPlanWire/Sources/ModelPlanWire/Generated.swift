// SPDX-License-Identifier: MIT
// Code generated from Go wire DTOs and JSON tags. DO NOT EDIT.
// Regenerate: cd cli && go run ./internal/swiftwire/cmd --write
import Foundation
public enum WireProtocol {
    public static let version = "1.0"
    public static let jsonrpc = "2.0"
    public static let rowsVersion = 1
    public static let maxFrameBytes = 8388608
}

// This support code is emitted with the DTOs; it never stores engine state.
public enum WireDecodeError: Error, Sendable {
    case invalidIdentity, invalidAuthorization, invalidVersion, invalidBound, invalidFrame, tokenPlacement
}

private struct WireCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

private enum WireValidation {
    static func identity(_ value: String) throws {
        guard !value.isEmpty, value.utf8.count <= 256,
              !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
        else { throw WireDecodeError.invalidIdentity }
    }
    static func reference(_ value: String) throws {
        guard value.count == 16, value.allSatisfy({ "0123456789abcdef".contains($0) })
        else { throw WireDecodeError.invalidIdentity }
    }
    static func toolID(_ value: String) throws {
        guard value.range(of: "^[a-z][a-z0-9-]{0,47}$", options: .regularExpression) != nil
        else { throw WireDecodeError.invalidIdentity }
    }
    static func protocolVersion(_ value: String) throws {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0] == WireProtocol.version.split(separator: ".")[0],
              !parts[1].isEmpty, parts[1].allSatisfy({ $0.isASCII && $0.isNumber })
        else { throw WireDecodeError.invalidVersion }
    }
}

public struct WireTimestamp: Codable, Sendable, Equatable {
    public let rawValue: String
    public init(_ rawValue: String) throws {
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard plain.date(from: rawValue) != nil || fractional.date(from: rawValue) != nil
        else { throw WireDecodeError.invalidBound }
        self.rawValue = rawValue
    }
    public init(from decoder: Decoder) throws { try self.init(decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}

public enum WireRequestID: Codable, Sendable, Equatable {
    case string(String), signed(Int64), unsigned(UInt64)
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let value = try? c.decode(String.self) { try WireValidation.identity(value); self = .string(value) }
        else if let value = try? c.decode(Int64.self) { self = .signed(value) }
        else if let value = try? c.decode(UInt64.self) { self = .unsigned(value) }
        else { throw WireDecodeError.invalidIdentity }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let value): try WireValidation.identity(value); try c.encode(value)
        case .signed(let value): try c.encode(value)
        case .unsigned(let value): try c.encode(value)
        }
    }
}

public indirect enum WireJSONValue: Codable, Sendable, Equatable {
    case object([String: WireJSONValue]), array([WireJSONValue]), string(String)
    case signed(Int64), unsigned(UInt64), number(Double), bool(Bool), null
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let value = try? c.decode(Bool.self) { self = .bool(value) }
        else if let value = try? c.decode(String.self) { self = .string(value) }
        else if let value = try? c.decode(Int64.self) { self = .signed(value) }
        else if let value = try? c.decode(UInt64.self) { self = .unsigned(value) }
        else if let value = try? c.decode(Double.self) { self = .number(value) }
        else if let value = try? c.decode([WireJSONValue].self) { self = .array(value) }
        else { self = .object(try c.decode([String: WireJSONValue].self)) }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .signed(let v): try c.encode(v)
        case .unsigned(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
}

public enum WireDecoder {
    // M0 owns feature isolation and the state/floor; this function never updates a store.
    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        guard data.count <= WireProtocol.maxFrameBytes else { throw WireDecodeError.invalidFrame }
        let tree = try JSONDecoder().decode(WireJSONValue.self, from: data)
        let credential = type == WireCredentialResult.self
        let credentialRequest: Bool
        if type == WireRequest.self, case .object(let fields) = tree,
           fields["method"] == .string("credentials/result") { credentialRequest = true }
        else { credentialRequest = false }
        try checkTokens(tree, path: [], directCredential: credential, credentialRequest: credentialRequest)
        return try JSONDecoder().decode(type, from: data)
    }
    private static func checkTokens(_ value: WireJSONValue, path: [String], directCredential: Bool, credentialRequest: Bool) throws {
        switch value {
        case .object(let fields):
            for (key, child) in fields {
                if key == "accessToken" && !((directCredential && path.isEmpty) || (credentialRequest && path == ["params"])) {
                    throw WireDecodeError.tokenPlacement
                }
                try checkTokens(child, path: path + [key], directCredential: directCredential, credentialRequest: credentialRequest)
            }
        case .array(let items):
            for child in items { try checkTokens(child, path: path + ["[]"], directCredential: directCredential, credentialRequest: credentialRequest) }
        default: break
        }
    }
}

public struct RowsAccount: Codable, Sendable {
    public let `route`: RowsRoute
    public let `subscriptionRef`: String?
    public let `accountLocator`: String?
    public let `plan`: RowsPlan
    public let `beta`: Bool
    public let `credits`: RowsCredits?
    public let `valueState`: RowsValueState
    public let `observedAt`: WireTimestamp?
    public let `freshUntil`: WireTimestamp?
    public let `lastFailure`: RowsFailure?
    public let `windows`: [RowsWindow]
    private enum CodingKeys: String, CodingKey {
        case `route`
        case `subscriptionRef`
        case `accountLocator`
        case `plan`
        case `beta`
        case `credits`
        case `valueState`
        case `observedAt`
        case `freshUntil`
        case `lastFailure`
        case `windows`
    }
    public init(`route`: RowsRoute, `subscriptionRef`: String? = nil, `accountLocator`: String? = nil, `plan`: RowsPlan, `beta`: Bool, `credits`: RowsCredits? = nil, `valueState`: RowsValueState, `observedAt`: WireTimestamp? = nil, `freshUntil`: WireTimestamp? = nil, `lastFailure`: RowsFailure? = nil, `windows`: [RowsWindow]) throws {
        self.`route` = `route`
        self.`subscriptionRef` = `subscriptionRef`
        self.`accountLocator` = `accountLocator`
        self.`plan` = `plan`
        self.`beta` = `beta`
        self.`credits` = `credits`
        self.`valueState` = `valueState`
        self.`observedAt` = `observedAt`
        self.`freshUntil` = `freshUntil`
        self.`lastFailure` = `lastFailure`
        self.`windows` = `windows`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`route` = try c.decode(RowsRoute.self, forKey: .`route`)
        self.`subscriptionRef` = try c.decodeIfPresent(String.self, forKey: .`subscriptionRef`)
        self.`accountLocator` = try c.decodeIfPresent(String.self, forKey: .`accountLocator`)
        self.`plan` = try c.decode(RowsPlan.self, forKey: .`plan`)
        self.`beta` = try c.decode(Bool.self, forKey: .`beta`)
        self.`credits` = try? c.decodeIfPresent(RowsCredits.self, forKey: .`credits`)
        self.`valueState` = try c.decode(RowsValueState.self, forKey: .`valueState`)
        self.`observedAt` = try? c.decodeIfPresent(WireTimestamp.self, forKey: .`observedAt`)
        self.`freshUntil` = try? c.decodeIfPresent(WireTimestamp.self, forKey: .`freshUntil`)
        self.`lastFailure` = try? c.decodeIfPresent(RowsFailure.self, forKey: .`lastFailure`)
        self.`windows` = try c.decode([RowsWindow].self, forKey: .`windows`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`route`, forKey: .`route`)
        try c.encode(`subscriptionRef`, forKey: .`subscriptionRef`)
        try c.encode(`accountLocator`, forKey: .`accountLocator`)
        try c.encode(`plan`, forKey: .`plan`)
        try c.encode(`beta`, forKey: .`beta`)
        try c.encode(`credits`, forKey: .`credits`)
        try c.encode(`valueState`, forKey: .`valueState`)
        try c.encode(`observedAt`, forKey: .`observedAt`)
        try c.encode(`freshUntil`, forKey: .`freshUntil`)
        try c.encode(`lastFailure`, forKey: .`lastFailure`)
        try c.encode(`windows`, forKey: .`windows`)
    }
    private func validate() throws {
        if let value = `subscriptionRef` { try WireValidation.reference(value) }
        if let value = `accountLocator` { try WireValidation.reference(value) }
    }
}

public enum RowsAction: Codable, Sendable, Equatable {
    case `openSettingsConsent`
    case `openSettingsKeychain`
    case `openTool`
    case `installRuntime`
    case `refresh`
    case `updateCli`
    case `none`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "open_settings_consent": self = .`openSettingsConsent`
        case "open_settings_keychain": self = .`openSettingsKeychain`
        case "open_tool": self = .`openTool`
        case "install_runtime": self = .`installRuntime`
        case "refresh": self = .`refresh`
        case "update_cli": self = .`updateCli`
        case "none": self = .`none`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`openSettingsConsent`: return "open_settings_consent"
        case .`openSettingsKeychain`: return "open_settings_keychain"
        case .`openTool`: return "open_tool"
        case .`installRuntime`: return "install_runtime"
        case .`refresh`: return "refresh"
        case .`updateCli`: return "update_cli"
        case .`none`: return "none"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public enum RowsCode: Codable, Sendable, Equatable {
    case `ok`
    case `estimated`
    case `staleReading`
    case `observationTimeUnknown`
    case `notReadYet`
    case `readerBusy`
    case `consentChanged`
    case `noManualReading`
    case `noUsageWindows`
    case `consentRequired`
    case `consentDenied`
    case `consentOutdated`
    case `keychainUnset`
    case `keychainDenied`
    case `keychainCanceled`
    case `keychainNotFound`
    case `keychainUnavailable`
    case `keychainConfirmationNeeded`
    case `loginExpired`
    case `runtimeMissing`
    case `updateRequired`
    case `keyMissing`
    case `toolNotFound`
    case `catalogueRetired`
    case `http401`
    case `unsupportedLogin`
    case `privacyBlocked`
    case `catalogueOff`
    case `notAdmitted`
    case `codexbarNotAudited`
    case `codexbarNotRead`
    case `codexbarAccessUnknown`
    case `browserSessionConsentRequired`
    case `noReader`
    case `cleanupPending`
    case `fileMissing`
    case `fileUnreadable`
    case `parseError`
    case `schemaChanged`
    case `http403`
    case `http429`
    case `http5xx`
    case `network`
    case `timeout`
    case `other`
    case `readersOff`
    case `noConsent`
    case `noDockRows`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "ok": self = .`ok`
        case "estimated": self = .`estimated`
        case "stale_reading": self = .`staleReading`
        case "observation_time_unknown": self = .`observationTimeUnknown`
        case "not_read_yet": self = .`notReadYet`
        case "reader_busy": self = .`readerBusy`
        case "consent_changed": self = .`consentChanged`
        case "no_manual_reading": self = .`noManualReading`
        case "no_usage_windows": self = .`noUsageWindows`
        case "consent_required": self = .`consentRequired`
        case "consent_denied": self = .`consentDenied`
        case "consent_outdated": self = .`consentOutdated`
        case "keychain_unset": self = .`keychainUnset`
        case "keychain_denied": self = .`keychainDenied`
        case "keychain_canceled": self = .`keychainCanceled`
        case "keychain_not_found": self = .`keychainNotFound`
        case "keychain_unavailable": self = .`keychainUnavailable`
        case "keychain_confirmation_needed": self = .`keychainConfirmationNeeded`
        case "login_expired": self = .`loginExpired`
        case "runtime_missing": self = .`runtimeMissing`
        case "update_required": self = .`updateRequired`
        case "key_missing": self = .`keyMissing`
        case "tool_not_found": self = .`toolNotFound`
        case "catalogue_retired": self = .`catalogueRetired`
        case "http_401": self = .`http401`
        case "unsupported_login": self = .`unsupportedLogin`
        case "privacy_blocked": self = .`privacyBlocked`
        case "catalogue_off": self = .`catalogueOff`
        case "not_admitted": self = .`notAdmitted`
        case "codexbar_not_audited": self = .`codexbarNotAudited`
        case "codexbar_not_read": self = .`codexbarNotRead`
        case "codexbar_access_unknown": self = .`codexbarAccessUnknown`
        case "browser_session_consent_required": self = .`browserSessionConsentRequired`
        case "no_reader": self = .`noReader`
        case "cleanup_pending": self = .`cleanupPending`
        case "file_missing": self = .`fileMissing`
        case "file_unreadable": self = .`fileUnreadable`
        case "parse_error": self = .`parseError`
        case "schema_changed": self = .`schemaChanged`
        case "http_403": self = .`http403`
        case "http_429": self = .`http429`
        case "http_5xx": self = .`http5xx`
        case "network": self = .`network`
        case "timeout": self = .`timeout`
        case "other": self = .`other`
        case "readers_off": self = .`readersOff`
        case "no_consent": self = .`noConsent`
        case "no_dock_rows": self = .`noDockRows`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`ok`: return "ok"
        case .`estimated`: return "estimated"
        case .`staleReading`: return "stale_reading"
        case .`observationTimeUnknown`: return "observation_time_unknown"
        case .`notReadYet`: return "not_read_yet"
        case .`readerBusy`: return "reader_busy"
        case .`consentChanged`: return "consent_changed"
        case .`noManualReading`: return "no_manual_reading"
        case .`noUsageWindows`: return "no_usage_windows"
        case .`consentRequired`: return "consent_required"
        case .`consentDenied`: return "consent_denied"
        case .`consentOutdated`: return "consent_outdated"
        case .`keychainUnset`: return "keychain_unset"
        case .`keychainDenied`: return "keychain_denied"
        case .`keychainCanceled`: return "keychain_canceled"
        case .`keychainNotFound`: return "keychain_not_found"
        case .`keychainUnavailable`: return "keychain_unavailable"
        case .`keychainConfirmationNeeded`: return "keychain_confirmation_needed"
        case .`loginExpired`: return "login_expired"
        case .`runtimeMissing`: return "runtime_missing"
        case .`updateRequired`: return "update_required"
        case .`keyMissing`: return "key_missing"
        case .`toolNotFound`: return "tool_not_found"
        case .`catalogueRetired`: return "catalogue_retired"
        case .`http401`: return "http_401"
        case .`unsupportedLogin`: return "unsupported_login"
        case .`privacyBlocked`: return "privacy_blocked"
        case .`catalogueOff`: return "catalogue_off"
        case .`notAdmitted`: return "not_admitted"
        case .`codexbarNotAudited`: return "codexbar_not_audited"
        case .`codexbarNotRead`: return "codexbar_not_read"
        case .`codexbarAccessUnknown`: return "codexbar_access_unknown"
        case .`browserSessionConsentRequired`: return "browser_session_consent_required"
        case .`noReader`: return "no_reader"
        case .`cleanupPending`: return "cleanup_pending"
        case .`fileMissing`: return "file_missing"
        case .`fileUnreadable`: return "file_unreadable"
        case .`parseError`: return "parse_error"
        case .`schemaChanged`: return "schema_changed"
        case .`http403`: return "http_403"
        case .`http429`: return "http_429"
        case .`http5xx`: return "http_5xx"
        case .`network`: return "network"
        case .`timeout`: return "timeout"
        case .`other`: return "other"
        case .`readersOff`: return "readers_off"
        case .`noConsent`: return "no_consent"
        case .`noDockRows`: return "no_dock_rows"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public enum RowsConsent: Codable, Sendable, Equatable {
    case `allowed`
    case `implicit`
    case `denied`
    case `unset`
    case `notRequired`
    case `retired`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "allowed": self = .`allowed`
        case "implicit": self = .`implicit`
        case "denied": self = .`denied`
        case "unset": self = .`unset`
        case "not_required": self = .`notRequired`
        case "retired": self = .`retired`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`allowed`: return "allowed"
        case .`implicit`: return "implicit"
        case .`denied`: return "denied"
        case .`unset`: return "unset"
        case .`notRequired`: return "not_required"
        case .`retired`: return "retired"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public struct RowsCredits: Codable, Sendable {
    public let `balance`: Double?
    public let `unit`: String
    private enum CodingKeys: String, CodingKey {
        case `balance`
        case `unit`
    }
    public init(`balance`: Double? = nil, `unit`: String) throws {
        self.`balance` = `balance`
        self.`unit` = `unit`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`balance` = try? c.decodeIfPresent(Double.self, forKey: .`balance`)
        self.`unit` = try c.decode(String.self, forKey: .`unit`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`balance`, forKey: .`balance`)
        try c.encode(`unit`, forKey: .`unit`)
    }
    private func validate() throws {
    }
}

public enum RowsDisabledReason: Codable, Sendable, Equatable {
    case `cooldown`
    case `readOnly`
    case `offline`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "cooldown": self = .`cooldown`
        case "read_only": self = .`readOnly`
        case "offline": self = .`offline`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`cooldown`: return "cooldown"
        case .`readOnly`: return "read_only"
        case .`offline`: return "offline"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public struct RowsExpiryState: Codable, Sendable {
    public let `state`: RowsState
    public let `reason`: RowsReason
    public let `nextStep`: RowsNextStep?
    private enum CodingKeys: String, CodingKey {
        case `state`
        case `reason`
        case `nextStep`
    }
    public init(`state`: RowsState, `reason`: RowsReason, `nextStep`: RowsNextStep? = nil) throws {
        self.`state` = `state`
        self.`reason` = `reason`
        self.`nextStep` = `nextStep`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`state` = try c.decode(RowsState.self, forKey: .`state`)
        self.`reason` = try c.decode(RowsReason.self, forKey: .`reason`)
        self.`nextStep` = try? c.decodeIfPresent(RowsNextStep.self, forKey: .`nextStep`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`state`, forKey: .`state`)
        try c.encode(`reason`, forKey: .`reason`)
        try c.encode(`nextStep`, forKey: .`nextStep`)
    }
    private func validate() throws {
    }
}

public struct RowsFailure: Codable, Sendable {
    public let `code`: RowsCode
    public let `at`: WireTimestamp
    private enum CodingKeys: String, CodingKey {
        case `code`
        case `at`
    }
    public init(`code`: RowsCode, `at`: WireTimestamp) throws {
        self.`code` = `code`
        self.`at` = `at`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`code` = try c.decode(RowsCode.self, forKey: .`code`)
        self.`at` = try c.decode(WireTimestamp.self, forKey: .`at`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`code`, forKey: .`code`)
        try c.encode(`at`, forKey: .`at`)
    }
    private func validate() throws {
    }
}

public enum RowsKind: Codable, Sendable, Equatable {
    case `tool`
    case `declared`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "tool": self = .`tool`
        case "declared": self = .`declared`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`tool`: return "tool"
        case .`declared`: return "declared"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public struct RowsName: Codable, Sendable {
    public let `en`: String
    public let `zh`: String
    public let `userAuthored`: Bool?
    private enum CodingKeys: String, CodingKey {
        case `en`
        case `zh`
        case `userAuthored`
    }
    public init(`en`: String, `zh`: String, `userAuthored`: Bool? = nil) throws {
        self.`en` = `en`
        self.`zh` = `zh`
        self.`userAuthored` = `userAuthored`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`en` = try c.decode(String.self, forKey: .`en`)
        self.`zh` = try c.decode(String.self, forKey: .`zh`)
        self.`userAuthored` = try? c.decodeIfPresent(Bool.self, forKey: .`userAuthored`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`en`, forKey: .`en`)
        try c.encode(`zh`, forKey: .`zh`)
        try c.encodeIfPresent(`userAuthored`, forKey: .`userAuthored`)
    }
    private func validate() throws {
    }
}

public struct RowsNextStep: Codable, Sendable {
    public let `action`: RowsAction
    public let `text`: RowsText
    public let `availableAt`: WireTimestamp?
    public let `disabledReason`: RowsDisabledReason?
    private enum CodingKeys: String, CodingKey {
        case `action`
        case `text`
        case `availableAt`
        case `disabledReason`
    }
    public init(`action`: RowsAction, `text`: RowsText, `availableAt`: WireTimestamp? = nil, `disabledReason`: RowsDisabledReason? = nil) throws {
        self.`action` = `action`
        self.`text` = `text`
        self.`availableAt` = `availableAt`
        self.`disabledReason` = `disabledReason`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`action` = try c.decode(RowsAction.self, forKey: .`action`)
        self.`text` = try c.decode(RowsText.self, forKey: .`text`)
        self.`availableAt` = try? c.decodeIfPresent(WireTimestamp.self, forKey: .`availableAt`)
        self.`disabledReason` = try? c.decodeIfPresent(RowsDisabledReason.self, forKey: .`disabledReason`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`action`, forKey: .`action`)
        try c.encode(`text`, forKey: .`text`)
        try c.encodeIfPresent(`availableAt`, forKey: .`availableAt`)
        try c.encodeIfPresent(`disabledReason`, forKey: .`disabledReason`)
    }
    private func validate() throws {
    }
}

public struct RowsPlan: Codable, Sendable {
    public let `id`: String
    public let `name`: RowsName?
    private enum CodingKeys: String, CodingKey {
        case `id`
        case `name`
    }
    public init(`id`: String, `name`: RowsName? = nil) throws {
        self.`id` = `id`
        self.`name` = `name`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`id` = try c.decode(String.self, forKey: .`id`)
        self.`name` = try? c.decodeIfPresent(RowsName.self, forKey: .`name`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`id`, forKey: .`id`)
        try c.encodeIfPresent(`name`, forKey: .`name`)
    }
    private func validate() throws {
        try WireValidation.identity(`id`)
    }
}

public struct RowsProjection: Codable, Sendable {
    public let `rowsVersion`: Int
    public let `consentGeneration`: UInt64
    public let `rows`: [RowsRow]
    public let `rowsSummary`: RowsRowsSummary
    private enum CodingKeys: String, CodingKey {
        case `rowsVersion`
        case `consentGeneration`
        case `rows`
        case `rowsSummary`
    }
    public init(`rowsVersion`: Int, `consentGeneration`: UInt64, `rows`: [RowsRow], `rowsSummary`: RowsRowsSummary) throws {
        self.`rowsVersion` = `rowsVersion`
        self.`consentGeneration` = `consentGeneration`
        self.`rows` = `rows`
        self.`rowsSummary` = `rowsSummary`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`rowsVersion` = try c.decode(Int.self, forKey: .`rowsVersion`)
        self.`consentGeneration` = try c.decode(UInt64.self, forKey: .`consentGeneration`)
        self.`rows` = try c.decode([RowsRow].self, forKey: .`rows`)
        self.`rowsSummary` = try c.decode(RowsRowsSummary.self, forKey: .`rowsSummary`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`rowsVersion`, forKey: .`rowsVersion`)
        try c.encode(`consentGeneration`, forKey: .`consentGeneration`)
        try c.encode(`rows`, forKey: .`rows`)
        try c.encode(`rowsSummary`, forKey: .`rowsSummary`)
    }
    private func validate() throws {
        guard `consentGeneration` >= 0 else { throw WireDecodeError.invalidBound }
        guard rowsVersion == WireProtocol.rowsVersion else { throw WireDecodeError.invalidVersion }
        guard Set(rows.map { $0.id }).count == rows.count else { throw WireDecodeError.invalidIdentity }
    }
}

public struct RowsReason: Codable, Sendable {
    public let `code`: RowsCode
    public let `text`: RowsText
    private enum CodingKeys: String, CodingKey {
        case `code`
        case `text`
    }
    public init(`code`: RowsCode, `text`: RowsText) throws {
        self.`code` = `code`
        self.`text` = `text`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`code` = try c.decode(RowsCode.self, forKey: .`code`)
        self.`text` = try c.decode(RowsText.self, forKey: .`text`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`code`, forKey: .`code`)
        try c.encode(`text`, forKey: .`text`)
    }
    private func validate() throws {
    }
}

public enum RowsResetMode: Codable, Sendable, Equatable {
    case `fixed`
    case `rolling`
    case `knownUnknown`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "fixed": self = .`fixed`
        case "rolling": self = .`rolling`
        case "unknown": self = .`knownUnknown`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`fixed`: return "fixed"
        case .`rolling`: return "rolling"
        case .`knownUnknown`: return "unknown"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public enum RowsRole: Codable, Sendable, Equatable {
    case `session`
    case `daily`
    case `weekly`
    case `monthly`
    case `other`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "session": self = .`session`
        case "daily": self = .`daily`
        case "weekly": self = .`weekly`
        case "monthly": self = .`monthly`
        case "other": self = .`other`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`session`: return "session"
        case .`daily`: return "daily"
        case .`weekly`: return "weekly"
        case .`monthly`: return "monthly"
        case .`other`: return "other"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public enum RowsRoute: Codable, Sendable, Equatable {
    case `savedLoginApi`
    case `runtimeRpc`
    case `localLog`
    case `apiKeyApi`
    case `localSqlite`
    case `statusLine`
    case `browserSession`
    case `manual`
    case `knownUnknown`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "saved_login_api": self = .`savedLoginApi`
        case "runtime_rpc": self = .`runtimeRpc`
        case "local_log": self = .`localLog`
        case "api_key_api": self = .`apiKeyApi`
        case "local_sqlite": self = .`localSqlite`
        case "status_line": self = .`statusLine`
        case "browser_session": self = .`browserSession`
        case "manual": self = .`manual`
        case "unknown": self = .`knownUnknown`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`savedLoginApi`: return "saved_login_api"
        case .`runtimeRpc`: return "runtime_rpc"
        case .`localLog`: return "local_log"
        case .`apiKeyApi`: return "api_key_api"
        case .`localSqlite`: return "local_sqlite"
        case .`statusLine`: return "status_line"
        case .`browserSession`: return "browser_session"
        case .`manual`: return "manual"
        case .`knownUnknown`: return "unknown"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public struct RowsRow: Codable, Sendable {
    public let `id`: String
    public let `kind`: RowsKind
    public let `order`: Int
    public let `name`: RowsName
    public let `vendorKey`: String?
    public let `surfaces`: [RowsSurface]
    public let `consent`: RowsConsent
    public let `state`: RowsState
    public let `reason`: RowsReason
    public let `nextStep`: RowsNextStep?
    public let `accounts`: [RowsAccount]
    public let `expiresAt`: WireTimestamp?
    public let `stateAfterExpiry`: RowsExpiryState?
    private enum CodingKeys: String, CodingKey {
        case `id`
        case `kind`
        case `order`
        case `name`
        case `vendorKey`
        case `surfaces`
        case `consent`
        case `state`
        case `reason`
        case `nextStep`
        case `accounts`
        case `expiresAt`
        case `stateAfterExpiry`
    }
    public init(`id`: String, `kind`: RowsKind, `order`: Int, `name`: RowsName, `vendorKey`: String? = nil, `surfaces`: [RowsSurface], `consent`: RowsConsent, `state`: RowsState, `reason`: RowsReason, `nextStep`: RowsNextStep? = nil, `accounts`: [RowsAccount], `expiresAt`: WireTimestamp? = nil, `stateAfterExpiry`: RowsExpiryState? = nil) throws {
        self.`id` = `id`
        self.`kind` = `kind`
        self.`order` = `order`
        self.`name` = `name`
        self.`vendorKey` = `vendorKey`
        self.`surfaces` = `surfaces`
        self.`consent` = `consent`
        self.`state` = `state`
        self.`reason` = `reason`
        self.`nextStep` = `nextStep`
        self.`accounts` = `accounts`
        self.`expiresAt` = `expiresAt`
        self.`stateAfterExpiry` = `stateAfterExpiry`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`id` = try c.decode(String.self, forKey: .`id`)
        self.`kind` = try c.decode(RowsKind.self, forKey: .`kind`)
        self.`order` = try c.decode(Int.self, forKey: .`order`)
        self.`name` = try c.decode(RowsName.self, forKey: .`name`)
        self.`vendorKey` = try? c.decodeIfPresent(String.self, forKey: .`vendorKey`)
        self.`surfaces` = try c.decode([RowsSurface].self, forKey: .`surfaces`)
        self.`consent` = try c.decode(RowsConsent.self, forKey: .`consent`)
        self.`state` = try c.decode(RowsState.self, forKey: .`state`)
        self.`reason` = try c.decode(RowsReason.self, forKey: .`reason`)
        self.`nextStep` = try? c.decodeIfPresent(RowsNextStep.self, forKey: .`nextStep`)
        self.`accounts` = try c.decode([RowsAccount].self, forKey: .`accounts`)
        self.`expiresAt` = try? c.decodeIfPresent(WireTimestamp.self, forKey: .`expiresAt`)
        self.`stateAfterExpiry` = try? c.decodeIfPresent(RowsExpiryState.self, forKey: .`stateAfterExpiry`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`id`, forKey: .`id`)
        try c.encode(`kind`, forKey: .`kind`)
        try c.encode(`order`, forKey: .`order`)
        try c.encode(`name`, forKey: .`name`)
        try c.encode(`vendorKey`, forKey: .`vendorKey`)
        try c.encode(`surfaces`, forKey: .`surfaces`)
        try c.encode(`consent`, forKey: .`consent`)
        try c.encode(`state`, forKey: .`state`)
        try c.encode(`reason`, forKey: .`reason`)
        try c.encode(`nextStep`, forKey: .`nextStep`)
        try c.encode(`accounts`, forKey: .`accounts`)
        try c.encode(`expiresAt`, forKey: .`expiresAt`)
        try c.encode(`stateAfterExpiry`, forKey: .`stateAfterExpiry`)
    }
    private func validate() throws {
        try WireValidation.identity(`id`)
        guard `kind`.isKnown else { throw WireDecodeError.invalidAuthorization }
        guard `consent`.isKnown else { throw WireDecodeError.invalidAuthorization }
        try WireValidation.identity(id)
        if kind.rawValue == "tool" { try WireValidation.toolID(id) }
        if kind.rawValue == "declared" && (!id.hasPrefix("declared:") || id.count <= 9) { throw WireDecodeError.invalidIdentity }
        if ["denied", "unset", "retired"].contains(consent.rawValue) && !accounts.isEmpty { throw WireDecodeError.invalidAuthorization }
    }
}

public struct RowsRowsSummary: Codable, Sendable {
    public let `state`: RowsSummaryState
    public let `reason`: RowsReason
    public let `text`: RowsText
    public let `nextStep`: RowsNextStep?
    private enum CodingKeys: String, CodingKey {
        case `state`
        case `reason`
        case `text`
        case `nextStep`
    }
    public init(`state`: RowsSummaryState, `reason`: RowsReason, `text`: RowsText, `nextStep`: RowsNextStep? = nil) throws {
        self.`state` = `state`
        self.`reason` = `reason`
        self.`text` = `text`
        self.`nextStep` = `nextStep`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`state` = try c.decode(RowsSummaryState.self, forKey: .`state`)
        self.`reason` = try c.decode(RowsReason.self, forKey: .`reason`)
        self.`text` = try c.decode(RowsText.self, forKey: .`text`)
        self.`nextStep` = try? c.decodeIfPresent(RowsNextStep.self, forKey: .`nextStep`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`state`, forKey: .`state`)
        try c.encode(`reason`, forKey: .`reason`)
        try c.encode(`text`, forKey: .`text`)
        try c.encode(`nextStep`, forKey: .`nextStep`)
    }
    private func validate() throws {
    }
}

public enum RowsState: Codable, Sendable, Equatable {
    case `off`
    case `needsAction`
    case `needsConsent`
    case `pending`
    case `unsupported`
    case `needsKeychain`
    case `failed`
    case `empty`
    case `stale`
    case `fresh`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "off": self = .`off`
        case "needs_action": self = .`needsAction`
        case "needs_consent": self = .`needsConsent`
        case "pending": self = .`pending`
        case "unsupported": self = .`unsupported`
        case "needs_keychain": self = .`needsKeychain`
        case "failed": self = .`failed`
        case "empty": self = .`empty`
        case "stale": self = .`stale`
        case "fresh": self = .`fresh`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`off`: return "off"
        case .`needsAction`: return "needs_action"
        case .`needsConsent`: return "needs_consent"
        case .`pending`: return "pending"
        case .`unsupported`: return "unsupported"
        case .`needsKeychain`: return "needs_keychain"
        case .`failed`: return "failed"
        case .`empty`: return "empty"
        case .`stale`: return "stale"
        case .`fresh`: return "fresh"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public enum RowsSummaryState: Codable, Sendable, Equatable {
    case `ok`
    case `readersOff`
    case `noConsent`
    case `empty`
    case `pending`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "ok": self = .`ok`
        case "readers_off": self = .`readersOff`
        case "no_consent": self = .`noConsent`
        case "empty": self = .`empty`
        case "pending": self = .`pending`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`ok`: return "ok"
        case .`readersOff`: return "readers_off"
        case .`noConsent`: return "no_consent"
        case .`empty`: return "empty"
        case .`pending`: return "pending"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public enum RowsSurface: Codable, Sendable, Equatable {
    case `dock`
    case `menu`
    case `settings`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "dock": self = .`dock`
        case "menu": self = .`menu`
        case "settings": self = .`settings`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`dock`: return "dock"
        case .`menu`: return "menu"
        case .`settings`: return "settings"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public struct RowsText: Codable, Sendable {
    public let `en`: String
    public let `zh`: String
    private enum CodingKeys: String, CodingKey {
        case `en`
        case `zh`
    }
    public init(`en`: String, `zh`: String) throws {
        self.`en` = `en`
        self.`zh` = `zh`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`en` = try c.decode(String.self, forKey: .`en`)
        self.`zh` = try c.decode(String.self, forKey: .`zh`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`en`, forKey: .`en`)
        try c.encode(`zh`, forKey: .`zh`)
    }
    private func validate() throws {
    }
}

public enum RowsValueState: Codable, Sendable, Equatable {
    case `current`
    case `retained`
    case `none`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "current": self = .`current`
        case "retained": self = .`retained`
        case "none": self = .`none`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`current`: return "current"
        case .`retained`: return "retained"
        case .`none`: return "none"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public struct RowsWindow: Codable, Sendable {
    public let `id`: String
    public let `role`: RowsRole
    public let `durationSeconds`: Int64?
    public let `label`: RowsText
    public let `limitKey`: String
    public let `poolKey`: String
    public let `resetMode`: RowsResetMode
    public let `remainingPercent`: Double?
    public let `resetsAt`: WireTimestamp?
    public let `observedAt`: WireTimestamp?
    public let `current`: Bool
    public let `validUntil`: WireTimestamp?
    private enum CodingKeys: String, CodingKey {
        case `id`
        case `role`
        case `durationSeconds`
        case `label`
        case `limitKey`
        case `poolKey`
        case `resetMode`
        case `remainingPercent`
        case `resetsAt`
        case `observedAt`
        case `current`
        case `validUntil`
    }
    public init(`id`: String, `role`: RowsRole, `durationSeconds`: Int64? = nil, `label`: RowsText, `limitKey`: String, `poolKey`: String, `resetMode`: RowsResetMode, `remainingPercent`: Double? = nil, `resetsAt`: WireTimestamp? = nil, `observedAt`: WireTimestamp? = nil, `current`: Bool, `validUntil`: WireTimestamp? = nil) throws {
        self.`id` = `id`
        self.`role` = `role`
        self.`durationSeconds` = `durationSeconds`
        self.`label` = `label`
        self.`limitKey` = `limitKey`
        self.`poolKey` = `poolKey`
        self.`resetMode` = `resetMode`
        self.`remainingPercent` = `remainingPercent`
        self.`resetsAt` = `resetsAt`
        self.`observedAt` = `observedAt`
        self.`current` = `current`
        self.`validUntil` = `validUntil`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`id` = try c.decode(String.self, forKey: .`id`)
        self.`role` = try c.decode(RowsRole.self, forKey: .`role`)
        self.`durationSeconds` = try? c.decodeIfPresent(Int64.self, forKey: .`durationSeconds`)
        self.`label` = try c.decode(RowsText.self, forKey: .`label`)
        self.`limitKey` = try c.decode(String.self, forKey: .`limitKey`)
        self.`poolKey` = try c.decode(String.self, forKey: .`poolKey`)
        self.`resetMode` = try c.decode(RowsResetMode.self, forKey: .`resetMode`)
        self.`remainingPercent` = try? c.decodeIfPresent(Double.self, forKey: .`remainingPercent`)
        self.`resetsAt` = try? c.decodeIfPresent(WireTimestamp.self, forKey: .`resetsAt`)
        self.`observedAt` = try? c.decodeIfPresent(WireTimestamp.self, forKey: .`observedAt`)
        self.`current` = try c.decode(Bool.self, forKey: .`current`)
        self.`validUntil` = try? c.decodeIfPresent(WireTimestamp.self, forKey: .`validUntil`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`id`, forKey: .`id`)
        try c.encode(`role`, forKey: .`role`)
        try c.encode(`durationSeconds`, forKey: .`durationSeconds`)
        try c.encode(`label`, forKey: .`label`)
        try c.encode(`limitKey`, forKey: .`limitKey`)
        try c.encode(`poolKey`, forKey: .`poolKey`)
        try c.encode(`resetMode`, forKey: .`resetMode`)
        try c.encode(`remainingPercent`, forKey: .`remainingPercent`)
        try c.encode(`resetsAt`, forKey: .`resetsAt`)
        try c.encode(`observedAt`, forKey: .`observedAt`)
        try c.encode(`current`, forKey: .`current`)
        try c.encode(`validUntil`, forKey: .`validUntil`)
    }
    private func validate() throws {
        try WireValidation.identity(`id`)
    }
}

public struct WireCancelParams: Codable, Sendable {
    public let `id`: WireRequestID
    private enum CodingKeys: String, CodingKey {
        case `id`
    }
    public init(`id`: WireRequestID) throws {
        self.`id` = `id`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`id` = try c.decode(WireRequestID.self, forKey: .`id`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`id`, forKey: .`id`)
    }
    private func validate() throws {
    }
}

public struct WireConsentFacts: Codable, Sendable {
    public let `scopes`: [WireConsentScope]
    private enum CodingKeys: String, CodingKey {
        case `scopes`
    }
    public init(`scopes`: [WireConsentScope]) throws {
        self.`scopes` = `scopes`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`scopes` = try c.decode([WireConsentScope].self, forKey: .`scopes`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`scopes`, forKey: .`scopes`)
    }
    private func validate() throws {
    }
}

public struct WireConsentGrantParams: Codable, Sendable {
    public let `requestId`: String
    public let `expectStoreEpoch`: String
    public let `expectGeneration`: UInt64
    public let `consentTextVersion`: Int
    public let `allow`: [String]
    public let `deny`: [String]
    public let `forget`: [String]?
    public let `keychain`: [String: WireKeychainChoice]?
    private enum CodingKeys: String, CodingKey {
        case `requestId`
        case `expectStoreEpoch`
        case `expectGeneration`
        case `consentTextVersion`
        case `allow`
        case `deny`
        case `forget`
        case `keychain`
    }
    public init(`requestId`: String, `expectStoreEpoch`: String, `expectGeneration`: UInt64, `consentTextVersion`: Int, `allow`: [String], `deny`: [String], `forget`: [String]? = nil, `keychain`: [String: WireKeychainChoice]? = nil) throws {
        self.`requestId` = `requestId`
        self.`expectStoreEpoch` = `expectStoreEpoch`
        self.`expectGeneration` = `expectGeneration`
        self.`consentTextVersion` = `consentTextVersion`
        self.`allow` = `allow`
        self.`deny` = `deny`
        self.`forget` = `forget`
        self.`keychain` = `keychain`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`requestId` = try c.decode(String.self, forKey: .`requestId`)
        self.`expectStoreEpoch` = try c.decode(String.self, forKey: .`expectStoreEpoch`)
        self.`expectGeneration` = try c.decode(UInt64.self, forKey: .`expectGeneration`)
        self.`consentTextVersion` = try c.decode(Int.self, forKey: .`consentTextVersion`)
        self.`allow` = try c.decode([String].self, forKey: .`allow`)
        self.`deny` = try c.decode([String].self, forKey: .`deny`)
        self.`forget` = try c.decodeIfPresent([String].self, forKey: .`forget`)
        self.`keychain` = try c.decodeIfPresent([String: WireKeychainChoice].self, forKey: .`keychain`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`requestId`, forKey: .`requestId`)
        try c.encode(`expectStoreEpoch`, forKey: .`expectStoreEpoch`)
        try c.encode(`expectGeneration`, forKey: .`expectGeneration`)
        try c.encode(`consentTextVersion`, forKey: .`consentTextVersion`)
        try c.encode(`allow`, forKey: .`allow`)
        try c.encode(`deny`, forKey: .`deny`)
        try c.encodeIfPresent(`forget`, forKey: .`forget`)
        try c.encodeIfPresent(`keychain`, forKey: .`keychain`)
    }
    private func validate() throws {
        try WireValidation.identity(`requestId`)
        try WireValidation.identity(`expectStoreEpoch`)
        guard `expectGeneration` >= 0 else { throw WireDecodeError.invalidBound }
        for scope in allow + deny + (forget ?? []) { try WireValidation.identity(scope) }
        for (scope, choice) in keychain ?? [:] {
            try WireValidation.identity(scope)
            guard ["allow", "deny"].contains(choice.rawValue) else { throw WireDecodeError.invalidAuthorization }
        }
    }
}

public struct WireConsentReceipt: Codable, Sendable {
    public let `requestId`: String
    public let `committed`: Bool
    public let `committedGeneration`: UInt64?
    public let `cleanupPending`: [String]?
    public let `code`: WireReceiptCode
    private enum CodingKeys: String, CodingKey {
        case `requestId`
        case `committed`
        case `committedGeneration`
        case `cleanupPending`
        case `code`
    }
    public init(`requestId`: String, `committed`: Bool, `committedGeneration`: UInt64? = nil, `cleanupPending`: [String]? = nil, `code`: WireReceiptCode) throws {
        self.`requestId` = `requestId`
        self.`committed` = `committed`
        self.`committedGeneration` = `committedGeneration`
        self.`cleanupPending` = `cleanupPending`
        self.`code` = `code`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`requestId` = try c.decode(String.self, forKey: .`requestId`)
        self.`committed` = try c.decode(Bool.self, forKey: .`committed`)
        self.`committedGeneration` = try c.decodeIfPresent(UInt64.self, forKey: .`committedGeneration`)
        self.`cleanupPending` = try c.decodeIfPresent([String].self, forKey: .`cleanupPending`)
        self.`code` = try c.decode(WireReceiptCode.self, forKey: .`code`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`requestId`, forKey: .`requestId`)
        try c.encode(`committed`, forKey: .`committed`)
        try c.encode(`committedGeneration`, forKey: .`committedGeneration`)
        try c.encodeIfPresent(`cleanupPending`, forKey: .`cleanupPending`)
        try c.encode(`code`, forKey: .`code`)
    }
    private func validate() throws {
        try WireValidation.identity(`requestId`)
        if committed && committedGeneration == nil { throw WireDecodeError.invalidAuthorization }
        guard code.isKnown else { throw WireDecodeError.invalidAuthorization }
    }
}

public struct WireConsentScope: Codable, Sendable {
    public let `scope`: String
    public let `tool`: String
    public let `route`: RowsRoute
    public let `detected`: Bool
    public let `retired`: Bool
    public let `state`: WireConsentState
    public let `defaultCheck`: Bool
    public let `keychain`: WireKeychainChoice?
    public let `cleanupPending`: Bool
    public let `disabledReason`: String?
    private enum CodingKeys: String, CodingKey {
        case `scope`
        case `tool`
        case `route`
        case `detected`
        case `retired`
        case `state`
        case `defaultCheck`
        case `keychain`
        case `cleanupPending`
        case `disabledReason`
    }
    public init(`scope`: String, `tool`: String, `route`: RowsRoute, `detected`: Bool, `retired`: Bool, `state`: WireConsentState, `defaultCheck`: Bool, `keychain`: WireKeychainChoice? = nil, `cleanupPending`: Bool, `disabledReason`: String? = nil) throws {
        self.`scope` = `scope`
        self.`tool` = `tool`
        self.`route` = `route`
        self.`detected` = `detected`
        self.`retired` = `retired`
        self.`state` = `state`
        self.`defaultCheck` = `defaultCheck`
        self.`keychain` = `keychain`
        self.`cleanupPending` = `cleanupPending`
        self.`disabledReason` = `disabledReason`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`scope` = try c.decode(String.self, forKey: .`scope`)
        self.`tool` = try c.decode(String.self, forKey: .`tool`)
        self.`route` = try c.decode(RowsRoute.self, forKey: .`route`)
        self.`detected` = try c.decode(Bool.self, forKey: .`detected`)
        self.`retired` = try c.decode(Bool.self, forKey: .`retired`)
        self.`state` = try c.decode(WireConsentState.self, forKey: .`state`)
        self.`defaultCheck` = try c.decode(Bool.self, forKey: .`defaultCheck`)
        self.`keychain` = try c.decodeIfPresent(WireKeychainChoice.self, forKey: .`keychain`)
        self.`cleanupPending` = try c.decode(Bool.self, forKey: .`cleanupPending`)
        self.`disabledReason` = try? c.decodeIfPresent(String.self, forKey: .`disabledReason`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`scope`, forKey: .`scope`)
        try c.encode(`tool`, forKey: .`tool`)
        try c.encode(`route`, forKey: .`route`)
        try c.encode(`detected`, forKey: .`detected`)
        try c.encode(`retired`, forKey: .`retired`)
        try c.encode(`state`, forKey: .`state`)
        try c.encode(`defaultCheck`, forKey: .`defaultCheck`)
        try c.encode(`keychain`, forKey: .`keychain`)
        try c.encode(`cleanupPending`, forKey: .`cleanupPending`)
        try c.encodeIfPresent(`disabledReason`, forKey: .`disabledReason`)
    }
    private func validate() throws {
        try WireValidation.identity(`scope`)
        try WireValidation.identity(`tool`)
        guard `state`.isKnown else { throw WireDecodeError.invalidAuthorization }
        if let value = `keychain`, !value.isKnown { throw WireDecodeError.invalidAuthorization }
    }
}

public enum WireConsentState: Codable, Sendable, Equatable {
    case `allowed`
    case `denied`
    case `unset`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "allowed": self = .`allowed`
        case "denied": self = .`denied`
        case "unset": self = .`unset`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`allowed`: return "allowed"
        case .`denied`: return "denied"
        case .`unset`: return "unset"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public enum WireCredentialOutcome: Codable, Sendable, Equatable {
    case `ok`
    case `canceled`
    case `denied`
    case `notFound`
    case `interactionRequired`
    case `timeout`
    case `error`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "ok": self = .`ok`
        case "canceled": self = .`canceled`
        case "denied": self = .`denied`
        case "not_found": self = .`notFound`
        case "interaction_required": self = .`interactionRequired`
        case "timeout": self = .`timeout`
        case "error": self = .`error`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`ok`: return "ok"
        case .`canceled`: return "canceled"
        case .`denied`: return "denied"
        case .`notFound`: return "not_found"
        case .`interactionRequired`: return "interaction_required"
        case .`timeout`: return "timeout"
        case .`error`: return "error"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public struct WireCredentialRequest: Codable, Sendable {
    public let `operationId`: String
    public let `provider`: String
    public let `scope`: String
    public let `interactive`: Bool
    private enum CodingKeys: String, CodingKey {
        case `operationId`
        case `provider`
        case `scope`
        case `interactive`
    }
    public init(`operationId`: String, `provider`: String, `scope`: String, `interactive`: Bool) throws {
        self.`operationId` = `operationId`
        self.`provider` = `provider`
        self.`scope` = `scope`
        self.`interactive` = `interactive`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`operationId` = try c.decode(String.self, forKey: .`operationId`)
        self.`provider` = try c.decode(String.self, forKey: .`provider`)
        self.`scope` = try c.decode(String.self, forKey: .`scope`)
        self.`interactive` = try c.decode(Bool.self, forKey: .`interactive`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`operationId`, forKey: .`operationId`)
        try c.encode(`provider`, forKey: .`provider`)
        try c.encode(`scope`, forKey: .`scope`)
        try c.encode(`interactive`, forKey: .`interactive`)
    }
    private func validate() throws {
        try WireValidation.identity(`operationId`)
        try WireValidation.identity(`provider`)
        try WireValidation.identity(`scope`)
    }
}

public struct WireCredentialResult: Codable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let `operationId`: String
    public let `outcome`: WireCredentialOutcome
    public let `accessToken`: String?
    public let `expiresAt`: WireTimestamp?
    private enum CodingKeys: String, CodingKey {
        case `operationId`
        case `outcome`
        case `accessToken`
        case `expiresAt`
    }
    public init(`operationId`: String, `outcome`: WireCredentialOutcome, `accessToken`: String? = nil, `expiresAt`: WireTimestamp? = nil) throws {
        self.`operationId` = `operationId`
        self.`outcome` = `outcome`
        self.`accessToken` = `accessToken`
        self.`expiresAt` = `expiresAt`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Non-success credentials may not carry a token or expiry, even explicit null.
        let outcome = try c.decode(WireCredentialOutcome.self, forKey: .outcome)
        if outcome.rawValue != "ok" && (c.contains(.accessToken) || c.contains(.expiresAt)) { throw WireDecodeError.invalidAuthorization }
        self.`operationId` = try c.decode(String.self, forKey: .`operationId`)
        self.`outcome` = try c.decode(WireCredentialOutcome.self, forKey: .`outcome`)
        self.`accessToken` = try c.decodeIfPresent(String.self, forKey: .`accessToken`)
        self.`expiresAt` = try c.decodeIfPresent(WireTimestamp.self, forKey: .`expiresAt`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`operationId`, forKey: .`operationId`)
        try c.encode(`outcome`, forKey: .`outcome`)
        try c.encodeIfPresent(`accessToken`, forKey: .`accessToken`)
        try c.encodeIfPresent(`expiresAt`, forKey: .`expiresAt`)
    }
    private func validate() throws {
        try WireValidation.identity(`operationId`)
        guard `outcome`.isKnown else { throw WireDecodeError.invalidAuthorization }
        if outcome.rawValue == "ok" {
            guard let token = accessToken, !token.isEmpty else { throw WireDecodeError.invalidAuthorization }
        } else if accessToken != nil || expiresAt != nil { throw WireDecodeError.invalidAuthorization }
    }
    public var description: String { "WireCredentialResult([redacted])" }
    public var debugDescription: String { description }
}

public struct WireDiagnostics: Codable, Sendable {
    public let `protocolVersion`: String
    public let `serverVersion`: String
    public let `uptimeSeconds`: Int64
    public let `scopes`: [WireScopeDiag]
    public let `lastErrorClass`: String?
    private enum CodingKeys: String, CodingKey {
        case `protocolVersion`
        case `serverVersion`
        case `uptimeSeconds`
        case `scopes`
        case `lastErrorClass`
    }
    public init(`protocolVersion`: String, `serverVersion`: String, `uptimeSeconds`: Int64, `scopes`: [WireScopeDiag], `lastErrorClass`: String? = nil) throws {
        self.`protocolVersion` = `protocolVersion`
        self.`serverVersion` = `serverVersion`
        self.`uptimeSeconds` = `uptimeSeconds`
        self.`scopes` = `scopes`
        self.`lastErrorClass` = `lastErrorClass`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`protocolVersion` = try c.decode(String.self, forKey: .`protocolVersion`)
        self.`serverVersion` = try c.decode(String.self, forKey: .`serverVersion`)
        self.`uptimeSeconds` = try c.decode(Int64.self, forKey: .`uptimeSeconds`)
        self.`scopes` = try c.decode([WireScopeDiag].self, forKey: .`scopes`)
        self.`lastErrorClass` = try? c.decodeIfPresent(String.self, forKey: .`lastErrorClass`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`protocolVersion`, forKey: .`protocolVersion`)
        try c.encode(`serverVersion`, forKey: .`serverVersion`)
        try c.encode(`uptimeSeconds`, forKey: .`uptimeSeconds`)
        try c.encode(`scopes`, forKey: .`scopes`)
        try c.encodeIfPresent(`lastErrorClass`, forKey: .`lastErrorClass`)
    }
    private func validate() throws {
    }
}

public struct WireEmpty: Codable, Sendable {
    public init() throws {
        try validate()
    }
    public init(from decoder: Decoder) throws {
        _ = try decoder.container(keyedBy: WireCodingKey.self)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        _ = encoder.container(keyedBy: WireCodingKey.self)
    }
    private func validate() throws {
    }
}

public struct WireEnvelope<T: Codable & Sendable>: Codable, Sendable {
    public let `sessionId`: String
    public let `storeEpoch`: String
    public let `consentGeneration`: UInt64
    public let `scopes`: [String]?
    public let `data`: T
    private enum CodingKeys: String, CodingKey {
        case `sessionId`
        case `storeEpoch`
        case `consentGeneration`
        case `scopes`
        case `data`
    }
    public init(`sessionId`: String, `storeEpoch`: String, `consentGeneration`: UInt64, `scopes`: [String]? = nil, `data`: T) throws {
        self.`sessionId` = `sessionId`
        self.`storeEpoch` = `storeEpoch`
        self.`consentGeneration` = `consentGeneration`
        self.`scopes` = `scopes`
        self.`data` = `data`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`sessionId` = try c.decode(String.self, forKey: .`sessionId`)
        self.`storeEpoch` = try c.decode(String.self, forKey: .`storeEpoch`)
        self.`consentGeneration` = try c.decode(UInt64.self, forKey: .`consentGeneration`)
        self.`scopes` = try c.decodeIfPresent([String].self, forKey: .`scopes`)
        self.`data` = try c.decode(T.self, forKey: .`data`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`sessionId`, forKey: .`sessionId`)
        try c.encode(`storeEpoch`, forKey: .`storeEpoch`)
        try c.encode(`consentGeneration`, forKey: .`consentGeneration`)
        try c.encodeIfPresent(`scopes`, forKey: .`scopes`)
        try c.encode(`data`, forKey: .`data`)
    }
    private func validate() throws {
        try WireValidation.identity(`sessionId`)
        try WireValidation.identity(`storeEpoch`)
        if let snapshot = data as? WireRowsSnapshot, snapshot.projection.consentGeneration != consentGeneration { throw WireDecodeError.invalidAuthorization }
    }
}

public struct WireErrorContext: Codable, Sendable {
    public let `sessionId`: String
    public let `storeEpoch`: String?
    public let `consentGeneration`: UInt64?
    private enum CodingKeys: String, CodingKey {
        case `sessionId`
        case `storeEpoch`
        case `consentGeneration`
    }
    public init(`sessionId`: String, `storeEpoch`: String? = nil, `consentGeneration`: UInt64? = nil) throws {
        self.`sessionId` = `sessionId`
        self.`storeEpoch` = `storeEpoch`
        self.`consentGeneration` = `consentGeneration`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`sessionId` = try c.decode(String.self, forKey: .`sessionId`)
        self.`storeEpoch` = try c.decodeIfPresent(String.self, forKey: .`storeEpoch`)
        self.`consentGeneration` = try c.decodeIfPresent(UInt64.self, forKey: .`consentGeneration`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`sessionId`, forKey: .`sessionId`)
        try c.encodeIfPresent(`storeEpoch`, forKey: .`storeEpoch`)
        try c.encodeIfPresent(`consentGeneration`, forKey: .`consentGeneration`)
    }
    private func validate() throws {
        try WireValidation.identity(`sessionId`)
        if let value = `storeEpoch` { try WireValidation.identity(value) }
    }
}

public struct WireFailure: Codable, Sendable {
    public let `jsonrpc`: String
    public let `id`: WireRequestID
    public let `error`: WireRPCError
    private enum CodingKeys: String, CodingKey {
        case `jsonrpc`
        case `id`
        case `error`
    }
    public init(`jsonrpc`: String, `id`: WireRequestID, `error`: WireRPCError) throws {
        self.`jsonrpc` = `jsonrpc`
        self.`id` = `id`
        self.`error` = `error`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`jsonrpc` = try c.decode(String.self, forKey: .`jsonrpc`)
        self.`id` = try c.decode(WireRequestID.self, forKey: .`id`)
        self.`error` = try c.decode(WireRPCError.self, forKey: .`error`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`jsonrpc`, forKey: .`jsonrpc`)
        try c.encode(`id`, forKey: .`id`)
        try c.encode(`error`, forKey: .`error`)
    }
    private func validate() throws {
        guard jsonrpc == WireProtocol.jsonrpc else { throw WireDecodeError.invalidVersion }
    }
}

public struct WireHealth: Codable, Sendable {
    public let `state`: WireHealthState
    public let `code`: String
    private enum CodingKeys: String, CodingKey {
        case `state`
        case `code`
    }
    public init(`state`: WireHealthState, `code`: String) throws {
        self.`state` = `state`
        self.`code` = `code`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`state` = try c.decode(WireHealthState.self, forKey: .`state`)
        self.`code` = try c.decode(String.self, forKey: .`code`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`state`, forKey: .`state`)
        try c.encode(`code`, forKey: .`code`)
    }
    private func validate() throws {
    }
}

public enum WireHealthState: Codable, Sendable, Equatable {
    case `ready`
    case `degraded`
    case `stopping`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "ready": self = .`ready`
        case "degraded": self = .`degraded`
        case "stopping": self = .`stopping`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`ready`: return "ready"
        case .`degraded`: return "degraded"
        case .`stopping`: return "stopping"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public struct WireHistoryItem: Codable, Sendable {
    public let `at`: WireTimestamp
    public let `model`: String?
    public let `tokens`: Int64?
    public let `window`: String?
    public let `value`: Double?
    private enum CodingKeys: String, CodingKey {
        case `at`
        case `model`
        case `tokens`
        case `window`
        case `value`
    }
    public init(`at`: WireTimestamp, `model`: String? = nil, `tokens`: Int64? = nil, `window`: String? = nil, `value`: Double? = nil) throws {
        self.`at` = `at`
        self.`model` = `model`
        self.`tokens` = `tokens`
        self.`window` = `window`
        self.`value` = `value`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`at` = try c.decode(WireTimestamp.self, forKey: .`at`)
        self.`model` = try? c.decodeIfPresent(String.self, forKey: .`model`)
        self.`tokens` = try? c.decodeIfPresent(Int64.self, forKey: .`tokens`)
        self.`window` = try? c.decodeIfPresent(String.self, forKey: .`window`)
        self.`value` = try? c.decodeIfPresent(Double.self, forKey: .`value`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`at`, forKey: .`at`)
        try c.encode(`model`, forKey: .`model`)
        try c.encode(`tokens`, forKey: .`tokens`)
        try c.encode(`window`, forKey: .`window`)
        try c.encode(`value`, forKey: .`value`)
    }
    private func validate() throws {
    }
}

public struct WireHistoryPage: Codable, Sendable {
    public let `items`: [WireHistoryItem]
    public let `nextCursor`: String?
    private enum CodingKeys: String, CodingKey {
        case `items`
        case `nextCursor`
    }
    public init(`items`: [WireHistoryItem], `nextCursor`: String? = nil) throws {
        self.`items` = `items`
        self.`nextCursor` = `nextCursor`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`items` = try c.decode([WireHistoryItem].self, forKey: .`items`)
        self.`nextCursor` = try? c.decodeIfPresent(String.self, forKey: .`nextCursor`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`items`, forKey: .`items`)
        try c.encodeIfPresent(`nextCursor`, forKey: .`nextCursor`)
    }
    private func validate() throws {
    }
}

public struct WireHistoryQueryParams: Codable, Sendable {
    public let `kind`: WireHistoryQueryParamsKind
    public let `tool`: String
    public let `ref`: String?
    public let `cursor`: String?
    public let `limit`: Int
    private enum CodingKeys: String, CodingKey {
        case `kind`
        case `tool`
        case `ref`
        case `cursor`
        case `limit`
    }
    public init(`kind`: WireHistoryQueryParamsKind, `tool`: String, `ref`: String? = nil, `cursor`: String? = nil, `limit`: Int) throws {
        self.`kind` = `kind`
        self.`tool` = `tool`
        self.`ref` = `ref`
        self.`cursor` = `cursor`
        self.`limit` = `limit`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`kind` = try c.decode(WireHistoryQueryParamsKind.self, forKey: .`kind`)
        self.`tool` = try c.decode(String.self, forKey: .`tool`)
        self.`ref` = try? c.decodeIfPresent(String.self, forKey: .`ref`)
        self.`cursor` = try? c.decodeIfPresent(String.self, forKey: .`cursor`)
        self.`limit` = try c.decode(Int.self, forKey: .`limit`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`kind`, forKey: .`kind`)
        try c.encode(`tool`, forKey: .`tool`)
        try c.encodeIfPresent(`ref`, forKey: .`ref`)
        try c.encodeIfPresent(`cursor`, forKey: .`cursor`)
        try c.encode(`limit`, forKey: .`limit`)
    }
    private func validate() throws {
        try WireValidation.identity(`tool`)
        guard `limit` >= 1 else { throw WireDecodeError.invalidBound }
        guard `limit` <= 500 else { throw WireDecodeError.invalidBound }
    }
}

public enum WireHistoryQueryParamsKind: Codable, Sendable, Equatable {
    case `tokens`
    case `quotaCycles`
    case `sessions`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "tokens": self = .`tokens`
        case "quota_cycles": self = .`quotaCycles`
        case "sessions": self = .`sessions`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`tokens`: return "tokens"
        case .`quotaCycles`: return "quota_cycles"
        case .`sessions`: return "sessions"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public struct WireInitializeParams: Codable, Sendable {
    public let `sessionId`: String
    public let `protocolVersion`: String
    public let `appVersion`: String
    public let `capabilities`: [String]
    private enum CodingKeys: String, CodingKey {
        case `sessionId`
        case `protocolVersion`
        case `appVersion`
        case `capabilities`
    }
    public init(`sessionId`: String, `protocolVersion`: String, `appVersion`: String, `capabilities`: [String]) throws {
        self.`sessionId` = `sessionId`
        self.`protocolVersion` = `protocolVersion`
        self.`appVersion` = `appVersion`
        self.`capabilities` = `capabilities`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`sessionId` = try c.decode(String.self, forKey: .`sessionId`)
        self.`protocolVersion` = try c.decode(String.self, forKey: .`protocolVersion`)
        self.`appVersion` = try c.decode(String.self, forKey: .`appVersion`)
        self.`capabilities` = try c.decode([String].self, forKey: .`capabilities`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`sessionId`, forKey: .`sessionId`)
        try c.encode(`protocolVersion`, forKey: .`protocolVersion`)
        try c.encode(`appVersion`, forKey: .`appVersion`)
        try c.encode(`capabilities`, forKey: .`capabilities`)
    }
    private func validate() throws {
        try WireValidation.identity(`sessionId`)
        try WireValidation.protocolVersion(protocolVersion)
    }
}

public struct WireInitializeResult: Codable, Sendable {
    public let `protocolVersion`: String
    public let `serverVersion`: String
    public let `capabilities`: [String]
    private enum CodingKeys: String, CodingKey {
        case `protocolVersion`
        case `serverVersion`
        case `capabilities`
    }
    public init(`protocolVersion`: String, `serverVersion`: String, `capabilities`: [String]) throws {
        self.`protocolVersion` = `protocolVersion`
        self.`serverVersion` = `serverVersion`
        self.`capabilities` = `capabilities`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`protocolVersion` = try c.decode(String.self, forKey: .`protocolVersion`)
        self.`serverVersion` = try c.decode(String.self, forKey: .`serverVersion`)
        self.`capabilities` = try c.decode([String].self, forKey: .`capabilities`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`protocolVersion`, forKey: .`protocolVersion`)
        try c.encode(`serverVersion`, forKey: .`serverVersion`)
        try c.encode(`capabilities`, forKey: .`capabilities`)
    }
    private func validate() throws {
        try WireValidation.protocolVersion(protocolVersion)
    }
}

public enum WireKeychainChoice: Codable, Sendable, Equatable {
    case `allow`
    case `deny`
    case `unset`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "allow": self = .`allow`
        case "deny": self = .`deny`
        case "unset": self = .`unset`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`allow`: return "allow"
        case .`deny`: return "deny"
        case .`unset`: return "unset"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public struct WireNotification<T: Codable & Sendable>: Codable, Sendable {
    public let `jsonrpc`: String
    public let `method`: String
    public let `params`: WireEnvelope<T>
    private enum CodingKeys: String, CodingKey {
        case `jsonrpc`
        case `method`
        case `params`
    }
    public init(`jsonrpc`: String, `method`: String, `params`: WireEnvelope<T>) throws {
        self.`jsonrpc` = `jsonrpc`
        self.`method` = `method`
        self.`params` = `params`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`jsonrpc` = try c.decode(String.self, forKey: .`jsonrpc`)
        self.`method` = try c.decode(String.self, forKey: .`method`)
        self.`params` = try c.decode(WireEnvelope<T>.self, forKey: .`params`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`jsonrpc`, forKey: .`jsonrpc`)
        try c.encode(`method`, forKey: .`method`)
        try c.encode(`params`, forKey: .`params`)
    }
    private func validate() throws {
        guard jsonrpc == WireProtocol.jsonrpc else { throw WireDecodeError.invalidVersion }
    }
}

public struct WireRPCError: Codable, Sendable {
    public let `code`: Int
    public let `message`: String
    public let `data`: WireErrorContext
    private enum CodingKeys: String, CodingKey {
        case `code`
        case `message`
        case `data`
    }
    public init(`code`: Int, `message`: String, `data`: WireErrorContext) throws {
        self.`code` = `code`
        self.`message` = `message`
        self.`data` = `data`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`code` = try c.decode(Int.self, forKey: .`code`)
        self.`message` = try c.decode(String.self, forKey: .`message`)
        self.`data` = try c.decode(WireErrorContext.self, forKey: .`data`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`code`, forKey: .`code`)
        try c.encode(`message`, forKey: .`message`)
        try c.encode(`data`, forKey: .`data`)
    }
    private func validate() throws {
    }
}

public enum WireReceiptCode: Codable, Sendable, Equatable {
    case `ok`
    case `cleanupPending`
    case `staleGeneration`
    case `staleConsentText`
    case `rejected`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "ok": self = .`ok`
        case "cleanup_pending": self = .`cleanupPending`
        case "stale_generation": self = .`staleGeneration`
        case "stale_consent_text": self = .`staleConsentText`
        case "rejected": self = .`rejected`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`ok`: return "ok"
        case .`cleanupPending`: return "cleanup_pending"
        case .`staleGeneration`: return "stale_generation"
        case .`staleConsentText`: return "stale_consent_text"
        case .`rejected`: return "rejected"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public struct WireRefreshRequestParams: Codable, Sendable {
    public let `scopes`: [String]?
    private enum CodingKeys: String, CodingKey {
        case `scopes`
    }
    public init(`scopes`: [String]? = nil) throws {
        self.`scopes` = `scopes`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`scopes` = try c.decodeIfPresent([String].self, forKey: .`scopes`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(`scopes`, forKey: .`scopes`)
    }
    private func validate() throws {
    }
}

public struct WireRefreshScheduled: Codable, Sendable {
    public let `scope`: String
    public let `at`: WireTimestamp
    public let `disabledReason`: String?
    private enum CodingKeys: String, CodingKey {
        case `scope`
        case `at`
        case `disabledReason`
    }
    public init(`scope`: String, `at`: WireTimestamp, `disabledReason`: String? = nil) throws {
        self.`scope` = `scope`
        self.`at` = `at`
        self.`disabledReason` = `disabledReason`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`scope` = try c.decode(String.self, forKey: .`scope`)
        self.`at` = try c.decode(WireTimestamp.self, forKey: .`at`)
        self.`disabledReason` = try? c.decodeIfPresent(String.self, forKey: .`disabledReason`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`scope`, forKey: .`scope`)
        try c.encode(`at`, forKey: .`at`)
        try c.encodeIfPresent(`disabledReason`, forKey: .`disabledReason`)
    }
    private func validate() throws {
        try WireValidation.identity(`scope`)
    }
}

public struct WireRequest: Codable, Sendable {
    public let `jsonrpc`: String
    public let `id`: WireRequestID?
    public let `method`: String
    public let `params`: WireJSONValue?
    private enum CodingKeys: String, CodingKey {
        case `jsonrpc`
        case `id`
        case `method`
        case `params`
    }
    public init(`jsonrpc`: String, `id`: WireRequestID? = nil, `method`: String, `params`: WireJSONValue? = nil) throws {
        self.`jsonrpc` = `jsonrpc`
        self.`id` = `id`
        self.`method` = `method`
        self.`params` = `params`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`jsonrpc` = try c.decode(String.self, forKey: .`jsonrpc`)
        self.`id` = try c.decodeIfPresent(WireRequestID.self, forKey: .`id`)
        self.`method` = try c.decode(String.self, forKey: .`method`)
        self.`params` = try? c.decodeIfPresent(WireJSONValue.self, forKey: .`params`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`jsonrpc`, forKey: .`jsonrpc`)
        try c.encodeIfPresent(`id`, forKey: .`id`)
        try c.encode(`method`, forKey: .`method`)
        try c.encodeIfPresent(`params`, forKey: .`params`)
    }
    private func validate() throws {
        guard jsonrpc == WireProtocol.jsonrpc else { throw WireDecodeError.invalidVersion }
    }
}

public struct WireRowsSnapshot: Codable, Sendable {
    public let `sequence`: UInt64
    public let `projection`: RowsProjection
    private enum CodingKeys: String, CodingKey {
        case `sequence`
        case `projection`
    }
    public init(`sequence`: UInt64, `projection`: RowsProjection) throws {
        self.`sequence` = `sequence`
        self.`projection` = `projection`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`sequence` = try c.decode(UInt64.self, forKey: .`sequence`)
        self.`projection` = try c.decode(RowsProjection.self, forKey: .`projection`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`sequence`, forKey: .`sequence`)
        try c.encode(`projection`, forKey: .`projection`)
    }
    private func validate() throws {
        guard `sequence` >= 0 else { throw WireDecodeError.invalidBound }
    }
}

public struct WireScopeDiag: Codable, Sendable {
    public let `scope`: String
    public let `state`: RowsState
    public let `code`: RowsCode
    public let `lastRead`: WireTimestamp?
    public let `nextDueAt`: WireTimestamp?
    private enum CodingKeys: String, CodingKey {
        case `scope`
        case `state`
        case `code`
        case `lastRead`
        case `nextDueAt`
    }
    public init(`scope`: String, `state`: RowsState, `code`: RowsCode, `lastRead`: WireTimestamp? = nil, `nextDueAt`: WireTimestamp? = nil) throws {
        self.`scope` = `scope`
        self.`state` = `state`
        self.`code` = `code`
        self.`lastRead` = `lastRead`
        self.`nextDueAt` = `nextDueAt`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`scope` = try c.decode(String.self, forKey: .`scope`)
        self.`state` = try c.decode(RowsState.self, forKey: .`state`)
        self.`code` = try c.decode(RowsCode.self, forKey: .`code`)
        self.`lastRead` = try? c.decodeIfPresent(WireTimestamp.self, forKey: .`lastRead`)
        self.`nextDueAt` = try? c.decodeIfPresent(WireTimestamp.self, forKey: .`nextDueAt`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`scope`, forKey: .`scope`)
        try c.encode(`state`, forKey: .`state`)
        try c.encode(`code`, forKey: .`code`)
        try c.encode(`lastRead`, forKey: .`lastRead`)
        try c.encode(`nextDueAt`, forKey: .`nextDueAt`)
    }
    private func validate() throws {
        try WireValidation.identity(`scope`)
    }
}

public struct WireSuccess<T: Codable & Sendable>: Codable, Sendable {
    public let `jsonrpc`: String
    public let `id`: WireRequestID
    public let `result`: WireEnvelope<T>
    private enum CodingKeys: String, CodingKey {
        case `jsonrpc`
        case `id`
        case `result`
    }
    public init(`jsonrpc`: String, `id`: WireRequestID, `result`: WireEnvelope<T>) throws {
        self.`jsonrpc` = `jsonrpc`
        self.`id` = `id`
        self.`result` = `result`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`jsonrpc` = try c.decode(String.self, forKey: .`jsonrpc`)
        self.`id` = try c.decode(WireRequestID.self, forKey: .`id`)
        self.`result` = try c.decode(WireEnvelope<T>.self, forKey: .`result`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`jsonrpc`, forKey: .`jsonrpc`)
        try c.encode(`id`, forKey: .`id`)
        try c.encode(`result`, forKey: .`result`)
    }
    private func validate() throws {
        guard jsonrpc == WireProtocol.jsonrpc else { throw WireDecodeError.invalidVersion }
    }
}

