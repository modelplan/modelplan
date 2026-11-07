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

// Named JSON-RPC error codes used by the Swift client.
public enum WireErrorCode {
    public static let protocolMismatch: Int = -32010
    public static let busy: Int = -32013
}

// Generated from Go supervision; key names only, never environment values.
public enum WireChildEnvironment {
    public static let allowedKeys: Set<String> = ["HOME", "KIMI_CODE_API_KEY", "LANG", "LC_ALL", "LC_CTYPE", "MINIMAX_CODING_API_KEY", "MODELPLAN_CODEX_ACCOUNT", "MODELPLAN_READERS", "MODELPLAN_VERIFY_READERS", "OPENCODE_API_KEY", "PATH", "TMPDIR", "Z_AI_API_KEY"]
}

// This support code is emitted with the DTOs; it never stores engine state.
public enum WireDecodeError: Error, Sendable {
    case invalidIdentity, invalidAuthorization, invalidVersion, invalidBound, invalidFrame, tokenPlacement, invalidRowEncoding
}

private struct WireCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil
    init?(stringValue: String) { self.stringValue = stringValue }
    init(_ value: String) { self.stringValue = value }
    init?(intValue: Int) { return nil }
}

private enum WireValidation {
    static func identity(_ value: String) throws {
        guard !value.isEmpty,
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

public struct WireDecoded<Value> {
    public let value: Value
    public let invalidRowCount: Int
}
extension WireDecoded: Sendable where Value: Sendable {}

private final class WireDecodeCounter {
    var invalidRows = 0
}
private let wireDecodeCounterKey = CodingUserInfoKey(rawValue: "modelplan.invalidRows")!

private enum WireRowDecoding {
    static func decode(from decoder: Decoder) throws -> RowsRow {
        do { return try RowsRow(from: decoder) }
        catch let error as WireDecodeError {
            // Only semantic row validation is isolated. An undecodable identity
            // binding or structurally malformed payload is still a malformed frame.
            switch error {
            case .invalidIdentity, .invalidAuthorization, .invalidVersion, .invalidBound:
                let fields = try decoder.container(keyedBy: WireCodingKey.self)
                let id = try fields.decode(String.self, forKey: WireCodingKey("id"))
                guard !id.isEmpty else { throw WireDecodeError.invalidFrame }
                let order = try fields.decode(Int.self, forKey: WireCodingKey("order"))
                let surfaces = try fields.decode([RowsSurface].self, forKey: WireCodingKey("surfaces"))
                let placeholder = try RowsRow(invalidID: id, invalidOrder: order, invalidSurfaces: surfaces)
                (decoder.userInfo[wireDecodeCounterKey] as? WireDecodeCounter)?.invalidRows += 1
                return placeholder
            default: throw error
            }
        }
    }
}

public enum WireDecoder {
    // M0 owns feature isolation and the state/floor; this function never updates a store.
    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decodeWithDiagnostics(type, from: data).value
    }
    public static func decodeWithDiagnostics<T: Decodable>(_ type: T.Type, from data: Data) throws -> WireDecoded<T> {
        // Older Foundation dictionary fast paths can trap on malformed keys.
        // Validate syntax first; discard this tree and decode the original bytes
        // below so identifiers never pass through NSNumber/Double conversion.
        guard data.count <= WireProtocol.maxFrameBytes,
              String(data: data, encoding: .utf8) != nil else { throw WireDecodeError.invalidFrame }
        do { _ = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) }
        catch { throw WireDecodeError.invalidFrame }
        let tree = try JSONDecoder().decode(WireJSONValue.self, from: data)
        let credential = type == WireCredentialResult.self
        let credentialRequest: Bool
        if type == WireRequest.self, case .object(let fields) = tree,
           fields["method"] == .string("credentials/result") { credentialRequest = true }
        else { credentialRequest = false }
        try checkTokens(tree, path: [], directCredential: credential, credentialRequest: credentialRequest)
        let counter = WireDecodeCounter()
        let decoder = JSONDecoder()
        decoder.userInfo[wireDecodeCounterKey] = counter
        let value = try decoder.decode(type, from: data)
        return WireDecoded(value: value, invalidRowCount: counter.invalidRows)
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
    public let `today`: RowsAccountToday?
    public let `resetCards`: RowsResetCards?
    public let `refreshNotBefore`: WireTimestamp?
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
        case `today`
        case `resetCards`
        case `refreshNotBefore`
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
    public init(`today`: RowsAccountToday? = nil, `resetCards`: RowsResetCards? = nil, `refreshNotBefore`: WireTimestamp? = nil, `route`: RowsRoute, `subscriptionRef`: String? = nil, `accountLocator`: String? = nil, `plan`: RowsPlan, `beta`: Bool, `credits`: RowsCredits? = nil, `valueState`: RowsValueState, `observedAt`: WireTimestamp? = nil, `freshUntil`: WireTimestamp? = nil, `lastFailure`: RowsFailure? = nil, `windows`: [RowsWindow]) throws {
        self.`today` = `today`
        self.`resetCards` = `resetCards`
        self.`refreshNotBefore` = `refreshNotBefore`
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
        if c.contains(.`today`), try c.decodeNil(forKey: .`today`) { throw WireDecodeError.invalidIdentity }
        self.`today` = try c.decodeIfPresent(RowsAccountToday.self, forKey: .`today`)
        if c.contains(.`resetCards`), try c.decodeNil(forKey: .`resetCards`) { throw WireDecodeError.invalidIdentity }
        self.`resetCards` = try c.decodeIfPresent(RowsResetCards.self, forKey: .`resetCards`)
        self.`refreshNotBefore` = try? c.decodeIfPresent(WireTimestamp.self, forKey: .`refreshNotBefore`)
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
        try c.encodeIfPresent(`today`, forKey: .`today`)
        try c.encodeIfPresent(`resetCards`, forKey: .`resetCards`)
        try c.encodeIfPresent(`refreshNotBefore`, forKey: .`refreshNotBefore`)
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

public struct RowsAccountToday: Codable, Sendable {
    public let `observedOutputTokens`: Int64?
    public let `generationTps`: Double?
    public let `runningSessions`: Int?
    public let `bindingBasis`: RowsTodayBindingBasis
    private enum CodingKeys: String, CodingKey {
        case `observedOutputTokens`
        case `generationTps`
        case `runningSessions`
        case `bindingBasis`
    }
    public init(`observedOutputTokens`: Int64? = nil, `generationTps`: Double? = nil, `runningSessions`: Int? = nil, `bindingBasis`: RowsTodayBindingBasis) throws {
        self.`observedOutputTokens` = `observedOutputTokens`
        self.`generationTps` = `generationTps`
        self.`runningSessions` = `runningSessions`
        self.`bindingBasis` = `bindingBasis`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if c.contains(.`observedOutputTokens`), try c.decodeNil(forKey: .`observedOutputTokens`) { throw WireDecodeError.invalidIdentity }
        self.`observedOutputTokens` = try c.decodeIfPresent(Int64.self, forKey: .`observedOutputTokens`)
        if c.contains(.`generationTps`), try c.decodeNil(forKey: .`generationTps`) { throw WireDecodeError.invalidIdentity }
        self.`generationTps` = try c.decodeIfPresent(Double.self, forKey: .`generationTps`)
        if c.contains(.`runningSessions`), try c.decodeNil(forKey: .`runningSessions`) { throw WireDecodeError.invalidIdentity }
        self.`runningSessions` = try c.decodeIfPresent(Int.self, forKey: .`runningSessions`)
        self.`bindingBasis` = try c.decode(RowsTodayBindingBasis.self, forKey: .`bindingBasis`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(`observedOutputTokens`, forKey: .`observedOutputTokens`)
        try c.encodeIfPresent(`generationTps`, forKey: .`generationTps`)
        try c.encodeIfPresent(`runningSessions`, forKey: .`runningSessions`)
        try c.encode(`bindingBasis`, forKey: .`bindingBasis`)
    }
    private func validate() throws {
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
    case `policyPending`
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
        case "policy_pending": self = .`policyPending`
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
        case .`policyPending`: return "policy_pending"
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
public struct RowsModelScope: Codable, Sendable {
    public let `models`: [String]
    private enum CodingKeys: String, CodingKey {
        case `models`
    }
    public init(`models`: [String]) throws {
        self.`models` = `models`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`models` = try c.decode([String].self, forKey: .`models`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`models`, forKey: .`models`)
    }
    private func validate() throws {
    }
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

public struct RowsResetCardItem: Codable, Sendable {
    public let `id`: String
    public let `expiresAt`: WireTimestamp?
    private enum CodingKeys: String, CodingKey {
        case `id`
        case `expiresAt`
    }
    public init(`id`: String, `expiresAt`: WireTimestamp?) throws {
        self.`id` = `id`
        self.`expiresAt` = `expiresAt`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`id` = try c.decode(String.self, forKey: .`id`)
        guard c.contains(.`expiresAt`) else { throw WireDecodeError.invalidIdentity }
        self.`expiresAt` = try c.decodeIfPresent(WireTimestamp.self, forKey: .`expiresAt`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`id`, forKey: .`id`)
        try c.encode(`expiresAt`, forKey: .`expiresAt`)
    }
    private func validate() throws {
        try WireValidation.identity(`id`)
        guard id.utf8.count == 64, id.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else { throw WireDecodeError.invalidIdentity }
    }
}

public struct RowsResetCardSource: Codable, Sendable {
    public let `source`: RowsResetCardSourceKind
    public let `observedAt`: WireTimestamp
    private enum CodingKeys: String, CodingKey {
        case `source`
        case `observedAt`
    }
    public init(`source`: RowsResetCardSourceKind, `observedAt`: WireTimestamp) throws {
        self.`source` = `source`
        self.`observedAt` = `observedAt`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`source` = try c.decode(RowsResetCardSourceKind.self, forKey: .`source`)
        self.`observedAt` = try c.decode(WireTimestamp.self, forKey: .`observedAt`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`source`, forKey: .`source`)
        try c.encode(`observedAt`, forKey: .`observedAt`)
    }
    private func validate() throws {
        guard `source`.isKnown else { throw WireDecodeError.invalidAuthorization }
    }
}

public enum RowsResetCardSourceKind: Codable, Sendable, Equatable {
    case `codexAccount`
    case `codexbar`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "codex-account": self = .`codexAccount`
        case "codexbar": self = .`codexbar`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`codexAccount`: return "codex-account"
        case .`codexbar`: return "codexbar"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public enum RowsResetCardState: Codable, Sendable, Equatable {
    case `knownUnknown`
    case `partial`
    case `complete`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "unknown": self = .`knownUnknown`
        case "partial": self = .`partial`
        case "complete": self = .`complete`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`knownUnknown`: return "unknown"
        case .`partial`: return "partial"
        case .`complete`: return "complete"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public struct RowsResetCards: Codable, Sendable {
    public let `state`: RowsResetCardState
    public let `count`: Int?
    public let `earliestExpiresAt`: WireTimestamp?
    public let `items`: [RowsResetCardItem]?
    public let `truncated`: Bool
    public let `sources`: [RowsResetCardSource]
    private enum CodingKeys: String, CodingKey {
        case `state`
        case `count`
        case `earliestExpiresAt`
        case `items`
        case `truncated`
        case `sources`
    }
    public init(`state`: RowsResetCardState, `count`: Int?, `earliestExpiresAt`: WireTimestamp? = nil, `items`: [RowsResetCardItem]? = nil, `truncated`: Bool, `sources`: [RowsResetCardSource]) throws {
        self.`state` = `state`
        self.`count` = `count`
        self.`earliestExpiresAt` = `earliestExpiresAt`
        self.`items` = `items`
        self.`truncated` = `truncated`
        self.`sources` = `sources`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`state` = try c.decode(RowsResetCardState.self, forKey: .`state`)
        guard c.contains(.`count`) else { throw WireDecodeError.invalidIdentity }
        self.`count` = try c.decodeIfPresent(Int.self, forKey: .`count`)
        if c.contains(.`earliestExpiresAt`), try c.decodeNil(forKey: .`earliestExpiresAt`) { throw WireDecodeError.invalidIdentity }
        self.`earliestExpiresAt` = try c.decodeIfPresent(WireTimestamp.self, forKey: .`earliestExpiresAt`)
        if c.contains(.`items`), try c.decodeNil(forKey: .`items`) { throw WireDecodeError.invalidIdentity }
        self.`items` = try c.decodeIfPresent([RowsResetCardItem].self, forKey: .`items`)
        self.`truncated` = try c.decode(Bool.self, forKey: .`truncated`)
        self.`sources` = try c.decode([RowsResetCardSource].self, forKey: .`sources`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`state`, forKey: .`state`)
        try c.encode(`count`, forKey: .`count`)
        try c.encodeIfPresent(`earliestExpiresAt`, forKey: .`earliestExpiresAt`)
        try c.encodeIfPresent(`items`, forKey: .`items`)
        try c.encode(`truncated`, forKey: .`truncated`)
        try c.encode(`sources`, forKey: .`sources`)
    }
    private func validate() throws {
        guard `state`.isKnown else { throw WireDecodeError.invalidAuthorization }
        guard (items?.count ?? 0) <= 64, sources.count <= 16 else { throw WireDecodeError.invalidBound }
        if let count = count, !(0...10000).contains(count) { throw WireDecodeError.invalidBound }
    }
}

public struct RowsResetEvent: Codable, Sendable {
    public let `version`: Int
    public let `id`: String
    public let `provider`: String
    public let `rowId`: String
    public let `status`: RowsResetEventStatus
    public let `confirms`: String?
    public let `planIds`: [String]?
    public let `publishedAt`: WireTimestamp
    public let `schedule`: RowsResetSchedule?
    public let `expiresAt`: WireTimestamp
    public let `source`: RowsResetSource
    private enum CodingKeys: String, CodingKey {
        case `version`
        case `id`
        case `provider`
        case `rowId`
        case `status`
        case `confirms`
        case `planIds`
        case `publishedAt`
        case `schedule`
        case `expiresAt`
        case `source`
    }
    public init(`version`: Int, `id`: String, `provider`: String, `rowId`: String, `status`: RowsResetEventStatus, `confirms`: String? = nil, `planIds`: [String]? = nil, `publishedAt`: WireTimestamp, `schedule`: RowsResetSchedule? = nil, `expiresAt`: WireTimestamp, `source`: RowsResetSource) throws {
        self.`version` = `version`
        self.`id` = `id`
        self.`provider` = `provider`
        self.`rowId` = `rowId`
        self.`status` = `status`
        self.`confirms` = `confirms`
        self.`planIds` = `planIds`
        self.`publishedAt` = `publishedAt`
        self.`schedule` = `schedule`
        self.`expiresAt` = `expiresAt`
        self.`source` = `source`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`version` = try c.decode(Int.self, forKey: .`version`)
        self.`id` = try c.decode(String.self, forKey: .`id`)
        self.`provider` = try c.decode(String.self, forKey: .`provider`)
        self.`rowId` = try c.decode(String.self, forKey: .`rowId`)
        self.`status` = try c.decode(RowsResetEventStatus.self, forKey: .`status`)
        self.`confirms` = try? c.decodeIfPresent(String.self, forKey: .`confirms`)
        self.`planIds` = try? c.decodeIfPresent([String].self, forKey: .`planIds`)
        self.`publishedAt` = try c.decode(WireTimestamp.self, forKey: .`publishedAt`)
        self.`schedule` = try? c.decodeIfPresent(RowsResetSchedule.self, forKey: .`schedule`)
        self.`expiresAt` = try c.decode(WireTimestamp.self, forKey: .`expiresAt`)
        self.`source` = try c.decode(RowsResetSource.self, forKey: .`source`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`version`, forKey: .`version`)
        try c.encode(`id`, forKey: .`id`)
        try c.encode(`provider`, forKey: .`provider`)
        try c.encode(`rowId`, forKey: .`rowId`)
        try c.encode(`status`, forKey: .`status`)
        try c.encodeIfPresent(`confirms`, forKey: .`confirms`)
        try c.encodeIfPresent(`planIds`, forKey: .`planIds`)
        try c.encode(`publishedAt`, forKey: .`publishedAt`)
        try c.encodeIfPresent(`schedule`, forKey: .`schedule`)
        try c.encode(`expiresAt`, forKey: .`expiresAt`)
        try c.encode(`source`, forKey: .`source`)
    }
    private func validate() throws {
        try WireValidation.identity(`id`)
        try WireValidation.identity(`provider`)
    }
}

public enum RowsResetEventStatus: Codable, Sendable, Equatable {
    case `announced`
    case `confirmed`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "announced": self = .`announced`
        case "confirmed": self = .`confirmed`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`announced`: return "announced"
        case .`confirmed`: return "confirmed"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public struct RowsResetLink: Codable, Sendable {
    public let `type`: String
    public let `url`: String
    private enum CodingKeys: String, CodingKey {
        case `type`
        case `url`
    }
    public init(`type`: String, `url`: String) throws {
        self.`type` = `type`
        self.`url` = `url`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`type` = try c.decode(String.self, forKey: .`type`)
        self.`url` = try c.decode(String.self, forKey: .`url`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`type`, forKey: .`type`)
        try c.encode(`url`, forKey: .`url`)
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
public struct RowsResetSchedule: Codable, Sendable {
    public let `precision`: String
    public let `from`: WireTimestamp
    public let `through`: WireTimestamp
    private enum CodingKeys: String, CodingKey {
        case `precision`
        case `from`
        case `through`
    }
    public init(`precision`: String, `from`: WireTimestamp, `through`: WireTimestamp) throws {
        self.`precision` = `precision`
        self.`from` = `from`
        self.`through` = `through`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`precision` = try c.decode(String.self, forKey: .`precision`)
        self.`from` = try c.decode(WireTimestamp.self, forKey: .`from`)
        self.`through` = try c.decode(WireTimestamp.self, forKey: .`through`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`precision`, forKey: .`precision`)
        try c.encode(`from`, forKey: .`from`)
        try c.encode(`through`, forKey: .`through`)
    }
    private func validate() throws {
    }
}

public struct RowsResetSource: Codable, Sendable {
    public let `kind`: String
    public let `publicationId`: String
    public let `url`: String?
    public let `links`: [RowsResetLink]?
    private enum CodingKeys: String, CodingKey {
        case `kind`
        case `publicationId`
        case `url`
        case `links`
    }
    public init(`kind`: String, `publicationId`: String, `url`: String? = nil, `links`: [RowsResetLink]? = nil) throws {
        self.`kind` = `kind`
        self.`publicationId` = `publicationId`
        self.`url` = `url`
        self.`links` = `links`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`kind` = try c.decode(String.self, forKey: .`kind`)
        self.`publicationId` = try c.decode(String.self, forKey: .`publicationId`)
        self.`url` = try? c.decodeIfPresent(String.self, forKey: .`url`)
        self.`links` = try? c.decodeIfPresent([RowsResetLink].self, forKey: .`links`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`kind`, forKey: .`kind`)
        try c.encode(`publicationId`, forKey: .`publicationId`)
        try c.encodeIfPresent(`url`, forKey: .`url`)
        try c.encodeIfPresent(`links`, forKey: .`links`)
    }
    private func validate() throws {
        try WireValidation.identity(`publicationId`)
    }
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
    public let `refreshNotBefore`: WireTimestamp?
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
    public let invalid: Bool
    private enum CodingKeys: String, CodingKey {
        case `refreshNotBefore`
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
    public init(`refreshNotBefore`: WireTimestamp? = nil, `id`: String, `kind`: RowsKind, `order`: Int, `name`: RowsName, `vendorKey`: String? = nil, `surfaces`: [RowsSurface], `consent`: RowsConsent, `state`: RowsState, `reason`: RowsReason, `nextStep`: RowsNextStep? = nil, `accounts`: [RowsAccount], `expiresAt`: WireTimestamp? = nil, `stateAfterExpiry`: RowsExpiryState? = nil) throws {
        self.`refreshNotBefore` = `refreshNotBefore`
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
        self.invalid = false
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`refreshNotBefore` = try? c.decodeIfPresent(WireTimestamp.self, forKey: .`refreshNotBefore`)
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
        self.invalid = false
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(`refreshNotBefore`, forKey: .`refreshNotBefore`)
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
        guard !invalid else { throw WireDecodeError.invalidRowEncoding }
        try WireValidation.identity(`id`)
        guard `kind`.isKnown else { throw WireDecodeError.invalidAuthorization }
        guard `consent`.isKnown else { throw WireDecodeError.invalidAuthorization }
        try WireValidation.identity(id)
        if kind.rawValue == "tool" { try WireValidation.toolID(id) }
        if kind.rawValue == "declared" && (!id.hasPrefix("declared:") || id.count <= 9) { throw WireDecodeError.invalidIdentity }
        if (["denied", "unset"].contains(consent.rawValue) || reason.code.rawValue == "cleanup_pending") && !accounts.isEmpty { throw WireDecodeError.invalidAuthorization }
    }
    fileprivate init(invalidID: String, invalidOrder: Int, invalidSurfaces: [RowsSurface]) throws {
        self.refreshNotBefore = nil
        self.id = invalidID
        self.kind = .unknown("invalid_row")
        self.order = invalidOrder
        self.name = try RowsName(en: "Unavailable reading", zh: "读数不可用")
        self.vendorKey = nil
        self.surfaces = invalidSurfaces
        self.consent = .unset
        self.state = .failed
        self.reason = try RowsReason(code: .unknown("invalid_row"), text: RowsText(en: "Reading unavailable", zh: "读数不可用"))
        self.nextStep = nil
        self.accounts = []
        self.expiresAt = nil
        self.stateAfterExpiry = nil
        self.invalid = true
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

public enum RowsTodayBindingBasis: Codable, Sendable, Equatable {
    case `sourceWideCurrentBinding`
    case `sessionBinding`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "source-wide-current-binding": self = .`sourceWideCurrentBinding`
        case "session-binding": self = .`sessionBinding`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`sourceWideCurrentBinding`: return "source-wide-current-binding"
        case .`sessionBinding`: return "session-binding"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
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
    public let `source`: RowsWindowSource?
    public let `modelScope`: RowsModelScope?
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
        case `source`
        case `modelScope`
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
    public init(`source`: RowsWindowSource? = nil, `modelScope`: RowsModelScope? = nil, `id`: String, `role`: RowsRole, `durationSeconds`: Int64? = nil, `label`: RowsText, `limitKey`: String, `poolKey`: String, `resetMode`: RowsResetMode, `remainingPercent`: Double? = nil, `resetsAt`: WireTimestamp? = nil, `observedAt`: WireTimestamp? = nil, `current`: Bool, `validUntil`: WireTimestamp? = nil) throws {
        self.`source` = `source`
        self.`modelScope` = `modelScope`
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
        if c.contains(.`source`), try c.decodeNil(forKey: .`source`) { throw WireDecodeError.invalidIdentity }
        self.`source` = try c.decodeIfPresent(RowsWindowSource.self, forKey: .`source`)
        if c.contains(.`modelScope`), try c.decodeNil(forKey: .`modelScope`) { throw WireDecodeError.invalidIdentity }
        self.`modelScope` = try c.decodeIfPresent(RowsModelScope.self, forKey: .`modelScope`)
        self.`id` = try c.decode(String.self, forKey: .`id`)
        self.`role` = try c.decode(RowsRole.self, forKey: .`role`)
        self.`durationSeconds` = try? c.decodeIfPresent(Int64.self, forKey: .`durationSeconds`)
        self.`label` = try c.decode(RowsText.self, forKey: .`label`)
        self.`limitKey` = try c.decode(String.self, forKey: .`limitKey`)
        self.`poolKey` = try c.decode(String.self, forKey: .`poolKey`)
        self.`resetMode` = try c.decode(RowsResetMode.self, forKey: .`resetMode`)
        self.`remainingPercent` = try? c.decodeIfPresent(Double.self, forKey: .`remainingPercent`)
        do { self.`resetsAt` = try c.decodeIfPresent(WireTimestamp.self, forKey: .`resetsAt`) }
        catch { throw WireDecodeError.invalidBound }
        self.`observedAt` = try? c.decodeIfPresent(WireTimestamp.self, forKey: .`observedAt`)
        self.`current` = try c.decode(Bool.self, forKey: .`current`)
        self.`validUntil` = try? c.decodeIfPresent(WireTimestamp.self, forKey: .`validUntil`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(`source`, forKey: .`source`)
        try c.encodeIfPresent(`modelScope`, forKey: .`modelScope`)
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

public enum RowsWindowSource: Codable, Sendable, Equatable {
    case `localHistory`
    case `runtime`
    case `savedLogin`
    case `apiKey`
    case `other`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "local_history": self = .`localHistory`
        case "runtime": self = .`runtime`
        case "saved_login": self = .`savedLogin`
        case "api_key": self = .`apiKey`
        case "other": self = .`other`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`localHistory`: return "local_history"
        case .`runtime`: return "runtime"
        case .`savedLogin`: return "saved_login"
        case .`apiKey`: return "api_key"
        case .`other`: return "other"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
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

public struct WireCockpitAccount: Codable, Sendable {
    public let `tool`: String
    public let `account`: RowsAccount
    private enum CodingKeys: String, CodingKey {
        case `tool`
        case `account`
    }
    public init(`tool`: String, `account`: RowsAccount) throws {
        self.`tool` = `tool`
        self.`account` = `account`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`tool` = try c.decode(String.self, forKey: .`tool`)
        self.`account` = try c.decode(RowsAccount.self, forKey: .`account`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`tool`, forKey: .`tool`)
        try c.encode(`account`, forKey: .`account`)
    }
    private func validate() throws {
        try WireValidation.identity(`tool`)
    }
}

public struct WireCockpitAlert: Codable, Sendable {
    public let `source`: String
    public let `subscriptionRef`: String
    public let `windowId`: String
    public let `severity`: String
    public let `remainingPercent`: Double
    private enum CodingKeys: String, CodingKey {
        case `source`
        case `subscriptionRef`
        case `windowId`
        case `severity`
        case `remainingPercent`
    }
    public init(`source`: String, `subscriptionRef`: String, `windowId`: String, `severity`: String, `remainingPercent`: Double) throws {
        self.`source` = `source`
        self.`subscriptionRef` = `subscriptionRef`
        self.`windowId` = `windowId`
        self.`severity` = `severity`
        self.`remainingPercent` = `remainingPercent`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`source` = try c.decode(String.self, forKey: .`source`)
        self.`subscriptionRef` = try c.decode(String.self, forKey: .`subscriptionRef`)
        self.`windowId` = try c.decode(String.self, forKey: .`windowId`)
        self.`severity` = try c.decode(String.self, forKey: .`severity`)
        self.`remainingPercent` = try c.decode(Double.self, forKey: .`remainingPercent`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`source`, forKey: .`source`)
        try c.encode(`subscriptionRef`, forKey: .`subscriptionRef`)
        try c.encode(`windowId`, forKey: .`windowId`)
        try c.encode(`severity`, forKey: .`severity`)
        try c.encode(`remainingPercent`, forKey: .`remainingPercent`)
    }
    private func validate() throws {
        try WireValidation.reference(`subscriptionRef`)
    }
}

public struct WireCockpitCredits: Codable, Sendable {
    public let `balance`: Double?
    public let `observedAt`: WireTimestamp
    private enum CodingKeys: String, CodingKey {
        case `balance`
        case `observedAt`
    }
    public init(`balance`: Double? = nil, `observedAt`: WireTimestamp) throws {
        self.`balance` = `balance`
        self.`observedAt` = `observedAt`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`balance` = try c.decodeIfPresent(Double.self, forKey: .`balance`)
        self.`observedAt` = try c.decode(WireTimestamp.self, forKey: .`observedAt`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`balance`, forKey: .`balance`)
        try c.encode(`observedAt`, forKey: .`observedAt`)
    }
    private func validate() throws {
    }
}

public struct WireCockpitData: Codable, Sendable {
    public let `details`: WireCockpitDetails?
    public let `history`: WireCockpitHistory?
    public let `projection`: WireRowsProjection
    public let `subscriptions`: [WireCockpitSubscription]
    private enum CodingKeys: String, CodingKey {
        case `details`
        case `history`
        case `projection`
        case `subscriptions`
    }
    public init(`details`: WireCockpitDetails? = nil, `history`: WireCockpitHistory? = nil, `projection`: WireRowsProjection, `subscriptions`: [WireCockpitSubscription]) throws {
        self.`details` = `details`
        self.`history` = `history`
        self.`projection` = `projection`
        self.`subscriptions` = `subscriptions`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`details` = try c.decodeIfPresent(WireCockpitDetails.self, forKey: .`details`)
        self.`history` = try c.decodeIfPresent(WireCockpitHistory.self, forKey: .`history`)
        self.`projection` = try c.decode(WireRowsProjection.self, forKey: .`projection`)
        self.`subscriptions` = try c.decode([WireCockpitSubscription].self, forKey: .`subscriptions`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(`details`, forKey: .`details`)
        try c.encodeIfPresent(`history`, forKey: .`history`)
        try c.encode(`projection`, forKey: .`projection`)
        try c.encode(`subscriptions`, forKey: .`subscriptions`)
    }
    private func validate() throws {
    }
}

public struct WireCockpitDetails: Codable, Sendable {
    public let `publication`: WireCockpitPublication?
    public let `version`: Int
    public let `sources`: [String]
    public let `subscriptions`: [WireCockpitSubscriptionDetails]
    public let `sessions`: [WireCockpitSession]
    public let `sessionCoverage`: String
    public let `resetEvents`: [RowsResetEvent]
    public let `alerts`: [WireCockpitAlert]
    public let `publishedModels`: [WireCockpitPublicationModel]?
    public let `forecasts`: [WireCockpitForecast]?
    private enum CodingKeys: String, CodingKey {
        case `publication`
        case `version`
        case `sources`
        case `subscriptions`
        case `sessions`
        case `sessionCoverage`
        case `resetEvents`
        case `alerts`
        case `publishedModels`
        case `forecasts`
    }
    public init(`publication`: WireCockpitPublication? = nil, `version`: Int, `sources`: [String], `subscriptions`: [WireCockpitSubscriptionDetails], `sessions`: [WireCockpitSession], `sessionCoverage`: String, `resetEvents`: [RowsResetEvent], `alerts`: [WireCockpitAlert], `publishedModels`: [WireCockpitPublicationModel]? = nil, `forecasts`: [WireCockpitForecast]? = nil) throws {
        self.`publication` = `publication`
        self.`version` = `version`
        self.`sources` = `sources`
        self.`subscriptions` = `subscriptions`
        self.`sessions` = `sessions`
        self.`sessionCoverage` = `sessionCoverage`
        self.`resetEvents` = `resetEvents`
        self.`alerts` = `alerts`
        self.`publishedModels` = `publishedModels`
        self.`forecasts` = `forecasts`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if c.contains(.`publication`), try c.decodeNil(forKey: .`publication`) { throw WireDecodeError.invalidIdentity }
        self.`publication` = try c.decodeIfPresent(WireCockpitPublication.self, forKey: .`publication`)
        self.`version` = try c.decode(Int.self, forKey: .`version`)
        self.`sources` = try c.decode([String].self, forKey: .`sources`)
        self.`subscriptions` = try c.decode([WireCockpitSubscriptionDetails].self, forKey: .`subscriptions`)
        self.`sessions` = try c.decode([WireCockpitSession].self, forKey: .`sessions`)
        self.`sessionCoverage` = try c.decode(String.self, forKey: .`sessionCoverage`)
        self.`resetEvents` = try c.decode([RowsResetEvent].self, forKey: .`resetEvents`)
        self.`alerts` = try c.decode([WireCockpitAlert].self, forKey: .`alerts`)
        if c.contains(.`publishedModels`), try c.decodeNil(forKey: .`publishedModels`) { throw WireDecodeError.invalidIdentity }
        self.`publishedModels` = try c.decodeIfPresent([WireCockpitPublicationModel].self, forKey: .`publishedModels`)
        if c.contains(.`forecasts`), try c.decodeNil(forKey: .`forecasts`) { throw WireDecodeError.invalidIdentity }
        self.`forecasts` = try c.decodeIfPresent([WireCockpitForecast].self, forKey: .`forecasts`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(`publication`, forKey: .`publication`)
        try c.encode(`version`, forKey: .`version`)
        try c.encode(`sources`, forKey: .`sources`)
        try c.encode(`subscriptions`, forKey: .`subscriptions`)
        try c.encode(`sessions`, forKey: .`sessions`)
        try c.encode(`sessionCoverage`, forKey: .`sessionCoverage`)
        try c.encode(`resetEvents`, forKey: .`resetEvents`)
        try c.encode(`alerts`, forKey: .`alerts`)
        try c.encodeIfPresent(`publishedModels`, forKey: .`publishedModels`)
        try c.encodeIfPresent(`forecasts`, forKey: .`forecasts`)
    }
    private func validate() throws {
        guard `version` >= 1 else { throw WireDecodeError.invalidBound }
        guard `version` <= 1 else { throw WireDecodeError.invalidBound }
    }
}

public struct WireCockpitEntityRanking: Codable, Sendable {
    public let `measure`: String
    public let `attribution`: String
    public let `recent7d`: WireCockpitEntityWindow
    public let `recent30d`: WireCockpitEntityWindow
    private enum CodingKeys: String, CodingKey {
        case `measure`
        case `attribution`
        case `recent7d`
        case `recent30d`
    }
    public init(`measure`: String, `attribution`: String, `recent7d`: WireCockpitEntityWindow, `recent30d`: WireCockpitEntityWindow) throws {
        self.`measure` = `measure`
        self.`attribution` = `attribution`
        self.`recent7d` = `recent7d`
        self.`recent30d` = `recent30d`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`measure` = try c.decode(String.self, forKey: .`measure`)
        self.`attribution` = try c.decode(String.self, forKey: .`attribution`)
        self.`recent7d` = try c.decode(WireCockpitEntityWindow.self, forKey: .`recent7d`)
        self.`recent30d` = try c.decode(WireCockpitEntityWindow.self, forKey: .`recent30d`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`measure`, forKey: .`measure`)
        try c.encode(`attribution`, forKey: .`attribution`)
        try c.encode(`recent7d`, forKey: .`recent7d`)
        try c.encode(`recent30d`, forKey: .`recent30d`)
    }
    private func validate() throws {
    }
}

public struct WireCockpitEntityWindow: Codable, Sendable {
    public let `entities`: Int
    public let `totalObservedOutputTokens`: Int64
    public let `top`: [WireCockpitRankedEntity]
    private enum CodingKeys: String, CodingKey {
        case `entities`
        case `totalObservedOutputTokens`
        case `top`
    }
    public init(`entities`: Int, `totalObservedOutputTokens`: Int64, `top`: [WireCockpitRankedEntity]) throws {
        self.`entities` = `entities`
        self.`totalObservedOutputTokens` = `totalObservedOutputTokens`
        self.`top` = `top`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`entities` = try c.decode(Int.self, forKey: .`entities`)
        self.`totalObservedOutputTokens` = try c.decode(Int64.self, forKey: .`totalObservedOutputTokens`)
        self.`top` = try c.decode([WireCockpitRankedEntity].self, forKey: .`top`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`entities`, forKey: .`entities`)
        try c.encode(`totalObservedOutputTokens`, forKey: .`totalObservedOutputTokens`)
        try c.encode(`top`, forKey: .`top`)
    }
    private func validate() throws {
    }
}

public struct WireCockpitForecast: Codable, Sendable {
    public let `source`: String
    public let `subscriptionRef`: String
    public let `windowId`: String
    public let `runsOutAt`: WireTimestamp?
    public let `pace`: WireForecastPace
    public let `basis`: WireForecastBasis
    public let `observedAt`: WireTimestamp
    private enum CodingKeys: String, CodingKey {
        case `source`
        case `subscriptionRef`
        case `windowId`
        case `runsOutAt`
        case `pace`
        case `basis`
        case `observedAt`
    }
    public init(`source`: String, `subscriptionRef`: String, `windowId`: String, `runsOutAt`: WireTimestamp? = nil, `pace`: WireForecastPace, `basis`: WireForecastBasis, `observedAt`: WireTimestamp) throws {
        self.`source` = `source`
        self.`subscriptionRef` = `subscriptionRef`
        self.`windowId` = `windowId`
        self.`runsOutAt` = `runsOutAt`
        self.`pace` = `pace`
        self.`basis` = `basis`
        self.`observedAt` = `observedAt`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`source` = try c.decode(String.self, forKey: .`source`)
        self.`subscriptionRef` = try c.decode(String.self, forKey: .`subscriptionRef`)
        self.`windowId` = try c.decode(String.self, forKey: .`windowId`)
        self.`runsOutAt` = try c.decodeIfPresent(WireTimestamp.self, forKey: .`runsOutAt`)
        self.`pace` = try c.decode(WireForecastPace.self, forKey: .`pace`)
        self.`basis` = try c.decode(WireForecastBasis.self, forKey: .`basis`)
        self.`observedAt` = try c.decode(WireTimestamp.self, forKey: .`observedAt`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`source`, forKey: .`source`)
        try c.encode(`subscriptionRef`, forKey: .`subscriptionRef`)
        try c.encode(`windowId`, forKey: .`windowId`)
        try c.encode(`runsOutAt`, forKey: .`runsOutAt`)
        try c.encode(`pace`, forKey: .`pace`)
        try c.encode(`basis`, forKey: .`basis`)
        try c.encode(`observedAt`, forKey: .`observedAt`)
    }
    private func validate() throws {
        try WireValidation.reference(`subscriptionRef`)
    }
}

public struct WireCockpitHistory: Codable, Sendable {
    public let `version`: Int
    public let `sources`: [String]
    public let `coverage`: String
    public let `recordingSince`: WireTimestamp?
    public let `subscriptions`: [WireCockpitSubscriptionHistory]
    public let `models`: WireCockpitEntityRanking
    public let `tools`: WireCockpitEntityRanking
    public let `dailyFrom`: String?
    public let `daily`: [WireCockpitSourceBucket]
    public let `hourly`: [WireCockpitSourceBucket]
    public let `projects`: WireCockpitProjectRanking
    private enum CodingKeys: String, CodingKey {
        case `version`
        case `sources`
        case `coverage`
        case `recordingSince`
        case `subscriptions`
        case `models`
        case `tools`
        case `dailyFrom`
        case `daily`
        case `hourly`
        case `projects`
    }
    public init(`version`: Int, `sources`: [String], `coverage`: String, `recordingSince`: WireTimestamp? = nil, `subscriptions`: [WireCockpitSubscriptionHistory], `models`: WireCockpitEntityRanking, `tools`: WireCockpitEntityRanking, `dailyFrom`: String? = nil, `daily`: [WireCockpitSourceBucket], `hourly`: [WireCockpitSourceBucket], `projects`: WireCockpitProjectRanking) throws {
        self.`version` = `version`
        self.`sources` = `sources`
        self.`coverage` = `coverage`
        self.`recordingSince` = `recordingSince`
        self.`subscriptions` = `subscriptions`
        self.`models` = `models`
        self.`tools` = `tools`
        self.`dailyFrom` = `dailyFrom`
        self.`daily` = `daily`
        self.`hourly` = `hourly`
        self.`projects` = `projects`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`version` = try c.decode(Int.self, forKey: .`version`)
        self.`sources` = try c.decode([String].self, forKey: .`sources`)
        self.`coverage` = try c.decode(String.self, forKey: .`coverage`)
        self.`recordingSince` = try c.decodeIfPresent(WireTimestamp.self, forKey: .`recordingSince`)
        self.`subscriptions` = try c.decode([WireCockpitSubscriptionHistory].self, forKey: .`subscriptions`)
        self.`models` = try c.decode(WireCockpitEntityRanking.self, forKey: .`models`)
        self.`tools` = try c.decode(WireCockpitEntityRanking.self, forKey: .`tools`)
        self.`dailyFrom` = try c.decodeIfPresent(String.self, forKey: .`dailyFrom`)
        self.`daily` = try c.decode([WireCockpitSourceBucket].self, forKey: .`daily`)
        self.`hourly` = try c.decode([WireCockpitSourceBucket].self, forKey: .`hourly`)
        self.`projects` = try c.decode(WireCockpitProjectRanking.self, forKey: .`projects`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`version`, forKey: .`version`)
        try c.encode(`sources`, forKey: .`sources`)
        try c.encode(`coverage`, forKey: .`coverage`)
        try c.encode(`recordingSince`, forKey: .`recordingSince`)
        try c.encode(`subscriptions`, forKey: .`subscriptions`)
        try c.encode(`models`, forKey: .`models`)
        try c.encode(`tools`, forKey: .`tools`)
        try c.encode(`dailyFrom`, forKey: .`dailyFrom`)
        try c.encode(`daily`, forKey: .`daily`)
        try c.encode(`hourly`, forKey: .`hourly`)
        try c.encode(`projects`, forKey: .`projects`)
    }
    private func validate() throws {
        guard `version` >= 1 else { throw WireDecodeError.invalidBound }
        guard `version` <= 1 else { throw WireDecodeError.invalidBound }
    }
}

public struct WireCockpitHistorySums: Codable, Sendable {
    public let `inputTokens`: Int64?
    public let `outputTokens`: Int64
    public let `cacheReadTokens`: Int64?
    public let `cacheWriteTokens`: Int64?
    public let `cacheHitRatio`: Double?
    public let `generationTps`: Double?
    public let `observedRequests`: Int
    public let `eligibleRequests`: Int
    private enum CodingKeys: String, CodingKey {
        case `inputTokens`
        case `outputTokens`
        case `cacheReadTokens`
        case `cacheWriteTokens`
        case `cacheHitRatio`
        case `generationTps`
        case `observedRequests`
        case `eligibleRequests`
    }
    public init(`inputTokens`: Int64? = nil, `outputTokens`: Int64, `cacheReadTokens`: Int64? = nil, `cacheWriteTokens`: Int64? = nil, `cacheHitRatio`: Double? = nil, `generationTps`: Double? = nil, `observedRequests`: Int, `eligibleRequests`: Int) throws {
        self.`inputTokens` = `inputTokens`
        self.`outputTokens` = `outputTokens`
        self.`cacheReadTokens` = `cacheReadTokens`
        self.`cacheWriteTokens` = `cacheWriteTokens`
        self.`cacheHitRatio` = `cacheHitRatio`
        self.`generationTps` = `generationTps`
        self.`observedRequests` = `observedRequests`
        self.`eligibleRequests` = `eligibleRequests`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`inputTokens` = try c.decodeIfPresent(Int64.self, forKey: .`inputTokens`)
        self.`outputTokens` = try c.decode(Int64.self, forKey: .`outputTokens`)
        self.`cacheReadTokens` = try c.decodeIfPresent(Int64.self, forKey: .`cacheReadTokens`)
        self.`cacheWriteTokens` = try c.decodeIfPresent(Int64.self, forKey: .`cacheWriteTokens`)
        self.`cacheHitRatio` = try c.decodeIfPresent(Double.self, forKey: .`cacheHitRatio`)
        self.`generationTps` = try c.decodeIfPresent(Double.self, forKey: .`generationTps`)
        self.`observedRequests` = try c.decode(Int.self, forKey: .`observedRequests`)
        self.`eligibleRequests` = try c.decode(Int.self, forKey: .`eligibleRequests`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`inputTokens`, forKey: .`inputTokens`)
        try c.encode(`outputTokens`, forKey: .`outputTokens`)
        try c.encode(`cacheReadTokens`, forKey: .`cacheReadTokens`)
        try c.encode(`cacheWriteTokens`, forKey: .`cacheWriteTokens`)
        try c.encode(`cacheHitRatio`, forKey: .`cacheHitRatio`)
        try c.encode(`generationTps`, forKey: .`generationTps`)
        try c.encode(`observedRequests`, forKey: .`observedRequests`)
        try c.encode(`eligibleRequests`, forKey: .`eligibleRequests`)
    }
    private func validate() throws {
    }
}

public struct WireCockpitProjectRanking: Codable, Sendable {
    public let `recent7d`: [WireCockpitRankedProject]
    public let `recent30d`: [WireCockpitRankedProject]
    private enum CodingKeys: String, CodingKey {
        case `recent7d`
        case `recent30d`
    }
    public init(`recent7d`: [WireCockpitRankedProject], `recent30d`: [WireCockpitRankedProject]) throws {
        self.`recent7d` = `recent7d`
        self.`recent30d` = `recent30d`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`recent7d` = try c.decode([WireCockpitRankedProject].self, forKey: .`recent7d`)
        self.`recent30d` = try c.decode([WireCockpitRankedProject].self, forKey: .`recent30d`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`recent7d`, forKey: .`recent7d`)
        try c.encode(`recent30d`, forKey: .`recent30d`)
    }
    private func validate() throws {
    }
}

public struct WireCockpitPublication: Codable, Sendable {
    public let `contractVersion`: Int
    public let `publicationId`: String
    public let `publishedAt`: WireTimestamp
    public let `source`: String
    public let `models`: [WireCockpitPublicationModel]
    public let `truncated`: Bool
    private enum CodingKeys: String, CodingKey {
        case `contractVersion`
        case `publicationId`
        case `publishedAt`
        case `source`
        case `models`
        case `truncated`
    }
    public init(`contractVersion`: Int, `publicationId`: String, `publishedAt`: WireTimestamp, `source`: String, `models`: [WireCockpitPublicationModel], `truncated`: Bool) throws {
        self.`contractVersion` = `contractVersion`
        self.`publicationId` = `publicationId`
        self.`publishedAt` = `publishedAt`
        self.`source` = `source`
        self.`models` = `models`
        self.`truncated` = `truncated`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`contractVersion` = try c.decode(Int.self, forKey: .`contractVersion`)
        self.`publicationId` = try c.decode(String.self, forKey: .`publicationId`)
        self.`publishedAt` = try c.decode(WireTimestamp.self, forKey: .`publishedAt`)
        self.`source` = try c.decode(String.self, forKey: .`source`)
        self.`models` = try c.decode([WireCockpitPublicationModel].self, forKey: .`models`)
        self.`truncated` = try c.decode(Bool.self, forKey: .`truncated`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`contractVersion`, forKey: .`contractVersion`)
        try c.encode(`publicationId`, forKey: .`publicationId`)
        try c.encode(`publishedAt`, forKey: .`publishedAt`)
        try c.encode(`source`, forKey: .`source`)
        try c.encode(`models`, forKey: .`models`)
        try c.encode(`truncated`, forKey: .`truncated`)
    }
    private func validate() throws {
        guard `contractVersion` >= 1 else { throw WireDecodeError.invalidBound }
        guard `contractVersion` <= 1 else { throw WireDecodeError.invalidBound }
        try WireValidation.identity(`publicationId`)
    }
}

public struct WireCockpitPublicationEffort: Codable, Sendable {
    public let `effort`: String
    public let `label`: String
    public let `star`: Bool
    public let `multiplier`: Double?
    public let `ability`: Double?
    public let `cost`: Double?
    public let `time`: Double?
    public let `provisional`: Bool?
    private enum CodingKeys: String, CodingKey {
        case `effort`
        case `label`
        case `star`
        case `multiplier`
        case `ability`
        case `cost`
        case `time`
        case `provisional`
    }
    public init(`effort`: String, `label`: String, `star`: Bool, `multiplier`: Double? = nil, `ability`: Double? = nil, `cost`: Double? = nil, `time`: Double? = nil, `provisional`: Bool? = nil) throws {
        self.`effort` = `effort`
        self.`label` = `label`
        self.`star` = `star`
        self.`multiplier` = `multiplier`
        self.`ability` = `ability`
        self.`cost` = `cost`
        self.`time` = `time`
        self.`provisional` = `provisional`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`effort` = try c.decode(String.self, forKey: .`effort`)
        self.`label` = try c.decode(String.self, forKey: .`label`)
        self.`star` = try c.decode(Bool.self, forKey: .`star`)
        if c.contains(.`multiplier`), try c.decodeNil(forKey: .`multiplier`) { throw WireDecodeError.invalidIdentity }
        self.`multiplier` = try c.decodeIfPresent(Double.self, forKey: .`multiplier`)
        self.`ability` = try c.decodeIfPresent(Double.self, forKey: .`ability`)
        self.`cost` = try c.decodeIfPresent(Double.self, forKey: .`cost`)
        self.`time` = try c.decodeIfPresent(Double.self, forKey: .`time`)
        if c.contains(.`provisional`), try c.decodeNil(forKey: .`provisional`) { throw WireDecodeError.invalidIdentity }
        self.`provisional` = try c.decodeIfPresent(Bool.self, forKey: .`provisional`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`effort`, forKey: .`effort`)
        try c.encode(`label`, forKey: .`label`)
        try c.encode(`star`, forKey: .`star`)
        try c.encodeIfPresent(`multiplier`, forKey: .`multiplier`)
        try c.encode(`ability`, forKey: .`ability`)
        try c.encode(`cost`, forKey: .`cost`)
        try c.encode(`time`, forKey: .`time`)
        try c.encodeIfPresent(`provisional`, forKey: .`provisional`)
    }
    private func validate() throws {
    }
}

public struct WireCockpitPublicationModel: Codable, Sendable {
    public let `id`: String
    public let `name`: String
    public let `developerId`: String
    public let `recommended`: String
    public let `efforts`: [WireCockpitPublicationEffort]
    private enum CodingKeys: String, CodingKey {
        case `id`
        case `name`
        case `developerId`
        case `recommended`
        case `efforts`
    }
    public init(`id`: String, `name`: String, `developerId`: String, `recommended`: String, `efforts`: [WireCockpitPublicationEffort]) throws {
        self.`id` = `id`
        self.`name` = `name`
        self.`developerId` = `developerId`
        self.`recommended` = `recommended`
        self.`efforts` = `efforts`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`id` = try c.decode(String.self, forKey: .`id`)
        self.`name` = try c.decode(String.self, forKey: .`name`)
        self.`developerId` = try c.decode(String.self, forKey: .`developerId`)
        self.`recommended` = try c.decode(String.self, forKey: .`recommended`)
        self.`efforts` = try c.decode([WireCockpitPublicationEffort].self, forKey: .`efforts`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`id`, forKey: .`id`)
        try c.encode(`name`, forKey: .`name`)
        try c.encode(`developerId`, forKey: .`developerId`)
        try c.encode(`recommended`, forKey: .`recommended`)
        try c.encode(`efforts`, forKey: .`efforts`)
    }
    private func validate() throws {
        try WireValidation.identity(`id`)
    }
}

public struct WireCockpitQueryParams: Codable, Sendable {
    public let `redBelow`: Int?
    private enum CodingKeys: String, CodingKey {
        case `redBelow`
    }
    public init(`redBelow`: Int? = nil) throws {
        self.`redBelow` = `redBelow`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if c.contains(.`redBelow`), try c.decodeNil(forKey: .`redBelow`) { throw WireDecodeError.invalidIdentity }
        self.`redBelow` = try c.decodeIfPresent(Int.self, forKey: .`redBelow`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(`redBelow`, forKey: .`redBelow`)
    }
    private func validate() throws {
        if let value = `redBelow`, ![10, 16, 20, 25].contains(value) { throw WireDecodeError.invalidBound }
    }
}

public struct WireCockpitRankedEntity: Codable, Sendable {
    public let `name`: String
    public let `observedRequests`: Int
    public let `observedOutputTokens`: Int64
    public let `share`: Double
    private enum CodingKeys: String, CodingKey {
        case `name`
        case `observedRequests`
        case `observedOutputTokens`
        case `share`
    }
    public init(`name`: String, `observedRequests`: Int, `observedOutputTokens`: Int64, `share`: Double) throws {
        self.`name` = `name`
        self.`observedRequests` = `observedRequests`
        self.`observedOutputTokens` = `observedOutputTokens`
        self.`share` = `share`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`name` = try c.decode(String.self, forKey: .`name`)
        self.`observedRequests` = try c.decode(Int.self, forKey: .`observedRequests`)
        self.`observedOutputTokens` = try c.decode(Int64.self, forKey: .`observedOutputTokens`)
        self.`share` = try c.decode(Double.self, forKey: .`share`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`name`, forKey: .`name`)
        try c.encode(`observedRequests`, forKey: .`observedRequests`)
        try c.encode(`observedOutputTokens`, forKey: .`observedOutputTokens`)
        try c.encode(`share`, forKey: .`share`)
    }
    private func validate() throws {
    }
}

public struct WireCockpitRankedProject: Codable, Sendable {
    public let `ref`: String
    public let `label`: String?
    public let `model`: String?
    public let `effort`: String?
    public let `observedOutputTokens`: Int64
    public let `share`: Double
    private enum CodingKeys: String, CodingKey {
        case `ref`
        case `label`
        case `model`
        case `effort`
        case `observedOutputTokens`
        case `share`
    }
    public init(`ref`: String, `label`: String? = nil, `model`: String? = nil, `effort`: String? = nil, `observedOutputTokens`: Int64, `share`: Double) throws {
        self.`ref` = `ref`
        self.`label` = `label`
        self.`model` = `model`
        self.`effort` = `effort`
        self.`observedOutputTokens` = `observedOutputTokens`
        self.`share` = `share`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`ref` = try c.decode(String.self, forKey: .`ref`)
        self.`label` = try c.decodeIfPresent(String.self, forKey: .`label`)
        self.`model` = try c.decodeIfPresent(String.self, forKey: .`model`)
        self.`effort` = try c.decodeIfPresent(String.self, forKey: .`effort`)
        self.`observedOutputTokens` = try c.decode(Int64.self, forKey: .`observedOutputTokens`)
        self.`share` = try c.decode(Double.self, forKey: .`share`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`ref`, forKey: .`ref`)
        try c.encode(`label`, forKey: .`label`)
        try c.encode(`model`, forKey: .`model`)
        try c.encode(`effort`, forKey: .`effort`)
        try c.encode(`observedOutputTokens`, forKey: .`observedOutputTokens`)
        try c.encode(`share`, forKey: .`share`)
    }
    private func validate() throws {
    }
}

public struct WireCockpitResetCount: Codable, Sendable {
    public let `kind`: String
    public let `count`: Int?
    public let `expiresAt`: WireTimestamp?
    private enum CodingKeys: String, CodingKey {
        case `kind`
        case `count`
        case `expiresAt`
    }
    public init(`kind`: String, `count`: Int? = nil, `expiresAt`: WireTimestamp? = nil) throws {
        self.`kind` = `kind`
        self.`count` = `count`
        self.`expiresAt` = `expiresAt`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`kind` = try c.decode(String.self, forKey: .`kind`)
        self.`count` = try c.decodeIfPresent(Int.self, forKey: .`count`)
        self.`expiresAt` = try c.decodeIfPresent(WireTimestamp.self, forKey: .`expiresAt`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`kind`, forKey: .`kind`)
        try c.encode(`count`, forKey: .`count`)
        try c.encode(`expiresAt`, forKey: .`expiresAt`)
    }
    private func validate() throws {
    }
}

public struct WireCockpitSession: Codable, Sendable {
    public let `sessionRef`: String
    public let `source`: String
    public let `subscriptionRef`: String?
    public let `model`: String
    public let `effort`: String?
    public let `projectLabel`: String?
    public let `lastObservedAt`: WireTimestamp
    public let `state`: String
    public let `rate`: Double?
    private enum CodingKeys: String, CodingKey {
        case `sessionRef`
        case `source`
        case `subscriptionRef`
        case `model`
        case `effort`
        case `projectLabel`
        case `lastObservedAt`
        case `state`
        case `rate`
    }
    public init(`sessionRef`: String, `source`: String, `subscriptionRef`: String? = nil, `model`: String, `effort`: String? = nil, `projectLabel`: String? = nil, `lastObservedAt`: WireTimestamp, `state`: String, `rate`: Double? = nil) throws {
        self.`sessionRef` = `sessionRef`
        self.`source` = `source`
        self.`subscriptionRef` = `subscriptionRef`
        self.`model` = `model`
        self.`effort` = `effort`
        self.`projectLabel` = `projectLabel`
        self.`lastObservedAt` = `lastObservedAt`
        self.`state` = `state`
        self.`rate` = `rate`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`sessionRef` = try c.decode(String.self, forKey: .`sessionRef`)
        self.`source` = try c.decode(String.self, forKey: .`source`)
        self.`subscriptionRef` = try c.decodeIfPresent(String.self, forKey: .`subscriptionRef`)
        self.`model` = try c.decode(String.self, forKey: .`model`)
        self.`effort` = try c.decodeIfPresent(String.self, forKey: .`effort`)
        self.`projectLabel` = try c.decodeIfPresent(String.self, forKey: .`projectLabel`)
        self.`lastObservedAt` = try c.decode(WireTimestamp.self, forKey: .`lastObservedAt`)
        self.`state` = try c.decode(String.self, forKey: .`state`)
        self.`rate` = try c.decodeIfPresent(Double.self, forKey: .`rate`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`sessionRef`, forKey: .`sessionRef`)
        try c.encode(`source`, forKey: .`source`)
        try c.encode(`subscriptionRef`, forKey: .`subscriptionRef`)
        try c.encode(`model`, forKey: .`model`)
        try c.encode(`effort`, forKey: .`effort`)
        try c.encode(`projectLabel`, forKey: .`projectLabel`)
        try c.encode(`lastObservedAt`, forKey: .`lastObservedAt`)
        try c.encode(`state`, forKey: .`state`)
        try c.encode(`rate`, forKey: .`rate`)
    }
    private func validate() throws {
        try WireValidation.reference(`sessionRef`)
        if let value = `subscriptionRef` { try WireValidation.reference(value) }
    }
}

public struct WireCockpitSourceBucket: Codable, Sendable {
    public let `at`: String
    public let `source`: String
    public let `observedOutputTokens`: Int64
    private enum CodingKeys: String, CodingKey {
        case `at`
        case `source`
        case `observedOutputTokens`
    }
    public init(`at`: String, `source`: String, `observedOutputTokens`: Int64) throws {
        self.`at` = `at`
        self.`source` = `source`
        self.`observedOutputTokens` = `observedOutputTokens`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`at` = try c.decode(String.self, forKey: .`at`)
        self.`source` = try c.decode(String.self, forKey: .`source`)
        self.`observedOutputTokens` = try c.decode(Int64.self, forKey: .`observedOutputTokens`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`at`, forKey: .`at`)
        try c.encode(`source`, forKey: .`source`)
        try c.encode(`observedOutputTokens`, forKey: .`observedOutputTokens`)
    }
    private func validate() throws {
    }
}

public struct WireCockpitSourceHistory: Codable, Sendable {
    public let `source`: String
    public let `bindingBasis`: String
    public let `recent7d`: WireCockpitHistorySums
    public let `recent30d`: WireCockpitHistorySums
    private enum CodingKeys: String, CodingKey {
        case `source`
        case `bindingBasis`
        case `recent7d`
        case `recent30d`
    }
    public init(`source`: String, `bindingBasis`: String, `recent7d`: WireCockpitHistorySums, `recent30d`: WireCockpitHistorySums) throws {
        self.`source` = `source`
        self.`bindingBasis` = `bindingBasis`
        self.`recent7d` = `recent7d`
        self.`recent30d` = `recent30d`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`source` = try c.decode(String.self, forKey: .`source`)
        self.`bindingBasis` = try c.decode(String.self, forKey: .`bindingBasis`)
        self.`recent7d` = try c.decode(WireCockpitHistorySums.self, forKey: .`recent7d`)
        self.`recent30d` = try c.decode(WireCockpitHistorySums.self, forKey: .`recent30d`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`source`, forKey: .`source`)
        try c.encode(`bindingBasis`, forKey: .`bindingBasis`)
        try c.encode(`recent7d`, forKey: .`recent7d`)
        try c.encode(`recent30d`, forKey: .`recent30d`)
    }
    private func validate() throws {
    }
}

public struct WireCockpitSubscription: Codable, Sendable {
    public let `subscriptionRef`: String
    public let `accounts`: [WireCockpitAccount]
    private enum CodingKeys: String, CodingKey {
        case `subscriptionRef`
        case `accounts`
    }
    public init(`subscriptionRef`: String, `accounts`: [WireCockpitAccount]) throws {
        self.`subscriptionRef` = `subscriptionRef`
        self.`accounts` = `accounts`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`subscriptionRef` = try c.decode(String.self, forKey: .`subscriptionRef`)
        self.`accounts` = try c.decode([WireCockpitAccount].self, forKey: .`accounts`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`subscriptionRef`, forKey: .`subscriptionRef`)
        try c.encode(`accounts`, forKey: .`accounts`)
    }
    private func validate() throws {
        try WireValidation.reference(`subscriptionRef`)
    }
}

public struct WireCockpitSubscriptionDetails: Codable, Sendable {
    public let `resetCountsTruncated`: Bool?
    public let `resetCards`: RowsResetCards?
    public let `subscriptionRef`: String
    public let `resetCounts`: [WireCockpitResetCount]
    public let `credits`: WireCockpitCredits?
    public let `today`: [WireCockpitToday]
    private enum CodingKeys: String, CodingKey {
        case `resetCountsTruncated`
        case `resetCards`
        case `subscriptionRef`
        case `resetCounts`
        case `credits`
        case `today`
    }
    public init(`resetCountsTruncated`: Bool? = nil, `resetCards`: RowsResetCards? = nil, `subscriptionRef`: String, `resetCounts`: [WireCockpitResetCount], `credits`: WireCockpitCredits? = nil, `today`: [WireCockpitToday]) throws {
        self.`resetCountsTruncated` = `resetCountsTruncated`
        self.`resetCards` = `resetCards`
        self.`subscriptionRef` = `subscriptionRef`
        self.`resetCounts` = `resetCounts`
        self.`credits` = `credits`
        self.`today` = `today`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if c.contains(.`resetCountsTruncated`), try c.decodeNil(forKey: .`resetCountsTruncated`) { throw WireDecodeError.invalidIdentity }
        self.`resetCountsTruncated` = try c.decodeIfPresent(Bool.self, forKey: .`resetCountsTruncated`)
        if c.contains(.`resetCards`), try c.decodeNil(forKey: .`resetCards`) { throw WireDecodeError.invalidIdentity }
        self.`resetCards` = try c.decodeIfPresent(RowsResetCards.self, forKey: .`resetCards`)
        self.`subscriptionRef` = try c.decode(String.self, forKey: .`subscriptionRef`)
        self.`resetCounts` = try c.decode([WireCockpitResetCount].self, forKey: .`resetCounts`)
        self.`credits` = try c.decodeIfPresent(WireCockpitCredits.self, forKey: .`credits`)
        self.`today` = try c.decode([WireCockpitToday].self, forKey: .`today`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(`resetCountsTruncated`, forKey: .`resetCountsTruncated`)
        try c.encodeIfPresent(`resetCards`, forKey: .`resetCards`)
        try c.encode(`subscriptionRef`, forKey: .`subscriptionRef`)
        try c.encode(`resetCounts`, forKey: .`resetCounts`)
        try c.encode(`credits`, forKey: .`credits`)
        try c.encode(`today`, forKey: .`today`)
    }
    private func validate() throws {
        try WireValidation.reference(`subscriptionRef`)
    }
}

public struct WireCockpitSubscriptionHistory: Codable, Sendable {
    public let `subscriptionRef`: String
    public let `sources`: [WireCockpitSourceHistory]
    private enum CodingKeys: String, CodingKey {
        case `subscriptionRef`
        case `sources`
    }
    public init(`subscriptionRef`: String, `sources`: [WireCockpitSourceHistory]) throws {
        self.`subscriptionRef` = `subscriptionRef`
        self.`sources` = `sources`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`subscriptionRef` = try c.decode(String.self, forKey: .`subscriptionRef`)
        self.`sources` = try c.decode([WireCockpitSourceHistory].self, forKey: .`sources`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`subscriptionRef`, forKey: .`subscriptionRef`)
        try c.encode(`sources`, forKey: .`sources`)
    }
    private func validate() throws {
        try WireValidation.reference(`subscriptionRef`)
    }
}

public struct WireCockpitToday: Codable, Sendable {
    public let `source`: String
    public let `observedOutputTokens`: Int64
    public let `generationTps`: Double?
    public let `bindingBasis`: String
    private enum CodingKeys: String, CodingKey {
        case `source`
        case `observedOutputTokens`
        case `generationTps`
        case `bindingBasis`
    }
    public init(`source`: String, `observedOutputTokens`: Int64, `generationTps`: Double? = nil, `bindingBasis`: String) throws {
        self.`source` = `source`
        self.`observedOutputTokens` = `observedOutputTokens`
        self.`generationTps` = `generationTps`
        self.`bindingBasis` = `bindingBasis`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`source` = try c.decode(String.self, forKey: .`source`)
        self.`observedOutputTokens` = try c.decode(Int64.self, forKey: .`observedOutputTokens`)
        self.`generationTps` = try c.decodeIfPresent(Double.self, forKey: .`generationTps`)
        self.`bindingBasis` = try c.decode(String.self, forKey: .`bindingBasis`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`source`, forKey: .`source`)
        try c.encode(`observedOutputTokens`, forKey: .`observedOutputTokens`)
        try c.encode(`generationTps`, forKey: .`generationTps`)
        try c.encode(`bindingBasis`, forKey: .`bindingBasis`)
    }
    private func validate() throws {
    }
}

public struct WireConsentFacts: Codable, Sendable {
    public let `consentTextVersion`: Int
    public let `scopes`: [WireConsentScope]
    private enum CodingKeys: String, CodingKey {
        case `consentTextVersion`
        case `scopes`
    }
    public init(`consentTextVersion`: Int, `scopes`: [WireConsentScope]) throws {
        self.`consentTextVersion` = `consentTextVersion`
        self.`scopes` = `scopes`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`consentTextVersion` = try c.decode(Int.self, forKey: .`consentTextVersion`)
        self.`scopes` = try c.decode([WireConsentScope].self, forKey: .`scopes`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`consentTextVersion`, forKey: .`consentTextVersion`)
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
    public let `disabledReason`: WireScopeDisabledReason?
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
    public init(`scope`: String, `tool`: String, `route`: RowsRoute, `detected`: Bool, `retired`: Bool, `state`: WireConsentState, `defaultCheck`: Bool, `keychain`: WireKeychainChoice? = nil, `cleanupPending`: Bool, `disabledReason`: WireScopeDisabledReason? = nil) throws {
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
        self.`disabledReason` = try? c.decodeIfPresent(WireScopeDisabledReason.self, forKey: .`disabledReason`)
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
        if c.contains(.`accessToken`), try c.decodeNil(forKey: .`accessToken`) { throw WireDecodeError.invalidIdentity }
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
    public let `refreshDecisions`: [WireRefreshDecision]?
    public let `protocolVersion`: String
    public let `serverVersion`: String
    public let `uptimeSeconds`: Int64
    public let `scopes`: [WireScopeDiag]
    public let `lastErrorClass`: String?
    private enum CodingKeys: String, CodingKey {
        case `refreshDecisions`
        case `protocolVersion`
        case `serverVersion`
        case `uptimeSeconds`
        case `scopes`
        case `lastErrorClass`
    }
    public init(`refreshDecisions`: [WireRefreshDecision]? = nil, `protocolVersion`: String, `serverVersion`: String, `uptimeSeconds`: Int64, `scopes`: [WireScopeDiag], `lastErrorClass`: String? = nil) throws {
        self.`refreshDecisions` = `refreshDecisions`
        self.`protocolVersion` = `protocolVersion`
        self.`serverVersion` = `serverVersion`
        self.`uptimeSeconds` = `uptimeSeconds`
        self.`scopes` = `scopes`
        self.`lastErrorClass` = `lastErrorClass`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if c.contains(.`refreshDecisions`), try c.decodeNil(forKey: .`refreshDecisions`) { throw WireDecodeError.invalidIdentity }
        self.`refreshDecisions` = try c.decodeIfPresent([WireRefreshDecision].self, forKey: .`refreshDecisions`)
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
        try c.encodeIfPresent(`refreshDecisions`, forKey: .`refreshDecisions`)
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
        for scope in (scopes ?? []) { try WireValidation.identity(scope) }
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
    public let `id`: WireRequestID?
    public let `error`: WireRPCError
    private enum CodingKeys: String, CodingKey {
        case `jsonrpc`
        case `id`
        case `error`
    }
    public init(`jsonrpc`: String, `id`: WireRequestID?, `error`: WireRPCError) throws {
        self.`jsonrpc` = `jsonrpc`
        self.`id` = `id`
        self.`error` = `error`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let extra = try decoder.container(keyedBy: WireCodingKey.self)
        if extra.allKeys.contains(where: { $0.stringValue == "result" }) { throw WireDecodeError.invalidFrame }
        self.`jsonrpc` = try c.decode(String.self, forKey: .`jsonrpc`)
        guard c.contains(.`id`) else { throw WireDecodeError.invalidIdentity }
        self.`id` = try c.decodeIfPresent(WireRequestID.self, forKey: .`id`)
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

public enum WireForecastBasis: Codable, Sendable, Equatable {
    case `recentRate`
    case `cycleAverage`
    case `none`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "recent-rate": self = .`recentRate`
        case "cycle-average": self = .`cycleAverage`
        case "none": self = .`none`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`recentRate`: return "recent-rate"
        case .`cycleAverage`: return "cycle-average"
        case .`none`: return "none"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public enum WireForecastPace: Codable, Sendable, Equatable {
    case `tight`
    case `onTrack`
    case `surplus`
    case `exhausted`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "tight": self = .`tight`
        case "on_track": self = .`onTrack`
        case "surplus": self = .`surplus`
        case "exhausted": self = .`exhausted`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`tight`: return "tight"
        case .`onTrack`: return "on_track"
        case .`surplus`: return "surplus"
        case .`exhausted`: return "exhausted"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
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

public enum WireHistoryKind: Codable, Sendable, Equatable {
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
    public let `kind`: WireHistoryKind
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
    public init(`kind`: WireHistoryKind, `tool`: String, `ref`: String? = nil, `cursor`: String? = nil, `limit`: Int) throws {
        self.`kind` = `kind`
        self.`tool` = `tool`
        self.`ref` = `ref`
        self.`cursor` = `cursor`
        self.`limit` = `limit`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`kind` = try c.decode(WireHistoryKind.self, forKey: .`kind`)
        self.`tool` = try c.decode(String.self, forKey: .`tool`)
        if c.contains(.`ref`), try c.decodeNil(forKey: .`ref`) { throw WireDecodeError.invalidIdentity }
        self.`ref` = try c.decodeIfPresent(String.self, forKey: .`ref`)
        if c.contains(.`cursor`), try c.decodeNil(forKey: .`cursor`) { throw WireDecodeError.invalidIdentity }
        self.`cursor` = try c.decodeIfPresent(String.self, forKey: .`cursor`)
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
public enum WireMemberRefreshOutcome: Codable, Sendable, Equatable {
    case `started`
    case `deferred`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "started": self = .`started`
        case "deferred": self = .`deferred`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`started`: return "started"
        case .`deferred`: return "deferred"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public enum WireMemberRefreshReason: Codable, Sendable, Equatable {
    case `floor`
    case `backoff`
    case `budget`
    case `notGranted`
    case `offline`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "floor": self = .`floor`
        case "backoff": self = .`backoff`
        case "budget": self = .`budget`
        case "not_granted": self = .`notGranted`
        case "offline": self = .`offline`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`floor`: return "floor"
        case .`backoff`: return "backoff"
        case .`budget`: return "budget"
        case .`notGranted`: return "not_granted"
        case .`offline`: return "offline"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public struct WireMemberRefreshResult: Codable, Sendable {
    public let `outcome`: WireMemberRefreshOutcome
    public let `notBefore`: WireTimestamp?
    public let `reason`: WireMemberRefreshReason?
    private enum CodingKeys: String, CodingKey {
        case `outcome`
        case `notBefore`
        case `reason`
    }
    public init(`outcome`: WireMemberRefreshOutcome, `notBefore`: WireTimestamp? = nil, `reason`: WireMemberRefreshReason? = nil) throws {
        self.`outcome` = `outcome`
        self.`notBefore` = `notBefore`
        self.`reason` = `reason`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`outcome` = try c.decode(WireMemberRefreshOutcome.self, forKey: .`outcome`)
        if c.contains(.`notBefore`), try c.decodeNil(forKey: .`notBefore`) { throw WireDecodeError.invalidIdentity }
        self.`notBefore` = try c.decodeIfPresent(WireTimestamp.self, forKey: .`notBefore`)
        if c.contains(.`reason`), try c.decodeNil(forKey: .`reason`) { throw WireDecodeError.invalidIdentity }
        self.`reason` = try c.decodeIfPresent(WireMemberRefreshReason.self, forKey: .`reason`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`outcome`, forKey: .`outcome`)
        try c.encodeIfPresent(`notBefore`, forKey: .`notBefore`)
        try c.encodeIfPresent(`reason`, forKey: .`reason`)
    }
    private func validate() throws {
    }
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

public struct WirePluginInstallParams: Codable, Sendable {
    public let `tool`: WirePluginTool
    public let `offline`: Bool?
    private enum CodingKeys: String, CodingKey {
        case `tool`
        case `offline`
    }
    public init(`tool`: WirePluginTool, `offline`: Bool? = nil) throws {
        self.`tool` = `tool`
        self.`offline` = `offline`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`tool` = try c.decode(WirePluginTool.self, forKey: .`tool`)
        self.`offline` = try? c.decodeIfPresent(Bool.self, forKey: .`offline`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`tool`, forKey: .`tool`)
        try c.encodeIfPresent(`offline`, forKey: .`offline`)
    }
    private func validate() throws {
    }
}

public struct WirePluginInstallResult: Codable, Sendable {
    public let `schemaVersion`: Int
    public let `tool`: WirePluginTool
    public let `status`: WirePluginInstallStatus
    public let `commands`: [[String]]
    public let `completed`: Int
    public let `docs`: String
    private enum CodingKeys: String, CodingKey {
        case `schemaVersion`
        case `tool`
        case `status`
        case `commands`
        case `completed`
        case `docs`
    }
    public init(`schemaVersion`: Int, `tool`: WirePluginTool, `status`: WirePluginInstallStatus, `commands`: [[String]], `completed`: Int, `docs`: String) throws {
        self.`schemaVersion` = `schemaVersion`
        self.`tool` = `tool`
        self.`status` = `status`
        self.`commands` = `commands`
        self.`completed` = `completed`
        self.`docs` = `docs`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`schemaVersion` = try c.decode(Int.self, forKey: .`schemaVersion`)
        self.`tool` = try c.decode(WirePluginTool.self, forKey: .`tool`)
        self.`status` = try c.decode(WirePluginInstallStatus.self, forKey: .`status`)
        self.`commands` = try c.decode([[String]].self, forKey: .`commands`)
        self.`completed` = try c.decode(Int.self, forKey: .`completed`)
        self.`docs` = try c.decode(String.self, forKey: .`docs`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`schemaVersion`, forKey: .`schemaVersion`)
        try c.encode(`tool`, forKey: .`tool`)
        try c.encode(`status`, forKey: .`status`)
        try c.encode(`commands`, forKey: .`commands`)
        try c.encode(`completed`, forKey: .`completed`)
        try c.encode(`docs`, forKey: .`docs`)
    }
    private func validate() throws {
        guard `schemaVersion` >= 1 else { throw WireDecodeError.invalidBound }
        guard `schemaVersion` <= 1 else { throw WireDecodeError.invalidBound }
        guard `completed` >= 0 else { throw WireDecodeError.invalidBound }
        guard `completed` <= 2 else { throw WireDecodeError.invalidBound }
        guard tool.isKnown, status.isKnown, commands.count == 2,
              commands.allSatisfy({ !$0.isEmpty && $0.allSatisfy { !$0.isEmpty } }) else { throw WireDecodeError.invalidFrame }
        switch status {
        case .installed: guard completed == commands.count else { throw WireDecodeError.invalidFrame }
        case .instructions, .planned: guard completed == 0 else { throw WireDecodeError.invalidFrame }
        case .failed: guard completed < commands.count else { throw WireDecodeError.invalidFrame }
        default: throw WireDecodeError.invalidFrame
        }
    }
}

public enum WirePluginInstallStatus: Codable, Sendable, Equatable {
    case `installed`
    case `instructions`
    case `planned`
    case `failed`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "installed": self = .`installed`
        case "instructions": self = .`instructions`
        case "planned": self = .`planned`
        case "failed": self = .`failed`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`installed`: return "installed"
        case .`instructions`: return "instructions"
        case .`planned`: return "planned"
        case .`failed`: return "failed"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public enum WirePluginTool: Codable, Sendable, Equatable {
    case `claudeCode`
    case `codex`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "claude-code": self = .`claudeCode`
        case "codex": self = .`codex`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`claudeCode`: return "claude-code"
        case .`codex`: return "codex"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public struct WirePublicationCapability: Codable, Sendable {
    public let `status`: String
    public let `reason`: String?
    private enum CodingKeys: String, CodingKey {
        case `status`
        case `reason`
    }
    public init(`status`: String, `reason`: String? = nil) throws {
        self.`status` = `status`
        self.`reason` = `reason`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`status` = try c.decode(String.self, forKey: .`status`)
        self.`reason` = try? c.decodeIfPresent(String.self, forKey: .`reason`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`status`, forKey: .`status`)
        try c.encodeIfPresent(`reason`, forKey: .`reason`)
    }
    private func validate() throws {
    }
}

public struct WirePublicationResult: Codable, Sendable {
    public let `contractVersion`: Int
    public let `capabilities`: [String: WirePublicationCapability]
    public let `schemaVersion`: Int
    public let `publicationId`: String
    public let `publishedAt`: String?
    public let `units`: WirePublicationUnits
    public let `selectionRevision`: WireJSONValue?
    public let `models`: [WireJSONValue]
    public let `lineups`: [WireJSONValue]
    public let `speedTiers`: [WireJSONValue]
    public let `resets`: [WireJSONValue]
    public let `windows`: [WireJSONValue]
    public let `multipliers`: [WireJSONValue]?
    public let `multiplierHorizon`: WireJSONValue?
    public let `planMetering`: WireJSONValue?
    private enum CodingKeys: String, CodingKey {
        case `contractVersion`
        case `capabilities`
        case `schemaVersion`
        case `publicationId`
        case `publishedAt`
        case `units`
        case `selectionRevision`
        case `models`
        case `lineups`
        case `speedTiers`
        case `resets`
        case `windows`
        case `multipliers`
        case `multiplierHorizon`
        case `planMetering`
    }
    public init(`contractVersion`: Int, `capabilities`: [String: WirePublicationCapability], `schemaVersion`: Int, `publicationId`: String, `publishedAt`: String?, `units`: WirePublicationUnits, `selectionRevision`: WireJSONValue? = nil, `models`: [WireJSONValue], `lineups`: [WireJSONValue], `speedTiers`: [WireJSONValue], `resets`: [WireJSONValue], `windows`: [WireJSONValue], `multipliers`: [WireJSONValue]?, `multiplierHorizon`: WireJSONValue?, `planMetering`: WireJSONValue?) throws {
        self.`contractVersion` = `contractVersion`
        self.`capabilities` = `capabilities`
        self.`schemaVersion` = `schemaVersion`
        self.`publicationId` = `publicationId`
        self.`publishedAt` = `publishedAt`
        self.`units` = `units`
        self.`selectionRevision` = `selectionRevision`
        self.`models` = `models`
        self.`lineups` = `lineups`
        self.`speedTiers` = `speedTiers`
        self.`resets` = `resets`
        self.`windows` = `windows`
        self.`multipliers` = `multipliers`
        self.`multiplierHorizon` = `multiplierHorizon`
        self.`planMetering` = `planMetering`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`contractVersion` = try c.decode(Int.self, forKey: .`contractVersion`)
        self.`capabilities` = try c.decode([String: WirePublicationCapability].self, forKey: .`capabilities`)
        self.`schemaVersion` = try c.decode(Int.self, forKey: .`schemaVersion`)
        self.`publicationId` = try c.decode(String.self, forKey: .`publicationId`)
        guard c.contains(.`publishedAt`) else { throw WireDecodeError.invalidIdentity }
        self.`publishedAt` = try c.decodeIfPresent(String.self, forKey: .`publishedAt`)
        self.`units` = try c.decode(WirePublicationUnits.self, forKey: .`units`)
        self.`selectionRevision` = c.contains(.`selectionRevision`) ? try c.decode(WireJSONValue.self, forKey: .`selectionRevision`) : nil
        self.`models` = try c.decode([WireJSONValue].self, forKey: .`models`)
        self.`lineups` = try c.decode([WireJSONValue].self, forKey: .`lineups`)
        self.`speedTiers` = try c.decode([WireJSONValue].self, forKey: .`speedTiers`)
        self.`resets` = try c.decode([WireJSONValue].self, forKey: .`resets`)
        self.`windows` = try c.decode([WireJSONValue].self, forKey: .`windows`)
        guard c.contains(.`multipliers`) else { throw WireDecodeError.invalidIdentity }
        self.`multipliers` = try c.decodeIfPresent([WireJSONValue].self, forKey: .`multipliers`)
        guard c.contains(.`multiplierHorizon`) else { throw WireDecodeError.invalidIdentity }
        self.`multiplierHorizon` = try c.decodeIfPresent(WireJSONValue.self, forKey: .`multiplierHorizon`)
        guard c.contains(.`planMetering`) else { throw WireDecodeError.invalidIdentity }
        self.`planMetering` = try c.decodeIfPresent(WireJSONValue.self, forKey: .`planMetering`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`contractVersion`, forKey: .`contractVersion`)
        try c.encode(`capabilities`, forKey: .`capabilities`)
        try c.encode(`schemaVersion`, forKey: .`schemaVersion`)
        try c.encode(`publicationId`, forKey: .`publicationId`)
        try c.encode(`publishedAt`, forKey: .`publishedAt`)
        try c.encode(`units`, forKey: .`units`)
        try c.encodeIfPresent(`selectionRevision`, forKey: .`selectionRevision`)
        try c.encode(`models`, forKey: .`models`)
        try c.encode(`lineups`, forKey: .`lineups`)
        try c.encode(`speedTiers`, forKey: .`speedTiers`)
        try c.encode(`resets`, forKey: .`resets`)
        try c.encode(`windows`, forKey: .`windows`)
        try c.encode(`multipliers`, forKey: .`multipliers`)
        try c.encode(`multiplierHorizon`, forKey: .`multiplierHorizon`)
        try c.encode(`planMetering`, forKey: .`planMetering`)
    }
    private func validate() throws {
        guard `contractVersion` >= 1 else { throw WireDecodeError.invalidBound }
        guard `contractVersion` <= 1 else { throw WireDecodeError.invalidBound }
        guard `schemaVersion` >= 1 else { throw WireDecodeError.invalidBound }
        guard `schemaVersion` <= 1 else { throw WireDecodeError.invalidBound }
        try WireValidation.identity(`publicationId`)
    }
}

public struct WirePublicationUnits: Codable, Sendable {
    public let `ability`: String
    public let `cost`: String
    public let `time`: String
    private enum CodingKeys: String, CodingKey {
        case `ability`
        case `cost`
        case `time`
    }
    public init(`ability`: String, `cost`: String, `time`: String) throws {
        self.`ability` = `ability`
        self.`cost` = `cost`
        self.`time` = `time`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`ability` = try c.decode(String.self, forKey: .`ability`)
        self.`cost` = try c.decode(String.self, forKey: .`cost`)
        self.`time` = try c.decode(String.self, forKey: .`time`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`ability`, forKey: .`ability`)
        try c.encode(`cost`, forKey: .`cost`)
        try c.encode(`time`, forKey: .`time`)
    }
    private func validate() throws {
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
public struct WireRefreshDecision: Codable, Sendable {
    public let `agoSeconds`: Int64
    public let `scope`: WireRefreshDecisionScope
    public let `outcome`: WireRefreshDecisionOutcome
    public let `reason`: WireRefreshDecisionReason
    private enum CodingKeys: String, CodingKey {
        case `agoSeconds`
        case `scope`
        case `outcome`
        case `reason`
    }
    public init(`agoSeconds`: Int64, `scope`: WireRefreshDecisionScope, `outcome`: WireRefreshDecisionOutcome, `reason`: WireRefreshDecisionReason) throws {
        self.`agoSeconds` = `agoSeconds`
        self.`scope` = `scope`
        self.`outcome` = `outcome`
        self.`reason` = `reason`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`agoSeconds` = try c.decode(Int64.self, forKey: .`agoSeconds`)
        self.`scope` = try c.decode(WireRefreshDecisionScope.self, forKey: .`scope`)
        self.`outcome` = try c.decode(WireRefreshDecisionOutcome.self, forKey: .`outcome`)
        self.`reason` = try c.decode(WireRefreshDecisionReason.self, forKey: .`reason`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`agoSeconds`, forKey: .`agoSeconds`)
        try c.encode(`scope`, forKey: .`scope`)
        try c.encode(`outcome`, forKey: .`outcome`)
        try c.encode(`reason`, forKey: .`reason`)
    }
    private func validate() throws {
        guard `agoSeconds` >= 0 else { throw WireDecodeError.invalidBound }
    }
}

public enum WireRefreshDecisionOutcome: Codable, Sendable, Equatable {
    case `notAttempted`
    case `deferred`
    case `failed`
    case `succeeded`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "not_attempted": self = .`notAttempted`
        case "deferred": self = .`deferred`
        case "failed": self = .`failed`
        case "succeeded": self = .`succeeded`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`notAttempted`: return "not_attempted"
        case .`deferred`: return "deferred"
        case .`failed`: return "failed"
        case .`succeeded`: return "succeeded"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public enum WireRefreshDecisionReason: Codable, Sendable, Equatable {
    case `startup`
    case `wake`
    case `due`
    case `notGranted`
    case `offline`
    case `readOnly`
    case `budget`
    case `inFlight`
    case `unavailable`
    case `completed`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "startup": self = .`startup`
        case "wake": self = .`wake`
        case "due": self = .`due`
        case "not_granted": self = .`notGranted`
        case "offline": self = .`offline`
        case "read_only": self = .`readOnly`
        case "budget": self = .`budget`
        case "in_flight": self = .`inFlight`
        case "unavailable": self = .`unavailable`
        case "completed": self = .`completed`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`startup`: return "startup"
        case .`wake`: return "wake"
        case .`due`: return "due"
        case .`notGranted`: return "not_granted"
        case .`offline`: return "offline"
        case .`readOnly`: return "read_only"
        case .`budget`: return "budget"
        case .`inFlight`: return "in_flight"
        case .`unavailable`: return "unavailable"
        case .`completed`: return "completed"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public enum WireRefreshDecisionScope: Codable, Sendable, Equatable {
    case `codexRuntimeUsage`
    case `codexLocalHistory`
    case `claudeAccountUsageSavedLogin`
    case `geminiAccountUsageSavedLogin`
    case `cursorAccountUsageSavedLogin`
    case `copilotRuntimeUsage`
    case `kimiAccountUsageSavedLogin`
    case `grokAccountUsageSavedLogin`
    case `kiroRuntimeUsage`
    case `antigravityRuntimeUsage`
    case `zaiAccountUsageApiKey`
    case `minimaxAccountUsageApiKey`
    case `opencodegoAccountUsageApiKey`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "codex.runtime_usage": self = .`codexRuntimeUsage`
        case "codex.local_history": self = .`codexLocalHistory`
        case "claude.account_usage.saved_login": self = .`claudeAccountUsageSavedLogin`
        case "gemini.account_usage.saved_login": self = .`geminiAccountUsageSavedLogin`
        case "cursor.account_usage.saved_login": self = .`cursorAccountUsageSavedLogin`
        case "copilot.runtime_usage": self = .`copilotRuntimeUsage`
        case "kimi.account_usage.saved_login": self = .`kimiAccountUsageSavedLogin`
        case "grok.account_usage.saved_login": self = .`grokAccountUsageSavedLogin`
        case "kiro.runtime_usage": self = .`kiroRuntimeUsage`
        case "antigravity.runtime_usage": self = .`antigravityRuntimeUsage`
        case "zai.account_usage.api_key": self = .`zaiAccountUsageApiKey`
        case "minimax.account_usage.api_key": self = .`minimaxAccountUsageApiKey`
        case "opencodego.account_usage.api_key": self = .`opencodegoAccountUsageApiKey`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`codexRuntimeUsage`: return "codex.runtime_usage"
        case .`codexLocalHistory`: return "codex.local_history"
        case .`claudeAccountUsageSavedLogin`: return "claude.account_usage.saved_login"
        case .`geminiAccountUsageSavedLogin`: return "gemini.account_usage.saved_login"
        case .`cursorAccountUsageSavedLogin`: return "cursor.account_usage.saved_login"
        case .`copilotRuntimeUsage`: return "copilot.runtime_usage"
        case .`kimiAccountUsageSavedLogin`: return "kimi.account_usage.saved_login"
        case .`grokAccountUsageSavedLogin`: return "grok.account_usage.saved_login"
        case .`kiroRuntimeUsage`: return "kiro.runtime_usage"
        case .`antigravityRuntimeUsage`: return "antigravity.runtime_usage"
        case .`zaiAccountUsageApiKey`: return "zai.account_usage.api_key"
        case .`minimaxAccountUsageApiKey`: return "minimax.account_usage.api_key"
        case .`opencodegoAccountUsageApiKey`: return "opencodego.account_usage.api_key"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public enum WireRefreshDisabledReason: Codable, Sendable, Equatable {
    case `cooldown`
    case `readOnly`
    case `offline`
    case `policyPending`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "cooldown": self = .`cooldown`
        case "read_only": self = .`readOnly`
        case "offline": self = .`offline`
        case "policy_pending": self = .`policyPending`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`cooldown`: return "cooldown"
        case .`readOnly`: return "read_only"
        case .`offline`: return "offline"
        case .`policyPending`: return "policy_pending"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}
public struct WireRefreshMember: Codable, Sendable {
    public let `rowId`: String
    public let `route`: RowsRoute
    public let `subscriptionRef`: String?
    public let `accountLocator`: String?
    private enum CodingKeys: String, CodingKey {
        case `rowId`
        case `route`
        case `subscriptionRef`
        case `accountLocator`
    }
    public init(`rowId`: String, `route`: RowsRoute, `subscriptionRef`: String? = nil, `accountLocator`: String? = nil) throws {
        self.`rowId` = `rowId`
        self.`route` = `route`
        self.`subscriptionRef` = `subscriptionRef`
        self.`accountLocator` = `accountLocator`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`rowId` = try c.decode(String.self, forKey: .`rowId`)
        self.`route` = try c.decode(RowsRoute.self, forKey: .`route`)
        if c.contains(.`subscriptionRef`), try c.decodeNil(forKey: .`subscriptionRef`) { throw WireDecodeError.invalidIdentity }
        self.`subscriptionRef` = try c.decodeIfPresent(String.self, forKey: .`subscriptionRef`)
        if c.contains(.`accountLocator`), try c.decodeNil(forKey: .`accountLocator`) { throw WireDecodeError.invalidIdentity }
        self.`accountLocator` = try c.decodeIfPresent(String.self, forKey: .`accountLocator`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(`rowId`, forKey: .`rowId`)
        try c.encode(`route`, forKey: .`route`)
        try c.encodeIfPresent(`subscriptionRef`, forKey: .`subscriptionRef`)
        try c.encodeIfPresent(`accountLocator`, forKey: .`accountLocator`)
    }
    private func validate() throws {
        if let value = `subscriptionRef` { try WireValidation.reference(value) }
        if let value = `accountLocator` { try WireValidation.reference(value) }
    }
}

public struct WireRefreshRequestParams: Codable, Sendable {
    public let `member`: WireRefreshMember?
    public let `scopes`: [String]?
    private enum CodingKeys: String, CodingKey {
        case `member`
        case `scopes`
    }
    public init(`member`: WireRefreshMember? = nil, `scopes`: [String]? = nil) throws {
        self.`member` = `member`
        self.`scopes` = `scopes`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if c.contains(.`member`), try c.decodeNil(forKey: .`member`) { throw WireDecodeError.invalidIdentity }
        self.`member` = try c.decodeIfPresent(WireRefreshMember.self, forKey: .`member`)
        self.`scopes` = try c.decodeIfPresent([String].self, forKey: .`scopes`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(`member`, forKey: .`member`)
        try c.encodeIfPresent(`scopes`, forKey: .`scopes`)
    }
    private func validate() throws {
        for scope in (scopes ?? []) { try WireValidation.identity(scope) }
    }
}

public struct WireRefreshScheduled: Codable, Sendable {
    public let `scope`: String
    public let `at`: WireTimestamp
    public let `disabledReason`: WireRefreshDisabledReason?
    private enum CodingKeys: String, CodingKey {
        case `scope`
        case `at`
        case `disabledReason`
    }
    public init(`scope`: String, `at`: WireTimestamp, `disabledReason`: WireRefreshDisabledReason? = nil) throws {
        self.`scope` = `scope`
        self.`at` = `at`
        self.`disabledReason` = `disabledReason`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`scope` = try c.decode(String.self, forKey: .`scope`)
        self.`at` = try c.decode(WireTimestamp.self, forKey: .`at`)
        self.`disabledReason` = try? c.decodeIfPresent(WireRefreshDisabledReason.self, forKey: .`disabledReason`)
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

public struct WireRequest: Codable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
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
        if c.contains(.`id`), try c.decodeNil(forKey: .`id`) { throw WireDecodeError.invalidIdentity }
        self.`id` = try c.decodeIfPresent(WireRequestID.self, forKey: .`id`)
        self.`method` = try c.decode(String.self, forKey: .`method`)
        self.`params` = c.contains(.`params`) ? try c.decode(WireJSONValue.self, forKey: .`params`) : nil
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
        try WireValidation.identity(method)
        if method == "credentials/result" {
            guard let params = params else { throw WireDecodeError.invalidAuthorization }
            _ = try WireDecoder.decode(WireCredentialResult.self, from: JSONEncoder().encode(params))
        }
    }
    public var description: String { "WireRequest([redacted params])" }
    public var debugDescription: String { description }
}

public struct WireRowsProjection: Codable, Sendable {
    public let `resetEvents`: [RowsResetEvent]?
    public let `forecasts`: [WireCockpitForecast]?
    public let `rowsVersion`: Int
    public let `rows`: [RowsRow]
    public let `rowsSummary`: RowsRowsSummary
    public var invalidRowCount: Int { `rows`.filter { $0.invalid }.count }
    private enum CodingKeys: String, CodingKey {
        case `resetEvents`
        case `forecasts`
        case `rowsVersion`
        case `rows`
        case `rowsSummary`
    }
    public init(`resetEvents`: [RowsResetEvent]? = nil, `forecasts`: [WireCockpitForecast]? = nil, `rowsVersion`: Int, `rows`: [RowsRow], `rowsSummary`: RowsRowsSummary) throws {
        self.`resetEvents` = `resetEvents`
        self.`forecasts` = `forecasts`
        self.`rowsVersion` = `rowsVersion`
        self.`rows` = `rows`
        self.`rowsSummary` = `rowsSummary`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if c.contains(.`resetEvents`), try c.decodeNil(forKey: .`resetEvents`) { throw WireDecodeError.invalidIdentity }
        self.`resetEvents` = try c.decodeIfPresent([RowsResetEvent].self, forKey: .`resetEvents`)
        if c.contains(.`forecasts`), try c.decodeNil(forKey: .`forecasts`) { throw WireDecodeError.invalidIdentity }
        self.`forecasts` = try? c.decodeIfPresent([WireCockpitForecast].self, forKey: .`forecasts`)
        self.`rowsVersion` = try c.decode(Int.self, forKey: .`rowsVersion`)
        var rowElements = try c.nestedUnkeyedContainer(forKey: .`rows`)
        var decodedRows: [RowsRow] = []
        while !rowElements.isAtEnd {
            let rowDecoder = try rowElements.superDecoder()
            decodedRows.append(try WireRowDecoding.decode(from: rowDecoder))
        }
        self.`rows` = decodedRows
        self.`rowsSummary` = try c.decode(RowsRowsSummary.self, forKey: .`rowsSummary`)
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        try validate()
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(`resetEvents`, forKey: .`resetEvents`)
        try c.encodeIfPresent(`forecasts`, forKey: .`forecasts`)
        try c.encode(`rowsVersion`, forKey: .`rowsVersion`)
        try c.encode(`rows`, forKey: .`rows`)
        try c.encode(`rowsSummary`, forKey: .`rowsSummary`)
    }
    private func validate() throws {
        guard rowsVersion == WireProtocol.rowsVersion else { throw WireDecodeError.invalidVersion }
        guard Set(rows.map { $0.id }).count == rows.count else { throw WireDecodeError.invalidIdentity }
    }
}

public struct WireRowsSnapshot: Codable, Sendable {
    public let `sequence`: UInt64
    public let `projection`: WireRowsProjection
    private enum CodingKeys: String, CodingKey {
        case `sequence`
        case `projection`
    }
    public init(`sequence`: UInt64, `projection`: WireRowsProjection) throws {
        self.`sequence` = `sequence`
        self.`projection` = `projection`
        try validate()
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.`sequence` = try c.decode(UInt64.self, forKey: .`sequence`)
        self.`projection` = try c.decode(WireRowsProjection.self, forKey: .`projection`)
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

public enum WireScopeDisabledReason: Codable, Sendable, Equatable {
    case `policyPending`
    case unknown(String)
    public init(rawValue: String) {
        switch rawValue {
        case "policy_pending": self = .`policyPending`
        default: self = .unknown(rawValue)
        }
    }
    public var rawValue: String {
        switch self {
        case .`policyPending`: return "policy_pending"
        case .unknown(let value): return value
        }
    }
    public var isKnown: Bool { if case .unknown = self { return false }; return true }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
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
        let extra = try decoder.container(keyedBy: WireCodingKey.self)
        if extra.allKeys.contains(where: { $0.stringValue == "error" }) { throw WireDecodeError.invalidFrame }
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
